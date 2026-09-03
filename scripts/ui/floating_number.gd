extends CanvasLayer
## FloatingNumber — R4 enemy-action-feedback presentation component.
##
## Hosts the two transient FX the owner's playtest #5 asked for:
##   * a floating damage number spawned at the struck unit on every landed hit;
##   * a pulsing "acting unit" marker shown for the DURATION of each enemy turn,
##     so the 2-33 s enemy turn never reads as a hang.
##
## PRESENTATION ONLY — no combat/damage/AI/turn-order read or write. The
## CombatManager hooks hand these finished display strings/positions; this
## component never calls back into combat logic. The strings use the R4 shrimp
## nicknames (resolved upstream from unit.character_data.display_name); this file
## renders whatever text it is given and never touches an internal character_name.
##
## WALL-CLOCK, NEVER FRAME-COUNTED (Card 0's web lesson): every fade/pulse uses
## create_tween() (SceneTree Tween, wall-clock). There is deliberately NO
## `await get_tree().process_frame` counting wait anywhere here — a frame-counted
## wait scales with web fps and would stretch these FX on the low-fps WebGL build.
##
## LAYOUT / OCCLUSION: like CombatLog it lives on its OWN CanvasLayer, so it is
## structurally out of UiOcclusionWatch's button-over-text scope (cross-layer
## pairs are skipped). The transient Labels also sit at unit positions on the
## board, away from the fixed HUD buttons; each self-removes via queue_free once
## its Tween finishes. mouse_filter is IGNORE on every spawned node.
##
## Nodes are built in code (no scene $ path) so the .tscn stays a bare host and
## the script is self-contained.

## Wall-clock timings (seconds). Kept short so no frame stays visually static.
const _FLOAT_RISE_SEC: float = 0.6
const _FLOAT_FADE_SEC: float = 0.4
const _MARKER_PULSE_SEC: float = 0.5

var _marker: Control = null
var _marker_target: Node = null


func _ready() -> void:
	layer = 101


## Spawn a short floating number (e.g. "-12") at a target unit's screen position.
## target is a Node2D on the board; the fade is wall-clock and it frees itself.
func spawn_number(target: Node, text: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	var base: Vector2 = _screen_pos_of(target) - label.get_combined_minimum_size() * 0.5
	label.position = base
	# Wall-clock rise + fade, then self-free. One Tween, chained sequentially.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", base.y - 28.0, _FLOAT_RISE_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, _FLOAT_FADE_SEC) \
		.set_delay(_FLOAT_RISE_SEC * 0.5)
	tw.chain().tween_callback(label.queue_free)


## Show the pulsing acting-unit marker at `unit` for the duration of its turn.
## Re-pointing at a new unit moves the existing marker instead of stacking.
func show_marker(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if _marker == null or not is_instance_valid(_marker):
		_marker = _build_marker()
		add_child(_marker)
	_marker_target = unit
	_move_marker_to_target()
	_start_marker_pulse()


## Remove the acting-unit marker (called at the end of each enemy turn).
func hide_marker() -> void:
	_marker_target = null
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


## Keep the marker glued to its (possibly tween-moving) target while visible.
func _process(_delta: float) -> void:
	if _marker != null and is_instance_valid(_marker) \
			and _marker_target != null and is_instance_valid(_marker_target):
		_move_marker_to_target()


func _build_marker() -> Control:
	var label := Label.new()
	label.name = "ActingMarker"
	label.text = "…"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _move_marker_to_target() -> void:
	if _marker == null or _marker_target == null:
		return
	var center: Vector2 = _screen_pos_of(_marker_target)
	_marker.position = center - _marker.get_combined_minimum_size() * 0.5 \
		+ Vector2(0.0, -26.0)


## A looping pulse so the marker is visibly in motion the whole enemy turn — the
## presentation guarantee behind the owner's "no frame stays static > 1 s".
## The pulsing property (modulate:a) is tween-driven; the marker's own lifetime
## is bounded by hide_marker(), NOT a frame count.
func _start_marker_pulse() -> void:
	if _marker == null or not is_instance_valid(_marker):
		return
	# Kill any prior pulse Tween so re-pointing doesn't stack pulse loops.
	_marker.modulate.a = 1.0
	var tw := _marker.create_tween()
	tw.set_loops()
	tw.tween_property(_marker, "modulate:a", 0.35, _MARKER_PULSE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_marker, "modulate:a", 1.0, _MARKER_PULSE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## world -> screen for a Node2D on the board, via the root viewport's canvas
## transform (which carries the Camera2D). Falls back to the unit's own position
## when the node is not a Node2D (never crashes on a non-2D target).
func _screen_pos_of(node: Node) -> Vector2:
	var world: Vector2 = Vector2.ZERO
	if node is Node2D:
		world = (node as Node2D).global_position
	elif "position" in node:
		world = node.position
	var viewport := get_viewport()
	if viewport == null:
		return world
	return viewport.get_canvas_transform() * world
