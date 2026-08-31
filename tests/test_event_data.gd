## Unit tests for scripts/data/event_data.gd (EventData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const EventData = preload("res://scripts/data/event_data.gd")
const EventLogic = preload("res://scripts/data/event_logic.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")
const I18nScript = preload("res://scripts/autoload/i18n.gd")

## Expected row data, verbatim from step2_design §8.6.
const ROW_EFFECTS := {
	"bandits": {
		"A": [{"type": "silver", "value": -10, "target": ""}],
		"B": [{"type": "attr", "value": 1, "target": "bone"}],
	},
	"merchant": {
		"A": [{"type": "silver", "value": -20, "target": ""}, {"type": "item", "value": 0, "target": "eq_sword_3"}],
		"B": [{"type": "none", "value": 0, "target": ""}],
	},
	"ruins": {
		"A": [{"type": "attr", "value": 1, "target": "wisdom"}],
		"B": [{"type": "attr", "value": 1, "target": "fortune"}],
	},
	"beggar": {
		"A": [{"type": "silver", "value": -5, "target": ""}, {"type": "attr", "value": 1, "target": "fortune"}],
		"B": [{"type": "practice", "value": 2, "target": ""}],
	},
	"tomb_bed": {
		"A": [{"type": "attr", "value": 2, "target": "inner"}],
		"B": [{"type": "item", "value": 0, "target": "eq_sword_2"}],
	},
	"wounded_eagle": {
		"A": [{"type": "silver", "value": -8, "target": ""}, {"type": "practice", "value": 2, "target": ""}],
		"B": [{"type": "attr", "value": 1, "target": "wisdom"}],
	},
	"peach_maze": {
		"A": [{"type": "attr", "value": 2, "target": "agility"}],
		"B": [{"type": "attr", "value": 1, "target": "wisdom"}],
	},
	"snake_bile": {
		"A": [{"type": "silver", "value": -15, "target": ""}, {"type": "attr", "value": 2, "target": "bone"}],
		"B": [{"type": "attr", "value": 1, "target": "fortune"}],
	},
	"dragon_scrap": {
		"A": [{"type": "practice", "value": 4, "target": ""}],
		"B": [{"type": "silver", "value": 25, "target": ""}],
	},
	"flood_ferry": {
		"A": [{"type": "silver", "value": -10, "target": ""}],
		"B": [{"type": "attr", "value": 1, "target": "inner"}],
	},
	"escort_job": {
		"A": [{"type": "silver", "value": 22, "target": ""}],
		"B": [{"type": "attr", "value": 1, "target": "wisdom"}],
	},
	"dali_market": {
		"A": [{"type": "silver", "value": -18, "target": ""}, {"type": "item", "value": 0, "target": "eq_armor_2"}, {"type": "attr", "value": 1, "target": "bone"}],
		"B": [{"type": "silver", "value": -14, "target": ""}, {"type": "item", "value": 0, "target": "eq_boots_2"}],
	},
	"night_rain": {
		"A": [{"type": "silver", "value": -6, "target": ""}, {"type": "attr", "value": 1, "target": "bone"}],
		"B": [{"type": "practice", "value": 2, "target": ""}],
	},
	"gambling_den": {
		"A": [{"type": "silver", "value": 30, "target": ""}],
		"B": [{"type": "attr", "value": 2, "target": "fortune"}],
	},
	"quanzhen_scripture": {
		"A": [{"type": "attr", "value": 2, "target": "wisdom"}],
		"B": [{"type": "silver", "value": -5, "target": ""}, {"type": "practice", "value": 3, "target": ""}],
	},
	"lost_purse": {
		"A": [{"type": "attr", "value": 2, "target": "fortune"}],
		"B": [{"type": "silver", "value": 20, "target": ""}],
	},
	"riverside_duel": {
		"A": [{"type": "practice", "value": 2, "target": ""}],
		"B": [{"type": "silver", "value": 15, "target": ""}],
	},
	"ancient_bell": {
		"A": [{"type": "attr", "value": 2, "target": "inner"}],
		"B": [{"type": "silver", "value": 12, "target": ""}],
	},
	"poisoned_well": {
		"A": [{"type": "silver", "value": -10, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}],
		"B": [{"type": "attr", "value": 2, "target": "wisdom"}],
	},
	"tiger_pass": {
		"A": [{"type": "silver", "value": -8, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}],
		"B": [{"type": "attr", "value": 2, "target": "agility"}],
	},
	"lantern_festival": {
		"A": [{"type": "attr", "value": 2, "target": "wisdom"}],
		"B": [{"type": "silver", "value": 5, "target": ""}, {"type": "attr", "value": 1, "target": "fortune"}],
	},
	"pawnshop": {
		"A": [{"type": "silver", "value": 16, "target": ""}],
		"B": [{"type": "silver", "value": -14, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}],
	},
	"storyteller": {
		"A": [{"type": "silver", "value": -5, "target": ""}, {"type": "practice", "value": 1, "target": ""}],
		"B": [{"type": "attr", "value": 1, "target": "wisdom"}],
	},
	"chess_stall": {
		"A": [{"type": "attr", "value": 2, "target": "wisdom"}],
		"B": [{"type": "silver", "value": -8, "target": ""}, {"type": "practice", "value": 2, "target": ""}],
	},
	"smithy": {
		"A": [{"type": "silver", "value": -18, "target": ""}, {"type": "item", "value": 0, "target": "eq_sword_3"}],
		"B": [{"type": "attr", "value": 1, "target": "wisdom"}],
	},
	"cliff_herbs": {
		"A": [{"type": "silver", "value": 12, "target": ""}, {"type": "attr", "value": 1, "target": "agility"}],
		"B": [{"type": "silver", "value": -18, "target": ""}, {"type": "attr", "value": 2, "target": "inner"}],
	},
	"wedding_train": {
		"A": [{"type": "silver", "value": -8, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}],
		"B": [{"type": "attr", "value": 1, "target": "agility"}],
	},
	"sword_mound": {
		"A": [{"type": "practice", "value": 3, "target": ""}],
		"B": [{"type": "silver", "value": 17, "target": ""}],
	},
	"night_inn": {
		"A": [{"type": "silver", "value": 9, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}],
		"B": [{"type": "silver", "value": -10, "target": ""}, {"type": "attr", "value": 1, "target": "bone"}],
	},
	"wild_goose_letter": {
		"A": [{"type": "attr", "value": 1, "target": "agility"}, {"type": "silver", "value": 6, "target": ""}],
		"B": [{"type": "attr", "value": 2, "target": "wisdom"}],
	},
	"snow_pass": {
		"A": [{"type": "silver", "value": -12, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}],
		"B": [{"type": "attr", "value": 2, "target": "agility"}],
	},
	"drunken_fist": {
		"A": [{"type": "silver", "value": -9, "target": ""}, {"type": "practice", "value": 2, "target": ""}],
		"B": [{"type": "attr", "value": 1, "target": "bone"}],
	},
	"river_god": {
		"A": [{"type": "attr", "value": 2, "target": "wisdom"}],
		"B": [{"type": "silver", "value": 15, "target": ""}],
	},
	"plague_village": {
		"A": [{"type": "silver", "value": -12, "target": ""}, {"type": "attr", "value": 2, "target": "fortune"}],
		"B": [{"type": "attr", "value": 1, "target": "wisdom"}],
	},
	"young_disciple": {
		"A": [{"type": "practice", "value": 1, "target": ""}, {"type": "attr", "value": 1, "target": "wisdom"}],
		"B": [{"type": "silver", "value": 10, "target": ""}],
	},
	"fallen_rider": {
		"A": [{"type": "silver", "value": 14, "target": ""}],
		"B": [{"type": "item", "value": 0, "target": "eq_boots_1"}],
	},
}

