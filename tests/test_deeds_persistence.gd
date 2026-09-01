## Unit tests for PlayerProfile.deeds (R3 choice ledger schema).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by the unit_test_runner registry. Pure headless,
## no scene, no RNG (the seeded stream's op order is a lifeline — this task adds
## zero RNG ops).

const DEED_KEYS: Array[String] = [
	"work_months", "cultivate_months", "practice_months",
	"travel_resolved", "silver_earned", "rerolls_used_this_year",
]


static func run() -> bool:
	var ok := true
	ok = _test_new_default(ok)
	ok = _test_roundtrip(ok)
	ok = _test_legacy_no_deeds(ok)
	ok = _test_corrupted_values(ok)
	ok = _test_negative_clamp(ok)
	ok = _test_json_roundtrip(ok)
	if ok:
		print("PASS test_deeds_persistence")
	else:
		print("FAIL test_deeds_persistence")
	return ok


# --- criterion 1: fresh default profile has all six keys == 0 -----------------

static func _test_new_default(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	ok = _expect(ok, p.deeds.size() == 6, "new_default deeds.size() == 6")
	for key in DEED_KEYS:
		ok = _expect(ok, p.deeds.has(key), "new_default deeds has key " + key)
		ok = _expect(ok, p.deeds[key] == 0, "new_default deeds[" + key + "] == 0")
		ok = _expect(ok, p.get_deed(key) == 0, "get_deed(" + key + ") == 0")
	# no unknown keys
	for key in p.deeds.keys():
		ok = _expect(ok, DEED_KEYS.has(key), "no unknown deed key " + str(key))
	return ok


# --- criterion 2: nonzero values round-trip exactly through to_dict/from_dict --

static func _test_roundtrip(ok: bool) -> bool:
	var p1: PlayerProfile = PlayerProfile.new_default()
	p1.deeds["work_months"] = 3
	p1.deeds["cultivate_months"] = 5
	p1.deeds["practice_months"] = 7
	p1.deeds["travel_resolved"] = 2
	p1.deeds["silver_earned"] = 120
	p1.deeds["rerolls_used_this_year"] = 1
	# also set some unrelated fields to prove they survive untouched
	p1.set_attr("bone", 15)
	p1.add_gongfa("shaolin_yijin_d", "D")
	p1.silver = 42
	p1.flags["tutorial_done"] = true

	var p2: PlayerProfile = PlayerProfile.from_dict(p1.to_dict())
	for key in DEED_KEYS:
		ok = _expect(ok, p2.deeds[key] == p1.deeds[key], "roundtrip deed " + key)
	ok = _expect(ok, p2.get_attr("bone") == 15, "roundtrip keeps attrs")
	ok = _expect(ok, p2.gongfa == p1.gongfa, "roundtrip keeps gongfa")
	ok = _expect(ok, p2.silver == 42, "roundtrip keeps silver")
	ok = _expect(ok, p2.flags["tutorial_done"] == true, "roundtrip keeps flags")
	return ok


# --- criterion 3: a LEGACY dict with no "deeds" key loads with all 0 ----------

static func _test_legacy_no_deeds(ok: bool) -> bool:
	var legacy: Dictionary = {
		"attrs": {"bone": 18, "inner": 16, "agility": 14, "wisdom": 20, "fortune": 12},
		"gongfa": [{"id": "shaolin_yijin_d", "grade": "D", "practice": 4, "mastered": true}],
		"silver": 99,
		"inventory": ["qingfeng_sword"],
		"equipped": {"weapon": "qingfeng_sword", "armor": "", "boots": ""},
		"flags": {"tutorial_done": true, "events_seen": ["bandits"]},
	}
	var p: PlayerProfile = PlayerProfile.from_dict(legacy)
	for key in DEED_KEYS:
		ok = _expect(ok, p.deeds[key] == 0, "legacy deed " + key + " == 0")
	ok = _expect(ok, p.get_attr("bone") == 18, "legacy attrs preserved")
	ok = _expect(ok, p.gongfa.size() == 1, "legacy gongfa preserved")
	ok = _expect(ok, p.gongfa[0]["mastered"] == true, "legacy gongfa mastered preserved")
	ok = _expect(ok, p.silver == 99, "legacy silver preserved")
	ok = _expect(ok, p.inventory == ["qingfeng_sword"], "legacy inventory preserved")
	ok = _expect(ok, p.equipped_id("weapon") == "qingfeng_sword", "legacy equipped preserved")
	ok = _expect(ok, p.flags["tutorial_done"] == true, "legacy flags preserved")
	ok = _expect(ok, p.flags["events_seen"] == ["bandits"], "legacy events_seen preserved")
	return ok


# --- criterion 4: corrupted values coerce to ints >= 0 without crashing --------

static func _test_corrupted_values(ok: bool) -> bool:
	# "3" (String), true (bool), null, 2.7 (float) each independently coerced
	var cases: Array[Dictionary] = [
		{"work_months": "3"},
		{"cultivate_months": true},
		{"practice_months": null},
		{"travel_resolved": 2.7},
	]
	for c in cases:
		var src: Dictionary = {"deeds": c}
		var p: PlayerProfile = PlayerProfile.from_dict(src)
		for key in DEED_KEYS:
			var v: Variant = p.deeds[key]
			ok = _expect(ok, v is int, "corrupted " + key + " coerced to int")
			ok = _expect(ok, (v as int) >= 0, "corrupted " + key + " >= 0")
	# specific expected values
	var p_str: PlayerProfile = PlayerProfile.from_dict({"deeds": {"work_months": "3"}})
	ok = _expect(ok, p_str.deeds["work_months"] == 0, "String \"3\" -> 0")
	var p_bool: PlayerProfile = PlayerProfile.from_dict({"deeds": {"cultivate_months": true}})
	ok = _expect(ok, p_bool.deeds["cultivate_months"] == 0, "bool true -> 0")
	var p_null: PlayerProfile = PlayerProfile.from_dict({"deeds": {"practice_months": null}})
	ok = _expect(ok, p_null.deeds["practice_months"] == 0, "null -> 0")
	var p_float: PlayerProfile = PlayerProfile.from_dict({"deeds": {"travel_resolved": 2.7}})
	ok = _expect(ok, p_float.deeds["travel_resolved"] == 2, "float 2.7 -> 2")
	# non-Dictionary src_deeds (String / Array) -> all 0, no crash
	var p_arr: PlayerProfile = PlayerProfile.from_dict({"deeds": [1, 2, 3]})
	for key in DEED_KEYS:
		ok = _expect(ok, p_arr.deeds[key] == 0, "Array src_deeds " + key + " == 0")
	var p_str_src: PlayerProfile = PlayerProfile.from_dict({"deeds": "junk"})
	for key in DEED_KEYS:
		ok = _expect(ok, p_str_src.deeds[key] == 0, "String src_deeds " + key + " == 0")
	# unknown extra keys inside a saved deeds dict are dropped
	var p_extra: PlayerProfile = PlayerProfile.from_dict({"deeds": {"work_months": 2, "bogus": 9}})
	ok = _expect(ok, p_extra.deeds["work_months"] == 2, "known key kept")
	ok = _expect(ok, not p_extra.deeds.has("bogus"), "unknown extra key dropped")
	ok = _expect(ok, p_extra.deeds.size() == 6, "deeds.size() stays 6")
	return ok


# --- criterion 5: negative inputs clamp to 0 -----------------------------------

static func _test_negative_clamp(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.from_dict({"deeds": {"work_months": -5, "silver_earned": -1}})
	ok = _expect(ok, p.deeds["work_months"] == 0, "negative work_months clamped to 0")
	ok = _expect(ok, p.deeds["silver_earned"] == 0, "negative silver_earned clamped to 0")
	# get_deed also clamps
	var p2: PlayerProfile = PlayerProfile.new_default()
	p2.deeds["work_months"] = -3
	ok = _expect(ok, p2.get_deed("work_months") == 0, "get_deed clamps negative to 0")
	ok = _expect(ok, p2.get_deed("missing_key") == 0, "get_deed unknown key -> 0")
	return ok


# --- criterion 6: JSON round-trip preserves all six exactly --------------------

static func _test_json_roundtrip(ok: bool) -> bool:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.deeds["work_months"] = 4
	p.deeds["cultivate_months"] = 6
	p.deeds["practice_months"] = 8
	p.deeds["travel_resolved"] = 3
	p.deeds["silver_earned"] = 250
	p.deeds["rerolls_used_this_year"] = 2
	p.set_attr("wisdom", 19)
	p.flags["tutorial_done"] = true
	p.flags["events_seen"].append("merchant")

	var json := JSON.stringify(p.to_dict())
	ok = _expect(ok, json != "", "JSON.stringify produced output (all String keys)")
	var parsed: Variant = JSON.parse_string(json)
	ok = _expect(ok, parsed is Dictionary, "JSON.parse_string yields a Dictionary")
	if parsed is Dictionary:
		var restored: PlayerProfile = PlayerProfile.from_dict(parsed)
		for key in DEED_KEYS:
			ok = _expect(ok, restored.deeds[key] == p.deeds[key], "JSON roundtrip deed " + key)
		ok = _expect(ok, restored.get_attr("wisdom") == 19, "JSON roundtrip attr preserved")
		ok = _expect(ok, restored.flags["tutorial_done"] == true, "JSON roundtrip flags preserved")
		ok = _expect(ok, restored.flags["events_seen"] == ["merchant"], "JSON roundtrip events_seen preserved")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_deeds_persistence: " + msg)
	return false
