extends Camera2D
## CameraFollower — the camera owns visibility (2026-08-28 camera round).
##
## Attached to the existing `Camera` node in scenes/main.tscn and
## scenes/menu.tscn (node name / position / enabled / current unchanged).
## It replaces the sprite-level visibility clamp with a camera-level property:
## during a battle it follows the ACTING unit (player on the player turn, the
## acting enemy on the enemy turn — including mid-move, since we read the live
## `position`), and confines the camera to the board so the active unit always
## sits inside the unobstructed band between the HUD top strip and the action
## bar.
##
## Every number below is DERIVED from symbols — never a literal:
##   board  = GridManager.board_rect()   (today Rect2(0,0,960,704))
##   V      = get_viewport().get_visible_rect().size   (today (960,704))
##   T      = TopStrip.get_global_rect().end.y         (today 92)
##   B      = SkillBar.get_global_rect().position.y    (today 648)
##   cover_before = T            cover_after = V.y - B
##   cam_y_lo = board.y + V.y/2 - cover_before   (= 260 today)
##   cam_y_hi = board.y_end - V.y/2 + cover_after (= 408 today)
##   cam_x_lo = board.x + V.x/2                   (= 480 today, cover 0)
##   cam_x_hi = board.x_end - V.x/2               (= 480 today)
## Today cam_x is a single point and cam_y ∈ [260,408] — that is an EMERGENT
## property of board == viewport with zero side cover, never a hardcode.
## Changing GRID_HEIGHT 11 -> 20 changes only the substituted numbers, never
## this body.
##
## Degenerate branch: if cam_lo > cam_hi (board smaller than the viewport on
## that axis) the camera pins to the board centre instead of flinging to a
## corner (Godot's clampf with lo > hi returns lo, which would be wrong).
##
## Published surface (harness reads `Camera.<name>`): the 12 variables declared
## below. `active_unit_screen_y` maps the active unit's feet through the CANVAS
## transform (Coord.world_to_screen) — the camera-aware mapping, NOT final.
##
## Smoothing is disabled for determinism (frame-pinned playtest asserts must
## not race a pan); on battle entry and every turn/phase jump we snap the
## scroll so the canvas transform reflects the new position before any assert.

# ---------------------------------------------------------------------------
# Published surface (playtest/portrait_visibility rewrite + camera nails)
# ---------------------------------------------------------------------------

## Camera centre in world px this frame (== `position`, re-published).
var camera_position: Vector2 = Vector2.ZERO
## No-blank camera-range bounds (derived each frame from board + viewport + HUD).
var camera_x_lo: float = 0.0
var camera_x_hi: float = 0.0
var camera_y_lo: float = 0.0
var camera_y_hi: float = 0.0
## Unobstructed band edges (viewport-logical px): [hud_band_top, hud_band_bottom].
var hud_band_top: float = 0.0
var hud_band_bottom: float = 0.0
## Active unit's feet, screen y (canvas transform) and world y this frame.
var active_unit_screen_y: float = 0.0
var active_unit_world_y: float = 0.0
## Viewport half-height (read, never a literal: get_visible_rect().size.y / 2).
var viewport_half_y: float = 0.0
## Name of the follow target (== CombatManager.active_unit_name while following).
var follow_target_id: String = ""
## True when the camera is actually following the active unit this frame.
var follow_target_is_active: bool = false

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Lazily-resolved painted HUD leaves (their rects define the band).
var _top_strip: Control = null
var _skill_bar: Control = null
## True once signal wiring has run (idempotent guard for _ready / lazy path).
var _wired: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Determinism: a frame-pinned playtest assert must not race a smoothing pan.
	position_smoothing_enabled = false
	_resolve_hud_nodes()


func _resolve_hud_nodes() -> void:
	# HUD lives in a non-following CanvasLayer, so its rects are already in
	# viewport-logical px — exactly the space the band must be expressed in.
	# Defensive: the same shell shape exists in main.tscn and menu.tscn; if a
	# node is ever missing we fall back to cover 0 (full-board band).
	_top_strip = get_node_or_null("../HUDLayer/HUD/TopStrip") as Control
	_skill_bar = get_node_or_null("../HUDLayer/HUD/SkillBar") as Control

	if not GameManager.battle_started.is_connected(_on_battle_entry):
		GameManager.battle_started.connect(_on_battle_entry)
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
	if not CombatManager.turn_started.is_connected(_on_turn_started):
		CombatManager.turn_started.connect(_on_turn_started)
	if not CombatManager.phase_changed.is_connected(_on_phase_changed):
		CombatManager.phase_changed.connect(_on_phase_changed)
	_wired = true


## Snap the scroll so the canvas transform reflects the current position before
## any frame-pinned assert (battle entry and every turn/phase target jump).
func _snap() -> void:
	reset_smoothing()
	force_update_scroll()


func _on_battle_entry() -> void:
	_snap()


func _on_state_changed(_new_state: String) -> void:
	_snap()


func _on_turn_started(_unit: Node) -> void:
	_snap()


func _on_phase_changed(_phase: String) -> void:
	_snap()


func _process(_delta: float) -> void:
	if not _wired:
		_resolve_hud_nodes()

	var board: Rect2 = GridManager.board_rect()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = vp_size / 2.0
	viewport_half_y = vp_size.y / 2.0

	# --- HUD covers (viewport-logical px, from the painted leaves). ---
	var cover_before: float = 0.0
	var cover_after: float = 0.0
	if _top_strip != null and is_instance_valid(_top_strip):
		cover_before = _top_strip.get_global_rect().end.y
	if _skill_bar != null and is_instance_valid(_skill_bar):
		cover_after = vp_size.y - _skill_bar.get_global_rect().position.y
	hud_band_top = cover_before
	hud_band_bottom = vp_size.y - cover_after

	# --- No-blank camera range (derived from symbols). ---
	camera_x_lo = board.position.x + half.x
	camera_x_hi = board.end.x - half.x
	camera_y_lo = board.position.y + half.y - cover_before
	camera_y_hi = board.end.y - half.y + cover_after

	# --- Follow target: the acting unit, only while a battle is live. ---
	var following: bool = false
	var target: Node = CombatManager.get_active_unit()
	if GameManager.get_state() == GameManager.STATE_BATTLE \
			and target != null and is_instance_valid(target):
		following = true

	var desired: Vector2
	if following:
		var target2d: Node2D = target as Node2D
		var feet: Vector2 = target2d.position
		desired = Vector2(
			_clamp_axis(feet.x, camera_x_lo, camera_x_hi, board.get_center().x),
			_clamp_axis(feet.y, camera_y_lo, camera_y_hi, board.get_center().y))
		active_unit_world_y = feet.y
		active_unit_screen_y = Coord.world_to_screen(feet, get_viewport()).y
		follow_target_id = CombatManager.active_unit_name
		follow_target_is_active = (follow_target_id == CombatManager.active_unit_name)
	else:
		# Non-battle (menu / creation / segments) and null target: hold the
		# board centre. The follower only activates during STATE_BATTLE.
		desired = board.get_center()
		active_unit_world_y = 0.0
		active_unit_screen_y = 0.0
		follow_target_id = ""
		follow_target_is_active = false

	position = desired
	camera_position = position


## Per-axis no-blank clamp with the degenerate branch: when the no-blank range
## is empty (lo > hi, i.e. board < viewport on this axis) pin to the centre so
## the camera never flings to a corner.
func _clamp_axis(value: float, lo: float, hi: float, center: float) -> float:
	if lo > hi:
		return center
	return clampf(value, lo, hi)
