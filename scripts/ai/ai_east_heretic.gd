## AIControllerEastHeretic — 东邪黄药师 AI
##
## Ranged poison specialist. Prefers to fight at range 2-3. Retreats if the
## player closes to melee (range 1) or when HP drops below 25%.
##
## Skill[0]: Poison Cloud — AoE DoT at range 2-3.
extends "res://scripts/ai/ai_base.gd"


func get_retreat_threshold() -> float:
	return 0.25


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

	# Retreat if below threshold.
	if health_ratio < get_retreat_threshold():
		enemy.fsm_state = "RETREAT"
		return _move_away(enemy, player)

	# If player is adjacent (melee range): retreat to preferred range.
	if distance == 1:
		enemy.fsm_state = "RETREAT"
		return _move_away(enemy, player)

	# Preferred range: 2-3 tiles. Use skill[0] (poison cloud) if ready,
	# else basic attack.
	if distance >= 2 and distance <= 3:
		if _is_skill_ready(enemy, 0):
			enemy.fsm_state = "SKILL"
			return {
				action = "skill",
				target = player,
				params = { skill_index = 0 }
			}
		else:
			enemy.fsm_state = "ATTACK"
			return {
				action = "basic_attack",
				target = player,
				params = {}
			}

	# Player is too far: approach to preferred range.
	if distance > 3:
		enemy.fsm_state = "APPROACH"
		return _move_toward(enemy, player)

	return {}
