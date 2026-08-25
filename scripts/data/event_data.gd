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


## 16 event rows; option fields: {"label", "effects": [...]}.
## 4 baseline rows (step2_design §8.6 verbatim: bandits / merchant / ruins /
## beggar) + 12 expansion rows (step2_design §5: tomb_bed ... lost_purse).
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
	{
		"id": "tomb_bed", "title": "古墓寒玉",
		"text": "荒山之中藏着一座古墓，\n石室中央横着一张寒玉床。",
		"option_a": {"label": "卧床练气", "effects": [{"type": "attr", "value": 2, "target": "inner"}]},
		"option_b": {"label": "床畔拾剑", "effects": [{"type": "item", "value": 0, "target": "eq_sword_2"}]},
	},
	{
		"id": "wounded_eagle", "title": "神雕负伤",
		"text": "一只巨雕伏在崖边，\n翅上箭伤未愈，目光如炬。",
		"option_a": {"label": "施药疗伤", "effects": [{"type": "silver", "value": -8, "target": ""}, {"type": "practice", "value": 2, "target": ""}]},
		"option_b": {"label": "静观其变", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "peach_maze", "title": "桃花迷阵",
		"text": "海岛风送来桃花香，\n花影错落，隐成阵势。",
		"option_a": {"label": "循隙闯阵", "effects": [{"type": "attr", "value": 2, "target": "agility"}]},
		"option_b": {"label": "阵外观潮", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "snake_bile", "title": "蛇胆奇效",
		"text": "白驼山弟子叫卖蛇胆，\n称其大补真元，价钱不菲。",
		"option_a": {"label": "重金购之", "effects": [{"type": "silver", "value": -15, "target": ""}, {"type": "attr", "value": 2, "target": "bone"}]},
		"option_b": {"label": "掉头就走", "effects": [{"type": "attr", "value": 1, "target": "fortune"}]},
	},
	{
		"id": "dragon_scrap", "title": "降龙残谱",
		"text": "书摊上一册残破掌谱，\n隐见「降龙」二字，纸色发黄。",
		"option_a": {"label": "强记于心", "effects": [{"type": "practice", "value": 4, "target": ""}]},
		"option_b": {"label": "卖与书贾", "effects": [{"type": "silver", "value": 25, "target": ""}]},
	},
	{
		"id": "flood_ferry", "title": "渡口风波",
		"text": "河水暴涨，渡口只余一舟，\n艄公索价甚高，爱搭不理。",
		"option_a": {"label": "付钱渡河", "effects": [{"type": "silver", "value": -10, "target": ""}]},
		"option_b": {"label": "泅水而过", "effects": [{"type": "attr", "value": 1, "target": "inner"}]},
	},
	{
		"id": "escort_job", "title": "镖行招募",
		"text": "镖头缺人手，见你身手，\n便邀你押一趟去南边的镖。",
		"option_a": {"label": "接下镖单", "effects": [{"type": "silver", "value": 22, "target": ""}]},
		"option_b": {"label": "婉拒独行", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "dali_market", "title": "大理市集",
		"text": "市集上皮甲快靴俱全，\n掌柜的拍着胸脯称分量十足。",
		"option_a": {"label": "购皮甲", "effects": [{"type": "silver", "value": -18, "target": ""}, {"type": "item", "value": 0, "target": "eq_armor_2"}, {"type": "attr", "value": 1, "target": "bone"}]},
		"option_b": {"label": "购快靴", "effects": [{"type": "silver", "value": -14, "target": ""}, {"type": "item", "value": 0, "target": "eq_boots_2"}]},
	},
	{
		"id": "night_rain", "title": "破庙夜雨",
		"text": "夜雨滂沱，破庙漏得厉害，\n老僧独坐，就着灯火补屋檐。",
		"option_a": {"label": "帮工换宿", "effects": [{"type": "silver", "value": -6, "target": ""}, {"type": "attr", "value": 1, "target": "bone"}]},
		"option_b": {"label": "檐下练剑", "effects": [{"type": "practice", "value": 2, "target": ""}]},
	},
	{
		"id": "gambling_den", "title": "赌坊喧嚣",
		"text": "镇上赌坊彻夜喧闹，\n有人一夜输光了全部盘缠。",
		"option_a": {"label": "入局三把", "effects": [{"type": "silver", "value": 30, "target": ""}]},
		"option_b": {"label": "袖手旁观", "effects": [{"type": "attr", "value": 2, "target": "fortune"}]},
	},
	{
		"id": "quanzhen_scripture", "title": "全真抄经",
		"text": "全真宫外老道伏案抄经，\n见你驻足，递来一卷道德经。",
		"option_a": {"label": "随他抄经", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
		"option_b": {"label": "求教剑理", "effects": [{"type": "silver", "value": -5, "target": ""}, {"type": "practice", "value": 3, "target": ""}]},
	},
	{
		"id": "lost_purse", "title": "遗落的褡裢",
		"text": "路旁褡裢里散着银两，\n四下无人，只有风声掠过草叶。",
		"option_a": {"label": "送还失主", "effects": [{"type": "attr", "value": 2, "target": "fortune"}]},
		"option_b": {"label": "收起走人", "effects": [{"type": "silver", "value": 20, "target": ""}]},
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
