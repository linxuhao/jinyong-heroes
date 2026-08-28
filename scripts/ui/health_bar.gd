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
## Dark gray track: the EMPTY portion of the bar. The 2026-08-25 darkening
## decision — the earlier light track (0.62) sat too close in luminance to the
## green fill to register as an "empty portion" at 960x704 (5_vision Q5), and
## the still-earlier dark-track failure (full bars read as solid blocks)
## predated the wide empty cap. With a 14 px cap the dark slot is a strong
## fill-vs-empty contrast (track luminance ~0.35 vs green fill ~0.73). The fill
## never blends into it: all three fill bands differ from this track color.
const _TRACK_BG := Color(0.35, 0.35, 0.38)
## Dark 1px border around the track so the light track stays visible against
## the light summit backdrop.
const _TRACK_BORDER := Color(0.05, 0.05, 0.05)
## Empty-cap width in pixels: the fixed-width sliver of track color kept at the
## RIGHT end of the bar at every fill level, including 100%. At full HP the
## fill covers the whole bar rect and the widget would read as a solid block
## (5_vision Q5) — the cap keeps the "empty slot" of the bar always visible.
##
## THE COST, stated because the gain alone is not the whole truth: the cap is
## drawn OVER the fill, so it hides the last 14 of the bar's 64 px at every
## level. A full bar reads as roughly 78%, and everything from ~78% to 100%
## looks identical. Measured on a real 960x704 frame: 50 px of green then 14 px
## of track at full HP.
##
## Accepted anyway, for two reasons: every bar carries the same cap, so
## comparing two units is unaffected; and the band it flattens (~78-100%) is the
## one where the exact number matters least — the HP-gated skills open below
## 50%. If that ever stops being true, shrink the cap rather than widen it, and
## re-measure at 1x instead of zooming in (the 2026-08-25 lesson: a readability
## claim verified from a 4x crop is not a readability claim).
const EMPTY_CAP_PX: float = 14.0
## Bottom edge of the battle top strip, in viewport px. This is the PAIR of
## hud.tscn's TopStrip offsets (0..92, full-width band drawn behind the top
## HUD widgets): floating health bars clamp their top edge to STRIP_BOTTOM + 2
## so no bar ever enters the strip zone. Keep in sync with hud.tscn.
const STRIP_BOTTOM: float = 92.0

## Authored child-height floors (health_bar.tscn): Bar 12, NameLabel 9. These
## are FLOORS, never the root-height source — _relayout_children() sets each
## child to max(floor, measured combined minimum) and the root height to the
## measured children sum.
const _BAR_FLOOR_Y: float = 12.0
const _NAME_LABEL_FLOOR_Y: float = 9.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The character node this health bar follows.
var _char_node: Node = null

## Cached ratio for color blending.
var _last_ratio: float = 1.0

## Screen-space top edge of the widget this frame (== global_position.y after
## the clamp). Published in follow_character() after the clamp assigns
## global_position; retains its previous-frame value on the early-return paths.
var bar_top: float = 0.0

## Screen-space bottom edge of the widget this frame (== global_position.y +
## size.y). Published in follow_character() after the clamp; retains its
## previous-frame value on the early-return paths.
var bar_bottom: float = 0.0

## World y of this frame's follow anchor point (the widget's PRE-clamp desired
## anchor in WORLD px, before any viewport clamp). Which branch produced it:
## above-portrait = sprite_top - 4 - size.y; flipped = ink_bottom + 4; legacy
## feet = char.global_position.y - 32. Retains its previous-frame value on the
## early-return paths (same semantics as bar_top/bar_bottom).
var health_bar_world_y: float = 0.0

## Screen y of that same anchor after Coord.world_to_screen (canvas transform,
## camera-aware) — the pre-clamp projected position of the widget's anchor.
## The camera nail pin asserts the clamp-independent invariant
##   health_bar_screen_y - health_bar_world_y == viewport_half_y - camera_position.y
## which holds only under the canvas (camera) transform; under the final
## transform (no camera) the left side is 0 and the pin turns red. Retains its
## previous-frame value on the early-return paths.
var health_bar_screen_y: float = 0.0

