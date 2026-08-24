## RangeHighlight — selected-skill range/target highlight overlay
##
## Pure-presentation read-only view over the battlefield grid: shows (a) the
## selected skill's reachable tiles and (b) which living enemies are valid
## targets, driven by the player's own hit test (player.can_skill_hit) so what
## is displayed is exactly what executes. The engine stays authoritative at
## execution time.
##
## Self-driving: polls GameManager.get_player() every frame (never stores the
## ref), hides when there is no battle / no player / no selected skill, and
## recomputes + redraws ONLY when the selected skill index, the player's grid
## position, or the living-enemy count changed since the last recompute. The
## node dies with the battlefield scene on a swap — no manual teardown needed.
extends Node2D

# ---------------------------------------------------------------------------
# Constants (exact literals from the task contract)
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64

## Translucent blue fill for reachable tiles. Fill alpha ≤ 0.28 keeps the
## 35%-alpha grid lines visible (design readability hard rule #1).
const REACH_FILL: Color = Color(0.30, 0.65, 1.00, 0.16)
const REACH_EDGE: Color = Color(0.30, 0.65, 1.00, 0.45)

## Translucent red fill for valid target tiles, drawn on top of the reach set.
const TARGET_FILL: Color = Color(1.00, 0.30, 0.20, 0.28)
const TARGET_EDGE: Color = Color(1.00, 0.30, 0.20, 0.75)

# ---------------------------------------------------------------------------
# Observables (playtest surface contract)
# ---------------------------------------------------------------------------

## Observable fill color — the exact REACH_FILL constant, exposed so playtest
## scenarios can assert blue-dominant distinctness vs MoveRangeHighlight's
## green fill. Read-only observable; zero behavior change.
var fill_color: Color = REACH_FILL

## Number of tiles in the reachable set (0 when hidden or for "global" shape).
var tile_count: int = 0

## Number of enemy tiles that pass player.can_skill_hit (0 when hidden).
var target_count: int = 0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Reachable tiles for the currently selected skill (tile-local coords).
var _reachable: Array[Vector2i] = []

## Valid target tiles (one per living enemy passing the hit test).
var _targets: Array[Vector2i] = []

## Cheap-diff keys: recompute only when one of these changes.
var _last_index: int = -2
var _last_grid: Vector2i = Vector2i(-1, -1)
var _last_enemy_count: int = -1

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
	var index: int = player.selected_skill_index
	if index < 0 or index >= player.skills.size():
		_hide()
		return
	var skill = player.skills[index]
	if skill == null:
		_hide()
		return

	# Show the overlay: a valid battle with a selected skill exists. This is the
	# only writer of visible = true; _hide() stays the only writer of
	# visible = false (deselect / toggle-off / battle-exit). It must run BEFORE
	# the diff early-return so frames where nothing changed also keep the node
	# visible — otherwise a single _hide() during pre-battle frames leaves the
	# highlight hidden forever even though tile_count/target_count are computed.
	visible = true

	var enemy_count: int = GameManager.get_enemies_alive().size()
	if index == _last_index and player.grid_pos == _last_grid \
			and enemy_count == _last_enemy_count:
		return  # Nothing changed — keep the current draw.

	_last_index = index
	_last_grid = player.grid_pos
	_last_enemy_count = enemy_count
	_recompute(player, skill)
	queue_redraw()


## Hide the overlay and zero the observables. The diff keys are invalidated so
## the next valid selection always recomputes from scratch.
func _hide() -> void:
	visible = false
	tile_count = 0
	target_count = 0
	_reachable.clear()
	_targets.clear()
	_last_index = -2
	_last_grid = Vector2i(-1, -1)
	_last_enemy_count = -1


## Rebuild the reachable + target tile sets for the given player/skill.
## Reachability mirrors player.can_skill_hit's shape arms exactly (reuse, no
## reimplementation); the target test IS player.can_skill_hit itself.
func _recompute(player, skill) -> void:
	_reachable.clear()
	_targets.clear()

	var origin: Vector2i = player.grid_pos
	var shape: String = skill.aoe_shape

	if shape == "global":
		# No reachable fill for global techniques — every living enemy is a target.
		pass
	elif skill.jump_tiles > 0 or skill.aoe_origin == "target" or shape == "single":
		_reachable = _chebyshev_ball(origin, int(skill.range))
	elif shape == "line":
		_reachable = _line_within_range(origin, int(skill.range))
	elif shape == "adjacent":
		_reachable = _chebyshev_ring(origin, 1)
	elif shape == "cross" or shape == "square":
		_reachable = GridManager.get_tiles_in_aoe(origin, shape, max(int(skill.aoe_size), 1))
	else:
		# Unknown shape — radius-range ball (can_skill_hit's trailing fallback).
		_reachable = _chebyshev_ball(origin, int(skill.range))

	tile_count = _reachable.size()

	for enemy in GameManager.get_enemies_alive():
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		if player.can_skill_hit(skill, enemy):
			_targets.append(enemy.grid_pos)

	target_count = _targets.size()


## Chebyshev ball of the given radius around origin, clipped to the board.
func _chebyshev_ball(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if GridManager.is_in_bounds(cell):
				tiles.append(cell)
	return tiles


## Chebyshev ring at exactly the given distance around origin, clipped to the
## board (mirrors can_skill_hit's "adjacent" arm: dist == 1).
func _chebyshev_ring(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if max(abs(dx), abs(dy)) != radius:
				continue
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if GridManager.is_in_bounds(cell):
				tiles.append(cell)
	return tiles


## Same row or same column cells within range (mirrors can_skill_hit's "line"
## arm; GridManager's get_tiles_in_aoe("line") needs a direction, so this is
## hand-rolled). The origin is added once, by the row pass.
func _line_within_range(origin: Vector2i, range_val: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dx in range(-range_val, range_val + 1):
		var cell: Vector2i = origin + Vector2i(dx, 0)
		if GridManager.is_in_bounds(cell):
			tiles.append(cell)
	for dy in range(-range_val, range_val + 1):
		if dy == 0:
			continue  # Origin already added by the row pass.
		var cell: Vector2i = origin + Vector2i(0, dy)
		if GridManager.is_in_bounds(cell):
			tiles.append(cell)
	return tiles


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Reach fills first (under), then target fills on top.
	for cell in _reachable:
		var rect: Rect2 = Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, REACH_FILL)
		draw_rect(rect, REACH_EDGE, false, 1.0)
	for cell in _targets:
		var rect: Rect2 = Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, TARGET_FILL)
		draw_rect(rect, TARGET_EDGE, false, 2.0)
