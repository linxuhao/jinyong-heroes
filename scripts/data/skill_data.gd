extends Resource

## Data-only resource defining a martial arts skill's parameters.
## Instantiated programmatically in battlefield.gd — not saved as .tres files.

@export var skill_name: String = ""
@export var description: String = ""
@export var damage: int = 0
@export var range: int = 1
@export var cooldown: int = 0             # cooldown in ROUNDS (was float seconds)
@export var aoe_shape: String = "single"  # "single", "line", "cross", "square", "adjacent"
@export var aoe_size: int = 0             # radius in tiles (1 = self + adjacent 3x3)
@export var knockback: int = 0            # tiles pushed back (0 = none)
@export var dot_damage: int = 0           # damage per tick (0 = none)
@export var dot_rounds: int = 0           # DoT duration in ROUNDS (replaces float dot_duration)
@export var heal_amount: int = 0          # 0 = not a heal
@export var aoe_origin: String = "self"   # "self"|"target"|"landing"
@export var shield_amount: int = 0        # shield granted (0 = none)
@export var shield_rounds: int = 0        # shield duration in rounds
@export var jump_tiles: int = 0           # jump displacement (3 for jump techniques)
@export var status_applied: String = ""   # "poison"|"move_minus_next_turn"|"no_techniques_next_turn"|
                                          #  "no_move_next_turn"|"init_minus_20"|"toad_charge"|"hazard_zone"
@export var ignore_damage_reduction: bool = false   # e.g. Solar Finger bypasses DR
@export var hp_gate_below_ratio: float = 0.0        # usable only below this HP fraction (0.5 = Seventeen Forms)
@export var target_friendly: bool = false           # heal/affect allies (e.g. Primal Breath)
@export var is_finisher: bool = false               # 绝招 flag for display
@export var cost: int = 0              # 内力消耗 (0 = 未定义/不消耗; the only shipped value this round)

## Insufficient-inner-force predicate (single source of truth, jinyong-spend-qi):
## true only when the skill costs inner force (cost > 0) AND the pool is strictly
## below it. cost == 0 never blocks (free basic, enemy/progression techniques).
## Semantically identical to skill_button.gd::no_energy_predicate, which a later
## task delegates here. Shared by the executor gate (combat_manager.gd), the
## player's select-time rejection (player.gd), and the debug drain. Pure — no
## instance state.
static func insufficient_energy(cost: int, energy: int) -> bool:
	return cost > 0 and energy < cost

## Spend math (pure): pool minus cost, clamped at 0; a negative cost reads as 0.
## The executor's deduction and the debug drain both go through this one path.
static func spend(current: int, cost: int) -> int:
	return maxi(current - maxi(cost, 0), 0)
