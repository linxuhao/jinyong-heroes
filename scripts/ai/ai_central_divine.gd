## AIControllerCentralDivine — 中神通王重阳 AI
##
## Defensive counter-attacker (approaches and holds melee). Maintains Qi
## Aegis, dispels hostile buffs with Primal Unity, and unleashes Seven Stars
## / Quanzhen Sword up close.
##
## Skill index map (from battlefield.gd):
##   0 quanzhen_sword · 1 seven_stars · 2 qi_aegis · 3 primal_unity
extends "res://scripts/ai/ai_base.gd"


func evaluate(enemy: Node) -> Dictionary:
	if enemy == null:
		return {}
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return {}
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return {}

	var dist: int = _distance(enemy.grid_pos, player.grid_pos)

	# 1) Qi Aegis (shield 50 x3) — ready and (wounded or player within 2).
	if _is_skill_ready(enemy, 2) \
			and (int(enemy.health) < int(enemy.max_health) or dist <= 2):
		return {
			move_path = [], action = "skill", target = enemy,
			skill_index = 2, fsm_state = "SKILL",
		}
	# 2) Primal Unity (global dispel strike) — always when ready.
	if _is_skill_ready(enemy, 3):
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 3, fsm_state = "SKILL",
		}
	# 3) Seven Stars (cross 2) — player within 2.
	if _is_skill_ready(enemy, 1) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 1, fsm_state = "SKILL",
		}
	# 4) Quanzhen Sword (single) — adjacent.
	if _is_skill_ready(enemy, 0) and dist <= 1:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 0, fsm_state = "SKILL",
		}
	# 5) In melee range — basic attack (26 @ 1).
	if dist <= 1:
		return {
			move_path = [], action = "basic_attack", target = player,
			fsm_state = "ATTACK",
		}
	# 6) Approach to melee.
	return _approach_decision(enemy, player, 1)
