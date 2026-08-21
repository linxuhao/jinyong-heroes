## Enemy — Generic AI-driven opponent
##
## Generic shell for all five Greats (五绝). Pluggable AI controller
## (AIControllerBase) provides distinct per-enemy behavior. Delegates
## action execution to CombatManager. Follows the same pattern as
## Player but is driven by an AI accumulator tick instead of keyboard input.
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

## Per-skill remaining cooldown in seconds (parallel to skills array).
## Initialised to 0.0 (ready) by setup().
var skill_cooldowns: Array[float] = []

## True while a movement tween is playing. Set/cleared by CombatManager.
var is_moving: bool = false

## World-px top edge of the sprite texture rect, updated every frame by
## _refresh_sprite_clamp(). Exposed for playtest surface assertions.
var sprite_top: float = 0.0

## Current FSM state label. One of: "IDLE", "APPROACH", "ATTACK",
## "SKILL", "RETREAT". Updated by AI evaluation results.
var fsm_state: String = "IDLE"

## Pluggable AI controller (AIControllerBase, RefCounted — NOT a Node).
## Set by battlefield.gd after instantiation.
var ai_controller = null

## Accumulator for AI decision ticks. Ticks up by delta every frame,
## triggers AI evaluation when >= 0.5 seconds.
var _ai_accumulator: float = 0.0

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

## AI evaluation interval in seconds.
const AI_TICK_INTERVAL: float = 0.5

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

	# Skills.
	skills = data.skills.duplicate()
	skill_cooldowns = []
	for _i in skills.size():
		skill_cooldowns.append(0.0)

	# AI controller.
	ai_controller = ai

	# FSM starts idle.
	fsm_state = "IDLE"

	# Grid position from current world position (set by battlefield after
	# positioning the node).
	grid_pos = GridManager.world_to_grid(position)

	# Visual appearance.
	_apply_character_visuals()


## Returns whether the enemy is currently animating a movement tween.
## Used by CombatManager.is_unit_busy().
func get_is_moving() -> bool:
	return is_moving


## Reset the AI decision timer so the AI re-evaluates immediately.
## Called by CombatManager._drain_action_queue after an action completes.
func reset_ai_timer() -> void:
	_ai_accumulator = AI_TICK_INTERVAL  # will trigger next _process


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Snap to grid position if not already set.
	if grid_pos == Vector2i(-1, -1):
		grid_pos = GridManager.world_to_grid(position)
	position = GridManager.grid_to_world(grid_pos)


func _process(delta: float) -> void:
	# Clamp the sprite into the artwork rect every frame (before the state gate
	# so sprite_top is updated during TUTORIAL too).
	_refresh_sprite_clamp()

	# Only tick during active battle, and only when unpaused.
	var state: String = GameManager.get_state()
	if state != "BATTLE":
		return
	if CombatManager.get_is_paused():
		return

	# Tick cooldowns.
	for i in range(skill_cooldowns.size()):
		var new_val: float = skill_cooldowns[i] - delta
		if new_val < 0.0:
			new_val = 0.0
		skill_cooldowns[i] = new_val

	# AI decision tick — accumulate and evaluate at interval.
	_ai_accumulator += delta
	if _ai_accumulator >= AI_TICK_INTERVAL and not CombatManager.is_unit_busy(self):
		_ai_accumulator = 0.0
		_evaluate_ai()


# ---------------------------------------------------------------------------
# AI evaluation
# ---------------------------------------------------------------------------

## Call the AI controller's evaluate() method and process its decision.
func _evaluate_ai() -> void:
	if ai_controller == null:
		return

	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if not ("health" in player) or player.health <= 0:
		return

	var decision: Dictionary = ai_controller.evaluate(self, player, 0.0)
	if decision.is_empty():
		fsm_state = "IDLE"
		return

	var action: String = decision.get("action", "")
	match action:
		"move":
			var params: Dictionary = decision.get("params", {})
			var to_pos: Vector2i = params.get("to", grid_pos)
			# Determine direction: towards player → APPROACH, away → RETREAT.
			if _distance(to_pos, player.grid_pos) < _distance(grid_pos, player.grid_pos):
				fsm_state = "APPROACH"
			else:
				fsm_state = "RETREAT"
			# Delegate movement to the enemy itself as target (move affects self).
			CombatManager.request_action(self, "move", self, params)

		"basic_attack":
			fsm_state = "ATTACK"
			var target: Node = decision.get("target", player)
			CombatManager.request_action(self, "basic_attack", target, {})

		"skill":
			fsm_state = "SKILL"
			var target: Node = decision.get("target", player)
			var params: Dictionary = decision.get("params", {})
			CombatManager.request_action(self, "skill", target, params)

		_:
			fsm_state = "IDLE"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Chebyshev distance helper (mirrors AIControllerBase._distance).
func _distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


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
