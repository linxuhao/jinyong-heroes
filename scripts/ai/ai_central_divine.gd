## AIControllerCentralDivine — 中神通王重阳 AI
##
## Defensive counter-attacker. Waits for the player to approach (stays IDLE
## if not attacked recently). If attacked within the last 3 seconds, actively
## approaches to range 2. At range 1-2, uses Divine Burst (AoE) or basic
## attack. Retreats at 30% HP.
##
## Skill[0]: Divine Burst — area burst skill, effective at close range.
extends "res://scripts/ai/ai_base.gd"

## Timestamp (seconds via Time.get_ticks_msec/1000.0) when the enemy was
## last attacked. Set externally by enemy.gd or via signal. Initialised
## to a very old value so the AI starts passive.
var _last_attacked_time: float = -999.0


func get_retreat_threshold() -> float:
	return 0.30


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
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Retreat if below threshold.
	if health_ratio < get_retreat_threshold():
		enemy.fsm_state = "RETREAT"
		return _move_away(enemy, player)

	# Close range: counter-attack.
	if distance <= 2:
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

	# Out of range (>2): decide based on whether recently attacked.
	if distance > 2:
		if current_time - _last_attacked_time <= 3.0:
			# Recently attacked — actively approach.
			enemy.fsm_state = "APPROACH"
			return _move_toward(enemy, player)
		else:
			# Not attacked recently — stay IDLE, wait for player.
			enemy.fsm_state = "IDLE"
			return {}

	return {}
