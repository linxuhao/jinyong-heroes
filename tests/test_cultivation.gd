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
const EventDataScript = preload("res://scripts/data/event_data.gd")

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
	ok = _test_event_seen_count_observable(ok)
	ok = _test_event_draw_exclusion(ok)
	ok = _test_event_pool_reset(ok)
	ok = _test_event_effects_fresh(ok)
	ok = _test_event_effects_adversary(ok)
	ok = _test_event_title_body_surface(ok)
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


# --- criterion 11: events_seen_count observable mirrors the sanitized bag -------

func _test_event_seen_count_observable(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 11)
	ok = _expect(ok, node.events_seen_count == 0, "fresh profile -> events_seen_count == 0")
	_sm.profile.flags["events_seen"] = ["bandits", "merchant", "ruins"]
	node._sync_surface()
	ok = _expect(ok, node.events_seen_count == 3, "3 sanitized seen ids -> events_seen_count == 3")
	# Hostile/stale ids still count — the observable mirrors the raw bag size, and
	# _draw_event's has() filter ignores anything not in TABLE.
	_sm.profile.flags["events_seen"] = ["bandits", "stale_garbage", "merchant", "", "ruins"]
	node._sync_surface()
	ok = _expect(ok, node.events_seen_count == 5, "hostile/stale/empty entries still counted (size 5)")
	_teardown(node)
	return ok


# --- criterion: event_title/event_body publish the raw zh of the displayed event --

func _test_event_title_body_surface(ok: bool) -> bool:
	var node: Node = _setup("shaolin", [], 11)
	node.event_id = "bandits"
	node._sync_surface()
	var d = EventDataScript.def("bandits")
	ok = _expect(ok, node.event_title == d.title, "event_title publishes the raw zh title of the current event")
	ok = _expect(ok, node.event_body == d.text, "event_body publishes the raw zh body of the current event")
	node.event_id = ""
	node._sync_surface()
	ok = _expect(ok, node.event_title == "", "event_title clears to \"\" when no event is displayed")
	ok = _expect(ok, node.event_body == "", "event_body clears to \"\" when no event is displayed")
	_teardown(node)
	return ok


# --- criterion 12: no-repeat bag — exclusion + forced draw ----------------------

func _test_event_draw_exclusion(ok: bool) -> bool:
	# events_seen holds 15 of the 16 TABLE ids -> the pool is exactly the one
	# missing id, so the single randi_range(0, 0) is forced regardless of seed.
	var all_ids: Array = _event_table_ids()
	ok = _expect(ok, all_ids.size() >= 16, "event pool has >= 16 rows for the forced-draw test")
	var missing: String = str(all_ids[0])
	var seen: Array = []
	for i in range(1, all_ids.size()):
		seen.append(all_ids[i])
	ok = _expect(ok, seen.size() == all_ids.size() - 1, "seen holds 15 of 16 ids")
	_sm.new_profile({}, [])
	_sm.profile.flags["events_seen"] = seen
	_sm.apply_seed(2024)
	var node: Node = CULTIVATION_SCENE.instantiate()
	var drawn: String = node._draw_event()
	ok = _expect(ok, drawn == missing,
		"15-of-16 exclusion: draw returns the only missing id (got %s, want %s)" % [drawn, missing])
	node.free()
	return ok


# --- criterion 13: pool-exhausted reset (never "", never a stall) ---------------

func _test_event_pool_reset(ok: bool) -> bool:
	# events_seen holds all 16 ids -> the pool is empty -> the reset branch
	# clears events_seen and refills from all 16, then draws. The draw must
	# return a non-empty id AND flags["events_seen"] must be empty immediately
	# after (the reset branch) — never "", never a stall.
	var all_ids: Array = _event_table_ids()
	_sm.new_profile({}, [])
	_sm.profile.flags["events_seen"] = all_ids.duplicate()
	_sm.apply_seed(7)
	var node: Node = CULTIVATION_SCENE.instantiate()
	var drawn: String = node._draw_event()
	ok = _expect(ok, drawn != "", "pool-exhausted reset returns a non-empty id")
	ok = _expect(ok, all_ids.has(drawn), "drawn id is one of the 16 table ids (got %s)" % drawn)
	var seen_after: Array = _sm.profile.flags.get("events_seen", [])
	ok = _expect(ok, seen_after.is_empty(),
		"reset clears events_seen immediately after the draw (size %d)" % seen_after.size())
	node.free()
	return ok


