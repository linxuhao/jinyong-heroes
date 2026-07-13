## GridManager (autoload)
##
## Singleton that owns the grid coordinate system, tile occupancy tracking,
## AStar2D pathfinding, movement validation, and range/AoE target queries.
##
## All grid coordinates are Vector2i where (0,0) is the top-left tile.
## World positions are in pixels; conversion uses TILE_SIZE and GRID_ORIGIN.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 15
const GRID_HEIGHT: int = 11
const GRID_ORIGIN: Vector2 = Vector2(32, 32)  # half-tile offset for centering

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Maps Vector2i grid coordinates to the occupying Node (character), if any.
var occupancy: Dictionary = {}

## AStar2D pathfinding graph. Points are indexed by id = y * GRID_WIDTH + x.
var astar: AStar2D = null

## Reference to the battlefield TileMap (set by battlefield.gd via set_tilemap).
var tilemap_ref: TileMap = null

# Four cardinal directions used for neighbor connections and movement.
const _DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),  # up
	Vector2i(0, 1),   # down
	Vector2i(-1, 0),  # left
	Vector2i(1, 0),   # right
]

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func _ready() -> void:
	astar = AStar2D.new()


## Store a reference to the battlefield TileMap for optional visual syncing.
## Does not rebuild the AStar grid — call setup_grid() separately.
func set_tilemap(tm: TileMap) -> void:
	tilemap_ref = tm


## Build (or rebuild) the AStar2D graph for the full GRID_WIDTH x GRID_HEIGHT
## area. Clears any existing graph first. All points start enabled.
## Called by battlefield.gd once in _ready().
func setup_grid() -> void:
	astar.clear()
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var id: int = y * GRID_WIDTH + x
			astar.add_point(id, Vector2(x, y))
	
	# Connect 4-directional neighbours.
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var id: int = y * GRID_WIDTH + x
			for dir in _DIRECTIONS:
				var nx: int = x + dir.x
				var ny: int = y + dir.y
				if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
					var nid: int = ny * GRID_WIDTH + nx
					if not astar.are_points_connected(id, nid):
						astar.connect_points(id, nid, true)


# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

## Convert a world pixel position to grid coordinates.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / TILE_SIZE)),
		int(floor(world_pos.y / TILE_SIZE))
	)


## Convert grid coordinates to the pixel-centre world position.
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * TILE_SIZE + GRID_ORIGIN.x,
		grid_pos.y * TILE_SIZE + GRID_ORIGIN.y
	)


# ---------------------------------------------------------------------------
# Bounds / occupancy queries
# ---------------------------------------------------------------------------

## Returns true if the given grid position is within the battlefield bounds.
func is_in_bounds(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH
		and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT)


## Returns true if a unit currently occupies the given grid position.
func is_occupied(grid_pos: Vector2i) -> bool:
	return occupancy.has(grid_pos)


# ---------------------------------------------------------------------------
# Occupancy management
# ---------------------------------------------------------------------------

## Mark a tile as occupied by the given unit. Returns true on success,
## false if the tile is already occupied or out of bounds.
func reserve_tile(grid_pos: Vector2i, unit: Node) -> bool:
	if not is_in_bounds(grid_pos):
		return false
	if is_occupied(grid_pos):
		return false
	
	occupancy[grid_pos] = unit
	
	# Disable the AStar point so pathfinding routes around this tile.
	if astar != null and astar.has_point(_point_id(grid_pos)):
		astar.set_point_disabled(_point_id(grid_pos), true)
	
	return true


## Clear occupancy for a tile, re-enabling the AStar point.
func free_tile(grid_pos: Vector2i) -> void:
	if occupancy.erase(grid_pos):
		if astar != null and astar.has_point(_point_id(grid_pos)):
			astar.set_point_disabled(_point_id(grid_pos), false)


