class_name MapBattleData

## Map-battle data layer for the Huashan summit finale (jinyong-huashan round).
##
## Pure static data — zero autoload dependency, mirrors the MapData / EventData /
## FacilityData data-layer pattern. Supplies the opponent roster and spawn
## positions for each consumed map battle id, fail-safe (an unknown binding is
## inert, never a crash).
##
## The only live binding today is `huashan_duel` (华山's battle slot — see
## map_data.gd:48-49). Its opponent roster is the five greats, composed entirely
## from existing enemy/character data (no new assets, no new combat system).

## Battle id -> ordered opponent roster (the `character_name` spelling the
## CombatManager.turn_order carries, spaces preserved).
const ROSTERS: Dictionary = {
	"huashan_duel": ["East Heretic", "West Poison", "South Emperor", "North Beggar", "Central Divine"],
}

## Map-battle spawn layout — OWNED here, never read from the tutorial's
## positions dict, so the tutorial battlefield stays byte-identical.
## Invariants (each tile must satisfy all of them):
##   - inside the walkable interior: col 1..13, row 1..9
##   - NOT the player spawn (7,5) and not on the player's row 5 / column 7
##     (line-caster deny)
##   - pairwise distinct
## Player spawn is fixed at (7,5) for every battle path.
const PLAYER_SPAWN: Vector2i = Vector2i(7, 5)

const POSITIONS: Dictionary = {
	"huashan_duel": {
		"East Heretic":   Vector2i(1, 1),
		"West Poison":    Vector2i(1, 4),
		"South Emperor":  Vector2i(1, 9),
		"North Beggar":   Vector2i(13, 9),
		"Central Divine": Vector2i(13, 1),
	},
}


## The opponent roster (as `character_name` strings, in order) for a battle id.
## An unknown / typo'd / empty binding reads as [] — inert, never a crash.
static func roster_ids(battle_id: String) -> Array[String]:
	var list: Variant = ROSTERS.get(battle_id, [])
	if typeof(list) != TYPE_ARRAY:
		return []
	var out: Array[String] = []
	for name in list:
		out.append(name as String)
	return out


## The spawn tile for a battle id's named opponent. Vector2i.ZERO when the
## battle id or the name key is unknown — inert, never a crash.
static func position_for(battle_id: String, name_key: String) -> Vector2i:
	var battle_positions: Variant = POSITIONS.get(battle_id, {})
	if typeof(battle_positions) != TYPE_DICTIONARY:
		return Vector2i.ZERO
	var tile: Variant = (battle_positions as Dictionary).get(name_key, Vector2i.ZERO)
	if typeof(tile) != TYPE_VECTOR2I:
		return Vector2i.ZERO
	return tile as Vector2i
