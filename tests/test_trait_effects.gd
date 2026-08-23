## Unit tests for the pure static helpers landed this round:
##   scripts/data/trait_effects.gd       — 修习 lookup table, 破/狼/杀 formulas
##   scripts/data/tutorial_fillers.gd    — mastered filler arts to fixpoint 1.3
##   scripts/data/encounter_data.gd      — sparring partner CharacterData
##
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## NOTE on typing: the helpers are preload constants, not class_name globals.
## Instances are declared with plain `=` and inferred locals get an EXPLICIT
## type (e.g. `var got: float = ...`, `var internal_before: int = ...`) —
## access through a Variant-typed instance returns Variant, so `:=` cannot
## infer it (parse error).

const TraitEffects = preload("res://scripts/data/trait_effects.gd")
const TutorialFillers = preload("res://scripts/data/tutorial_fillers.gd")
const EncounterData = preload("res://scripts/data/encounter_data.gd")
const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const CharacterData = preload("res://scripts/data/character_data.gd")


static func run() -> bool:
	var ok := true
	ok = _test_practice_gain_boundaries(ok)
	ok = _test_practice_gain_tier_switches(ok)
	ok = _test_practice_gain_sums(ok)
	ok = _test_pojun_practice(ok)
	ok = _test_lang(ok)
	ok = _test_sha(ok)
	ok = _test_tutorial_fillers(ok)
	ok = _test_encounter_data(ok)
	if ok:
		print("PASS test_trait_effects")
	else:
		print("FAIL test_trait_effects")
	return ok


# --- 1. practice_gain: tier thresholds and boundaries ------------------------

static func _test_practice_gain_boundaries(ok: bool) -> bool:
	# ≤15 tier: 60/30/10 — thresholds 0.60 / 0.90
	ok = _expect(ok, TraitEffects.practice_gain(10, 0.59) == 1, "w10 roll0.59 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(10, 0.60) == 2, "w10 roll0.60 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(10, 0.89) == 2, "w10 roll0.89 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(10, 0.90) == 3, "w10 roll0.90 -> +3")
	# 16–25 tier: 35/45/20 — thresholds 0.35 / 0.80
	ok = _expect(ok, TraitEffects.practice_gain(16, 0.34) == 1, "w16 roll0.34 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(16, 0.35) == 2, "w16 roll0.35 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(16, 0.79) == 2, "w16 roll0.79 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(16, 0.80) == 3, "w16 roll0.80 -> +3")
	# 26–35 tier: 20/50/30 — thresholds 0.20 / 0.70
	ok = _expect(ok, TraitEffects.practice_gain(26, 0.19) == 1, "w26 roll0.19 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(26, 0.20) == 2, "w26 roll0.20 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(26, 0.69) == 2, "w26 roll0.69 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(26, 0.70) == 3, "w26 roll0.70 -> +3")
	# ≥36 tier: 10/45/45 — thresholds 0.10 / 0.55
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.09) == 1, "w36 roll0.09 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.10) == 2, "w36 roll0.10 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.54) == 2, "w36 roll0.54 -> +2")
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.55) == 3, "w36 roll0.55 -> +3")
	# Far-end rolls within each tier.
	ok = _expect(ok, TraitEffects.practice_gain(10, 0.999) == 3, "w10 roll0.999 -> +3")
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.999) == 3, "w36 roll0.999 -> +3")
	ok = _expect(ok, TraitEffects.practice_gain(10, 0.0) == 1, "w10 roll0.0 -> +1")
	return ok


# --- 2. practice_gain: wisdom tier switches ----------------------------------

static func _test_practice_gain_tier_switches(ok: bool) -> bool:
	# wisdom 15 uses the ≤15 tier; 16 and 25 use 16–25; 26 and 35 use 26–35;
	# 36 uses ≥36. Probe with the roll just above each tier's +1 threshold.
	ok = _expect(ok, TraitEffects.practice_gain(15, 0.60) == 2, "w15 roll0.60 -> +2 (≤15 tier)")
	ok = _expect(ok, TraitEffects.practice_gain(16, 0.35) == 2, "w16 roll0.35 -> +2 (16-25 tier)")
	ok = _expect(ok, TraitEffects.practice_gain(25, 0.35) == 2, "w25 roll0.35 -> +2 (16-25 tier)")
	ok = _expect(ok, TraitEffects.practice_gain(26, 0.20) == 2, "w26 roll0.20 -> +2 (26-35 tier)")
	ok = _expect(ok, TraitEffects.practice_gain(35, 0.20) == 2, "w35 roll0.20 -> +2 (26-35 tier)")
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.10) == 2, "w36 roll0.10 -> +2 (≥36 tier)")
	# Below the +1 threshold of the tier the wisdom actually belongs to.
	ok = _expect(ok, TraitEffects.practice_gain(15, 0.34) == 1, "w15 roll0.34 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(25, 0.34) == 1, "w25 roll0.34 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(35, 0.19) == 1, "w35 roll0.19 -> +1")
	ok = _expect(ok, TraitEffects.practice_gain(36, 0.09) == 1, "w36 roll0.09 -> +1")
	return ok


