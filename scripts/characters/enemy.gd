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

@onready var _sprite: Polygon2D = $Sprite
@onready var _name_label: Label = $NameLabel

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Diamond half-radius in pixels (point-to-centre distance).
const DIAMOND_RADIUS: float = 28.0

## Diamond polygon vertex count.
const DIAMOND_POINTS: int = 4

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
	if _sprite != null:
		_sprite.color = data.color
	if _name_label != null:
		_name_label.text = data.character_name


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
	_generate_diamond_polygon()

	# Snap to grid position if not already set.
	if grid_pos == Vector2i(-1, -1):
		grid_pos = GridManager.world_to_grid(position)
	position = GridManager.grid_to_world(grid_pos)


func _process(delta: float) -> void:
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


## Generate a filled diamond polygon for the Sprite Polygon2D.
func _generate_diamond_polygon() -> void:
	if _sprite == null:
		return

	var points: PackedVector2Array = [
		Vector2(0.0, -DIAMOND_RADIUS),    # top
		Vector2(DIAMOND_RADIUS, 0.0),     # right
		Vector2(0.0, DIAMOND_RADIUS),     # bottom
		Vector2(-DIAMOND_RADIUS, 0.0),    # left
	]

	_sprite.set_polygon(points)
