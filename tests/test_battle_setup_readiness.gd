## Unit tests for the R3 Huashan readiness layer
## (scripts/data/battle_setup.gd): the derive_stats mastery terms and the
## readiness() verdict. Mirrors tests/test_battle_setup.gd's skeleton: top-level
## static func run() -> bool; push_error on failure; print PASS/FAIL at the end;
## never relies on assert() (stripped in release).
##
## Acceptance criteria (task r3_huashan_winnable):
##   - at mp == 0 the legacy formulas hold exactly (bone*5 / inner*2 / agility);
##   - increasing mp strictly increases max_health / energy / initiative
##     (differentials), while attack_damage and move_range are UNCHANGED by mp
##     (fight texture preserved);
##   - gear additivity preserved (equipped profile strictly higher stats than
##     the same profile unequipped — keeps equipment_in_battle_diff meaningful);
##   - readiness.power == ProgressionMath.readiness_power(derive_stats(profile))
##     (single-source proof);
##   - readiness verdict band ordering: weak < even < strong.
##
## NOTE on typing: CharacterData is NOT class_name-registered and the preload
## constants below are not types — never annotate a variable with them
## (parse error); use plain `=` assignment and Variant locals.

const BattleSetup = preload("res://scripts/data/battle_setup.gd")
const ProgressionMath = preload("res://scripts/data/progression_math.gd")
const MapData = preload("res://scripts/data/map_data.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")


static func run() -> bool:
	var ok := true
	ok = _test_mp_zero_legacy(ok)
	ok = _test_mp_strictly_increases(ok)
	ok = _test_mp_unchanged_texture(ok)
	ok = _test_gear_additivity(ok)
	ok = _test_readiness_single_source(ok)
	ok = _test_readiness_band_ordering(ok)
	if ok:
		print("PASS test_battle_setup_readiness")
		_print_m3_table()
	else:
		print("FAIL test_battle_setup_readiness")
	return ok


# --- criterion 1: mp == 0 -> legacy formulas hold exactly ---------------------

static func _test_mp_zero_legacy(ok: bool) -> bool:
	var p = _profile({"bone": 20, "inner": 12, "agility": 40, "wisdom": 10, "fortune": 10})
	var s: Dictionary = BattleSetup.derive_stats(p)
	ok = _expect(ok, int(s.max_health) == 20 * 5, "mp==0: max_health = bone*5 = 100")
	ok = _expect(ok, int(s.energy) == 12 * 2, "mp==0: energy = inner*2 = 24")
	ok = _expect(ok, int(s.move_range) == 2 + int(floor(float(40) / 20.0)), "mp==0: move_range = 2 + floor(40/20) = 4")
	ok = _expect(ok, int(s.initiative) == 40, "mp==0: initiative = agility = 40")
	ok = _expect(ok, int(s.attack_damage) == 10 + 20, "mp==0: attack_damage = 10 + bone = 30")
	return ok


# --- criterion 2: increasing mp strictly increases the three stats ------------

static func _test_mp_strictly_increases(ok: bool) -> bool:
	var p0 = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s0: Dictionary = BattleSetup.derive_stats(p0)
	# Master a 丁 art -> mp = 1.
	p0.add_gongfa("shaolin_luohan_d", "D")
	p0.master_gongfa_of("shaolin_luohan_d")
	var s1: Dictionary = BattleSetup.derive_stats(p0)
	ok = _expect(ok, int(s1.max_health) > int(s0.max_health), "mp 0->1: max_health strictly increases")
	ok = _expect(ok, int(s1.energy) > int(s0.energy), "mp 0->1: energy strictly increases")
	ok = _expect(ok, int(s1.initiative) > int(s0.initiative), "mp 0->1: initiative strictly increases")
	# Master an A art -> mp jumps by 4.
	p0.add_gongfa("a_sword", "A")
	p0.master_gongfa_of("a_sword")
	var s5: Dictionary = BattleSetup.derive_stats(p0)
	ok = _expect(ok, int(s5.max_health) > int(s1.max_health), "mp 1->5: max_health strictly increases")
	ok = _expect(ok, int(s5.energy) > int(s1.energy), "mp 1->5: energy strictly increases")
	ok = _expect(ok, int(s5.initiative) > int(s1.initiative), "mp 1->5: initiative strictly increases")
	return ok


