class_name ProgressionGongfaData

## Registry of the progression gongfa rows: 5 sects × (internal + external) ×
## 丁丙乙 = 30 arts plus the 甲级 (A) ladder — 4 hand-authored external A arts
## (a_sword / a_palm / a_polearm / a_dart) and 5 internal A arts
## (design/40_progression.md §2.4 + step2_design §2.2/§4.2–§4.3).
## Pure data layer — practice/mastery bookkeeping, sect grants and the
## year-end grade ladder belong to cultivation; this file only supplies the
## rows, the 丁4/丙6/乙8/甲10 practice table, the year→grade map, and the
## generic external technique stubs (丁1 / 丙2 / 乙3, damage 丁18 / 丙22 / 乙26)
## plus the hand-authored external A techniques (step2_design §4.3).
##
## NOTE on typing: GongfaData / SkillData are NOT class_name-registered — they
## are preloaded constants (see tests/test_gongfa_cascade.gd header). Never
## annotate a variable or return with them (parse error); type such values as
## Resource / Variant and assign with plain `=`.

const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const SkillData = preload("res://scripts/data/skill_data.gd")

## Months of 练功 required to master a gongfa, by grade (step2_design §2.2/§4.2).
const PRACTICE_TO_MASTER := {"D": 4, "C": 6, "B": 8, "A": 10}

## Grade granted at the start of each cultivation year (index = year - 1,
## so year 2 → "C", year 3 → "B"). The year ladder tops at 乙 — 甲 comes only
## from the 神功 card pool, never from the year ladder.
const GRADE_BY_YEAR := ["D", "C", "B"]

## Grade letter → art-id suffix (ids are lowercase, e.g. shaolin_yijin_d).
const GRADE_SUFFIX := {"D": "d", "C": "c", "B": "b", "A": "a"}

## Grade letter → display step (丁 入门 / 丙 精进 / 乙 大成 / 甲 圆满).
const GRADE_STEP := {"D": "入门", "C": "精进", "B": "大成", "A": "圆满"}

## Generic external technique stubs: count and damage per grade
## (step2_design §2.2/§4.2: 丁1/丙2/乙3/甲4 techniques, damage 丁18/丙22/乙26/甲30;
## the 甲 grade's 4th technique is the 绝招 finisher).
const TECHNIQUE_COUNT := {"D": 1, "C": 2, "B": 3, "A": 4}
const TECHNIQUE_DAMAGE := {"D": 18, "C": 22, "B": 26, "A": 30}
const TECHNIQUE_NAMES := ["一式", "二式", "三式"]

## 5 sect rows (design/40_progression.md §2.4 verbatim; step2_design §2.2
## external attributes). Row fields:
##   id | display_name | internal_pinyin | internal_base | internal_attribute |
##   external_pinyin | external_base | external_school | external_attribute
## Art id = `<sect_id>_<pinyin>_<grade-lowercase>` (matches the step2 §7
## save-schema example shaolin_yijin_d / shaolin_luohan_d).
const SECTS: Array = [
	{
		"id": "shaolin", "display_name": "少林",
		"internal_pinyin": "yijin", "internal_base": "易筋经", "internal_attribute": "刚",
		"external_pinyin": "luohan", "external_base": "罗汉拳", "external_school": "palm", "external_attribute": "刚",
	},
	{
		"id": "wudang", "display_name": "武当",
		"internal_pinyin": "chunyang", "internal_base": "纯阳无极功", "internal_attribute": "柔",
		"external_pinyin": "taiji", "external_base": "太极剑", "external_school": "sword", "external_attribute": "柔",
	},
	{
		"id": "gaibang", "display_name": "丐帮",
		"internal_pinyin": "huntian", "internal_base": "混天功", "internal_attribute": "阳",
		"external_pinyin": "dagou", "external_base": "打狗棒法", "external_school": "polearm", "external_attribute": "阳",
	},
	{
		"id": "emei", "display_name": "峨眉",
		"internal_pinyin": "jiuyang", "internal_base": "峨眉九阳功", "internal_attribute": "阴",
		"external_pinyin": "emeijian", "external_base": "峨眉剑法", "external_school": "sword", "external_attribute": "阴",
	},
	{
		"id": "tangmen", "display_name": "唐门",
		"internal_pinyin": "xinfa", "internal_base": "唐门心法", "internal_attribute": "柔",
		"external_pinyin": "mantianhuayu", "external_base": "满天花雨", "external_school": "dart", "external_attribute": "柔",
	},
]