const ROW_TITLES := {
	"bandits": "山道遇劫", "merchant": "车马过路", "ruins": "古墓残碑", "beggar": "巷口乞食",
	"tomb_bed": "古墓寒玉", "wounded_eagle": "神雕负伤", "peach_maze": "桃花迷阵",
	"snake_bile": "蛇胆奇效", "dragon_scrap": "降龙残谱", "flood_ferry": "渡口风波",
	"escort_job": "镖行招募", "dali_market": "大理市集", "night_rain": "破庙夜雨",
	"gambling_den": "赌坊喧嚣", "quanzhen_scripture": "全真抄经", "lost_purse": "遗落的褡裢",
	"riverside_duel": "河滩论剑", "ancient_bell": "荒寺晚钟", "poisoned_well": "荒村毒井",
	"tiger_pass": "虎啸危崖", "lantern_festival": "上元灯会", "pawnshop": "当铺旧刀",
	"storyteller": "茶馆说书", "chess_stall": "街角残局", "smithy": "铸剑回炉",
	"cliff_herbs": "崖上采药", "wedding_train": "山道花轿", "sword_mound": "荒冢埋剑",
	"night_inn": "客栈夜账", "wild_goose_letter": "雁足传书", "snow_pass": "风雪隘口",
	"drunken_fist": "醉汉传拳", "river_god": "河伯娶亲", "plague_village": "疫村施药",
	"young_disciple": "登门求教", "fallen_rider": "坠马客商",
}

