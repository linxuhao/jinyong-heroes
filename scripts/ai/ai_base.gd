## AIControllerBase — AI base class (RefCounted)
##
## Abstract base for all enemy AI controllers. Provides helpers for distance
## calculation, pathfinding, movement, and skill-readiness checks.
##
## Subclasses override evaluate() and get_retreat_threshold().
## Instances are created with .new() in battlefield.gd and assigned to
## enemy.ai_controller.
extends RefCounted

# ---------------------------------------------------------------------------
# Virtual methods — override in subclasses
# ---------------------------------------------------------------------------

## Evaluate the situation and return an action dictionary.
## Keys: {action: String, target: Node, params: Dictionary}
## action can be "move", "basic_attack", "skill", or "" (no action).
## target is the player Node for attacks/skills, or the enemy self for moves.
## params contains action-specific data:
##   - For "move": {to: Vector2i}
##   - For "skill": {skill_index: int}
## Returns {} (empty dict) for no action.
func evaluate(_enemy: Node, _player: Node, _delta: float) -> Dictionary:
	return {}


## Return the health ratio threshold below which this AI will retreat.
## 0.0 means never retreat. Override in subclasses.
func get_retreat_threshold() -> float:
	return 0.0


# ---------------------------------------------------------------------------
# Protected helpers
# ---------------------------------------------------------------------------

## Chebyshev distance between two grid positions.
func _distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


## Get the A* path from enemy to player via GridManager.
## Returns Array[Vector2i] (including both start and end), or empty if
## no path exists.
func _get_path_to_player(enemy: Node, player: Node) -> Array[Vector2i]:
	if enemy == null or player == null:
		return []
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return []

	return GridManager.find_path(enemy.grid_pos, player.grid_pos)


## Returns true if the Chebyshev distance between enemy and player is
## within range_val.
func _is_in_range(enemy: Node, player: Node, range_val: int) -> bool:
	if enemy == null or player == null:
		return false
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return false

	return _distance(enemy.grid_pos, player.grid_pos) <= range_val


## Return a move action that moves the enemy one step toward the player
## along the A* path. Returns {} if no valid step exists.
func _move_toward(enemy: Node, player: Node) -> Dictionary:
	var path: Array[Vector2i] = _get_path_to_player(enemy, player)
	if path.size() < 2:
		return {}

	var next_step: Vector2i = path[1]  # first step after current position

	# Safety check: the tile must be in bounds and not occupied.
	if not GridManager.is_in_bounds(next_step):
		return {}
	if GridManager.is_occupied(next_step):
		return {}

	return {
		action = "move",
		target = enemy,
		params = { to = next_step }
	}


## Return a move action that moves the enemy one tile directly away from
## the player (cardinal directions only). Tries the primary away direction;
## if blocked, tries perpendicular directions. Returns {} if all blocked.
func _move_away(enemy: Node, player: Node) -> Dictionary:
	if enemy == null or player == null:
		return {}
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return {}

	var enemy_pos: Vector2i = enemy.grid_pos
	var player_pos: Vector2i = player.grid_pos

	# Calculate the primary direction away from player.
	var dx: int = 0
	var dy: int = 0

	if enemy_pos.x > player_pos.x:
		dx = 1  # move right (away from player who is left)
	elif enemy_pos.x < player_pos.x:
		dx = -1  # move left (away from player who is right)

	if enemy_pos.y > player_pos.y:
		dy = 1  # move down
	elif enemy_pos.y < player_pos.y:
		dy = -1  # move up

	# Try directions in priority order.
	var directions: Array[Vector2i] = []

	# Primary direction (away on the larger axis).
	if abs(dx) >= abs(dy):
		directions.append(Vector2i(dx, 0))
		# Perpendicular options.
		if dy != 0:
			directions.append(Vector2i(0, dy))
			directions.append(Vector2i(0, -dy))
		else:
			directions.append(Vector2i(0, 1))
			directions.append(Vector2i(0, -1))
	else:
		directions.append(Vector2i(0, dy))
		if dx != 0:
			directions.append(Vector2i(dx, 0))
			directions.append(Vector2i(-dx, 0))
		else:
			directions.append(Vector2i(1, 0))
			directions.append(Vector2i(-1, 0))

	# Try each direction until we find a valid tile.
	for dir_vec in directions:
		var target_pos: Vector2i = enemy_pos + dir_vec
		if GridManager.is_in_bounds(target_pos) and not GridManager.is_occupied(target_pos):
			return {
				action = "move",
				target = enemy,
				params = { to = target_pos }
			}

	return {}


## Check whether a skill at the given index is ready to use (cooldown elapsed
## and index is valid).
func _is_skill_ready(enemy: Node, skill_index: int) -> bool:
	if enemy == null:
		return false
	if not ("skill_cooldowns" in enemy and "skills" in enemy):
		return false
	if skill_index < 0 or skill_index >= enemy.skill_cooldowns.size():
		return false
	if skill_index >= enemy.skills.size():
		return false

	return enemy.skill_cooldowns[skill_index] <= 0.0
