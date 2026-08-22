## AIControllerNorthBeggar — 北丐洪七公 AI
##
## High-damage melee brawler. Charges the player, unloads Dragon Palms in
## priority order, and uses the Dog-Beating Staff at range 2.
##
## Skill index map (from battlefield.gd):
##   0 proud_dragon_regret · 1 flying_dragon · 2 dragon_in_the_field
##   3 hidden_dragon · 4 dog_beating_trip · 5 dog_beating_poke
##   6 dog_beating_seal
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

	# 1) Hidden Dragon (square 2 AoE, KB 2) — player within 2.
	if _is_skill_ready(enemy, 3) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 3, fsm_state = "SKILL",
		}
	# 2) Proud Dragon Regret (single, KB 2) — adjacent.
	if _is_skill_ready(enemy, 0) and dist <= 1:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 0, fsm_state = "SKILL",
		}
	# 3) Dragon in the Field (line 3, KB 1) — cardinal line within 3.
	if _is_skill_ready(enemy, 2) \
			and _aligned_in_line(enemy.grid_pos, player.grid_pos) and dist <= 3:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 2, fsm_state = "SKILL",
		}
	# 4) Flying Dragon (jump 3 + 3x3 at landing) — player within 3 and a
	#    valid landing tile exists.
	if _is_skill_ready(enemy, 1) and dist <= 3 \
			and _move_toward_budget(enemy, player, 3).size() > 1:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 1, fsm_state = "SKILL",
		}
	# 5-7) Dog-Beating Staff (range 2, highest damage first).
	if _is_skill_ready(enemy, 6) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 6, fsm_state = "SKILL",
		}
	if _is_skill_ready(enemy, 5) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 5, fsm_state = "SKILL",
		}
	if _is_skill_ready(enemy, 4) and dist <= 2:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 4, fsm_state = "SKILL",
		}
	# 8) In melee range — basic attack (28 @ 1).
	if dist <= 1:
		return {
			move_path = [], action = "basic_attack", target = player,
			fsm_state = "ATTACK",
		}
	# 9) Approach to melee.
	return _approach_decision(enemy, player, 1)
