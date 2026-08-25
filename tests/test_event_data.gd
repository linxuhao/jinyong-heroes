## Unit tests for scripts/data/event_data.gd (EventData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const EventData = preload("res://scripts/data/event_data.gd")

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
}

const ROW_TITLES := {
	"bandits": "山道遇劫匪", "merchant": "行商路过", "ruins": "古墓残碑", "beggar": "老丐乞食",
	"tomb_bed": "古墓寒玉", "wounded_eagle": "神雕负伤", "peach_maze": "桃花迷阵",
	"snake_bile": "蛇胆奇效", "dragon_scrap": "降龙残谱", "flood_ferry": "渡口风波",
	"escort_job": "镖行招募", "dali_market": "大理市集", "night_rain": "破庙夜雨",
	"gambling_den": "赌坊喧嚣", "quanzhen_scripture": "全真抄经", "lost_purse": "遗落的褡裢",
}


static func run() -> bool:
	var ok := true
	ok = _test_all_rows(ok)
	ok = _test_option_effects(ok)
	ok = _test_effect_targets(ok)
	ok = _test_texts(ok)
	ok = _test_unknown(ok)
	ok = _test_fresh_instances(ok)
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
	ok = _expect(ok, all2[0].title == "山道遇劫匪", "all() instances fresh")
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
