## Unit tests for the real 甲乙丙丁 fa_hui_du prerequisite cascade
## (scripts/data/gongfa_data.gd + scripts/data/character_data.gd) and the
## CombatManager delegation (scripts/autoload/combat_manager.gd).
##
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## NOTE on typing: GongfaData / CharacterData are NOT class_name-registered
## globals — they are preload constants. Declare instances with plain `=`
## (no `:=` / no `: GongfaData` annotation): the preload constant is not a
## type, so type annotations on it fail to parse and `:=` cannot infer.

const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const CharacterData = preload("res://scripts/data/character_data.gd")
const CombatManagerScript = preload("res://scripts/autoload/combat_manager.gd")


static func run() -> bool:
	var ok := true
	ok = _test_staged_short_circuit(ok)
	ok = _test_null_unit(ok)
	ok = _test_d_empty(ok)
	ok = _test_a_empty(ok)
	ok = _test_b_unmastered_c(ok)
	ok = _test_a_cd_mastered_no_b(ok)
	ok = _test_a_bcd_mastered(ok)
	ok = _test_school_isolation(ok)
	ok = _test_same_attr_crosses_schools(ok)
	ok = _test_same_attr_cap(ok)
	ok = _test_internal_cascade(ok)
	ok = _test_defaults(ok)
	ok = _test_combat_manager_delegate(ok)
	if ok:
		print("PASS test_gongfa_cascade")
	else:
		print("FAIL test_gongfa_cascade")
	return ok


# --- criterion 1: staged_values short-circuits to the field -------------------

static func _test_staged_short_circuit(ok: bool) -> bool:
	var art = _gongfa("A", "sword", "hard", "external", 1.3)
	var unit = _unit([], [], true)
	ok = _expect(ok, art.get_fa_hui_du(unit) == 1.3,
		"staged unit returns field 1.3 (not cascade)")
	art.fa_hui_du = 0.9
	ok = _expect(ok, art.get_fa_hui_du(unit) == 0.9,
		"staged unit returns the FIELD 0.9, never recomputed")
	return ok


# --- criterion 2: null unit falls back to the field ---------------------------

static func _test_null_unit(ok: bool) -> bool:
	var art = _gongfa("A", "sword", "hard", "external", 1.3)
	ok = _expect(ok, art.get_fa_hui_du(null) == 1.3, "null unit -> fa_hui_du field")
	art.fa_hui_du = 0.75
	ok = _expect(ok, art.get_fa_hui_du(null) == 0.75,
		"null unit -> the exact field value")
	return ok


# --- criterion 3: D art, empty arts -> 1.0 ------------------------------------

static func _test_d_empty(ok: bool) -> bool:
	var art = _gongfa("D", "sword", "hard", "external", 1.3)
	var unit = _unit([], [])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 1.0,
		"D art empty arts -> 1.0 (missing 0, same_attr 0)")
	return ok


# --- criterion 4: A art, empty arts -> 0.6 ------------------------------------

static func _test_a_empty(ok: bool) -> bool:
	var art = _gongfa("A", "sword", "hard", "external", 1.3)
	var unit = _unit([], [])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 0.6,
		"A art empty arts -> 0.6 (missing 3, 神功卡 0.6~0.7 case)")
	return ok


# --- criterion 5: B art, C present but unmastered, no D -> 0.7 ----------------

static func _test_b_unmastered_c(ok: bool) -> bool:
	var art = _gongfa("B", "sword", "hard", "external", 1.3)
	var c_unmastered = _gongfa("C", "sword", "hard", "external", 1.3)
	var unit = _unit([], [c_unmastered])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 0.7,
		"B art with unmastered same-school C and no D -> 0.7 (missing 2)")
	return ok


# --- criterion 6: A art, C+D mastered but B absent -> 0.85 --------------------

static func _test_a_cd_mastered_no_b(ok: bool) -> bool:
	var art = _gongfa("A", "sword", "hard", "external", 1.3)
	var c_mastered = _gongfa("C", "sword", "hard", "external", 1.3)
	c_mastered.mastered = true
	var d_mastered = _gongfa("D", "sword", "hard", "external", 1.3)
	d_mastered.mastered = true
	var unit = _unit([], [c_mastered, d_mastered])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 0.85,
		"A art with C+D mastered but B absent -> 0.85 (missing 1)")
	return ok


# --- criterion 7: A art, B+C+D mastered all 柔, A unmastered -> 1.3 -----------

static func _test_a_bcd_mastered(ok: bool) -> bool:
	var art = _gongfa("A", "sword", "soft", "external", 1.3)
	var b = _gongfa("B", "sword", "soft", "external", 1.3)
	b.mastered = true
	var c = _gongfa("C", "sword", "soft", "external", 1.3)
	c.mastered = true
	var d = _gongfa("D", "sword", "soft", "external", 1.3)
	d.mastered = true
	# The evaluated A itself is present but unmastered -> does not add same_attr.
	var unit = _unit([], [art, b, c, d])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 1.3,
		"A art with B+C+D mastered all 柔 -> 1.3 (base 1.0, same_attr 3)")
	return ok


