class_name ProgressionMath

## Pure static math helpers for the R3 progression rebalance (step2_design
## D1/D3/D4). Deterministic helpers only — no RNG, no autoload references, no
## scene tree. profile / stats / deeds are passed as args, so every function
## runs headless from any caller (unit tests, the ending evaluator, the battle
## stat extension).
##
## SINGLE-SOURCE RULE: r3_action_rebalance (work_income), r3_ending_logic
## (deed_score, mastery_points) and r3_huashan_winnable (readiness_power) call
## these functions and tune the named PROVISIONAL consts after their
## measurements — they never re-derive the math inline, so the ending evaluator
## and the battle-stat extension can never drift apart.

## Grade → mastery points (design/10_systems.md §3: 丁=1 丙=2 乙=3 甲=4).
const GRADE_POINTS := {"丁": 1, "丙": 2, "乙": 3, "甲": 4}

## Deed-score weights (PROVISIONAL — r3_ending_logic (M2) tunes THESE consts
## after measuring the 36-month yield curves; never the formula).
const DEED_TRAVEL_WEIGHT := 2.0
const DEED_SILVER_WEIGHT := 0.05

## Number of gongfa rows whose `mastered` is true.
static func mastered_count(profile: PlayerProfile) -> int:
	var count := 0
	for row in profile.gongfa:
		if row.get("mastered", false) == true:
			count += 1
	return count

## Sum of GRADE_POINTS over MASTERED rows only. Unmastered rows and rows with an
## unknown grade string contribute 0 (a row with a missing `mastered` key reads
## as unmastered, mirroring the deed_score missing-key convention).
static func mastery_points(profile: PlayerProfile) -> int:
	var total := 0
	for row in profile.gongfa:
		if row.get("mastered", false) != true:
			continue
		var grade: String = str(row.get("grade", ""))
		total += int(GRADE_POINTS.get(grade, 0))
	return total

## Work income: 10 + 2 * mastered_count (PROVISIONAL R3 D3). Monotone
## non-decreasing; strictly > 10 once mastered >= 1. Total over all ints
## (negative input clamps to 0 via maxi).
static func work_income(mastered: int) -> int:
	return 10 + 2 * maxi(mastered, 0)

## Deed score: travel_resolved and silver_earned weighted (PROVISIONAL
## weights). Missing keys read as 0 without raising.
static func deed_score(deeds: Dictionary) -> float:
	var travel: float = float(deeds.get("travel_resolved", 0))
	var silver: float = float(deeds.get("silver_earned", 0))
	return DEED_TRAVEL_WEIGHT * travel + DEED_SILVER_WEIGHT * silver

## Readiness power composite (PROVISIONAL R3 D4). Band thresholds live in
## MapData.HUASHAN_BAR, NEVER here. Floor division on each term (cast each
## Variant value explicitly — GDScript `/` over Variant has no guaranteed
## floor semantics).
static func readiness_power(stats: Dictionary) -> int:
	var hp: int = int(floor(float(stats.get("max_health", 0)) / 5.0))
	var atk: int = int(floor(float(stats.get("attack_damage", 0))))
	var ini: int = int(floor(float(stats.get("initiative", 0)) / 2.0))
	return hp + atk + ini
