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


func _ready() -> void:
	if ThemeDB.fallback_font == null:
		var font: Font = load("res://assets/fonts/NotoSansSC-Regular.otf")
		if font != null:
			ThemeDB.fallback_font = font
