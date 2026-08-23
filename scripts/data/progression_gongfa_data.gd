class_name ProgressionGongfaData

## Registry of the progression gongfa rows: 5 sects × (internal + external) ×
## 丁丙乙 = 30 arts (design/40_progression.md §2.4 + step2_design §2.2).
## Pure data layer — practice/mastery bookkeeping, sect grants and the
## year-end grade ladder belong to cultivation; this file only supplies the
## rows, the 丁4/丙6/乙8 practice table, the year→grade map, and the generic
## external technique stubs (丁1 / 丙2 / 乙3, damage 丁18 / 丙22 / 乙26).
##
## NOTE on typing: GongfaData / SkillData are NOT class_name-registered — they
## are preloaded constants (see tests/test_gongfa_cascade.gd header). Never
## annotate a variable or return with them (parse error); type such values as
## Resource / Variant and assign with plain `=`.

const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const SkillData = preload("res://scripts/data/skill_data.gd")

## Months of 练功 required to master a gongfa, by grade (step2_design §2.2).
const PRACTICE_TO_MASTER := {"D": 4, "C": 6, "B": 8}

## Grade granted at the start of each cultivation year (index = year - 1,
## so year 2 → "C", year 3 → "B").
const GRADE_BY_YEAR := ["D", "C", "B"]

## Grade letter → art-id suffix (ids are lowercase, e.g. shaolin_yijin_d).
const GRADE_SUFFIX := {"D": "d", "C": "c", "B": "b"}

## Grade letter → display step (丁 入门 / 丙 精进 / 乙 大成).
const GRADE_STEP := {"D": "入门", "C": "精进", "B": "大成"}

## Generic external technique stubs: count and damage per grade
## (step2_design §2.2: 丁1/丙2/乙3 techniques, damage 丁18/丙22/乙26).
const TECHNIQUE_COUNT := {"D": 1, "C": 2, "B": 3}
const TECHNIQUE_DAMAGE := {"D": 18, "C": 22, "B": 26}
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


## Fresh GongfaData looked up by full art id; null if unknown. Iterates the
## 30 generated ids rather than string-parsing, so any pinyin value works.
static func art_by_id(id: String) -> Resource:
	for sect in SECTS:
		for kind in ["internal", "external"]:
			for grade in GRADE_SUFFIX.keys():
				var generated: String = art_id(sect["id"] as String, kind, grade)
				if generated == id:
					return _build_art(sect["id"] as String, kind, grade)
	return null


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
