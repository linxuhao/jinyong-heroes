extends Resource

## Data-only resource defining a character's stats, skills, and AI configuration.
## Instantiated programmatically in battlefield.gd — not saved as .tres files.

@export var character_name: String = ""
@export var max_health: int = 100
@export var move_range: int = 1           # tiles per move action
@export var attack_damage: int = 10
@export var attack_range: int = 1         # tiles
@export var skills: Array = []
@export var ai_class: String = ""         # e.g. "AIControllerEastHeretic"
@export var color: Color = Color.WHITE    # placeholder shape color
@export var initiative: int = 0           # 身法 value; drives turn order
@export var energy: int = 0               # 内力 pool (display only; player 180, enemies 0)
@export var internal_arts: Array = []     # Array of GongfaData
@export var external_arts: Array = []     # Array of GongfaData
@export var passive_id: String = ""       # primary internal art's passive
@export var team: int = 0                 # 0 = player, 1 = Five Greats

## 编排数值 (staged values) marker: when true, the 甲乙丙丁 fa_hui_du cascade is
## bypassed and every art keeps its flat `fa_hui_du` field. The tutorial battle
## sets this on all six units so the protected 1.3 values stay byte-identical.
@export var staged_values: bool = false
