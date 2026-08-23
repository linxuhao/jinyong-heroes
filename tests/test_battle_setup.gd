## Unit tests for the progression-side battle setup
## (scripts/data/battle_setup.gd): the §7 stat-derivation formulas and the
## CharacterData build (traits propagation, mastered propagation, grade-sorted
## equip cap 2 / 3 with 左右互搏, generic grade techniques). Covers the subtask
## card's acceptance criteria with exact expected values (derive 100/24/4/40/30,
## move 2@10/3@20, range melee-1 / tangmen-2, build traits/team-0/50, mastered
## propagation, techniques, equip cap + grade sort, skills = equipped only).
## Mirrors tests/test_gongfa_cascade.gd's skeleton: top-level static func
## run() -> bool; push_error on failure; print PASS/FAIL at the end; never
## relies on assert() (stripped in release).
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
	ok = _test_build_defaults(ok)
	ok = _test_build_mastered_propagation(ok)
	ok = _test_build_techniques_per_grade(ok)
	ok = _test_build_skills_from_external(ok)
	ok = _test_build_traits_default(ok)
	ok = _test_build_traits_propagation(ok)
	ok = _test_build_equip_cap(ok)
	ok = _test_build_grade_sorted(ok)
	ok = _test_build_stable_tie(ok)
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


# --- criterion 5: build_character defaults ---------------------------------------

static func _test_build_defaults(ok: bool) -> bool:
	var p = _profile({})
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.traits == [], "progression build -> traits empty")
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


# --- criterion 7: equip cap 2 — highest grades equipped first --------------------

static func _test_build_techniques_per_grade(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("shaolin_luohan_d", "D")
	p.add_gongfa("shaolin_luohan_c", "C")
	p.add_gongfa("shaolin_luohan_b", "B")
	var cd = BattleSetup.build_character(p)
	var externals: Array = cd.external_arts
	# Cap 2 without ambidextrous: grade-sorted [B, C, D] keeps only B + C.
	ok = _expect(ok, externals.size() == 2, "cap 2 -> 2 equipped (3 owned)")
	var counts: Array[int] = []
	for art in externals:
		counts.append(art.techniques.size())
	ok = _expect(ok, counts == [3, 2],
		"equipped B+C techniques 3+2, got %s" % str(counts))
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


# --- criterion 9: traits default empty on a trait-less profile ------------------

static func _test_build_traits_default(ok: bool) -> bool:
	var p = _profile({})
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.traits == [], "no traits -> CharacterData.traits empty")
	return ok


# --- criterion 10: profile traits propagate onto the CharacterData --------------

static func _test_build_traits_propagation(ok: bool) -> bool:
	var p = _profile({})
	p.add_trait("sha_po_lang")
	p.add_trait("iron_shirt")
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.traits == p.traits, "traits copied from profile")
	ok = _expect(ok, cd.traits.has("sha_po_lang") and cd.traits.has("iron_shirt"),
		"both traits present on CharacterData")
	# Duplicate copy, not aliasing: later profile changes cannot leak in.
	p.add_trait("swallow_lightness")
	ok = _expect(ok, cd.traits.size() == 2, "traits duplicated (profile change isolated)")
	return ok


# --- criterion 11: equip cap 2 vs 3 with 左右互搏/ambidextrous -------------------

static func _test_build_equip_cap(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("shaolin_luohan_d", "D")
	p.add_gongfa("shaolin_luohan_c", "C")
	p.add_gongfa("shaolin_luohan_b", "B")
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.external_arts.size() == 2, "no ambidextrous -> cap 2")
	var skills: int = 0
	for art in cd.external_arts:
		skills += art.techniques.size()
	ok = _expect(ok, skills == 5, "cap 2 -> skills 3+2 = 5")
	p.add_trait("ambidextrous")
	var cd3 = BattleSetup.build_character(p)
	ok = _expect(ok, cd3.external_arts.size() == 3, "ambidextrous -> cap 3")
	var skills3: int = 0
	for art in cd3.external_arts:
		skills3 += art.techniques.size()
	ok = _expect(ok, skills3 == 6, "ambidextrous -> skills 3+2+1 = 6")
	return ok


# --- criterion 12: grade-sorted equip — A always equipped, skills[0] = 总诀式 ---

static func _test_build_grade_sorted(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("shaolin_luohan_d", "D")
	p.add_gongfa("a_sword", "A")
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.external_arts.size() == 2, "D + A both equipped (cap 2)")
	ok = _expect(ok, str(cd.external_arts[0].grade) == "A",
		"grade-sorted: A first despite later profile insertion")
	ok = _expect(ok, cd.skills[0].skill_name == "总诀式",
		"skills[0] is the A sword's first technique (总诀式)")
	return ok


# --- criterion 13: stable tie — two grade-A arts keep profile order -------------

static func _test_build_stable_tie(ok: bool) -> bool:
	var p = _profile({})
	p.add_gongfa("a_sword", "A")
	p.add_gongfa("a_palm", "A")
	p.add_trait("ambidextrous")
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.external_arts.size() == 2, "two A arts equipped")
	ok = _expect(ok, cd.external_arts[0].gongfa_name == "独孤九剑",
		"stable tie: a_sword keeps first position")
	ok = _expect(ok, cd.external_arts[1].gongfa_name == "降龙十八掌",
		"stable tie: a_palm keeps second position")
	ok = _expect(ok, cd.skills.size() == 4 + 4, "skills = both A arts' 4 techniques")
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
