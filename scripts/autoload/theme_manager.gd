## ThemeManager (autoload)
##
## Runtime bootstrap for the global Chinese font theme. The primary mechanism
## is the committed Theme resource `res://assets/themes/global_theme.tres`
## (wired via ProjectSettings `gui/theme/custom`), which references the
## Noto Sans SC FontFile by res:// path. This autoload is the CI-safe fallback:
## if the Theme resource's font binding ever fails to load (import race, uid
## rot), it installs the same font as ThemeDB.fallback_font so every label in
## the game still renders Chinese glyphs. No per-node font overrides anywhere.
extends Node


## Font colors for the script-driven focus marker on option-list rows.
## OPTION_FONT_FOCUS is the bright paper tone used on the focused row;
## OPTION_FONT_DIM is the muted (but still legible) tone for non-focused rows.
const OPTION_FONT_FOCUS: Color = Color(0.98, 0.96, 0.9, 1)
const OPTION_FONT_DIM: Color = Color(0.62, 0.60, 0.55, 1)


## Cached StyleBoxFlats for the two option-row visual states. Built once on
## first use and never mutated afterwards, so repeated calls in hot loops
## allocate nothing and share safe immutable resources.
var _option_plain: StyleBoxFlat = null
var _option_focused: StyleBoxFlat = null


func _ready() -> void:
	if ThemeDB.fallback_font == null:
		var font: Font = load("res://assets/fonts/NotoSansSC-Regular.otf")
		if font != null:
			ThemeDB.fallback_font = font


## Returns one of the two cached option-row styleboxes (never a fresh
## allocation per call). Both boxes share identical geometry/margins (mirroring
## the global theme's Button/styles/normal) so swapping between them does NOT
## change a button's minimum size. The focused box adds an unmistakable
## 3px cinnabar left bar + cinnabar border, replacing the old 2-3% brightness
## (modulate 1.0 vs 0.72) focus cue.
func option_style(focused: bool) -> StyleBoxFlat:
	if focused:
		if _option_focused == null:
			_option_focused = _build_option_stylebox(true)
		return _option_focused
	if _option_plain == null:
		_option_plain = _build_option_stylebox(false)
	return _option_plain


func _build_option_stylebox(is_focused: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.13, 1)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_right = 3
	sb.corner_radius_bottom_left = 3
	sb.content_margin_left = 12.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 4.0
	if is_focused:
		# Cinnabar focus treatment: widened left bar + cinnabar border.
		sb.border_width_left = 3
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.69, 0.22, 0.18, 1)
	else:
		# Plain state mirrors the theme's Button/styles/normal.
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.62, 0.55, 0.42, 1)
	return sb
