## Unit tests for scripts/data/trait_data.gd (TraitData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by a later subtask; this file only delivers the
## script plus the assertion contract from task_plan.md acceptance criterion 1.

const POSITIVE_ROWS := [
	{"id": "ambidextrous", "display_name": "左右互搏", "cost": 10, "hooks": ["skill_bar_3_arts"]},
	{"id": "self_taught", "display_name": "无师自通", "cost": 10, "hooks": ["bypass_prereq_learn"]},
	{"id": "gifted_bones", "display_name": "骨骼清奇", "cost": 8, "hooks": ["dual_main_internal"]},
	{"id": "photographic_memory", "display_name": "过目不忘", "cost": 8, "hooks": ["self_learn_watched"]},
	{"id": "iron_shirt", "display_name": "铁布衫", "cost": 7, "hooks": ["fatal_guard_once"]},
	{"id": "swallow_lightness", "display_name": "身轻如燕", "cost": 6, "hooks": ["pass_through_enemies"]},
	{"id": "worldly_experience", "display_name": "江湖阅历", "cost": 6, "hooks": ["map_inquire"]},
	{"id": "deep_fortune", "display_name": "福缘深厚", "cost": 5, "hooks": ["yearly_event_reroll"]},
]

const FLAW_ROWS := [
	{"id": "sha_po_lang", "display_name": "杀破狼", "cost": -6, "hooks": ["solo_only"]},
	{"id": "old_wound", "display_name": "旧伤", "cost": -8, "hooks": ["no_finishers"]},
	{"id": "inner_demon", "display_name": "心魔", "cost": -8, "hooks": ["hp30_chaos"]},
	{"id": "lone_bane", "display_name": "孤煞", "cost": -6, "hooks": ["no_internal_from_sect"]},
	{"id": "dull_sinews", "display_name": "筋骨迟钝", "cost": -5, "hooks": ["no_lightfoot_school"]},
]


static func run() -> bool:
	var ok := true

	# all() -> 13 rows, ids unique
	var all_defs: Array = TraitData.all()
	ok = _expect(ok, all_defs.size() == 13, "all() has 13 rows")
	var seen := {}
	for def in all_defs:
		ok = _expect(ok, not seen.has(def.id), "duplicate id in all(): " + str(def.id))
		seen[def.id] = true

	# per-id data: get_def non-null, display_name non-empty & verbatim, cost verbatim (incl. negatives), hooks verbatim
	for row in POSITIVE_ROWS:
		ok = _check_row(ok, row)
	for row in FLAW_ROWS:
		ok = _check_row(ok, row)

	# unknown id -> null
	ok = _expect(ok, TraitData.get_def("nope") == null, "get_def unknown -> null")

	# cost_of matches table; unknown -> 0
	for row in POSITIVE_ROWS:
		ok = _expect(ok, TraitData.cost_of(row["id"]) == row["cost"], "cost_of " + str(row["id"]))
	for row in FLAW_ROWS:
		ok = _expect(ok, TraitData.cost_of(row["id"]) == row["cost"], "cost_of " + str(row["id"]))
	ok = _expect(ok, TraitData.cost_of("nope") == 0, "cost_of unknown -> 0")

	# is_flaw: all 5 flaws true, all 8 positives false, unknown false
	for row in FLAW_ROWS:
		ok = _expect(ok, TraitData.is_flaw(row["id"]), "is_flaw " + str(row["id"]))
	for row in POSITIVE_ROWS:
		ok = _expect(ok, not TraitData.is_flaw(row["id"]), "not is_flaw " + str(row["id"]))
	ok = _expect(ok, not TraitData.is_flaw("nope"), "is_flaw unknown -> false")

	# positive_ids: exactly the 8 positives, in table order
	var positive: Array = TraitData.positive_ids()
	var expected_pos := []
	for row in POSITIVE_ROWS:
		expected_pos.append(row["id"])
	ok = _expect(ok, positive.size() == 8, "positive_ids has exactly 8 entries")
	ok = _expect(ok, positive == expected_pos, "positive_ids in table order")

	# fresh instances: mutating one all() result must not pollute later calls
	var a: Array = TraitData.all()
	a[0].hooks.append("mutated")
	a[0].id = "mutated"
	a[1].cost = 999
	var b: Array = TraitData.all()
	ok = _expect(ok, b[0].hooks == ["skill_bar_3_arts"], "all() instances fresh (hooks)")
	ok = _expect(ok, b[0].id == "ambidextrous", "all() instances fresh (id)")
	ok = _expect(ok, b[1].cost == 10, "all() instances fresh (cost)")

	if ok:
		print("PASS test_trait_data")
	else:
		print("FAIL test_trait_data")
	return ok


static func _check_row(ok: bool, row: Dictionary) -> bool:
	var id: String = row["id"] as String
	var def = TraitData.get_def(id)
	ok = _expect(ok, def != null, "get_def exists for " + id)
	if def == null:
		return ok
	ok = _expect(ok, def.display_name == row["display_name"], "display_name " + id)
	ok = _expect(ok, (def.display_name as String) != "", "display_name non-empty " + id)
	ok = _expect(ok, def.cost == row["cost"], "cost " + id + " matches table")
	ok = _expect(ok, def.hooks == row["hooks"], "hooks " + id + " match table")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_trait_data: " + msg)
	return false
