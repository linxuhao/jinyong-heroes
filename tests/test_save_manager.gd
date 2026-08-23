## Integration tests for scripts/autoload/save_manager.gd (SaveManager).
##
## Run manually from the repo root:
##   godot --headless -s tests/test_save_manager.gd
##
## The script extends SceneTree; autoloads from project.godot ARE loaded in -s
## mode and are fetched from the root (deferred, so the tree is fully up).
## The test mutates GameManager.current_state to exercise the save guard and
## restores it afterwards so later assertions are not polluted. run_tests.sh
## does not collect unit tests yet — this file only delivers the script plus
## the acceptance contract; the compile gate parses it (it is never auto-run).
extends SceneTree

const SaveManagerScript = preload("res://scripts/autoload/save_manager.gd")
const CardDataScript = preload("res://scripts/data/card_data.gd")

var _sm = null   # SaveManager autoload node
var _gm = null   # GameManager autoload node


func _initialize() -> void:
	# Defer so the root tree (and every autoload) is fully up before touching it.
	call_deferred("_run")


func _run() -> void:
	_sm = root.get_node_or_null("SaveManager")
	_gm = root.get_node_or_null("GameManager")
	if _sm == null or _gm == null:
		push_error("test_save_manager: SaveManager/GameManager autoloads not found (run with -s from the repo root)")
		quit(1)
		return
	# Hermetic start: clear any save files left by an earlier interrupted run.
	# (Criterion 11 then starts from a known-clean state.)
	_sm.delete_slot(1)
	_sm.delete_slot(2)
	_sm.delete_slot(3)
	var ok := _test_all()
	if ok:
		print("PASS test_save_manager")
	else:
		print("FAIL test_save_manager")
	quit(0 if ok else 1)


func _test_all() -> bool:
	var ok := true
	ok = _test_mix_seed_avalanche(ok)
	ok = _test_apply_seed(ok)
	ok = _test_new_profile(ok)
	ok = _test_draw_shape_and_counts(ok)
	ok = _test_reshuffle_and_determinism(ok)
	ok = _test_trait_deck_excludes_owned(ok)
	ok = _test_save_guard_and_atomic(ok)
	ok = _test_roundtrip_continuity(ok)
	ok = _test_snapshot_roundtrip_observability(ok)
	ok = _test_bad_file_fallback(ok)
	ok = _test_missing_file_no_wipe(ok)
	ok = _test_delete_idempotent(ok)
	return ok


# --- criterion 1: splitmix64 avalanche ----------------------------------------

func _test_mix_seed_avalanche(ok: bool) -> bool:
	var a: int = SaveManagerScript.mix_seed(1)
	var b: int = SaveManagerScript.mix_seed(2)
	ok = _expect(ok, (a ^ b) & 0xFFFFFF00 != 0, "mix_seed avalanche: high bits differ between seeds 1 and 2")
	return ok


# --- criterion 2: apply_seed ---------------------------------------------------

func _test_apply_seed(ok: bool) -> bool:
	_sm.apply_seed(7)
	ok = _expect(ok, _sm.rng.seed == SaveManagerScript.mix_seed(7), "apply_seed(7) -> rng.seed == mix_seed(7)")
	ok = _expect(ok, _sm.seed == 7, "apply_seed(7) -> seed var == 7")
	var state1: int = _sm.rng.state
	_sm.apply_seed(8)
	var state2: int = _sm.rng.state
	ok = _expect(ok, state1 != state2, "different seeds -> different rng.state")
	return ok


# --- criterion 3: new_profile shape + deck sizes -------------------------------

func _test_new_profile(ok: bool) -> bool:
	_sm.new_profile({"bone": 15}, ["lone_bane"])
	ok = _expect(ok, _sm.profile.get_attr("bone") == 15, "new_profile bone == 15")
	for key in ["inner", "agility", "wisdom", "fortune"]:
		ok = _expect(ok, _sm.profile.get_attr(key) == 10, "new_profile attr " + key + " == 10")
	ok = _expect(ok, _sm.profile.traits == ["lone_bane"], "new_profile traits == [lone_bane]")
	ok = _expect(ok, _sm.profile.flags["tutorial_done"] == true, "new_profile tutorial_done true")
	ok = _expect(ok, _sm.seed != 0, "new_profile generates a seed")
	ok = _expect(ok, _sm.eco_left == 12, "eco_left == 12")
	ok = _expect(ok, _sm.eq_left == 12, "eq_left == 12")
	ok = _expect(ok, _sm.growth_left == 9, "growth_left == 9")
	ok = _expect(ok, _sm.pow_left == 6, "pow_left == 6")
	ok = _expect(ok, _sm.art_left == 6, "art_left == 6")
	ok = _expect(ok, _sm.trait_left == 8, "trait_left == 8 (lone_bane is a flaw; all 8 positives remain)")
	return ok