## 甲级 external A arts (step2_design §4.3) — one per school, with hand-authored
## real techniques. The attribute deliberately does NOT equal that school's
## feeding sect-line attributes (sword lines 柔/阴 → a_sword 刚; palm line 刚 →
## a_palm 阳; polearm line 阳 → a_polearm 刚; dart line 柔 → a_dart 阴) so a
## completed 3-year ladder sits at exactly 1.0 and the climb to 1.3 stays a
## real pursuit. Field values map to SkillData 1:1 (aoe_shape / aoe_origin /
## aoe_size / range / cooldown / knockback / ignore_damage_reduction /
## is_finisher); "—" in the range column means 1.
const EXTERNAL_A_ARTS: Array = [
	{
		"id": "a_sword", "name": "独孤九剑", "school": "sword", "attribute": "刚",
		"techniques": [
			{"skill_name": "总诀式", "damage": 30, "range": 1, "cooldown": 1, "aoe_shape": "single", "aoe_size": 0, "aoe_origin": "self"},
			{"skill_name": "破剑式", "damage": 28, "range": 1, "cooldown": 2, "aoe_shape": "single", "aoe_size": 0, "aoe_origin": "self", "ignore_damage_reduction": true},
			{"skill_name": "破气式", "damage": 26, "range": 3, "cooldown": 3, "aoe_shape": "line", "aoe_size": 0, "aoe_origin": "self"},
			{"skill_name": "绝招·无招胜有招", "damage": 55, "range": 1, "cooldown": 5, "aoe_shape": "square", "aoe_size": 2, "aoe_origin": "self", "is_finisher": true},
		],
	},
	{
		"id": "a_palm", "name": "降龙十八掌", "school": "palm", "attribute": "阳",
		"techniques": [
			{"skill_name": "亢龙有悔", "damage": 30, "range": 1, "cooldown": 1, "aoe_shape": "single", "aoe_size": 0, "aoe_origin": "self", "knockback": 1},
			{"skill_name": "飞龙在天", "damage": 28, "range": 3, "cooldown": 2, "aoe_shape": "line", "aoe_size": 0, "aoe_origin": "self"},
			{"skill_name": "见龙在田", "damage": 26, "range": 1, "cooldown": 3, "aoe_shape": "cross", "aoe_size": 1, "aoe_origin": "self"},
			{"skill_name": "绝招·潜龙勿用", "damage": 55, "range": 1, "cooldown": 5, "aoe_shape": "square", "aoe_size": 2, "aoe_origin": "self", "is_finisher": true, "knockback": 2},
		],
	},
	{
		"id": "a_polearm", "name": "杨家枪法", "school": "polearm", "attribute": "刚",
		"techniques": [
			{"skill_name": "回马枪", "damage": 30, "range": 1, "cooldown": 1, "aoe_shape": "single", "aoe_size": 0, "aoe_origin": "self"},
			{"skill_name": "梨花枪", "damage": 28, "range": 3, "cooldown": 2, "aoe_shape": "line", "aoe_size": 0, "aoe_origin": "self"},
			{"skill_name": "锁喉枪", "damage": 26, "range": 1, "cooldown": 3, "aoe_shape": "single", "aoe_size": 0, "aoe_origin": "self", "knockback": 1},
			{"skill_name": "绝招·枪出如龙", "damage": 55, "range": 1, "cooldown": 5, "aoe_shape": "square", "aoe_size": 2, "aoe_origin": "self", "is_finisher": true},
		],
	},
	{
		"id": "a_dart", "name": "小李飞刀", "school": "dart", "attribute": "阴",
		"techniques": [
			{"skill_name": "例不虚发", "damage": 30, "range": 3, "cooldown": 1, "aoe_shape": "single", "aoe_size": 0, "aoe_origin": "self"},
			{"skill_name": "连环飞刀", "damage": 28, "range": 2, "cooldown": 2, "aoe_shape": "line", "aoe_size": 0, "aoe_origin": "target"},
			{"skill_name": "满天刀雨", "damage": 26, "range": 3, "cooldown": 3, "aoe_shape": "square", "aoe_size": 1, "aoe_origin": "target"},
			{"skill_name": "绝招·一刀飞仙", "damage": 55, "range": 3, "cooldown": 5, "aoe_shape": "square", "aoe_size": 2, "aoe_origin": "target", "is_finisher": true},
		],
	},
]


