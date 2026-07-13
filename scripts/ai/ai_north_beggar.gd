## AIControllerNorthBeggar — 北丐洪七公 AI
##
## High-damage melee brawler. Charges directly at the player and uses
## Dragon Palm (降龙十八掌) — a 3-tile line AoE with massive damage and
## long cooldown — at range 1-3. When below retreat threshold, toggles
## between retreat and re-engage each evaluation.
##
## Skill[0]: Dragon Palm — 3-tile line AoE, high damage, long cooldown.
extends "res://scripts/ai/ai_base.gd"

## Toggles between RETREAT and APPROACH every other evaluation when
## below retreat threshold.
var _retreat_toggle: bool = false


func get_retreat_threshold() -> float:
	return 0.15


func evaluate(enemy: Node, player: Node, delta: float) -> Dictionary:
	# Guard: if busy, skip.
	if CombatManager.is_unit_busy(enemy):
		return {}

	if enemy == null or player == null:
		return {}
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return {}
	if not ("health" in enemy and "max_health" in enemy):
		return {}

	var distance: int = _distance(enemy.grid_pos, player.grid_pos)
	var health_ratio: float = float(enemy.health) / float(enemy.max_health)

	# Below retreat threshold: toggle between retreat and re-engage.
	if health_ratio < get_retreat_threshold():
		_retreat_toggle = not _retreat_toggle
		if _retreat_toggle:
			enemy.fsm_state = "RETREAT"
			return _move_away(enemy, player)
		else:
			# Re-engage: move toward player even when low.
			enemy.fsm_state = "APPROACH"
			return _move_toward(enemy, player)

	# Preferred range 1-3: use skill[0] (Dragon Palm) if ready.
	if distance >= 1 and distance <= 3:
		if _is_skill_ready(enemy, 0):
			enemy.fsm_state = "SKILL"
			return {
				action = "skill",
				target = player,
				params = { skill_index = 0 }
			}
		# If adjacent, use basic attack.
		elif distance == 1:
			enemy.fsm_state = "ATTACK"
			return {
				action = "basic_attack",
				target = player,
				params = {}
			}
		else:
			# Approach to get closer.
			enemy.fsm_state = "APPROACH"
			return _move_toward(enemy, player)

	# Out of range: approach.
	if distance > 3:
		enemy.fsm_state = "APPROACH"
		return _move_toward(enemy, player)

	return {}
