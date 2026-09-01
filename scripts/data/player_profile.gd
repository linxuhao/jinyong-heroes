class_name PlayerProfile
extends RefCounted

## Pure data layer for the persisted player character (step2_design C2 / C7).
## RefCounted — no scene-tree or autoload dependency. Every field is plain-JSON
## serializable (all String keys) so a profile round-trips losslessly through
## JSON.stringify / JSON.parse_string (research note: stringify returns "" for
## Dictionaries with non-String keys, so all keys here are Strings).
##
## Attr meaning (design/40_progression.md §7):
##   bone=根骨, inner=内力, agility=身法, wisdom=悟性, fortune=福缘.
## Floor rule (§7.1): attrs never go below 10 (creation minimum); there is NO
## ceiling — 20 is only the creation cap, cultivation can push higher.

const ATTR_KEYS: Array[String] = ["bone", "inner", "agility", "wisdom", "fortune"]
const ATTR_FLOOR: int = 10
const EquipmentData = preload("res://scripts/data/equipment_data.gd")

var attrs: Dictionary = {"bone": 10, "inner": 10, "agility": 10, "wisdom": 10, "fortune": 10}
var traits: Array[String] = []
var gongfa: Array[Dictionary] = []   # each {"id": String, "grade": String, "practice": int, "mastered": bool}
var silver: int = 0
var inventory: Array[String] = []
# Three equipment slots (兵刃/护甲/鞋履): slot -> an inventory equipment id or "".
# Plain Dictionary with String keys ONLY (a typed Dictionary is not JSON
# round-trip safe — godot#97137; save_manager's serialize_failed guard fails on
# non-String keys). Equipped ids are always a subset of inventory (see equip()
# and the from_dict repair).
var equipped: Dictionary = {"weapon": "", "armor": "", "boots": ""}
# Choice ledger (R3): per-run deed counters that feed the ending evaluation and
# the fortune reroll budget. String keys ONLY (JSON-lossless, mirrors the equipped
# precedent), int values, and every mutator clamps >= 0 (see get_deed / from_dict
# repair). These are first-class fields, NOT flags entries — flags.from_dict drops
# unknown keys, so a flags-stored deed would silently zero on load and make the
# ending lie.
var deeds: Dictionary = {"work_months": 0, "cultivate_months": 0, "practice_months": 0, "travel_resolved": 0, "silver_earned": 0, "rerolls_used_this_year": 0}
var companions: Array[String] = []   # empty this round; schema reserved (step2_design C2)
var cultivation: Dictionary = {"year": 1, "month": 1, "sect_id": ""}
var map_node: String = "wuming_valley"   # design/40_progression.md §5 start node 无名谷
var flags: Dictionary = {"tutorial_done": false, "events_seen": []}
var main_external_id: String = ""


static func new_default() -> PlayerProfile:
	return PlayerProfile.new()


func get_attr(key: String) -> int:
	var v: Variant = attrs.get(key, ATTR_FLOOR)
	if v is int:
		return v
	return ATTR_FLOOR


func set_attr(key: String, value: int) -> void:
	attrs[key] = maxi(value, ATTR_FLOOR)


func add_attr(key: String, delta: int) -> void:
	set_attr(key, get_attr(key) + delta)


func has_trait(id: String) -> bool:
	return traits.has(id)


func add_trait(id: String) -> void:
	if not has_trait(id):
		traits.append(id)


func remove_trait(id: String) -> void:
	traits.erase(id)


func has_gongfa(id: String) -> bool:
	return not get_gongfa(id).is_empty()


func get_gongfa(id: String) -> Dictionary:
	for entry in gongfa:
		if entry.get("id", "") == id:
			return entry
	return {}


func add_gongfa(id: String, grade: String = "") -> bool:
	if has_gongfa(id):
		return false
	gongfa.append({"id": id, "grade": grade, "practice": 0, "mastered": false})
	return true


func master_gongfa_of(id: String) -> bool:
	var entry := get_gongfa(id)
	if entry.is_empty():
		return false
	entry["mastered"] = true
	return true