# --- 3. practice_gain: exact expected sums over 1000 rolls --------------------

static func _test_practice_gain_sums(ok: bool) -> bool:
	var sums: Dictionary = {
		"w10": _sum_practice_gain(10),
		"w16": _sum_practice_gain(16),
		"w26": _sum_practice_gain(26),
		"w36": _sum_practice_gain(36),
	}
	ok = _expect(ok, sums["w10"] == 1500, "w10 sum over 1000 rolls == 1500")
	ok = _expect(ok, sums["w16"] == 1850, "w16 sum over 1000 rolls == 1850")
	ok = _expect(ok, sums["w26"] == 2100, "w26 sum over 1000 rolls == 2100")
	ok = _expect(ok, sums["w36"] == 2350, "w36 sum over 1000 rolls == 2350")
	return ok


static func _sum_practice_gain(wisdom: int) -> int:
	var total: int = 0
	for i in range(1000):
		total += TraitEffects.practice_gain(wisdom, float(i) / 1000.0)
	return total


# --- 4. pojun_practice --------------------------------------------------------

static func _test_pojun_practice(ok: bool) -> bool:
	ok = _expect(ok, TraitEffects.pojun_practice(0) == 0, "pojun 0 -> 0")
	ok = _expect(ok, TraitEffects.pojun_practice(1) == 2, "pojun 1 -> 2")
	ok = _expect(ok, TraitEffects.pojun_practice(2) == 3, "pojun 2 -> 3")
	ok = _expect(ok, TraitEffects.pojun_practice(3) == 5, "pojun 3 -> 5 (round 4.5)")
	ok = _expect(ok, TraitEffects.pojun_practice(4) == 6, "pojun 4 -> 6")
	ok = _expect(ok, TraitEffects.pojun_practice(6) == 9, "pojun 6 -> 9")
	return ok


# --- 5. lang_attack_mult / lang_dr --------------------------------------------

static func _test_lang(ok: bool) -> bool:
	ok = _expect(ok, is_equal_approx(TraitEffects.lang_attack_mult(0), 1.0), "lang mult N=0 -> 1.0")
	ok = _expect(ok, is_equal_approx(TraitEffects.lang_attack_mult(1), 1.08), "lang mult N=1 -> 1.08")
	ok = _expect(ok, is_equal_approx(TraitEffects.lang_attack_mult(3), 1.24), "lang mult N=3 -> 1.24")
	ok = _expect(ok, is_equal_approx(TraitEffects.lang_dr(0), 0.0), "lang dr N=0 -> 0.0")
	ok = _expect(ok, is_equal_approx(TraitEffects.lang_dr(1), 0.05), "lang dr N=1 -> 0.05")
	ok = _expect(ok, is_equal_approx(TraitEffects.lang_dr(3), 0.15), "lang dr N=3 -> 0.15")
	return ok


# --- 6. sha_heal_amount -------------------------------------------------------

static func _test_sha(ok: bool) -> bool:
	# round(28*0.2)=6 ≤ cap round(50*0.15)=8 -> 6
	ok = _expect(ok, TraitEffects.sha_heal_amount(28, 50, 0) == 6, "sha loss28 hp50 -> 6 (under cap)")
	# round(60*0.2)=12 > cap 8 -> capped at 8
	ok = _expect(ok, TraitEffects.sha_heal_amount(60, 50, 0) == 8, "sha loss60 hp50 -> capped 8")
	# budget 8-5=3, min(12, 3) -> 3
	ok = _expect(ok, TraitEffects.sha_heal_amount(60, 50, 5) == 3, "sha loss60 hp50 healed5 -> 3 (partial)")
	# zero loss -> 0
	ok = _expect(ok, TraitEffects.sha_heal_amount(0, 50, 0) == 0, "sha zero loss -> 0")
	# budget exhausted -> 0 (never negative)
	ok = _expect(ok, TraitEffects.sha_heal_amount(60, 50, 8) == 0, "sha budget exhausted -> 0")
	# round(3*0.15)=round(0.45)=0 budget -> 0
	ok = _expect(ok, TraitEffects.sha_heal_amount(60, 3, 0) == 0, "sha round(0.45)=0 budget -> 0")
	return ok


# --- 7. TutorialFillers.fill: fixpoint 1.3 via the real cascade ---------------

