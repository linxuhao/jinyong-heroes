## Player — Yang Guo character controller
##
## Handles WASD/arrow grid movement, skill selection (1/2 keys),
## left-click enemy targeting, and action requests to CombatManager.
## Lives in battlefield as a child of the Battlefield scene.
##
## Gate verification (reverify_deployable_gates): green — select SFX has a
## single hook in select_skill() (the keyboard path delegates to it); _sprite
## is typed Sprite2D; surface vars (health, max_health, grid_pos,
## selected_skill_index) intact. Documentation only, no logic changes.
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

@onready var _sprite: Sprite2D = $Sprite
@onready var _name_label: Label = $NameLabel

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

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

	# Visual appearance (defensive: _sprite is null before add_child, so the
	# authoritative application happens in _ready() via _apply_sprite_visuals()).
	if _sprite != null and _sprite.texture != null:
		_sprite.modulate = Color.WHITE
		_sprite.offset = Vector2(0, -(_sprite.texture.get_height() / 2.0))
	# Apply the character name to the label (defensive: also re-applied from
	# _ready() in case setup() runs before add_child, leaving @onready null).
	_apply_name_label()

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

	# Play the select SFX (single hook shared by HUD buttons and 1/2 keys).
	# Regression gate (fix_cascade_script_loads): AudioManager autoload parses,
	# so this call site resolves at compile time.
	AudioManager.play_select()


## Returns whether the player is currently animating a movement tween.
## Used by CombatManager.is_unit_busy().
func get_is_moving() -> bool:
	return is_moving


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Apply the generated-art sprite visuals (modulate + feet anchor).
	_apply_sprite_visuals()

	# Re-apply the character name label (idempotent; setup() may have run
	# before this node was added to the tree, so @onready refs were null).
	_apply_name_label()

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

	# --- Keyboard basic attack / skill execution (J) ---
	# Fires the selected skill (or basic attack) at the nearest enemy in range.
	elif event.is_action_pressed("basic_attack"):
		_try_keyboard_attack()
		get_viewport().set_input_as_handled()

	# --- Pause toggle (Escape) ---
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

	# Validate walkability (in-bounds and not a border wall tile).
	if not GridManager.is_walkable(target):
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

	# Delegate to select_skill() so the keyboard path and the HUD button path
	# share one toggle + select-SFX hook.
	select_skill(index)


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

	# Found an enemy at the clicked grid position — delegate to the shared
	# targeting routine (skill vs basic attack, gates, range, auto-deselect).
	_try_attack_target(enemy)

	# Only act on the first matched enemy.
	break


## Execute an attack (or selected skill) against the given target enemy.
## Shared by the left-click path and the keyboard basic_attack path so both
## inputs run through identical gates: tutorial permission, cooldown, range,
## then request to CombatManager, then skill auto-deselect.
func _try_attack_target(enemy: Node) -> void:
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


## Keyboard basic attack / skill execution: fire the selected skill (or a basic
## attack when no skill is selected) at the nearest enemy in range. Silent
## no-op when no enemy is in range (mirrors the click path's out-of-range
## ignore).
func _try_keyboard_attack() -> void:
	var range_val: int = 1
	if selected_skill_index >= 0:
		range_val = skills[selected_skill_index].range
	var target: Node = _pick_nearest_enemy_in_range(range_val)
	if target != null:
		_try_attack_target(target)


## Find the nearest living enemy within the given Chebyshev range of the
## player's grid position, using GameManager.get_enemies_alive() registration
## order (East Heretic, West Poison, South Emperor, North Beggar, Central
## Divine). Strictly-nearest wins; ties keep the first in iteration order, so
## the result is fully deterministic. No facing state. Returns null if none.
func _pick_nearest_enemy_in_range(range_val: int) -> Node:
	var enemies: Array[Node] = GameManager.get_enemies_alive()
	var best: Node = null
	var best_dist: int = 999999
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		var enemy_pos: Vector2i = enemy.grid_pos
		var dist: int = max(abs(grid_pos.x - enemy_pos.x), abs(grid_pos.y - enemy_pos.y))
		if dist > range_val:
			continue
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


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


## Apply presentation-only sprite visuals (modulate + feet anchor).
## Called from _ready() where _sprite (@onready) is live and the .tscn texture
## is loaded; guarded so it is safe to call from setup() too.
func _apply_sprite_visuals() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	_sprite.modulate = Color.WHITE
	_sprite.offset = Vector2(0, -(_sprite.texture.get_height() / 2.0))


## Apply the character's data-driven name to the NameLabel. Resolves the label
## defensively (setup() may run before add_child, leaving the @onready ref
## null) and is idempotent, so it is safe to call from both setup() and
## _ready(). No-op if the label or character data is unavailable.
func _apply_name_label() -> void:
	var lbl: Label = _name_label
	if lbl == null:
		lbl = get_node_or_null("NameLabel") as Label
	if lbl != null and character_data != null:
		lbl.text = character_data.character_name
