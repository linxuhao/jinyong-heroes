## Unit tests for PlayerProfile.equipped (three equipment slots).
## Contract: top-level static func run() -> bool; push_error on failure;
## never relies on assert() (stripped in release). Collected by
## tests/unit_test_runner.gd.
##
## Covers: default three empty slots, JSON-lossless round-trip, hostile
## from_dict coercion, the full equip/unequip validation matrix, reversibility,
## and the equipped-subset-of-inventory repair on load.
## NOTE: all Dictionary/Array locals are explicitly typed to avoid GDScript
## inference failures on heterogeneous literals.

static func run() -> bool:
	var ok := true
	ok = _test_default_slots(ok)
	ok = _test_roundtrip(ok)
	ok = _test_json_roundtrip(ok)
	ok = _test_hostile_from_dict(ok)
	ok = _test_equip_validation(ok)
	ok = _test_reversible(ok)
	ok = _test_inventory_repair_on_load(ok)
	if ok:
		print("PASS test_player_profile_equipment")
	else:
		print("FAIL test_player_profile_equipment")
	return ok


# --- default slots --------------------------------------------------------------

static func _test_default_slots(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	ok = _expect(ok, p.equipped == {"weapon": "", "armor": "", "boots": ""}, "default equipped three empty slots")
	ok = _expect(ok, p.equipped_id("weapon") == "", "default weapon empty")
	ok = _expect(ok, p.equipped_id("armor") == "", "default armor empty")
	ok = _expect(ok, p.equipped_id("boots") == "", "default boots empty")
	ok = _expect(ok, p.equipped_id("bogus") == "", "unknown slot returns empty")
	return ok


# --- to_dict -> from_dict round-trip (no JSON) ----------------------------------

static func _test_roundtrip(ok: bool) -> bool:
	var p1: PlayerProfile = PlayerProfile.new_default()
	p1.inventory.append("eq_sword_3")
	p1.inventory.append("eq_boots_4")
	ok = _expect(ok, p1.equip("weapon", "eq_sword_3"), "equip weapon sword")
	ok = _expect(ok, p1.equip("boots", "eq_boots_4"), "equip boots")
	var p2: PlayerProfile = PlayerProfile.from_dict(p1.to_dict())
	ok = _expect(ok, p2.equipped == {"weapon": "eq_sword_3", "armor": "", "boots": "eq_boots_4"}, "roundtrip equipped preserved")
	ok = _expect(ok, p2.equipped_id("weapon") == "eq_sword_3", "roundtrip weapon id")
	ok = _expect(ok, p2.equipped_id("boots") == "eq_boots_4", "roundtrip boots id")
	# equip -> unequip -> to_dict equals the pre-equip snapshot
	var p3: PlayerProfile = PlayerProfile.new_default()
	p3.inventory.append("eq_sword_1")
	var before: Dictionary = p3.to_dict()
	p3.equip("weapon", "eq_sword_1")
	var during: Dictionary = p3.to_dict()
	ok = _expect(ok, during.get("equipped", {}).get("weapon", "") == "eq_sword_1", "equipped present mid-equip")
	p3.unequip_slot("weapon")
	var after: Dictionary = p3.to_dict()
	ok = _expect(ok, after == before, "equip->unequip returns to pre-equip snapshot")
	return ok


# --- JSON round-trip ------------------------------------------------------------

static func _test_json_roundtrip(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.inventory.append("eq_sword_3")
	p.inventory.append("eq_armor_2")
	p.equip("weapon", "eq_sword_3")
	p.equip("armor", "eq_armor_2")
	var json: String = JSON.stringify(p.to_dict())
	ok = _expect(ok, json != "", "JSON.stringify produced output (all keys String)")
	var parsed: Variant = JSON.parse_string(json)
	ok = _expect(ok, parsed is Dictionary, "JSON.parse_string yields a Dictionary")
	if parsed is Dictionary:
		var restored: PlayerProfile = PlayerProfile.from_dict(parsed)
		ok = _expect(ok, restored.to_dict() == p.to_dict(), "JSON round-trip preserves profile incl. equipped")
		ok = _expect(ok, restored.equipped_id("weapon") == "eq_sword_3", "JSON round-trip weapon")
		ok = _expect(ok, restored.equipped_id("armor") == "eq_armor_2", "JSON round-trip armor")
	return ok


# --- hostile from_dict ----------------------------------------------------------

static func _test_hostile_from_dict(ok: bool) -> bool:
	# equipped = 42 -> default three empty slots
	var num_src: Dictionary = {"equipped": 42}
	var num_p: PlayerProfile = PlayerProfile.from_dict(num_src)
	ok = _expect(ok, num_p.equipped == {"weapon": "", "armor": "", "boots": ""}, "equipped int -> empty slots")
	# equipped = "x" -> default three empty slots
	var str_src: Dictionary = {"equipped": "x"}
	var str_p: PlayerProfile = PlayerProfile.from_dict(str_src)
	ok = _expect(ok, str_p.equipped == {"weapon": "", "armor": "", "boots": ""}, "equipped string -> empty slots")
	# equipped = [] -> default three empty slots
	var arr_src: Dictionary = {"equipped": []}
	var arr_p: PlayerProfile = PlayerProfile.from_dict(arr_src)
	ok = _expect(ok, arr_p.equipped == {"weapon": "", "armor": "", "boots": ""}, "equipped array -> empty slots")
	# values non-String -> dropped to ""
	var bad_val_src: Dictionary = {
		"equipped": {"weapon": 42, "armor": true, "boots": null},
	}
	var bad_val_p: PlayerProfile = PlayerProfile.from_dict(bad_val_src)
	ok = _expect(ok, bad_val_p.equipped == {"weapon": "", "armor": "", "boots": ""}, "non-string slot values -> empty")
	# unknown slot keys are naturally dropped
	var unknown_src: Dictionary = {
		"equipped": {"weapon": "eq_sword_1", "necklace": "eq_neck_1"},
	}
	var unknown_p: PlayerProfile = PlayerProfile.from_dict(unknown_src)
	ok = _expect(ok, unknown_p.equipped == {"weapon": "", "armor": "", "boots": ""}, "unknown slot key dropped + not in inventory")
	# equipped id not in inventory -> repaired to "" on load
	var repair_src: Dictionary = {
		"inventory": ["eq_sword_1"],
		"equipped": {"weapon": "eq_sword_1", "armor": "eq_armor_3", "boots": "eq_boots_2"},
	}
	var repair_p: PlayerProfile = PlayerProfile.from_dict(repair_src)
	ok = _expect(ok, repair_p.equipped_id("weapon") == "eq_sword_1", "inventory id kept")
	ok = _expect(ok, repair_p.equipped_id("armor") == "", "armor not in inventory -> repaired")
	ok = _expect(ok, repair_p.equipped_id("boots") == "", "boots not in inventory -> repaired")
	# legacy save with NO equipped key -> default empty slots, no crash
	var legacy_src: Dictionary = {"silver": 5}
	var legacy_p: PlayerProfile = PlayerProfile.from_dict(legacy_src)
	ok = _expect(ok, legacy_p.equipped == {"weapon": "", "armor": "", "boots": ""}, "legacy no equipped -> empty slots")
	return ok


# --- equip/unequip validation matrix --------------------------------------------

static func _test_equip_validation(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.inventory.append("eq_sword_3")
	p.inventory.append("eq_sword_4")   # in inventory for the (f) swap test
	p.inventory.append("eq_armor_2")
	p.inventory.append("eq_boots_4")
	# (a) slot not in SLOTS -> false
	ok = _expect(ok, not p.equip("necklace", "eq_sword_3"), "unknown slot rejected")
	# (b) id == "" -> false
	ok = _expect(ok, not p.equip("weapon", ""), "empty id rejected")
	# (c) id not in inventory -> false (eq_sword_1 is deliberately ABSENT here)
	ok = _expect(ok, not p.equip("weapon", "eq_sword_1"), "id not in inventory rejected")
	# (d) category/slot mismatch -> false
	ok = _expect(ok, not p.equip("weapon", "eq_armor_2"), "armor id in weapon slot rejected")
	ok = _expect(ok, not p.equip("boots", "eq_sword_3"), "sword id in boots slot rejected")
	# (e) same id already equipped -> true, idempotent
	ok = _expect(ok, p.equip("weapon", "eq_sword_3"), "first equip weapon")
	ok = _expect(ok, p.equip("weapon", "eq_sword_3"), "re-equip same id is true")
	ok = _expect(ok, p.equipped_id("weapon") == "eq_sword_3", "re-equip unchanged")
	# (f) different id -> true, overwrite (swap semantics; displaced stays in inventory)
	ok = _expect(ok, p.equip("weapon", "eq_sword_4"), "different id overwrites")
	ok = _expect(ok, p.equipped_id("weapon") == "eq_sword_4", "overwrite applied")
	ok = _expect(ok, p.inventory.has("eq_sword_3"), "displaced id stays in inventory")
	# unequip_slot
	ok = _expect(ok, p.unequip_slot("weapon"), "unequip weapon true")
	ok = _expect(ok, p.equipped_id("weapon") == "", "weapon cleared")
	ok = _expect(ok, p.unequip_slot("weapon"), "unequip already-empty is true (idempotent)")
	ok = _expect(ok, not p.unequip_slot("bogus"), "unequip unknown slot false")
	return ok


# --- reversibility ---------------------------------------------------------------

static func _test_reversible(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.inventory.append("eq_sword_2")
	p.inventory.append("eq_boots_3")
	var before: Dictionary = p.to_dict()
	ok = _expect(ok, p.equip("weapon", "eq_sword_2"), "equip sword")
	ok = _expect(ok, p.equip("boots", "eq_boots_3"), "equip boots")
	var during: Dictionary = p.to_dict()
	ok = _expect(ok, during.get("equipped", {}).get("weapon", "") == "eq_sword_2", "weapon equipped mid")
	ok = _expect(ok, during.get("equipped", {}).get("boots", "") == "eq_boots_3", "boots equipped mid")
	ok = _expect(ok, p.unequip_slot("weapon"), "unequip weapon")
	ok = _expect(ok, p.unequip_slot("boots"), "unequip boots")
	var after: Dictionary = p.to_dict()
	ok = _expect(ok, after == before, "equip->unequip -> to_dict equals pre-equip snapshot")
	return ok


# --- equipped-subset-of-inventory repair on load ----------------------------------

static func _test_inventory_repair_on_load(ok: bool) -> bool:
	# id in equipped but NOT in inventory -> repaired to "" on load
	var src: Dictionary = {
		"inventory": ["eq_sword_1", "eq_armor_2"],
		"equipped": {"weapon": "eq_sword_1", "armor": "eq_armor_3", "boots": "eq_boots_4"},
	}
	var p: PlayerProfile = PlayerProfile.from_dict(src)
	ok = _expect(ok, p.equipped_id("weapon") == "eq_sword_1", "weapon in inventory kept")
	ok = _expect(ok, p.equipped_id("armor") == "", "armor not in inventory repaired")
	ok = _expect(ok, p.equipped_id("boots") == "", "boots not in inventory repaired")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_player_profile_equipment: " + msg)
	return false