static func sect_ids() -> Array[String]:
	var out: Array[String] = []
	for row in SECTS:
		out.append(row["id"] as String)
	return out


## Deep-duplicated sect row; {} if unknown.
static func sect_def(sect_id: String) -> Dictionary:
	for row in SECTS:
		if row["id"] == sect_id:
			return row.duplicate(true)
	return {}


## Full art id `<sect>_<pinyin>_<grade-lowercase>`; "" if any part is unknown.
static func art_id(sect_id: String, kind: String, grade: String) -> String:
	var sect: Dictionary = sect_def(sect_id)
	if sect.is_empty():
		return ""
	if not GRADE_SUFFIX.has(grade):
		return ""
	var pinyin: String
	if kind == "internal":
		pinyin = sect["internal_pinyin"] as String
	elif kind == "external":
		pinyin = sect["external_pinyin"] as String
	else:
		return ""
	var suffix: String = GRADE_SUFFIX[grade] as String
	return sect_id + "_" + pinyin + "_" + suffix


## Fresh GongfaData for the sect's internal art of the given grade; null if
## unknown. Internal arts are data-only: zero energy, no passive, no stats.
static func internal_art(sect_id: String, grade: String) -> Resource:
	return _build_art(sect_id, "internal", grade)


## Fresh GongfaData for the sect's external art of the given grade, with its
## generic technique stubs attached; null if unknown.
static func external_art(sect_id: String, grade: String) -> Resource:
	return _build_art(sect_id, "external", grade)


## Fresh GongfaData looked up by full art id; null if unknown. Resolves the 4
## explicit external-A ids (a_sword etc.) first, then iterates the generated
## ids. Generated external-A ids (e.g. shaolin_luohan_a) are NOT resolvable —
## _build_art refuses kind=="external" and grade=="A", so only the 9-id A pool
## (4 hand-authored external + 5 internal) resolves.
static func art_by_id(id: String) -> Resource:
	for row in EXTERNAL_A_ARTS:
		if row["id"] == id:
			return _build_external_a(row)
	for sect in SECTS:
		for kind in ["internal", "external"]:
			for grade in GRADE_SUFFIX.keys():
				var generated: String = art_id(sect["id"] as String, kind, grade)
				if generated == id:
					return _build_art(sect["id"] as String, kind, grade)
	return null


## The 9-row 甲级 pool (神功 grant pool, step2_design §4.3): the 4 external A
## ids then the 5 internal A ids, in this exact stable order.
static func a_pool() -> Array[String]:
	var out: Array[String] = []
	for row in EXTERNAL_A_ARTS:
		out.append(row["id"] as String)
	for sect in SECTS:
		out.append(art_id(sect["id"] as String, "internal", "A"))
	return out


## The external A art for a school ("sword"→a_sword / "palm"→a_palm /
## "polearm"→a_polearm / "dart"→a_dart); null for any other school
## (including "internal"). Returns a fresh Resource each call.
static func a_art_for_school(school: String) -> Resource:
	for row in EXTERNAL_A_ARTS:
		if row["school"] == school:
			return _build_external_a(row)
	return null


## The sect's internal A art (e.g. shaolin_yijin_a ·圆满); null if unknown.
static func a_art_for_sect(sect_id: String) -> Resource:
	return internal_art(sect_id, "A")


