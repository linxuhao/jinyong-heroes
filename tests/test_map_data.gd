## Unit tests for scripts/data/map_data.gd (MapData registry).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).

const MapData = preload("res://scripts/data/map_data.gd")

const NODE_IDS := ["wuming_valley", "luoyang", "wudang", "xiangyang", "kunlun", "shaolin"]

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
	ok = _expect(ok, MapData.neighbors("shaolin") == ["luoyang"], "shaolin adjacent only to luoyang")
	ok = _expect(ok, MapData.neighbors("kunlun") == ["xiangyang"], "kunlun adjacent only to xiangyang")
	ok = _expect(ok, MapData.neighbors("nope").is_empty(), "neighbors unknown -> []")
	return ok


static func _test_ending_tiers(ok: bool) -> bool:
	ok = _expect(ok, MapData.ending_tier(90) == 3, "90 -> tier 3")
	ok = _expect(ok, MapData.ending_tier(120) == 3, "120 -> tier 3")
	ok = _expect(ok, MapData.ending_tier(89) == 2, "89 -> tier 2")
	ok = _expect(ok, MapData.ending_tier(60) == 2, "60 -> tier 2")
	ok = _expect(ok, MapData.ending_tier(59) == 1, "59 -> tier 1")
	ok = _expect(ok, MapData.ending_tier(0) == 1, "0 -> tier 1")
	ok = _expect(ok, MapData.ending_def(3)["title"] == "一代宗师", "tier 3 title")
	ok = _expect(ok, MapData.ending_def(2)["title"] == "武林名宿", "tier 2 title")
	ok = _expect(ok, MapData.ending_def(1)["title"] == "隐于市井", "tier 1 title")
	ok = _expect(ok, MapData.ending_def(9).is_empty(), "ending_def unknown -> {}")
	for tier in [1, 2, 3]:
		var text: String = MapData.ending_def(tier)["text"] as String
		ok = _expect(ok, text.length() > 20, "tier " + str(tier) + " text is 3-5 lines")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_map_data: " + msg)
	return false
