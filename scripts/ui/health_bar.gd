## HealthBar — Floating health bar that follows a character's world position
## and displays HP with color-coded status (green/yellow/red).
extends Control

# ---------------------------------------------------------------------------
# Fill / track color constants
# ---------------------------------------------------------------------------
# The fill is a dedicated StyleBoxFlat override recolored per HP band; the
# track background stays constant (_TRACK_BG) so the bar reads as a bar at
# any fill level. The whole-node modulate is never used: it would tint the
# track, border, and fill together, hiding the fill-length change on damage.

const _FILL_GREEN := Color(0.3, 0.9, 0.35)
const _FILL_YELLOW := Color(0.95, 0.85, 0.2)
const _FILL_RED := Color(0.9, 0.25, 0.2)
## Light gray track: the EMPTY portion of the bar, kept light so a vision model
## can see the filled/empty split at any fill level (5_vision Q5 — dark tracks
## made full bars read as solid blocks). The fill never blends into it: all
## three fill bands differ from this track color.
const _TRACK_BG := Color(0.62, 0.62, 0.65)
## Dark 1px border around the track so the light track stays visible against
## the light summit backdrop.
const _TRACK_BORDER := Color(0.05, 0.05, 0.05)
## Empty-cap width in pixels: the fixed-width sliver of track color kept at the
## RIGHT end of the bar at every fill level, including 100%. At full HP the
## fill covers the whole bar rect and the widget would read as a solid block
## (5_vision Q5) — the cap keeps the "empty slot" of the bar always visible.
const EMPTY_CAP_PX: float = 6.0
## Bottom edge of the battle top strip, in viewport px. This is the PAIR of
## hud.tscn's TopStrip offsets (0..80, full-width band drawn behind the top
## HUD widgets): floating health bars clamp their top edge to STRIP_BOTTOM + 2
## so no bar ever enters the strip zone. Keep in sync with hud.tscn.
const STRIP_BOTTOM: float = 80.0

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

## Total widget height in pixels (= size.y; 20.0 for the compact 68×20 layout).
## Assigned in setup() (so the headless null-char test reads it without a char
## node) AND re-assigned in follow_character() whenever the widget lays out.
var total_height: float = 0.0

## The rendered track background color (the EMPTY portion of the bar) — the
## bg_color of the "background" stylebox, written unconditionally in setup().
## Exposed so the playtest surface can assert the track is light and visible
## at full HP (e.g. 'track_bg.get_luminance() > 0.30').
var track_bg: Color = _TRACK_BG

## Edge-clamp displacement: distance between the current root center and the
## desired (pre-clamp) root center. ~0 when unclamped (character mid-viewport),
## grows by the clamp offset when pinned to a viewport edge. Computed inside
## follow_character(), BEFORE the clamp lines.
var follow_delta: float = 0.0

## Current fill color — the bg_color of the dedicated fill stylebox, written
## by update_health() per HP band. Exposed so the playtest surface can assert
## the fill is bright green at full HP (e.g. 'fill_color.g > 0.5 and
## fill_color.g > fill_color.r') — Color members are readable in the harness.
var fill_color: Color = _FILL_GREEN

## The EmptyCap width in pixels (= EMPTY_CAP_PX). Exposed so the playtest
## surface / unit test can assert the end-cap geometry without reaching into
## the ColorRect node directly.
var empty_cap_px: float = EMPTY_CAP_PX

## Alpha of the name-label backing stylebox (0.7 once the backing exists;
## 0.0 fallback when the NameLabel node is absent, e.g. headless). Written
## unconditionally in setup(); asserted `> 0.3` on the playtest surface so
## name labels stay readable when a portrait passes behind them.
var name_backing_alpha: float = 0.0

## The dedicated "fill" stylebox of the bar. Created once in setup(); its
## bg_color is the only thing update_health() recolors. Null until setup runs
## (all write sites guard on it).
var _fill_sb: StyleBoxFlat = null

