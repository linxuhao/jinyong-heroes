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
