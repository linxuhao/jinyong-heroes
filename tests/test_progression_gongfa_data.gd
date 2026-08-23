## Unit tests for scripts/data/progression_gongfa_data.gd (ProgressionGongfaData).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const ProgressionGongfaData = preload("res://scripts/data/progression_gongfa_data.gd")

const SECT_IDS := ["shaolin", "wudang", "gaibang", "emei", "tangmen"]
const GRADES := ["D", "C", "B"]
const KINDS := ["internal", "external"]

## Verbatim 丁 display names (design/40_progression.md §2.4).
const D_DISPLAY := {
	"shaolin": {"internal": "易筋经·入门", "external": "罗汉拳"},
	"wudang": {"internal": "纯阳无极功·入门", "external": "太极剑"},
	"gaibang": {"internal": "混天功·入门", "external": "打狗棒法"},
	"emei": {"internal": "峨眉九阳功·入门", "external": "峨眉剑法"},
	"tangmen": {"internal": "唐门心法·入门", "external": "满天花雨"},
}

## Bare bases (before ·入门/·精进/·大成), verbatim from §2.4.
const INTERNAL_BASE := {"shaolin": "易筋经", "wudang": "纯阳无极功", "gaibang": "混天功", "emei": "峨眉九阳功", "tangmen": "唐门心法"}
const EXTERNAL_BASE := {"shaolin": "罗汉拳", "wudang": "太极剑", "gaibang": "打狗棒法", "emei": "峨眉剑法", "tangmen": "满天花雨"}

## §2.4 internal attributes / step2_design §2.2 external attributes.
const INTERNAL_ATTR := {"shaolin": "刚", "wudang": "柔", "gaibang": "阳", "emei": "阴", "tangmen": "柔"}
const EXTERNAL_ATTR := {"shaolin": "刚", "wudang": "柔", "gaibang": "阳", "emei": "阴", "tangmen": "柔"}

## §2.4 门类 for external arts.
const EXTERNAL_SCHOOL := {"shaolin": "palm", "wudang": "sword", "gaibang": "polearm", "emei": "sword", "tangmen": "dart"}

const STEP := {"C": "精进", "B": "大成"}
const TECHNIQUE_COUNT := {"D": 1, "C": 2, "B": 3}
const TECHNIQUE_DAMAGE := {"D": 18, "C": 22, "B": 26}
const TECHNIQUE_NAMES := ["一式", "二式", "三式"]


static func run() -> bool:
	var ok := true
	ok = _test_sects(ok)
	ok = _test_ids(ok)
	ok = _test_arts(ok)
	ok = _test_techniques(ok)
	ok = _test_consts(ok)
	ok = _test_unknown(ok)
	ok = _test_fresh_instances(ok)
	ok = _test_a_tables(ok)
	ok = _test_a_pool(ok)
	ok = _test_external_a_rows(ok)
	ok = _test_internal_a_rows(ok)
	ok = _test_a_lookup(ok)
	if ok:
		print("PASS test_progression_gongfa_data")
	else:
		print("FAIL test_progression_gongfa_data")
	return ok


static func _test_sects(ok: bool) -> bool:
	ok = _expect(ok, ProgressionGongfaData.sect_ids() == SECT_IDS, "sect_ids order")
	ok = _expect(ok, ProgressionGongfaData.sect_def("shaolin")["display_name"] == "少林", "sect_def shaolin")
	ok = _expect(ok, ProgressionGongfaData.sect_def("nope").is_empty(), "sect_def unknown -> {}")
	return ok


