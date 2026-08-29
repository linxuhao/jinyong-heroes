class_name FacilityData

## 门派设施 (sect facility) data pool — the third jianghu map-node content type.
## Pure data layer, mirrors EventData: class_name + internal RefCounted class +
## const TABLE + static def()/all()/_build(). A facility has ONE action (not a
## binary option_a/option_b — that would make it "a second event"), so each row
## carries a flat `effects` array in the same shape as EventData.EventOption.effects.
## Effects use ONLY the closed domain {silver, attr, practice, none}.
##
## This file is the single sanctioned text source for facility prose (the §433
## rule: no inline anecdotes in map_data.gd / map.gd). The preload edge is
## reversed: map_data.gd preloads this file; this file never references map_data.gd.

class FacilityDef extends RefCounted:
	var id: String = ""
	var node: String = ""                    # the node id this facility binds to ("shaolin" / "wudang")
	var title: String = ""                   # Chinese
	var text: String = ""                    # 2-line Chinese body (contains one \n)
	var action_label: String = ""            # the use prompt
	var effects: Array[Dictionary] = []      # each {"type": "silver"|"attr"|"practice"|"none", "value": int, "target": String}


## 2 facility rows, order: shaolin, wudang. The silver cost is carried as a
## negative "silver" effect (same convention as EventData rows); the gain is an
## "attr" effect. Magnitudes are "functional enough", NOT tuned (phase 5 owns
## numerical tuning).
const TABLE: Array = [
	{
		"id": "shaolin_wooden_men", "node": "shaolin",
		"title": "木人巷",
		"text": "木人巷中十八尊木人，\n拳脚如雨，是少林弟子练骨之地。",
		"action_label": "入巷练骨",
		"effects": [
			{"type": "silver", "value": -8, "target": ""},
			{"type": "attr", "value": 2, "target": "bone"},
		],
	},
	{
		"id": "wudang_meditation", "node": "wudang",
		"title": "紫霄静修",
		"text": "紫霄宫静室檀香袅袅，\n吐纳之间，内力自生。",
		"action_label": "静室修内",
		"effects": [
			{"type": "silver", "value": -8, "target": ""},
			{"type": "attr", "value": 2, "target": "inner"},
		],
	},
]


## Fresh FacilityDef instances, table order.
static func all() -> Array[FacilityDef]:
	var out: Array[FacilityDef] = []
	for row in TABLE:
		out.append(_build(row))
	return out


## Fresh FacilityDef for an id; null if unknown.
static func def(id: String) -> FacilityDef:
	for row in TABLE:
		if row["id"] == id:
			return _build(row)
	return null


## The facility bound to node_id (first table row whose node matches); null if none.
## This is the single resolution point MapData.active_facility_id delegates to.
static func for_node(node_id: String) -> FacilityDef:
	for row in TABLE:
		if row["node"] == node_id:
			return _build(row)
	return null


## The absolute silver price = abs(sum of value where type == "silver" and value < 0);
## 0 if none. Null input returns 0 (never crashes).
static func silver_cost(def: FacilityDef) -> int:
	if def == null:
		return 0
	var total: int = 0
	for e in def.effects:
		var effect := e as Dictionary
		if effect.get("type", "") == "silver" and (effect.get("value", 0) as int) < 0:
			total += effect["value"] as int
	return absi(total)


static func _build(row: Dictionary) -> FacilityDef:
	var def := FacilityDef.new()
	def.id = row["id"] as String
	def.node = row["node"] as String
	def.title = row["title"] as String
	def.text = row["text"] as String
	def.action_label = row["action_label"] as String
	var effects: Array = row["effects"] as Array
	var out: Array[Dictionary] = []
	for e in effects:
		out.append((e as Dictionary).duplicate(true))
	def.effects = out
	return def
