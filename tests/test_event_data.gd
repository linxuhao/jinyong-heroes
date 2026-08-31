## Unit tests for scripts/data/event_data.gd (EventData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const EventData = preload("res://scripts/data/event_data.gd")
const EventLogic = preload("res://scripts/data/event_logic.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")

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
	ok = _test_no_repeat_full_journey(ok)
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