## Move a unit from one tile to another. Animates with a Tween.
## Returns true if the move was successfully initiated.
## The caller should check is_in_bounds and is_occupied on 'to' first,
## though this method also validates.
func move_unit(unit: Node, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_in_bounds(to_pos):
		return false
	if is_occupied(to_pos):
		return false
	
	# Free the origin tile.
	free_tile(from_pos)
	
	# Reserve the destination.
	if not reserve_tile(to_pos, unit):
		# Re-reserve the origin if destination reservation fails (shouldn't
		# happen since we already checked, but guard anyway).
		reserve_tile(from_pos, unit)
		return false
	
	# Animate the movement.
	if unit is Node2D:
		var tween: Tween = create_tween()
		tween.bind_node(unit)
		tween.tween_property(unit, "position", grid_to_world(to_pos), 0.15)
	
	return true


# ---------------------------------------------------------------------------
# Pathfinding
# ---------------------------------------------------------------------------

## Find an A* path from 'from' to 'to' grid coordinates.
## Returns an empty array if no path exists or positions are out of bounds.
func find_path(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(from_pos) or not is_in_bounds(to_pos):
		return []
	
	var from_id: int = _point_id(from_pos)
	var to_id: int = _point_id(to_pos)
	
	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return []
	
	var path_ids: PackedInt64Array = astar.get_id_path(from_id, to_id)
	if path_ids.is_empty():
		return []
	
	var path: Array[Vector2i] = []
	for pid in path_ids:
		var x: int = pid % GRID_WIDTH
		var y: int = pid / GRID_WIDTH
		path.append(Vector2i(x, y))
	
	return path


# ---------------------------------------------------------------------------
# Move-range calculation (flood-fill BFS)
# ---------------------------------------------------------------------------

## Returns all reachable grid positions within the given movement budget.
## Uses BFS with 4-directional connectivity, respecting occupancy and bounds.
func get_move_range(origin: Vector2i, move_points: int) -> Array[Vector2i]:
	if move_points <= 0 or not is_in_bounds(origin):
		return []
	
	var visited: Dictionary = {}    # Vector2i -> distance
	var queue: Array[Dictionary] = []
	var result: Array[Vector2i] = []
	
	visited[origin] = 0
	queue.append({ "pos": origin, "dist": 0 })
	
	while queue.size() > 0:
		var current: Dictionary = queue.pop_front()
		for dir in _DIRECTIONS:
			var next_pos: Vector2i = current.pos + dir
			var next_dist: int = current.dist + 1
			
			if not is_in_bounds(next_pos):
				continue
			if next_dist > move_points:
				continue
			if is_occupied(next_pos):
				continue
			if visited.has(next_pos):
				continue
			
			visited[next_pos] = next_dist
			queue.append({ "pos": next_pos, "dist": next_dist })
			result.append(next_pos)
	
	return result


# ---------------------------------------------------------------------------
# Target queries
# ---------------------------------------------------------------------------

## Returns all units whose Chebyshev distance from origin <= range_val.
func get_units_in_range(origin: Vector2i, range_val: int) -> Array[Node]:
	var units: Array[Node] = []
	for grid_pos in occupancy.keys():
		if _chebyshev_distance(origin, grid_pos) <= range_val:
			var unit: Node = occupancy[grid_pos] as Node
			if unit != null and is_instance_valid(unit):
				units.append(unit)
	return units


## Returns units whose grid positions fall within the specified area-of-effect
## pattern centred at origin.
##
## shape   |  pattern
## --------|-------------------------------------------
## single  |  just the origin tile
## line    |  `size` tiles in `direction` from origin
## cross   |  origin + 4 cardinal neighbours
## square  |  (size*2+1)^2 Chebyshev ball centred at origin
##
## For "line", a non-zero direction must be provided.
func get_units_in_aoe(origin: Vector2i, shape: String, size: int,
		direction: Vector2i = Vector2i.ZERO) -> Array[Node]:
	
	var target_tiles: Array[Vector2i] = []
	
	match shape:
		"single":
			target_tiles.append(origin)
		
		"line":
			if direction == Vector2i.ZERO:
				# No direction given — try to auto-detect toward nearest enemy.
				var nearest: Vector2i = _nearest_enemy_direction(origin)
				if nearest != Vector2i.ZERO:
					direction = nearest
				else:
					return []  # No valid direction; no targets.
			
			for i in range(1, size + 1):
				var tile: Vector2i = origin + direction * i
				if is_in_bounds(tile):
					target_tiles.append(tile)
		
		"cross":
			target_tiles.append(origin)
			for dir in _DIRECTIONS:
				var tile: Vector2i = origin + dir
				if is_in_bounds(tile):
					target_tiles.append(tile)
		
		"square":
			for dx in range(-size, size + 1):
				for dy in range(-size, size + 1):
					var tile: Vector2i = origin + Vector2i(dx, dy)
					if is_in_bounds(tile):
						target_tiles.append(tile)
		
		_:
			# Unknown shape — treat as single.
			target_tiles.append(origin)
	
	# Collect units present on the target tiles.
	var units: Array[Node] = []
	for tile in target_tiles:
		if occupancy.has(tile):
			var unit: Node = occupancy[tile] as Node
			if unit != null and is_instance_valid(unit):
				units.append(unit)
	
	# Deduplicate (a unit occupies only one tile, but keep clean).
	units = _deduplicate_nodes(units)
	return units


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Compute the AStar point id for a grid position.
static func _point_id(grid_pos: Vector2i) -> int:
	return grid_pos.y * GRID_WIDTH + grid_pos.x


## Chebyshev distance between two grid positions.
static func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


## Find the direction toward the nearest occupied tile (enemy) from origin.
## Returns a cardinal unit vector, or Vector2i.ZERO if none found.
func _nearest_enemy_direction(origin: Vector2i) -> Vector2i:
	var nearest_dir: Vector2i = Vector2i.ZERO
	var nearest_dist: int = 9999
	
	for grid_pos in occupancy.keys():
		if grid_pos == origin:
			continue
		var dist: int = _chebyshev_distance(origin, grid_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			# Compute cardinal direction (prefer axis with larger delta).
			var dx: int = 0
			var dy: int = 0
			if grid_pos.x > origin.x:
				dx = 1
			elif grid_pos.x < origin.x:
				dx = -1
			if grid_pos.y > origin.y:
				dy = 1
			elif grid_pos.y < origin.y:
				dy = -1
			# If both axes differ, pick the one with larger absolute delta.
			if abs(grid_pos.x - origin.x) >= abs(grid_pos.y - origin.y):
				nearest_dir = Vector2i(dx, 0)
			else:
				nearest_dir = Vector2i(0, dy)
	
	return nearest_dir


## Remove duplicate Node references from an array while preserving order.
static func _deduplicate_nodes(arr: Array[Node]) -> Array[Node]:
	var seen: Dictionary = {}
	var result: Array[Node] = []
	for n in arr:
		var key: int = n.get_instance_id()
		if not seen.has(key):
			seen[key] = true
			result.append(n)
	return result
