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
}

const ROW_TITLES := {"bandits": "山道遇劫匪", "merchant": "行商路过", "ruins": "古墓残碑", "beggar": "老丐乞食"}


static func run() -> bool:
	var ok := true
	ok = _test_all_rows(ok)
	ok = _test_option_effects(ok)
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
	ok = _expect(ok, all_defs.size() == 4, "all() has 4 rows")
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
