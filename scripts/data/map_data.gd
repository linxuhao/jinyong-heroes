class_name MapData

## Map for segment 6 (step2_design §8.7): 6 nodes, undirected adjacency, and
## the 3 ending tiers (step2_design §8.8). Pure data layer — node selection
## (adjacency-validated focus moves), travel and ending routing belong to the
## map segment; this file only supplies the graph and the tier thresholds.

## Event pool used to resolve node-entry event bindings (the single sanctioned
## text source — see design/20_content.md §8). Preloaded directly; event_data.gd
## is pure data and does not reference map_data.gd, so this is a safe one-way edge.
const EventData = preload("res://scripts/data/event_data.gd")
## Sect-facility data pool (the single sanctioned text source for facility prose —
## design/20_content.md §8). Preloaded directly; facility_data.gd is pure data and
## does not reference map_data.gd, so this is a safe one-way edge (mirrors EventData).
const FacilityData = preload("res://scripts/data/facility_data.gd")

## Per-node entry-content declaration slots (design/20_content.md §8.1).
## Status domain: "active" (implemented + live) | "declared" (declaration-only,
## unimplemented). Battle stays declared everywhere except 华山 (huashan_duel);
## facility is live on 少林 (shaolin_wooden_men) and 武当 (wudang_meditation), the
## two sects, and stays declared on the other five nodes. Mainline event slots are LIVE:
## wuming_valley/luoyang/wudang/xiangyang each bind a deterministic event_id from
## the pool (literal rows — never a pool draw, keeping the node-event and
## cultivation channels' events_seen independent). The end node (kunlun) stays
## declared because end-node routing runs BEFORE entry content, so a future
## end-node event can never silently block the ending. Each slot's id
## key is <type>_id (event_id / battle_id / facility_id).
## 6 map nodes. Mainline = 无名谷→洛阳→武当→襄阳→昆仑 (4 moves); 少林 is a
## branch off 洛阳. Only kunlun is an end node.
const NODES: Array = [
	{"id": "wuming_valley", "display_name": "无名谷", "is_end": false,
		"entry_content": {"event": {"status": "active", "event_id": "tomb_bed"}, "battle": {"status": "declared", "battle_id": ""}, "facility": {"status": "declared", "facility_id": ""}}},
	{"id": "luoyang", "display_name": "洛阳", "is_end": false,
		"entry_content": {"event": {"status": "active", "event_id": "merchant"}, "battle": {"status": "declared", "battle_id": ""}, "facility": {"status": "declared", "facility_id": ""}}},
	{"id": "wudang", "display_name": "武当", "is_end": false,
		"entry_content": {"event": {"status": "active", "event_id": "quanzhen_scripture"}, "battle": {"status": "declared", "battle_id": ""}, "facility": {"status": "active", "facility_id": "wudang_meditation"}}},
	{"id": "xiangyang", "display_name": "襄阳", "is_end": false,
		"entry_content": {"event": {"status": "active", "event_id": "dragon_scrap"}, "battle": {"status": "declared", "battle_id": ""}, "facility": {"status": "declared", "facility_id": ""}}},
	{"id": "kunlun", "display_name": "昆仑", "is_end": true,
		"entry_content": {"event": {"status": "declared", "event_id": ""}, "battle": {"status": "declared", "battle_id": ""}, "facility": {"status": "declared", "facility_id": ""}}},
	{"id": "shaolin", "display_name": "少林", "is_end": false,
		"entry_content": {"event": {"status": "active", "event_id": "night_rain"}, "battle": {"status": "declared", "battle_id": ""}, "facility": {"status": "active", "facility_id": "shaolin_wooden_men"}}},
	# 华山 is the first node whose BATTLE slot is live, and it carries no event
	# on purpose: a node holding both would need a precedence rule, and inventing
	# one belongs in a design decision, not in a data row. Hanging it off 少林
	# (itself a branch) keeps the mainline spine byte-identical, so the travel
	# scenarios that walk 无名谷→…→昆仑 never see it.
	{"id": "huashan", "display_name": "华山", "is_end": false,
		"entry_content": {"event": {"status": "declared", "event_id": ""}, "battle": {"status": "active", "battle_id": "huashan_duel"}, "facility": {"status": "declared", "facility_id": ""}}},
]

## Undirected adjacency — both directions are listed explicitly.
const ADJACENCY: Dictionary = {
	"wuming_valley": ["luoyang"],
	"luoyang": ["wuming_valley", "wudang", "shaolin"],
	"wudang": ["luoyang", "xiangyang"],
	"xiangyang": ["wudang", "kunlun"],
	"kunlun": ["xiangyang"],
	"shaolin": ["luoyang", "huashan"],
	"huashan": ["shaolin"],
}

## Huashan readiness band thresholds (R3 D4). Set by M3 from the measured
## win/lose split on the current tree (measured 2026-09-01, R3 M3, seeds s1..s5),
## NOT by eyeballing the composite range. readiness() in battle_setup.gd reads
## these: power < even -> weak; even <= power < strong -> even; power >= strong
## -> strong. A normally-played balanced route must exceed `even` on >= 4/5 seeds
## and win the duel on >= 4/5; a creation-fresh profile must score below `even`
## on all 5 seeds and lose. See design/40_progression.md §「华山战备」.
const HUASHAN_BAR: Dictionary = {"even": 30, "strong": 40}

