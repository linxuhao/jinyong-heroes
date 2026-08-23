class_name TraitData

## Registry of the 13 innate traits / flaws (先天特质与缺陷) from
## design/40_progression.md §2.2, with costs and stable hook ids from
## step2_design C7. Pure data layer — hook EXECUTION (e.g. lone_bane
## suppressing a sect's internal gongfa) belongs to later subtasks
## (sect_select / cultivation); this file only supplies the data rows.
##
## Positive traits have cost > 0 (spend creation points); flaws have cost < 0
## (refund points). The table is a const so it can never be mutated; all()
## returns fresh TraitDef instances each call.

class TraitDef extends RefCounted:
	var id: String = ""
	var display_name: String = ""   # Chinese name (rendered UI text, design/30_presentation.md)
	var cost: int = 0               # >0 positive trait; <0 flaw (refund)
	var hooks: Array[String] = []   # stable effect-hook ids (extension points; data-only this round)


const TABLE: Array = [
	{"id": "ambidextrous", "display_name": "左右互搏", "cost": 10, "hooks": ["skill_bar_3_arts"]},
	{"id": "self_taught", "display_name": "无师自通", "cost": 10, "hooks": ["bypass_prereq_learn"]},
	{"id": "gifted_bones", "display_name": "骨骼清奇", "cost": 8, "hooks": ["dual_main_internal"]},
	{"id": "photographic_memory", "display_name": "过目不忘", "cost": 8, "hooks": ["self_learn_watched"]},
	{"id": "iron_shirt", "display_name": "铁布衫", "cost": 7, "hooks": ["fatal_guard_once"]},
	{"id": "swallow_lightness", "display_name": "身轻如燕", "cost": 6, "hooks": ["pass_through_enemies"]},
	{"id": "worldly_experience", "display_name": "江湖阅历", "cost": 6, "hooks": ["map_inquire"]},
	{"id": "deep_fortune", "display_name": "福缘深厚", "cost": 5, "hooks": ["yearly_event_reroll"]},
	{"id": "sha_po_lang", "display_name": "杀破狼", "cost": -6, "hooks": ["solo_only"]},
	{"id": "old_wound", "display_name": "旧伤", "cost": -8, "hooks": ["no_finishers"]},
	{"id": "inner_demon", "display_name": "心魔", "cost": -8, "hooks": ["hp30_chaos"]},
	{"id": "lone_bane", "display_name": "孤煞", "cost": -6, "hooks": ["no_internal_from_sect"]},
	{"id": "dull_sinews", "display_name": "筋骨迟钝", "cost": -5, "hooks": ["no_lightfoot_school"]},
]


## 13 fresh TraitDef instances, in table order. Callers may mutate the returned
## instances freely without polluting the registry (each build duplicates the
## hooks array too).
static func all() -> Array[TraitDef]:
	var out: Array[TraitDef] = []
	for row in TABLE:
		out.append(_build(row))
	return out


static func get_def(id: String) -> TraitDef:
	for row in TABLE:
		if row["id"] == id:
			return _build(row)
	return null


static func cost_of(id: String) -> int:
	for row in TABLE:
		if row["id"] == id:
			return row["cost"] as int
	return 0


static func is_flaw(id: String) -> bool:
	for row in TABLE:
		if row["id"] == id:
			return (row["cost"] as int) < 0
	return false


## The 8 positive trait ids, in table order.
static func positive_ids() -> Array[String]:
	var out: Array[String] = []
	for row in TABLE:
		if (row["cost"] as int) > 0:
			out.append(row["id"] as String)
	return out


static func _build(row: Dictionary) -> TraitDef:
	var def := TraitDef.new()
	def.id = row["id"] as String
	def.display_name = row["display_name"] as String
	def.cost = row["cost"] as int
	var hooks_src: Array = row["hooks"] as Array
	var hooks_out: Array[String] = []
	for h in hooks_src:
		if h is String:
			hooks_out.append(h as String)
	def.hooks = hooks_out
	return def
