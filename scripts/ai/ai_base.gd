## AIControllerBase — AI base class (RefCounted)
##
## Abstract base for all enemy AI controllers. Provides helpers for distance
## calculation, pathfinding, movement, and skill-readiness checks.
##
## Subclasses override evaluate(). Instances are created with .new() in
## battlefield.gd and assigned to enemy.ai_controller.
extends RefCounted

# ---------------------------------------------------------------------------
# Virtual methods — override in subclasses
# ---------------------------------------------------------------------------

## Evaluate the situation and return a decision dictionary. Called ONCE per
## enemy turn by CombatManager's turn engine (never on a timer). Pure
## function of the enemy's cooldowns / health / grid_pos, the player's
## grid_pos / health, and allies' health — zero RNG, zero delta, zero
## per-instance mutable state.
##
## Keys:
##   move_path: Array[Vector2i]  # index 0 = current tile; engine walks 1..end
##   action: String              # "basic_attack" | "skill" | "wait"
##   target: Node                # attack/heal target; self for self-buffs
##   skill_index: int            # set when action == "skill"
##   params: Dictionary          # optional for skills
##   fsm_state: String           # "APPROACH"|"ATTACK"|"SKILL"|"RETREAT"|"WAIT"
## Returns {} for no action (wait in place).
func evaluate(enemy: Node) -> Dictionary:
	return {}


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


## Build a multi-step move path from the enemy toward the player, capped at
## `max_tiles` steps after the start. Every included tile must pass
## GridManager.is_walkable and not be occupied; the player's own tile is
## never included (pathing ends before it). Returns [start, step1, ...], or
## [] when no step exists.
func _move_toward_budget(enemy: Node, player: Node, max_tiles: int) -> Array[Vector2i]:
	if enemy == null or player == null:
		return []
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return []

	var path: Array[Vector2i] = _get_path_to_player(enemy, player)
	if path.size() < 2:
		return []

	var result: Array[Vector2i] = [enemy.grid_pos]
	var steps: int = 0
	for i in range(1, path.size()):
		if steps >= max_tiles:
			break
		var tile: Vector2i = path[i]
		if tile == player.grid_pos:
			break  # Never include the player's occupied tile.
		if not GridManager.is_walkable(tile):
			continue
		if GridManager.is_occupied(tile):
			continue
		result.append(tile)
		steps += 1

	if result.size() < 2:
		return []
	return result


## Walk the movement budget toward the player and stop at the FIRST tile whose
## Chebyshev distance to the player is <= attack_range, attacking from there.
## Returns an ATTACK decision (move_path + basic_attack) when such a tile
## exists, else an APPROACH decision (move the whole budget, action "wait").
## Never returns {}.
func _approach_decision(enemy: Node, player: Node, attack_range: int) -> Dictionary:
	if enemy == null or player == null:
		return { move_path = [], action = "wait", fsm_state = "APPROACH" }
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return { move_path = [], action = "wait", fsm_state = "APPROACH" }

	var path: Array[Vector2i] = _move_toward_budget(enemy, player, int(enemy.move_range))
	if path.is_empty():
		return { move_path = [], action = "wait", fsm_state = "APPROACH" }

	for i in range(1, path.size()):
		if _distance(path[i], player.grid_pos) <= attack_range:
			return {
				move_path = path.slice(0, i + 1),
				action = "basic_attack",
				target = player,
				fsm_state = "ATTACK",
			}
	return { move_path = path, action = "wait", fsm_state = "APPROACH" }


## Return a one-tile RETREAT decision moving directly away from the player
## (cardinal directions only). Tries the primary away direction; if blocked,
## tries perpendicular directions. Returns {} if all blocked.
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

	# Try each direction until we find a valid, walkable tile.
	for dir_vec in directions:
		var target_pos: Vector2i = enemy_pos + dir_vec
		if GridManager.is_walkable(target_pos) and not GridManager.is_occupied(target_pos):
			return {
				move_path = [enemy_pos, target_pos],
				action = "wait",
				fsm_state = "RETREAT",
			}

	return {}


## Check whether a skill at the given index is ready to use (round-based int
## cooldown elapsed and index is valid).
func _is_skill_ready(enemy: Node, skill_index: int) -> bool:
	if enemy == null:
		return false
	if not ("skill_cooldowns" in enemy and "skills" in enemy):
		return false
	if skill_index < 0 or skill_index >= enemy.skill_cooldowns.size():
		return false
	if skill_index >= enemy.skills.size():
		return false

	return int(enemy.skill_cooldowns[skill_index]) <= 0


## True when the two grid positions share a row or column (line AoE gate).
func _aligned_in_line(a: Vector2i, b: Vector2i) -> bool:
	return a.x == b.x or a.y == b.y