## Verbatim body text for all 36 rows (pins the text field byte-for-byte).
const ROW_TEXTS := {
	"bandits": "行至山道，一伙拦路的虾截住去路。\n为首一只长钳提着钢刀，索要买路财。",
	"merchant": "一只虾赶着马车路过，\n钳里挽着缰绳，满载刀剑兵刃正愁销路。",
	"ruins": "荒野深处露出一角残碑，\n碑文似与古墓武学有关。",
	"beggar": "巷口一只老虾伸钳乞食，\n触须低垂，复眼却在你身上暗暗打量。",
	"tomb_bed": "荒山之中藏着一座古墓，\n石室中央横着一张寒玉床。",
	"wounded_eagle": "一只巨雕伏在崖边，\n翅上箭伤未愈，目光如炬。",
	"peach_maze": "海岛风送来桃花香，\n花影错落，隐成阵势。",
	"snake_bile": "白驼山来的虾客叫卖蛇胆，\n药袋挂在触须上，称大补真元，价钱不菲。",
	"dragon_scrap": "书摊上一册残破掌谱，\n隐见「降龙」二字，纸色发黄。",
	"flood_ferry": "河水暴涨，渡口只余一舟，\n一只虾撑舟而立，索价甚高，爱搭不理。",
	"escort_job": "镖局里一只虾头领缺个帮工，见你身手，\n便邀你押一趟去南边的镖。",
	"dali_market": "市集上皮甲快靴俱全，\n铺里的虾拍着甲壳称分量十足。",
	"night_rain": "夜雨滂沱，破庙漏得厉害，\n一只老虾独坐，就着灯火补屋檐。",
	"gambling_den": "镇上赌坊彻夜喧闹，\n一只虾一夜输光了全部盘缠。",
	"quanzhen_scripture": "全真宫外一只老虾伏案抄经，\n见你驻足，伸钳递来一卷道德经。",
	"lost_purse": "路旁褡裢里散着银两，\n四下不见虾影，只有风声掠过草叶。",
	"riverside_duel": "河滩上两派剑客各立一端，\n口舌已僵，都请你执剑裁断。",
	"ancient_bell": "荒寺暮色里铜钟自鸣，\n钟腹内壁隐有呼吸般的铭文。",
	"poisoned_well": "荒村井水一夜发苦，\n药翁提药箱来，开口要价。",
	"tiger_pass": "崖下虎啸阵阵，\n商队头目兜售过路符。",
	"lantern_festival": "上元灯会人声鼎沸，\n灯摊谜面未解，猴子却已逃了。",
	"pawnshop": "当铺柜台压着一柄断票旧刀，\n刀主落魄，已无力赎当。",
	"storyteller": "茶馆说书人正讲一段旧年剑侠，\n满堂喝彩，茶碗都忘了喝。",
	"chess_stall": "街角棋盘摆着一局残局，\n据说十年无人解出。",
	"smithy": "铁匠铺炉火正旺，\n老铁匠说你的旧剑可以回炉重铸。",
	"cliff_herbs": "崖上采药人正招人攀崖，\n崖顶灵芝长势极好，亦可买去。",
	"wedding_train": "山道上一顶花轿拦住去路，\n按老例须随礼方能通行。",
	"sword_mound": "荒冢之旁堆着断剑残刃，\n剑意未散，隐隐有鸣。",
	"night_inn": "客栈掌柜伏在账本前揉眼，\n见你驻足，邀你帮算账或温酒暖身。",
	"wild_goose_letter": "一只大雁落在脚边，\n足上系着帛书，村舍就在山下。",
	"snow_pass": "风雪封了隘口，\n向导蹲在火边，开口报了价。",
	"drunken_fist": "醉汉在酒肆口手舞足蹈，\n看似胡闹，拳理却暗合章法。",
	"river_god": "河伯娶亲的鼓号从村头响起，\n巫师索价，村民面有难色，求你定夺。",
	"plague_village": "疫村炊烟稀薄，\n村中郎中望着药柜叹气，缺药无力。",
	"young_disciple": "一名少年在门外徘徊良久，\n终于鼓足勇气，开口求你指点。",
	"fallen_rider": "客商坠马，货物散落一地，\n他揉着腰，四下张望寻人搭手。",
}

