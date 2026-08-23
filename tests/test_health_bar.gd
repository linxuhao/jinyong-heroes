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

	# Compact geometry: 68x20 widget, 64x8 bar, name above, label 9px tall.
	ok = _expect(ok, bar.size == Vector2(68, 20), "bar.size == Vector2(68, 20)")
	ok = _expect(ok, is_equal_approx(bar.total_height, 20.0), "bar.total_height == 20.0")
	ok = _expect(ok, is_equal_approx(bar.bar_width, 64.0), "bar.bar_width == 64.0")
	ok = _expect(ok, bar.name_text == "测试", 'bar.name_text == "测试"')

	# HP band colors: >50% green, >25% yellow, else red.
	bar.update_health(100, 100)
	ok = _expect(ok, bar.fill_color.is_equal_approx(Color(0.3, 0.9, 0.35)),
			"update_health(100,100) fill_color == green")
	bar.update_health(40, 100)
	ok = _expect(ok, bar.fill_color.is_equal_approx(Color(0.95, 0.85, 0.2)),
			"update_health(40,100) fill_color == yellow")
	bar.update_health(20, 100)
	ok = _expect(ok, bar.fill_color.is_equal_approx(Color(0.9, 0.25, 0.2)),
			"update_health(20,100) fill_color == red")

	# The track draws 3px larger than the control rect on every side via
	# expand margins (never content margins), and a dedicated fill stylebox
	# must exist for the per-band recoloring.
	var bar_node = bar.get_node("Bar")
	var bg = bar_node.get_theme_stylebox("background")
	ok = _expect(ok, bg is StyleBoxFlat, "background stylebox is StyleBoxFlat")
	if bg is StyleBoxFlat:
		ok = _expect(ok, is_equal_approx(bg.get_expand_margin_all(), 3.0),
				"background expand_margin_all == 3.0")
	ok = _expect(ok, bar_node.get_theme_stylebox("fill") != null, "fill stylebox non-null")

	if ok:
		print("PASS: test_health_bar")
	else:
		print("FAIL: test_health_bar")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_health_bar: " + what)
	return ok_so_far and cond
