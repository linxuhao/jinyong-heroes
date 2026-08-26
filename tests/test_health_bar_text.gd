## Unit tests for the additive HP-number observables on the health bar (UX-05).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## This round is presentation-only and the three frozen health-bar files keep
## every geometry constant byte-identical. This file therefore (a) pins the new
## hp_label_text format, (b) verifies the observables stay live on setup/update,
## and (c) re-pins the frozen geometry so any accidental constant drift reddens
## THIS test rather than silently passing.
##
## Fully headless: the scene is instantiated but never add_child'd into a tree,
## exercising health_bar.gd's call-order-independent setup() path (the @onready
## members are still null and the child nodes are resolved via get_node_or_null).

const HealthBarScene: PackedScene = preload("res://scenes/ui/health_bar.tscn")


static func run() -> bool:
	var ok := true

	# --- Headless instantiate path ---------------------------------------
	var bar = HealthBarScene.instantiate()
	ok = _expect(ok, bar is Control, "scene is a Control")

	# Pure static format, exercised via the health_bar.gd script on the instance.
	ok = _expect(ok, bar.hp_label_text(500, 500) == "500/500", 'hp_label_text(500,500) == "500/500"')
	ok = _expect(ok, bar.hp_label_text(200, 500) == "200/500", 'hp_label_text(200,500) == "200/500"')
	ok = _expect(ok, bar.hp_label_text(0, 500) == "0/500", 'hp_label_text(0,500) == "0/500"')

	bar.setup("测试", 500, null)

	# Observables initialized to max/max in setup() so the number reads the
	# moment the battle spawns, not just after a damage event.
	ok = _expect(ok, bar.hp_text == "500/500", 'setup() hp_text == "500/500"')
	ok = _expect(ok, bar.hp_value == 500, "setup() hp_value == 500")
	ok = _expect(ok, bar.hp_max == 500, "setup() hp_max == 500")

	# The additive HpLabel (child of Bar) receives the text in setup() too.
	var hp_label: Label = bar.get_node("Bar/HpLabel") as Label
	ok = _expect(ok, hp_label != null, "Bar/HpLabel exists and is a Label")
	if hp_label != null:
		ok = _expect(ok, hp_label.text == "500/500", 'Bar/HpLabel.text == "500/500" after setup()')

	# Live update: the observables and the label track the new value.
	bar.update_health(200, 500)
	ok = _expect(ok, bar.hp_text == "200/500", 'update_health(200,500) hp_text == "200/500"')
	ok = _expect(ok, bar.hp_value == 200, "update_health(200,500) hp_value == 200")
	ok = _expect(ok, bar.hp_max == 500, "update_health(200,500) hp_max == 500")
	if hp_label != null:
		ok = _expect(ok, hp_label.text == "200/500", 'Bar/HpLabel.text == "200/500" after update_health()')
		ok = _expect(ok, hp_label.mouse_filter == 2,
				"Bar/HpLabel.mouse_filter == 2 (never blocks HUD clicks)")

	# --- Scene structure of the additive HpLabel --------------------------
	if hp_label != null:
		ok = _expect(ok, hp_label.clip_text == false, "HpLabel.clip_text == false (no clip)")
		ok = _expect(ok, hp_label.text_overrun_behavior == 0,
				"HpLabel.text_overrun_behavior == 0 (no ellipsis)")
		ok = _expect(ok, is_equal_approx(hp_label.anchor_right, 1.0),
				"HpLabel.anchor_right == 1.0 (full-rect anchors)")
		ok = _expect(ok, is_equal_approx(hp_label.anchor_bottom, 1.0),
				"HpLabel.anchor_bottom == 1.0 (full-rect anchors)")
		ok = _expect(ok, hp_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
				"HpLabel horizontal_alignment == center")
		ok = _expect(ok, hp_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
				"HpLabel vertical_alignment == center")
		ok = _expect(ok, hp_label.get_theme_font_size("font_size") == 9,
				"HpLabel font_size == 9")
		ok = _expect(ok, hp_label.get_theme_color("font_color").is_equal_approx(
				Color(0.95, 0.95, 0.95)), "HpLabel font_color == light")
		ok = _expect(ok, hp_label.get_theme_color("font_outline_color").is_equal_approx(
				Color(0.05, 0.05, 0.05)), "HpLabel font_outline_color == dark")

		# HpLabel must be Bar's LAST child so it paints above the fill and the
		# EmptyCap (otherwise the cap would cover the number).
		var bar_node = bar.get_node("Bar")
		var children = bar_node.get_children()
		ok = _expect(ok, children.size() >= 2, "Bar has at least 2 children")
		if children.size() > 0:
			ok = _expect(ok, children[children.size() - 1] == hp_label,
					"HpLabel is Bar's last child (paints above fill & EmptyCap)")

	# --- Frozen geometry regression pin -----------------------------------
	# These authored constants must remain byte-identical after the additive
	# label work; any drift reddens this additive test instead of silently
	# changing the frozen contract (regression-pinned alongside test_health_bar.gd).
	ok = _expect(ok, bar.size == Vector2(68, 24), "bar.size == Vector2(68, 24) (frozen)")
	ok = _expect(ok, is_equal_approx(bar.bar_width, 64.0), "bar.bar_width == 64.0 (frozen)")
	ok = _expect(ok, is_equal_approx(bar.bar_height, 12.0), "bar.bar_height == 12.0 (frozen)")
	ok = _expect(ok, is_equal_approx(bar.empty_area_px, 168.0), "bar.empty_area_px == 168.0 (frozen)")
	ok = _expect(ok, is_equal_approx(bar.empty_cap_px, 14.0), "bar.empty_cap_px == 14.0 (frozen)")

	if ok:
		print("PASS: test_health_bar_text")
	else:
		print("FAIL: test_health_bar_text")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_health_bar_text: " + what)
	return ok_so_far and cond
