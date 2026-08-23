## SaveManager (autoload) — step2_design C2 / task plan save_manager.
##
## Owns the PlayerProfile, the single seeded RandomNumberGenerator, the six
## deck states (remaining/drawn per category), and the 3-slot JSON save IO at
## user://save_<slot>.json with atomic writes (.tmp + .bak rollback) and strict
## load validation. Also exposes the playtest surface variables
## (seed/last_error/slot/has_save/eco_left/.../art_left).
##
## RNG contract (step2_design §7): one instance, one seed persisted in the
## save, all gameplay draws in operation order. mix_seed() is the splitmix64
## finalizer — RandomNumberGenerator has no avalanche effect for similar seeds.
##
## Parse-safety: this file never references autoloads that are not yet
## registered. GameManager (registered before SaveManager in project.godot) is
## read via the autoload global; SceneManager (a sibling subtask) is polled via
## get_node_or_null("/root/SceneManager") so an unregistered identifier can
## never become a parse error.
extends Node

const SAVE_VERSION: int = 1
const DECK_CATEGORIES: Array[String] = ["economy", "equipment", "growth", "power", "trait", "artifact"]
const MONTHLY_CATEGORIES: Array[String] = ["economy", "equipment", "growth"]
const YEARLY_CATEGORIES: Array[String] = ["power", "trait", "artifact"]
const STABLE_STATES: Array[String] = ["CULTIVATION", "MAP"]

# ---------------------------------------------------------------------------
# State (surface vars have safe defaults so arbitrary-frame assertions never
# see null: seed/last_error/slot/has_save and the six *_left counts).
# ---------------------------------------------------------------------------

var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # never null
var profile: PlayerProfile = PlayerProfile.new_default()
var seed: int = 0
var last_error: String = ""   # "" | "no_save" | "bad_json" | "bad_version" | "bad_schema" | "save_refused" | "io_error"
var slot: int = 0             # last used slot 1..3; 0 = none yet
var has_save: bool = false    # true after a successful save_slot() this session
var eco_left: int = 0
var eq_left: int = 0
var growth_left: int = 0
var pow_left: int = 0
var trait_left: int = 0
var art_left: int = 0
var decks: Dictionary = {}    # {"economy": {"remaining": Array, "drawn": Array}, ...} — six keys, all String
var segment: String = ""      # not surface; save writes GameManager.current_state, load restores it

# ---------------------------------------------------------------------------
# RNG
# ---------------------------------------------------------------------------

## splitmix64 finalizer (verbatim algorithm from research_notes). Mixes a raw
## entropy seed once so similar raw seeds do not produce similar streams.
static func mix_seed(x: int) -> int:
    var v: int = x + 0x9E3779B97F4A7C15
    v = (v ^ (v >> 30)) * 0xBF58476D1CE4E5B9
    v = (v ^ (v >> 27)) * 0x94D049BB133111EB
    return v ^ (v >> 31)


## Fresh RNG seeded from mix_seed(seed_value); records the raw seed for the
## save file.
func apply_seed(seed_value: int) -> void:
    rng = RandomNumberGenerator.new()
    rng.seed = mix_seed(seed_value)
    seed = seed_value

# ---------------------------------------------------------------------------
# Profile / decks
# ---------------------------------------------------------------------------

## Character-creation confirm entry: a fresh profile (attrs/traits applied,
## tutorial_done set — creation is only reachable after the tutorial), a fresh
## deck set, and a fresh entropy seed from the system clock (not gameplay RNG).
func new_profile(attrs: Dictionary, traits: Array[String]) -> void:
    profile = PlayerProfile.new_default()
    for key in PlayerProfile.ATTR_KEYS:
        var v: Variant = attrs.get(key, PlayerProfile.ATTR_FLOOR)
        if v is int:
            profile.set_attr(key, v as int)
    for t in traits:
        if t is String:
            profile.add_trait(t as String)
    profile.flags["tutorial_done"] = true
    seed = Time.get_ticks_usec()
    apply_seed(seed)
    _init_decks()
    _refresh_deck_counts()
    last_error = ""
    slot = 0
    has_save = false


