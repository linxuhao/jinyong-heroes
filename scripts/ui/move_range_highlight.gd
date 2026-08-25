## MoveRangeHighlight — movement-range highlight overlay
##
## Pure-presentation read-only view over the battlefield grid: shows every tile
## the player could still reach with the remaining movement budget, using the
## EXACT rules of player._try_move (walkable tiles, unoccupied landing tiles,
## and — if the 身轻如燕 swallow_lightness trait is owned — slide-through of
## occupied tiles at cost 2, landing on the walkable unoccupied tile beyond).
## The displayed set EQUALS the executable set: it never suggests a move
## _try_move would refuse, and never omits a move _try_move would allow.
##
## Self-driving: polls GameManager.get_player() every frame (never stores the
## ref), hides when there is no battle / no player / not the player's turn / no
## remaining movement budget, and recomputes + redraws ONLY when the player's
## grid position, the movement budget, the acted flag, the occupancy map, the
## turn-start tile, or the undo-available flag changed since the last recompute.
## The node dies with the battlefield scene on a swap — no manual teardown
## needed.
##
## Delivery note: the optional GridManager.plan_movement refactor of _recompute
## was deliberately NOT performed (its private BFS stays, coexisting with the
## planner). The task plan allows the switch only if movement_range_highlight
## stays byte-green, which this implementer has no shell/Godot to verify — any
## refactor risks drifting the pinned 39-tile assertion. No other deviations.
extends Node2D

# ---------------------------------------------------------------------------
# Constants (exact literals from the task contract)
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64

## Translucent green fill for reachable movement tiles. Green is deliberately
## distinct from the skill-range blue (RangeHighlight.REACH_FILL) and the
## target red (TARGET_FILL) so the two highlights can never be confused; the
## fill_color observable makes that distinctness assertable numerically.
## Fill alpha ≤ 0.28 keeps the 35%-alpha grid lines visible (design
## readability hard rule #1).
const MOVE_FILL: Color = Color(0.35, 0.85, 0.30, 0.16)
const MOVE_EDGE: Color = Color(0.35, 0.85, 0.30, 0.45)

## Bright amber-green edge for the turn-start tile marker ("where right-click
## returns to"). Numerically distinct from MOVE_FILL/MOVE_EDGE (green) and from
## RangeHighlight's blue/red: r and g high, b low (< 0.35).
const START_EDGE: Color = Color(0.85, 0.90, 0.20, 0.90)
const START_EDGE_DIM: Color = Color(0.85, 0.90, 0.20, 0.32)  # undo_available == false

## Cardinal neighbor offsets (4-direction BFS, mirroring _try_move's cardinal
## movement — there is no diagonal movement in this game).
const _DIRS: Array = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

# ---------------------------------------------------------------------------
# Observables (playtest surface contract)
# ---------------------------------------------------------------------------

## Number of tiles in the reachable movement set (0 when hidden).
var tile_count: int = 0

## Observable fill color — the exact MOVE_FILL constant, exposed so playtest
## scenarios can assert green-dominant distinctness vs RangeHighlight's blue.
var fill_color: Color = MOVE_FILL

## Turn-start tile the player's undo would return to. Polled every frame from
## player.turn_start_grid; (-1,-1) when invalid or hidden. Marker state only —
## never part of the reachable-set visibility condition.
var start_tile: Vector2i = Vector2i(-1, -1)

## Whether right-click undo is currently available (polled from
## player.undo_available, which is recomputed per frame by the player). False
## after a successful action commits the move (engine sets acted) or once the
## turn ends. Marker state only — the commit is expressed through the marker's
## dimmed color, never by hiding the reachable set.
var undo_available: bool = false

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Reachable movement tiles (tile-local coords), including the origin tile.
var _reachable: Array[Vector2i] = []

## Cheap-diff keys: recompute only when one of these changes. `acted` is in the
## key set because it is cheap to compare and can never change the reachable
## set — but it MUST NEVER appear in the visibility condition below (an action
## does not spend the movement budget; player._try_move never reads `acted`).
var _last_grid: Vector2i = Vector2i(-1, -1)
var _last_moves: int = -1
var _last_acted: bool = false
var _last_occ: String = ""
var _last_start_tile: Vector2i = Vector2i(-1, -1)
var _last_undo: bool = false

