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

## Emitted on load_slot() success only (slot 1..3), before the function returns
## true. Failure paths (no_save/bad_json/bad_schema/bad_version) never emit —
## the cultivation screen connects this to refresh its surface after a load
## lands on the already-hosted scene.
signal loaded(slot: int)

## Emitted at the end of new_profile(): a run has begun with a fresh profile, so
## run-boundary session state (GameManager.map_events_resolved_count) resets.
signal profile_created

# ---------------------------------------------------------------------------
# State (surface vars have safe defaults so arbitrary-frame assertions never
# see null: seed/last_error/slot/has_save and the six *_left counts).
# ---------------------------------------------------------------------------

var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # never null
var profile: PlayerProfile = PlayerProfile.new_default()
var seed: int = 0
var last_error: String = ""   # "" | "no_save" | "bad_json" | "bad_version" | "bad_schema" | "save_refused" | "io_error" | "serialize_failed" | "validate_failed"
var slot: int = 0             # last used slot 1..3; 0 = none yet
var has_save: bool = false    # true after a successful save_slot() this session
# IO-error instrumentation (task plan save_manager_repair): latched on every
# io_error path so a probe can read the REAL error code/text instead of a bare
# string. debug_user_dir_* records the resolved user:// root for diagnostics.
var last_io_error_code: int = 0
var last_io_error_text: String = ""
var debug_user_dir_path: String = OS.get_user_data_dir()
var debug_user_dir_exists: bool = false
var eco_left: int = 0
var eq_left: int = 0
var growth_left: int = 0
var pow_left: int = 0
var trait_left: int = 0
var art_left: int = 0
# Playtest roundtrip observability (step2_design C15): captured on every
# SUCCESSFUL save_slot/load_slot so a harness can assert full save->load
# equality. Failure paths leave all six untouched. Schema is unchanged —
# these are surface reads of the same dicts, never persisted keys.
var snapshot_profile_json: String = ""
var snapshot_rng_state: int = 0
var snapshot_decks_string: String = ""
var loaded_profile_json: String = ""
var loaded_rng_state: int = 0
var loaded_decks_string: String = ""
var decks: Dictionary = {}    # {"economy": {"remaining": Array, "drawn": Array}, ...} — six keys, all String
var segment: String = ""      # not surface; save writes GameManager.current_state, load restores it

# ---------------------------------------------------------------------------
# RNG
# ---------------------------------------------------------------------------

## splitmix64 finalizer (verbatim algorithm from research_notes). Mixes a raw
## entropy seed once so similar raw seeds do not produce similar streams —
## RandomNumberGenerator has no avalanche effect, so close raw seeds must not
## yield close streams.
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
## tutorial_done set false — creation now happens BEFORE the tutorial;
## TutorialManager._finish_tutorial() sets it true on tutorial completion), a
## fresh deck set, and a fresh entropy seed from the system clock (not gameplay
## RNG).
func new_profile(attrs: Dictionary, traits: Array[String]) -> void:
    profile = PlayerProfile.new_default()
    for key in PlayerProfile.ATTR_KEYS:
        var v: Variant = attrs.get(key, PlayerProfile.ATTR_FLOOR)
        if v is int:
            profile.set_attr(key, v as int)
    for t in traits:
        if t is String:
            profile.add_trait(t as String)
    profile.flags["tutorial_done"] = false
    seed = Time.get_ticks_usec()
    apply_seed(seed)
    _init_decks()
    _refresh_deck_counts()
    last_error = ""
    slot = 0
    has_save = false
    profile_created.emit()


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
# User dir / IO diagnostics
# ---------------------------------------------------------------------------

## Autoload-ready: self-heal the user dir so the very first save cannot fail
## on a missing user:// root (an unset HOME in CI makes this real). Only
## touches core classes — no cross-autoload dependency.
func _ready() -> void:
    ensure_user_dir()

## Public self-heal: create user:// when absent, then record the observable
## state. Returns true when the dir exists afterwards. Safe to call any time
## (save_slot() calls it again at the top so a dir deleted mid-session
## self-heals before the write).
func ensure_user_dir() -> bool:
    var abs := ProjectSettings.globalize_path("user://")
    DirAccess.make_dir_recursive_absolute(abs)
    debug_user_dir_exists = DirAccess.dir_exists_absolute(abs)
    return debug_user_dir_exists

## File-existence check for slot s in 1..3 — the menu/availability surface must
## use this, never has_save (has_save is session-memory: set only by a
## successful save_slot() this session, never by load or by file state).
func has_save_file(s: int) -> bool:
    return s in [1, 2, 3] and FileAccess.file_exists("user://save_%d.json" % s)

## Latch the last IO failure code/text and mark last_error = "io_error".
## Called ONLY at real file-op failures (open-WRITE null, copy_absolute fail,
## rename_absolute fail). Non-IO failures (empty-JSON guard, step-2/step-5
## validation) set serialize_failed / validate_failed directly and do NOT call
## this — get_open_error() is meaningless on a path that never hit the disk.
func _record_io_error(code: int) -> void:
    last_io_error_code = code
    last_io_error_text = error_string(code)
    last_error = "io_error"

