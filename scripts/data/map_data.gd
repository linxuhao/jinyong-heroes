class_name MapData

## Map for segment 6 (step2_design §8.7): 6 nodes, undirected adjacency, and
## the 3 ending tiers (step2_design §8.8). Pure data layer — node selection
## (adjacency-validated focus moves), travel and ending routing belong to the
## map segment; this file only supplies the graph and the tier thresholds.

## 6 map nodes. Mainline = 无名谷→洛阳→武当→襄阳→昆仑 (4 moves); 少林 is a
## branch off 洛阳. Only kunlun is an end node.
const NODES: Array = [
	{"id": "wuming_valley", "display_name": "无名谷", "is_end": false},
	{"id": "luoyang", "display_name": "洛阳", "is_end": false},
	{"id": "wudang", "display_name": "武当", "is_end": false},
	{"id": "xiangyang", "display_name": "襄阳", "is_end": false},
	{"id": "kunlun", "display_name": "昆仑", "is_end": true},
	{"id": "shaolin", "display_name": "少林", "is_end": false},
]

## Undirected adjacency — both directions are listed explicitly.
const ADJACENCY: Dictionary = {
	"wuming_valley": ["luoyang"],
	"luoyang": ["wuming_valley", "wudang", "shaolin"],
	"wudang": ["luoyang", "xiangyang"],
	"xiangyang": ["wudang", "kunlun"],
	"kunlun": ["xiangyang"],
	"shaolin": ["luoyang"],
}

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
