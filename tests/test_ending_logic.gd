## Unit tests for scripts/data/ending_logic.gd (EndingLogic multi-axis
## evaluation) + MapData.ending_tier_score.
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by the unit_test_runner registry. Pure headless,
## no scene, no RNG (the seeded stream's op order is a lifeline — this task
## adds zero RNG ops).

const EndingLogic = preload("res://scripts/data/ending_logic.gd")
const MapData = preload("res://scripts/data/map_data.gd")


static func run() -> bool:
	var ok := true
	ok = _test_shape(ok)
	ok = _test_legacy_empty_deeds(ok)
	ok = _test_divergence(ok)
	ok = _test_monotonicity(ok)
	ok = _test_tier_scan(ok)
	if ok:
		print("PASS test_ending_logic")
	else:
		print("FAIL test_ending_logic")
	return ok


# --- criterion 1: evaluate returns the exact contract shape -------------------

static func _test_shape(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	var ev: Dictionary = EndingLogic.evaluate(p, p.deeds)
	ok = _expect(ok, ev.has("score"), "evaluate has score")
	ok = _expect(ok, ev["score"] is int, "score is int")
	ok = _expect(ok, ev.has("tier"), "evaluate has tier")
	ok = _expect(ok, ev["tier"] is int, "tier is int")
	ok = _expect(ok, int(ev["tier"]) >= 1 and int(ev["tier"]) <= 3, "tier in 1..3")
	ok = _expect(ok, ev.has("axes"), "evaluate has axes")
	var axes: Dictionary = ev["axes"]
	ok = _expect(ok, axes.has("attrs") and axes.has("mastery") and axes.has("deeds"),
		"axes has attrs/mastery/deeds")
	ok = _expect(ok, axes["attrs"] is int, "axes.attrs is int")
	ok = _expect(ok, axes["mastery"] is int, "axes.mastery is int")
	ok = _expect(ok, axes["deeds"] is float, "axes.deeds is float")
	ok = _expect(ok, ev.has("summary_keys"), "evaluate has summary_keys")
	var keys: Array = ev["summary_keys"]
	ok = _expect(ok, keys is Array, "summary_keys is Array")
	ok = _expect(ok, keys.size() == 3, "summary_keys has 3 entries")
	# fresh default profile: attrs sum = 50, mastery 0, deeds 0 -> score 50
	ok = _expect(ok, int(axes["attrs"]) == 50, "fresh attrs sum == 50")
	ok = _expect(ok, int(ev["score"]) == 50, "fresh score == 50")
	return ok


# --- criterion 2: empty / legacy deeds evaluate without crashing --------------

static func _test_legacy_empty_deeds(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	var ev: Dictionary = EndingLogic.evaluate(p, {})
	ok = _expect(ok, float(ev["axes"]["deeds"]) == 0.0, "empty deeds -> deeds axis 0.0")
	ok = _expect(ok, int(ev["score"]) == 50, "empty deeds score == 50")
	# a legacy dict with only some deed keys (missing keys read 0)
	var partial: Dictionary = {"travel_resolved": 2}
	var ev2: Dictionary = EndingLogic.evaluate(p, partial)
	ok = _expect(ok, float(ev2["axes"]["deeds"]) > 0.0, "partial deeds -> deeds axis > 0")
	return ok


# --- criterion 3: divergence — two profiles differing only in deeds/mastery ---

static func _test_divergence(ok: bool) -> bool:
	# Same attrs, same gongfa; differ only in deeds.
	var p1: PlayerProfile = PlayerProfile.new_default()
	var p2: PlayerProfile = PlayerProfile.new_default()
	var ev1: Dictionary = EndingLogic.evaluate(p1, p1.deeds)
	var ev2: Dictionary = EndingLogic.evaluate(p2, {"work_months": 12, "silver_earned": 300, "travel_resolved": 4})
	ok = _expect(ok, int(ev1["score"]) != int(ev2["score"]), "deeds-only difference changes score")
	# Same attrs, same deeds; differ only in mastery (mastered arts).
	var p3: PlayerProfile = PlayerProfile.new_default()
	p3.add_gongfa("a1", "D")
	p3.master_gongfa_of("a1")
	var ev3: Dictionary = EndingLogic.evaluate(p3, p3.deeds)
	ok = _expect(ok, int(ev3["score"]) != int(ev1["score"]), "mastery-only difference changes score")
	ok = _expect(ok, int(ev3["axes"]["mastery"]) == 1, "mastered D -> mastery 1")
	return ok


# --- criterion 4: score is monotone non-decreasing in each axis ---------------

static func _test_monotonicity(ok: bool) -> bool:
	var base: PlayerProfile = PlayerProfile.new_default()
	var base_ev: Dictionary = EndingLogic.evaluate(base, base.deeds)
	# attrs up
	var p_attr: PlayerProfile = PlayerProfile.new_default()
	p_attr.set_attr("bone", 20)
	var ev_attr: Dictionary = EndingLogic.evaluate(p_attr, p_attr.deeds)
	ok = _expect(ok, int(ev_attr["score"]) >= int(base_ev["score"]), "attrs up -> score non-decreasing")
	# mastery up
	var p_mast: PlayerProfile = PlayerProfile.new_default()
	p_mast.add_gongfa("b1", "A")
	p_mast.master_gongfa_of("b1")
	var ev_mast: Dictionary = EndingLogic.evaluate(p_mast, p_mast.deeds)
	ok = _expect(ok, int(ev_mast["score"]) >= int(base_ev["score"]), "mastery up -> score non-decreasing")
	# deeds up
	var ev_deeds: Dictionary = EndingLogic.evaluate(base, {"travel_resolved": 5, "silver_earned": 100})
	ok = _expect(ok, int(ev_deeds["score"]) >= int(base_ev["score"]), "deeds up -> score non-decreasing")
	return ok


# --- criterion 5: ending_tier_score scan respects row order, floor 1 ----------

static func _test_tier_scan(ok: bool) -> bool:
	ok = _expect(ok, MapData.ending_tier_score(0) == 1, "ending_tier_score(0) == 1")
	ok = _expect(ok, MapData.ending_tier_score(-5) == 1, "ending_tier_score(-5) == 1")
	# row order: a high score hits the highest tier whose min_score it reaches
	var t3: int = MapData.ending_tier_score(999)
	ok = _expect(ok, t3 == 3, "huge score -> tier 3")
	# monotone: score strictly above a tier's min_score never drops below it
	var prev: int = 1
	for s in range(0, 200, 7):
		var cur: int = MapData.ending_tier_score(s)
		ok = _expect(ok, cur >= prev, "ending_tier_score non-decreasing at " + str(s))
		prev = cur
	# ending_tier (the old attrs-only fn) is REMOVED — no dead dual path.
		var src := FileAccess.get_file_as_string("res://scripts/data/map_data.gd")
		ok = _expect(ok, src.contains("func ending_tier_score(") and not src.contains("func ending_tier("), "ending_tier removed (no dead dual path)")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_ending_logic: " + msg)
	return false
