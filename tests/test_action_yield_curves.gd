## M1 measurement instrument — per-action yield curves (R3, 2026-09-01).
##
## Drives the REAL action math (ProgressionMath / EventLogic / TraitEffects /
## PlayerProfile) over 36 seeded months for 5 single-action strategies
## (all-work / all-practice / all-cultivate / all-travel) + 1 balanced, and
## PRINTS a yield table (silver earned, practice points, attr points, events
## resolved per strategy). Asserts only STRUCTURAL facts — all outputs finite
## and non-negative; a mastered-heavy run's per-month work income exceeds a
## fresh run's; travel resolves <= 36 events — never balance literals.
##
## Contract: top-level static func run() -> bool; push_error on failure; print
## PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by the unit_test_runner registry. Pure headless,
## no scene. Uses its OWN seeded RandomNumberGenerator (NOT SaveManager.rng) so
## it never touches the game's deterministic stream — the seeded op-order
## lifeline (save_load_roundtrip / event_travel_effects) is untouched.
##
## The printed table is transcribed into design/40_progression.md §3 with the
## run label "measured 2026-09-01, R3 M1, seeded run".

const TraitEffects = preload("res://scripts/data/trait_effects.gd")
const PRACTICE_ACTION_GAIN: int = 2  # mirrors cultivation.gd's PROVISIONAL const
const SECT_ID: String = "shaolin"
const MONTHS: int = 36


static func run() -> bool:
	var ok := true
	var table: Array[Dictionary] = []
	for strategy in _strategy_names():
		var res: Dictionary = _run_strategy(strategy)
		table.append(res)
		ok = _assert_structural(ok, res)
	# Cross-strategy structural facts.
	ok = _assert_cross_strategy(ok, table)
	_print_table(table)
	if ok:
		print("PASS test_action_yield_curves")
	else:
		print("FAIL test_action_yield_curves")
	return ok


static func _strategy_names() -> Array[String]:
	return ["all_work", "all_practice", "all_cultivate", "all_travel", "balanced"]


## Run one strategy over 36 seeded months and return its yield record.
static func _run_strategy(strategy: String) -> Dictionary:
	var profile: PlayerProfile = PlayerProfile.new_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260901
	var practice_points: int = 0
	var attr_points: int = 0
	# Deterministic deck order via the seeded rng (same seed across strategies,
	# so the card contribution is a constant, not a confound).
	var card_deck: Array[String] = _seeded_shuffle(CardData.initial_deck("growth"), rng)
	var deck_pos: int = 0
	for month in range(MONTHS):
		_grant_year_arts(profile, month)
		# Monthly free card (one growth card per month, same seed across
		# strategies so the card contribution is a constant, not a confound).
		if deck_pos >= card_deck.size():
			card_deck = _seeded_shuffle(CardData.initial_deck("growth"), rng)
			deck_pos = 0
		_apply_card(profile, card_deck[deck_pos], rng)
		deck_pos += 1
		# The strategy's monthly action.
		match strategy:
			"all_work":
				var gain: int = ProgressionMath.work_income(ProgressionMath.mastered_count(profile))
				profile.silver += gain
				profile.deeds["work_months"] = profile.get_deed("work_months") + 1
				profile.deeds["silver_earned"] = profile.get_deed("silver_earned") + gain
			"all_practice":
				EventLogic.add_practice(profile, PRACTICE_ACTION_GAIN)
				practice_points += PRACTICE_ACTION_GAIN
				profile.deeds["practice_months"] = profile.get_deed("practice_months") + 1
			"all_cultivate":
				var roll: float = rng.randf()
				var g: int = TraitEffects.practice_gain(profile.get_attr("wisdom"), roll)
				profile.add_attr("bone", g)
				attr_points += g
				profile.deeds["cultivate_months"] = profile.get_deed("cultivate_months") + 1
			"all_travel":
				_resolve_travel(profile, rng)
			"balanced":
				match month % 4:
					0:
						var gain2: int = ProgressionMath.work_income(ProgressionMath.mastered_count(profile))
						profile.silver += gain2
						profile.deeds["work_months"] = profile.get_deed("work_months") + 1
						profile.deeds["silver_earned"] = profile.get_deed("silver_earned") + gain2
					1:
						EventLogic.add_practice(profile, PRACTICE_ACTION_GAIN)
						practice_points += PRACTICE_ACTION_GAIN
						profile.deeds["practice_months"] = profile.get_deed("practice_months") + 1
					2:
						var roll2: float = rng.randf()
						var g2: int = TraitEffects.practice_gain(profile.get_attr("wisdom"), roll2)
						profile.add_attr("bone", g2)
						attr_points += g2
						profile.deeds["cultivate_months"] = profile.get_deed("cultivate_months") + 1
					3:
						_resolve_travel(profile, rng)
	return {
		"strategy": strategy,
		"silver_earned": profile.get_deed("silver_earned"),
		"practice_points": practice_points,
		"attr_points": attr_points,
		"events_resolved": profile.get_deed("travel_resolved"),
		"mastered_count": ProgressionMath.mastered_count(profile),
		"work_income_final": ProgressionMath.work_income(ProgressionMath.mastered_count(profile)),
		"ending_score": int(EndingLogic.evaluate(profile, profile.deeds)["score"]),
		"ending_tier": int(EndingLogic.evaluate(profile, profile.deeds)["tier"]),
	}