## True when the widget is anchored by the portrait-TOP rule: the unclamped
## desired widget bottom == sprite_top - 4 (the above-portrait anchor path ran).
## False on two paths: the legacy feet fallback (a character node without a
## sprite_top property) and the FLIPPED path below (a top-band unit whose
## above-portrait anchor would land inside the top strip gets its widget top
## anchored 4 px below the portrait ink bottom instead — the above-anchor rule
## did NOT run, so this flag is false there).
var bar_anchors_sprite_top: bool = false

## True when this bar took the FLIPPED side of the portrait for this frame:
## the widget TOP is anchored 4 px below the portrait ink bottom (used for
## top-band units, e.g. Central_Divine at (7,1), whose above-portrait anchor
## would land inside the top strip floor STRIP_BOTTOM + 2 == 94 and pull the
## bar back over the portrait's upper ink).
## False = the normal "widget bottom 4 px above sprite_top" anchoring. Published
## every frame in follow_character() and whitelisted on the HealthBar playtest
## surface, so the flip side a unit actually got is assertable (never inferred
## from a hardcoded bar_top literal).
var bar_anchors_below_portrait: bool = false


## even if the label node is missing, so it is safe to assert on.
var name_text: String = ""

## Bar width in pixels (= Bar.size.x). Refreshed in setup() and every frame
## from follow_character() so the geometric "<= 64 px (one cell)" assertion
## reads the live layout.
var bar_width: float = 0.0

## Bar height in pixels (= Bar.size.y). 12.0 after this round.
var bar_height: float = 0.0

## Visible empty-slot area at the right end (EMPTY_CAP_PX × bar_height).
## The area argument behind Q5: 48 px² was invisible at native size;
## >= 120 px² is not.
var empty_area_px: float = 0.0

## Total widget height in pixels (= size.y; 24.0 for the compact 68×24 layout).
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

## The rendered HP number — the CURRENT value only (e.g. "400"), never "cur/max".
## Route (a) of the readability rework: a 64px bar cannot render the 9-glyph
## "1000/1000" legibly (strokes stick together at 7-8px), so only the current
## value is drawn; max_health stays discoverable via the hp_max observable.
## Written to max in setup() and rewritten on every update_health() so it stays
## live on damage. Exposed for the playtest surface so health asserts can be
## expressed relative to max_health (never an absolute HP literal).
var hp_text: String = ""

## The live current-HP integer mirror (== the `current` argument of the most
## recent update_health() call; max/max after setup()).
var hp_value: int = 0

## The live max-HP integer mirror (== the `max_hp` argument of the most recent
## update_health() call).
var hp_max: int = 0

## True when the MEASURED rendered ink width of the HpLabel text fits within the
## Bar width (64 px), so the current-value string never overflows the bar on
## either side. Recomputed at the end of setup() and update_health() (right
## after hp_text is written) via _hp_rendered_width() against the live bar width.
## Whitelisted on the playtest surface and asserted in ui_geometry_readability.yaml
## (hp_text_width_ok == true) — recomputed against the real rendered width so it
## is true only when the number actually fits its 64px host.
var hp_text_width_ok: bool = false

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _bar: ProgressBar = $Bar
@onready var _name_label: Label = $NameLabel

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Render the HP number as the CURRENT value only (e.g. "400", "1000"). Route (a)
## of the HP readability rework: a 64px bar cannot legibly render the 9-glyph
## "1000/1000" at any legible font size, so only the current value is drawn and
## max_health is surfaced via the hp_max observable. max_hp stays in the
## signature (call shape and all call sites unchanged) but is intentionally
## unused for now. Pure function — does not touch the scene, so it is safely
## headless-testable.
static func hp_label_text(current: int, max_hp: int) -> String:
	return str(current)

