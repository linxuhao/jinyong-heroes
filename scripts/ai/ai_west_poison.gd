## AIControllerWestPoison — 西毒欧阳锋 AI
##
## Aggressive melee poisoner. Always rushes toward the player and never
## retreats. Applies poison DoT on its venom strike skill.
##
## Skill[0]: Venom Strike — heavy melee attack with poison DoT.
class_name AIControllerWestPoison
extends AIControllerBase


func get_retreat_threshold() -> float:
	return 0.0  # never retreats


func evaluate(enemy: Node, player: Node, delta: float) -> Dictionary:
	# Guard: if busy, skip.
	if CombatManager.is_unit_busy(enemy):
		return {}

	if enemy == null or player == null:
		return {}
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return {}

	var distance: int = _distance(enemy.grid_pos, player.grid_pos)

	# In melee range: use skill[0] (venom strike) if ready, else basic attack.
	if distance == 1:
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

	# Not in range: approach the player aggressively.
	enemy.fsm_state = "APPROACH"
	return _move_toward(enemy, player)