## Grant the sect's arts for the current year (mirrors _grant_year_arts):
## year 1 -> D, year 2 -> C, year 3 -> B. month is 0-based.
static func _grant_year_arts(profile: PlayerProfile, month: int) -> void:
	var year: int = (month / 12) + 1
	var grade: String = ProgressionGongfaData.GRADE_BY_YEAR[clampi(year - 1, 0, 2)]
	var internal: String = ProgressionGongfaData.art_id(SECT_ID, "internal", grade)
	if internal != "":
		profile.add_gongfa(internal, grade)
	var external: String = ProgressionGongfaData.art_id(SECT_ID, "external", grade)
	if external != "":
		profile.add_gongfa(external, grade)


## Resolve one travel event: draw (one rng op), resolve option_a, mark seen.
static func _resolve_travel(profile: PlayerProfile, rng: RandomNumberGenerator) -> void:
	var eid: String = EventLogic.draw_unseen_id(profile, rng)
	var def = EventData.def(eid)
	if def != null:
		var opt = def.option_a
		var res: Dictionary = EventLogic.apply_option_effects(profile, opt)
		if res["ok"]:
			profile.deeds["travel_resolved"] = profile.get_deed("travel_resolved") + 1
	var seen: Array = profile.flags.get("events_seen", [])
	if eid != "" and not seen.has(eid):
		seen.append(eid)


## Apply one card's effect (mirrors cultivation._apply_card's effect math).
## Trait / shen_gong / tech_unlock cards are skipped (they do not feed the
## measured action yields and would add unneeded RNG).
static func _apply_card(profile: PlayerProfile, id: String, rng: RandomNumberGenerator) -> void:
	var card = CardData.def(id)
	if card == null:
		return
	match card.effect_type:
		"silver":
			var before: int = profile.silver
			profile.silver = maxi(profile.silver + card.effect_value, 0)
			profile.deeds["silver_earned"] = profile.get_deed("silver_earned") + maxi(profile.silver - before, 0)
		"attr":
			profile.add_attr(card.effect_target, card.effect_value)
		"item":
			if card.effect_target != "" and not profile.inventory.has(card.effect_target):
				profile.inventory.append(card.effect_target)
		"practice":
			EventLogic.add_practice(profile, card.effect_value)
		_:
			pass  # trait / shen_gong / tech_unlock / none — not action-yield-relevant


## Deterministic Fisher-Yates shuffle driven by the seeded rng (so the deck
## order is reproducible for a given seed).
static func _seeded_shuffle(items: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Structural per-strategy facts: all outputs finite and non-negative.
static func _assert_structural(ok: bool, res: Dictionary) -> bool:
	var silver: int = res["silver_earned"]
	var practice: int = res["practice_points"]
	var attr: int = res["attr_points"]
	var events: int = res["events_resolved"]
	var mastered: int = res["mastered_count"]
	var work_income: int = res["work_income_final"]
	ok = _expect(ok, silver >= 0, res["strategy"] + " silver_earned >= 0")
	ok = _expect(ok, practice >= 0, res["strategy"] + " practice_points >= 0")
	ok = _expect(ok, attr >= 0, res["strategy"] + " attr_points >= 0")
	ok = _expect(ok, events >= 0, res["strategy"] + " events_resolved >= 0")
	ok = _expect(ok, mastered >= 0, res["strategy"] + " mastered_count >= 0")
	ok = _expect(ok, work_income >= 10, res["strategy"] + " work_income_final >= 10")
	# travel resolves at most one event per month (36 months max).
	ok = _expect(ok, events <= MONTHS, res["strategy"] + " events_resolved <= 36")
	return ok


## Cross-strategy structural facts.
static func _assert_cross_strategy(ok: bool, table: Array[Dictionary]) -> bool:
	var practice_run: Dictionary = {}
	var work_run: Dictionary = {}
	for res in table:
		if res["strategy"] == "all_practice":
			practice_run = res
		elif res["strategy"] == "all_work":
			work_run = res
	# A mastered-heavy run (all-practice masters arts) has strictly higher
	# per-month work income than a fresh run (all-work masters none).
	ok = _expect(ok, int(practice_run["mastered_count"]) > 0, "all_practice masters at least one art")
	ok = _expect(ok, int(work_run["mastered_count"]) == 0, "all_work masters no arts")
	ok = _expect(ok, int(practice_run["work_income_final"]) > int(work_run["work_income_final"]),
		"mastered-heavy work income > fresh work income")
	return ok


static func _print_table(table: Array[Dictionary]) -> void:
	print("=== R3 M1 ACTION YIELD CURVES (measured 2026-09-01, seeded run) ===")
	print("strategy | silver_earned | practice_points | attr_points | events_resolved | mastered | work_income_final | ending_score | ending_tier")
	for res in table:
		print("%s | %d | %d | %d | %d | %d | %d | %d | %d" % [
			res["strategy"], res["silver_earned"], res["practice_points"],
			res["attr_points"], res["events_resolved"], res["mastered_count"],
			res["work_income_final"], res["ending_score"], res["ending_tier"],
		])


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_action_yield_curves: " + msg)
	return false
