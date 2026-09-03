## TutorialManager (autoload)
##
## Step-by-step tutorial overlay system with input gating. Manages 7 tutorial
## steps that teach the player movement, basic attacks, skills, end turn, and
## pause. Once the tutorial completes (or is skipped), calls
## GameManager.start_battle(). Advances on ui_accept (Enter/Space) or
## tutorial_next (Enter) for automated headless playtest.
extends Node

# ---------------------------------------------------------------------------
# Step constants
# ---------------------------------------------------------------------------

const STEP_WELCOME: int = 0
const STEP_MOVEMENT: int = 1
const STEP_ATTACK: int = 2
const STEP_SKILLS: int = 3
const STEP_END_TURN: int = 4
const STEP_PAUSE: int = 5
const STEP_COMBAT_START: int = 6
const STEP_COUNT: int = 7

## Every action that can be gated. Skip and the all-enemies-dead fast-forward
## unlock the full list (the player controller still enforces the round-4
## two-phase palm-art unlock for skill_5..skill_8).
const _ALL_ACTIONS: Array[String] = [
	"move", "attack_confirm",
	"skill_1", "skill_2", "skill_3", "skill_4",
	"skill_5", "skill_6", "skill_7", "skill_8",
	"end_turn", "pause",
]

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
	STEP_WELCOME: "华山论剑",
	STEP_MOVEMENT: "移动",
	STEP_ATTACK: "普通攻击",
	STEP_SKILLS: "招式",
	STEP_END_TURN: "结束回合",
	STEP_PAUSE: "暂停",
	STEP_COMBAT_START: "战斗开始！",
}

## Body strings (with BBCode) keyed by step id.
const _STEP_BODIES: Dictionary = {
	STEP_WELCOME: (
		"你是独臂大虾。击败五大高手，夺得华山论剑的胜者！\n\n"
		+ "按「继续」或回车继续。"
	),
	STEP_MOVEMENT: (
		"WASD/方向键每次移动一格。每回合有 4 点移动力。\n\n"
		+ "现在就试试移动吧！"
	),
	STEP_ATTACK: (
		"移动到敌人身边，按 J（或鼠标左键）进行普通攻击。"
	),
	STEP_SKILLS: (
		"按 1-4 选择重剑剑法招式，再按 J 对射程内最近的敌人施展。"
		+ "招式 5-8（黯然销魂掌）将在第 4 回合解锁。\n\n"
		+ "每个按钮都会显示它的发挥度（例如 发挥 ×1.3）。"
	),
	STEP_END_TURN: (
		"按空格结束回合。结束回合后，敌人会按出手顺序依次行动。"
	),
	STEP_PAUSE: (
		"按 Esc 暂停/继续游戏。"
	),
	STEP_COMBAT_START: (
		"教学完成。击败五大高手！\n\n"
		+ "按「继续」开始战斗。"
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
		_allowed_actions = _ALL_ACTIONS.duplicate()
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
	_allowed_actions = _ALL_ACTIONS.duplicate()

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

	# Safe: every child lookup below uses get_node_or_null, which re-resolves
	# the path each call and returns null for freed nodes — never a
	# freed-object cast.
	_title_label = panel.get_node_or_null("Title") as Label
	_body_label = panel.get_node_or_null("Body") as RichTextLabel

	var buttons: HBoxContainer = panel.get_node_or_null("Buttons") as HBoxContainer
	if buttons != null:
		# Safe: get_node_or_null re-resolves; null for freed nodes.
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
	# tr(): the Label auto-translates whole titles anyway, but RichTextLabel
	# body text is translated explicitly here so the EN locale never depends
	# on RichTextLabel's auto-translate behavior. zh (and headless) is a
	# byte-identical no-op — the zh string is its own key.
	if _title_label != null:
		_title_label.text = tr(title)
	if _body_label != null:
		_body_label.text = tr(body)

	# Re-apply bbcode.
	if _body_label != null:
		_body_label.text = tr(body)

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
		STEP_ATTACK:
			_allowed_actions = ["move", "attack_confirm"]
		STEP_SKILLS:
			_allowed_actions = ["move", "attack_confirm", "skill_1", "skill_2", "skill_3", "skill_4"]
		STEP_END_TURN:
			_allowed_actions = ["move", "attack_confirm", "skill_1", "skill_2", "skill_3", "skill_4", "end_turn"]
		STEP_PAUSE:
			_allowed_actions = ["move", "attack_confirm", "skill_1", "skill_2", "skill_3", "skill_4", "end_turn", "pause"]
		STEP_COMBAT_START:
			_allowed_actions = ["move", "attack_confirm", "skill_1", "skill_2", "skill_3", "skill_4", "end_turn", "pause"]

# ---------------------------------------------------------------------------
# Internal — Finish
# ---------------------------------------------------------------------------

## Finish the tutorial: hide overlay, deactivate, mark the tutorial as done
## on the profile (D3 flag flip — creation now happens before the tutorial,
## so tutorial completion is where tutorial_done becomes true), emit
## tutorial_finished, and call GameManager.start_battle().
func _finish_tutorial() -> void:
	_hide_overlay_internal()
	is_active = false
	SaveManager.profile.flags["tutorial_done"] = true
	tutorial_finished.emit()
	GameManager.start_battle()

# ---------------------------------------------------------------------------
# Input handling — ui_accept / tutorial_next advance the tutorial
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
		# Consume the event to prevent propagation.
		get_viewport().set_input_as_handled()
		advance()

# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

## Called when the "Next" button is pressed.
func _on_next_pressed() -> void:
	advance()
