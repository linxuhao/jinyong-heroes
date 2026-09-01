## Unit tests for scripts/data/map_data.gd (MapData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const MapData = preload("res://scripts/data/map_data.gd")
const EventData = preload("res://scripts/data/event_data.gd")

const NODE_IDS := ["wuming_valley", "luoyang", "wudang", "xiangyang", "kunlun", "shaolin", "huashan"]

## The §8.7 undirected graph, listed once per undirected edge.
const EDGES := [
	["wuming_valley", "luoyang"],
	["luoyang", "wudang"],
	["luoyang", "shaolin"],
	["wudang", "xiangyang"],
	["xiangyang", "kunlun"],
]


static func run() -> bool:
	var ok := true
	ok = _test_nodes(ok)
	ok = _test_adjacency(ok)
	ok = _test_ending_tiers(ok)
	ok = _test_entry_content(ok)
	if ok:
		print("PASS test_map_data")
	else:
		print("FAIL test_map_data")
	return ok


static func _test_nodes(ok: bool) -> bool:
	ok = _expect(ok, MapData.node_ids() == NODE_IDS, "node_ids order")
	ok = _expect(ok, MapData.start_node() == "wuming_valley", "start node wuming_valley")
	ok = _expect(ok, MapData.node_def("wuming_valley")["display_name"] == "无名谷", "wuming display name")
	ok = _expect(ok, MapData.node_def("nope").is_empty(), "node_def unknown -> {}")
	ok = _expect(ok, MapData.is_end_node("kunlun"), "kunlun is end node")
	ok = _expect(ok, not MapData.is_end_node("luoyang"), "luoyang not end")
	ok = _expect(ok, not MapData.is_end_node("nope"), "unknown node not end")
	return ok


static func _test_adjacency(ok: bool) -> bool:
	# every edge both ways
	for edge in EDGES:
		var a: String = edge[0]
		var b: String = edge[1]
		ok = _expect(ok, MapData.is_adjacent(a, b), "adjacent " + a + "-" + b)
		ok = _expect(ok, MapData.is_adjacent(b, a), "adjacent " + b + "-" + a)
	# symmetry for every ordered pair (incl. self)
	for a in NODE_IDS:
		for b in NODE_IDS:
			ok = _expect(ok, MapData.is_adjacent(a, b) == MapData.is_adjacent(b, a), "symmetric " + a + "/" + b)
	# no non-edge adjacency on the graph
	ok = _expect(ok, not MapData.is_adjacent("wuming_valley", "wudang"), "no wuming-wudang")
	ok = _expect(ok, not MapData.is_adjacent("wuming_valley", "shaolin"), "no wuming-shaolin")
	ok = _expect(ok, not MapData.is_adjacent("shaolin", "wudang"), "no shaolin-wudang")
	ok = _expect(ok, not MapData.is_adjacent("shaolin", "xiangyang"), "no shaolin-xiangyang")
	ok = _expect(ok, not MapData.is_adjacent("wudang", "kunlun"), "no wudang-kunlun")
	# neighbors exactly per the graph
	# 少林 gained 华山 as a branch neighbour (the first live battle node). The
	# mainline spine is untouched, which is why the travel scenarios that walk
	# 无名谷→…→昆仑 never see it — asserted just below for 昆仑.
	ok = _expect(ok, MapData.neighbors("shaolin") == ["luoyang", "huashan"], "shaolin adjacent to luoyang + huashan")
	ok = _expect(ok, MapData.neighbors("huashan") == ["shaolin"], "huashan hangs off shaolin only")
	ok = _expect(ok, MapData.is_adjacent("shaolin", "huashan") and MapData.is_adjacent("huashan", "shaolin"), "shaolin-huashan is undirected")
	ok = _expect(ok, not MapData.is_adjacent("luoyang", "huashan"), "huashan is not on the mainline")
	ok = _expect(ok, MapData.neighbors("kunlun") == ["xiangyang"], "kunlun adjacent only to xiangyang")
	ok = _expect(ok, MapData.neighbors("nope").is_empty(), "neighbors unknown -> []")
	return ok


