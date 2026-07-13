## Player — Yang Guo character controller
##
## Handles WASD/arrow grid movement, skill selection (1/2 keys),
## left-click enemy targeting, and action requests to CombatManager.
## Lives in battlefield as a child of the Battlefield scene.
extends Node2D

const CharacterData = preload("res://scripts/data/character_data.gd")
const SkillData = preload("res://scripts/data/skill_data.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when health changes. HUD HealthBar listens to this.
signal health_changed(new_health: int, max_health: int)

## Emitted every frame when cooldowns change. HUD skill buttons listen to this.
signal cooldowns_updated(cooldowns: Array)

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

## True while a movement tween is playing. Blocks new input during animation.
var is_moving: bool = false

## Index of the currently selected skill, or -1 for basic attack.
var selected_skill_index: int = -1

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _sprite: Polygon2D = $Sprite
@onready var _name_label: Label = $NameLabel

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Circle segment count for the procedural Polygon2D shape.
const CIRCLE_SEGMENTS: int = 32

## Circle radius in pixels.
const CIRCLE_RADIUS: float = 28.0

## Movement animation duration in seconds (matches GridManager's tween).
const MOVE_DURATION: float = 0.15

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise the player with a CharacterData resource.
## Called by battlefield.gd after instantiating this scene.
func setup(data) -> void:
	character_data = data

	# Health.
	max_health = data.max_health
	health = max_health

	# Skills.
	skills = data.skills.duplicate()
	skill_cooldowns = []
	for _i in skills.size():
		skill_cooldowns.append(0.0)

	# Grid position from current world position (set by battlefield after
	# positioning the node).
	grid_pos = GridManager.world_to_grid(position)

	# Visual appearance.
	if _sprite != null:
		_sprite.color = data.color
	if _name_label != null:
		_name_label.text = data.character_name

	# Deselect any skill.
	selected_skill_index = -1


## Select (or toggle off) a skill by its index.
## Called by HUD buttons via GameManager.get_player().
func select_skill(index: int) -> void:
	if index == selected_skill_index:
		# Toggle off.
		selected_skill_index = -1
	else:
		selected_skill_index = index


## Returns whether the player is currently animating a movement tween.
## Used by CombatManager.is_unit_busy().
func get_is_moving() -> bool:
	return is_moving


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_generate_circle_polygon()

	# Snap to grid position if not already set.
	if grid_pos == Vector2i(-1, -1):
		grid_pos = GridManager.world_to_grid(position)
	position = GridManager.grid_to_world(grid_pos)


func _process(delta: float) -> void:
	# Only tick cooldowns during active battle, and only when unpaused.
	var state: String = GameManager.get_state()
	if state != "BATTLE":
		return
	if CombatManager.get_is_paused():
		return

	# Tick cooldowns.
	var changed: bool = false
	for i in range(skill_cooldowns.size()):
		var new_val: float = skill_cooldowns[i] - delta
		if new_val < 0.0:
			new_val = 0.0
		if skill_cooldowns[i] != new_val:
			changed = true
		skill_cooldowns[i] = new_val

	# Emit update for HUD if any cooldown changed.
	if changed:
		cooldowns_updated.emit(skill_cooldowns.duplicate())


func _unhandled_input(event: InputEvent) -> void:
	# Gate: ignore input if game is over or player is moving.
	var state: String = GameManager.get_state()
	if state == "WON" or state == "LOST":
		return
	if is_moving:
		return

	# --- Movement (WASD / Arrow keys) ---
	if event.is_action_pressed("move_up"):
		_try_move(Vector2i(0, -1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_try_move(Vector2i(0, 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_try_move(Vector2i(-1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_try_move(Vector2i(1, 0))
		get_viewport().set_input_as_handled()

	# --- Skill selection (1 / 2 keys) ---
	elif event.is_action_pressed("skill_1"):
		_try_select_skill(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_2"):
		_try_select_skill(1)
		get_viewport().set_input_as_handled()

	# --- Pause toggle (Space / Escape) ---
	elif event.is_action_pressed("pause_game"):
		if TutorialManager.is_input_allowed("pause"):
			CombatManager.toggle_pause()
			get_viewport().set_input_as_handled()

	# --- Left-click on enemy grid position ---
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_handle_click_targeting()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## Attempt to move one tile in the given cardinal direction.
func _try_move(direction: Vector2i) -> void:
	# Input gating — tutorial must allow movement.
	if not TutorialManager.is_input_allowed("move"):
		return

	var target: Vector2i = grid_pos + direction

	# Validate bounds.
	if not GridManager.is_in_bounds(target):
		return

	# Validate occupancy.
	if GridManager.is_occupied(target):
		return

	# Initiate movement via GridManager (handles occupancy + tween).
	is_moving = true
	GridManager.move_unit(self, grid_pos, target)
	grid_pos = target

	# Schedule is_moving reset after the animation completes.
	var reset_tween: Tween = create_tween()
	reset_tween.tween_callback(_on_move_completed).set_delay(MOVE_DURATION)


## Called when the movement animation finishes.
func _on_move_completed() -> void:
	if not is_instance_valid(self):
		return
	is_moving = false
	# Snap position to exact grid centre (prevents floating-point drift).
	position = GridManager.grid_to_world(grid_pos)


# ---------------------------------------------------------------------------
# Skill selection
# ---------------------------------------------------------------------------

## Attempt to select (or toggle off) a skill by index.
func _try_select_skill(index: int) -> void:
	var action_name: String = "skill_1" if index == 0 else "skill_2"
	if not TutorialManager.is_input_allowed(action_name):
		return

	if selected_skill_index == index:
		# Toggle off.
		selected_skill_index = -1
	else:
		selected_skill_index = index


# ---------------------------------------------------------------------------
# Targeting (left-click)
# ---------------------------------------------------------------------------

## Handle a left mouse click: find which enemy (if any) was clicked on the grid
## and execute the appropriate action.
func _handle_click_targeting() -> void:
	var click_world: Vector2 = get_global_mouse_position()
	var click_grid: Vector2i = GridManager.world_to_grid(click_world)

	# Iterate living enemies to see if one occupies the clicked tile.
	var enemies: Array[Node] = GameManager.get_enemies_alive()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		if enemy.grid_pos != click_grid:
			continue

		# Found an enemy at the clicked grid position.
		# Determine whether to use a skill or basic attack.
		if selected_skill_index >= 0:
			# Using a skill.
			var skill_action: String = "skill_1" if selected_skill_index == 0 else "skill_2"
			if not TutorialManager.is_input_allowed(skill_action):
				return
			if skill_cooldowns[selected_skill_index] > 0.0:
				# Cooldown not ready — silently ignore.
				return

			# Check range: skill.range must satisfy Chebyshev distance.
			var skill = skills[selected_skill_index]
			if not _is_in_range(enemy, skill.range):
				# Out of range — silently ignore.
				return

			_execute_skill(selected_skill_index, enemy)
			selected_skill_index = -1  # Auto-deselect after use.

		else:
			# Basic attack.
			if not TutorialManager.is_input_allowed("basic_attack"):
				return

			# Must be adjacent (Chebyshev distance <= 1).
			if not _is_adjacent(enemy.grid_pos):
				# Out of range — silently ignore.
				return

			_execute_basic_attack(enemy)

		# Only act on the first matched enemy.
		break


# ---------------------------------------------------------------------------
# Action execution
# ---------------------------------------------------------------------------

## Execute a basic attack against the given target enemy.
func _execute_basic_attack(target: Node) -> void:
	CombatManager.request_action(self, "basic_attack", target, {})


## Execute a skill against the given target enemy.
## Cooldown is set by CombatManager._execute_skill internally.
func _execute_skill(skill_index: int, target: Node) -> void:
	if skill_index < 0 or skill_index >= skills.size():
		return
	if skill_cooldowns[skill_index] > 0.0:
		return  # Cooldown not ready — shouldn't reach here but guard anyway.

	CombatManager.request_action(self, "skill", target, {
		"skill_index": skill_index,
	})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns true if the given grid position is adjacent (Chebyshev distance ≤ 1).
func _is_adjacent(pos: Vector2i) -> bool:
	return abs(grid_pos.x - pos.x) <= 1 and abs(grid_pos.y - pos.y) <= 1


## Returns true if the given enemy is within the specified range (Chebyshev).
func _is_in_range(enemy: Node, range_val: int) -> bool:
	if not ("grid_pos" in enemy):
		return false
	var enemy_pos: Vector2i = enemy.grid_pos
	return abs(grid_pos.x - enemy_pos.x) <= range_val \
		and abs(grid_pos.y - enemy_pos.y) <= range_val


## Generate a filled circle polygon for the Sprite Polygon2D.
func _generate_circle_polygon() -> void:
	if _sprite == null:
		return

	var points: PackedVector2Array = []
	var angle_step: float = TAU / CIRCLE_SEGMENTS

	for i in range(CIRCLE_SEGMENTS):
		var angle: float = i * angle_step
		points.append(Vector2(
			cos(angle) * CIRCLE_RADIUS,
			sin(angle) * CIRCLE_RADIUS
		))

	_sprite.set_polygon(points)