static func _test_ids(ok: bool) -> bool:
	var ids: Array = []
	for sect_id in SECT_IDS:
		for kind in KINDS:
			for grade in GRADES:
				ids.append(ProgressionGongfaData.art_id(sect_id, kind, grade))
	# 30 distinct ids (uniqueness)
	var seen := {}
	for id in ids:
		seen[id] = true
	ok = _expect(ok, ids.size() == 30, "30 full art ids")
	ok = _expect(ok, seen.size() == 30, "all 30 ids unique")
	ok = _expect(ok, ids.has("shaolin_yijin_d"), "shaolin_yijin_d present")
	ok = _expect(ok, ids.has("shaolin_luohan_d"), "shaolin_luohan_d present")
	# art_by_id round-trips every generated id
	for id in ids:
		ok = _expect(ok, ProgressionGongfaData.art_by_id(id) != null, "art_by_id round-trip " + id)
	# A-grade ids generate for both kinds; the internal one resolves, the
	# generated external one does not (see _test_a_pool).
	ok = _expect(ok, ProgressionGongfaData.art_id("shaolin", "internal", "A") == "shaolin_yijin_a", "art_id internal A")
	ok = _expect(ok, ProgressionGongfaData.art_id("shaolin", "external", "A") == "shaolin_luohan_a", "art_id external A (generated)")
	ok = _expect(ok, ProgressionGongfaData.art_id("shaolin", "nope", "D") == "", "art_id bad kind -> ''")
	return ok


static func _test_arts(ok: bool) -> bool:
	for sect_id in SECT_IDS:
		for grade in GRADES:
			var internal = ProgressionGongfaData.internal_art(sect_id, grade)
			var external = ProgressionGongfaData.external_art(sect_id, grade)
			ok = _expect(ok, internal != null, "internal_art non-null " + sect_id + " " + grade)
			ok = _expect(ok, external != null, "external_art non-null " + sect_id + " " + grade)
			if internal == null or external == null:
				continue
			# identity fields
			ok = _expect(ok, internal.grade == grade, "internal grade " + sect_id)
			ok = _expect(ok, internal.kind == "internal", "internal kind")
			ok = _expect(ok, internal.school == "internal", "internal school")
			ok = _expect(ok, external.grade == grade, "external grade " + sect_id)
			ok = _expect(ok, external.kind == "external", "external kind")
			ok = _expect(ok, external.school == EXTERNAL_SCHOOL[sect_id], "external school " + sect_id)
			ok = _expect(ok, internal.attribute == INTERNAL_ATTR[sect_id], "internal attr " + sect_id)
			ok = _expect(ok, external.attribute == EXTERNAL_ATTR[sect_id], "external attr " + sect_id)
			ok = _expect(ok, internal.fa_hui_du == 1.0, "internal fa_hui_du 1.0")
			ok = _expect(ok, external.fa_hui_du == 1.0, "external fa_hui_du 1.0")
			ok = _expect(ok, internal.mastered == false, "internal mastered false")
			ok = _expect(ok, external.mastered == false, "external mastered false")
			# display names: verbatim 丁, ·精进/·大成 for C/B
			ok = _expect(ok, internal.gongfa_name == _expected_display(sect_id, "internal", grade), "internal display " + sect_id + " " + grade)
			ok = _expect(ok, external.gongfa_name == _expected_display(sect_id, "external", grade), "external display " + sect_id + " " + grade)
			# internal arts are data-only: empty techniques, zero energy
			ok = _expect(ok, internal.techniques.is_empty(), "internal techniques empty " + sect_id)
			ok = _expect(ok, internal.energy_provided == 0, "internal energy 0 " + sect_id)
	return ok


static func _test_techniques(ok: bool) -> bool:
	for sect_id in SECT_IDS:
		for grade in GRADES:
			var art = ProgressionGongfaData.external_art(sect_id, grade)
			var techs: Array = art.techniques
			ok = _expect(ok, techs.size() == TECHNIQUE_COUNT[grade], "technique count " + sect_id + " " + grade)
			for i in range(techs.size()):
				var t = techs[i]
				ok = _expect(ok, t.damage == TECHNIQUE_DAMAGE[grade], "damage " + sect_id + " " + grade)
				ok = _expect(ok, t.range == 1, "range 1 " + sect_id + " " + grade)
				ok = _expect(ok, t.cooldown == 1, "cooldown 1 " + sect_id + " " + grade)
				ok = _expect(ok, t.aoe_shape == "single", "aoe_shape single " + sect_id + " " + grade)
				ok = _expect(ok, t.aoe_size == 0, "aoe_size 0 " + sect_id + " " + grade)
				ok = _expect(ok, t.is_finisher == false, "is_finisher false " + sect_id + " " + grade)
				ok = _expect(ok, (t.skill_name as String).ends_with("·" + TECHNIQUE_NAMES[i]), "skill name suffix " + sect_id + " " + grade)
	return ok


