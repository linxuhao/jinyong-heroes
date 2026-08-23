class_name EventData

## 游历 (travel) event pool — first batch of 4 events, 2 options each
## (step2_design §8.6). Pure data layer — event resolution (RNG draw, no
## repeat until pool exhausted, consequence application) belongs to the
## cultivation segment; this file only supplies the rows.

class EventOption extends RefCounted:
	var label: String = ""
	var effects: Array[Dictionary] = []  # each {"type": "silver"|"attr"|"item"|"practice"|"none", "value": int, "target": String}
	var battle_id: Variant = null        # reserved stub (null = no battle this round)


class EventDef extends RefCounted:
	var id: String = ""
	var title: String = ""
	var text: String = ""                # 2–3 line Chinese body
	var option_a: EventOption
	var option_b: EventOption


## 4 event rows; option fields: {"label", "effects": [...]}.
## (step2_design §8.6 verbatim: bandits / merchant / ruins / beggar.)
const TABLE: Array = [
	{
		"id": "bandits", "title": "山道遇劫匪",
		"text": "行至山道，一伙劫匪拦住去路。\n为首之人手提钢刀，索要买路财。",
		"option_a": {"label": "破财消灾", "effects": [{"type": "silver", "value": -10, "target": ""}]},
		"option_b": {"label": "出手退敌", "effects": [{"type": "attr", "value": 1, "target": "bone"}]},
	},
	{
		"id": "merchant", "title": "行商路过",
		"text": "一位行商赶着马车路过，\n车上满载刀剑兵刃，正愁销路。",
		"option_a": {"label": "买下长剑", "effects": [{"type": "silver", "value": -20, "target": ""}, {"type": "item", "value": 0, "target": "eq_sword_3"}]},
		"option_b": {"label": "婉拒", "effects": [{"type": "none", "value": 0, "target": ""}]},
	},
	{
		"id": "ruins", "title": "古墓残碑",
		"text": "荒野深处露出一角残碑，\n碑文似与古墓武学有关。",
		"option_a": {"label": "入内参悟", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
		"option_b": {"label": "谨慎绕行", "effects": [{"type": "attr", "value": 1, "target": "fortune"}]},
	},
	{
		"id": "beggar", "title": "老丐乞食",
		"text": "巷口一名老丐伸手乞食，\n目光却在你身上暗暗打量。",
		"option_a": {"label": "施舍", "effects": [{"type": "silver", "value": -5, "target": ""}, {"type": "attr", "value": 1, "target": "fortune"}]},
		"option_b": {"label": "切磋武学", "effects": [{"type": "practice", "value": 2, "target": ""}]},
	},
]


## Fresh EventDef instances, table order.
static func all() -> Array[EventDef]:
	var out: Array[EventDef] = []
	for row in TABLE:
		out.append(_build(row))
	return out


## Fresh EventDef for an id; null if unknown.
static func def(id: String) -> EventDef:
	for row in TABLE:
		if row["id"] == id:
			return _build(row)
	return null


static func _build(row: Dictionary) -> EventDef:
	var def := EventDef.new()
	def.id = row["id"] as String
	def.title = row["title"] as String
	def.text = row["text"] as String
	def.option_a = _build_option(row["option_a"] as Dictionary)
	def.option_b = _build_option(row["option_b"] as Dictionary)
	return def


static func _build_option(row: Dictionary) -> EventOption:
	var opt := EventOption.new()
	opt.label = row["label"] as String
	var effects: Array = row["effects"] as Array
	var out: Array[Dictionary] = []
	for e in effects:
		out.append((e as Dictionary).duplicate(true))
	opt.effects = out
	opt.battle_id = row.get("battle_id", null)
	return opt