## Draw one card per category (MONTHLY or YEARLY array order — never
## Dictionary iteration order), removing each from its deck's remaining and
## moving it into drawn. Returns three dicts with the six CardDef fields.
func draw_cards(monthly: bool) -> Array[Dictionary]:
    var categories: Array[String] = MONTHLY_CATEGORIES if monthly else YEARLY_CATEGORIES
    var out: Array[Dictionary] = []
    for cat in categories:
        out.append(_draw_one(cat))
    _refresh_deck_counts()
    return out

# ---------------------------------------------------------------------------
# Save / load / delete
# ---------------------------------------------------------------------------

## Guarded save: slot in 1..3, GameManager.current_state in STABLE_STATES, no
## SceneManager swap in flight. Atomic 5-step write (.tmp -> validate -> backup
## old -> rename -> re-validate -> drop backup); any failure restores the backup
## and sets last_error="io_error".
func save_slot(s: int) -> bool:
    if not (s >= 1 and s <= 3):
        last_error = "save_refused"
        return false
    if not STABLE_STATES.has(GameManager.current_state):
        last_error = "save_refused"
        return false
    if _swap_in_flight():
        last_error = "save_refused"
        return false

    var real := _path(s)
    var tmp := _tmp_path(s)
    var bak := _bak_path(s)

    # Step 1: write the tmp file (pretty-printed plain JSON).
    var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        last_error = "io_error"
        return false
    f.store_string(JSON.stringify(_build_save_dict(), "\t"))
    f.close()

    # Step 2: re-read and validate the tmp — never trust the write.
    if not _apply_save_dict(_read_json(tmp)):
        _remove_file(tmp)
        last_error = "io_error"
        return false

    # Step 3: back up an existing save before touching it.
    if FileAccess.file_exists(real):
        if DirAccess.copy_absolute(real, bak) != OK:
            _remove_file(tmp)
            last_error = "io_error"
            return false

    # Step 4: remove the old file, promote tmp -> real.
    if FileAccess.file_exists(real):
        DirAccess.remove_absolute(real)
    if DirAccess.rename_absolute(tmp, real) != OK:
        _restore_bak(bak, real)
        last_error = "io_error"
        return false

    # Step 5: re-read and re-validate the real file, then drop the backup.
    if not _apply_save_dict(_read_json(real)):
        _restore_bak(bak, real)
        last_error = "io_error"
        return false
    _remove_file(bak)

    slot = s
    has_save = true
    last_error = ""
    return true


## Load with validation. Missing file -> "no_save" (current profile untouched —
## never wipe unsaved data); unparseable/bad-shape/bad-version -> fresh default
## profile fallback with the matching error code. Never crashes.
func load_slot(s: int) -> bool:
    if not (s >= 1 and s <= 3):
        last_error = "bad_schema"
        return false
    var real := _path(s)
    if not FileAccess.file_exists(real):
        last_error = "no_save"
        return false
    var parsed: Variant = _read_json(real)
    if parsed == null:
        _fallback_fresh_profile("bad_json")
        return false
    if not (parsed is Dictionary):
        _fallback_fresh_profile("bad_schema")
        return false
    var version: Variant = (parsed as Dictionary).get("version", null)
    if not (version is int) or version as int != SAVE_VERSION:
        _fallback_fresh_profile("bad_version")
        return false
    if not _apply_save_dict(parsed):
        _fallback_fresh_profile("bad_schema")
        return false
    slot = s
    last_error = ""
    return true


## Delete the save file and any stale .tmp/.bak. True whenever the file ends
## up absent (including when it was already absent); false only on a real IO
## error.
func delete_slot(s: int) -> bool:
    if not (s >= 1 and s <= 3):
        return false
    var any_error := false
    for path in [_path(s), _tmp_path(s), _bak_path(s)]:
        if FileAccess.file_exists(path):
            if DirAccess.remove_absolute(path) != OK:
                any_error = true
    return not any_error


## Design: autosave is fixed to slot 1.
func autosave() -> bool:
    return save_slot(1)

# ---------------------------------------------------------------------------
# Private — decks
# ---------------------------------------------------------------------------

func _init_decks() -> void:
    decks = {}
    for cat in DECK_CATEGORIES:
        var remaining: Array[String] = []
        if cat == "trait":
            remaining = CardData.build_trait_deck(profile.traits)
        else:
            remaining = CardData.initial_deck(cat)
        decks[cat] = {"remaining": remaining, "drawn": []}


