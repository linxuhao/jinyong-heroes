## Integration tests for scripts/segments/cultivation.gd (CultivationScreen).
##
## Run manually from the repo root:
##   godot --headless -s tests/test_cultivation.gd
## (run_tests.sh drives this file with its own -s invocation; it is NOT
## collected by unit_test_runner.gd because cultivation needs the full
## deferred SceneTree + autoloads and a live GameManager.state == "CULTIVATION"
## for the save guard and the fast-forward loop.)
##
## Every scenario starts hermetic: fresh profile (SaveManager.new_profile),
## deterministic seed (SaveManager.apply_seed BEFORE any draw), sect / year /
## month set on the profile, GameManager.current_state forced to "CULTIVATION",
## then the cultivation scene instantiated and added to the root so _ready()
## runs. The run is fully synchronous (no awaits), so per-scenario nodes can be
## freed immediately. Assertions target categories/counts/effects — never exact
## card ids — because deck reshuffles depend on draw history.
extends SceneTree

const CULTIVATION_SCENE = preload("res://scenes/segments/cultivation.tscn")
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
		push_error("test_cultivation: SaveManager/GameManager autoloads not found (run with -s from the repo root)")
		quit(1)
		return
	# Hermetic start: clear save files left by an earlier interrupted run.
	_sm.delete_slot(1)
	_sm.delete_slot(2)
	_sm.delete_slot(3)
	_gm.current_state = "CULTIVATION"
	var ok := _test_all()
	_gm.current_state = "TUTORIAL"   # leave the autoload clean for later runs
	if ok:
		print("PASS test_cultivation")
	else:
		print("FAIL test_cultivation")
	quit(0 if ok else 1)


func _test_all() -> bool:
	var ok := true
	ok = _test_ready_grants_and_stages(ok)
	ok = _test_deck_bookkeeping(ok)
	ok = _test_lone_bane_external_only(ok)
	ok = _test_practice_mastery(ok)
	ok = _test_cultivate_determinism(ok)
	ok = _test_work_and_silver_card(ok)
	ok = _test_trait_pool_card(ok)
	ok = _test_year_end_advance(ok)
	ok = _test_month36_to_map(ok)
	ok = _test_fast_forward(ok)
	ok = _test_save_load_delete_roundtrip(ok)
	ok = _test_add_practice_no_unmastered_noop(ok)
	return ok


# --- criterion 1: fresh profile -> _ready grants arts + stages month 1 ---------

func _test_ready_grants_and_stages(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 12345)
	ok = _expect(ok, node.gongfa_count == 2, "fresh shaolin month 1 grants internal + external (2 arts)")
	ok = _expect(ok, node.mastered_count == 0, "no art is mastered at start")
	ok = _expect(ok, node.phase == "CARD_PICK", "year 1 month 1 stages CARD_PICK (no YEAR_AUGMENT)")
	ok = _expect(ok, node.year == 1 and node.month == 1, "surface year/month == 1/1")
	ok = _expect(ok, node.sect_id == "shaolin", "surface sect_id == shaolin")
	ok = _expect(ok, node.drawn_card_categories.size() == 3, "3 monthly cards drawn")
	var distinct: Dictionary = {}
	for c in node.drawn_card_categories:
		distinct[c] = true
	ok = _expect(ok, distinct.size() == 3, "the 3 categories are distinct")
	ok = _expect(ok, distinct.has("economy") and distinct.has("equipment") and distinct.has("growth"),
		"categories drawn from {economy, equipment, growth}")
	ok = _expect(ok, _sm.profile.main_external_id == "shaolin_luohan_d", "main_external_id set to shaolin_luohan_d")
	_teardown(node)
	return ok


# --- criterion 2: deck bookkeeping ----------------------------------------------