# --- criterion 14: effects really land — 16 defs x 2 options on a fresh stub ----

func _test_event_effects_fresh(ok: bool) -> bool:
	var case_no := 0
	for def in EventDataScript.all():
		for opt_idx in [0, 1]:
			case_no += 1
			# Fresh hermetic stub: silver 100 (so both cost and gain silver
			# effects move the field), one unmastered D gongfa (so a practice
			# effect has a real target).
			_sm.new_profile({}, [])
			_sm.profile.silver = 100
			_sm.profile.add_gongfa("shaolin_yijin_d", "D")
			_sm.apply_seed(1000 + case_no)
			var node: Node = CULTIVATION_SCENE.instantiate()
			node.event_id = def.id
			var before: Dictionary = _profile_snapshot()
			node._apply_event_option(opt_idx)
			var after: Dictionary = _profile_snapshot()
			var opt = def.option_a if opt_idx == 0 else def.option_b
			var expected: Dictionary = _expected_after(before, opt.effects)
			ok = _expect(ok, int(after["silver"]) == int(expected["silver"]),
				"silver %s/%s (%d -> %d, expected %d)" % [def.id, opt_idx, int(before["silver"]), int(after["silver"]), int(expected["silver"])])
			for key in PlayerProfile.ATTR_KEYS:
				ok = _expect(ok, int(after["attrs"][key]) == int(expected["attrs"][key]),
					"attr %s %s/%s (%d -> %d, expected %d)" % [key, def.id, opt_idx, int(before["attrs"][key]), int(after["attrs"][key]), int(expected["attrs"][key])])
			for target in expected["items"]:
				ok = _expect(ok, _sm.profile.inventory.has(target),
					"item %s granted %s/%s" % [target, def.id, opt_idx])
			for gid in expected["practice"].keys():
				ok = _expect(ok, int(after["practice"].get(gid, 0)) == int(expected["practice"][gid]),
					"practice %s %s/%s (%d -> %d, expected %d)" % [gid, def.id, opt_idx, int(before["practice"].get(gid, 0)), int(after["practice"].get(gid, 0)), int(expected["practice"][gid])])
			# Dead-content guard: at least one mutable field moved, unless the
			# option is an explicit `none` (merchant option_b — the only row
			# whose "no-op" is authored, not accidental).
			ok = _expect(ok, _any_field_moved(before, after) or _is_explicit_none(opt),
				"option lands or is explicit none %s/%s" % [def.id, opt_idx])
			node.free()
	return ok


# --- criterion 15: effects land even in the adversary (worst-case) state --------

func _test_event_effects_adversary(ok: bool) -> bool:
	# Adversary worst-case profile: silver == 0 (silver costs clamp -> no-op),
	# every equipment id already owned (item grants dedup -> no-op), and the only
	# gongfa mastered (practice -> no-op). A row is DEAD CONTENT unless at least
	# one of its two options still moves a field in this state.
	var equip_ids: Array = [
		"eq_sword_1", "eq_sword_2", "eq_sword_3", "eq_sword_4",
		"eq_armor_1", "eq_armor_2", "eq_armor_3", "eq_armor_4",
		"eq_boots_1", "eq_boots_2", "eq_boots_3", "eq_boots_4",
	]
	for def in EventDataScript.all():
		var a_moved: bool = _adversary_option_moves(def.id, 0, equip_ids)
		var b_moved: bool = _adversary_option_moves(def.id, 1, equip_ids)
		if def.id == "merchant":
			# WHITELIST (the single documented exception): merchant option_a pays
			# 20 silver (clamped to no-op at silver == 0) for eq_sword_3 (already
			# owned -> dedup no-op); option_b is an explicit "none". Both options
			# are genuinely inert in the adversary state, so merchant is exempted.
			# The four baseline rows are byte-identical; only this comment
			# whitelists merchant. Any OTHER row that goes dead here fails.
			ok = _expect(ok, not a_moved and not b_moved,
				"whitelist merchant is inert in adversary state (A=%s B=%s)" % [a_moved, b_moved])
			continue
		ok = _expect(ok, a_moved or b_moved,
			"adversary must-land row %s (A=%s B=%s)" % [def.id, a_moved, b_moved])
	return ok