## Plain-JSON serializable snapshot. Deep-duplicates the container fields so the
## caller can mutate the result without corrupting the live profile.
func to_dict() -> Dictionary:
	return {
		"attrs": attrs.duplicate(),
		"traits": traits.duplicate(),
		"gongfa": gongfa.duplicate(true),
		"silver": silver,
		"inventory": inventory.duplicate(),
		"companions": companions.duplicate(),
		"cultivation": cultivation.duplicate(),
		"map_node": map_node,
		"flags": flags.duplicate(true),
		"main_external_id": main_external_id,
		"equipped": _equipped_snapshot(),
		"deeds": deeds.duplicate(),
	}


## Restores a profile from untrusted save data. NEVER fails and never crashes:
## non-Dictionary input (null / String / Array — whatever JSON.parse_string
## produced) yields a fresh default profile; every field is coerced defensively
## (typed arrays are filtered BEFORE push — pushing a wrong type into
## Array[String]/Array[Dictionary] is a runtime error).
static func from_dict(d: Variant) -> PlayerProfile:
	var p := new_default()
	if not (d is Dictionary):
		return p
	var src: Dictionary = d

	# attrs — every known key coerced; missing/non-number -> floor; value clamped >= floor.
	# JSON has one numeric type (this build's parse_string returns floats for all
	# numbers), so int-or-float is accepted and coerced — never dropped.
	var src_attrs: Variant = src.get("attrs", {})
	if src_attrs is Dictionary:
		for key in ATTR_KEYS:
			var v: Variant = (src_attrs as Dictionary).get(key, ATTR_FLOOR)
			if v is int or v is float:
				p.attrs[key] = maxi(int(v), ATTR_FLOOR)
			else:
				p.attrs[key] = ATTR_FLOOR

	# traits — keep only non-empty Strings; never trust save data.
	_append_string_array(p.traits, src.get("traits", []))

	# gongfa — each entry forced to the exact shape; a bad/empty id drops the row.
	var src_gongfa: Variant = src.get("gongfa", [])
	if src_gongfa is Array:
		for raw in src_gongfa:
			if not (raw is Dictionary):
				continue
			var entry: Dictionary = raw
			var gid: Variant = entry.get("id", null)
			if not (gid is String) or (gid as String) == "":
				continue
			var grade: Variant = entry.get("grade", "")
			if not (grade is String):
				grade = ""
			var practice: Variant = entry.get("practice", 0)
			if not (practice is int or practice is float):
				practice = 0
			var mastered: Variant = entry.get("mastered", false)
			if not (mastered is bool):
				mastered = false
			p.gongfa.append({
				"id": gid as String,
				"grade": grade as String,
				"practice": maxi(practice as int, 0),
				"mastered": mastered as bool,
			})

	# silver — clamp >= 0 (int-or-float per JSON roundtrip).
	var src_silver: Variant = src.get("silver", 0)
	if src_silver is int or src_silver is float:
		p.silver = maxi(int(src_silver), 0)

	# inventory / companions — non-empty Strings only.
	_append_string_array(p.inventory, src.get("inventory", []))
	_append_string_array(p.companions, src.get("companions", []))
	# inventory must be coerced BEFORE equipped: the equipped-subset-of-inventory
	# repair below needs the coerced inventory to compare against.

	# equipped — three slots (weapon/armor/boots), each an inventory equipment id
	# or "". (a) non-Dictionary equipped (null / String / Array — or a LEGACY save
	# with no "equipped" key, which .get defaults to {}) -> keep the three-empty
	# slot default: no crash, nothing wiped. (b) only the three known slot keys are
	# read; a value is accepted iff it is a non-empty String, else "". Unknown slot
	# keys are naturally dropped. (c) invariant repair: an equipped id that is not
	# in the (already-coerced) inventory is dropped to "" — equipped is a subset of
	# inventory after load.
	var src_equipped: Variant = src.get("equipped", {})
	if src_equipped is Dictionary:
		var eq_src: Dictionary = src_equipped
		for slot in EquipmentData.SLOTS:
			var v: Variant = eq_src.get(slot, "")
			if v is String and (v as String) != "" and p.inventory.has(v as String):
				p.equipped[slot] = v as String
			else:
				p.equipped[slot] = ""

	# deeds — six known String keys, int values clamped >= 0. A non-Dictionary
	# src_deeds (null / String / Array — or a LEGACY save with no "deeds" key,
	# which .get defaults to {}) keeps all six at 0: no crash, nothing wiped.
	# Each known key: int-or-float -> maxi(int(v), 0); anything else (missing key,
	# String / bool / null / Array) -> 0. Unknown extra keys are naturally dropped.
	var src_deeds: Variant = src.get("deeds", {})
	if src_deeds is Dictionary:
		var dd: Dictionary = src_deeds
		for key in p.deeds.keys():
			var v: Variant = dd.get(key, 0)
			if v is int or v is float:
				p.deeds[key] = maxi(int(v), 0)
			else:
				p.deeds[key] = 0

	# cultivation — year 1..3, month 1..12, sect_id a String.
	var src_cult: Variant = src.get("cultivation", {})
	if src_cult is Dictionary:
		var cd: Dictionary = src_cult
		var year: Variant = cd.get("year", 1)
		if not (year is int or year is float):
			year = 1
		p.cultivation["year"] = clampi(int(year), 1, 3)
		var month: Variant = cd.get("month", 1)
		if not (month is int or month is float):
			month = 1
		p.cultivation["month"] = clampi(int(month), 1, 12)
		var sect_id: Variant = cd.get("sect_id", "")
		if sect_id is String:
			p.cultivation["sect_id"] = sect_id as String

	# map_node
	var src_map: Variant = src.get("map_node", "wuming_valley")
	if src_map is String:
		p.map_node = src_map as String

	# flags — unknown keys are dropped; tutorial_done coerced to bool;
	# events_seen keeps only non-empty Strings.
	var src_flags: Variant = src.get("flags", {})
	if src_flags is Dictionary:
		var fd: Dictionary = src_flags
		if fd.has("tutorial_done"):
			var td: Variant = fd.get("tutorial_done", false)
			p.flags["tutorial_done"] = (td is bool) and td
		_append_string_array(p.flags["events_seen"], fd.get("events_seen", []))

	# main_external_id
	var src_main: Variant = src.get("main_external_id", "")
	if src_main is String:
		p.main_external_id = src_main as String

	return p


