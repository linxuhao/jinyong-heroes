class_name EndingLogic

## Pure-static multi-axis ending evaluation (R3 D1). The ONLY tier-scoring path
## in the repo — ending.gd renders it, the playtest nails assert on it, and the
## unit suite exercises it headlessly. No autoloads, no scene tree, zero RNG.
##
## score = round(attrs*K_ATTR + mastery*K_MASTERY + ProgressionMath.deed_score(deeds))
## tier  = MapData.ending_tier_score(score)
##
## SINGLE-SOURCE RULE: the axis math (mastery_points / deed_score) lives in
## ProgressionMath; this file only weights and sums. Tuning the constants below
## (K_ATTR / K_MASTERY) is the M2 measurement's job — never re-derive the axis
## math inline, so the ending evaluator and the battle-stat extension can never
## drift apart.

## Attribute-axis weight (PROVISIONAL until M2 — r3_ending_logic tunes this
## const after measuring the 36-month yield curves; never the formula).
const K_ATTR := 1.0
## Mastery-axis weight (PROVISIONAL until M2).
const K_MASTERY := 2.0

## Evaluate a profile + its persisted deeds into the ending record.
## Returns {"score": int, "tier": int, "axes": {"attrs": int, "mastery": int,
## "deeds": float}, "summary_keys": Array[String]}.
## Empty / legacy deeds (missing keys) read as 0 via ProgressionMath.deed_score
## — never a crash, never a lie.
static func evaluate(profile: PlayerProfile, deeds: Dictionary) -> Dictionary:
	var attrs: int = 0
	for key in PlayerProfile.ATTR_KEYS:
		attrs += profile.get_attr(key)
	var mastery: int = ProgressionMath.mastery_points(profile)
	var deed_score: float = ProgressionMath.deed_score(deeds)
	var score: int = int(round(attrs * K_ATTR + mastery * K_MASTERY + deed_score))
	var tier: int = MapData.ending_tier_score(score)
	return {
		"score": score,
		"tier": tier,
		"axes": {"attrs": attrs, "mastery": mastery, "deeds": deed_score},
		"summary_keys": ["attrs", "mastery", "deeds"],
	}
