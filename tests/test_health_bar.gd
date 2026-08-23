## Unit tests for the compact health-bar geometry and HP-band coloring.
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by a later subtask; this file only delivers the
## script plus the assertion contract from task_plan.md acceptance criterion 4.
##
## Fully headless: the scene is instantiated but never add_child'd into a tree.
## This exercises health_bar.gd's deliberate call-order-independent setup()
## path, where the @onready members are still null and the child nodes are
## resolved via get_node_or_null.

const HealthBarScene: PackedScene = preload("res://scenes/ui/health_bar.tscn")


static func run() -> bool:
	var ok := true

	# Instantiate without entering a tree (the headless null-char path).
	var bar = HealthBarScene.instantiate()
	bar.setup("测试", 100, null)

	# Compact geometry: 68x26 widget, 64x6 bar, name label 20px tall above it
	# (font 10 + outline 2 — the label rect must hold the CJK glyph box, so it
	# grew from 14 to 20 px with the widget from 20 to 26 px total; review-fix
	# 2 resolution in task_plan fix_vision_gate_readability).
	ok = _expect(ok, bar.size == Vector2(68, 26), "bar.size == Vector2(68, 26)")
	ok = _expect(ok, is_equal_approx(bar.total_height, 26.0), "bar.total_height == 26.0")
	ok = _expect(ok, is_equal_approx(bar.bar_width, 64.0), "bar.bar_width == 64.0")
	ok = _expect(ok, bar.name_text == "测试", 'bar.name_text == "测试"')

	# Track visibility (5_vision Q5): the track bg is LIGHT (luminance > 0.30)
	# so the empty portion of the bar reads against the backdrop at any fill
	# level, and it must never match any fill band color.
	ok = _expect(ok, bar.track_bg.get_luminance() > 0.30,
			"track_bg luminance > 0.30 (light empty track)")

	# HP band colors: >50% green, >25% yellow, else red.
	bar.update_health(100, 100)
	ok = _expect(ok, bar.fill_color.is_equal_approx(Color(0.3, 0.9, 0.35)),
			"update_health(100,100) fill_color == green")
	ok = _expect(ok, not bar.fill_color.is_equal_approx(bar.track_bg),
			"full-HP fill color differs from the track (expanded track stays visible)")
	bar.update_health(40, 100)
	ok = _expect(ok, bar.fill_color.is_equal_approx(Color(0.95, 0.85, 0.2)),
			"update_health(40,100) fill_color == yellow")
	bar.update_health(20, 100)
	ok = _expect(ok, bar.fill_color.is_equal_approx(Color(0.9, 0.25, 0.2)),
			"update_health(20,100) fill_color == red")

	# The track draws 3px larger than the control rect on every side via
	# expand margins (never content margins), and a dedicated fill stylebox
	# must exist for the per-band recoloring — its bg_color is a distinct,
	# dedicated fill, never the track color.
	var bar_node = bar.get_node("Bar")
	var bg = bar_node.get_theme_stylebox("background")
	ok = _expect(ok, bg is StyleBoxFlat, "background stylebox is StyleBoxFlat")
	if bg is StyleBoxFlat:
		ok = _expect(ok, is_equal_approx(bg.get_expand_margin_all(), 3.0),
				"background expand_margin_all == 3.0")
	ok = _expect(ok, bar_node.get_theme_stylebox("fill") != null, "fill stylebox non-null")
	var fill_sb = bar_node.get_theme_stylebox("fill")
	if fill_sb is StyleBoxFlat:
		ok = _expect(ok, not fill_sb.bg_color.is_equal_approx(bar.track_bg),
				"fill stylebox bg differs from track bg")

	# Name-label no-clip (5_vision Q6 / review-fix 2): the label rect must be
	# tall enough for the CJK glyph box — Font.get_height(10) + 2 * outline
	# (the outline widens glyphs both sides) — and the label + bar must both
	# fit inside the 26px widget without overlapping.
	var label: Label = bar.get_node("NameLabel")
	var glyph_box: int = label.get_theme_font("font").get_height(10) \
			+ 2 * label.get_theme_constant("outline_size")
	ok = _expect(ok, label.size.y >= glyph_box,
			"NameLabel.size.y (%d) >= CJK glyph box (%d)" % [label.size.y, glyph_box])
	ok = _expect(ok, label.size.y + bar_node.size.y <= bar.total_height,
			"NameLabel.size.y + Bar.size.y fit inside widget (no overlap)")

	if ok:
		print("PASS: test_health_bar")
	else:
		print("FAIL: test_health_bar")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_health_bar: " + what)
	return ok_so_far and cond
