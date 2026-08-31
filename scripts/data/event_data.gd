class_name EventData

## 游历 (travel) event pool — 36 rows, 2 options each
## 36-row pool = full 36-month journey (4 baseline + 12 expansion rows + 20 appended 2026-08-31, jinyong-event-pool-36). Pure data layer — event resolution (RNG draw, no
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


## 36 event rows; option fields: {"label", "effects": [...]}.
## 16 frozen rows (step2_design §8.6 verbatim: bandits / merchant / ruins /
## beggar + 12 expansion: tomb_bed ... lost_purse)
## + 20 appended rows 2026-08-31 (jinyong-event-pool-36: riverside_duel ... fallen_rider).
const TABLE: Array = [
	{
		"id": "bandits", "title": "山道遇劫",
		"text": "行至山道，一伙拦路的虾截住去路。\n为首一只长钳提着钢刀，索要买路财。",
		"option_a": {"label": "破财消灾", "effects": [{"type": "silver", "value": -10, "target": ""}]},
		"option_b": {"label": "出手退敌", "effects": [{"type": "attr", "value": 1, "target": "bone"}]},
	},
	{
		"id": "merchant", "title": "车马过路",
		"text": "一只虾赶着马车路过，\n钳里挽着缰绳，满载刀剑兵刃正愁销路。",
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
		"id": "beggar", "title": "巷口乞食",
		"text": "巷口一只老虾伸钳乞食，\n触须低垂，复眼却在你身上暗暗打量。",
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
		"text": "白驼山来的虾客叫卖蛇胆，\n药袋挂在触须上，称大补真元，价钱不菲。",
		"option_a": {"label": "重金购之", "effects": [{"type": "silver", "value": -15, "target": ""}, {"type": "attr", "value": 2, "target": "bone"}]},
		"option_b": {"label": "掉头就走", "effects": [{"type": "attr", "value": 1, "target": "fortune"}]},
	},
	{
		"id": "dragon_scrap", "title": "降龙残谱",
		"text": "书摊上一册残破掌谱，\n隐见「降龙」二字，纸色发黄。",
		"option_a": {"label": "强记于心", "effects": [{"type": "practice", "value": 4, "target": ""}]},
		"option_b": {"label": "卖与书铺", "effects": [{"type": "silver", "value": 25, "target": ""}]},
	},
	{
		"id": "flood_ferry", "title": "渡口风波",
		"text": "河水暴涨，渡口只余一舟，\n一只虾撑舟而立，索价甚高，爱搭不理。",
		"option_a": {"label": "付钱渡河", "effects": [{"type": "silver", "value": -10, "target": ""}]},
		"option_b": {"label": "泅水而过", "effects": [{"type": "attr", "value": 1, "target": "inner"}]},
	},
	{
		"id": "escort_job", "title": "镖行招募",
		"text": "镖局里一只虾头领缺个帮工，见你身手，\n便邀你押一趟去南边的镖。",
		"option_a": {"label": "接下镖单", "effects": [{"type": "silver", "value": 22, "target": ""}]},
		"option_b": {"label": "婉拒独行", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "dali_market", "title": "大理市集",
		"text": "市集上皮甲快靴俱全，\n铺里的虾拍着甲壳称分量十足。",
		"option_a": {"label": "购皮甲", "effects": [{"type": "silver", "value": -18, "target": ""}, {"type": "item", "value": 0, "target": "eq_armor_2"}, {"type": "attr", "value": 1, "target": "bone"}]},
		"option_b": {"label": "购快靴", "effects": [{"type": "silver", "value": -14, "target": ""}, {"type": "item", "value": 0, "target": "eq_boots_2"}]},
	},
	{
		"id": "night_rain", "title": "破庙夜雨",
		"text": "夜雨滂沱，破庙漏得厉害，\n一只老虾独坐，就着灯火补屋檐。",
		"option_a": {"label": "帮工换宿", "effects": [{"type": "silver", "value": -6, "target": ""}, {"type": "attr", "value": 1, "target": "bone"}]},
		"option_b": {"label": "檐下练剑", "effects": [{"type": "practice", "value": 2, "target": ""}]},
	},
	{
		"id": "gambling_den", "title": "赌坊喧嚣",
		"text": "镇上赌坊彻夜喧闹，\n一只虾一夜输光了全部盘缠。",
		"option_a": {"label": "入局三把", "effects": [{"type": "silver", "value": 30, "target": ""}]},
		"option_b": {"label": "袖手旁观", "effects": [{"type": "attr", "value": 2, "target": "fortune"}]},
	},
	{
		"id": "quanzhen_scripture", "title": "全真抄经",
		"text": "全真宫外一只老虾伏案抄经，\n见你驻足，伸钳递来一卷道德经。",
		"option_a": {"label": "随他抄经", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
		"option_b": {"label": "求教剑理", "effects": [{"type": "silver", "value": -5, "target": ""}, {"type": "practice", "value": 3, "target": ""}]},
	},
	{
		"id": "lost_purse", "title": "遗落的褡裢",
		"text": "路旁褡裢里散着银两，\n四下不见虾影，只有风声掠过草叶。",
		"option_a": {"label": "归还失物", "effects": [{"type": "attr", "value": 2, "target": "fortune"}]},
		"option_b": {"label": "收起走人", "effects": [{"type": "silver", "value": 20, "target": ""}]},
	},
	{
		"id": "riverside_duel", "title": "河滩论剑",
		"text": "河滩上两派剑客各立一端，\n口舌已僵，都请你执剑裁断。",
		"option_a": {"label": "出招定胜负", "effects": [{"type": "practice", "value": 2, "target": ""}]},
		"option_b": {"label": "劝散取彩", "effects": [{"type": "silver", "value": 15, "target": ""}]},
	},
	{
		"id": "ancient_bell", "title": "荒寺晚钟",
		"text": "荒寺暮色里铜钟自鸣，\n钟腹内壁隐有呼吸般的铭文。",
		"option_a": {"label": "抚钟入息", "effects": [{"type": "attr", "value": 2, "target": "inner"}]},
		"option_b": {"label": "敲钟卖铜", "effects": [{"type": "silver", "value": 12, "target": ""}]},
	},
	{
		"id": "poisoned_well", "title": "荒村毒井",
		"text": "荒村井水一夜发苦，\n药翁提药箱来，开口要价。",
		"option_a": {"label": "出银请药", "effects": [{"type": "silver", "value": -10, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}]},
		"option_b": {"label": "自学辨毒", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
	},
	{
		"id": "tiger_pass", "title": "虎啸危崖",
		"text": "崖下虎啸阵阵，\n商队头目兜售过路符。",
		"option_a": {"label": "买符通过", "effects": [{"type": "silver", "value": -8, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}]},
		"option_b": {"label": "攀崖绕行", "effects": [{"type": "attr", "value": 2, "target": "agility"}]},
	},
	{
		"id": "lantern_festival", "title": "上元灯会",
		"text": "上元灯会人声鼎沸，\n灯摊谜面未解，猴子却已逃了。",
		"option_a": {"label": "破灯猜谜", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
		"option_b": {"label": "追猴拾遗", "effects": [{"type": "silver", "value": 5, "target": ""}, {"type": "attr", "value": 1, "target": "fortune"}]},
	},
	{
		"id": "pawnshop", "title": "当铺旧刀",
		"text": "当铺柜台压着一柄断票旧刀，\n刀主落魄，已无力赎当。",
		"option_a": {"label": "断票贱收", "effects": [{"type": "silver", "value": 16, "target": ""}]},
		"option_b": {"label": "代赎还主", "effects": [{"type": "silver", "value": -14, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}]},
	},
	{
		"id": "storyteller", "title": "茶馆说书",
		"text": "茶馆说书人正讲一段旧年剑侠，\n满堂喝彩，茶碗都忘了喝。",
		"option_a": {"label": "买茶续听", "effects": [{"type": "silver", "value": -5, "target": ""}, {"type": "practice", "value": 1, "target": ""}]},
		"option_b": {"label": "默记剑理", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "chess_stall", "title": "街角残局",
		"text": "街角棋盘摆着一局残局，\n据说十年无人解出。",
		"option_a": {"label": "静思破局", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
		"option_b": {"label": "出银买谱", "effects": [{"type": "silver", "value": -8, "target": ""}, {"type": "practice", "value": 2, "target": ""}]},
	},
	{
		"id": "smithy", "title": "铸剑回炉",
		"text": "铁匠铺炉火正旺，\n老铁匠说你的旧剑可以回炉重铸。",
		"option_a": {"label": "出银回炉", "effects": [{"type": "silver", "value": -18, "target": ""}, {"type": "item", "value": 0, "target": "eq_sword_3"}]},
		"option_b": {"label": "旁观剑理", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "cliff_herbs", "title": "崖上采药",
		"text": "崖上采药人正招人攀崖，\n崖顶灵芝长势极好，亦可买去。",
		"option_a": {"label": "帮攀崖顶", "effects": [{"type": "silver", "value": 12, "target": ""}, {"type": "attr", "value": 1, "target": "agility"}]},
		"option_b": {"label": "重金购芝", "effects": [{"type": "silver", "value": -18, "target": ""}, {"type": "attr", "value": 2, "target": "inner"}]},
	},
	{
		"id": "wedding_train", "title": "山道花轿",
		"text": "山道上一顶花轿拦住去路，\n按老例须随礼方能通行。",
		"option_a": {"label": "随礼放行", "effects": [{"type": "silver", "value": -8, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}]},
		"option_b": {"label": "攀坡绕行", "effects": [{"type": "attr", "value": 1, "target": "agility"}]},
	},
	{
		"id": "sword_mound", "title": "荒冢埋剑",
		"text": "荒冢之旁堆着断剑残刃，\n剑意未散，隐隐有鸣。",
		"option_a": {"label": "拾剑参悟", "effects": [{"type": "practice", "value": 3, "target": ""}]},
		"option_b": {"label": "断剑熔银", "effects": [{"type": "silver", "value": 17, "target": ""}]},
	},
	{
		"id": "night_inn", "title": "客栈夜账",
		"text": "客栈掌柜伏在账本前揉眼，\n见你驻足，邀你帮算账或温酒暖身。",
		"option_a": {"label": "帮算夜账", "effects": [{"type": "silver", "value": 9, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}]},
		"option_b": {"label": "温酒暖身", "effects": [{"type": "silver", "value": -10, "target": ""}, {"type": "attr", "value": 1, "target": "bone"}]},
	},
	{
		"id": "wild_goose_letter", "title": "雁足传书",
		"text": "一只大雁落在脚边，\n足上系着帛书，村舍就在山下。",
		"option_a": {"label": "拾书送村", "effects": [{"type": "attr", "value": 1, "target": "agility"}, {"type": "silver", "value": 6, "target": ""}]},
		"option_b": {"label": "拆书细读", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
	},
	{
		"id": "snow_pass", "title": "风雪隘口",
		"text": "风雪封了隘口，\n向导蹲在火边，开口报了价。",
		"option_a": {"label": "出银雇导", "effects": [{"type": "silver", "value": -12, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}]},
		"option_b": {"label": "踏雪先行", "effects": [{"type": "attr", "value": 2, "target": "agility"}]},
	},
	{
		"id": "drunken_fist", "title": "醉汉传拳",
		"text": "醉汉在酒肆口手舞足蹈，\n看似胡闹，拳理却暗合章法。",
		"option_a": {"label": "买酒请教", "effects": [{"type": "silver", "value": -9, "target": ""}, {"type": "practice", "value": 2, "target": ""}]},
		"option_b": {"label": "以拳换教", "effects": [{"type": "attr", "value": 1, "target": "bone"}]},
	},
	{
		"id": "river_god", "title": "河伯娶亲",
		"text": "河伯娶亲的鼓号从村头响起，\n巫师索价，村民面有难色，求你定夺。",
		"option_a": {"label": "破局辨伪", "effects": [{"type": "attr", "value": 2, "target": "wisdom"}]},
		"option_b": {"label": "受金平事", "effects": [{"type": "silver", "value": 15, "target": ""}]},
	},
	{
		"id": "plague_village", "title": "疫村施药",
		"text": "疫村炊烟稀薄，\n村中郎中望着药柜叹气，缺药无力。",
		"option_a": {"label": "出银买药", "effects": [{"type": "silver", "value": -12, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}]},
		"option_b": {"label": "自学方剂", "effects": [{"type": "attr", "value": 1, "target": "wisdom"}]},
	},
	{
		"id": "young_disciple", "title": "登门求教",
		"text": "一名少年在门外徘徊良久，\n终于鼓足勇气，开口求你指点。",
		"option_a": {"label": "耐心点拨", "effects": [{"type": "practice", "value": 1, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}]},
		"option_b": {"label": "收礼了事", "effects": [{"type": "silver", "value": 10, "target": ""}]},
	},
	{
		"id": "fallen_rider", "title": "坠马客商",
		"text": "客商坠马，货物散落一地，\n他揉着腰，四下张望寻人搭手。",
		"option_a": {"label": "帮拣银赏", "effects": [{"type": "silver", "value": 14, "target": ""}]},
		"option_b": {"label": "捡靴自用", "effects": [{"type": "item", "value": 0, "target": "eq_boots_1"}]},
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