static func _test_consts(ok: bool) -> bool:
	ok = _expect(ok, ProgressionGongfaData.PRACTICE_TO_MASTER == {"D": 4, "C": 6, "B": 8, "A": 10}, "PRACTICE_TO_MASTER 丁4/丙6/乙8/甲10")
	ok = _expect(ok, ProgressionGongfaData.GRADE_BY_YEAR == ["D", "C", "B"], "GRADE_BY_YEAR")
	ok = _expect(ok, ProgressionGongfaData.display_name_of("shaolin_yijin_d") == "易筋经·入门", "display_name_of 丁 internal")
	ok = _expect(ok, ProgressionGongfaData.display_name_of("shaolin_luohan_c") == "罗汉拳·精进", "display_name_of 丙 external")
	ok = _expect(ok, ProgressionGongfaData.display_name_of("tangmen_xinfa_b") == "唐门心法·大成", "display_name_of 乙 internal")
	return ok


static func _test_unknown(ok: bool) -> bool:
	ok = _expect(ok, ProgressionGongfaData.internal_art("nope", "D") == null, "internal_art unknown sect -> null")
	ok = _expect(ok, ProgressionGongfaData.external_art("shaolin", "A") == null, "external_art grade A -> null")
	ok = _expect(ok, ProgressionGongfaData.art_by_id("nope") == null, "art_by_id unknown -> null")
	ok = _expect(ok, ProgressionGongfaData.display_name_of("nope") == "", "display_name_of unknown -> ''")
	return ok


static func _test_fresh_instances(ok: bool) -> bool:
	var a = ProgressionGongfaData.internal_art("shaolin", "D")
	a.gongfa_name = "mutated"
	var b = ProgressionGongfaData.internal_art("shaolin", "D")
	ok = _expect(ok, b.gongfa_name == "易筋经·入门", "internal_art instances fresh")
	var e1 = ProgressionGongfaData.external_art("shaolin", "C")
	var t0 = e1.techniques[0]
	t0.damage = 999
	var e2 = ProgressionGongfaData.external_art("shaolin", "C")
	var t2 = e2.techniques[0]
	ok = _expect(ok, t2.damage == 22, "technique stubs fresh")
	return ok


## --- A-grade tables ----------------------------------------------------------

static func _test_a_tables(ok: bool) -> bool:
	ok = _expect(ok, ProgressionGongfaData.GRADE_SUFFIX["A"] == "a", "GRADE_SUFFIX A -> a")
	ok = _expect(ok, ProgressionGongfaData.GRADE_STEP["A"] == "圆满", "GRADE_STEP A -> 圆满")
	ok = _expect(ok, ProgressionGongfaData.PRACTICE_TO_MASTER["A"] == 10, "PRACTICE_TO_MASTER A == 10")
	ok = _expect(ok, ProgressionGongfaData.TECHNIQUE_COUNT["A"] == 4, "TECHNIQUE_COUNT A == 4")
	ok = _expect(ok, ProgressionGongfaData.TECHNIQUE_DAMAGE["A"] == 30, "TECHNIQUE_DAMAGE A == 30")
	ok = _expect(ok, ProgressionGongfaData.GRADE_BY_YEAR == ["D", "C", "B"],
		"year ladder still tops at 乙")
	return ok


## --- A pool: 9 ids, fixed order, all resolve ---------------------------------

static func _test_a_pool(ok: bool) -> bool:
	var pool: Array = ProgressionGongfaData.a_pool()
	var expected: Array = [
		"a_sword", "a_palm", "a_polearm", "a_dart",
		"shaolin_yijin_a", "wudang_chunyang_a", "gaibang_huntian_a",
		"emei_jiuyang_a", "tangmen_xinfa_a",
	]
	ok = _expect(ok, pool.size() == 9, "a_pool size 9")
	ok = _expect(ok, pool == expected, "a_pool fixed order")
	for id in pool:
		ok = _expect(ok, ProgressionGongfaData.art_by_id(id) != null, "a_pool id resolves " + id)
	ok = _expect(ok, ProgressionGongfaData.art_by_id("shaolin_luohan_a") == null,
		"generated external A not resolvable")
	ok = _expect(ok, ProgressionGongfaData.external_art("shaolin", "A") == null,
		"external_art A -> null (guard)")
	ok = _expect(ok, ProgressionGongfaData.internal_art("shaolin", "A") != null,
		"internal_art A resolves")
	return ok


