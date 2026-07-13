class_name SkillData
extends Resource

## Data-only resource defining a martial arts skill's parameters.
## Instantiated programmatically in battlefield.gd — not saved as .tres files.

@export var skill_name: String = ""
@export var description: String = ""
@export var damage: int = 0
@export var range: int = 1
@export var cooldown: float = 0.0
@export var aoe_shape: String = "single"  # "single", "line", "cross", "square"
@export var aoe_size: int = 0             # radius in tiles (1 = self + adjacent 3x3)
@export var knockback: int = 0            # tiles pushed back (0 = none)
@export var dot_damage: int = 0           # damage per tick (0 = none)
@export var dot_duration: float = 0.0     # seconds
@export var heal_amount: int = 0          # 0 = not a heal
