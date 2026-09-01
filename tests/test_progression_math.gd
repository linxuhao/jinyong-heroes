## Unit tests for the pure-static R3 progression math module:
##   scripts/data/progression_math.gd  — GRADE_POINTS + mastered_count /
##     mastery_points / work_income / deed_score / readiness_power
##
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by the unit_test_runner registry. Pure headless,
## no scene, no RNG (the seeded stream's op order is a lifeline — this task
## adds zero RNG ops).
##
## NOTE on typing: ProgressionMath is a class_name global, so the static funcs
## are called directly on the class. Every local that receives a Variant-typed
## expression (dict .get(), array element, etc.) is declared with an EXPLICIT
## type — `:=` cannot infer a Variant (parse error). The PROVISIONAL consts
## (DEED_TRAVEL_WEIGHT / DEED_SILVER_WEIGHT / the work-income slope) are tuned
## LATER by consumer tasks, so this test asserts only monotonicity / differential
## facts, never the specific provisional numbers.

const GRADE_KEYS: Array[String] = ["丁", "丙", "乙", "甲"]


static func run() -> bool:
	var ok := true
	ok = _test_grade_points(ok)
	ok = _test_mastered_count(ok)
	ok = _test_mastery_points(ok)
	ok = _test_work_income(ok)
	ok = _test_deed_score(ok)
	ok = _test_readiness_power(ok)
	if ok:
		print("PASS test_progression_math")
	else:
		print("FAIL test_progression_math")
	return ok


# --- criterion 1: GRADE_POINTS covers exactly the four grades -----------------

static func _test_grade_points(ok: bool) -> bool:
	ok = _expect(ok, ProgressionMath.GRADE_POINTS.size() == 4, "GRADE_POINTS.size() == 4")
	for key in GRADE_KEYS:
		ok = _expect(ok, ProgressionMath.GRADE_POINTS.has(key), "GRADE_POINTS has " + key)
	ok = _expect(ok, int(ProgressionMath.GRADE_POINTS["丁"]) == 1, "丁 == 1")
	ok = _expect(ok, int(ProgressionMath.GRADE_POINTS["丙"]) == 2, "丙 == 2")
	ok = _expect(ok, int(ProgressionMath.GRADE_POINTS["乙"]) == 3, "乙 == 3")
	ok = _expect(ok, int(ProgressionMath.GRADE_POINTS["甲"]) == 4, "甲 == 4")
	for key in ProgressionMath.GRADE_POINTS.keys():
		ok = _expect(ok, GRADE_KEYS.has(str(key)), "no unknown grade key " + str(key))
	return ok


# --- criterion 2: mastered_count counts only mastered rows ---------------------

