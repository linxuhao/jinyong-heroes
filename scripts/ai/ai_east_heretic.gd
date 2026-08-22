## AIControllerEastHeretic — 东邪黄药师 AI
##
## Ranged controller. Keeps distance 2-3, debuffs the player's initiative
## whenever possible, and retreats when the player closes to melee.
##
## Skill index map (from battlefield.gd):
##   0 falling_petals · 1 jade_flute_acupoint · 2 peach_blossom_maze
##   3 tidal_melody
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

	# 1) Tidal Melody (global init debuff) — always when ready.
	if _is_skill_ready(enemy, 3):
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 3, fsm_state = "SKILL",
		}
	# 2) Falling Petals (3x3 centered on the target tile, range 3).
	if _is_skill_ready(enemy, 0) and dist <= 3:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 0, fsm_state = "SKILL",
		}
	# 3) Jade Flute Acupoint (technique seal; the rule gates it at range 3).
	if _is_skill_ready(enemy, 1) and dist <= 3:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 1, fsm_state = "SKILL",
		}
	# 4) Peach Blossom Maze (hazard zone around self; player within 2).
	if _is_skill_ready(enemy, 2) and dist <= 2:
		return {
			move_path = [], action = "skill", target = enemy,
			skill_index = 2, fsm_state = "SKILL",
		}
	# 5) Player adjacent — retreat to keep distance 2-3.
	if dist == 1:
		return _move_away(enemy, player)
	# 6) In basic range (22 @ 3) — ranged basic attack.
	if dist <= 3:
		return {
			move_path = [], action = "basic_attack", target = player,
			fsm_state = "ATTACK",
		}
	# 7) Approach to preferred range 3.
	return _approach_decision(enemy, player, 3)
