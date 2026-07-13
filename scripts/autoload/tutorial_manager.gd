## TutorialManager (autoload)
##
## Step-by-step tutorial overlay system with input gating. Manages 7 tutorial
## steps that teach the player movement, basic attacks, skills, and pause.
## Once the tutorial completes (or is skipped), calls GameManager.start_battle().
## Responds to ui_accept (Enter/Space) for automated headless playtest.
extends Node

# ---------------------------------------------------------------------------
# Step constants
# ---------------------------------------------------------------------------

const STEP_WELCOME: int = 0
const STEP_MOVEMENT: int = 1
const STEP_BASIC_ATTACK: int = 2
const STEP_SKILL_1: int = 3
const STEP_SKILL_2: int = 4
const STEP_PAUSE: int = 5
const STEP_COMBAT_START: int = 6
const STEP_COUNT: int = 7

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a tutorial step is shown. Passes the step id.
signal step_shown(step_id: int)

## Emitted when a tutorial step is completed. Passes the step id.
signal step_completed(step_id: int)

## Emitted when the entire tutorial is finished (all steps done or skipped).
signal tutorial_finished()

## Emitted when the tutorial is skipped by the player.
signal tutorial_skipped()

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The current step index (0-based). Read by external scripts.
var current_step: int = 0

## Whether each step has been completed. Indexed by step id.
## NOTE: intentionally prefixed to avoid name collision with the signal.
var _completed_steps: Array[bool] = []

## True while the tutorial is active and showing overlays.
var is_active: bool = false

## Reference to the tutorial overlay CanvasLayer, set via set_overlay().
var _tutorial_overlay: CanvasLayer = null

## Action names that the player is allowed to perform, accumulated as steps
## complete. Checked by is_input_allowed().
var _allowed_actions: Array[String] = []

## Cached reference to the overlay's "Next" button.
var _next_button: Button = null

## Cached reference to the overlay's "Skip Tutorial" button.
var _skip_button: Button = null

## Cached reference to the overlay's title Label.
var _title_label: Label = null

## Cached reference to the overlay's body RichTextLabel.
var _body_label: RichTextLabel = null

## Cached reference to the overlay's root dim ColorRect (for show/hide).
var _dim_rect: ColorRect = null

# ---------------------------------------------------------------------------
# Step overlay content
# ---------------------------------------------------------------------------

## Title strings keyed by step id.
const _STEP_TITLES: Dictionary = {
	STEP_WELCOME: "Welcome to Huashan Sword Tournament",
	STEP_MOVEMENT: "Movement",
	STEP_BASIC_ATTACK: "Basic Attack",
	STEP_SKILL_1: "Skill: Sorrowful Palms (黯然销魂掌)",
	STEP_SKILL_2: "Skill: Heavy Iron Sword (玄铁剑法)",
	STEP_PAUSE: "Pause Combat",
	STEP_COMBAT_START: "Battle Begin!",
}

## Body strings (with BBCode) keyed by step id.
const _STEP_BODIES: Dictionary = {
	STEP_WELCOME: (
		"You are Yang Guo (杨过). Defeat all Five Greats to become champion!\n\n"
		+ "Press [b]Next[/b] or [b]Enter/Space[/b] to continue."
	),
	STEP_MOVEMENT: (
		"Use [b]WASD[/b] or [b]Arrow keys[/b] to move Yang Guo one tile at a "
		+ "time on the grid.\n\nTry moving now!"
	),
	STEP_BASIC_ATTACK: (
		"Move adjacent to an enemy, then [b]left-click[/b] on them to perform "
		+ "a basic attack.\n\nTry attacking an enemy!"
	),
	STEP_SKILL_1: (
		"Press [b]1[/b] to select Sorrowful Palms, then click an adjacent "
		+ "enemy.\nHigh damage with knockback. 4s cooldown."
	),
	STEP_SKILL_2: (
		"Press [b]2[/b] to select Heavy Iron Sword.\n"
		+ "Line AoE attack hitting enemies in a 2-tile line. 3s cooldown."
	),
	STEP_PAUSE: (
		"Press [b]Space[/b] or [b]Escape[/b] to pause/unpause combat at any "
		+ "time.\nUse this to plan your next move!"
	),
	STEP_COMBAT_START: (
		"The tutorial is complete. Defeat all Five Greats!\n\n"
		+ "Press [b]Next[/b] to begin."
	),
}

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

