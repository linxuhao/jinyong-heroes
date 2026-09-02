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
	# M2' 5-seed sweep (C3): every strategy runs on 5 deterministic seeds so the
	# ending-tier separation is measured across the RNG spread, not one draw.
	var seeds: Array[int] = [20260901, 20260902, 20260903, 20260904, 20260905]
	for seed in seeds:
		for strategy in _strategy_names():
			var res: Dictionary = _run_strategy(strategy, seed)
			table.append(res)
			ok = _assert_structural(ok, res)
	# Cross-strategy structural facts.
	ok = _assert_cross_strategy(ok, table)
	# M2' tier-separation structural pins (C3): the lowest legal routes land in
	# tier 1, a focused route in tier 2, a strong/balanced route in tier 3 —
	# read from MapData.ENDING_TIERS at runtime, never hard-coded.
	ok = _assert_tier_separation(ok, table)
	_print_table(table)
	if ok:
		print("PASS test_action_yield_curves")
	else:
		print("FAIL test_action_yield_curves")
	return ok


static func _strategy_names() -> Array[String]:
	return ["do_nothing", "idle_real", "all_work", "all_practice", "all_cultivate", "all_travel", "balanced"]


## Run one strategy over 36 seeded months and return its yield record.
static func _run_strategy(strategy: String, seed: int) -> Dictionary:
	var profile: PlayerProfile = PlayerProfile.new_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var practice_points: int = 0
	var attr_points: int = 0
	# Deterministic deck order via the seeded rng (same seed across strategies,
	# so the card contribution is a constant, not a confound).
	var card_deck: Array[String] = _seeded_shuffle(CardData.initial_deck("growth"), rng)
	var deck_pos: int = 0
	for month in range(MONTHS):
		# do_nothing is the EMPTY profile (0 sects, 0 arts) — the only legal
		# zero-yield route. Every other strategy is a real-save profile that
		# receives the sect's year grants (year 1 D, year 2 C, year 3 B).
		if strategy != "do_nothing":
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
			"do_nothing":
				pass  # pure monthly card, no action (empty-profile do-nothing)
			"idle_real":
				pass  # real-save prefix granted once, then card only, no action
			"all_work":
				var gain: int = ProgressionMath.work_income(profile.get_deed("work_months"))
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
						var gain2: int = ProgressionMath.work_income(profile.get_deed("work_months"))
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
		"seed": seed,
		"silver_earned": profile.get_deed("silver_earned"),
		"practice_points": practice_points,
		"attr_points": attr_points,
		"events_resolved": profile.get_deed("travel_resolved"),
		"mastered_count": ProgressionMath.mastered_count(profile),
		"work_months": profile.get_deed("work_months"),
		"work_income_final": ProgressionMath.work_income(profile.get_deed("work_months")),
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
## C3 M2' deed lever: FREE-CARD silver is NOT counted toward the 历练 (deeds)
## axis — mirrors the live cultivation.gd _apply_card change (the card's silver
## still enters profile.silver; only the deed bookkeeping stops counting it).
static func _apply_card(profile: PlayerProfile, id: String, rng: RandomNumberGenerator) -> void:
	var card = CardData.def(id)
	if card == null:
		return
	match card.effect_type:
		"silver":
			profile.silver = maxi(profile.silver + card.effect_value, 0)
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
	# The work curve is months-driven (C7): a late-work run (all_work, 36 work
	# months) has strictly higher per-month work income than an early-work run
	# (all_practice, 0 work months) — the curve steepens with months worked.
	ok = _expect(ok, int(work_run["work_months"]) > 0, "all_work accumulates work months")
	ok = _expect(ok, int(practice_run["work_months"]) == 0, "all_practice does no work")
	ok = _expect(ok, int(work_run["work_income_final"]) > int(practice_run["work_income_final"]),
		"late-work work income > early-work work income")
	return ok


