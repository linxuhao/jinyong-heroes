## Unit tests for the fortune reroll budget (design D2 / §「福缘」).
##   scripts/data/trait_effects.gd::fortune_reroll_budget
##
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## The budget formula (verbatim from the interface contract):
##   budget = 1 + maxi(0, (fortune - 10) / 10) + (1 if deep_fortune else 0)
## Integer division (GDScript `/` on ints truncates toward zero), so:
##   fortune 0/5  -> 1;  10 -> 1;  20 -> 2;  30 -> 3;  deep_fortune adds exactly 1.

const TraitEffects = preload("res://scripts/data/trait_effects.gd")


static func run() -> bool:
	var ok := true
	ok = _test_budget_curve(ok)
	ok = _test_deep_fortune(ok)
	if ok:
		print("PASS test_fortune_budget")
	else:
		print("FAIL test_fortune_budget")
	return ok


## The base curve (no deep_fortune): fortune 0/5 -> 1, 10 -> 1, 20 -> 2, 30 -> 3.
static func _test_budget_curve(ok: bool) -> bool:
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(0, false) == 1, "fortune 0 -> 1")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(5, false) == 1, "fortune 5 -> 1")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(10, false) == 1, "fortune 10 -> 1")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(20, false) == 2, "fortune 20 -> 2")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(30, false) == 3, "fortune 30 -> 3")
	# Below-floor fortune (0..9) still grants the base 1 (never negative).
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(3, false) == 1, "fortune 3 -> 1")
	# Boundary: fortune 19 -> (19-10)/10 = 0 -> 1; fortune 20 -> 1 -> 2.
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(19, false) == 1, "fortune 19 -> 1")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(20, false) == 2, "fortune 20 -> 2")
	return ok


## deep_fortune adds exactly 1 at every fortune tier.
static func _test_deep_fortune(ok: bool) -> bool:
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(10, true) == 2, "fortune 10 + deep -> 2")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(20, true) == 3, "fortune 20 + deep -> 3")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(30, true) == 4, "fortune 30 + deep -> 4")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(5, true) == 2, "fortune 5 + deep -> 2")
	ok = _expect(ok, TraitEffects.fortune_reroll_budget(0, true) == 2, "fortune 0 + deep -> 2")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_fortune_budget: " + msg)
	return false
