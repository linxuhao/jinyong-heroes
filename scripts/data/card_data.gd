class_name CardData

## Card pools for the cultivation month loop (step2_design §8.5): monthly
## economy / equipment / growth decks plus yearly power / trait / artifact
## decks. Pure data layer — deck state (remaining/drawn) lives in the save;
## this file only supplies the unique def rows, deck composition with
## multiplicities, and the dynamic trait-deck builder.
##
## The trait deck is dynamic (up to 8 unowned positive traits); it has no
## static TABLE rows — initial_deck("trait") is [] and def() synthesizes a
## CardDef on the fly from TraitData.positive_ids().

class CardDef extends RefCounted:
	var id: String = ""
	var display_name: String = ""
	var category: String = ""      # one of CATEGORIES
	var effect_type: String = ""   # "silver"|"attr"|"practice"|"item"|"trait"|"tech_unlock"|"shen_gong"|"none"
	var effect_value: int = 0      # silver / attr delta / practice delta
	var effect_target: String = "" # attr key for "attr"; item id for "item" (== card id); "" otherwise


const CATEGORIES := ["economy", "equipment", "growth", "power", "trait", "artifact"]

## Unique def rows in deck order; "count" is the deck multiplicity.
## Deck sizes: economy 12, equipment 12, growth 9, power 6, artifact 6.
## (step2 §8.5 lists "growth 12" nominally but only 9 rows are defined —
## the rows are authoritative; see task_plan 风险.)
const TABLE: Array = [
	# economy (4+3+2+3 = 12)
	{"id": "eco_20", "display_name": "一袋碎银", "category": "economy", "count": 4, "effect_type": "silver", "effect_value": 20, "effect_target": ""},
	{"id": "eco_50", "display_name": "半锭纹银", "category": "economy", "count": 3, "effect_type": "silver", "effect_value": 50, "effect_target": ""},
	{"id": "eco_100", "display_name": "一锭元宝", "category": "economy", "count": 2, "effect_type": "silver", "effect_value": 100, "effect_target": ""},
	{"id": "eco_trade_1", "display_name": "行商分成", "category": "economy", "count": 1, "effect_type": "silver", "effect_value": 40, "effect_target": ""},
	{"id": "eco_trade_2", "display_name": "行商分成", "category": "economy", "count": 1, "effect_type": "silver", "effect_value": 60, "effect_target": ""},
	{"id": "eco_trade_3", "display_name": "行商分成", "category": "economy", "count": 1, "effect_type": "silver", "effect_value": 80, "effect_target": ""},
	# equipment (4+4+4 = 12; recorded in inventory, data-only this round)
	{"id": "eq_sword_1", "display_name": "铁剑", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_sword_1"},
	{"id": "eq_sword_2", "display_name": "精铁剑", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_sword_2"},
	{"id": "eq_sword_3", "display_name": "青锋剑", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_sword_3"},
	{"id": "eq_sword_4", "display_name": "长剑", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_sword_4"},
	{"id": "eq_armor_1", "display_name": "布衣", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_armor_1"},
	{"id": "eq_armor_2", "display_name": "皮甲", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_armor_2"},
	{"id": "eq_armor_3", "display_name": "锁子甲", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_armor_3"},
	{"id": "eq_armor_4", "display_name": "软猬甲", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_armor_4"},
	{"id": "eq_boots_1", "display_name": "草鞋", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_boots_1"},
	{"id": "eq_boots_2", "display_name": "快靴", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_boots_2"},
	{"id": "eq_boots_3", "display_name": "踏云履", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_boots_3"},
	{"id": "eq_boots_4", "display_name": "凌波靴", "category": "equipment", "count": 1, "effect_type": "item", "effect_value": 0, "effect_target": "eq_boots_4"},
	# growth (5+2+1+1 = 9)
	{"id": "gr_attr_bone", "display_name": "根骨淬炼", "category": "growth", "count": 1, "effect_type": "attr", "effect_value": 1, "effect_target": "bone"},
	{"id": "gr_attr_inner", "display_name": "内力充盈", "category": "growth", "count": 1, "effect_type": "attr", "effect_value": 1, "effect_target": "inner"},
	{"id": "gr_attr_agility", "display_name": "身法灵动", "category": "growth", "count": 1, "effect_type": "attr", "effect_value": 1, "effect_target": "agility"},
	{"id": "gr_attr_wisdom", "display_name": "悟性顿开", "category": "growth", "count": 1, "effect_type": "attr", "effect_value": 1, "effect_target": "wisdom"},
	{"id": "gr_attr_fortune", "display_name": "福缘临身", "category": "growth", "count": 1, "effect_type": "attr", "effect_value": 1, "effect_target": "fortune"},
	{"id": "gr_practice_2", "display_name": "苦修心得", "category": "growth", "count": 2, "effect_type": "practice", "effect_value": 2, "effect_target": ""},
	{"id": "gr_trait_pool", "display_name": "机缘悟道", "category": "growth", "count": 1, "effect_type": "trait", "effect_value": 0, "effect_target": ""},
	{"id": "gr_silver_30", "display_name": "一袋盘缠", "category": "growth", "count": 1, "effect_type": "silver", "effect_value": 30, "effect_target": ""},
	# power (yearly, 2+2+2 = 6)
	{"id": "pw_practice_4", "display_name": "闭关潜修", "category": "power", "count": 2, "effect_type": "practice", "effect_value": 4, "effect_target": ""},
	{"id": "pw_attr_3", "display_name": "脱胎换骨", "category": "power", "count": 2, "effect_type": "attr", "effect_value": 3, "effect_target": "bone"},
	{"id": "pw_tech_unlock", "display_name": "招式顿悟", "category": "power", "count": 2, "effect_type": "tech_unlock", "effect_value": 0, "effect_target": ""},
	# artifact (yearly, 3+2+1 = 6)
	{"id": "art_ding_speed", "display_name": "仙丹妙药", "category": "artifact", "count": 3, "effect_type": "practice", "effect_value": 6, "effect_target": ""},
	{"id": "art_shen_gong", "display_name": "失传神功", "category": "artifact", "count": 2, "effect_type": "shen_gong", "effect_value": 0, "effect_target": ""},
	{"id": "art_silver_500", "display_name": "前朝宝藏", "category": "artifact", "count": 1, "effect_type": "silver", "effect_value": 500, "effect_target": ""},
]


## Fresh CardDef for an id; null if unknown. Trait ids from
## TraitData.positive_ids() are synthesized dynamically (no TABLE row).
static func def(id: String) -> CardDef:
	for row in TABLE:
		if row["id"] == id:
			return _build(row)
	if TraitData.positive_ids().has(id):
		return _build_trait(id)
	return null


## Fresh CardDef per unique TABLE row of a category (no multiplicity expansion).
static func defs_in_category(cat: String) -> Array[CardDef]:
	var out: Array[CardDef] = []
	for row in TABLE:
		if row["category"] == cat:
			out.append(_build(row))
	return out


## Initial deck: ids expanded by "count" in TABLE order. Trait deck is dynamic
## → always [] (use build_trait_deck).
static func initial_deck(cat: String) -> Array[String]:
	var out: Array[String] = []
	if cat == "trait":
		return out
	for row in TABLE:
		if row["category"] == cat:
			var count: int = row["count"] as int
			var id: String = row["id"] as String
			for i in range(count):
				out.append(id)
	return out


## Deck multiplicity (sum of counts); trait → 0 (dynamic).
static func deck_size(cat: String) -> int:
	if cat == "trait":
		return 0
	var total: int = 0
	for row in TABLE:
		if row["category"] == cat:
			total += row["count"] as int
	return total


## Trait deck = TraitData.positive_ids() minus already-owned ids, in table
## order (owned traits are excluded BEFORE drawing, never offered again).
static func build_trait_deck(owned_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id in TraitData.positive_ids():
		if not owned_ids.has(id):
			out.append(id)
	return out


static func _build(row: Dictionary) -> CardDef:
	var def := CardDef.new()
	def.id = row["id"] as String
	def.display_name = row["display_name"] as String
	def.category = row["category"] as String
	def.effect_type = row["effect_type"] as String
	def.effect_value = row["effect_value"] as int
	def.effect_target = row["effect_target"] as String
	return def


static func _build_trait(id: String) -> CardDef:
	var trait_def = TraitData.get_def(id)
	var def := CardDef.new()
	def.id = id
	def.display_name = trait_def.display_name
	def.category = "trait"
	def.effect_type = "trait"
	def.effect_value = 0
	def.effect_target = ""
	return def