# ---------------------------------------------------------------------------
# Save / load / delete
# ---------------------------------------------------------------------------

## Guarded save: slot in 1..3, GameManager.current_state in STABLE_STATES, no
## SceneManager swap in flight. Atomic 5-step write (.tmp -> validate -> backup
## old -> rename -> re-validate -> drop backup); any failure restores the backup
## and sets last_error="io_error".
## update_snapshot := false (autosaves only) skips the snapshot_* re-read block
## so a background autosave can never clobber the manual save->load roundtrip
## surface; slot/has_save/last_error and the file write still happen.
func save_slot(s: int, update_snapshot: bool = true) -> bool:
    if not (s >= 1 and s <= 3):
        last_error = "save_refused"
        return false
    if not STABLE_STATES.has(GameManager.current_state):
        last_error = "save_refused"
        return false
    if _swap_in_flight():
        last_error = "save_refused"
        return false

    ensure_user_dir()

    # Stale-file hygiene: a .tmp/.bak left by an interrupted prior save must
    # never poison the next save (copy/rename onto an existing path is
    # platform-dependent). Removing first makes steps 3/4 deterministic.
    _remove_file(_tmp_path(s))
    _remove_file(_bak_path(s))

    var real := _path(s)
    var tmp := _tmp_path(s)
    var bak := _bak_path(s)

    # Step 1: write the tmp file (pretty-printed plain JSON). A save dict that
    # JSON.stringify cannot serialize (e.g. a nested Dictionary with a
    # non-String key) stringifies to "" — writing that would create an empty
    # file that then fails Step-2 validation opaquely. Guard it as
    # serialize_failed (a serialization defect, NOT an IO failure — no file op
    # ran, so get_open_error() is meaningless here) and leave no file behind.
    var json_text := JSON.stringify(_build_save_dict(), "\t")
    if json_text == "":
        last_error = "serialize_failed"
        last_io_error_code = 0
        last_io_error_text = "OK"
        return false
    var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        _record_io_error(FileAccess.get_open_error())
        return false
    f.store_string(json_text)
    f.close()

    # Step 2: re-read and validate the tmp — never trust the write. A
    # validation failure is a schema defect, not an IO failure — the file was
    # read and parsed fine, so record validate_failed without get_open_error().
    if not _apply_save_dict(_read_json(tmp)):
        _remove_file(tmp)
        last_error = "validate_failed"
        last_io_error_code = 0
        last_io_error_text = "OK"
        return false

    # Step 3: back up an existing save before touching it.
    if FileAccess.file_exists(real):
        var copy_err: Error = DirAccess.copy_absolute(real, bak)
        if copy_err != OK:
            _remove_file(tmp)
            _record_io_error(copy_err)
            return false

    # Step 4: remove the old file, promote tmp -> real.
    if FileAccess.file_exists(real):
        DirAccess.remove_absolute(real)
    var rename_err: Error = DirAccess.rename_absolute(tmp, real)
    if rename_err != OK:
        _restore_bak(bak, real)
        _record_io_error(rename_err)
        return false

    # Step 5: re-read and re-validate the real file, then drop the backup.
    # Invariant: a failed save never leaves a promoted-but-invalid `real` file —
    # restore the backup when one exists, otherwise remove the invalid file
    # (the old _restore_bak no-ops with no .bak and left it behind, which then
    # surfaced as bad_schema/bad_json on a later load).
    if not _apply_save_dict(_read_json(real)):
        if FileAccess.file_exists(bak):
            _restore_bak(bak, real)
        else:
            _remove_file(real)
        last_error = "validate_failed"
        last_io_error_code = 0
        last_io_error_text = "OK"
        return false
    _remove_file(bak)

    # Surface snapshots from the file that was just written (re-read, not the
    # live dict). The live dict holds ints (JSON.stringify -> "4"), but a later
    # load parses the file with JSON.parse_string, which yields floats ("4.0")
    # in this build (player_profile.gd L117-118) — stringifying the live dict
    # and the parsed dict would render the SAME number as two different
    # strings, breaking snapshot_* == loaded_* on a roundtrip. Re-reading the
    # file captures exactly the bytes a load will parse; step 5 just validated
    # it, so this read cannot fail. Success path only. Skipped for autosaves
    # (update_snapshot == false) — the snapshot surface is for MANUAL save->load
    # roundtrip asserts; a month-advance autosave must never overwrite it with a
    # newer profile (that is exactly the clobber this guard prevents).
    if update_snapshot:
        var saved: Variant = _read_json(real)
        if saved is Dictionary:
            var saved_dict: Dictionary = saved
            snapshot_profile_json = JSON.stringify(saved_dict["profile"])
            snapshot_rng_state = int(saved_dict["rng_state"])
            snapshot_decks_string = _decks_string(saved_dict["decks"] as Dictionary)

    slot = s
    has_save = true
    last_error = ""
    return true


