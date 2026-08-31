## Unit pins for the Huashan duel map-battle data layer (jinyong-huashan round).
## Covers MapBattleData:
##   1. the huashan_duel opponent roster — exactly the five greats, in order
##   2. the fail-safe unknown binding — an unknown battle id reads inert
##   3. the position-table invariants — walkable interior, off the player spawn,
##      pairwise distinct (generic property pins, so a reposition does not break
##      them)
##
## Contract: plain GDScript (NO extends), top-level `static func run() -> bool`,
## push_error() on failure, print PASS/FAIL at the end. Collected by
## tests/unit_test_runner.gd's TESTS registry (append-only).

const MapBattleData = preload("res://scripts/data/map_battle_data.gd")

## The fixed player spawn for every battle path (battlefield._instantiate_player).
const PLAYER_SPAWN: Vector2i = Vector2i(7, 5)

## The walkable-interior bounds (battleboard cols 1..13, rows 1..9).
const COL_MIN: int = 1
const COL_MAX: int = 13
const ROW_MIN: int = 1
const ROW_MAX: int = 9


static func run() -> bool:
	var ok: bool = true
	ok = _test_roster(ok)
	ok = _test_positions(ok)
	if ok:
		print("PASS: test_map_battle_data")
	else:
		print("FAIL: test_map_battle_data")
	return ok


static func _test_roster(ok: bool) -> bool:
	var expected: Array[String] = [
		"East Heretic", "West Poison", "South Emperor", "North Beggar", "Central Divine",
	]
	var got: Array[String] = MapBattleData.roster_ids("huashan_duel")
	ok = _expect(ok, got == expected,
			"roster_ids(huashan_duel) returns the five greats in order (got %s)" % str(got))
	ok = _expect(ok, got.size() == 5,
			"huashan_duel fields exactly five opponents (got %d)" % got.size())
	var unknown: Array[String] = MapBattleData.roster_ids("no_such_battle")
	ok = _expect(ok, unknown.is_empty(),
			"roster_ids(unknown) -> [] (fail-safe, inert)")
	return ok


static func _test_positions(ok: bool) -> bool:
	var pos: Dictionary = MapBattleData.POSITIONS.get("huashan_duel", {})
	ok = _expect(ok, not pos.is_empty(), "POSITIONS['huashan_duel'] is non-empty")
	var seen: Array[Vector2i] = []
	for key in pos:
		var tile: Vector2i = pos[key] as Vector2i
		ok = _expect(ok, tile.x >= COL_MIN and tile.x <= COL_MAX
				and tile.y >= ROW_MIN and tile.y <= ROW_MAX,
				"%s tile %s inside walkable interior (col %d..%d, row %d..%d)"
				% [key, str(tile), COL_MIN, COL_MAX, ROW_MIN, ROW_MAX])
		ok = _expect(ok, tile != PLAYER_SPAWN,
				"%s tile %s is not the player spawn (7,5)" % [key, str(tile)])
		ok = _expect(ok, not seen.has(tile),
				"%s tile %s is pairwise distinct" % [key, str(tile)])
		seen.append(tile)
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_map_battle_data: " + what)
	return ok_so_far and cond
