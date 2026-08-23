extends Resource

## Data-only resource defining a character's stats, skills, and AI configuration.
## Instantiated programmatically in battlefield.gd — not saved as .tres files.

@export var character_name: String = ""
## Rendered display name (Chinese, design §2.1). `character_name` stays the
## canonical English identity — this field is the display layer only.
@export var display_name: String = ""
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

## Battle-side trait carrier: profile trait ids copied onto the battle
## CharacterData by BattleSetup.build_character (combat hooks key off these).
@export var traits: Array[String] = []
