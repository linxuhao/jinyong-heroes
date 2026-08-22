## Enemy — Generic AI-driven opponent
##
## Generic shell for all five Greats (五绝). Pluggable AI controller
## (AIControllerBase) provides distinct per-enemy behavior. The turn engine
## (CombatManager) invokes ai_controller.evaluate() exactly once per enemy
## turn and executes the returned move path + one action. Follows the same
## turn-state pattern as Player (per-turn budgets, round-based int cooldowns).
extends Node2D

const CharacterData = preload("res://scripts/data/character_data.gd")
const SkillData = preload("res://scripts/data/skill_data.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when health changes. HUD HealthBar listens to this.
signal health_changed(new_health: int, max_health: int)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Current grid position (tile coordinate).
var grid_pos: Vector2i = Vector2i(-1, -1)

## Current health points.
var health: int = 100

## Maximum health points.
var max_health: int = 100

## The CharacterData resource set by battlefield during setup.
var character_data = null

## Array of SkillData resources (from character_data).
var skills: Array = []

## Per-skill remaining cooldown in ROUNDS (parallel to skills array).
## Ints, initialised to 0 (ready) by setup(). Decremented by the turn engine
## (CombatManager.begin_turn) at the unit's own turn start — never per frame.
var skill_cooldowns: Array[int] = []

## Movement budget remaining this turn (tiles). Reset to move_range by the
## engine at the start of every turn.
var moves_left: int = 0

## True once the unit has moved this turn.
var moved: bool = false

## True once the unit has performed an action this turn.
var acted: bool = false

## Number of turns this unit has taken since the battle began.
var turns_taken: int = 0

## Shield pool (absorbed before HP). Managed by CombatManager status ticks.
var shield: int = 0

## Per-unit status table (poison / shield / next-turn restrictions / ...).
## Entries: { id, kind, rounds, params }. Written by CombatManager.
var statuses: Array[Dictionary] = []

## Observable status ids, kept in sync with statuses (surface contract).
var status_names: Array[String] = []

## 身法 initiative value; drives turn order.
var initiative: int = 0

## Team id: 1 = Five Greats.
var team: int = 1

## Primary internal art's passive id (engine hooks: finger_dart, ...).
var passive_id: String = ""

## 内力 energy pool (display only — no technique costs this run).
var energy: int = 0

## Movement range in tiles (from character_data; caps AI move budgets).
var move_range: int = 0

## True while a movement tween is playing. Set/cleared by CombatManager.
var is_moving: bool = false

## World-px top edge of the sprite texture rect, updated every frame by
## _refresh_sprite_clamp(). Exposed for playtest surface assertions.
var sprite_top: float = 0.0

## Current FSM state label. One of: "IDLE", "APPROACH", "ATTACK",
## "SKILL", "RETREAT". Updated from the AI evaluation result.
var fsm_state: String = "IDLE"

## Pluggable AI controller (AIControllerBase, RefCounted — NOT a Node).
## Set by battlefield.gd after instantiation.
var ai_controller = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _sprite: Sprite2D = $Sprite

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Character name → preloaded portrait texture. Keys MUST match the
## character_name values set in battlefield.gd.
const TEXTURE_PATHS: Dictionary = {
	"East Heretic": preload("res://assets/characters/east_heretic.png"),
	"West Poison": preload("res://assets/characters/west_poison.png"),
	"South Emperor": preload("res://assets/characters/south_emperor.png"),
	"North Beggar": preload("res://assets/characters/north_beggar.png"),
	"Central Divine": preload("res://assets/characters/central_divine.png"),
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise the enemy with a CharacterData resource and AI controller.
## Called by battlefield.gd after instantiating this scene.
func setup(data, ai) -> void:
	character_data = data

	# Health.
	max_health = data.max_health
	health = max_health

	# Skills (cooldowns as int ROUNDS, initialised ready).
	skills = data.skills.duplicate()
	skill_cooldowns = []
	for _i in skills.size():
		skill_cooldowns.append(0)

	# AI controller.
	ai_controller = ai

	# Turn-based state from the CharacterData record.
	moves_left = data.move_range
	move_range = data.move_range
	initiative = data.initiative
	team = 1
	passive_id = data.passive_id
	energy = data.energy
	statuses = []
	status_names = []
	shield = 0
	turns_taken = 0
	moved = false
	acted = false

	# FSM starts idle.
	fsm_state = "IDLE"

	# Grid position from current world position (set by battlefield after
	# positioning the node).
	grid_pos = GridManager.world_to_grid(position)

	# Visual appearance.
	_apply_character_visuals()


## Returns whether the enemy is currently animating a movement tween.
## Used by the combat engine to gate animation overlap.
func get_is_moving() -> bool:
	return is_moving


## Turn-start hook. Intentionally EMPTY: the turn engine calls
## CombatManager.begin_turn(unit), which owns the full turn-start lifecycle
## (budget reset incl. next-turn restrictions, round-based int cooldown
## decrement + cooldowns_updated emit, DoT/status ticks, constant regen).
## This hook must NEVER replicate that logic — double-decrementing cooldowns
## or re-resetting budgets would desync the engine.
func begin_turn() -> void:
	pass


## Clear the one-turn restriction statuses at the end of this turn
## (dragging mire / jade flute acupoint / acupoint lock). Called by
## CombatManager.end_current_turn().
func clear_this_turn_restrictions() -> void:
	_remove_status("move_minus_next_turn")
	_remove_status("no_techniques_next_turn")
	_remove_status("no_move_next_turn")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Snap to grid position if not already set.
	if grid_pos == Vector2i(-1, -1):
		grid_pos = GridManager.world_to_grid(position)
	position = GridManager.grid_to_world(grid_pos)


func _process(_delta: float) -> void:
	# Clamp the sprite into the artwork rect every frame (before the state gate
	# so sprite_top is updated during TUTORIAL too).
	# NOTE: cooldowns are int ROUNDS, decremented only by the turn engine at
	# the unit's own turn start — no per-frame ticking, no timer-driven AI.
	_refresh_sprite_clamp()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Remove every status entry with the given id and sync status_names.
func _remove_status(status_id: String) -> void:
	var i: int = 0
	while i < statuses.size():
		if statuses[i].get("id", "") == status_id:
			statuses.remove_at(i)
		else:
			i += 1
	_sync_status_names()


## Rebuild status_names from the statuses table (surface observability).
func _sync_status_names() -> void:
	status_names = []
	for st in statuses:
		status_names.append(str(st.get("id", "")))


## Assign the character portrait texture, tint and feet anchor to the Sprite.
## Resolves the node via get_node_or_null so it works even when called from
## setup() BEFORE the node enters the tree (@onready _sprite is null then).
func _apply_character_visuals() -> void:
	var sprite: Sprite2D = _sprite
	if sprite == null:
		sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return

	var name_key: String = character_data.character_name if character_data != null else ""
	var tex: Texture2D = TEXTURE_PATHS.get(name_key, null)
	if tex == null:
		# Null-safe fallback: sprite stays texture-less (invisible), logic intact.
		push_warning("Enemy texture not found for character: %s" % name_key)
		return

	sprite.texture = tex
	sprite.modulate = Color.WHITE
	sprite.offset = Vector2(0, -(tex.get_height() / 2.0))  # feet at tile centre


## Clamp the sprite's offset so the whole texture rect stays inside the board
## artwork rect, and publish sprite_top for playtest assertions. Idempotent:
## only writes _sprite.offset when the clamp changes it. Called every frame at
## the top of _process() (before state gates), so top-row enemies are clamped
## during TUTORIAL too. The clamp is authoritative per frame — it refines any
## feet anchor set by _apply_character_visuals().
func _refresh_sprite_clamp() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var tex_size: Vector2 = _sprite.texture.get_size()
	var desired: Vector2 = GridManager.clamp_sprite_offset(position, tex_size)
	if _sprite.offset != desired:
		_sprite.offset = desired
	sprite_top = position.y + desired.y - tex_size.y / 2.0
