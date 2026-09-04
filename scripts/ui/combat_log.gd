extends CanvasLayer
## CombatLog — R4 enemy-action-feedback presentation component.
##
## A small, bounded combat log anchored to the BOTTOM-LEFT corner of the screen,
## visible only while it holds at least one line. It is the on-screen answer to
## the owner's 2026-09-03 playtest #5 complaint that an enemy's turn is a fully
## static screen with no indication anything is happening: every landed hit and
## every movement-zeroing status appends one line here.
##
## PRESENTATION ONLY. This component reads nothing from and writes nothing to any
## combat / damage / initiative / AI / turn-order state — the CombatManager hooks
## hand it a finished display string and it renders it. It never calls back into
## combat logic.
##
## DISPLAY LAYER ONLY: the strings handed to append() are built by the
## CombatManager hooks from unit.character_data.display_name (the R4 shrimp
## nicknames). This component never sees or renders an internal character_name.
##
## LAYOUT / OCCLUSION: lives on its OWN CanvasLayer (never the default canvas),
## which structurally isolates it from the battle HUD's Buttons, name plates,
## order bar and skill bar for UiOcclusionWatch — a cross-CanvasLayer pair is out
## of the watch's scope by construction (ui_occlusion_watch.gd's
## _same_effective_layer). It is also anchored to the bottom edge, clear of the
## top band (0..92) the occlusion watch strips. mouse_filter is IGNORE so the log
## never swallows a board click (the SegmentHost defect class).
##
## Nodes are built in code (not via a scene $ path) so the .tscn stays a bare
## CanvasLayer host and the script is self-contained.

const MAX_LINES: int = 6

## Screen-space margins for the bottom-left dock.
const _MARGIN_X: float = 16.0
const _MARGIN_Y: float = 16.0

var _label: Label = null
var _lines: PackedStringArray = PackedStringArray()

## R5 combat-log-leak fix: this log is a BATTLE-SCENE surface, but it is hosted
## under the CombatManager autoload (so it survives scene changes). It must be
## hidden whenever the game is not in the BATTLE state, and re-created empty at
## battle start. `_in_battle` caches the state edge so a false->true transition
## clears the buffered lines exactly once per new battle. Seeded in _ready() so
## a log lazily created mid-battle (the R4 _fx_on_hit path) does not clear the
## line it was just handed on its first _process frame.
var _in_battle: bool = false

## Presentation-only mirror of the rendered log text (the same string the
## visible label shows, last MAX_LINES lines joined by "\n"). Published so the
## HUD can relay the content onto its own whitelisted surface (the CombatLog
## node itself lives under the CombatManager autoload and is not a proven
## assert target in the harness). Read-only copy — no behavior change.
var rendered_text: String = ""


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.name = "CombatLogLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.92, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)
	# Seed the state edge from the CURRENT state so a log created mid-battle
	# (R4 lazy _fx_ensure path) starts in-battle and never clears its first line.
	_in_battle = (GameManager.current_state == "BATTLE")


## Per-frame state sync: the log is a battle-scene surface, so it is visible
## only while the game is in the BATTLE state. A false->true edge (a new battle
## beginning) clears the buffered lines so a second duel never shows the
## previous duel's lines. Visibility is state-based, not pause-based: during
## BATTLE — including paused, pause menu open, roster panel open — the log
## stays exactly as before (this project's pause is a boolean gate with no
## Engine.time_scale, so _process keeps running while paused).
func _process(_delta: float) -> void:
	var in_battle: bool = (GameManager.current_state == "BATTLE")
	if in_battle and not _in_battle:
		clear()
	_in_battle = in_battle
	_set_battle_layer_visible(in_battle)


## Set this CanvasLayer's visibility and mirror it onto the CombatManager host
## (the acting_unit_marker.gd precedent: a presentation component writes its
## visibility back to the autoload each frame so the harness can assert it).
func _set_battle_layer_visible(value: bool) -> void:
	self.visible = value
	if "combat_log_visible" in CombatManager:
		CombatManager.combat_log_visible = value


## Append one finished display line and keep only the last MAX_LINES visible.
## Visible whenever it holds at least one line.
func append(text: String) -> void:
	if _label == null:
		return
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_label.text = "\n".join(_lines)
	rendered_text = _label.text
	_label.visible = _lines.size() > 0
	_dock_bottom_left()


## Number of lines currently held (capped at MAX_LINES) — a read helper the
## CombatLog hooks surface as debug_combat_log_lines is a cumulative counter,
## not this live count; kept separate on purpose.
func line_count() -> int:
	return _lines.size()


## Clear all lines (e.g. battle teardown) and hide the dock.
func clear() -> void:
	_lines.clear()
	rendered_text = ""
	if _label != null:
		_label.text = ""
		_label.visible = false


## Re-anchor the label to the bottom-left of the viewport each append so it stays
## clear of the top band and the fixed HUD edges regardless of line count.
func _dock_bottom_left() -> void:
	# CanvasLayer has no get_viewport_rect() (that is a Control method) — read the
	# viewport's visible rect instead (the autoload host of this CanvasLayer still
	# exposes get_viewport()). Degrades to a sane 1280x720 fallback pre-tree.
	var vp_size: Vector2 = Vector2(1280.0, 720.0)
	var viewport := get_viewport()
	if viewport != null:
		vp_size = viewport.get_visible_rect().size
	var label_size: Vector2 = _label.get_combined_minimum_size()
	_label.size = label_size
	_label.position = Vector2(
		_MARGIN_X,
		maxf(vp_size.y - label_size.y - _MARGIN_Y, _MARGIN_Y)
	)