## Measure the RENDERED ink width of `text` in `hp_label`, INCLUDING the outline
## expansion (the outline widens glyphs ~outline_size px per side, so the drawn
## width is string_width + 2*outline_size). Returns 0.0 if the label or its font
## cannot be resolved (never crashes) — under which the fit check reports ok.
## Pure/headless-safe: theme lookups fall back to the project default font.
static func _hp_rendered_width(hp_label: Label, text: String) -> float:
	if hp_label == null:
		return 0.0
	var f: Font = hp_label.get_theme_font("font")
	if f == null:
		return 0.0
	var fs: int = hp_label.get_theme_font_size("font_size")
	var os: int = hp_label.get_theme_constant("outline_size")
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0 * float(os)

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
		bar_height = bar.size.y
		empty_area_px = EMPTY_CAP_PX * bar_height
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
		# Draw the track 8px larger than the control rect on every side. At
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
		# bar.size stays 64x12, so the `HealthBar.bar_width <= 64` geometric
		# assert is untouched — this is drawing, not layout.
		sb.set_expand_margin_all(8.0)
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
		# outline with a soft shadow. The outline widens glyphs by
		# ~outline_size px, which the short aliases still fit inside the 64 px
		# label with clip_text disabled. (The font SIZE is the height lever —
		# see the name-plate text-metrics block below.)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_constant_override("shadow_outline_size", 1)
		# Name-plate text metrics (2026-08-28 geometry fix). The nameplate is a
		# SINGLE line, so the only real lever on its measured height (== the font
		# line height, which is what clamps the authored rect upward and with it
		# the derived widget height) is the font size. Measured on this theme:
		# font_size 10 → 15 px line height → a 27 px widget, which breaks the
		# untouched ui_geometry_readability.yaml f30 envelope `total_height <= 26`;
		# font_size 9 → 12 px → exactly the compact 24 px the scene authors
		# (12 name row + 12 bar row). outline_size / shadow_outline_size /
		# line_spacing are NOT levers (measured: overriding them to 0 changed the
		# label's minimum height by 0 px), so the Q6 name readability kit —
		# outline, shadow, semi-transparent backing — is untouched.
		label.add_theme_font_size_override("font_size", 9)
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
		# Horizontal insets left/right = 3.0 create a visible ~6px seam between
		# adjacent units' nameplates: two adjacent widgets differ by exactly one
		# 64px cell, so the backing seam = content_margin_left + content_margin_right,
		# independent of absolute position. Top/bottom are 0.0 — the VERTICAL
		# inflation source is compacted here and re-asserted in _relayout_children()
		# so the widget contains its measured children. The NameLabel rect (64x9),
		# widget 68x24, Bar 64x12 and all other frozen geometry are untouched —
		# this only insets the DRAWN backing box (StyleBox.get_stylebox_rect shrinks
		# the draw rect by the content margins).
		_name_backing_sb.set_content_margin(SIDE_TOP, 0.0)
		_name_backing_sb.set_content_margin(SIDE_BOTTOM, 0.0)
		_name_backing_sb.set_content_margin(SIDE_LEFT, 3.0)
		_name_backing_sb.set_content_margin(SIDE_RIGHT, 3.0)
		label.add_theme_stylebox_override("normal", _name_backing_sb)
		name_backing_alpha = 0.7

	# Always record the name (unconditionally, outside the label-null guard)
	# so the observable is set in every setup() path.
	name_text = char_name

	# Record the track color observable unconditionally (outside the bar-null
	# guard) so the playtest surface reads it even when the bar node is absent.
	track_bg = _TRACK_BG

	# Lay out children and derive the widget height (measured children sum) so
	# the headless unit pin reads the laid-out root even without a tree / char
	# node (follow_character() early-returns on the null-char path).
	_relayout_children()

	# Record the widget height observable unconditionally (outside the node
	# guards) so the headless null-char test reads size.y (20.0) even though
	# follow_character() returns early when _char_node is null.
	total_height = size.y

	# Record the HP-number observables to max/max unconditionally (outside the
	# node guards) so the headless null-char path reads a valid "max/max" string
	# even before any health_changed fires.
	hp_text = hp_label_text(max_hp, max_hp)
	hp_value = max_hp
	hp_max = max_hp
	# Guarded write to the additive HpLabel sibling node (child of Bar) so the
	# number is visible the moment the battle spawns, not just after a damage
	# event. get_node_or_null keeps this safe on the headless null-char path.
	var hp_label: Label = _bar.get_node_or_null("HpLabel") as Label if _bar != null else null
	if hp_label != null:
		hp_label.text = hp_text
		# Fit observable valid the moment the battle spawns. bar_width was set
		# above in the bar block (64.0); the <=0 guard covers a hypothetical
		# absent-bar path so the check never misfires.
		hp_text_width_ok = _hp_rendered_width(hp_label, hp_text) <= (bar_width if bar_width > 0.0 else 64.0)

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

	# Rewrite the HP-number observables on every update so the text stays live on
	# damage. hp_max is the same max_hp passed by the caller, so playtest asserts
	# can always express the number relative to max_health (never an absolute HP
	# literal). The HpLabel sibling (child of Bar) is written guarded via
	# get_node_or_null (same defensive-resolution pattern as the EmptyCap).
	hp_text = hp_label_text(current, max_hp)
	hp_value = current
	hp_max = max_hp
	# MOUSE_FILTER_IGNORE (2) on the BAR ITSELF. Its two children were already
	# re-asserted below and the root widget is filter 2 in the scene, but the
	# ProgressBar carrying them set nothing and therefore inherited Godot's
	# Control default, STOP. Measured: a right-click on the player's own feet
	# tile reached `_input` and never reached `_unhandled_input` — the GUI phase
	# handed it to this node — so "右键退回", which the on-screen hint promises,
	# did nothing. The live rect is 64x22 at y in [feet-20, feet+2], i.e. the
	# bottom of every unit's own tile, which is exactly where a player aims to
	# retreat. No descendant of a floating HUD widget may be STOP.
	_bar.mouse_filter = 2
	var hp_label: Label = _bar.get_node_or_null("HpLabel") as Label
	if hp_label != null:
		hp_label.text = hp_text
		# MOUSE_FILTER_IGNORE (2): re-asserted every update so the number label
		# never blocks clicks on the HUD layer (root widget is also filter 2).
		hp_label.mouse_filter = 2
		# Recomputed on every update so the fit observable tracks the live text
		# (bar_width is the live bar size from the last frame / setup()).
		hp_text_width_ok = _hp_rendered_width(hp_label, hp_text) <= (bar_width if bar_width > 0.0 else 64.0)

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


