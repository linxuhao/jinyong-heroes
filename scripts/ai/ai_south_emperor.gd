## AIControllerSouthEmperor — 南帝段智兴 AI
##
## Balanced healer. Heals self (or the most wounded ally) whenever Primal
## Breath is ready, then fights at range 1-2 with Solar Finger / Acupoint
## Lock / Six-Pulse Volley; approaches to range 2, inside the player's AoE.
##
## Skill index map (from battlefield.gd):
##   0 solar_finger · 1 acupoint_lock · 2 primal_breath · 3 six_pulse_volley
extends "res://scripts/ai/ai_base.gd"


## Balance lever (step2_design §4.4 ranged-pair throttle): when true,
## Six-Pulse Volley is held until the player is below 50% HP. Default false —
## the protected scenarios' verdicts depend on the default behavior, and only
## this const changes behavior, never the code path.
const SIX_PULSE_LOW_HP_ONLY: bool = false


func evaluate(enemy: Node) -> Dictionary:
	if enemy == null:
		return {}
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return {}
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return {}

	var dist: int = _distance(enemy.grid_pos, player.grid_pos)

	# 1) Primal Breath — heal self if wounded, else the lowest-HP%-ally
	#    (registration order, first on tie); falls through when all are full.
	if _is_skill_ready(enemy, 2):
		var heal_target: Node = _choose_heal_target(enemy)
		if heal_target != null:
			return {
				move_path = [], action = "skill", target = heal_target,
				skill_index = 2, fsm_state = "SKILL",
			}
	# 2) Solar Finger (range 2, ignores damage reduction).
	if _is_skill_ready(enemy, 0) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 0, fsm_state = "SKILL",
		}
	# 3) Acupoint Lock (range 2, movement seal).
	if _is_skill_ready(enemy, 1) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 1, fsm_state = "SKILL",
		}
	# 4) Six-Pulse Volley (line 3) — cardinal line within 3. When
	#    SIX_PULSE_LOW_HP_ONLY is set, it waits until the player is below
	#    half HP; when false (default) the guard is unchanged.
	if _is_skill_ready(enemy, 3) \
			and _aligned_in_line(enemy.grid_pos, player.grid_pos) and dist <= 3 \
			and (not SIX_PULSE_LOW_HP_ONLY \
					or int(player.health) * 2 < int(player.max_health)):
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 3, fsm_state = "SKILL",
		}
	# 5) In basic range (24 @ 2) — basic attack.
	if dist <= 2:
		return {
			move_path = [], action = "basic_attack", target = player,
			fsm_state = "ATTACK",
		}
	# 6) Approach to range 2.
	return _approach_decision(enemy, player, 2)


## Choose the heal target: self when wounded, else the lowest-HP%-ally in
## GameManager enemy registration order (first on tie). Returns null when
## every ally (incl. self) is at full HP.
func _choose_heal_target(enemy: Node) -> Node:
	if enemy == null:
		return null
	if int(enemy.health) < int(enemy.max_health):
		return enemy

	var best: Node = null
	var best_ratio: float = 1.0
	for ally in GameManager.get_enemies_alive():
		if ally == null or not is_instance_valid(ally):
			continue
		if not ("health" in ally and "max_health" in ally):
			continue
		if int(ally.max_health) <= 0:
			continue
		var ratio: float = float(ally.health) / float(ally.max_health)
		# Strictly-less so the first ally with the lowest ratio wins ties.
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally

	if best != null and int(best.health) < int(best.max_health):
		return best
	return null