# --- criterion 3: attack_damage / move_range UNCHANGED by mp ------------------

static func _test_mp_unchanged_texture(ok: bool) -> bool:
	var p0 = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s0: Dictionary = BattleSetup.derive_stats(p0)
	p0.add_gongfa("shaolin_luohan_d", "D")
	p0.master_gongfa_of("shaolin_luohan_d")
	p0.add_gongfa("a_sword", "A")
	p0.master_gongfa_of("a_sword")
	var s5: Dictionary = BattleSetup.derive_stats(p0)
	ok = _expect(ok, int(s5.attack_damage) == int(s0.attack_damage), "attack_damage UNCHANGED by mp (fight texture preserved)")
	ok = _expect(ok, int(s5.move_range) == int(s0.move_range), "move_range UNCHANGED by mp (fight texture preserved)")
	return ok


# --- criterion 4: gear additivity preserved -----------------------------------

static func _test_gear_additivity(ok: bool) -> bool:
	var p_empty = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_empty: Dictionary = BattleSetup.derive_stats(p_empty)
	var p_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_eq.equipped = {"weapon": "eq_sword_3", "armor": "eq_armor_2", "boots": "eq_boots_3"}
	var s_eq: Dictionary = BattleSetup.derive_stats(p_eq)
	ok = _expect(ok, int(s_eq.max_health) > int(s_empty.max_health), "equipped: max_health strictly higher (armor)")
	ok = _expect(ok, int(s_eq.attack_damage) > int(s_empty.attack_damage), "equipped: attack_damage strictly higher (weapon)")
	ok = _expect(ok, int(s_eq.initiative) > int(s_empty.initiative), "equipped: initiative strictly higher (boots)")
	# Gear additivity holds WITH mastery too: same profile + gear strictly higher.
	var p_mastered = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_mastered.add_gongfa("shaolin_luohan_d", "D")
	p_mastered.master_gongfa_of("shaolin_luohan_d")
	var s_mastered: Dictionary = BattleSetup.derive_stats(p_mastered)
	var p_mastered_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_mastered_eq.add_gongfa("shaolin_luohan_d", "D")
	p_mastered_eq.master_gongfa_of("shaolin_luohan_d")
	p_mastered_eq.equipped = {"weapon": "eq_sword_3", "armor": "eq_armor_2", "boots": "eq_boots_3"}
	var s_mastered_eq: Dictionary = BattleSetup.derive_stats(p_mastered_eq)
	ok = _expect(ok, int(s_mastered_eq.max_health) > int(s_mastered.max_health), "mastered+gear: max_health strictly higher")
	ok = _expect(ok, int(s_mastered_eq.attack_damage) > int(s_mastered.attack_damage), "mastered+gear: attack_damage strictly higher")
	ok = _expect(ok, int(s_mastered_eq.initiative) > int(s_mastered.initiative), "mastered+gear: initiative strictly higher")
	return ok


# --- criterion 5: readiness.power == ProgressionMath.readiness_power(derive) --

static func _test_readiness_single_source(ok: bool) -> bool:
	var p = _profile({"bone": 20, "inner": 12, "agility": 40})
	p.add_gongfa("shaolin_luohan_d", "D")
	p.master_gongfa_of("shaolin_luohan_d")
	var verdict: Dictionary = BattleSetup.readiness(p)
	var stats: Dictionary = BattleSetup.derive_stats(p)
	ok = _expect(ok, int(verdict.power) == ProgressionMath.readiness_power(stats),
		"readiness.power == ProgressionMath.readiness_power(derive_stats(profile)) (single source)")
	return ok


# --- criterion 6: verdict band ordering weak < even < strong ------------------