# --- helpers ---------------------------------------------------------------------

## All TABLE ids, in table order.
func _event_table_ids() -> Array:
	var out: Array = []
	for def in EventDataScript.all():
		out.append(def.id)
	return out


## Snapshot the profile fields that event effects can move, plus which gongfa is
## currently the first unmastered (the practice effect's target).
func _profile_snapshot() -> Dictionary:
	var attrs := {}
	for key in PlayerProfile.ATTR_KEYS:
		attrs[key] = _sm.profile.get_attr(key)
	var practice := {}
	var first_unmastered := ""
	for entry in _sm.profile.gongfa:
		var id: String = str(entry.get("id", ""))
		practice[id] = int(entry.get("practice", 0))
		if first_unmastered == "" and not bool(entry.get("mastered", false)):
			first_unmastered = id
	return {
		"silver": _sm.profile.silver,
		"attrs": attrs,
		"items": _sm.profile.inventory.duplicate(),
		"practice": practice,
		"first_unmastered": first_unmastered,
	}


## The state _apply_event_option's match produces from a before-state and an
## effects array — mirrors cultivation.gd:_apply_event_option exactly (silver
## clamps at 0, item dedups, practice targets the first unmastered gongfa).
func _expected_after(before: Dictionary, effects: Array) -> Dictionary:
	var silver: int = int(before["silver"])
	var attrs: Dictionary = (before["attrs"] as Dictionary).duplicate()
	var items: Array = (before["items"] as Array).duplicate()
	var practice: Dictionary = (before["practice"] as Dictionary).duplicate()
	for eff in effects:
		var d: Dictionary = eff as Dictionary
		match d.get("type", "none"):
			"silver":
				silver = maxi(silver + int(d.get("value", 0)), 0)
			"attr":
				var key: String = str(d.get("target", ""))
				attrs[key] = int(attrs.get(key, 0)) + int(d.get("value", 0))
			"item":
				var target: String = str(d.get("target", ""))
				if target != "" and not items.has(target):
					items.append(target)
			"practice":
				var gid: String = str(before.get("first_unmastered", ""))
				if gid != "":
					practice[gid] = int(practice.get(gid, 0)) + int(d.get("value", 0))
	return {"silver": silver, "attrs": attrs, "items": items, "practice": practice}


## True if any of the tracked profile fields differ between two snapshots.
func _any_field_moved(before: Dictionary, after: Dictionary) -> bool:
	if int(after["silver"]) != int(before["silver"]):
		return true
	for key in PlayerProfile.ATTR_KEYS:
		if int(after["attrs"][key]) != int(before["attrs"][key]):
			return true
	if (after["items"] as Array).size() != (before["items"] as Array).size():
		return true
	for gid in after["practice"].keys():
		if int(after["practice"][gid]) != int(before["practice"].get(gid, 0)):
			return true
	return false


## True when an option is an explicit authored no-op (every effect type == "none").
func _is_explicit_none(opt) -> bool:
	if opt == null or opt.effects == null:
		return false
	var effs: Array = opt.effects
	if effs.is_empty():
		return false
	for eff in effs:
		if (eff as Dictionary).get("type", "") != "none":
			return false
	return true


## Apply one option against a fresh adversary profile; true if any field moved.
func _adversary_option_moves(event_id: String, opt_idx: int, equip_ids: Array) -> bool:
	_sm.new_profile({}, [])
	_sm.profile.silver = 0
	for eid in equip_ids:
		_sm.profile.inventory.append(eid)
	_sm.profile.add_gongfa("shaolin_yijin_d", "D")
	_sm.profile.master_gongfa_of("shaolin_yijin_d")
	_sm.apply_seed(99)
	var node: Node = CULTIVATION_SCENE.instantiate()
	node.event_id = event_id
	var before: Dictionary = _profile_snapshot()
	node._apply_event_option(opt_idx)
	var after: Dictionary = _profile_snapshot()
	node.free()
	return _any_field_moved(before, after)

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
