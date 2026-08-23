class_name BattleSetup

## Progression-side battle setup (step2_design §7 / task plan battle_setup):
## derives battle stats from a PlayerProfile via the design formulas and builds
## a CharacterData for an encounter battle. Pure data layer — no scene-tree or
## autoload dependency; unit-tested by tests/test_battle_setup.gd.
##
## Formulas (design/40_progression.md §7 + step2_design §2.2):
##   气血 = 根骨×5, 内力值 = 内力×2, 移动力 = 2 + floor(身法/20),
##   先攻 = 身法, 普攻 = 10 + 根骨,
##   attack_range = 1 (主外功近战门派) / 2 (远程门派: 唐门/暗器).
## Techniques come from progression_gongfa_data.gd's generic grade stubs
## (丁1 / 丙2 / 乙3); GongfaData.mastered mirrors the profile's mastered flags.

const CharacterData = preload("res://scripts/data/character_data.gd")
const ProgressionGongfaData = preload("res://scripts/data/progression_gongfa_data.gd")

## Melee weapon classes (mirror of CombatManager.MELEE_SCHOOLS; kept local so
## this data layer has no autoload dependency). Ranged = everything else —
## in the progression table that is 唐门/暗器 (school "dart") only.
const _MELEE_SCHOOLS: Array[String] = [
	"sword", "blade", "polearm", "palm", "qinggong", "hardening",
]


## Derive the battle stats for a PlayerProfile. Returns a Dictionary with
## max_health / energy / move_range / initiative / attack_damage / attack_range.
static func derive_stats(profile) -> Dictionary:
	var bone: int = _attr(profile, "bone")
	var inner: int = _attr(profile, "inner")
	var agility: int = _attr(profile, "agility")
	return {
		"max_health": bone * 5,
		"energy": inner * 2,
		"move_range": 2 + int(floor(float(agility) / 20.0)),
		"initiative": agility,
		"attack_damage": 10 + bone,
		"attack_range": _attack_range_for(profile),
	}


## Build a CharacterData for an encounter battle from a PlayerProfile.
## staged_values=false (the real 甲乙丙丁 cascade applies); gongfa rows map to
## fresh GongfaData resources with mastered mirrored from the profile; skills
## are the external arts' generic grade techniques. Passive comes from the
## primary internal art when the art declares one (progression internal arts
## carry none this round, so it stays "").
static func build_character(profile) -> Resource:
	var stats: Dictionary = derive_stats(profile)
	var cd = CharacterData.new()
	cd.character_name = "ProgressionHero"
	cd.display_name = "侠客"
	cd.max_health = int(stats.max_health)
	cd.energy = int(stats.energy)
	cd.move_range = int(stats.move_range)
	cd.attack_damage = int(stats.attack_damage)
	cd.attack_range = int(stats.attack_range)
	cd.initiative = int(stats.initiative)
	cd.team = 0
	cd.staged_values = false

	var internal_arts: Array = []
	var external_arts: Array = []
	var skills: Array = []
	for entry in profile.gongfa:
		var art_id: String = str(entry.get("id", ""))
		if art_id == "":
			continue
		var art = ProgressionGongfaData.art_by_id(art_id)
		if art == null:
			continue
		art.mastered = bool(entry.get("mastered", false))
		if str(art.kind) == "internal":
			internal_arts.append(art)
			if str(art.passive_id) != "":
				cd.passive_id = str(art.passive_id)
		else:
			external_arts.append(art)
			skills += art.techniques
	cd.internal_arts = internal_arts
	cd.external_arts = external_arts
	cd.skills = skills
	return cd


## Profile attr with a safe int coercion (fallback 10).
static func _attr(profile, key: String) -> int:
	var v: Variant = profile.attrs.get(key, 10)
	if v is int:
		return v
	return 10


## attack_range from the main external art's school: 2 for ranged schools
## (唐门/暗器, i.e. "dart" — the only ranged sect in the progression table),
## else 1. Falls back to the first external gongfa row, then to melee.
static func _attack_range_for(profile) -> int:
	return 2 if _school_is_ranged(_main_external_school(profile)) else 1


static func _school_is_ranged(school: String) -> bool:
	return not _MELEE_SCHOOLS.has(school)


## School of the profile's main external art (main_external_id, else the first
## external gongfa row); "palm" (melee) as the conservative default.
static func _main_external_school(profile) -> String:
	var main_id: String = str(profile.main_external_id)
	if main_id != "":
		var art = ProgressionGongfaData.art_by_id(main_id)
		if art != null and str(art.kind) == "external":
			return str(art.school)
	for entry in profile.gongfa:
		var art_id: String = str(entry.get("id", ""))
		if art_id == "":
			continue
		var art = ProgressionGongfaData.art_by_id(art_id)
		if art != null and str(art.kind) == "external":
			return str(art.school)
	return "palm"