## Verbatim option labels for all 36 rows: [label_a, label_b].
const ROW_LABELS := {
	"bandits": ["破财消灾", "出手退敌"],
	"merchant": ["买下长剑", "婉拒"],
	"ruins": ["入内参悟", "谨慎绕行"],
	"beggar": ["施舍", "切磋武学"],
	"tomb_bed": ["卧床练气", "床畔拾剑"],
	"wounded_eagle": ["施药疗伤", "静观其变"],
	"peach_maze": ["循隙闯阵", "阵外观潮"],
	"snake_bile": ["重金购之", "掉头就走"],
	"dragon_scrap": ["强记于心", "卖与书铺"],
	"flood_ferry": ["付钱渡河", "泅水而过"],
	"escort_job": ["接下镖单", "婉拒独行"],
	"dali_market": ["购皮甲", "购快靴"],
	"night_rain": ["帮工换宿", "檐下练剑"],
	"gambling_den": ["入局三把", "袖手旁观"],
	"quanzhen_scripture": ["随他抄经", "求教剑理"],
	"lost_purse": ["归还失物", "收起走人"],
	"riverside_duel": ["出招定胜负", "劝散取彩"],
	"ancient_bell": ["抚钟入息", "敲钟卖铜"],
	"poisoned_well": ["出银请药", "自学辨毒"],
	"tiger_pass": ["买符通过", "攀崖绕行"],
	"lantern_festival": ["破灯猜谜", "追猴拾遗"],
	"pawnshop": ["断票贱收", "代赎还主"],
	"storyteller": ["买茶续听", "默记剑理"],
	"chess_stall": ["静思破局", "出银买谱"],
	"smithy": ["出银回炉", "旁观剑理"],
	"cliff_herbs": ["帮攀崖顶", "重金购芝"],
	"wedding_train": ["随礼放行", "攀坡绕行"],
	"sword_mound": ["拾剑参悟", "断剑熔银"],
	"night_inn": ["帮算夜账", "温酒暖身"],
	"wild_goose_letter": ["拾书送村", "拆书细读"],
	"snow_pass": ["出银雇导", "踏雪先行"],
	"drunken_fist": ["买酒请教", "以拳换教"],
	"river_god": ["破局辨伪", "受金平事"],
	"plague_village": ["出银买药", "自学方剂"],
	"young_disciple": ["耐心点拨", "收礼了事"],
	"fallen_rider": ["帮拣银赏", "捡靴自用"],
}


