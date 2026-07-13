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

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The current game state. One of "TUTORIAL", "BATTLE", "WON", "LOST".
var current_state: String = "TUTORIAL"

## Array of living enemy nodes registered via register_enemy().
var enemies_alive: Array[Node] = []

## Reference to the player character Node, stored via set_player().
var _player: Node = null

## Reference to the end-game overlay CanvasLayer (guards against duplicates).
var _overlay_layer: CanvasLayer = null

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
		_show_end_game_overlay("Victory! 华山论剑 Champion!")
	else:
		current_state = "LOST"
		game_lost.emit()
		state_changed.emit("LOST")
		_show_end_game_overlay("Defeat…")

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
	if _overlay_layer != null:
		# Overlay already exists — just update the text.
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
