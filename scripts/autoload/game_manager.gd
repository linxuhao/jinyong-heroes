## GameManager (autoload)
##
## Top-level game state machine. Owns win/lose conditions, scene references,
## and battle lifecycle. Runs as an autoload singleton.
##
## State machine: TUTORIAL -> BATTLE -> (WON | LOST)
## PAUSED is a sub-state of BATTLE managed by CombatManager.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the battle starts (transition TUTORIAL -> BATTLE).
signal battle_started()

## Emitted when all enemies are defeated (transition BATTLE -> WON).
signal game_won()

## Emitted when the player's health reaches zero (transition BATTLE -> LOST).
signal game_lost()

## Emitted on every state transition. Passes the new state name.
signal state_changed(new_state: String)

## Emitted when the player presses continue on the WON overlay (routes to the
## next segment). SceneManager connects here to perform the actual scene swap.
signal continue_requested()

## Emitted when the player presses retry on the LOST overlay (routes back to a
## fresh tutorial battle). SceneManager connects here to reload the battlefield.
signal retry_requested()

## Emitted by restart_game() after state_changed("TUTORIAL"). SceneManager
## (sibling task) connects here to reload a fresh battlefield for the restarted
## tutorial.
signal restart_requested()

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## State string constants. The playtest spec asserts these raw values verbatim
## (GameManager.current_state == "WON" etc.) — never rename them.
const STATE_TUTORIAL: String = "TUTORIAL"
const STATE_BATTLE: String = "BATTLE"
const STATE_WON: String = "WON"
const STATE_LOST: String = "LOST"
const STATE_TRANSITION: String = "TRANSITION"
const STATE_CHARACTER_CREATION: String = "CHARACTER_CREATION"
const STATE_SECT_SELECTION: String = "SECT_SELECTION"
const STATE_CULTIVATION: String = "CULTIVATION"
const STATE_MAP: String = "MAP"
const STATE_ENDING: String = "ENDING"

## enter_segment()'s validation domain: the six segment scenes only. The battle
## states (TUTORIAL/BATTLE/WON/LOST) are reached through their own entry points
## (start_battle / end_battle / request_retry / request_continue) and are
## deliberately excluded.
const SEGMENT_STATES: Array[String] = [
	STATE_TRANSITION, STATE_CHARACTER_CREATION, STATE_SECT_SELECTION,
	STATE_CULTIVATION, STATE_MAP, STATE_ENDING,
]

## Legal predecessor map for enter_segment() (design §4 table): each segment
## state lists the single state it may be entered from. Values reference the
## STATE_* constants so a rename cannot silently desync the table.
const SEGMENT_PREDECESSORS: Dictionary = {
	"TRANSITION": [STATE_WON],
	"CHARACTER_CREATION": [STATE_TRANSITION],
	"SECT_SELECTION": [STATE_CHARACTER_CREATION],
	"CULTIVATION": [STATE_SECT_SELECTION],
	"MAP": [STATE_CULTIVATION],
	"ENDING": [STATE_MAP],
}

## The current game state — one of the STATE_* constants above.
var current_state: String = STATE_TUTORIAL

## Array of living enemy nodes registered via register_enemy().
var enemies_alive: Array[Node] = []

## Reference to the player character Node, stored via set_player().
var _player: Node = null

## Reference to the end-game overlay CanvasLayer (guards against duplicates).
var _overlay_layer: CanvasLayer = null

## Battle context: where end_battle()'s WON/LOST route once the overlay is
## dismissed. "TUTORIAL" = the tutorial battle (WON -> TRANSITION, LOST ->
## retry); future encounter battles set it to "CULTIVATION" via
## set_battle_return_state(). This is the seam that makes WON/LOST transitions,
## not terminal states.
var battle_return_state: String = "TUTORIAL"

## Observable: the end-game overlay's rendered text, written unconditionally
## inside _show_end_game_overlay() whenever the overlay shows (WON -> text
## containing 胜利, LOST -> text containing 战败). Never contains the ellipsis
## character U+2026 "…" or "..." (repo-wide no-ellipsis rule for UI text) —
## asserted by test_game_manager_fsm and the playtest surface.
var end_overlay_text: String = ""

