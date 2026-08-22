## AIControllerEastHeretic — 东邪黄药师 AI
##
## Ranged controller with a deterministic engagement throttle (step2_design
## §4.4). Casts Tidal Melody exactly once in round 1 (its -20 initiative
## debuff makes the player act last in rounds 2-3 — load-bearing ordering),
## attacks every turn in the rounds 1-3 hot ramp, and from round 4 attacks
## only on THROTTLE_PERIOD-aligned rounds, otherwise casting Peach Blossom
## Maze or holding in place. Never retreats: he stays parked inside the
## player's radius-2 AoE envelope so the late-game Boundless Seas can catch
## him. Every decision is a pure function of state (CombatManager.current_round
## is the only time source) — zero RNG, zero per-instance mutable state.
##
## Skill index map (from battlefield.gd):
##   0 falling_petals · 1 jade_flute_acupoint · 2 peach_blossom_maze
##   3 tidal_melody
extends "res://scripts/ai/ai_base.gd"


## Attack cadence from round 4: an attack happens on rounds where
## current_round % THROTTLE_PERIOD == 0, otherwise the turn is throttled to
## Peach Blossom Maze / hold in place. THROTTLE_PERIOD = 2 ⇒ ~half the turns.
const THROTTLE_PERIOD: int = 2


func evaluate(enemy: Node) -> Dictionary:
	if enemy == null:
		return {}
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return {}
	if not ("grid_pos" in enemy and "grid_pos" in player):
		return {}

	var dist: int = _distance(enemy.grid_pos, player.grid_pos)
	var round_no: int = int(CombatManager.current_round)

	# 1) Tidal Melody (global init debuff) — exactly once, round 1. Its cd6
	#    means it is only ready in round 1 anyway; the round gate makes the
	#    once-per-fight guarantee deterministic (never re-cast in rounds 2+).
	if round_no == 1 and _is_skill_ready(enemy, 3):
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 3, fsm_state = "SKILL",
		}

	# 2) Rounds 1-3: the hot ramp — attack every turn (Petals / Flute / basic).
	if round_no <= 3:
		return _attack_decision(enemy, player, dist)

	# 3) Rounds 4+: deterministic throttle — attack only on period-aligned
	#    rounds (THROTTLE_PERIOD = 2 ⇒ current_round % 2 == 0).
	if round_no % THROTTLE_PERIOD == 0:
		return _attack_decision(enemy, player, dist)

	# 4) Throttled turn: Peach Blossom Maze (hazard zone around self) when
	#    useful, else hold in place — never move, never retreat, so he stays
	#    inside the player's radius-2 AoE envelope.
	if _is_skill_ready(enemy, 2) and dist <= 2:
		return {
			move_path = [], action = "skill", target = enemy,
			skill_index = 2, fsm_state = "SKILL",
		}
	return { move_path = [], action = "wait", fsm_state = "WAIT" }


## Damaging turn: Falling Petals, then Jade Flute Acupoint, then the basic
## attack from range 3; approaches to range 3 when out of reach. Peach
## Blossom Maze is deliberately NOT in this path (it is the throttle action
## on non-attack turns from round 4). Never retreats.
func _attack_decision(enemy: Node, player: Node, dist: int) -> Dictionary:
	# 1) Falling Petals (3x3 centered on the target tile, range 3).
	if _is_skill_ready(enemy, 0) and dist <= 3:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 0, fsm_state = "SKILL",
		}
	# 2) Jade Flute Acupoint (technique seal; the rule gates it at range 3).
	if _is_skill_ready(enemy, 1) and dist <= 3:
		return {
			move_path = [], action = "skill", target = player,
			skill_index = 1, fsm_state = "SKILL",
		}
	# 3) In basic range (22 @ 3) — hold and shoot from range 3, never retreat.
	if dist <= 3:
		return {
			move_path = [], action = "basic_attack", target = player,
			fsm_state = "ATTACK",
		}
	# 4) Approach to preferred range 3 (attack turns only; throttled turns
	#    never move).
	return _approach_decision(enemy, player, 3)