func _test_deck_bookkeeping(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 12345)   # _ready already drew month 1
	ok = _expect(ok, _sm.eco_left == 11 and _sm.eq_left == 11 and _sm.growth_left == 8,
		"one monthly draw: eco/eq/growth each -1 (11/11/8 from 12/12/9)")
	_teardown(node)
	return ok


# --- criterion 3: lone_bane suppresses the internal grant -----------------------

func _test_lone_bane_external_only(ok: bool) -> bool:
	var node: Node = _setup("emei", ["lone_bane"], 7)
	ok = _expect(ok, node.gongfa_count == 1, "lone_bane -> external only (1 art)")
	ok = _expect(ok, _sm.profile.has_gongfa("emei_emeijian_d"), "external art granted")
	ok = _expect(ok, not _sm.profile.has_gongfa("emei_jiuyang_d"), "internal art NOT granted")
	ok = _expect(ok, _sm.profile.main_external_id == "emei_emeijian_d", "main_external_id set to emei_emeijian_d")
	_teardown(node)
	return ok


# --- criterion 4: practice -> mastery (丁4) -------------------------------------

func _test_practice_mastery(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 99)
	var first_id: String = node._first_unmastered_id()
	ok = _expect(ok, first_id == "shaolin_yijin_d", "first unmastered is the internal D art (grant order)")
	var entry: Dictionary = _sm.profile.get_gongfa(first_id)
	ok = _expect(ok, int(entry.get("practice", 0)) == 0, "fresh art practice == 0")
	node._add_practice(1)
	entry = _sm.profile.get_gongfa(first_id)
	ok = _expect(ok, int(entry.get("practice", 0)) == 1, "one practice -> practice 1")
	for i in range(3):
		node._add_practice(1)
	entry = _sm.profile.get_gongfa(first_id)
	ok = _expect(ok, bool(entry.get("mastered", false)) == true, "4 practices master the D art (丁4)")
	node._sync_surface()   # the real flow syncs after each action; mirror it here
	ok = _expect(ok, node.mastered_count == 1, "mastered_count == 1")
	ok = _expect(ok, not node._unmastered_ids().has(first_id), "mastered art removed from the unmastered pool")
	_teardown(node)
	return ok


# --- criterion 5: cultivate gain in 1..3, seed-deterministic --------------------

func _test_cultivate_determinism(ok: bool) -> bool:
	var run_a: Dictionary = _cultivate_once(12345)
	var run_b: Dictionary = _cultivate_once(12345)
	ok = _expect(ok, run_a["gain"] >= 1 and run_a["gain"] <= 3, "cultivate gain in 1..3 (got %d)" % run_a["gain"])
	ok = _expect(ok, run_a["before"] + run_a["gain"] == run_a["after"], "bone increased by exactly the gain")
	ok = _expect(ok, run_a["gain"] == run_b["gain"], "same seed -> identical gain (determinism)")
	return ok


# --- criterion 6: work +10 silver; silver card --------------------------------

func _test_work_and_silver_card(ok: bool) -> bool:
	_sm.new_profile({}, [])
	_sm.apply_seed(5)
	var node: Node = CULTIVATION_SCENE.instantiate()
	node._apply_action({"kind": "work"})
	ok = _expect(ok, _sm.profile.silver == 10, "work -> silver +10")
	node._apply_card({"effect_type": "silver", "effect_value": 50})
	ok = _expect(ok, _sm.profile.silver == 60, "silver card (+50) on top of 10 -> 60")
	node.free()
	return ok


# --- §8.5 conformance: gr_trait_pool grants an unowned positive trait ----------

