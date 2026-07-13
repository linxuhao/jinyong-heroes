## AIControllerSouthEmperor — 南帝段智兴 AI
##
## Balanced melee combatant. Fights at range 1-2. Can heal self once per
## battle when HP drops below 30%. Retreats at 20% HP.
##
## Skill[0]: Healing Touch — self-heal skill (used once when low).
class_name AIControllerSouthEmperor
extends AIControllerBase

## Whether the self-heal has been used this battle.
var _heal_used: bool = false


func get_retreat_threshold() -> float:
	return 0.20


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

	# If health is low (< 30%) and heal hasn't been used yet, use it.
	if health_ratio < 0.30 and not _heal_used and _is_skill_ready(enemy, 0):
		_heal_used = true
		enemy.fsm_state = "SKILL"
		return {
			action = "skill",
			target = enemy,  # heal targets self
			params = { skill_index = 0, heal_self = true }
		}

	# Retreat if below threshold.
	if health_ratio < get_retreat_threshold():
		enemy.fsm_state = "RETREAT"
		return _move_away(enemy, player)

	# In range 1-2: basic attack.
	if distance >= 1 and distance <= 2:
		enemy.fsm_state = "ATTACK"
		return {
			action = "basic_attack",
			target = player,
			params = {}
		}

	# Out of range: approach.
	if distance > 2:
		enemy.fsm_state = "APPROACH"
		return _move_toward(enemy, player)

	return {}
