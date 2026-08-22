## AIControllerWestPoison — 西毒欧阳锋 AI
##
## Aggressive melee poisoner. Rushes the player, poisons with Spirit Serpent /
## Poison Sand Palm, and charges Toad Squat when out of reach.
##
## Skill index map (from battlefield.gd):
##   0 spirit_serpent · 1 toad_squat · 2 poison_sand_palm · 3 toad_swarm
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

	# 1) Toad Swarm (line 4, KB 2) — cardinal line within 4.
	if _is_skill_ready(enemy, 3) \
			and _aligned_in_line(enemy.grid_pos, player.grid_pos) and dist <= 4:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 3, fsm_state = "SKILL",
		}
	# 2) Spirit Serpent (poison 8x2) — adjacent.
	if _is_skill_ready(enemy, 0) and dist <= 1:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 0, fsm_state = "SKILL",
		}
	# 3) Poison Sand Palm (cross + poison 6x2) — adjacent.
	if _is_skill_ready(enemy, 2) and dist <= 1:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 2, fsm_state = "SKILL",
		}
	# 4) In melee range — basic attack (26 @ 1).
	if dist <= 1:
		return {
			move_path = [], action = "basic_attack", target = player,
			fsm_state = "ATTACK",
		}
	# 5) Toad Squat charge when the player is beyond reach but within
	#    move_range + 1 (stand and charge; staying planted keeps him inside
	#    the approach lane and the player's radius-2 AoE envelope).
	if _is_skill_ready(enemy, 1) and dist >= 2 and dist <= 4:
		return {
			move_path = [], action = "skill", target = enemy,
			skill_index = 1, fsm_state = "SKILL",
		}
	# 6) Approach to melee.
	return _approach_decision(enemy, player, 1)
