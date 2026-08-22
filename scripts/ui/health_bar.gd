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

## The character display name shown on the label. Always set by setup(),
## even if the label node is missing, so it is safe to assert on.
var name_text: String = ""

## Bar width in pixels (= Bar.size.x). Refreshed in setup() and every frame
## from follow_character() so the geometric "<= 64 px (one cell)" assertion
## reads the live layout.
var bar_width: float = 0.0

## Edge-clamp displacement: distance between the current root center and the
## desired (pre-clamp) root center. ~0 when unclamped (character mid-viewport),
## grows by the clamp offset when pinned to a viewport edge. Computed inside
## follow_character(), BEFORE the clamp lines.
var follow_delta: float = 0.0

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

	# Defensively resolve the child nodes so setup() is call-order independent:
	# when setup() runs BEFORE add_child(), the @onready members are still null,
	# so fall back to get_node_or_null and write the resolved refs BACK to the
	# members (update_health()/follow_character() rely on them).
	var bar: ProgressBar = _bar
	if bar == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		bar = get_node_or_null("Bar") as ProgressBar
		if bar != null:
			_bar = bar
	if bar != null:
		bar.max_value = max_hp
		bar.value = max_hp
		bar_width = bar.size.x
		# Dark-red background stylebox so the bar reads as a health bar even at
		# low fill; the 1px dark border keeps it visible against the backdrop.
		# Fill color stays driven by the existing green/yellow/red modulate
		# logic in update_health() — no fill stylebox override.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.35, 0.05, 0.05)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.05, 0.05, 0.05)
		bar.add_theme_stylebox_override("background", sb)

	var label: Label = _name_label
	if label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		label = get_node_or_null("NameLabel") as Label
		if label != null:
			_name_label = label
	if label != null:
		label.text = char_name

	# Always record the name (unconditionally, outside the label-null guard)
	# so the observable is set in every setup() path.
	name_text = char_name

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

	# get_final_transform() composes the viewport's global (stretch) transform
	# with the canvas (camera) transform, mapping the character's world position
	# into the window-pixel space where this non-following-layer Control lives.
	# At the default scale-1 window it is numerically identical to the old
	# camera.get_canvas_transform(), so existing assertions stay valid.
	var screen_pos: Vector2 = get_viewport().get_final_transform() * _char_node.global_position
	screen_pos += Vector2(-60, -50)
	# follow_delta: pre-clamp displacement of the root center from its desired
	# position (Euclidean distance, computed BEFORE the clamp below). ~0 when
	# the bar is unclamped and free-following; grows only when a viewport edge
	# pins the bar away from the character's projected position.
	follow_delta = (global_position + size * 0.5).distance_to(screen_pos + size * 0.5)
	# Keep the live bar-width observable in sync every frame (defensive: only
	# when the bar node is actually present).
	if is_instance_valid(_bar):
		bar_width = _bar.size.x
	# Clamp so the bar never clips off the viewport edges.
	var vp: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		clampf(screen_pos.x, 4.0, vp.x - size.x - 4.0),
		clampf(screen_pos.y, 4.0, vp.y - size.y - 4.0))
	visible = true

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Respond to the character's health_changed signal.
func _on_health_changed(new_health: int, max_health: int) -> void:
	update_health(new_health, max_health)