## Rendered display name of an art id (e.g. 易筋经·入门 / 罗汉拳·精进);
## "" if unknown.
static func display_name_of(id: String) -> String:
	var art = art_by_id(id)
	if art == null:
		return ""
	return art.gongfa_name


static func _build_art(sect_id: String, kind: String, grade: String) -> Resource:
	var sect: Dictionary = sect_def(sect_id)
	if sect.is_empty():
		return null
	if not GRADE_SUFFIX.has(grade):
		return null
	# External 甲 arts exist ONLY as the 4 hand-authored EXTERNAL_A_ARTS rows;
	# a generated one (e.g. shaolin_luohan_a) must not fabricate a fake
	# 罗汉拳·圆满 — this guard keeps the 9-id A pool exact.
	if kind == "external" and grade == "A":
		return null
	var base: String
	var attribute: String
	var school: String = "internal"
	if kind == "internal":
		base = sect["internal_base"] as String
		attribute = sect["internal_attribute"] as String
	elif kind == "external":
		base = sect["external_base"] as String
		attribute = sect["external_attribute"] as String
		school = sect["external_school"] as String
	else:
		return null
	var art = GongfaData.new()
	art.gongfa_name = _display_name(base, kind, grade)
	art.grade = grade
	art.kind = kind
	art.school = school
	art.attribute = attribute
	art.fa_hui_du = 1.0
	art.mastered = false
	if kind == "external":
		art.techniques = _techniques(art.gongfa_name, grade)
	else:
		art.energy_provided = 0
		art.passive_id = ""
		art.stat_bonuses = {}
	return art


## Display name: external 丁 keeps the bare base name (罗汉拳); everything
## else appends ·入门 / ·精进 / ·大成 (易筋经·入门 / 易筋经·精进 / 易筋经·大成).
static func _display_name(base: String, kind: String, grade: String) -> String:
	if kind == "external" and grade == "D":
		return base
	var step: String = GRADE_STEP[grade] as String
	return base + "·" + step


## N generic SkillData stubs for an external art: single-target, range 1,
## cooldown 1, damage per the grade table, named 一式 / 二式 / 三式.
static func _techniques(art_display_name: String, grade: String) -> Array:
	var count: int = TECHNIQUE_COUNT[grade] as int
	var damage: int = TECHNIQUE_DAMAGE[grade] as int
	var out: Array = []
	for i in range(count):
		var t = SkillData.new()
		t.skill_name = art_display_name + "·" + TECHNIQUE_NAMES[i]
		t.description = ""
		t.damage = damage
		t.range = 1
		t.cooldown = 1
		t.aoe_shape = "single"
		t.aoe_size = 0
		t.is_finisher = false
		out.append(t)
	return out


## Fresh GongfaData for an external A row (hand-authored techniques). The
## gongfa_name is the bare table name — deliberately NOT routed through
## _display_name (which would append ·圆满).
static func _build_external_a(row: Dictionary) -> Resource:
	var art = GongfaData.new()
	art.gongfa_name = row["name"] as String
	art.grade = "A"
	art.kind = "external"
	art.school = row["school"] as String
	art.attribute = row["attribute"] as String
	art.fa_hui_du = 1.0
	art.mastered = false
	art.techniques = _a_techniques(row["techniques"] as Array)
	return art


## SkillData rows for an external A technique table (step2_design §4.3 fields).
static func _a_techniques(rows: Array) -> Array:
	var out: Array = []
	for spec in rows:
		var t = SkillData.new()
		t.skill_name = spec.get("skill_name", "")
		t.description = ""
		t.damage = spec.get("damage", 0)
		t.range = spec.get("range", 1)
		t.cooldown = spec.get("cooldown", 1)
		t.aoe_shape = spec.get("aoe_shape", "single")
		t.aoe_size = spec.get("aoe_size", 0)
		t.aoe_origin = spec.get("aoe_origin", "self")
		t.knockback = spec.get("knockback", 0)
		t.ignore_damage_reduction = spec.get("ignore_damage_reduction", false)
		t.is_finisher = spec.get("is_finisher", false)
		out.append(t)
	return out