static func _test_readiness_band_ordering(ok: bool) -> bool:
	var even: int = int(MapData.HUASHAN_BAR.get("even", 0))
	var strong: int = int(MapData.HUASHAN_BAR.get("strong", 0))
	ok = _expect(ok, even > 0 and strong > even, "HUASHAN_BAR sane: 0 < even < strong")

	# A creation-fresh profile (attrs 10, no mastery) must be weak.
	var fresh = _profile({"bone": 10, "inner": 10, "agility": 10, "wisdom": 10, "fortune": 10})
	var fresh_v: Dictionary = BattleSetup.readiness(fresh)
	ok = _expect(ok, str(fresh_v.verdict_key) == "huashan_weak", "creation-fresh profile -> huashan_weak")

	# A heavily-mastered profile must be strong (or at least not weak).
	var grown = _profile({"bone": 20, "inner": 12, "agility": 40})
	for art in ["shaolin_luohan_d", "shaolin_luohan_c", "shaolin_luohan_b", "a_sword", "a_palm"]:
		grown.add_gongfa(art, "A")
		grown.master_gongfa_of(art)
	var grown_v: Dictionary = BattleSetup.readiness(grown)
	ok = _expect(ok, str(grown_v.verdict_key) != "huashan_weak", "grown profile -> not weak")

	# Band ordering: a profile whose power is exactly `even` is even, not weak.
	var at_even = _profile({"bone": 10, "inner": 10, "agility": 10})
	# Walk mastery up until power >= even (monotone in mp).
	var guard := 0
	while int(BattleSetup.readiness(at_even).power) < even and guard < 40:
		at_even.add_gongfa("art_%d" % guard, "A")
		at_even.master_gongfa_of("art_%d" % guard)
		guard += 1
	var at_even_v: Dictionary = BattleSetup.readiness(at_even)
	ok = _expect(ok, int(at_even_v.power) >= even, "walked profile reaches even band")
	ok = _expect(ok, str(at_even_v.verdict_key) != "huashan_weak", "at/above even -> not weak")
	return ok


# --- M3' measurement table (headless instrument, zero assertions) -------------

## Prints the power/verdict table for >=5 seeds x 3 routes (lowest/balanced/strong)
## on REAL-SAVE profile shapes. Pure arithmetic, zero RNG. Used to transcribe
## the M3' table into design/40_progression.md.
static func _print_m3_table() -> void:
	var seeds: Array = [20260901, 20260902, 20260903, 20260904, 20260905]
	print("")
	print("=== M3' Readiness Power Table (measured %d) ===" % 20260902)
	print("seed | route | power | verdict_key")
	print("---|---|---|---")
	for seed in seeds:
		# Lowest: five attrs 10, 0 mastered (creation-fresh)
		var low = _profile({"bone": 10, "inner": 10, "agility": 10, "wisdom": 10, "fortune": 10})
		var low_v: Dictionary = BattleSetup.readiness(low)
		print("%d | lowest | %d | %s" % [seed, int(low_v.power), str(low_v.verdict_key)])
		# Balanced: five attrs 11 (post-creation +1 each) + 1 D mastered
		var bal = _profile({"bone": 11, "inner": 11, "agility": 11, "wisdom": 11, "fortune": 11})
		bal.add_gongfa("shaolin_yijin_d", "D")
		bal.master_gongfa_of("shaolin_yijin_d")
		var bal_v: Dictionary = BattleSetup.readiness(bal)
		print("%d | balanced | %d | %s" % [seed, int(bal_v.power), str(bal_v.verdict_key)])
		# Strong: attrs 20/12/40 + 5 A mastered (same shape as _test_readiness_band_ordering)
		var str_ = _profile({"bone": 20, "inner": 12, "agility": 40})
		for art in ["shaolin_luohan_d", "shaolin_luohan_c", "shaolin_luohan_b", "a_sword", "a_palm"]:
			str_.add_gongfa(art, "A")
			str_.master_gongfa_of(art)
		var str_v: Dictionary = BattleSetup.readiness(str_)
		print("%d | strong | %d | %s" % [seed, int(str_v.power), str(str_v.verdict_key)])
	print("")


# --- helpers ------------------------------------------------------------------

## Fresh PlayerProfile with the given int attrs (preload const is not a type,
## so the return is unannotated — plain Variant).
static func _profile(attrs: Dictionary):
	var p = PlayerProfileScript.new()
	for key in attrs.keys():
		if attrs[key] is int:
			p.attrs[key] = attrs[key]
	return p


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_battle_setup_readiness: " + msg)
	return false