static func _test_ending_tiers(ok: bool) -> bool:
	ok = _expect(ok, MapData.ending_tier_score(90) == 3, "90 -> tier 3")
	ok = _expect(ok, MapData.ending_tier_score(120) == 3, "120 -> tier 3")
	ok = _expect(ok, MapData.ending_tier_score(89) == 2, "89 -> tier 2")
	ok = _expect(ok, MapData.ending_tier_score(60) == 2, "60 -> tier 2")
	ok = _expect(ok, MapData.ending_tier_score(59) == 1, "59 -> tier 1")
	ok = _expect(ok, MapData.ending_tier_score(0) == 1, "0 -> tier 1")
	ok = _expect(ok, MapData.ending_def(3)["title"] == "一代宗师", "tier 3 title")
	ok = _expect(ok, MapData.ending_def(2)["title"] == "武林名宿", "tier 2 title")
	ok = _expect(ok, MapData.ending_def(1)["title"] == "隐于市井", "tier 1 title")
	ok = _expect(ok, MapData.ending_def(9).is_empty(), "ending_def unknown -> {}")
	for tier in [1, 2, 3]:
		var text: String = MapData.ending_def(tier)["text"] as String
		ok = _expect(ok, text.length() > 20, "tier " + str(tier) + " text is 3-5 lines")
	return ok


