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
## Consumers: scripts/battlefield.gd:651 BattleSetup.build_character(SaveManager.profile)
## at encounter entry (the live caller), and tests/test_battle_setup.gd /
## tests/test_battle_setup_equipment.gd (unit suite).
## Equipped gear participates via EquipmentData.sum_bonuses in derive_stats;
## empty/legacy-equipped profiles produce output bit-identical to the base
## formulas above (reversibility baseline, unit-pinned).

const CharacterData = preload("res://scripts/data/character_data.gd")
const EquipmentData = preload("res://scripts/data/equipment_data.gd")
const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const ProgressionGongfaData = preload("res://scripts/data/progression_gongfa_data.gd")
const ProgressionMath = preload("res://scripts/data/progression_math.gd")
const MapData = preload("res://scripts/data/map_data.gd")

## Melee weapon classes (mirror of CombatManager.MELEE_SCHOOLS; kept local so
## this data layer has no autoload dependency). Ranged = everything else —
## in the progression table that is 唐门/暗器 (school "dart") only.
const _MELEE_SCHOOLS: Array[String] = [
	"sword", "blade", "polearm", "palm", "qinggong", "hardening",
]


## Derive the battle stats for a PlayerProfile. Returns a Dictionary with
## max_health / energy / move_range / initiative / attack_damage / attack_range.
##
## R3b C5 unlock (owner ruling 2026-09-02) CANCELS the R3 D4 rule
## ("mp 不进 move_range / attack_damage，保持质感"): three years of cultivation
## may now cash out into movement and damage as well. mp =
## ProgressionMath.mastery_points(profile) (sum of GRADE_POINTS over MASTERED
## gongfa rows) feeds:
##   attack_damage += 2 * mp   (a fresh mp = 0 profile reproduces the old
##                              formula EXACTLY — property-pinned in
##                              tests/test_battle_setup.gd)
##   move_range    += floor(mp / 3)   (six mastered D-grade arts = mp 6 ->
##                              move 4, the measured threshold at which a
##                              melee hero closes the M3'' spawn ring)
## max_health / energy / initiative / attack_range terms are UNCHANGED.
## EquipmentData.sum_bonuses returns keys attack/health/initiative/move ONLY —
## there is NO energy field, so energy = inner*2 + 4*mp (the gear energy bonus
## does not exist). Per-literal measurement table: design/40_progression.md
## M3'' (supersedes the R3 D4 note).
static func derive_stats(profile) -> Dictionary:
	var bone: int = _attr(profile, "bone")
	var inner: int = _attr(profile, "inner")
	var agility: int = _attr(profile, "agility")
	var mp: int = ProgressionMath.mastery_points(profile)
	var gear: Dictionary = EquipmentData.sum_bonuses(profile.get("equipped") if profile.get("equipped") != null else {})
	return {
		"max_health": bone * 5 + 18 * mp + int(gear.get("health", 0)),
		"energy": inner * 2 + 4 * mp,
		"move_range": 2 + int(floor(float(agility) / 20.0)) + int(floor(float(mp) / 2.0)) + int(gear.get("move", 0)),
		"initiative": agility + 3 * mp + int(gear.get("initiative", 0)),
		"attack_damage": 10 + bone + 12 * mp + int(gear.get("attack", 0)),
		"attack_range": _attack_range_for(profile),
	}


## Huashan readiness verdict (R3 D4). Pure, zero RNG. Wraps derive_stats so the
## warning can never drift from the numbers the duel actually uses (one formula
## source). power = ProgressionMath.readiness_power(derive_stats(profile));
## verdict_key against MapData.HUASHAN_BAR: power < E -> "huashan_weak";
## E <= power < S -> "huashan_even"; power >= S -> "huashan_strong".
static func readiness(profile) -> Dictionary:
	var stats: Dictionary = derive_stats(profile)
	var power: int = ProgressionMath.readiness_power(stats)
	var bar: Dictionary = MapData.HUASHAN_BAR
	var even: int = int(bar.get("even", 0))
	var strong: int = int(bar.get("strong", 0))
	var verdict_key: String = "huashan_strong"
	if power < even:
		verdict_key = "huashan_weak"
	elif power < strong:
		verdict_key = "huashan_even"
	return {"power": power, "verdict_key": verdict_key}


## Build a CharacterData for an encounter battle from a PlayerProfile.
## Profile traits are copied onto the CharacterData (battle-side trait carrier);
## gongfa rows map to fresh GongfaData resources with mastered mirrored from the
## profile. External arts are sorted by grade rank (甲 first, ties kept in
## profile order) and only the first 2 (or 3 with 左右互搏/ambidextrous) are
## EQUIPPED — skills are the equipped external arts' techniques only. Passive
## comes from the primary internal art when the art declares one (progression
## internal arts carry none this round, so it stays "").
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
	cd.traits = profile.traits.duplicate()

	var gear: Dictionary = EquipmentData.sum_bonuses(profile.get("equipped") if profile.get("equipped") != null else {})
	cd.gear_attack_bonus = int(gear.get("attack", 0))
	cd.gear_health_bonus = int(gear.get("health", 0))
	cd.gear_initiative_bonus = int(gear.get("initiative", 0))
	cd.gear_move_bonus = int(gear.get("move", 0))

	var internal_arts: Array = []
	var all_external: Array = []
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
			all_external.append(art)

	# Carry the FULL known external-arts list (same art instances, mastered flags
	# already mirrored above) so GongfaData.get_fa_hui_du()'s prerequisite cascade
	# sees every art the character knows — including lower grades dropped by the
	# equip slice. `external_arts` below stays the grade-sorted EQUIPPED slice
	# (primary-art melee classification and skill->art matching read only it).
	cd.all_external_arts = all_external

	# Equip the highest-grade external arts: stable grade-rank sort (A=甲 first,
	# ties keep profile order — GDScript sort_custom is NOT stable, so use the
	# private insertion sort), then keep the first 2 — or 3 with ambidextrous.
	var equipped: Array = _sort_by_grade_rank(all_external)
	var cap: int = 3 if profile.has_trait("ambidextrous") else 2
	cd.external_arts = equipped.slice(0, cap)
	var skills: Array = []
	for art in cd.external_arts:
		skills += art.techniques
	cd.skills = skills
	cd.internal_arts = internal_arts
	return cd


## Stable ascending sort by GongfaData.GRADE_RANK (A=0 first); grade ties keep
## the original (profile insertion) order. Insertion sort is stable — the
## engine's sort_custom is not.
static func _sort_by_grade_rank(arts: Array) -> Array:
	var out: Array = []
	for art in arts:
		var rank: int = GongfaData.GRADE_RANK.get(str(art.grade), 99)
		var inserted := false
		for i in range(out.size()):
			if rank < int(GongfaData.GRADE_RANK.get(str(out[i].grade), 99)):
				out.insert(i, art)
				inserted = true
				break
		if not inserted:
			out.append(art)
	return out


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
