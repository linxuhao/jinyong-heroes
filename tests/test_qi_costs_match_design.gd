## Unit tests pinning the inner-qi cost data (jinyong-spend-qi).
##
## Contract: plain GDScript (no extends), top-level `static func run() -> bool`;
## push_error on failure; print PASS/FAIL at the end. Collected into run_tests.sh
## via unit_test_runner.gd's TESTS registry (append-only).
##
## This file is the single greppable pin for the 8 player-move costs defined in
## design/20_content.md §7.1 (the source of truth). The playtest scenario
## qi_cost_blocks_cast_no_energy.yaml asserts the MECHANIC only (cost-agnostic);
## if a future round retunes costs, exactly this file reddens. It also pins the
## SkillData.insufficient_energy / SkillData.spend truth tables so the executor
## gate and the HUD no_energy predicate stay consistent.

const BattlefieldScript: GDScript = preload("res://scripts/battlefield.gd")
const SkillData: GDScript = preload("res://scripts/data/skill_data.gd")

## The 8 player moves and their inner-qi costs (design/20_content.md §7.1).
const DESIGN_COSTS: Dictionary = {
	"heavy_edge": 0,                  # 重剑无锋 — free basic strike (never fully disarmed)
	"grand_simplicity": 15,           # 大巧不工
	"thousand_force_cleave": 20,      # 力斩千钧
	"boundless_seas": 25,             # 四海无量 (绝招)
	"heart_rending_strike": 10,       # 心惊肉跳 (cheapest single, cd 1)
	"dragging_mire": 15,              # 拖泥带水
	"wandering_valley": 20,           # 徘徊空谷
	"seventeen_melancholy_forms": 30, # 黯然销魂十七式 (ultimate 绝招, most expensive)
}


static func run() -> bool:
	var ok := true

	# Instantiate battlefield.gd OFF-TREE: _ready() never runs, so no scene nodes
	# are touched; _create_all_skill_data() is pure data.
	var bf = BattlefieldScript.new()
	var skills: Dictionary = bf._create_all_skill_data()

	# --- (a) All 8 design costs pinned exactly (incl. heavy_edge == 0) ---
	for id: String in DESIGN_COSTS:
		if not skills.has(id):
			ok = _expect(ok, false, "missing skill id in dict: %s" % id)
			continue
		var sk = skills[id]
		var expected: int = int(DESIGN_COSTS[id])
		ok = _expect(ok, int(sk.cost) == expected,
				"%s.cost == %d (got %d)" % [id, expected, int(sk.cost)])

	# --- (b) EVERY other skill id must be cost 0 (protects enemy/progression
	#         techniques — a new non-zero key reddens this file) ---
	for id: String in skills:
		if DESIGN_COSTS.has(id):
			continue
		ok = _expect(ok, int(skills[id].cost) == 0,
				"non-player skill %s must be cost 0 (got %d)" % [id, int(skills[id].cost)])

	# --- (c) SkillData.insufficient_energy truth table ---
	ok = _expect(ok, SkillData.insufficient_energy(0, 0) == false, "insufficient_energy(0,0) == false")
	ok = _expect(ok, SkillData.insufficient_energy(0, 180) == false, "insufficient_energy(0,180) == false")
	ok = _expect(ok, SkillData.insufficient_energy(15, 15) == false, "insufficient_energy(15,15) == false (energy == cost castable)")
	ok = _expect(ok, SkillData.insufficient_energy(15, 14) == true, "insufficient_energy(15,14) == true")
	ok = _expect(ok, SkillData.insufficient_energy(30, 0) == true, "insufficient_energy(30,0) == true")

	# --- (d) SkillData.spend truth table ---
	ok = _expect(ok, SkillData.spend(180, 15) == 165, "spend(180,15) == 165")
	ok = _expect(ok, SkillData.spend(10, 30) == 0, "spend(10,30) == 0 (clamp at 0)")
	ok = _expect(ok, SkillData.spend(50, -5) == 50, "spend(50,-5) == 50 (negative cost reads as 0)")

	if ok:
		print("PASS: test_qi_costs_match_design")
	else:
		print("FAIL: test_qi_costs_match_design")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_qi_costs_match_design: " + what)
	return ok_so_far and cond