static func run() -> bool:
	var ok := true
	ok = _test_all_rows(ok)
	ok = _test_option_effects(ok)
	ok = _test_effect_targets(ok)
	ok = _test_texts(ok)
	ok = _test_unknown(ok)
	ok = _test_fresh_instances(ok)
	ok = _test_no_repeat_full_journey(ok)
	ok = _test_option_labels(ok)
	ok = _test_i18n_entries(ok)
	if ok:
		print("PASS test_event_data")
	else:
		print("FAIL test_event_data")
	return ok


static func _test_all_rows(ok: bool) -> bool:
	var all_defs: Array = EventData.all()
	ok = _expect(ok, all_defs.size() >= 16, "all() has >= 16 rows")
	var seen := {}
	for def in all_defs:
		ok = _expect(ok, not seen.has(def.id), "duplicate event id " + def.id)
		seen[def.id] = true
		ok = _expect(ok, def.title == ROW_TITLES[def.id], "title " + def.id)
		ok = _expect(ok, def.title != "", "title non-empty " + def.id)
		ok = _expect(ok, def.option_a != null and def.option_b != null, "both options exist " + def.id)
		if def.option_a == null or def.option_b == null:
			continue
		ok = _expect(ok, def.option_a.label != "" and def.option_b.label != "", "option labels non-empty " + def.id)
		ok = _expect(ok, not def.option_a.effects.is_empty() and not def.option_b.effects.is_empty(), "option effects non-empty " + def.id)
		ok = _expect(ok, def.option_a.battle_id == null and def.option_b.battle_id == null, "battle_id reserved null " + def.id)
	return ok


static func _test_option_effects(ok: bool) -> bool:
	for id in ROW_EFFECTS.keys():
		var def = EventData.def(id)
		ok = _expect(ok, def != null, "def exists " + id)
		if def == null:
			continue
		ok = _expect(ok, _effects(def.option_a.effects) == ROW_EFFECTS[id]["A"], "option A effects " + id)
		ok = _expect(ok, _effects(def.option_b.effects) == ROW_EFFECTS[id]["B"], "option B effects " + id)
	return ok


static func _test_effect_targets(ok: bool) -> bool:
	## Whitelists mirroring cultivation.gd:_apply_event_option's hard contract —
	## a typo'd type/target fails loudly here instead of silently no-opping.
	var allowed_types := ["silver", "attr", "item", "practice", "none"]
	var attr_keys := ["bone", "inner", "agility", "wisdom", "fortune"]
	var equip_ids := ["eq_sword_1", "eq_sword_2", "eq_sword_3", "eq_sword_4",
		"eq_armor_1", "eq_armor_2", "eq_armor_3", "eq_armor_4",
		"eq_boots_1", "eq_boots_2", "eq_boots_3", "eq_boots_4"]
	for def in EventData.all():
		for opt in [def.option_a, def.option_b]:
			ok = _expect(ok, opt != null, "both options non-null " + def.id)
			if opt == null:
				continue
			ok = _expect(ok, opt.label != "", "option label non-empty " + def.id)
			for e in opt.effects:
				var d: Dictionary = e as Dictionary
				ok = _expect(ok, d.has("type") and d.has("value") and d.has("target"), "effect has type/value/target " + def.id)
				if not (d.has("type") and d.has("value") and d.has("target")):
					continue
				ok = _expect(ok, allowed_types.has(d["type"]), "effect type whitelist " + def.id + ":" + str(d["type"]))
				if d["type"] == "attr":
					ok = _expect(ok, attr_keys.has(d["target"]), "attr target whitelist " + def.id + ":" + str(d["target"]))
				if d["type"] == "item":
					ok = _expect(ok, equip_ids.has(d["target"]), "item target whitelist " + def.id + ":" + str(d["target"]))
	# Costless-item uniqueness: an item grant with no paired silver effect is a
	# free grant — two rows must never offer the same costless target.
	var costless_targets := []
	for def in EventData.all():
		for opt in [def.option_a, def.option_b]:
			if opt == null:
				continue
			var has_silver := false
			for e in opt.effects:
				if (e as Dictionary)["type"] == "silver":
					has_silver = true
			if has_silver:
				continue
			for e in opt.effects:
				if (e as Dictionary)["type"] == "item":
					costless_targets.append((e as Dictionary)["target"])
	var seen := {}
	for t in costless_targets:
		ok = _expect(ok, not seen.has(t), "costless item target duplicate " + str(t))
		seen[t] = true
	# Must-land per row (acceptance criterion): at least one option contains an
	# attr effect OR a non-zero silver effect — both always mutate profile state,
	# whereas item/practice can no-op via dedup/mastered.
	for def in EventData.all():
		var row_lands := false
		for opt in [def.option_a, def.option_b]:
			if opt == null:
				continue
			for e in opt.effects:
				var d: Dictionary = e as Dictionary
				if d.get("type", "") == "attr":
					row_lands = true
				if d.get("type", "") == "silver" and int(d.get("value", 0)) != 0:
					row_lands = true
		ok = _expect(ok, row_lands, "row has a must-land option " + def.id)
	return ok