## One draw from one category, after ensuring the deck is non-empty (reshuffle
## if exhausted) and free of garbage / already-owned trait ids.
func _draw_one(cat: String) -> Dictionary:
    _ensure_deck(cat)
    var pool: Dictionary = decks[cat]
    var remaining: Array = pool["remaining"]
    if remaining.is_empty():
        # Nothing drawable (e.g. all 8 positive traits owned) — empty card.
        return {"id": "", "display_name": "", "category": cat, "effect_type": "", "effect_value": 0, "effect_target": ""}
    var id: Variant = remaining.pop_front()
    (pool["drawn"] as Array).append(id)
    if not (id is String):
        return {"id": "", "display_name": "", "category": cat, "effect_type": "", "effect_value": 0, "effect_target": ""}
    return _card_dict(id as String)


## Before a draw: if the deck is empty, reshuffle (static: drawn cards back in;
## trait: rebuilt from currently-unowned positives). Then drop ids with no
## CardData def and (trait deck only) ids the profile now owns — a hand-edited
## save must never re-offer an owned trait.
func _ensure_deck(cat: String) -> void:
    var pool: Dictionary = decks[cat]
    var remaining: Array = pool["remaining"]
    if remaining.is_empty():
        _reshuffle(cat)
        pool = decks[cat]
        remaining = pool["remaining"]
    var cleaned: Array[String] = []
    for id in remaining:
        if not (id is String):
            continue
        var sid: String = id as String
        if CardData.def(sid) == null:
            continue
        if cat == "trait" and profile.has_trait(sid):
            continue
        cleaned.append(sid)
    if cleaned.size() != remaining.size():
        pool["remaining"] = cleaned


## rng-driven Fisher-Yates on a copy of the input (never mutates the input).
## Every rng draw of the deck system happens here, in operation order — the
## single determinism seam.
func _shuffle(arr: Array[String]) -> Array[String]:
    var out: Array[String] = arr.duplicate()
    for i in range(out.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp: String = out[i]
        out[i] = out[j]
        out[j] = tmp
    return out


## Refill a category's remaining: static decks shuffle the drawn pile back in;
## the trait deck rebuilds from the dynamic unowned-positive list (all owned
## ids excluded at source, so the invariant holds even against hostile saves).
func _reshuffle(cat: String) -> void:
    var pool: Dictionary = decks[cat]
    var source: Array[String] = []
    if cat == "trait":
        source = CardData.build_trait_deck(profile.traits)
    else:
        for id in pool["drawn"]:
            if id is String and CardData.def(id as String) != null:
                source.append(id as String)
    pool["remaining"] = _shuffle(source)
    pool["drawn"] = []


## The six CardDef fields as a plain String-keyed Dictionary (JSON-safe).
func _card_dict(id: String) -> Dictionary:
    var def = CardData.def(id)
    if def == null:
        return {"id": "", "display_name": "", "category": "", "effect_type": "", "effect_value": 0, "effect_target": ""}
    return {
        "id": def.id,
        "display_name": def.display_name,
        "category": def.category,
        "effect_type": def.effect_type,
        "effect_value": def.effect_value,
        "effect_target": def.effect_target,
    }

# ---------------------------------------------------------------------------
# Private — counts
# ---------------------------------------------------------------------------

## Keep the six surface *_left vars in sync with the live deck state.
func _refresh_deck_counts() -> void:
    eco_left = _remaining_of("economy")
    eq_left = _remaining_of("equipment")
    growth_left = _remaining_of("growth")
    pow_left = _remaining_of("power")
    trait_left = _remaining_of("trait")
    art_left = _remaining_of("artifact")


func _remaining_of(cat: String) -> int:
    var pool: Variant = decks.get(cat, null)
    if not (pool is Dictionary):
        return 0
    var remaining: Variant = (pool as Dictionary).get("remaining", null)
    if remaining is Array:
        return (remaining as Array).size()
    return 0

# ---------------------------------------------------------------------------
# Private — save dict
# ---------------------------------------------------------------------------

func _build_save_dict() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "seed": seed,
        "rng_state": rng.state,
        "profile": profile.to_dict(),
        "segment": GameManager.current_state,
        "decks": _decks_snapshot(),
    }