## Load with validation. Missing file -> "no_save" (current profile untouched —
## never wipe unsaved data); unparseable/bad-shape/bad-version -> fresh default
## profile fallback with the matching error code. On success emits loaded(slot)
## before returning true. Never crashes.
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
    if not (version is int or version is float) or int(version) != SAVE_VERSION:
        _fallback_fresh_profile("bad_version")
        return false
    if not _apply_save_dict(parsed):
        _fallback_fresh_profile("bad_schema")
        return false
    # Surface snapshots from the parsed file dict (success path only; the
    # bad_json/bad_schema/bad_version fallbacks above leave them untouched).
    var parsed_dict: Dictionary = parsed
    loaded_profile_json = JSON.stringify(parsed_dict["profile"])
    loaded_rng_state = int(parsed_dict["rng_state"])
    loaded_decks_string = _decks_string(parsed_dict["decks"] as Dictionary)
    slot = s
    last_error = ""
    loaded.emit(s)
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


## Design: autosave is fixed to slot 1. update_snapshot=false so background
## autosaves write the file and set slot/has_save/last_error but never touch
## the snapshot_*/loaded_* roundtrip surface (the manual 存盘 slot-2 save owns
## that surface).
func autosave() -> bool:
    return save_slot(1, false)

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
    # Direct-boot guard: a direct scene boot of cultivation.tscn (or map.tscn)
    # never reaches new_profile()/_restore_decks()/_fallback_fresh_profile(), so
    # `decks` stays `{}`. Boot the six real decks on demand before indexing the
    # missing key (Godot 4.4 raises on a missing-key `[]` lookup). On the normal
    # path new_profile() already populated every DECK_CATEGORIES deck, so this
    # guard is a no-op and never clears drawn/rebuilds remaining.
    if not decks.has(cat):
        _init_decks()
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
        "rng_state": str(rng.state),
        "profile": profile.to_dict(),
        "segment": GameManager.current_state,
        "decks": _decks_snapshot(),
    }


## Deep copy of the live deck state so later mutation cannot corrupt an
## in-flight save. A category with no deck entry yet (e.g. debug_seed_save
## firing before any new_profile) snapshots as an empty deck so the save stays
## schema-valid and loads cleanly. Never index decks directly here — Godot 4.4
## raises "Invalid access to property or key" on a missing-key [] lookup.
func _decks_snapshot() -> Dictionary:
    var out: Dictionary = {}
    for cat in DECK_CATEGORIES:
        var pool: Variant = decks.get(cat, null)
        if not (pool is Dictionary):
            out[cat] = {"remaining": [], "drawn": []}
            continue
        var p: Dictionary = pool
        out[cat] = {
            "remaining": (p["remaining"] as Array).duplicate(),
            "drawn": (p["drawn"] as Array).duplicate(),
        }
    return out


## Deterministic string form of a validated "decks" subtree for the playtest
## surface: DECK_CATEGORIES order, per category "<cat>:<remaining joined by
## ,>,<drawn joined by ,>", categories joined by ";". No Dictionary iteration
## order is relied on. Godot 4 has no Array.join — String.join over a
## PackedStringArray is used, with str() coercion so a hostile hand-edited save
## can never crash the surface. Example:
## {"economy":{"remaining":["a","b"],"drawn":["c"]},...} -> "economy:a,b,c;..."
func _decks_string(decks_dict: Dictionary) -> String:
    var parts: PackedStringArray = []
    for cat in DECK_CATEGORIES:
        var pool: Variant = decks_dict.get(cat, null)
        var remaining_str := ""
        var drawn_str := ""
        if pool is Dictionary:
            var p: Dictionary = pool
            remaining_str = _join_ids(p.get("remaining", []))
            drawn_str = _join_ids(p.get("drawn", []))
        parts.append(cat + ":" + remaining_str + "," + drawn_str)
    return ";".join(parts)


## "a,b,c" for an Array of ids; "" for an empty or non-Array value.
func _join_ids(v: Variant) -> String:
    var out: PackedStringArray = []
    if v is Array:
        for item in v:
            out.append(str(item))
    return ",".join(out)


## Restore profile / rng / decks / segment from a validated save dict. Shared
## by load_slot and the save-time validation pass. Never mutates slot/has_save/
## last_error — callers own those. Restore order matters: seed first (setting
## it resets the stream), then state (resumes it).
func _apply_save_dict(d: Variant) -> bool:
    if not (d is Dictionary):
        return false
    var src: Dictionary = d
    var version: Variant = src.get("version", null)
    if not (version is int or version is float) or int(version) != SAVE_VERSION:
        return false
    var seed_v: Variant = src.get("seed", null)
    var rng_state_v: Variant = src.get("rng_state", null)
    var segment_v: Variant = src.get("segment", null)
    var decks_v: Variant = src.get("decks", null)
    if not (seed_v is int or seed_v is float) or not (rng_state_v is String):
        return false
    if not (segment_v is String):
        return false
    if not _validate_decks(decks_v):
        return false
    profile = PlayerProfile.from_dict(src.get("profile", null))
    seed = int(seed_v)
    rng.seed = seed
    rng.state = int(rng_state_v as String)
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
