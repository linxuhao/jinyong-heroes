## HealthBar — Floating health bar that follows a character's world position
## and displays HP with color-coded status (green/yellow/red).
extends Control

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The character node this health bar follows.
var _char_node: Node = null

## Cached ratio for color blending.
var _last_ratio: float = 1.0

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _bar: ProgressBar = $Bar
@onready var _name_label: Label = $NameLabel

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise the health bar with character info and connect signals.
## char_node must have a `health_changed` signal and `health`/`max_health`
## properties.
func setup(char_name: String, max_hp: int, char_node: Node) -> void:
	_char_node = char_node

	if is_instance_valid(_name_label):
		_name_label.text = char_name

	if is_instance_valid(_bar):
		_bar.max_value = max_hp
		_bar.value = max_hp

	# Connect to the character's health_changed signal.
	if char_node != null and is_instance_valid(char_node):
		if char_node.has_signal("health_changed"):
			char_node.health_changed.connect(_on_health_changed)


## Update the bar's value and color based on current/max HP.
## Called automatically via the health_changed signal.
func update_health(current: int, max_hp: int) -> void:
	if not is_instance_valid(_bar):
		return

	_bar.value = current

	var ratio: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	_last_ratio = ratio

	if ratio > 0.5:
		_bar.modulate = Color(0.2, 0.8, 0.2)   # green
	elif ratio > 0.25:
		_bar.modulate = Color(0.8, 0.8, 0.2)   # yellow
	else:
		_bar.modulate = Color(0.8, 0.2, 0.2)   # red


## Called every frame from HUD._process(). Follows the character's world
## position, converting to screen coordinates. Hides bar when character
## is dead or invalid.
func follow_character() -> void:
	if not is_instance_valid(_char_node):
		visible = false
		return

	# Hide if character is dead.
	if "health" in _char_node and _char_node.health <= 0:
		visible = false
		return

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var screen_pos: Vector2 = camera.get_canvas_transform() * _char_node.global_position
	global_position = screen_pos + Vector2(-60, -50)
	visible = true

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Respond to the character's health_changed signal.
func _on_health_changed(new_health: int, max_health: int) -> void:
	update_health(new_health, max_health)