static func _test_entry_content(ok: bool) -> bool:
	# every node declares exactly the three slots event / battle / facility
	for nid in NODE_IDS:
		var ec: Dictionary = MapData.entry_content(nid)
		ok = _expect(ok, ec.has("event") and ec.has("battle") and ec.has("facility"),
			"entry_content " + nid + " has 3 slots")
		ok = _expect(ok, ec.size() == 3, "entry_content " + nid + " has exactly 3 keys")
	# status domain is {active, declared} for every slot
	for nid in NODE_IDS:
		for slot_type in ["event", "battle", "facility"]:
			var slot: Dictionary = MapData.entry_content(nid)[slot_type]
			var status: String = slot.get("status", "")
			ok = _expect(ok, status == "active" or status == "declared",
				nid + " slot " + slot_type + " status in {active,declared}")
	# Eight ACTIVE slots across the table, of three kinds — and they are counted
	# SEPARATELY on purpose. The old single total said "five active event slots"
	# and was true only while every live slot happened to be an event; the moment
	# 华山's battle went live, one total could have stayed green while describing
	# the table wrongly. Five events (the four mainline + 少林), one battle
	# (华山, the first non-event slot to be implemented) and two facilities
	# (少林's 木人巷 + 武当's 紫霄静修, the two sects).
	var active_event_count := 0
	var active_battle_count := 0
	var active_facility_count := 0
	for nid in NODE_IDS:
		for slot_type in ["event", "battle", "facility"]:
			if MapData.entry_content(nid)[slot_type].get("status", "") != "active":
				continue
			if slot_type == "event":
				active_event_count += 1
			elif slot_type == "battle":
				active_battle_count += 1
			else:
				active_facility_count += 1
	ok = _expect(ok, active_event_count == 5, "five active event slots (the four mainline + 少林), got %d" % active_event_count)
	ok = _expect(ok, active_battle_count == 1, "one active battle slot (华山), got %d" % active_battle_count)
	ok = _expect(ok, active_facility_count == 2, "two active facility slots (少林/武当), got %d" % active_facility_count)
	# shaolin binding: shape + resolves in the pool + deep copy
	var shaolin_event: Dictionary = MapData.entry_content("shaolin")["event"]
	ok = _expect(ok, shaolin_event == {"status": "active", "event_id": "night_rain"},
		"shaolin event slot shape")
	ok = _expect(ok, MapData.active_event_id("shaolin") == "night_rain",
		"active_event_id shaolin")
	ok = _expect(ok, EventData.def(MapData.active_event_id("shaolin")) != null,
		"night_rain binding resolves in pool")
	# deep copy: mutating a returned entry_content must not leak into the const
	var deep: Dictionary = MapData.entry_content("shaolin")
	deep.erase("event")
	var reread: Dictionary = MapData.entry_content("shaolin")
	ok = _expect(ok, reread.has("event"), "entry_content deep copy: event key survives caller mutation")
	ok = _expect(ok, reread["event"] == {"status": "active", "event_id": "night_rain"},
		"entry_content deep copy: value intact")
	# mainline nodes: four carry live deterministic bindings; the end node
	# (kunlun) stays inert. Its event slot is declared because _travel() routes
	# an end node to ENDING BEFORE _maybe_start_entry_event() runs — a structural
	# non-trigger, so the terminal pin below is the machine-readable form of the
	# terminal-node rule (the ending can never be blocked by node content).
	ok = _expect(ok, MapData.active_event_id("wuming_valley") == "tomb_bed", "active_event_id wuming_valley bound to tomb_bed")
	ok = _expect(ok, MapData.active_event_id("luoyang") == "merchant", "active_event_id luoyang bound to merchant")
	ok = _expect(ok, MapData.active_event_id("wudang") == "quanzhen_scripture", "active_event_id wudang bound to quanzhen_scripture")
	ok = _expect(ok, MapData.active_event_id("xiangyang") == "dragon_scrap", "active_event_id xiangyang bound to dragon_scrap")
	ok = _expect(ok, MapData.active_event_id("kunlun") == "", "active_event_id kunlun stays inert (terminal guarantee)")
	ok = _expect(ok, MapData.declared_gap_types("luoyang") == ["battle", "facility"],
		"luoyang declared gap types (event slot now live -> fixed order [battle, facility])")
	ok = _expect(ok, MapData.declared_gap_types("wuming_valley") == ["battle", "facility"],
		"wuming_valley declared gap types (event slot now live -> fixed order [battle, facility])")
	ok = _expect(ok, MapData.declared_gap_types("shaolin") == ["battle"],
		"shaolin declared gap types (facility now live -> [battle])")
	# wudang is flipped too: facility drops from its gap list, battle remains. This
	# per-node pin exists precisely so an implementer cannot fake the total (two
	# active facility slots) while leaving wudang unimplemented — the honesty
	# observable must MOVE per-node, not just add up.
	ok = _expect(ok, MapData.declared_gap_types("wudang") == ["battle"],
		"wudang declared gap types (facility now live -> [battle])")
	# active_facility_id resolves the flipped bindings and stays inert elsewhere.
	ok = _expect(ok, MapData.active_facility_id("shaolin") == "shaolin_wooden_men",
		"active_facility_id shaolin -> shaolin_wooden_men")
	ok = _expect(ok, MapData.active_facility_id("wudang") == "wudang_meditation",
		"active_facility_id wudang -> wudang_meditation")
	ok = _expect(ok, MapData.active_facility_id("luoyang") == "",
		"active_facility_id luoyang stays inert (declared)")
	ok = _expect(ok, MapData.active_facility_id("huashan") == "",
		"active_facility_id huashan stays inert (declared)")
	ok = _expect(ok, MapData.active_facility_id("kunlun") == "",
		"active_facility_id kunlun stays inert (declared)")
	ok = _expect(ok, MapData.active_facility_id("xiangyang") == "",
		"active_facility_id xiangyang stays inert (declared)")
	ok = _expect(ok, MapData.active_facility_id("wuming_valley") == "",
		"active_facility_id wuming_valley stays inert (declared)")
	ok = _expect(ok, MapData.active_facility_id("nope") == "",
		"active_facility_id unknown -> \"\"")
	# unknown node degrades inert
	ok = _expect(ok, MapData.entry_content("nope").is_empty(), "entry_content unknown -> {}")
	ok = _expect(ok, MapData.active_event_id("nope") == "", "active_event_id unknown -> \"\"")
	ok = _expect(ok, MapData.declared_gap_types("nope").is_empty(), "declared_gap_types unknown -> []")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_map_data: " + msg)
	return false