static func _test_tutorial_fillers(ok: bool) -> bool:
	var unit = CharacterData.new()
	# Yang Guo tutorial shape: internal A 阳 + external A sword 刚 + external A palm 阴.
	unit.internal_arts = [_art("A", "internal", "yang", "internal")]
	unit.external_arts = [
		_art("A", "sword", "hard", "external"),
		_art("A", "palm", "yin", "external"),
	]
	var internal_before: int = unit.internal_arts.size()
	var external_before: int = unit.external_arts.size()
	TutorialFillers.fill(unit)
	# Every art (originals + fillers) computes exactly 1.3 via the real cascade.
	var arts: Array = unit.internal_arts + unit.external_arts
	for art in arts:
		var got: float = art.get_fa_hui_du(unit)
		ok = _expect(ok, got == 1.3, "every art computes 1.3 (got " + str(got) + ")")
	# Originals mastered.
	ok = _expect(ok, unit.internal_arts[0].mastered == true, "original internal mastered")
	ok = _expect(ok, unit.external_arts[0].mastered == true, "original external sword mastered")
	ok = _expect(ok, unit.external_arts[1].mastered == true, "original external palm mastered")
	# Fillers appended: A art needs B/C/D same-school slots each (3 internal + 6 external).
	ok = _expect(ok, unit.internal_arts.size() == internal_before + 3, "3 internal fillers appended")
	ok = _expect(ok, unit.external_arts.size() == external_before + 6, "6 external fillers appended")
	# Every art mastered; fillers keep empty techniques.
	for art in arts:
		ok = _expect(ok, art.mastered == true, "every art mastered")
		ok = _expect(ok, art.techniques.size() == 0, "every art keeps empty techniques")
	# Internal fillers are internal-kind; the school is the literal "internal".
	var int_ok := true
	for art in unit.internal_arts:
		if str(art.kind) != "internal":
			int_ok = false
	ok = _expect(ok, int_ok, "all internal_arts are internal-kind")
	# staged_values untouched.
	ok = _expect(ok, unit.staged_values == false, "staged_values stays false")
	# Fixpoint: a second fill appends nothing.
	TutorialFillers.fill(unit)
	var internal_after: int = unit.internal_arts.size()
	var external_after: int = unit.external_arts.size()
	ok = _expect(ok, internal_after == internal_before + 3, "fixpoint: no internal appends on 2nd fill")
	ok = _expect(ok, external_after == external_before + 6, "fixpoint: no external appends on 2nd fill")
	return ok


# --- 8. EncounterData.sparring_partner ----------------------------------------

static func _test_encounter_data(ok: bool) -> bool:
	var p1 = EncounterData.sparring_partner()
	var p2 = EncounterData.sparring_partner()
	ok = _expect(ok, p1 != p2, "two calls return distinct instances")
	ok = _expect(ok, p1.character_name == "Sparring Partner", "character_name")
	ok = _expect(ok, p1.display_name == "陪练弟子", "display_name")
	ok = _expect(ok, p1.max_health == 60, "max_health 60")
	ok = _expect(ok, p1.attack_damage == 12, "attack_damage 12")
	ok = _expect(ok, p1.move_range == 2, "move_range 2")
	ok = _expect(ok, p1.initiative == 3, "initiative 3")
	ok = _expect(ok, p1.attack_range == 1, "attack_range 1")
	ok = _expect(ok, p1.team == 1, "team 1")
	ok = _expect(ok, p1.ai_class == "AIControllerSparring", "ai_class")
	ok = _expect(ok, p1.skills.size() == 0, "skills empty")
	ok = _expect(ok, p1.passive_id == "", "passive_id empty")
	ok = _expect(ok, p1.internal_arts.size() == 1, "internal_arts.size() == 1")
	ok = _expect(ok, p1.external_arts.size() == 3, "external_arts.size() == 3")
	var arts: Array = p1.internal_arts + p1.external_arts
	for art in arts:
		ok = _expect(ok, str(art.grade) == "D", "art grade D")
		ok = _expect(ok, str(art.attribute) == "yang", "art attribute yang")
		ok = _expect(ok, art.mastered == true, "art mastered")
	# Each of the four arts computes 1.0 + 0.1×3 = 1.3 through the real cascade.
	for art in arts:
		var got: float = art.get_fa_hui_du(p1)
		ok = _expect(ok, got == 1.3, "sparring art fhd 1.3 (got " + str(got) + ")")
	ok = _expect(ok, EncounterData.sparring_partner_tile() == Vector2i(7, 4), "tile Vector2i(7,4)")
	return ok


# --- helpers ------------------------------------------------------------------

## Build a GongfaData resource with explicit fields. Returned as Resource so
## the static helpers stay type-safe without a class_name.
static func _art(grade: String, school: String, attribute: String, kind: String) -> Resource:
	var g = GongfaData.new()
	g.grade = grade
	g.school = school
	g.attribute = attribute
	g.kind = kind
	g.mastered = false
	g.techniques = []
	g.gongfa_name = "Test " + grade + " " + school
	return g


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_trait_effects: " + msg)
	return false
