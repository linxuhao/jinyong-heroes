## GridManager (autoload)
##
## Singleton that owns the grid coordinate system, tile occupancy tracking,
## AStar2D pathfinding, movement validation, and range/AoE target queries.
##
## All grid coordinates are Vector2i where (0,0) is the top-left tile.
## World positions are in pixels; conversion uses TILE_SIZE and GRID_ORIGIN.
##
## Gate verification (reverify_deployable_gates): green — the move-unit SFX
## hook (AudioManager.play_move() after a successful destination reserve)
## resolves against the AudioManager autoload; no parse / cascade-load
## failure. Documentation only, no logic changes.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 15
const GRID_HEIGHT: int = 11
const GRID_ORIGIN: Vector2 = Vector2(32, 32)  # half-tile offset for centering

## Bottom edge of the 0..92 top strip (presentation constant). Portrait ink may
## not start above it, so the clamp keeps top-row textures below the strip.
const BOARD_TOP_MARGIN_Y: float = 92.0

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
	
	# Permanently disable the border-ring points (walls). The graph is STATIC
	# GEOMETRY — occupancy never toggles points (see reserve_tile/free_tile),
	# so interior endpoints (player/enemy tiles) are always enabled and
	# find_path returns a real path even when the destination is occupied.
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if not is_walkable(Vector2i(x, y)):
				astar.set_point_disabled(y * GRID_WIDTH + x, true)


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


## Returns true if the given grid position is walkable: it must be inside the
## battlefield bounds AND not on the border ring (which is painted as stone
## walls). Border tiles are permanently disabled in the AStar graph, so the
## AStar geometry is static — occupancy never disables points.
func is_walkable(grid_pos: Vector2i) -> bool:
	if not is_in_bounds(grid_pos):
		return false
	if grid_pos.x == 0 or grid_pos.x == GRID_WIDTH - 1:
		return false
	if grid_pos.y == 0 or grid_pos.y == GRID_HEIGHT - 1:
		return false
	return true


## Offset for a centered sprite whose feet sit at `position` (preferred offset
## (0,-half.y)), clamped so the whole texture rect stays inside the board
## artwork rect [0, GRID_WIDTH*TILE_SIZE] x [0, GRID_HEIGHT*TILE_SIZE].
## Returns the preferred feet-anchor offset when no clamp is needed.
static func clamp_sprite_offset(position: Vector2, tex_size: Vector2) -> Vector2:
	var half: Vector2 = tex_size / 2.0
	var board: Vector2 = Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
	var offset := Vector2(0.0, -half.y)  # preferred: feet at node position
	# Guard: if the texture is larger than the board on either axis, keep the
	# preferred offset rather than inverting the clamp bounds.
	if tex_size.x >= board.x or tex_size.y >= board.y:
		return offset
	var origin: Vector2 = position + offset
	var clamped := Vector2(
		clampf(origin.x, half.x, board.x - half.x),
		clampf(origin.y, BOARD_TOP_MARGIN_Y + half.y, board.y - half.y))
	return clamped - position


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
	
	# NOTE: occupancy intentionally does NOT disable the AStar point. The graph
	# is static geometry (walls only); disabling the player's endpoint made
	# get_id_path return an empty array (Godot returns [] when an endpoint is
	# disabled), so enemies could never path to the player.
	
	return true


## Clear occupancy for a tile. Occupancy does not mutate the AStar graph
## (static geometry), so this only removes the dictionary entry.
func free_tile(grid_pos: Vector2i) -> void:
	occupancy.erase(grid_pos)


## Release every tile occupancy (the unit<->tile mapping) so a torn-down
## battlefield's units stop occupying the grid before the next scene
## instantiates. The grid geometry (AStar graph / tilemap ref) is kept intact —
## battlefield.gd re-calls setup_grid() in its own _ready().
func clear_grid() -> void:
	occupancy.clear()