# --- criterion 4: draw shape + counts ------------------------------------------

func _test_draw_shape_and_counts(ok: bool) -> bool:
	_sm.new_profile({}, [])
	var cards: Array = _sm.draw_cards(true)
	ok = _expect(ok, cards.size() == 3, "monthly draw returns 3 cards")
	var cats: Array[String] = []
	for c in cards:
		cats.append((c as Dictionary)["category"] as String)
	ok = _expect(ok, cats == ["economy", "equipment", "growth"], "category order economy/equipment/growth")
	var keys := ["id", "display_name", "category", "effect_type", "effect_value", "effect_target"]
	for c in cards:
		var cd: Dictionary = c
		for k in keys:
			ok = _expect(ok, cd.has(k), "card dict has key " + k)
		var id: String = cd["id"] as String
		ok = _expect(ok, CardDataScript.def(id) != null, "drawn id resolves: " + id)
	ok = _expect(ok, _sm.eco_left == 11 and _sm.eq_left == 11 and _sm.growth_left == 8,
		"counts after one draw: 11/11/8")
	return ok


# --- criterion 5: reshuffle + seed-replay determinism ---------------------------

func _test_reshuffle_and_determinism(ok: bool) -> bool:
	# 13 monthly draws: economy/equipment exhaust at 12, so the 13th draw forces
	# an rng-driven reshuffle — the deterministic part of the stream.
	_sm.new_profile({}, [])
	_sm.apply_seed(99)
	var first_run: Array = _draw_monthly_ids(13)
	ok = _expect(ok, _sm.eco_left == 11, "economy reshuffled after 12 draws (11 left after the 13th)")
	# Replay on an identical fresh profile + deck state with the same seed.
	_sm.new_profile({}, [])
	_sm.apply_seed(99)
	var second_run: Array = _draw_monthly_ids(13)
	ok = _expect(ok, first_run == second_run, "seed 99 replay -> identical draw sequence across reshuffles")
	return ok


# --- criterion 6: trait deck never offers an owned trait ------------------------

func _test_trait_deck_excludes_owned(ok: bool) -> bool:
	_sm.new_profile({}, ["iron_shirt"])
	ok = _expect(ok, _sm.trait_left == 7, "trait_left == 7 with iron_shirt owned")
	var cards: Array = _sm.draw_cards(false)
	for c in cards:
		var id: String = (c as Dictionary)["id"] as String
		ok = _expect(ok, id != "iron_shirt", "yearly draw never offers iron_shirt")
	return ok


# --- criterion 7: save guard + atomic file layout -------------------------------

func _test_save_guard_and_atomic(ok: bool) -> bool:
	var prev_state: String = _gm.current_state
	_sm.new_profile({}, [])
	_gm.current_state = "TUTORIAL"
	ok = _expect(ok, _sm.save_slot(1) == false, "save refused in TUTORIAL")
	ok = _expect(ok, _sm.last_error == "save_refused", "last_error == save_refused on guard")
	_gm.current_state = "CULTIVATION"
	ok = _expect(ok, _sm.save_slot(1), "save_slot(1) succeeds in CULTIVATION")
	ok = _expect(ok, _sm.slot == 1 and _sm.has_save, "slot/has_save set after save")
	ok = _expect(ok, _sm.last_error == "", "last_error cleared on success")

	var real := "user://save_1.json"
	ok = _expect(ok, FileAccess.file_exists(real), "save_1.json exists")
	var parsed: Variant = _read_text_json(real)
	ok = _expect(ok, parsed is Dictionary, "save file parses")
	if parsed is Dictionary:
		var d: Dictionary = parsed
		ok = _expect(ok, int(d["version"]) == 1, "save version == 1")
		ok = _expect(ok, int(d["seed"]) == _sm.seed, "save seed matches live seed")
		var decks_v: Variant = d.get("decks", null)
		ok = _expect(ok, decks_v is Dictionary, "save decks present")
		if decks_v is Dictionary:
			for cat in ["economy", "equipment", "growth", "power", "trait", "artifact"]:
				var pool: Variant = (decks_v as Dictionary).get(cat, null)
				ok = _expect(ok, pool is Dictionary, "save deck " + cat + " present")
				if pool is Dictionary:
					ok = _expect(ok, (pool as Dictionary)["remaining"] is Array, cat + " remaining is Array")
					ok = _expect(ok, (pool as Dictionary)["drawn"] is Array, cat + " drawn is Array")
	ok = _expect(ok, not FileAccess.file_exists("user://save_1.json.tmp"), "no .tmp residue after save")
	ok = _expect(ok, not FileAccess.file_exists("user://save_1.json.bak"), "no .bak residue after save")
	_gm.current_state = prev_state
	return ok


# --- criterion 8: save/load roundtrip continuity --------------------------------