## Ending tiers, descending by min_total (step2_design §8.8).
## total = bone + inner + agility + wisdom + fortune.
## INVARIANT: rows must stay sorted by min_total descending — ending_tier()
## scans top-down and returns the first row the total reaches. The final row's
## min_total is always 0, so any total yields at least tier 1.
const ENDING_TIERS: Array = [
	{"tier": 3, "min_total": 90, "title": "一代宗师",
		"text": "武林为之震动。\n你的名号传遍江湖，各派掌门纷纷登门请教。\n此世武学之巅，自此有了你的名字。"},
	{"tier": 2, "min_total": 60, "title": "武林名宿",
		"text": "江湖中人都认得你的名号。\n行至何处，皆有豪杰相迎。\n虽未登峰造极，亦是一方武林名宿。"},
	{"tier": 1, "min_total": 0, "title": "隐于市井",
		"text": "你收起兵刃，隐入市井。\n江湖纷争从此与你无关。\n唯有炊烟与酒香，伴你终老。"},
]


static func node_ids() -> Array[String]:
	var out: Array[String] = []
	for row in NODES:
		out.append(row["id"] as String)
	return out


## Deep-duplicated node row; {} if unknown.
static func node_def(id: String) -> Dictionary:
	for row in NODES:
		if row["id"] == id:
			return row.duplicate(true)
	return {}


## Adjacent node ids in listed order; [] if unknown.
static func neighbors(id: String) -> Array[String]:
	var out: Array[String] = []
	var list: Array = ADJACENCY.get(id, [])
	for n in list:
		out.append(n as String)
	return out


static func is_adjacent(a: String, b: String) -> bool:
	return neighbors(a).has(b)


static func is_end_node(id: String) -> bool:
	return node_def(id).get("is_end", false) == true


static func start_node() -> String:
	return "wuming_valley"


## Highest tier whose min_total the attribute total reaches; 1 floor.
static func ending_tier(total: int) -> int:
	for row in ENDING_TIERS:
		if total >= row["min_total"] as int:
			return row["tier"] as int
	return 1


## Deep-duplicated tier row; {} if unknown.
static func ending_def(tier: int) -> Dictionary:
	for row in ENDING_TIERS:
		if row["tier"] == tier:
			return row.duplicate(true)
	return {}


## The fixed slot-type order for entry-content traversal. Declared explicitly so
## declared_gap_types() output is deterministic regardless of Dictionary order.
const ENTRY_SLOT_TYPES: Array[String] = ["event", "battle", "facility"]


## Deep-duplicated entry_content for a node; {} if unknown.
static func entry_content(id: String) -> Dictionary:
	var row: Dictionary = node_def(id)
	if row.is_empty():
		return {}
	var ec: Variant = row.get("entry_content")
	if typeof(ec) != TYPE_DICTIONARY:
		return {}
	return (ec as Dictionary).duplicate(true)


## The event_id iff the node's event slot has status == "active" AND the id
## resolves in the event pool; "" otherwise. A typo'd / empty / unknown binding
## reads as inert (fail-safe, never a crash).
static func active_event_id(id: String) -> String:
	var ec: Dictionary = entry_content(id)
	var slot: Variant = ec.get("event")
	if typeof(slot) != TYPE_DICTIONARY:
		return ""
	if (slot as Dictionary).get("status", "") != "active":
		return ""
	var eid: Variant = (slot as Dictionary).get("event_id", "")
	if typeof(eid) != TYPE_STRING or eid == "":
		return ""
	if EventData.def(eid as String) == null:
		return ""
	return eid as String


## Slot types whose status == "declared" (unimplemented this round), in the
## fixed order event, battle, facility; [] if unknown. The honesty observable:
## declared-but-unimplemented content is assertable, not just documented.
## The node's battle-slot id when that slot is live, else "".
##
## Deliberately NOT symmetric with active_event_id(): that one rejects an id
## EventData cannot resolve, because a dangling event id would print empty prose
## at the player. There is no battle registry to check against yet — the game has
## exactly one battlefield — so the id is carried as a label for the encounter
## and validated only for presence. When a battle table lands, this is where it
## gets consulted, and the check belongs here rather than at the call site.
static func active_battle_id(id: String) -> String:
	var ec: Dictionary = entry_content(id)
	var slot: Variant = ec.get("battle")
	if typeof(slot) != TYPE_DICTIONARY:
		return ""
	if (slot as Dictionary).get("status", "") != "active":
		return ""
	var bid: Variant = (slot as Dictionary).get("battle_id", "")
	if typeof(bid) != TYPE_STRING or bid == "":
		return ""
	return bid as String


## The facility_id iff the node's facility slot has status == "active" AND the id
## resolves in the facility pool; "" otherwise. A typo'd / empty / unknown binding
## reads as inert (fail-safe, never a crash), exactly like active_event_id — a
## dangling facility id must not print empty prose at the player.
static func active_facility_id(id: String) -> String:
	var ec: Dictionary = entry_content(id)
	var slot: Variant = ec.get("facility")
	if typeof(slot) != TYPE_DICTIONARY:
		return ""
	if (slot as Dictionary).get("status", "") != "active":
		return ""
	var fid: Variant = (slot as Dictionary).get("facility_id", "")
	if typeof(fid) != TYPE_STRING or fid == "":
		return ""
	if FacilityData.def(fid as String) == null:
		return ""
	return fid as String


static func declared_gap_types(id: String) -> Array[String]:
	var out: Array[String] = []
	var ec: Dictionary = entry_content(id)
	if ec.is_empty():
		return out
	for slot_type in ENTRY_SLOT_TYPES:
		var slot: Variant = ec.get(slot_type)
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		if (slot as Dictionary).get("status", "") == "declared":
			out.append(slot_type)
	return out
