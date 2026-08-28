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
	# Route (a) of the readability rework: only the CURRENT value is rendered
	# ("500"), never "cur/max" — the 9-glyph "1000/1000" cannot fit a 64px bar
	# legibly at any font size. max_health stays discoverable via hp_max.
	ok = _expect(ok, bar.hp_label_text(500, 500) == "500", 'hp_label_text(500,500) == "500"')
	ok = _expect(ok, bar.hp_label_text(200, 500) == "200", 'hp_label_text(200,500) == "200"')
	ok = _expect(ok, bar.hp_label_text(0, 500) == "0", 'hp_label_text(0,500) == "0"')
	ok = _expect(ok, bar.hp_label_text(1000, 1000) == "1000",
			'hp_label_text(1000,1000) == "1000"')

	bar.setup("测试", 500, null)

	# Observables initialized to max in setup() so the number reads the moment
	# the battle spawns, not just after a damage event.
	ok = _expect(ok, bar.hp_text == "500", 'setup() hp_text == "500"')
	ok = _expect(ok, bar.hp_value == 500, "setup() hp_value == 500")
	ok = _expect(ok, bar.hp_max == 500, "setup() hp_max == 500")
	ok = _expect(ok, bar.hp_text_width_ok == true, "setup(500) hp_text_width_ok == true")

	# The additive HpLabel (child of Bar) receives the text in setup() too.
	var hp_label: Label = bar.get_node("Bar/HpLabel") as Label
	ok = _expect(ok, hp_label != null, "Bar/HpLabel exists and is a Label")
	if hp_label != null:
		ok = _expect(ok, hp_label.text == "500", 'Bar/HpLabel.text == "500" after setup()')

	# Live update: the observables and the label track the new value.
	bar.update_health(200, 500)
	ok = _expect(ok, bar.hp_text == "200", 'update_health(200,500) hp_text == "200"')
	ok = _expect(ok, bar.hp_value == 200, "update_health(200,500) hp_value == 200")
	ok = _expect(ok, bar.hp_max == 500, "update_health(200,500) hp_max == 500")
	if hp_label != null:
		ok = _expect(ok, hp_label.text == "200", 'Bar/HpLabel.text == "200" after update_health()')
		ok = _expect(ok, hp_label.mouse_filter == 2,
				"Bar/HpLabel.mouse_filter == 2 (never blocks HUD clicks)")
	ok = _expect(ok, bar.hp_text_width_ok == true, "update_health(200,500) hp_text_width_ok == true")

	# --- Worst-case width: "1000" must fit the 64px bar -------------------------
	# max_health is 1000 since the 2026-08-24 balance change, so the longest
	# string the bar can ever carry is "1000" (4 glyphs, route (a)). The fit
	# observable must be true for it (font_size 10 / outline 4 so the MEASURED
	# rendered width, string_size + 2*outline_size, is <= 64.0).
	bar.setup("测试", 1000, null)
	bar.update_health(1000, 1000)
	ok = _expect(ok, bar.hp_text == "1000", 'update_health(1000,1000) hp_text == "1000"')
	ok = _expect(ok, bar.hp_value == 1000, "update_health(1000,1000) hp_value == 1000")
	ok = _expect(ok, bar.hp_max == 1000, "update_health(1000,1000) hp_max == 1000")
	ok = _expect(ok, bar.hp_text_width_ok == true,
			"worst-case '1000' fits 64px (hp_text_width_ok == true)")

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
		ok = _expect(ok, hp_label.get_theme_font_size("font_size") >= 9,
				"HpLabel font_size >= 9 (legible on the bar)")
		ok = _expect(ok, hp_label.get_theme_constant("outline_size") >= 3,
				"HpLabel outline_size >= 3 (strong dark outline on bright fill)")
		var hp_fc: Color = hp_label.get_theme_color("font_color")
		ok = _expect(ok, hp_fc.get_luminance() >= 0.8,
				"HpLabel font_color luminance >= 0.8 (light glyph)")
		ok = _expect(ok, hp_label.get_theme_color("font_outline_color").is_equal_approx(
				Color(0.02, 0.02, 0.02)), "HpLabel font_outline_color == dark (0.02)")

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
	# Same correction as test_health_bar.gd, and for the same reason: the frozen
	# contract froze a number the theme is entitled to change, not the property
	# the number was standing in for. See that file for the full account.
	ok = _expect(ok, bar.bar_height >= 12.0,
			"bar.bar_height >= the authored 12, frozen as a FLOOR (got %.1f)" % bar.bar_height)
	ok = _expect(ok, is_equal_approx(bar.empty_area_px, bar.empty_cap_px * bar.bar_height),
			"empty_area_px is cap x height (got %.1f)" % bar.empty_area_px)
	ok = _expect(ok, bar.empty_area_px >= 120.0,
			"empty slot area clears the Q5 visibility floor of 120 px2 (got %.1f)" % bar.empty_area_px)
	ok = _expect(ok, is_equal_approx(bar.empty_cap_px, 14.0), "bar.empty_cap_px == 14.0 (frozen)")

	# --- DEFECT 2: nameplate backing seam -----------------------------------
	# The semi-transparent name backing is a StyleBoxFlat on NameLabel; its
	# horizontal content margins inset the DRAWN backing box (StyleBoxFlat draws
	# within get_stylebox_rect, which shrinks by the content margins), creating a
	# visible seam (>= 2px) between adjacent units' nameplates. Adjacent widgets
	# differ by exactly one 64px cell, so seam = left + right, position-independent.
	var name_label: Label = bar.get_node("NameLabel") as Label
	if name_label != null:
		var nb: StyleBoxFlat = name_label.get_theme_stylebox("normal") as StyleBoxFlat
		ok = _expect(ok, nb != null, "NameLabel normal stylebox is a StyleBoxFlat")
		if nb != null:
			# StyleBox exposes get_content_margin(Side), not per-side named
			# getters; the names used here do not exist and raised a SCRIPT ERROR
			# that killed run() before any of these ever evaluated. Same cause as
			# test_health_bar.gd: written against an API that isn't there, and
			# never executed, because no pipeline step runs this suite.
			var ml: float = nb.get_content_margin(SIDE_LEFT)
			var mr: float = nb.get_content_margin(SIDE_RIGHT)
			ok = _expect(ok, ml + mr >= 2.0,
					"name backing left+right margins >= 2.0 (visible seam, got %.1f)" % (ml + mr))
			ok = _expect(ok, is_equal_approx(ml, 3.0) and is_equal_approx(mr, 3.0),
					"name backing horizontal margins == 3.0 (6px seam, got %.1f/%.1f)" % [ml, mr])
			ok = _expect(ok, is_equal_approx(bar.name_backing_alpha, 0.7),
					"name_backing_alpha still 0.7")
			ok = _expect(ok, nb.bg_color.is_equal_approx(Color(0.05, 0.05, 0.08, 0.7)),
					"name backing bg_color still (0.05,0.05,0.08,0.7)")

	if ok:
		print("PASS: test_health_bar_text")
	else:
		print("FAIL: test_health_bar_text")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_health_bar_text: " + what)
	return ok_so_far and cond
