extends Control
## CARD 0b — ACTING-UNIT MARKER (scenes/ui/acting_unit_marker.tscn root script).
##
## A self-driving poller (move_hint_label.gd precedent): every frame it resolves
## CombatManager.get_active_unit() fresh (never stores the ref), repositions a
## drawn pulse ring at the unit's foot anchor, and mirrors visibility/name back
## into CombatManager.acting_marker_visible / acting_marker_unit_name.
## Deliberately DISTINCT from tile_markers.gd's idle dark-gold ellipse: this is
## a bright cyan/white double ring with a wall-clock pulse. Carries NO text, so
## UiOcclusionWatch stays violations == 0 / scan_ok == true. MOUSE_FILTER_IGNORE
## — the ring is never an interaction surface and eats no board clicks.

## Ring colors — bright cyan core + white halo, clearly distinct from the
## tile_markers dark-gold (MARKER_FILL / MARKER_EDGE) idle ellipse.
const RING_CORE := Color(0.35, 0.95, 1.0, 0.9)
const RING_HALO := Color(1.0, 1.0, 1.0, 0.95)
const RING_RADIUS: float = 26.0
const PULSE_SPEED: float = 6.0
const MARKER_SIZE: float = 64.0

var _pulse_t: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MARKER_SIZE, MARKER_SIZE)
	size = Vector2(MARKER_SIZE, MARKER_SIZE)
	visible = false


func _process(delta: float) -> void:
	_pulse_t += delta
	var unit: Node = CombatManager.get_active_unit()
	if unit == null or not is_instance_valid(unit) or not (unit is Node2D):
		visible = false
		CombatManager.acting_marker_visible = false
		CombatManager.acting_marker_unit_name = ""
		return
	# floating_number.gd _screen_pos_of precedent: canvas-transform the unit's
	# live world position (it tracks the unit even mid-move tween).
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() \
			* (unit as Node2D).global_position
	position = screen_pos - size * 0.5
	visible = true
	CombatManager.acting_marker_visible = true
	CombatManager.acting_marker_unit_name = CombatManager._name_of(unit)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_pulse_t * PULSE_SPEED)
	var r: float = RING_RADIUS + 4.0 * pulse
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, RING_CORE, 3.0, true)
	draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 48,
			Color(RING_HALO, 0.3 + 0.5 * pulse), 1.5, true)
