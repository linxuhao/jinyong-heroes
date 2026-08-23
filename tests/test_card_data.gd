## Unit tests for scripts/data/card_data.gd (CardData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const CardData = preload("res://scripts/data/card_data.gd")

## Deck multiplicities (step2_design §8.5 + task_plan risk note:
## growth is 9, not 12 — the listed rows are authoritative).
const DECK_SIZE := {"economy": 12, "equipment": 12, "growth": 9, "power": 6, "trait": 0, "artifact": 6}
const ATTR_KEYS := ["bone", "inner", "agility", "wisdom", "fortune"]


static func run() -> bool:
	var ok := true
	ok = _test_deck_sizes(ok)
	ok = _test_economy_deck(ok)
	ok = _test_equipment(ok)
	ok = _test_growth(ok)
	ok = _test_power_artifact(ok)
	ok = _test_trait_dynamic(ok)
	ok = _test_unknown(ok)
	ok = _test_fresh_instances(ok)
	if ok:
		print("PASS test_card_data")
	else:
		print("FAIL test_card_data")
	return ok


static func _test_deck_sizes(ok: bool) -> bool:
	for cat in DECK_SIZE.keys():
		ok = _expect(ok, CardData.deck_size(cat) == DECK_SIZE[cat], "deck_size " + cat + " == " + str(DECK_SIZE[cat]))
	return ok


static func _test_economy_deck(ok: bool) -> bool:
	var eco: Array = CardData.initial_deck("economy")
	ok = _expect(ok, eco.size() == 12, "economy deck 12 entries")
	ok = _expect(ok, eco.count("eco_20") == 4, "eco_20 x4")
	ok = _expect(ok, eco.count("eco_50") == 3, "eco_50 x3")
	ok = _expect(ok, eco.count("eco_100") == 2, "eco_100 x2")
	ok = _expect(ok, eco.count("eco_trade_1") == 1 and eco.count("eco_trade_2") == 1 and eco.count("eco_trade_3") == 1, "trade x1 each")
	# economy defs: 6 unique rows
	var defs: Array = CardData.defs_in_category("economy")
	ok = _expect(ok, defs.size() == 6, "economy has 6 unique defs")
	var seen := {}
	for def in defs:
		seen[def.id] = true
	ok = _expect(ok, seen.size() == 6, "economy def ids unique")
	ok = _expect(ok, CardData.def("eco_trade_1").display_name == "行商分成", "trade display name")
	ok = _expect(ok, CardData.def("eco_trade_2").effect_value == 60 and CardData.def("eco_trade_3").effect_value == 80, "trade values 40/60/80")
	return ok


static func _test_equipment(ok: bool) -> bool:
	var defs: Array = CardData.defs_in_category("equipment")
	ok = _expect(ok, defs.size() == 12, "equipment 12 defs")
	for def in defs:
		ok = _expect(ok, def.effect_type == "item", "equipment effect_type item " + def.id)
		ok = _expect(ok, def.effect_target == def.id, "equipment target == id " + def.id)
	ok = _expect(ok, CardData.def("eq_sword_3").display_name == "青锋剑", "eq_sword_3 青锋剑")
	ok = _expect(ok, CardData.def("eq_boots_4").display_name == "凌波靴", "eq_boots_4 凌波靴")
	return ok


static func _test_growth(ok: bool) -> bool:
	# growth attr cards target each of the 5 attrs at +1
	var targets := {}
	for key in ATTR_KEYS:
		var def = CardData.def("gr_attr_" + key)
		ok = _expect(ok, def != null, "gr_attr_" + key + " exists")
		if def != null:
			targets[def.effect_target] = def.effect_value
	ok = _expect(ok, targets == {"bone": 1, "inner": 1, "agility": 1, "wisdom": 1, "fortune": 1}, "growth attr cards +1 each")
	ok = _expect(ok, CardData.deck_size("growth") == 9, "growth deck 9")
	ok = _expect(ok, CardData.def("gr_practice_2").effect_type == "practice" and CardData.def("gr_practice_2").effect_value == 2, "gr_practice_2 practice +2")
	ok = _expect(ok, CardData.def("gr_trait_pool").effect_type == "trait", "gr_trait_pool trait")
	ok = _expect(ok, CardData.def("gr_silver_30").effect_type == "silver" and CardData.def("gr_silver_30").effect_value == 30, "gr_silver_30 +30")
	return ok


static func _test_power_artifact(ok: bool) -> bool:
	ok = _expect(ok, CardData.def("pw_practice_4").effect_value == 4, "pw_practice_4 +4")
	ok = _expect(ok, CardData.def("pw_attr_3").effect_target == "bone" and CardData.def("pw_attr_3").effect_value == 3, "pw_attr_3 bone +3")
	ok = _expect(ok, CardData.def("pw_tech_unlock").effect_type == "tech_unlock", "pw_tech_unlock")
	ok = _expect(ok, CardData.def("art_ding_speed").effect_value == 6, "art_ding_speed +6")
	ok = _expect(ok, CardData.def("art_shen_gong").effect_type == "shen_gong", "art_shen_gong")
	ok = _expect(ok, CardData.def("art_silver_500").effect_value == 500, "art_silver_500 +500")
	return ok


static func _test_trait_dynamic(ok: bool) -> bool:
	# no static rows: defs_in_category("trait") is empty, initial_deck is []
	ok = _expect(ok, CardData.defs_in_category("trait").is_empty(), "trait has no static defs")
	ok = _expect(ok, CardData.initial_deck("trait").is_empty(), "trait initial deck []")
	# synthesized trait card
	var card = CardData.def("ambidextrous")
	ok = _expect(ok, card != null, "trait card synthesized")
	if card != null:
		ok = _expect(ok, card.category == "trait", "trait card category")
		ok = _expect(ok, card.effect_type == "trait", "trait card effect_type")
		ok = _expect(ok, card.display_name == "左右互搏", "trait card display name")
	# build_trait_deck excludes owned, keeps positive order
	var expected: Array = []
	for id in TraitData.positive_ids():
		if id != "ambidextrous":
			expected.append(id)
	ok = _expect(ok, CardData.build_trait_deck(["ambidextrous"]) == expected, "build_trait_deck excludes owned")
	ok = _expect(ok, CardData.build_trait_deck([]).size() == 8, "build_trait_deck no owned -> 8")
	return ok


static func _test_unknown(ok: bool) -> bool:
	ok = _expect(ok, CardData.def("nope") == null, "def unknown -> null")
	ok = _expect(ok, CardData.defs_in_category("nope").is_empty(), "defs_in_category unknown -> []")
	ok = _expect(ok, CardData.initial_deck("nope").is_empty(), "initial_deck unknown -> []")
	return ok


static func _test_fresh_instances(ok: bool) -> bool:
	var c1 = CardData.def("eco_20")
	c1.effect_value = 999
	c1.display_name = "mutated"
	var c2 = CardData.def("eco_20")
	ok = _expect(ok, c2.effect_value == 20, "def fresh (effect_value)")
	ok = _expect(ok, c2.display_name == "一袋碎银", "def fresh (display_name)")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_card_data: " + msg)
	return false