func _ready() -> void:
	_completed_steps.resize(STEP_COUNT)
	_reset_step_completed()


## Reset all step-completed flags to false.
func _reset_step_completed() -> void:
	for i in range(STEP_COUNT):
		_completed_steps[i] = false

# ---------------------------------------------------------------------------
# Public API — Lifecycle
# ---------------------------------------------------------------------------

## Start the tutorial from step 0. Shows the first overlay and gates game
## input. Should be called after the battlefield is ready.
func start() -> void:
	if is_active:
		return

	is_active = true
	current_step = 0
	_allowed_actions = []
	_reset_step_completed()
	_show_current_step()


## Advance to the next tutorial step. Marks the current step as completed.
## If all enemies are already dead, fast-forwards to COMBAT_START.
## If the current step is COMBAT_START, finishes the tutorial.
func advance() -> void:
	if not is_active:
		return

	# Mark current step as completed.
	if current_step >= 0 and current_step < STEP_COUNT:
		_completed_steps[current_step] = true
		step_completed.emit(current_step)

	# Update allowed actions based on the step just completed.
	_update_allowed_actions()

	# Fast-forward if all enemies are dead mid-tutorial.
	if GameManager.enemies_alive.is_empty() and current_step < STEP_COMBAT_START:
		current_step = STEP_COMBAT_START
		# Unlock all actions when fast-forwarding.
		_allowed_actions = ["move", "basic_attack", "skill_1", "skill_2", "pause"]
		_show_current_step()
		return

	# If we just completed COMBAT_START, end the tutorial.
	if current_step == STEP_COMBAT_START:
		_finish_tutorial()
		return

	# Move to the next step.
	current_step += 1
	if current_step >= STEP_COUNT:
		_finish_tutorial()
		return

	_show_current_step()


## Skip the entire tutorial. Marks all steps completed, hides overlays,
## and immediately starts the battle. Skip button is visible from step 1
## onward (not on the WELCOME step).
func skip() -> void:
	if not is_active:
		return

	# Mark all steps as completed.
	for i in range(STEP_COUNT):
		_completed_steps[i] = true

	tutorial_skipped.emit()

	# Unlock all actions.
	_allowed_actions = ["move", "basic_attack", "skill_1", "skill_2", "pause"]

	_finish_tutorial()


## Returns true if the given action name is allowed by the tutorial's input
## gating. If the tutorial is not active, all actions are allowed.
func is_input_allowed(action: String) -> bool:
	if not is_active:
		return true
	return _allowed_actions.has(action)

# ---------------------------------------------------------------------------
# Public API — Overlay references
# ---------------------------------------------------------------------------