static func _test_texts(ok: bool) -> bool:
	for id in ROW_TITLES.keys():
		var def = EventData.def(id)
		ok = _expect(ok, (def.text as String) != "", "text non-empty " + id)
		ok = _expect(ok, (def.text as String).length() > 10, "text body 2-3 lines " + id)
		ok = _expect(ok, def.text == ROW_TEXTS[id], "text verbatim pin " + id)
	return ok


static func _test_unknown(ok: bool) -> bool:
	ok = _expect(ok, EventData.def("nope") == null, "def unknown -> null")
	return ok


static func _test_fresh_instances(ok: bool) -> bool:
	var d1 = EventData.def("bandits")
	d1.option_a.effects[0]["value"] = 999
	d1.option_a.label = "mutated"
	var d2 = EventData.def("bandits")
	ok = _expect(ok, (d2.option_a.effects[0] as Dictionary)["value"] == -10, "effects fresh (value)")
	ok = _expect(ok, d2.option_a.label == "破财消灾", "option label fresh")
	var all1: Array = EventData.all()
	all1[0].title = "mutated"
	var all2: Array = EventData.all()
	ok = _expect(ok, all2[0].title == "山道遇劫", "all() instances fresh")
	return ok


## Executable no-repeat gate (roadmap completeness item 3, ❌->✅).
## A full journey = 3 years x 12 months = 36 roams. Run the REAL
## EventLogic.draw_unseen_id once per month on a fresh profile and mark each id
## seen exactly as cultivation.gd:467-469 does (append-if-absent). Assert the
## seen-bag grows monotonically 0->36 with no mid-journey reset, and that all 36
## drawn ids are distinct. On the current 16-row pool this gate is RED at draw 17
## (the reset branch clears the bag, so the ladder drops back to 1); it stays red
## until event_rows_i18n_mirrors lands >= 36 rows.
static func _test_no_repeat_full_journey(ok: bool) -> bool:
	# Pre: build the id set from the real table (the size floor is asserted LAST
	# so the first red on the 16-pool is the no-repeat failure at draw 17).
	var all: Array = EventData.all()
	var all_ids := {}
	for def in all:
		all_ids[def.id] = true
	# 16-frozen baseline: the row ids that predate this round's pool growth. 36
	# distinct draws over only these 16 ids would force >= 20 new ids; the set
	# label stays self-documenting if a later round grows the pool further.
	var FROZEN16 := {
		"bandits": true, "merchant": true, "ruins": true, "beggar": true, "tomb_bed": true,
		"wounded_eagle": true, "peach_maze": true, "snake_bile": true, "dragon_scrap": true,
		"flood_ferry": true, "escort_job": true, "dali_market": true, "night_rain": true,
		"gambling_den": true, "quanzhen_scripture": true, "lost_purse": true,
	}
	# Fresh hermetic profile + deterministic, independent RNG stream.
	var profile: PlayerProfile = PlayerProfileScript.new()
	profile.flags["events_seen"] = []   # defensive: mirrors the sanitized bag
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	var drawn := {}
	for i in range(1, 37):
		var id: String = EventLogic.draw_unseen_id(profile, rng)
		ok = _expect(ok, id != "", "draw %d returns a non-empty id" % i)
		ok = _expect(ok, all_ids.has(id), "draw %d id is in TABLE (got %s)" % [i, id])
		# No-repeat: every drawn id must be new across the whole journey.
		ok = _expect(ok, not drawn.has(id), "draw %d repeats id %s (no-repeat violated)" % [i, id])
		drawn[id] = true
		# Mark seen EXACTLY as cultivation.gd:467-469 does (append-if-absent).
		var seen: Array = profile.flags.get("events_seen", [])
		if not seen.has(id):
			seen.append(id)
		profile.flags["events_seen"] = seen
		# Monotonic ladder 0->36: any shrinkage proves the zero-RNG reset branch
		# fired mid-journey — MEASURED, not reasoned.
		var bag_size: int = (profile.flags["events_seen"] as Array).size()
		ok = _expect(ok, bag_size == i, "draw %d seen-bag size == %d (reset fired; got %d)" % [i, i, bag_size])
	# Post: 36 distinct ids across the full journey.
	var distinct: Array = drawn.keys()
	ok = _expect(ok, distinct.size() == 36, "36 draws -> 36 distinct ids (got %d)" % distinct.size())
	# Pigeonhole over the frozen baseline: 36 distinct draws over only 16 frozen
	# ids must include >= 20 ids OUTSIDE FROZEN16 (i.e. newly-added rows).
	var new_ids := 0
	for did in distinct:
		if not FROZEN16.has(did):
			new_ids += 1
	ok = _expect(ok, new_ids >= 20, "journey drew >= 20 new (non-frozen) ids (got %d)" % new_ids)
	# Size floor asserted LAST so the first red on the 16-pool lands on the
	# no-repeat violation at draw 17, not here.
	ok = _expect(ok, all.size() >= 36, "TABLE has >= 36 rows (got %d)" % all.size())
	return ok