## Move a unit from one tile to another. Animates with a Tween.
## Returns true if the move was successfully initiated.
## The caller should check is_in_bounds and is_occupied on 'to' first,
## though this method also validates.
func move_unit(unit: Node, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_in_bounds(to_pos):
		return false
	if not is_walkable(to_pos):
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

	# Move SFX — player path; fires only when the destination was reserved.
	# Regression gate (fix_cascade_script_loads): AudioManager autoload parses,
	# so this call site resolves at compile time.
	AudioManager.play_move()

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


## Pure planner: BFS/SPFA over the grid under the EXACT player._try_move cost
## model (walkable + unoccupied landing tiles; 身轻如燕 slide-through of an
## occupied tile at cost 2, landing on the walkable unoccupied tile beyond).
## Path resolution, the movement-range highlighter and execution share this
## one model so they can never drift apart.
##
## Returns { "dist": {Vector2i: int}, "steps": {Vector2i: Array[Vector2i]} }:
## - dist[tile]  = cheapest movement cost to reach tile (the origin `from` is
##   always present at cost 0);
## - steps[tile] = ordered Array[Vector2i] of cardinal directions from `from`,
##   one entry per player._try_move call (a slide-through is a single entry
##   pointing INTO the occupied tile — _try_move performs the whole 2-tile
##   slide natively from that one direction).
## Unreachable tiles are simply omitted from both maps. Pure: reads only
## walkability/occupancy; never mutates occupancy or the AStar graph.
func plan_movement(from: Vector2i, budget: int, slide_ok: bool) -> Dictionary:
	# Relaxation BFS: a tile is re-enqueued whenever a strictly cheaper cost is
	# found, then re-expanded — REQUIRED because the mixed 1/2 cost model means
	# a later cheap path can beat an earlier expensive one. Iteration order is
	# the fixed _DIRECTIONS order only (playtest determinism is a hard repo
	# rule). The origin is seeded directly (it may itself be occupied — the
	# player's own tile), so relaxation can never re-enter it with a worse cost.
	var dist: Dictionary = {from: 0}
	var steps: Dictionary = {}
	var from_steps: Array[Vector2i] = []
	steps[from] = from_steps
	var queue: Array[Vector2i] = [from]

	while not queue.is_empty():
		var v: Vector2i = queue.pop_front()
		var d: int = dist[v]
		var v_steps: Array[Vector2i] = steps[v]
		for dir in _DIRECTIONS:
			var nxt: Vector2i = v + dir
			# Plain step: cost 1 onto a walkable, unoccupied landing tile.
			if GridManager.is_walkable(nxt) and not GridManager.is_occupied(nxt) \
					and d + 1 <= budget:
				var nxt_cost: int = d + 1
				if not dist.has(nxt) or dist[nxt] > nxt_cost:
					var nxt_steps: Array[Vector2i] = v_steps.duplicate()
					nxt_steps.append(dir)
					dist[nxt] = nxt_cost
					steps[nxt] = nxt_steps
					queue.append(nxt)
			# 身轻如燕 slide-through: an OCCUPIED neighbor is slid through at
			# cost 2, landing on the walkable, unoccupied tile beyond it. One
			# steps entry (the direction INTO the occupied tile) — the whole
			# 2-tile slide is a single player._try_move call. The occupied tile
			# itself is never a landing tile and never enters dist/steps.
			elif slide_ok and GridManager.is_occupied(nxt) and d + 2 <= budget:
				var beyond: Vector2i = nxt + dir
				if GridManager.is_walkable(beyond) and not GridManager.is_occupied(beyond):
					var slide_cost: int = d + 2
					if not dist.has(beyond) or dist[beyond] > slide_cost:
						var slide_steps: Array[Vector2i] = v_steps.duplicate()
						slide_steps.append(dir)
						dist[beyond] = slide_cost
						steps[beyond] = slide_steps
						queue.append(beyond)

	return {"dist": dist, "steps": steps}


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
			if not is_walkable(next_pos):
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
			# Check-then-cast: occupancy values are stored node refs that may
			# be freed (queue_free is deferred). Validate the raw Variant
			# BEFORE the typed assignment — `as Node` raises on a freed object.
			var raw = occupancy[grid_pos]
			if raw == null or not is_instance_valid(raw):
				continue
			var unit: Node = raw
			units.append(unit)
	return units


## Returns the raw tile-set covered by an area-of-effect shape centred at
## origin (no unit lookup, no dedup). Out-of-bounds tiles are dropped.
##
## shape     |  pattern
## ----------|------------------------------------------------
## single    |  just the origin tile
## line      |  `size` tiles in `direction` from origin
## cross     |  origin + `size` tiles in each of the 4 cardinal
##           |  directions (arm length = size): 1 + 4*size tiles
## square    |  (size*2+1)^2 Chebyshev ball centred at origin
## adjacent  |  the 8-tile Chebyshev ring at distance exactly 1
##
## For "line", a non-zero direction must be provided; otherwise the
## direction toward the nearest occupied tile is auto-detected (existing
## behaviour). Unknown shapes fall back to "single".
func get_tiles_in_aoe(origin: Vector2i, shape: String, size: int,
		direction: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	
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
			# Center + `size` tiles in each cardinal direction (arm length).
			target_tiles.append(origin)
			for dir in _DIRECTIONS:
				for i in range(1, size + 1):
					var tile: Vector2i = origin + dir * i
					if is_in_bounds(tile):
						target_tiles.append(tile)
		
		"square":
			for dx in range(-size, size + 1):
				for dy in range(-size, size + 1):
					var tile: Vector2i = origin + Vector2i(dx, dy)
					if is_in_bounds(tile):
						target_tiles.append(tile)
		
		"adjacent":
			# The 8-tile Chebyshev ring at distance exactly 1 (no center).
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var tile: Vector2i = origin + Vector2i(dx, dy)
					if is_in_bounds(tile):
						target_tiles.append(tile)
		
		_:
			# Unknown shape — treat as single.
			target_tiles.append(origin)
	
	return target_tiles


## Returns units whose grid positions fall within the specified area-of-effect
## pattern centred at origin.
##
## shape     |  pattern
## ----------|------------------------------------------------
## single    |  just the origin tile
## line      |  `size` tiles in `direction` from origin
## cross     |  origin + `size` tiles in each of the 4 cardinal
##           |  directions (arm length = size)
## square    |  (size*2+1)^2 Chebyshev ball centred at origin
## adjacent  |  the 8-tile Chebyshev ring at distance exactly 1
##
## For "line", a non-zero direction must be provided.
## When `hostile_to` is non-null, only units whose team differs from
## `hostile_to`'s team are returned: damage AoEs pass the caster so friendly
## units are never caught, while heal skills pass a same-team unit to get only
## allies. When `hostile_to` is null (or its team is unknown) no filtering is
## applied — the existing 4-argument call sites behave exactly as before.
func get_units_in_aoe(origin: Vector2i, shape: String, size: int,
		direction: Vector2i = Vector2i.ZERO,
		hostile_to: Node = null) -> Array[Node]:
	
	var target_tiles: Array[Vector2i] = get_tiles_in_aoe(origin, shape, size, direction)
	
	var filter_team: int = -1
	if hostile_to != null:
		filter_team = _team_of(hostile_to)
	
	# Collect units present on the target tiles.
	var units: Array[Node] = []
	for tile in target_tiles:
		if occupancy.has(tile):
			# Check-then-cast: same freed-ref hazard as get_units_in_range —
			# validate the raw Variant BEFORE the typed assignment.
			var raw = occupancy[tile]
			if raw == null or not is_instance_valid(raw):
				continue
			var unit: Node = raw
			if filter_team >= 0 and _team_of(unit) == filter_team:
				continue  # Same team — skip (not hostile).
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


## Read a unit's team id for AoE team filtering. Prefers a direct `team`
## property on the unit when present; otherwise falls back to the unit's
## `character_data.team` (player.gd / enemy.gd expose the team through their
## CharacterData resource). Returns -1 when the team cannot be determined —
## callers treat -1 as "no filtering" (keep every unit).
static func _team_of(unit: Node) -> int:
	if unit == null:
		return -1
	if "team" in unit:
		return int(unit.team)
	var cd: Resource = unit.get("character_data") as Resource
	if cd != null and "team" in cd:
		return int(cd.team)
	return -1