# --- criterion 8: school isolation — palm cannot satisfy sword ---------------

static func _test_school_isolation(ok: bool) -> bool:
	var art = _gongfa("C", "sword", "hard", "external", 1.3)
	var d_palm = _gongfa("D", "palm", "hard", "external", 1.3)
	d_palm.mastered = true
	var unit = _unit([], [d_palm])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 0.85,
		"C sword art, mastered D palm art -> 0.85 (刀法顶不了剑法)")
	return ok


# --- criterion 9: same_attr crosses schools and kinds -> 1.2 -----------------

static func _test_same_attr_crosses_schools(ok: bool) -> bool:
	# Evaluated art: D (no lower slots -> base 1.0), attribute 阳, unmastered.
	var art = _gongfa("D", "sword", "yang", "external", 1.3)
	var internal_yang = _gongfa("D", "internal", "yang", "internal", 1.3)
	internal_yang.mastered = true
	var palm_yang = _gongfa("D", "palm", "yang", "external", 1.3)
	palm_yang.mastered = true
	var unit = _unit([internal_yang], [palm_yang])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 1.2,
		"same_attr counts mastered arts across internal+external, schools -> 1.2")
	return ok


# --- criterion 10: same_attr capped at 3 -> 1.3, never 1.4 -------------------

static func _test_same_attr_cap(ok: bool) -> bool:
	var art = _gongfa("D", "sword", "soft", "external", 1.3)
	var extras := []
	for i in range(4):
		var e = _gongfa("D", "palm", "soft", "external", 1.3)
		e.mastered = true
		extras.append(e)
	var unit = _unit([], extras)
	ok = _expect(ok, art.get_fa_hui_du(unit) == 1.3,
		"4 mastered same-attribute arts cap at 1.3, never 1.4")
	return ok


# --- criterion 11: internal arts form their own 门类 cascade ------------------

static func _test_internal_cascade(ok: bool) -> bool:
	var art = _gongfa("C", "internal", "soft", "internal", 1.3)
	var d_internal = _gongfa("D", "internal", "soft", "internal", 1.3)
	d_internal.mastered = true
	var unit = _unit([d_internal], [])
	ok = _expect(ok, art.get_fa_hui_du(unit) == 1.1,
		"C internal art + mastered D internal art of same attribute -> 1.1")
	return ok


# --- criterion 12: defaults ---------------------------------------------------

static func _test_defaults(ok: bool) -> bool:
	var cd = CharacterData.new()
	ok = _expect(ok, cd.staged_values == false, "CharacterData.staged_values default false")
	var g = GongfaData.new()
	ok = _expect(ok, g.mastered == false, "GongfaData.mastered default false")
	return ok


# --- extra: CombatManager delegation -----------------------------------------

static func _test_combat_manager_delegate(ok: bool) -> bool:
	var cm = CombatManagerScript.new()
	# GongfaData with the cascade method -> delegates and returns the cascade.
	var art = _gongfa("D", "sword", "hard", "external", 1.3)
	var empty_unit = _unit([], [])
	ok = _expect(ok, cm.get_fa_hui_du(art, empty_unit) == 1.0,
		"CombatManager delegates to gongfa.get_fa_hui_du(unit)")
	ok = _expect(ok, cm.get_fa_hui_du(art, null) == 1.3,
		"CombatManager null unit -> field via delegate")
	# Non-gongfa without the method -> DEFAULT_FA_HUI_DU fallback (1.3).
	var not_gongfa := {"name": "not a gongfa"}
	ok = _expect(ok, cm.get_fa_hui_du(not_gongfa, empty_unit) == 1.3,
		"CombatManager non-gongfa falls back to DEFAULT_FA_HUI_DU")
	ok = _expect(ok, cm.get_fa_hui_du(null, empty_unit) == 1.3,
		"CombatManager null gongfa falls back to DEFAULT_FA_HUI_DU")
	return ok


# --- helpers ------------------------------------------------------------------

## Build a GongfaData resource with explicit fields. Returned as Resource so
## the static helpers stay type-safe without a class_name.
static func _gongfa(grade: String, school: String, attribute: String,
		kind: String, fhd: float) -> Resource:
	var g = GongfaData.new()
	g.grade = grade
	g.school = school
	g.attribute = attribute
	g.kind = kind
	g.fa_hui_du = fhd
	return g


## Build a CharacterData unit with the given internal/external arts arrays.
static func _unit(internal: Array, external: Array, staged: bool = false) -> Resource:
	var cd = CharacterData.new()
	cd.internal_arts = internal
	cd.external_arts = external
	cd.staged_values = staged
	return cd


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_gongfa_cascade: " + msg)
	return false