# ---------------------------------------------------------------------------
# Public API — State queries
# ---------------------------------------------------------------------------

## Returns the current game state string.
func get_state() -> String:
	return current_state

# ---------------------------------------------------------------------------
# Public API — State transitions
# ---------------------------------------------------------------------------

## Transition from TUTORIAL to BATTLE.
## No-op if the game is already in BATTLE, WON, or LOST state.
func start_battle() -> void:
	if current_state != "TUTORIAL":
		return

	current_state = "BATTLE"
	battle_started.emit()
	state_changed.emit("BATTLE")


## End the battle with a win or loss.
## Shows a centered overlay with victory or defeat text.
## No-op if the game is already in WON or LOST state.
func end_battle(won: bool) -> void:
	if current_state == "WON" or current_state == "LOST":
		return

	if won:
		current_state = "WON"
		game_won.emit()
		state_changed.emit("WON")
		_show_end_game_overlay("胜利！华山论剑的胜者！\n\n按回车继续")
	else:
		current_state = "LOST"
		game_lost.emit()
		state_changed.emit("LOST")
		_show_end_game_overlay("败于华山论剑\n\n按回车重试")

# ---------------------------------------------------------------------------
# Public API — Battle context & WON/LOST routing (combat_cleanup)
# ---------------------------------------------------------------------------

## Set where the current battle's WON/LOST should route once dismissed.
func set_battle_return_state(s: String) -> void:
	battle_return_state = s


## The current battle's return-state context (see battle_return_state).
func get_battle_return_state() -> String:
	return battle_return_state


## Drop every per-battle reference owned by this autoload so a scene swap never
## touches freed nodes: clears the enemy registry, releases the player slot
## (set_player is first-call-wins — a stale _player would silently swallow the
## next battle's player), and frees the end-game overlay.
func clear_battle() -> void:
	enemies_alive.clear()
	_player = null
	if _overlay_layer != null:
		_overlay_layer.queue_free()
		_overlay_layer = null


## WON overlay continue: route to the next segment and notify listeners.
## Destination is battle_return_state when it is a segment state (future
## encounter battles route WON back to CULTIVATION); the tutorial battle keeps
## battle_return_state == "TUTORIAL" (not a segment), which falls back to the
## fixed next segment TRANSITION. No-op unless the game is in WON.
func request_continue() -> void:
	if current_state != STATE_WON:
		return
	var target: String = battle_return_state if SEGMENT_STATES.has(battle_return_state) else STATE_TRANSITION
	current_state = target
	state_changed.emit(target)
	continue_requested.emit()


## LOST overlay retry: clear battle refs, route back to the tutorial, and
## notify listeners (SceneManager reloads a fresh battlefield). No-op unless
## the game is in LOST.
func request_retry() -> void:
	if current_state != "LOST":
		return
	clear_battle()
	current_state = "TUTORIAL"
	state_changed.emit("TUTORIAL")
	retry_requested.emit()


## Validated single-transition helper used by segment scenes (design §4 table).
## Returns true and emits state_changed(state) only when `state` is a segment
## state and current_state is its legal predecessor; any other target
## (non-segment, self, or out-of-order) returns false with no effect.
func enter_segment(state: String) -> bool:
	if not SEGMENT_STATES.has(state):
		return false
	var allowed: Variant = SEGMENT_PREDECESSORS.get(state, null)
	if not (allowed is Array) or not (allowed as Array).has(current_state):
		return false
	current_state = state
	state_changed.emit(state)
	return true


## Restart from ENDING (or anywhere): drop every battle reference, reset
## SaveManager to a fresh default profile, then route to a truly-fresh TUTORIAL.
## new_profile() alone marks tutorial_done = true (creation is only reachable
## after the tutorial), so a full restart clears that flag back to false.
## Emits state_changed("TUTORIAL") BEFORE restart_requested() so SceneManager
## routes the scene first, then reloads a fresh battlefield.
func restart_game() -> void:
	clear_battle()
	SaveManager.new_profile({}, [])
	SaveManager.profile.flags["tutorial_done"] = false
	current_state = STATE_TUTORIAL
	state_changed.emit(STATE_TUTORIAL)
	restart_requested.emit()