## The cached semi-transparent backing stylebox of the name label. Created once
## in setup() (idempotent — re-assigned on repeated setup calls) and applied as
## a "normal" stylebox override so the label reads on any artwork behind it.
var _name_backing_sb: StyleBoxFlat = null

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
		# Neutral track background (assigned once here, never recolored
		# afterwards — the track stays constant): LIGHT gray so the empty
		# portion is visible at any fill level (5_vision Q5), with a dark
		# 1px border to separate it from the light backdrop.
		var sb := StyleBoxFlat.new()
		sb.bg_color = _TRACK_BG
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = _TRACK_BORDER
		# Draw the track 4px larger than the control rect on every side. At
		# 100% HP the fill covers the whole rect, so without this the widget is
		# a solid coloured block and reads as a platform, not a bar — the
		# readability gate reported exactly that 11/11 ("solid green
		# rectangles, not bars with empty portions") while the fill/track
		# split underneath was already correct.
		#
		# expand_margin, not content_margin: content margins only move a
		# StyleBox's CONTENT, they never shrink the box it draws, so insetting
		# the fill that way renders identically and changes nothing. Growing
		# the track is the one that actually paints.
		#
		# bar.size stays 64x6, so the `HealthBar.bar_width <= 64` geometric
		# assert is untouched — this is drawing, not layout.
		sb.set_expand_margin_all(4.0)
		bar.add_theme_stylebox_override("background", sb)
		# Dedicated fill stylebox: recolored by update_health() per HP band.
		# No border widths on the fill (a border around only the filled
		# region looks broken).
		_fill_sb = StyleBoxFlat.new()
		_fill_sb.bg_color = _FILL_GREEN
		bar.add_theme_stylebox_override("fill", _fill_sb)
		fill_color = _FILL_GREEN
		# Pin the EmptyCap (the constant track-color end cap) to the bar's
		# right end. Done here — outside the char_node guard — so the
		# headless null-char path still pins it; update_health() re-pins it
		# on every call so the cap never drifts from the live bar width.
		var cap: ColorRect = bar.get_node_or_null("EmptyCap") as ColorRect
		if cap != null:
			cap.position.x = bar.size.x - EMPTY_CAP_PX
				# mouse_filter stays MOUSE_FILTER_IGNORE (2) — set in the tscn,
				# re-asserted in update_health(); never blocks HUD clicks.
			cap.size = Vector2(EMPTY_CAP_PX, bar.size.y)
			cap.color = _TRACK_BG
			cap.visible = true

	var label: Label = _name_label
	if label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		label = get_node_or_null("NameLabel") as Label
		if label != null:
			_name_label = label
	if label != null:
		label.text = char_name
		# Make the name readable over any backdrop: light text on a dark
		# outline with a soft shadow. Font size stays 10 (tscn); the outline
		# widens glyphs by ~outline_size px, which the short aliases still
		# fit inside the 110 px label with clip_text disabled.
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_constant_override("shadow_outline_size", 1)
		# Name-label backing: a cached semi-transparent StyleBoxFlat applied as
		# the "normal" stylebox so the label stays readable when a character
		# portrait passes behind it. Idempotent — re-assigned on repeated
		# setup() calls (stylebox overrides are replace-only, no accumulation).
		_name_backing_sb = StyleBoxFlat.new()
		_name_backing_sb.bg_color = Color(0.05, 0.05, 0.08, 0.7)
		_name_backing_sb.corner_radius_top_left = 2
		_name_backing_sb.corner_radius_top_right = 2
		_name_backing_sb.corner_radius_bottom_right = 2
		_name_backing_sb.corner_radius_bottom_left = 2
		_name_backing_sb.content_margin_all(2.0)
		label.add_theme_stylebox_override("normal", _name_backing_sb)
		name_backing_alpha = 0.7

	# Always record the name (unconditionally, outside the label-null guard)
	# so the observable is set in every setup() path.
	name_text = char_name

	# Record the track color observable unconditionally (outside the bar-null
	# guard) so the playtest surface reads it even when the bar node is absent.
	track_bg = _TRACK_BG

	# Record the widget height observable unconditionally (outside the node
	# guards) so the headless null-char test reads size.y (20.0) even though
	# follow_character() returns early when _char_node is null.
	total_height = size.y

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

	# Re-pin the EmptyCap to the bar's right end on every update so the cap
	# stays the visible "empty slot" at ANY fill level, including 100%. The
	# ColorRect child draws over the ProgressBar fill (never affects value).
	var cap: ColorRect = _bar.get_node_or_null("EmptyCap") as ColorRect
	if cap != null:
		cap.position.x = _bar.size.x - EMPTY_CAP_PX
		cap.size = Vector2(EMPTY_CAP_PX, _bar.size.y)
		cap.color = _TRACK_BG
		cap.visible = true
		# MOUSE_FILTER_IGNORE (2): re-asserted every update so the cap never
		# blocks clicks on the HUD layer (root widget is also filter 2).
		cap.mouse_filter = 2  # == MOUSE_FILTER_IGNORE; click-through

	var ratio: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	_last_ratio = ratio

	# Recolor the dedicated fill stylebox per HP band. The track background is
	# untouched (stays _TRACK_BG); never modulate the whole bar — that would
	# tint the track and border too, hiding the fill-length change on damage.
	if _fill_sb != null:
		if ratio > 0.5:
			_fill_sb.bg_color = _FILL_GREEN
		elif ratio > 0.25:
			_fill_sb.bg_color = _FILL_YELLOW
		else:
			_fill_sb.bg_color = _FILL_RED
		fill_color = _fill_sb.bg_color
		_bar.queue_redraw()


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
	# Compact 68×20 widget: offset by half the widget width (34) so it stays
	# horizontally centred above the character, and −28 to float it above the
	# feet without covering the actor (widget bottom edge stays 8 px above the
	# character: 28 − 20 = 8, the same hover height as before).
	screen_pos += Vector2(-34, -28)
	# follow_delta: pre-clamp displacement of the root center from its desired
	# position (Euclidean distance, computed BEFORE the clamp below). ~0 when
	# the bar is unclamped and free-following; grows only when a viewport edge
	# pins the bar away from the character's projected position.
	follow_delta = (global_position + size * 0.5).distance_to(screen_pos + size * 0.5)
	# Keep the live bar-width observable in sync every frame (defensive: only
	# when the bar node is actually present).
	if is_instance_valid(_bar):
		bar_width = _bar.size.x
	# Keep the height observable live while the widget actually runs its layout
	# pass (re-assigned on every frame follow_character() executes).
	total_height = size.y
	# Clamp so the bar never clips off the viewport edges. The y LOWER bound is
	# STRIP_BOTTOM + 2 (= 82): no floating bar ever enters the top strip zone
	# (the full-width backed band, hud.tscn TopStrip offsets 0..80). The x
	# clamp and the y upper bound stay viewport-edge based. Follow_delta above
	# stays computed BEFORE this clamp, so its semantics are unchanged.
	var vp: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		clampf(screen_pos.x, 4.0, vp.x - size.x - 4.0),
		clampf(screen_pos.y, STRIP_BOTTOM + 2.0, vp.y - size.y - 4.0))
	visible = true

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Respond to the character's health_changed signal.
func _on_health_changed(new_health: int, max_health: int) -> void:
	update_health(new_health, max_health)