## --- external A rows: 4 techniques, one finisher, 绝招 prefix, attr guard -----

static func _test_external_a_rows(ok: bool) -> bool:
	# Feeding sect-line attributes per school (design §4.3): the external A
	# attribute must NOT equal the lines that feed it (sword 柔/阴, palm 刚,
	# polearm 阳, dart 柔).
	var feeding := {"sword": ["柔", "阴"], "palm": ["刚"], "polearm": ["阳"], "dart": ["柔"]}
	for row_id in ["a_sword", "a_palm", "a_polearm", "a_dart"]:
		var art = ProgressionGongfaData.art_by_id(row_id)
		ok = _expect(ok, art != null, "external A resolves " + row_id)
		if art == null:
			continue
		var techs: Array = art.techniques
		ok = _expect(ok, techs.size() == 4, "external A has 4 techniques " + row_id)
		var finishers := 0
		var prefix_ok := true
		for t in techs:
			if t.is_finisher:
				finishers += 1
				if not (t.skill_name as String).begins_with("绝招"):
					prefix_ok = false
		ok = _expect(ok, finishers == 1, "exactly one finisher " + row_id)
		ok = _expect(ok, prefix_ok, "finisher name begins with 绝招 " + row_id)
		var attr: String = art.attribute
		ok = _expect(ok, not (feeding[art.school] as Array).has(attr),
			"external A attr " + attr + " not in feeding line " + row_id)
	return ok


## --- internal A rows: attribute == sect line, name = base + ·圆满 ---------------

static func _test_internal_a_rows(ok: bool) -> bool:
	for sect_id in SECT_IDS:
		var art = ProgressionGongfaData.internal_art(sect_id, "A")
		ok = _expect(ok, art != null, "internal A non-null " + sect_id)
		if art == null:
			continue
		ok = _expect(ok, art.attribute == INTERNAL_ATTR[sect_id],
			"internal A attr == sect line " + sect_id)
		ok = _expect(ok, art.gongfa_name == INTERNAL_BASE[sect_id] + "·圆满",
			"internal A name base+·圆满 " + sect_id)
		ok = _expect(ok, art.techniques.is_empty(), "internal A data-only " + sect_id)
		ok = _expect(ok, art.energy_provided == 0, "internal A energy 0 " + sect_id)
	return ok


## --- a_art_for_school / a_art_for_sect / display_name_of -----------------------

static func _test_a_lookup(ok: bool) -> bool:
	ok = _expect(ok, ProgressionGongfaData.a_art_for_school("sword").gongfa_name == "独孤九剑", "a_art_for_school sword")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_school("palm").gongfa_name == "降龙十八掌", "a_art_for_school palm")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_school("polearm").gongfa_name == "杨家枪法", "a_art_for_school polearm")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_school("dart").gongfa_name == "小李飞刀", "a_art_for_school dart")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_school("nope") == null, "a_art_for_school unknown -> null")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_school("internal") == null, "a_art_for_school internal -> null")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_sect("shaolin").gongfa_name == "易筋经·圆满", "a_art_for_sect shaolin")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_sect("tangmen").gongfa_name == "唐门心法·圆满", "a_art_for_sect tangmen")
	ok = _expect(ok, ProgressionGongfaData.a_art_for_sect("nope") == null, "a_art_for_sect unknown -> null")
	ok = _expect(ok, ProgressionGongfaData.display_name_of("a_sword") == "独孤九剑", "display_name_of external A")
	ok = _expect(ok, ProgressionGongfaData.display_name_of("shaolin_yijin_a") == "易筋经·圆满", "display_name_of internal A")
	return ok


static func _expected_display(sect_id: String, kind: String, grade: String) -> String:
	var base: String = (INTERNAL_BASE if kind == "internal" else EXTERNAL_BASE)[sect_id]
	if grade == "D":
		if kind == "internal":
			return D_DISPLAY[sect_id]["internal"]
		return D_DISPLAY[sect_id]["external"]
	return base + "·" + STEP[grade]


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_progression_gongfa_data: " + msg)
	return false