static func _test_mastered_count(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	ok = _expect(ok, ProgressionMath.mastered_count(p) == 0, "empty profile mastered_count == 0")
	p.add_gongfa("a1", "丁")
	p.add_gongfa("a2", "丙")
	p.add_gongfa("a3", "乙")
	ok = _expect(ok, ProgressionMath.mastered_count(p) == 0, "all-unmastered mastered_count == 0")
	p.master_gongfa_of("a1")
	p.master_gongfa_of("a3")
	ok = _expect(ok, ProgressionMath.mastered_count(p) == 2, "two mastered -> 2")
	return ok


# --- criterion 3: mastery_points sums GRADE_POINTS over mastered rows only -----

static func _test_mastery_points(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	ok = _expect(ok, ProgressionMath.mastery_points(p) == 0, "empty profile mastery_points == 0")
	# 丁 mastered, 丙 unmastered, 乙 mastered, 甲 unmastered -> 1 + 3 = 4
	p.add_gongfa("a1", "丁")
	p.add_gongfa("a2", "丙")
	p.add_gongfa("a3", "乙")
	p.add_gongfa("a4", "甲")
	p.master_gongfa_of("a1")
	p.master_gongfa_of("a3")
	ok = _expect(ok, ProgressionMath.mastery_points(p) == 4, "丁+乙 mastered -> 4")
	# all-unmastered -> 0
	var p2: PlayerProfile = PlayerProfile.new_default()
	p2.add_gongfa("b1", "甲")
	ok = _expect(ok, ProgressionMath.mastery_points(p2) == 0, "unmastered 甲 -> 0")
	# unknown grade string contributes 0 even when mastered
	var p3: PlayerProfile = PlayerProfile.new_default()
	p3.add_gongfa("c1", "ZZ")
	p3.master_gongfa_of("c1")
	ok = _expect(ok, ProgressionMath.mastery_points(p3) == 0, "unknown grade mastered -> 0")
	# a row with a missing `mastered` key reads as unmastered (0)
	var p4: PlayerProfile = PlayerProfile.new_default()
	p4.gongfa.append({"id": "d1", "grade": "甲", "practice": 0})
	ok = _expect(ok, ProgressionMath.mastery_points(p4) == 0, "missing mastered key -> 0")
	return ok


# --- criterion 4: work_income floor, strict growth, monotonicity --------------

static func _test_work_income(ok: bool) -> bool:
	ok = _expect(ok, ProgressionMath.work_income(0) == 10, "work_income(0) == 10")
	# strictly greater than 10 for every mastered >= 1
	for m in range(1, 11):
		ok = _expect(ok, ProgressionMath.work_income(m) > 10, "work_income(" + str(m) + ") > 10")
	# non-decreasing across 0..10
	var prev: int = ProgressionMath.work_income(0)
	for m in range(1, 11):
		var cur: int = ProgressionMath.work_income(m)
		ok = _expect(ok, cur >= prev, "work_income non-decreasing at " + str(m))
		prev = cur
	# negative input clamps to 0 (total function)
	ok = _expect(ok, ProgressionMath.work_income(-5) == 10, "work_income(-5) == 10")
	return ok


# --- criterion 5: deed_score monotone in both inputs, tolerant of empty dict --

static func _test_deed_score(ok: bool) -> bool:
	ok = _expect(ok, ProgressionMath.deed_score({}) == 0.0, "deed_score({}) == 0.0")
	# strictly increasing in travel_resolved (silver_earned held fixed)
	var base: float = ProgressionMath.deed_score({"travel_resolved": 1, "silver_earned": 10})
	var more_travel: float = ProgressionMath.deed_score({"travel_resolved": 2, "silver_earned": 10})
	ok = _expect(ok, more_travel > base, "deed_score increases with travel_resolved")
	# strictly increasing in silver_earned (travel_resolved held fixed)
	var more_silver: float = ProgressionMath.deed_score({"travel_resolved": 1, "silver_earned": 20})
	ok = _expect(ok, more_silver > base, "deed_score increases with silver_earned")
	# missing keys read as 0 without raising
	ok = _expect(ok, ProgressionMath.deed_score({"travel_resolved": 3}) > 0.0, "missing silver_earned reads 0")
	ok = _expect(ok, ProgressionMath.deed_score({"silver_earned": 50}) > 0.0, "missing travel_resolved reads 0")
	return ok


# --- criterion 6: readiness_power strictly increases on any single +1 ---------

static func _test_readiness_power(ok: bool) -> bool:
	var base_hp: int = ProgressionMath.readiness_power({"max_health": 14, "attack_damage": 10, "initiative": 20})
	var hp_up: int = ProgressionMath.readiness_power({"max_health": 15, "attack_damage": 10, "initiative": 20})
	ok = _expect(ok, hp_up > base_hp, "readiness_power increases with max_health (floor 14->2, 15->3)")
	var base_atk: int = ProgressionMath.readiness_power({"max_health": 100, "attack_damage": 10, "initiative": 20})
	var atk_up: int = ProgressionMath.readiness_power({"max_health": 100, "attack_damage": 11, "initiative": 20})
	ok = _expect(ok, atk_up > base_atk, "readiness_power increases with attack_damage")
	var base_ini: int = ProgressionMath.readiness_power({"max_health": 100, "attack_damage": 10, "initiative": 20})
	var ini_up: int = ProgressionMath.readiness_power({"max_health": 100, "attack_damage": 10, "initiative": 22})
	ok = _expect(ok, ini_up > base_ini, "readiness_power increases with initiative (floor 20/2=10, 22/2=11)")
	# floor division sanity: max_health 14 -> 2, 15 -> 3
	ok = _expect(ok, ProgressionMath.readiness_power({"max_health": 14, "attack_damage": 0, "initiative": 0}) == 2, "floor 14/5 == 2")
	ok = _expect(ok, ProgressionMath.readiness_power({"max_health": 15, "attack_damage": 0, "initiative": 0}) == 3, "floor 15/5 == 3")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_progression_math: " + msg)
	return false