## Deep copy of the live deck state so later mutation cannot corrupt an
## in-flight save.
func _decks_snapshot() -> Dictionary:
    var out: Dictionary = {}
    for cat in DECK_CATEGORIES:
        var pool: Dictionary = decks[cat]
        out[cat] = {
            "remaining": (pool["remaining"] as Array).duplicate(),
            "drawn": (pool["drawn"] as Array).duplicate(),
        }
    return out


## Restore profile / rng / decks / segment from a validated save dict. Shared
## by load_slot and the save-time validation pass. Never mutates slot/has_save/
## last_error — callers own those. Restore order matters: seed first (setting
## it resets the stream), then state (resumes it).
func _apply_save_dict(d: Variant) -> bool:
    if not (d is Dictionary):
        return false
    var src: Dictionary = d
    var version: Variant = src.get("version", null)
    if not (version is int) or version as int != SAVE_VERSION:
        return false
    var seed_v: Variant = src.get("seed", null)
    var rng_state_v: Variant = src.get("rng_state", null)
    var segment_v: Variant = src.get("segment", null)
    var decks_v: Variant = src.get("decks", null)
    if not (seed_v is int) or not (rng_state_v is int):
        return false
    if not (segment_v is String):
        return false
    if not _validate_decks(decks_v):
        return false
    profile = PlayerProfile.from_dict(src.get("profile", null))
    seed = seed_v as int
    rng.seed = seed
    rng.state = rng_state_v as int
    segment = segment_v as String
    _restore_decks(decks_v)
    _refresh_deck_counts()
    return true


## Schema check for the decks subtree (all six categories, remaining/drawn are
## Arrays) — shared by load and the save-time validation pass.
func _validate_decks(d: Variant) -> bool:
    if not (d is Dictionary):
        return false
    var src: Dictionary = d
    for cat in DECK_CATEGORIES:
        var pool: Variant = src.get(cat, null)
        if not (pool is Dictionary):
            return false
        var p: Dictionary = pool
        if not (p.get("remaining") is Array) or not (p.get("drawn") is Array):
            return false
    return true


## Coerce a hostile save's deck lists into clean Array[String] (filtered
## BEFORE push — pushing a wrong type into a typed array is a runtime error).
func _restore_decks(d: Dictionary) -> void:
    decks = {}
    for cat in DECK_CATEGORIES:
        var pool: Variant = d.get(cat, null)
        if not (pool is Dictionary):
            decks[cat] = {"remaining": [], "drawn": []}
            continue
        var p: Dictionary = pool
        decks[cat] = {
            "remaining": _coerce_string_array(p.get("remaining", [])),
            "drawn": _coerce_string_array(p.get("drawn", [])),
        }


func _coerce_string_array(v: Variant) -> Array[String]:
    var out: Array[String] = []
    if v is Array:
        for item in v:
            if item is String and (item as String) != "":
                out.append(item as String)
    return out

# ---------------------------------------------------------------------------
# Private — IO helpers
# ---------------------------------------------------------------------------

func _path(s: int) -> String:
    return "user://save_%d.json" % s


func _tmp_path(s: int) -> String:
    return "user://save_%d.json.tmp" % s


func _bak_path(s: int) -> String:
    return "user://save_%d.json.bak" % s


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var f: FileAccess = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return null
    var text: String = f.get_as_text()
    f.close()
    return JSON.parse_string(text)


func _remove_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)


## Restore the .bak over the real file and drop the backup. Only called on a
## failed save so the previous save is never lost (backup -> execute -> verify
## -> delete, never delete-then-insert).
func _restore_bak(bak: String, real: String) -> void:
    if not FileAccess.file_exists(bak):
        return
    if FileAccess.file_exists(real):
        DirAccess.remove_absolute(real)
    DirAccess.copy_absolute(bak, real)
    _remove_file(bak)


func _fallback_fresh_profile(err: String) -> void:
    profile = PlayerProfile.new_default()
    segment = ""
    _init_decks()
    _refresh_deck_counts()
    last_error = err


## True while SceneManager (a sibling autoload) has a deferred scene swap in
## flight. Polled via get_node_or_null so an unregistered SceneManager can
## never crash or fail the compile gate.
func _swap_in_flight() -> bool:
    var sm: Node = get_node_or_null("/root/SceneManager")
    if sm == null:
        return false
    var pending: Variant = sm.get("pending_swap")
    return pending is bool and pending as bool
