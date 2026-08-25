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

	# Compact geometry: 68x24 widget, 64x12 bar, name label 9px tall above it
	# (font 10; the label rect is intentionally shorter than the CJK glyph box —
	# the no-clip guarantee is clip_text = false, not rect height).
	ok = _expect(ok, bar.size == Vector2(68, 24), "bar.size == Vector2(68, 24)")
	ok = _expect(ok, is_equal_approx(bar.total_height, 24.0), "bar.total_height == 24.0")
	ok = _expect(ok, is_equal_approx(bar.bar_width, 64.0), "bar.bar_width == 64.0")
	# Bar height (authored 12 px — read via the headless instantiate path, before
	# the battle scene's theme min-size clamp pushes it to ~22) and the resulting
	# visible empty-slot area (14 px cap × 12 px = 168 px², the Q5 area argument).
	ok = _expect(ok, is_equal_approx(bar.bar_height, 12.0), "bar.bar_height == 12.0")
	ok = _expect(ok, is_equal_approx(bar.empty_area_px, 168.0), "bar.empty_area_px == 168.0")
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

	# The track draws 8px larger than the control rect on every side via
	# expand margins (never content margins), and a dedicated fill stylebox
	# must exist for the per-band recoloring — its bg_color is a distinct,
	# dedicated fill, never the track color.
	var bar_node = bar.get_node("Bar")
	var bg = bar_node.get_theme_stylebox("background")
	ok = _expect(ok, bg is StyleBoxFlat, "background stylebox is StyleBoxFlat")
	if bg is StyleBoxFlat:
		ok = _expect(ok, is_equal_approx(bg.get_expand_margin_all(), 8.0),
				"background expand_margin_all == 8.0")
		ok = _expect(ok, bg.border_width_left == 2 and bg.border_width_top == 2
				and bg.border_width_right == 2 and bg.border_width_bottom == 2,
				"background border_width == 2 on all four sides")
	ok = _expect(ok, bar_node.get_theme_stylebox("fill") != null, "fill stylebox non-null")
	var fill_sb = bar_node.get_theme_stylebox("fill")
	if fill_sb is StyleBoxFlat:
		ok = _expect(ok, not fill_sb.bg_color.is_equal_approx(bar.track_bg),
				"fill stylebox bg differs from track bg")

	# EmptyCap: the constant track-color end cap pinned to the bar's right end
	# (5_vision Q5 — a visible empty slot at ANY fill level, incl. 100%).
	var cap = bar_node.get_node("EmptyCap")
	ok = _expect(ok, cap is ColorRect, "Bar/EmptyCap exists and is a ColorRect")
	# Cap height tracks the bar height (authored 12 px, same value as bar_height).
	ok = _expect(ok, is_equal_approx(cap.size.y, bar.bar_height),
			"EmptyCap.size.y == bar.bar_height")
	ok = _expect(ok, bar.empty_cap_px > 0, "empty_cap_px > 0")
	ok = _expect(ok, is_equal_approx(cap.size.x, bar.empty_cap_px),
			"EmptyCap.size.x == empty_cap_px")
	ok = _expect(ok, cap.color.is_equal_approx(bar.track_bg),
			"EmptyCap.color == track_bg")
	ok = _expect(ok, abs(cap.position.x + cap.size.x - bar_node.size.x) < 0.01,
			"EmptyCap right-aligned with Bar (position.x + size.x == Bar.size.x)")
	ok = _expect(ok, cap.mouse_filter == 2,
			"EmptyCap.mouse_filter == 2 (never blocks clicks on the HUD layer)")

	# At full HP (ratio 1.0) the cap must STILL be pinned and visible — the
	# fill covers the whole bar rect, so the cap is the only empty-track hint.
	bar.update_health(100, 100)
	ok = _expect(ok, cap is ColorRect and is_equal_approx(cap.size.x, bar.empty_cap_px)
			and cap.color.is_equal_approx(bar.track_bg)
			and abs(cap.position.x + cap.size.x - bar_node.size.x) < 0.01
			and cap.visible,
			"EmptyCap still pinned & visible at full HP (ratio 1.0)")

	# Name-label no-clip (5_vision Q6): the 9px label rect cannot hold the full
	# CJK glyph box (font 10 em ≈ 15px) — that is by design. The no-clip
	# guarantee is Label.clip_text = false (text draws even outside the rect,
	# never ellipsized: text_overrun_behavior = 0), so assert those instead of
	# rect height, and keep the label + bar both fitting inside the 24px widget.
	var label: Label = bar.get_node("NameLabel")
	ok = _expect(ok, label.clip_text == false, "NameLabel.clip_text == false (no clip)")
	ok = _expect(ok, label.text_overrun_behavior == 0,
			"NameLabel.text_overrun_behavior == 0 (no ellipsis)")
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