func _test_roundtrip_continuity(ok: bool) -> bool:
	var prev_state: String = _gm.current_state
	_gm.current_state = "CULTIVATION"
	_sm.new_profile({}, [])
	_sm.draw_cards(true)
	_sm.draw_cards(true)
	ok = _expect(ok, _sm.save_slot(1), "save for roundtrip")
	# Mutation after the save point: the next economy card is consumed by a
	# draw that must NOT survive the reload.
	var mutation: Array = _sm.draw_cards(true)
	var expected_next: String = (mutation[0] as Dictionary)["id"] as String
	ok = _expect(ok, _sm.load_slot(1), "load_slot(1) succeeds")
	var after: Array = _sm.draw_cards(true)
	var economy_id: String = (after[0] as Dictionary)["id"] as String
	ok = _expect(ok, economy_id == expected_next,
		"post-load next economy card equals un-saved continuation (decks + rng_state restored)")
	_gm.current_state = prev_state
	return ok


# --- criterion 8b: save/load snapshot observability -----------------------------

func _test_snapshot_roundtrip_observability(ok: bool) -> bool:
	var prev_state: String = _gm.current_state
	_gm.current_state = "CULTIVATION"
	_sm.new_profile({"bone": 13}, ["lone_bane"])
	_sm.draw_cards(true)
	ok = _expect(ok, _sm.save_slot(1), "save for snapshot observability")
	ok = _expect(ok, _sm.snapshot_rng_state != 0, "snapshot_rng_state captured on save")
	ok = _expect(ok, _sm.snapshot_profile_json == JSON.stringify(_sm.profile.to_dict()),
		"snapshot_profile_json == profile.to_dict() at the save point")
	ok = _expect(ok, _sm.snapshot_decks_string != "", "snapshot_decks_string captured on save")
	# Mutation after the save point must NOT survive the reload (real save->load
	# path, not a dict copy).
	_sm.profile.set_attr("bone", 99)
	_sm.draw_cards(true)
	ok = _expect(ok, _sm.load_slot(1), "load_slot(1) succeeds")
	ok = _expect(ok, _sm.loaded_profile_json == _sm.snapshot_profile_json,
		"loaded_profile_json == snapshot_profile_json")
	ok = _expect(ok, _sm.loaded_rng_state == _sm.snapshot_rng_state,
		"loaded_rng_state == snapshot_rng_state")
	ok = _expect(ok, _sm.loaded_decks_string == _sm.snapshot_decks_string,
		"loaded_decks_string == snapshot_decks_string")
	ok = _expect(ok, _sm.profile.get_attr("bone") == 13,
		"profile restored to the save point (bone == 13)")
	_gm.current_state = prev_state
	return ok

func _test_bad_file_fallback(ok: bool) -> bool:
	var path := "user://save_2.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{{{not json")
	f.close()
	ok = _expect(ok, _sm.load_slot(2) == false, "bad json load fails")
	ok = _expect(ok, _sm.last_error == "bad_json", "last_error == bad_json")
	ok = _expect(ok, _sm.profile.get_attr("bone") == 10, "fallback profile bone == 10")
	ok = _expect(ok, _sm.profile.traits.is_empty(), "fallback profile traits empty")
	return ok


# --- criterion 10: missing file -> no_save, profile untouched ------------------

func _test_missing_file_no_wipe(ok: bool) -> bool:
	_sm.delete_slot(2)
	# Prime a non-default profile so a wipe would be detectable.
	_sm.new_profile({"bone": 17}, ["deep_fortune"])
	ok = _expect(ok, _sm.load_slot(2) == false, "missing file load fails")
	ok = _expect(ok, _sm.last_error == "no_save", "last_error == no_save")
	ok = _expect(ok, _sm.profile.get_attr("bone") == 17, "profile NOT wiped on no_save")
	ok = _expect(ok, _sm.profile.traits == ["deep_fortune"], "traits preserved on no_save")
	return ok


# --- criterion 11: delete idempotent -------------------------------------------

func _test_delete_idempotent(ok: bool) -> bool:
	var real := "user://save_1.json"
	ok = _expect(ok, FileAccess.file_exists(real), "save_1 exists before delete")
	ok = _expect(ok, _sm.delete_slot(1), "delete_slot(1) true")
	ok = _expect(ok, not FileAccess.file_exists(real), "save_1 gone after delete")
	ok = _expect(ok, _sm.delete_slot(1), "delete_slot(1) again true")
	return ok


# --- helpers ---------------------------------------------------------------------

## n monthly draws, each reduced to the three card ids, as an Array of
## Array[String] (deep-compared by == for replay determinism).
func _draw_monthly_ids(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		var ids: Array[String] = []
		for c in _sm.draw_cards(true):
			ids.append((c as Dictionary)["id"] as String)
		out.append(ids)
	return out


func _read_text_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_save_manager: " + msg)
	return false