## M2' tier-separation structural pins (C3). Reads the ENDING_TIERS thresholds
## from MapData at runtime (never hard-coded): the lowest legal routes
## (do_nothing / idle_real) must land strictly below the tier-2 min_score, the
## balanced route must reach the tier-3 min_score, the three routes must land on
## three DISTINCT tiers, and the three ENDING_TIERS titles must be pairwise
## distinct — across all 5 seeds. This is the deterministic consumer of the
## tier/title data (the in-session scenario renders two endings for the
## differential; the three-distinct-titles proof is carried here because a
## third full boot within the frame cap is not reliable).
static func _assert_tier_separation(ok: bool, table: Array[Dictionary]) -> bool:
	var tier2_min: int = 0
	var tier3_min: int = 0
	var titles: Array[String] = []
	for row in MapData.ENDING_TIERS:
		if int(row["tier"]) == 2:
			tier2_min = int(row["min_score"])
		elif int(row["tier"]) == 3:
			tier3_min = int(row["min_score"])
		titles.append(str(row["title"]))
	# Three distinct titles (C3): the three ENDING_TIERS rows are pairwise distinct.
	ok = _expect(ok, titles.size() == 3, "ENDING_TIERS has exactly 3 rows")
	ok = _expect(ok, titles[0] != titles[1] and titles[1] != titles[2] and titles[0] != titles[2],
		"three ENDING_TIERS titles pairwise distinct")
	# do_nothing / idle_real average score strictly below the tier-2 threshold.
	var do_nothing_scores: Array[int] = []
	var idle_real_scores: Array[int] = []
	var balanced_scores: Array[int] = []
	for res in table:
		if res["strategy"] == "do_nothing":
			do_nothing_scores.append(int(res["ending_score"]))
		elif res["strategy"] == "idle_real":
			idle_real_scores.append(int(res["ending_score"]))
		elif res["strategy"] == "balanced":
			balanced_scores.append(int(res["ending_score"]))
	var do_nothing_avg: float = _avg(do_nothing_scores)
	var idle_real_avg: float = _avg(idle_real_scores)
	var balanced_avg: float = _avg(balanced_scores)
	ok = _expect(ok, do_nothing_avg < float(tier2_min),
		"do_nothing avg score %.1f < tier-2 min_score %d" % [do_nothing_avg, tier2_min])
	ok = _expect(ok, idle_real_avg < float(tier2_min),
		"idle_real avg score %.1f < tier-2 min_score %d" % [idle_real_avg, tier2_min])
	ok = _expect(ok, balanced_avg >= float(tier3_min),
		"balanced avg score %.1f >= tier-3 min_score %d" % [balanced_avg, tier3_min])
	# The three routes land on three DISTINCT tiers (do_nothing tier 1, a
	# focused route tier 2, balanced tier 3) — the tier differential, not text.
	var do_nothing_tiers: Array[int] = []
	var practice_tiers: Array[int] = []
	for res in table:
		if res["strategy"] == "do_nothing":
			do_nothing_tiers.append(int(res["ending_tier"]))
		elif res["strategy"] == "all_practice":
			practice_tiers.append(int(res["ending_tier"]))
	ok = _expect(ok, _all_same(do_nothing_tiers) and int(do_nothing_tiers[0]) == 1,
		"do_nothing lands tier 1 on every seed")
	ok = _expect(ok, _all_same(practice_tiers) and int(practice_tiers[0]) == 2,
		"all_practice lands tier 2 on every seed")
	return ok


static func _all_same(values: Array[int]) -> bool:
	if values.is_empty():
		return false
	var first: int = values[0]
	for v in values:
		if v != first:
			return false
	return true


static func _avg(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for v in values:
		total += v
	return float(total) / float(values.size())


static func _print_table(table: Array[Dictionary]) -> void:
	print("=== R3 M1/M2' ACTION YIELD CURVES (measured 2026-09-02, seeded run) ===")
	print("strategy | seed | silver_earned | practice_points | attr_points | events_resolved | mastered | work_income_final | ending_score | ending_tier")
	for res in table:
		print("%s | %d | %d | %d | %d | %d | %d | %d | %d | %d" % [
			res["strategy"], res["seed"], res["silver_earned"], res["practice_points"],
			res["attr_points"], res["events_resolved"], res["mastered_count"],
			res["work_income_final"], res["ending_score"], res["ending_tier"],
		])


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_action_yield_curves: " + msg)
	return false