# ---------------------------------------------------------------------------
# Public API — Enemy tracking
# ---------------------------------------------------------------------------

## Register a living enemy node. Silently ignores duplicate registrations.
func register_enemy(node: Node) -> void:
	if node == null:
		return
	if enemies_alive.has(node):
		return
	enemies_alive.append(node)


## Unregister an enemy node (called on death).
## If all enemies are defeated while in BATTLE state, automatically triggers
## end_battle(true). Does NOT trigger a win during TUTORIAL state.
func unregister_enemy(node: Node) -> void:
	var idx: int = enemies_alive.find(node)
	if idx == -1:
		return

	enemies_alive.remove_at(idx)

	# Auto-win only during active battle.
	if current_state == "BATTLE" and enemies_alive.is_empty():
		end_battle(true)


## Returns a defensive copy of the living-enemies array.
func get_enemies_alive() -> Array[Node]:
	return enemies_alive.duplicate()

# ---------------------------------------------------------------------------
# Public API — Player reference
# ---------------------------------------------------------------------------

## Store a reference to the player character. First-call-wins — subsequent
## calls are silently ignored, preventing accidental overwrites.
func set_player(node: Node) -> void:
	if _player != null:
		return
	_player = node


## Returns the stored player reference, or null if not yet set.
func get_player() -> Node:
	return _player

# ---------------------------------------------------------------------------
# Private helpers — End-game overlay
# ---------------------------------------------------------------------------

## Creates and shows a centered victory/defeat overlay.
## Uses a CanvasLayer so it renders above all game content.
## Guarded against duplicate overlays.
func _show_end_game_overlay(text: String) -> void:
	# Observable: always record the rendered text (outside the overlay-null
	# guard) so the playtest surface reads it in every show path.
	end_overlay_text = text
	if _overlay_layer != null:
		# Overlay already exists — just update the text.
		# Safe: get_node_or_null re-resolves the path each call and returns
		# null for freed nodes — no freed-object cast can occur.
		var existing_label: Label = _overlay_layer.get_node_or_null("Panel/Label")
		if existing_label != null:
			existing_label.text = text
		return

	# Create CanvasLayer at a high layer (above HUD, below tutorial).
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "EndGameOverlay"
	_overlay_layer.layer = 50
	add_child(_overlay_layer)

	# Dimming overlay — semi-transparent black.
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks through.
	_overlay_layer.add_child(dim)

	# Centered panel.
	var panel: Panel = Panel.new()
	panel.name = "Panel"
	panel.size = Vector2(500, 250)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Style the panel.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

	_overlay_layer.add_child(panel)

	# Label.
	var label: Label = Label.new()
	label.name = "Label"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.add_theme_font_size_override("font_size", 28)
	panel.add_child(label)

# ---------------------------------------------------------------------------
# Input — WON/LOST continue/retry + DEBUG hooks
# ---------------------------------------------------------------------------

## WON/LOST keyboard routing: ui_accept / tutorial_next dismiss the overlay.
## Lives in _unhandled_input (NOT on the overlay) so headless playtest key
## presses drive the routing: the overlay dim is a plain ColorRect with no
## focusable controls, so keyboard events reach _unhandled_input untouched.
func _unhandled_input(event: InputEvent) -> void:
	if current_state == "WON":
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
			get_viewport().set_input_as_handled()
			request_continue()
	elif current_state == "LOST":
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
			get_viewport().set_input_as_handled()
			request_retry()


## Consume the unbound DEBUG actions (harness-only; empty event lists in
## project.godot, triggerable via Input.action_press). Both route through the
## real battle pipeline via CombatManager so WON/LOST behave exactly like
## normal play (debug_win_tutorial -> wipe enemies -> end_battle(true);
## debug_lose_tutorial -> kill player -> end_battle(false)).
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_win_tutorial"):
		CombatManager.debug_wipe_enemies()
	if Input.is_action_just_pressed("debug_lose_tutorial"):
		CombatManager.debug_kill_player()