## Equipped-slot id (defensive .get(slot, "")); "" for an unknown slot.
func equipped_id(slot: String) -> String:
	var v: Variant = equipped.get(slot, "")
	if v is String:
		return v as String
	return ""


## Equip `id` into `slot`. All failures are silent `false` (never push_error).
## Validation matrix (task_plan equipment_data_layer §3.1):
##   (a) slot not in EquipmentData.SLOTS            -> false
##   (b) id == ""                                    -> false (use unequip_slot to clear)
##   (c) id not in `inventory`                       -> false (装上的前提是该 id 真在 inventory 里)
##   (d) EquipmentData.slot_of(id) != slot           -> false (an armor id can never enter the weapon slot)
##   (e) same id already equipped in that slot       -> true (idempotent, no state change)
##   (f) different id in that slot                   -> true, overwrite (swap semantics;
##        the displaced item stays in inventory)
func equip(slot: String, id: String) -> bool:
	if not EquipmentData.SLOTS.has(slot):
		return false
	if id == "":
		return false
	if not inventory.has(id):
		return false
	if EquipmentData.slot_of(id) != slot:
		return false
	equipped[slot] = id
	return true


## Clear `slot` back to the empty slot. Invalid slot -> false; else set "" and
## return true (idempotent — clearing an already-empty slot is true).
func unequip_slot(slot: String) -> bool:
	if not EquipmentData.SLOTS.has(slot):
		return false
	equipped[slot] = ""
	return true


## Fresh plain {"weapon": v, "armor": v, "boots": v} each call (deep-copy
## semantics — caller mutation must not corrupt the live profile). String keys
## only, so to_dict stays JSON-lossless.
func _equipped_snapshot() -> Dictionary:
	return {
		"weapon": equipped_id("weapon"),
		"armor": equipped_id("armor"),
		"boots": equipped_id("boots"),
	}


## Read-only deed accessor (unified entry for downstream consumers). Defensive:
## a missing or wrong-typed value coerces to 0, never crashes.
func get_deed(key: String) -> int:
	var v: Variant = deeds.get(key, 0)
	if v is int or v is float:
		return maxi(int(v), 0)
	return 0


## Appends every non-empty String of `src` (a Variant that may not even be an
## Array) into the typed `out` array. Used for traits/inventory/companions/
## events_seen lists that must never crash on hostile save data.
static func _append_string_array(out: Array, src: Variant) -> void:
	if src is Array:
		for v in src:
			if v is String and (v as String) != "":
				out.append(v as String)