## Compact the theme-derived child inflation so the widget actually CONTAINS its
## measured children (the real defect: the widget reported 68x24 while its
## children measured 30 + 22 = 52 px of painted content, spilling past the
## bottom edge and overlapping each other by 18 px).
##
## Two levers, both applied to theme SOURCES (never to the resulting heights, so
## the invariant holds under any future theme):
##   - Bar: the ProgressBar "minimum_height" THEME CONSTANT only. Measured
##     2026-08-28: the authored 12 was being pushed to 22 by the project theme's
##     ProgressBar minimum_height, not by the track stylebox — with the constant
##     overridden the bar's combined minimum is 4.0 (just the 2+2 px track
##     border), i.e. the authored floor governs again. The track stylebox's
##     expand margins therefore stay 8.0 on ALL FOUR sides: they are the Q5
##     "track visible at full HP" halo (the drawn track grows 8 px past the rect
##     so a full bar reads as a bar, not a block), they are pinned as 8.0 on
##     every side by tests/test_health_bar.gd, and StyleBox.get_minimum_size()
##     does not include expand margins — trimming them would have bought nothing
##     and broken a green pin.
##   - NameLabel: the cached backing stylebox's TOP/BOTTOM content margins
##     (2.0 -> 0.0). SIDE_LEFT/SIDE_RIGHT stay 3.0 — that is the ~6px seam two
##     adjacent nameplates depend on.
## Then re-measure the children, lay the Bar strictly BELOW the NameLabel, and
## set the root height to their measured sum. No child height is written as a
## literal here — only READ and summed. Called from setup() (so the headless
## unit pin reads the laid-out root) and at the top of follow_character().
func _relayout_children() -> void:
	if not is_instance_valid(_bar):
		return
	# Compact theme-derived inflation SOURCES (never the resulting heights):
	#   - Bar: the ProgressBar "minimum_height" theme constant, which is what
	#     feeds get_combined_minimum_size() and clamped the authored 12 up to 22.
	#     The track stylebox's 8.0 expand margins are LEFT ALONE on all four
	#     sides — they are the Q5 full-HP track halo and do not enter the
	#     minimum-size computation (StyleBox.get_minimum_size() = content margins
	#     + borders only).
	#   - NameLabel: the cached backing StyleBoxFlat's TOP/BOTTOM content
	#     margins (2.0 -> 0.0). SIDE_LEFT/SIDE_RIGHT stay 3.0 — that is the
	#     ~6px seam two adjacent nameplates depend on.
	_bar.add_theme_constant_override("minimum_height", 0)
	if _name_backing_sb != null:
		_name_backing_sb.set_content_margin(SIDE_TOP, 0.0)
		_name_backing_sb.set_content_margin(SIDE_BOTTOM, 0.0)
	if not is_instance_valid(_name_label):
		return
	# Re-measure the children: each height is max(authored scene floor,
	# post-override combined minimum) — the theme can only GROW a child, never
	# shrink it below what the scene authored (Bar 12, NameLabel 9 in
	# health_bar.tscn). Measured 2026-08-28: after the overrides above Bar's
	# combined minimum is 4.0 (below the authored 12) and NameLabel's is its
	# font line height, so the floor — not the minimum — is what keeps the Q5
	# empty-slot area (cap 14 x bar 12 = 168 px² >= 120) honest. The floors are
	# the scene's authored values, NOT the sum source: the root height below is
	# still the measured children sum.
	_name_label.size.y = maxf(_NAME_LABEL_FLOOR_Y,
			_name_label.get_combined_minimum_size().y)
	_bar.size.y = maxf(_BAR_FLOOR_Y, _bar.get_combined_minimum_size().y)
	# Bar strictly below NameLabel (never overlapping).
	_name_label.position.y = 0.0
	_bar.position.y = _name_label.size.y
	# Root height = measured children sum. No child height is written as a
	# literal here — only READ (and floored at the authored scene value) and
	# summed.
	var h: float = _name_label.size.y + _bar.size.y
	if not is_equal_approx(size.y, h):
		size.y = h