func _test_trait_pool_card(ok: bool) -> bool:
	_sm.new_profile({}, [])
	_sm.apply_seed(11)
	var node: Node = CULTIVATION_SCENE.instantiate()
	var before: int = _sm.profile.traits.size()
	var def = CardDataScript.def("gr_trait_pool")
	node._apply_card({
		"id": def.id, "display_name": def.display_name, "category": def.category,
		"effect_type": def.effect_type, "effect_value": def.effect_value, "effect_target": def.effect_target,
	})
	ok = _expect(ok, _sm.profile.traits.size() == before + 1, "gr_trait_pool grants exactly one trait (no junk id)")
	if _sm.profile.traits.size() == before + 1:
		var gained: String = _sm.profile.traits[before]
		var gained_def = CardDataScript.def(gained)
		ok = _expect(ok, gained_def != null and gained_def.category == "trait",
			"granted id resolves to a real positive trait card: " + gained)
	node.free()
	return ok


# --- criterion 7: month 12 -> YEAR_END -> stay -> year 2 -----------------------

func _test_year_end_advance(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 123, 1, 12)
	node._apply_card(node._monthly_cards[0])
	node._apply_action({"kind": "work"})
	node._after_action()
	ok = _expect(ok, node.phase == "YEAR_END", "month 12 -> YEAR_END phase")
	node._resolve_year_end(0)
	ok = _expect(ok, node.year == 2 and node.month == 1, "stay -> year 2 month 1")
	ok = _expect(ok, node.gongfa_count == 4, "year 2 start grants the 丙 pair (4 arts total)")
	ok = _expect(ok, _sm.has_save == true, "year advance autosaves (has_save == true)")
	_teardown(node)
	return ok


# --- criterion 8: month 36 -> MAP ----------------------------------------------

func _test_month36_to_map(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 321, 3, 12)
	node._apply_card(node._monthly_cards[0])
	node._apply_action({"kind": "work"})
	node._after_action()
	ok = _expect(ok, _gm.current_state == "MAP", "month 36 -> GameManager state MAP")
	ok = _expect(ok, _sm.has_save == true, "final month autosaves before MAP")
	_teardown(node)
	return ok


# --- criterion 9: debug fast-forward completes in one synchronous call ---------

func _test_fast_forward(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 4242)
	ok = _expect(ok, node.phase == "CARD_PICK", "fast-forward starts from a staged month 1")
	node.fast_forward_used = true   # mirror _process: the flag is set before _fast_forward runs
	node._fast_forward()
	ok = _expect(ok, node.fast_forward_used == true, "fast_forward_used stays true")
	ok = _expect(ok, _gm.current_state == "MAP", "fast-forward completes: state MAP")
	ok = _expect(ok, node.year == 3 and node.month == 12, "fast-forward reached year 3 month 12")
	ok = _expect(ok, node.gongfa_count == 6, "3 years x 2 arts = 6 gongfa")
	ok = _expect(ok, _sm.has_save == true, "fast-forward autosaved along the way")
	_teardown(node)
	return ok


# --- criterion 10: save -> advance -> load -> delete roundtrip -----------------
#
# Note on the snapshot: every month advance autosaves (step2 §6,
# cultivation.gd::_after_action -> SaveManager.autosave), so the manual
# save_slot(1) at month 3 is clobbered by the advance's autosave before the
# load. load_slot restores the LATEST saved state — the roundtrip snapshots
# AFTER the advance (the month-4 autosave), then mutates the live profile so
# the reload must demonstrably come from disk, and finally verifies delete.

