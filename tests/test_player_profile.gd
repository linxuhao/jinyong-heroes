## Unit tests for scripts/data/player_profile.gd (PlayerProfile).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by a later subtask; this file only delivers the
## script plus the assertion contract from task_plan.md acceptance criteria 2-8.

const FIVE_KEYS: Array[String] = ["bone", "inner", "agility", "wisdom", "fortune"]


static func run() -> bool:
	var ok := true
	ok = _test_new_default(ok)
	ok = _test_attrs(ok)
	ok = _test_traits(ok)
	ok = _test_gongfa(ok)
	ok = _test_roundtrip(ok)
	ok = _test_defensive(ok)
	ok = _test_json_roundtrip(ok)
	if ok:
		print("PASS test_player_profile")
	else:
		print("FAIL test_player_profile")
	return ok


# --- criterion 2: new_default ------------------------------------------------

static func _test_new_default(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	for key in FIVE_KEYS:
		ok = _expect(ok, p.get_attr(key) == 10, "new_default attr " + key + " == 10")
	ok = _expect(ok, p.traits.is_empty(), "new_default traits empty")
	ok = _expect(ok, p.gongfa.is_empty(), "new_default gongfa empty")
	ok = _expect(ok, p.inventory.is_empty(), "new_default inventory empty")
	ok = _expect(ok, p.companions.is_empty(), "new_default companions empty")
	ok = _expect(ok, p.silver == 0, "new_default silver == 0")
	ok = _expect(ok, p.cultivation == {"year": 1, "month": 1, "sect_id": ""}, "new_default cultivation")
	ok = _expect(ok, p.map_node == "wuming_valley", "new_default map_node")
	ok = _expect(ok, p.flags == {"tutorial_done": false, "events_seen": []}, "new_default flags")
	ok = _expect(ok, p.main_external_id == "", "new_default main_external_id")
	return ok


# --- criterion 3: attr accessors ----------------------------------------------

static func _test_attrs(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	ok = _expect(ok, p.get_attr("bone") == 10, "bone initial 10")
	p.set_attr("bone", 15)
	ok = _expect(ok, p.get_attr("bone") == 15, "set_attr 15")
	p.set_attr("bone", 5)
	ok = _expect(ok, p.get_attr("bone") == 10, "set_attr floors at 10")
	p.set_attr("bone", 10)
	p.add_attr("bone", -3)
	ok = _expect(ok, p.get_attr("bone") == 10, "add_attr negative floors at 10")
	p.add_attr("bone", 5)
	ok = _expect(ok, p.get_attr("bone") == 15, "add_attr positive")
	ok = _expect(ok, p.get_attr("nope") == 10, "unknown key returns 10")
	return ok


# --- criterion 4: trait add/remove -------------------------------------------

static func _test_traits(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.add_trait("iron_shirt")
	ok = _expect(ok, p.has_trait("iron_shirt"), "add_trait -> has_trait")
	p.add_trait("iron_shirt")
	ok = _expect(ok, p.traits.size() == 1, "add_trait idempotent")
	p.remove_trait("iron_shirt")
	ok = _expect(ok, not p.has_trait("iron_shirt"), "remove_trait -> not has")
	p.remove_trait("iron_shirt")
	ok = _expect(ok, p.traits.is_empty(), "remove_trait absent is no-op")
	return ok


# --- criterion 5: gongfa add / get / master ----------------------------------

static func _test_gongfa(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	ok = _expect(ok, p.add_gongfa("shaolin_yijin_d", "D"), "add_gongfa returns true")
	ok = _expect(ok, p.has_gongfa("shaolin_yijin_d"), "has_gongfa true")
	ok = _expect(ok, not p.has_gongfa("missing"), "has_gongfa missing false")
	ok = _expect(ok, p.get_gongfa("missing").is_empty(), "get_gongfa missing -> {}")
	ok = _expect(ok, p.get_gongfa("shaolin_yijin_d") == {
		"id": "shaolin_yijin_d", "grade": "D", "practice": 0, "mastered": false
	}, "get_gongfa entry shape")
	ok = _expect(ok, not p.add_gongfa("shaolin_yijin_d", "D"), "duplicate add returns false")
	ok = _expect(ok, p.gongfa.size() == 1, "duplicate add keeps size 1")
	ok = _expect(ok, p.master_gongfa_of("shaolin_yijin_d"), "master returns true")
	ok = _expect(ok, p.get_gongfa("shaolin_yijin_d")["mastered"] == true, "mastered set true")
	ok = _expect(ok, not p.master_gongfa_of("missing"), "master missing returns false")
	return ok


# --- criterion 6: to_dict <-> from_dict round-trip ----------------------------

static func _test_roundtrip(ok: bool) -> bool:
	var p1: PlayerProfile = PlayerProfile.new_default()
	p1.set_attr("bone", 15)
	p1.set_attr("inner", 12)
	p1.set_attr("agility", 11)
	p1.set_attr("wisdom", 14)
	p1.set_attr("fortune", 9)   # floors back to 10
	p1.add_trait("iron_shirt")
	p1.add_trait("lone_bane")
	p1.add_gongfa("shaolin_yijin_d", "D")
	p1.add_gongfa("shaolin_luohan_d", "D")
	p1.master_gongfa_of("shaolin_yijin_d")
	p1.silver = 42
	p1.inventory.append("qingfeng_sword")
	p1.companions.append("companion_01")
	p1.cultivation["year"] = 2
	p1.cultivation["month"] = 5
	p1.cultivation["sect_id"] = "shaolin"
	p1.map_node = "luoyang"
	p1.flags["tutorial_done"] = true
	p1.flags["events_seen"].append("bandits")
	p1.main_external_id = "shaolin_luohan_d"

	var p2: PlayerProfile = PlayerProfile.from_dict(p1.to_dict())
	for key in FIVE_KEYS:
		ok = _expect(ok, p2.get_attr(key) == p1.get_attr(key), "roundtrip attr " + key)
	ok = _expect(ok, p2.traits == p1.traits, "roundtrip traits")
	ok = _expect(ok, p2.gongfa == p1.gongfa, "roundtrip gongfa")
	ok = _expect(ok, p2.silver == p1.silver, "roundtrip silver")
	ok = _expect(ok, p2.inventory == p1.inventory, "roundtrip inventory")
	ok = _expect(ok, p2.companions == p1.companions, "roundtrip companions")
	ok = _expect(ok, p2.cultivation == p1.cultivation, "roundtrip cultivation")
	ok = _expect(ok, p2.map_node == p1.map_node, "roundtrip map_node")
	ok = _expect(ok, p2.flags == p1.flags, "roundtrip flags")
	ok = _expect(ok, p2.main_external_id == p1.main_external_id, "roundtrip main_external_id")
	return ok


# --- criterion 7: defensive from_dict ----------------------------------------

static func _test_defensive(ok: bool) -> bool:
	# from_dict({}) is equivalent to new_default
	var d1: PlayerProfile = PlayerProfile.from_dict({})
	for key in FIVE_KEYS:
		ok = _expect(ok, d1.get_attr(key) == 10, "from_dict({}) attr " + key + " == 10")
	ok = _expect(ok, d1.traits.is_empty() and d1.gongfa.is_empty(), "from_dict({}) lists empty")
	ok = _expect(ok, d1.silver == 0, "from_dict({}) silver 0")
	ok = _expect(ok, d1.cultivation == {"year": 1, "month": 1, "sect_id": ""}, "from_dict({}) cultivation")
	ok = _expect(ok, d1.map_node == "wuming_valley" and d1.main_external_id == "", "from_dict({}) strings")

	# hostile values -> clamped defaults
	var hostile: PlayerProfile = PlayerProfile.from_dict({
		"attrs": {"bone": 5, "inner": "x"},
		"gongfa": [{"id": 7}],
		"silver": -5,
		"cultivation": {"year": 9, "month": 0},
	})
	ok = _expect(ok, hostile.get_attr("bone") == 10, "hostile bone clamped to 10")
	ok = _expect(ok, hostile.get_attr("inner") == 10, "hostile non-int inner -> 10")
	ok = _expect(ok, hostile.get_attr("agility") == 10, "hostile missing attr -> 10")
	ok = _expect(ok, hostile.gongfa.is_empty(), "hostile bad gongfa row dropped")
	ok = _expect(ok, hostile.silver == 0, "hostile silver clamped to 0")
	ok = _expect(ok, hostile.cultivation["year"] == 3, "hostile year clamped to 3")
	ok = _expect(ok, hostile.cultivation["month"] == 1, "hostile month clamped to 1")

	# junk types everywhere -> coerced, never crashes
	var junk: PlayerProfile = PlayerProfile.from_dict({
		"traits": [1, "iron_shirt", ""],
		"gongfa": [
			{"id": "g1", "grade": 7, "practice": -3, "mastered": "yes"},
			{"id": ""},
		],
		"cultivation": {"sect_id": 5},
		"flags": {"tutorial_done": 1, "unknown_key": "x", "events_seen": [42, "bandits", ""]},
	})
	ok = _expect(ok, junk.traits == ["iron_shirt"], "junk traits filtered to Strings")
	ok = _expect(ok, junk.gongfa.size() == 1, "junk empty-id gongfa row dropped")
	ok = _expect(ok, junk.gongfa[0] == {"id": "g1", "grade": "", "practice": 0, "mastered": false}, "junk gongfa coerced shape")
	ok = _expect(ok, junk.cultivation["sect_id"] == "", "junk non-string sect_id -> empty")
	ok = _expect(ok, junk.flags["tutorial_done"] == false, "junk tutorial_done forced to bool")
	ok = _expect(ok, junk.flags["events_seen"] == ["bandits"], "junk events_seen filtered")
	ok = _expect(ok, not junk.flags.has("unknown_key"), "junk unknown flag dropped")

	# non-Dictionary inputs (what JSON.parse_string may hand back) -> fresh default
	var not_dict: PlayerProfile = PlayerProfile.from_dict("not a dict")
	ok = _expect(ok, not_dict is PlayerProfile, "non-dict input yields a PlayerProfile")
	ok = _expect(ok, not_dict.get_attr("bone") == 10 and not_dict.silver == 0, "non-dict input default fields")
	var null_src: PlayerProfile = PlayerProfile.from_dict(null)
	ok = _expect(ok, null_src is PlayerProfile, "null input yields a PlayerProfile")
	ok = _expect(ok, null_src.cultivation == {"year": 1, "month": 1, "sect_id": ""}, "null input default cultivation")
	return ok


# --- criterion 8: JSON round-trip --------------------------------------------

static func _test_json_roundtrip(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.set_attr("bone", 18)
	p.set_attr("inner", 16)
	p.add_trait("ambidextrous")
	p.add_gongfa("wudang_taiji_c", "C")
	p.master_gongfa_of("wudang_taiji_c")
	p.silver = 99
	p.cultivation["year"] = 3
	p.cultivation["month"] = 12
	p.cultivation["sect_id"] = "wudang"
	p.map_node = "kunlun"
	p.flags["tutorial_done"] = true
	p.flags["events_seen"].append("merchant")
	p.main_external_id = "wudang_taiji_c"

	var json := JSON.stringify(p.to_dict())
	ok = _expect(ok, json != "", "JSON.stringify produced output (all keys String)")
	var parsed: Variant = JSON.parse_string(json)
	ok = _expect(ok, parsed is Dictionary, "JSON.parse_string yields a Dictionary")
	if parsed is Dictionary:
		var restored: PlayerProfile = PlayerProfile.from_dict(parsed)
		ok = _expect(ok, restored.to_dict() == p.to_dict(), "JSON round-trip preserves profile")
		ok = _expect(ok, restored.get_attr("bone") == 18, "JSON round-trip attr preserved")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_player_profile: " + msg)
	return false