# ---------------------------------------------------------------------------
# Per-frame update
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var player = GameManager.get_player()
	if not is_instance_valid(player):
		_hide()
		return
	if GameManager.get_state() != GameManager.STATE_BATTLE:
		_hide()
		return
	if not CombatManager.is_player_turn():
		_hide()
		return
	if player.moves_left <= 0:
		_hide()
		return

	# Show the overlay: a valid battle, the player's turn, and movement budget
	# remain. This is the only writer of visible = true; _hide() stays the only
	# writer of visible = false. It must run BEFORE the diff early-return so
	# frames where nothing changed also keep the node visible — otherwise a
	# single _hide() during pre-battle frames leaves the highlight hidden
	# forever even though tile_count is computed. (`acted` deliberately never
	# enters this condition: acting does not spend the movement budget, so a
	# unit that acted but still has moves_left can and will walk.)
	visible = true

	# Poll the trying-state observables every frame (same pattern as the diff
	# keys — player.turn_start_grid / player.undo_available are written outside
	# this node, so a per-frame read can never go stale). The "turn_start_grid"
	# in-player guard keeps this inert if the dependency task's fields are not
	# present; start_tile then stays (-1,-1) and no marker is drawn.
	if "turn_start_grid" in player:
		start_tile = player.turn_start_grid
	undo_available = player.undo_available

	var occ_sig: String = _occupancy_signature()
	if player.grid_pos == _last_grid and player.moves_left == _last_moves \
			and player.acted == _last_acted and occ_sig == _last_occ \
			and start_tile == _last_start_tile and undo_available == _last_undo:
		return  # Nothing changed — keep the current draw.

	_last_grid = player.grid_pos
	_last_moves = player.moves_left
	_last_acted = player.acted
	_last_occ = occ_sig
	_last_start_tile = start_tile
	_last_undo = undo_available
	_recompute(player)
	queue_redraw()


## Hide the overlay and zero the observables. The diff keys are invalidated so
## the next valid battle state always recomputes from scratch.
func _hide() -> void:
	visible = false
	tile_count = 0
	start_tile = Vector2i(-1, -1)
	undo_available = false
	_reachable.clear()
	_last_grid = Vector2i(-1, -1)
	_last_moves = -1
	_last_acted = false
	_last_occ = ""
	_last_start_tile = Vector2i(-1, -1)
	_last_undo = false


## Sorted join of the occupancy keys — the cheap-diff signature for "did any
## unit move onto/off a tile". Keys are sorted textually before joining so the
## signature is deterministic across frames.
func _occupancy_signature() -> String:
	var keys: Array = GridManager.occupancy.keys()
	var parts: PackedStringArray = PackedStringArray()
	for key in keys:
		parts.append(str(key))
	parts.sort()
	return "\n".join(parts)


## Rebuild the reachable set with a 4-direction BFS that mirrors player._try_move
## exactly (walkable + unoccupied landing; 身轻如燕 slide-through at cost 2).
## The origin tile is included at cost 0. The occupied slide-through tile itself
## is never a legal landing tile, so it never enters the set. The border ring is
## excluded automatically by GridManager.is_walkable.
func _recompute(player) -> void:
	_reachable.clear()

	var budget: int = player.moves_left
	var slide_ok: bool = player.traits.has("swallow_lightness")
	var origin: Vector2i = player.grid_pos

	# dist map: tile -> cheapest movement cost found so far. Seeded with the
	# origin at cost 0 (the origin is occupied by the player; seeding it first
	# means relax can never re-enter it with a worse cost).
	var dist: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]

	while not queue.is_empty():
		var v: Vector2i = queue.pop_front()
		var d: int = dist[v]
		for dir in _DIRS:
			var nxt: Vector2i = v + dir
			if GridManager.is_walkable(nxt) and not GridManager.is_occupied(nxt) \
					and d + 1 <= budget:
				_relax(nxt, d + 1, dist, queue)
			elif slide_ok and GridManager.is_occupied(nxt) and d + 2 <= budget:
				# 身轻如燕: slide THROUGH the occupied tile, landing on the
				# walkable, unoccupied tile beyond it (cost 2).
				var beyond: Vector2i = nxt + dir
				if GridManager.is_walkable(beyond) and not GridManager.is_occupied(beyond):
					_relax(beyond, d + 2, dist, queue)

	for cell in dist.keys():
		_reachable.append(cell)

	tile_count = _reachable.size()


## Relax a candidate tile if the new cost improves on the stored best. The
## improved tile is re-enqueued so its neighbors are re-expanded with the
## cheaper cost (handles the 1-vs-2 cost mixing correctly).
func _relax(cell: Vector2i, cost: int, dist: Dictionary, queue: Array[Vector2i]) -> void:
	if dist.has(cell) and dist[cell] <= cost:
		return
	dist[cell] = cost
	queue.append(cell)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	for cell in _reachable:
		var rect: Rect2 = Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, MOVE_FILL)
		draw_rect(rect, MOVE_EDGE, false, 1.0)

	# Trying-state marker: edge-only outline on the turn-start tile (the tile
	# right-click undo returns to). Drawn LAST so it sits on top of the reachable
	# set. Bright when undo is available, dim when committed (undo_available
	# flipped false — the commit state is expressed through the color, never by
	# hiding the reachable set above). Nothing is drawn while the tile is invalid
	# ((-1,-1), e.g. pre-battle or after _hide()) or out of bounds.
	if start_tile.x >= 0 and GridManager.is_in_bounds(start_tile):
		var start_rect: Rect2 = Rect2(start_tile.x * TILE_SIZE, start_tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(start_rect, START_EDGE if undo_available else START_EDGE_DIM, false, 2.0)
