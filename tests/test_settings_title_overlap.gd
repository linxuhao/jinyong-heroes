## Unit tests for the Settings title-overlap fix (task fix_settings_title_overlap).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## Verifies (a) after the anchor_bottom=0.0 fix the Title global rect ends ABOVE
## SettingsBox's top and title_rows_overlap is false; (b) forcing the Title
## offsets onto SettingsBox flips the observable to true; (c) restoring them
## flips it back to false. Both branches are asserted so the test can never pass
## vacuously.

const SettingsScene: PackedScene = preload("res://scenes/ui/settings_panel.tscn")


static func run() -> bool:
	var ok := true

	var panel = SettingsScene.instantiate()
	ok = _expect(ok, panel is Control, "settings panel is a Control")

	# get_global_rect() requires the node to be inside the SceneTree, so add it
	# to the root before reading geometry.
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)

	var title: Control = panel.get_node("Title")
	var box: Control = panel.get_node("SettingsBox")

	panel._refresh_title_overlap()
	ok = _expect(ok, panel.title_rows_overlap == false,
			"post-fix title_rows_overlap == false")

	# Geometry arithmetic: with anchor_bottom=0.0 the Title rect is
	# y=88..176 (offsets measured from the panel top), above SettingsBox
	# (y~304..560 in the 960x704 viewport).
	ok = _expect(ok, title.get_global_rect().end.y < box.get_global_rect().position.y,
			"Title global rect end.y < SettingsBox global rect position.y")

	# Force the Title onto SettingsBox: offsets are measured from the panel top
	# (anchor_bottom=0.0), so y=400..448 lands inside SettingsBox y~304..560.
	title.offset_top = 400.0
	title.offset_bottom = 448.0
	panel._refresh_title_overlap()
	ok = _expect(ok, panel.title_rows_overlap == true,
			"forced-overlap title_rows_overlap == true")

	# Restore the authored offsets; the observable flips back to false.
	title.offset_top = 88.0
	title.offset_bottom = 176.0
	panel._refresh_title_overlap()
	ok = _expect(ok, panel.title_rows_overlap == false,
			"restored title_rows_overlap == false")

	panel.queue_free()

	if ok:
		print("PASS: test_settings_title_overlap")
	else:
		print("FAIL: test_settings_title_overlap")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_settings_title_overlap: " + what)
	return ok_so_far and cond