## The world-y of the bottom edge of the character's live clamped portrait ink.
## Reads the per-frame `portrait_ink_rect` (a Rect2) published by player.gd /
## enemy.gd; falls back to sprite_top + portrait_tex_size.y for a node that has
## those but no ink rect (legacy / just-fallen path). Returns 0.0 when neither
## exists (caller lets the retained STRIP_BOTTOM+2 clamp bite).
func _portrait_ink_bottom_world() -> float:
	if _char_node == null:
		return 0.0
	var ink: Variant = _char_node.get("portrait_ink_rect")
	if typeof(ink) == TYPE_RECT2:
		return float(ink.end.y)
	var top: Variant = _char_node.get("sprite_top")
	var tex: Variant = _char_node.get("portrait_tex_size")
	if typeof(top) == TYPE_FLOAT and typeof(tex) == TYPE_VECTOR2:
		return float(top) + float(tex.y)
	return 0.0


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

	# Re-lay-out children and re-derive the widget height BEFORE any anchor math,
	# so size.y is the measured children sum (widget contains its own children).
	_relayout_children()

	# Map the character's world position to screen through the CANVAS transform
	# (Coord.world_to_screen) — the camera-aware mapping. The final transform is
	# only stretch (no camera); once the Camera2D moves it would stop following
	# the world. screen_pos is the base for the lateral (-34) and the anchor
	# offsets below.
	var screen_pos: Vector2 = Coord.world_to_screen(_char_node.global_position, get_viewport())
	# Portrait-top anchor: the widget bottom sits 4 px above the character's
	# per-frame sprite_top (world px, published by player.gd / enemy.gd), so the
	# nameplate reads as belonging to the portrait instead of sitting on the
	# shins. sprite_top is mapped to screen through Coord.world_to_screen below
	# (canvas transform, camera-aware). Read defensively via get() so a
	# character node without the property falls back to the legacy feet anchor.
	var top: Variant = _char_node.get("sprite_top") if _char_node != null else null
	bar_anchors_below_portrait = false
	# World y of the anchor this branch selects (published to
	# health_bar_world_y / health_bar_screen_y below).
	var anchor_world_y: float = 0.0
	if typeof(top) == TYPE_FLOAT:
		var top_y: float = Coord.world_to_screen(Vector2(0.0, float(top)), get_viewport()).y
		# Above-portrait anchor: widget BOTTOM 4 px above sprite_top.
		var above_top: float = top_y - 4.0 - size.y
		if above_top < STRIP_BOTTOM + 2.0:
			# Top-band unit: the above-portrait anchor would land inside the
			# 0..92 top strip floor (STRIP_BOTTOM + 2 == 94), pulling the bar
			# back over the portrait's upper ink. FLIP to the other side of the
			# portrait: anchor the widget TOP 4 px below the portrait ink
			# bottom. A consistent gap on the far side keeps follow_delta honest
			# everywhere instead of clamping the bar into the hair band.
			# bar_anchors_sprite_top stays false on the flipped path (the
			# above-anchor rule did NOT run).
			var ink_bottom: float = _portrait_ink_bottom_world()
			# The flipped bar anchors its TOP 4 px below the portrait ink bottom
			# (portrait_ink_rect.end.y + 4 — the unit's own feet + 4 once the ink
			# bottom coincides with the feet, i.e. the truthful "stands here"
			# statement from its own tile). It clears both HUD neighbours the
			# above-anchor position collided with: the top strip (STRIP_BOTTOM +
			# 2 == 94, the retained clamp below stays the last resort) and the
			# right-column SkillDescLabel.
			var flip_y: float = Coord.world_to_screen(Vector2(0.0, ink_bottom + 4.0), get_viewport()).y
			screen_pos = Vector2(screen_pos.x - 34.0, flip_y)
			anchor_world_y = ink_bottom + 4.0
			bar_anchors_below_portrait = true
			bar_anchors_sprite_top = false
		else:
			screen_pos = Vector2(screen_pos.x - 34.0, top_y - 4.0 - size.y)
			# anchor_world_y mixes a world value (sprite_top) with viewport-px
			# sizes (size.y); this identity relies on the frozen zoom = 1 the
			# whole round already assumes, so do not "fix" the mixing.
			anchor_world_y = float(top) - 4.0 - size.y
			bar_anchors_sprite_top = true
	else:
		# Legacy feet fallback (defensive): char node without sprite_top.
		screen_pos += Vector2(-34, -32)
		anchor_world_y = _char_node.global_position.y - 32.0
		bar_anchors_sprite_top = false
	# Publish the selected branch's anchor in world and screen space (the two
	# new observables pair with the camera follower's published
	# viewport_half_y / camera_position.y for the clamp-independent pin).
	health_bar_world_y = anchor_world_y
	health_bar_screen_y = Coord.world_to_screen(Vector2(0.0, anchor_world_y), get_viewport()).y
	# follow_delta: pre-clamp displacement of the root center from its desired
	# position (Euclidean distance, computed BEFORE the clamp below). ~0 when
	# the bar is unclamped and free-following; grows only when a viewport edge
	# pins the bar away from the character's projected position.
	follow_delta = (global_position + size * 0.5).distance_to(screen_pos + size * 0.5)
	# Keep the live bar-width observable in sync every frame (defensive: only
	# when the bar node is actually present).
	if is_instance_valid(_bar):
		bar_width = _bar.size.x
		bar_height = _bar.size.y
		empty_area_px = EMPTY_CAP_PX * bar_height
	# Keep the height observable live while the widget actually runs its layout
	# pass (re-assigned on every frame follow_character() executes).
	total_height = size.y
	# Clamp so the bar never clips off the viewport edges. The y LOWER bound is
	# STRIP_BOTTOM + 2 (= 94): no floating bar ever enters the top strip zone
	# (the full-width backed band, hud.tscn TopStrip offsets 0..92). The x
	# clamp and the y upper bound stay viewport-edge based. Follow_delta above
	# stays computed BEFORE this clamp, so its semantics are unchanged.
	var vp: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		clampf(screen_pos.x, 4.0, vp.x - size.x - 4.0),
		clampf(screen_pos.y, STRIP_BOTTOM + 2.0, vp.y - size.y - 4.0))
	# Publish the post-clamp live geometry observables (read AFTER the clamp
	# assigns global_position; early-return paths retain previous values).
	bar_top = global_position.y
	bar_bottom = global_position.y + size.y
	visible = true

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Respond to the character's health_changed signal.
func _on_health_changed(new_health: int, max_health: int) -> void:
	update_health(new_health, max_health)