## Verbatim option-label pin: every row's both labels must match ROW_LABELS.
static func _test_option_labels(ok: bool) -> bool:
	for id in ROW_TITLES.keys():
		var def = EventData.def(id)
		ok = _expect(ok, def != null, "def exists for labels " + id)
		if def == null:
			continue
		ok = _expect(ok, def.option_a.label == ROW_LABELS[id][0], "option_a label " + id)
		ok = _expect(ok, def.option_b.label == ROW_LABELS[id][1], "option_b label " + id)
	return ok


## EN-dictionary membership gate: every event string (title, text, both labels)
## must exist as a key in the i18n EN dictionary. test_i18n_coverage.py does NOT
## scan event_data.gd literals; this gate closes that blind spot.
static func _test_i18n_entries(ok: bool) -> bool:
	var en: Dictionary = I18nScript.EN
	for id in ROW_TITLES.keys():
		var def = EventData.def(id)
		ok = _expect(ok, def != null, "def exists for i18n " + id)
		if def == null:
			continue
		ok = _expect(ok, en.has(def.title), "EN has title " + id)
		ok = _expect(ok, en.has(def.text), "EN has text " + id)
		ok = _expect(ok, en.has(def.option_a.label), "EN has option_a label " + id)
		ok = _expect(ok, en.has(def.option_b.label), "EN has option_b label " + id)
	return ok


## Copy an effects array into a plain Array (deep-duplicated dictionaries).
static func _effects(effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		out.append((e as Dictionary).duplicate(true))
	return out


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_event_data: " + msg)
	return false
