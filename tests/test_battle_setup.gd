## Unit tests for the progression-side battle setup
## (scripts/data/battle_setup.gd): the §7 stat-derivation formulas and the
## CharacterData build (staged_values == false, mastered propagation, generic
## grade techniques). Mirrors tests/test_gongfa_cascade.gd's skeleton:
## top-level static func run() -> bool; push_error on failure; print
## PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## NOTE on typing: CharacterData is NOT class_name-registered and the preload
## constants below are not types — never annotate a variable with them
## (parse error); use plain `=` assignment and Variant locals.

const BattleSetup = preload("res://scripts/data/battle_setup.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")


static func run() -> bool:
	var ok := true
	ok = _test_derive_formula_values(ok)
	ok = _test_derive_move_range_steps(ok)
	ok = _test_attack_range_melee_default(ok)
	ok = _test_attack_range_ranged_tangmen(ok)
	ok = _test_build_not_staged(ok)
	ok = _test_build_mastered_propagation(ok)
	ok = _test_build_techniques_per_grade(ok)
	ok = _test_build_skills_from_external(ok)
	if ok:
		print("PASS test_battle_setup")
	else:
		print("FAIL test_battle_setup")
	return ok


# --- criterion 1: §7 formulas on the canonical profile ------------------------

static func _test_derive_formula_values(ok: bool) -> bool:
	var p = _profile({"bone": 20, "inner": 12, "agility": 40, "wisdom": 10, "fortune": 10})
	var s: Dictionary = BattleSetup.derive_stats(p)
	ok = _expect(ok, int(s.max_health) == 100, "max_health = 根骨*5 = 100")
	ok = _expect(ok, int(s.energy) == 24, "energy = 内力*2 = 24")
	ok = _expect(ok, int(s.move_range) == 4, "move_range = 2 + floor(40/20) = 4")
	ok = _expect(ok, int(s.initiative) == 40, "initiative = 身法 = 40")
	ok = _expect(ok, int(s.attack_damage) == 30, "attack_damage = 10 + 根骨 = 30")
	ok = _expect(ok, int(s.attack_range) == 1, "no gongfa -> melee range 1")
	return ok


# --- criterion 2: move_range floor steps ---------------------------------------

static func _test_derive_move_range_steps(ok: bool) -> bool:
	var p = _profile({"bone": 10, "inner": 10, "agility": 10, "wisdom": 10, "fortune": 10})
	ok = _expect(ok, int(BattleSetup.derive_stats(p).move_range) == 2,
		"agility 10 -> move_range 2")
	p.set_attr("agility", 20)
	ok = _expect(ok, int(BattleSetup.derive_stats(p).move_range) == 3,
		"agility 20 -> move_range 3")
	return ok


# --- criterion 3: default melee range ------------------------------------------

static func _test_attack_range_melee_default(ok: bool) -> bool:
	var p = _profile({})
	ok = _expect(ok, int(BattleSetup.derive_stats(p).attack_range) == 1,
		"empty profile -> melee range 1")
	return ok


# --- criterion 4: 唐门/暗器 (dart) is ranged, melee sects are not -------------

static func _test_attack_range_ranged_tangmen(ok: bool) -> bool:
	var p = _profile({})
	p.main_external_id = "tangmen_mantianhuayu_d"
	ok = _expect(ok, int(BattleSetup.derive_stats(p).attack_range) == 2,
		"tangmen dart school -> range 2")
	p.main_external_id = "wudang_taiji_d"
	ok = _expect(ok, int(BattleSetup.derive_stats(p).attack_range) == 1,
		"wudang sword school -> range 1")
	return ok


# --- criterion 5: build_character is never staged ------------------------------

static func _test_build_not_staged(ok: bool) -> bool:
	var p = _profile({})
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.staged_values == false, "progression build -> staged_values false")
	ok = _expect(ok, cd.team == 0, "progression hero is team 0")
	ok = _expect(ok, int(cd.max_health) == 50, "default profile max_health = 10*5 = 50")
	return ok


# --- criterion 6: mastered propagates from profile to GongfaData ---------------

static func _test_build_mastered_propagation(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("shaolin_yijin_d", "D")
	p.add_gongfa("shaolin_luohan_d", "D")
	p.master_gongfa_of("shaolin_luohan_d")
	var cd = BattleSetup.build_character(p)
	var internal_arts: Array = cd.internal_arts
	var external_arts: Array = cd.external_arts
	ok = _expect(ok, internal_arts.size() == 1 and external_arts.size() == 1,
		"one internal + one external art mapped")
	ok = _expect(ok, internal_arts[0].mastered == false,
		"unmastered internal stays false")
	ok = _expect(ok, external_arts[0].mastered == true,
		"mastered external propagates true")
	return ok


# --- criterion 7: generic grade techniques (丁1 / 丙2 / 乙3) --------------------

static func _test_build_techniques_per_grade(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("shaolin_luohan_d", "D")
	p.add_gongfa("shaolin_luohan_c", "C")
	p.add_gongfa("shaolin_luohan_b", "B")
	var cd = BattleSetup.build_character(p)
	var externals: Array = cd.external_arts
	ok = _expect(ok, externals.size() == 3, "3 external rows -> 3 arts")
	var counts: Array[int] = []
	for art in externals:
		counts.append(art.techniques.size())
	# Profile insertion order is preserved (d, c, b) — deterministic.
	ok = _expect(ok, counts == [1, 2, 3],
		"丁1/丙2/乙3 techniques, got %s" % str(counts))
	return ok


# --- criterion 8: skills are the union of external techniques ------------------

static func _test_build_skills_from_external(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("gaibang_dagou_d", "D")
	p.add_gongfa("emei_emeijian_c", "C")
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.skills.size() == 1 + 2,
		"skills = sum of external technique counts (丁1 + 丙2 = 3)")
	return ok


# --- helpers --------------------------------------------------------------------

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
	push_error("test_battle_setup: " + msg)
	return false