## Store a reference to the tutorial overlay CanvasLayer and cache its child
## controls. The overlay is expected to have the following structure:
##   CanvasLayer "TutorialOverlay"
##     ColorRect "Dim"          (full-screen dim, used for show/hide)
##     Panel "Panel"
##       Label "Title"
##       RichTextLabel "Body"
##       HBoxContainer "Buttons"
##         Button "Next"
##         Button "SkipTutorial"
##
## If the overlay is already set, this call is ignored (first-call-wins).
func set_overlay(node: CanvasLayer) -> void:
	if _tutorial_overlay != null:
		return

	_tutorial_overlay = node
	if _tutorial_overlay == null:
		return

	# Cache control references.
	_dim_rect = _tutorial_overlay.get_node_or_null("Dim") as ColorRect

	var panel: Panel = _tutorial_overlay.get_node_or_null("Panel") as Panel
	if panel == null:
		return

	_title_label = panel.get_node_or_null("Title") as Label
	_body_label = panel.get_node_or_null("Body") as RichTextLabel

	var buttons: HBoxContainer = panel.get_node_or_null("Buttons") as HBoxContainer
	if buttons != null:
		_next_button = buttons.get_node_or_null("Next") as Button
		_skip_button = buttons.get_node_or_null("SkipTutorial") as Button

	# Wire button signals.
	if _next_button != null:
		if not _next_button.pressed.is_connected(_on_next_pressed):
			_next_button.pressed.connect(_on_next_pressed)

	if _skip_button != null:
		if not _skip_button.pressed.is_connected(skip):
			_skip_button.pressed.connect(skip)

	# Start with overlay hidden.
	_hide_overlay_internal()


## Update the overlay panel's title and body text, then show it.
## This is the primary way to display tutorial content.
func show_overlay(title: String, body: String) -> void:
	if _title_label != null:
		_title_label.text = title
	if _body_label != null:
		_body_label.text = body

	# Re-apply bbcode.
	if _body_label != null:
		_body_label.text = body

	_show_overlay_internal()

# ---------------------------------------------------------------------------
# Internal — Overlay visibility
# ---------------------------------------------------------------------------

## Show the overlay (dim + panel). Also manages skip button visibility.
func _show_overlay_internal() -> void:
	if _tutorial_overlay == null:
		return

	_tutorial_overlay.visible = true

	# Skip button visible from step 1 onward (not on WELCOME step).
	if _skip_button != null:
		_skip_button.visible = (current_step > STEP_WELCOME)


## Hide the overlay entirely.
func _hide_overlay_internal() -> void:
	if _tutorial_overlay == null:
		return

	_tutorial_overlay.visible = false

# ---------------------------------------------------------------------------
# Internal — Step display
# ---------------------------------------------------------------------------

## Show the current step's overlay content and emit step_shown.
func _show_current_step() -> void:
	var title: String = _STEP_TITLES.get(current_step, "Tutorial")
	var body: String = _STEP_BODIES.get(current_step, "")
	show_overlay(title, body)
	step_shown.emit(current_step)


## Update _allowed_actions based on the last completed step.
func _update_allowed_actions() -> void:
	match current_step:
		STEP_WELCOME:
			# After WELCOME: no actions yet (MOVEMENT teaches move).
			pass
		STEP_MOVEMENT:
			_allowed_actions = ["move"]
		STEP_BASIC_ATTACK:
			_allowed_actions = ["move", "basic_attack"]
		STEP_SKILL_1:
			_allowed_actions = ["move", "basic_attack", "skill_1"]
		STEP_SKILL_2:
			_allowed_actions = ["move", "basic_attack", "skill_1", "skill_2"]
		STEP_PAUSE:
			_allowed_actions = ["move", "basic_attack", "skill_1", "skill_2", "pause"]
		STEP_COMBAT_START:
			_allowed_actions = ["move", "basic_attack", "skill_1", "skill_2", "pause"]

# ---------------------------------------------------------------------------
# Internal — Finish
# ---------------------------------------------------------------------------

## Finish the tutorial: hide overlay, deactivate, emit tutorial_finished,
## and call GameManager.start_battle().
func _finish_tutorial() -> void:
	_hide_overlay_internal()
	is_active = false
	tutorial_finished.emit()
	GameManager.start_battle()

# ---------------------------------------------------------------------------
# Input handling — ui_accept (Enter/Space) advances tutorial
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_accept"):
		# Consume the event to prevent propagation.
		get_viewport().set_input_as_handled()
		advance()

# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

## Called when the "Next" button is pressed.
func _on_next_pressed() -> void:
	advance()