func _test_save_load_delete_roundtrip(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 777, 1, 3)
	ok = _expect(ok, _sm.save_slot(1), "save_slot(1) at year 1 month 3")
	# Advance one real month past the save point (this autosaves month 4).
	node._apply_card(node._monthly_cards[0])
	node._apply_action({"kind": "work"})
	node._after_action()
	ok = _expect(ok, node.month == 4, "month advanced to 4 after one month")
	# Snapshot AFTER the advance: the month-4 autosave is what load restores.
	var snapshot: Dictionary = {
		"year": _sm.profile.cultivation["year"],
		"month": _sm.profile.cultivation["month"],
		"bone": _sm.profile.get_attr("bone"),
		"silver": _sm.profile.silver,
	}
	ok = _expect(ok, int(snapshot["month"]) == 4, "advance autosaved the month-4 state")
	# Mutate the live profile so the reload must come from disk, not memory.
	_sm.profile.set_attr("bone", _sm.profile.get_attr("bone") + 50)
	_sm.profile.silver += 500
	ok = _expect(ok, _sm.load_slot(1), "load_slot(1) succeeds")
	ok = _expect(ok, int(_sm.profile.cultivation["year"]) == int(snapshot["year"]), "reloaded year == snapshot")
	ok = _expect(ok, int(_sm.profile.cultivation["month"]) == int(snapshot["month"]), "reloaded month == snapshot (latest autosave)")
	ok = _expect(ok, _sm.profile.get_attr("bone") == int(snapshot["bone"]), "reloaded bone == snapshot, not the mutated memory")
	ok = _expect(ok, _sm.profile.silver == int(snapshot["silver"]), "reloaded silver == snapshot, not the mutated memory")
	ok = _expect(ok, _sm.delete_slot(1), "delete_slot(1) removes the save")
	ok = _expect(ok, not FileAccess.file_exists("user://save_1.json"), "save_1.json gone after delete")
	_teardown(node)
	return ok


# --- risk edge: _add_practice no-ops with no unmastered gongfa -----------------

func _test_add_practice_no_unmastered_noop(ok: bool) -> bool:
	# No gongfa at all (no sect granted): must no-op without error.
	_sm.new_profile({}, [])
	_sm.apply_seed(3)
	var node: Node = CULTIVATION_SCENE.instantiate()
	ok = _expect(ok, _sm.profile.gongfa.is_empty(), "no gongfa without a sect")
	node._add_practice(1)
	ok = _expect(ok, _sm.profile.gongfa.is_empty(), "_add_practice no-ops with no unmastered gongfa")
	node.free()
	# All granted arts mastered: practice overflow must not create new entries.
	var node2: Node = _setup("shaolin", [], 4)
	for i in range(8):
		node2._add_practice(1)
	ok = _expect(ok, node2._unmastered_ids().is_empty(), "8 practices master both D arts -> no unmastered left")
	var count_before: int = _sm.profile.gongfa.size()
	node2._add_practice(1)
	ok = _expect(ok, _sm.profile.gongfa.size() == count_before, "overflow practice adds no new art and no error")
	_teardown(node2)
	return ok


# --- helpers ---------------------------------------------------------------------

## Fresh deterministic scenario: new profile (attrs/traits), sect / year / month
## set on the profile, RNG seeded BEFORE any draw, state forced to CULTIVATION.
## Returns the instantiated-and-added CultivationScreen (its _ready() already
## granted the year's arts and staged the month's cards).
func _setup(sect_id: String, traits: Array, seed_value: int, year: int = 1, month: int = 1) -> Node:
	_sm.new_profile({}, traits)
	_sm.profile.cultivation["sect_id"] = sect_id
	_sm.profile.cultivation["year"] = year
	_sm.profile.cultivation["month"] = month
	_sm.apply_seed(seed_value)
	_gm.current_state = "CULTIVATION"
	var inst: Node = CULTIVATION_SCENE.instantiate()
	root.add_child(inst)
	return inst


## One cultivate draw on a fresh seeded profile; returns before/gain/after.
## The node is NOT added to the tree, so no _ready / card draws run — the rng
## draw inside _apply_action is the first draw after reseeding, which is what
## makes two runs with the same seed byte-identical.
func _cultivate_once(seed_value: int) -> Dictionary:
	_sm.new_profile({}, [])
	_sm.apply_seed(seed_value)
	var node: Node = CULTIVATION_SCENE.instantiate()
	var before: int = _sm.profile.get_attr("bone")
	node._apply_action({"kind": "cultivate", "target": "bone"})
	var after: int = _sm.profile.get_attr("bone")
	node.free()
	return {"before": before, "gain": after - before, "after": after}


func _teardown(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_cultivation: " + msg)
	return false
