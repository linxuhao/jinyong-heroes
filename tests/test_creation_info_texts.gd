## Unit tests for the additive character-creation info layer (UX-06/07/08).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
##
## This round is presentation-only and the frozen creation geometry keeps every
## constant byte-identical. This file therefore (a) pins the new pure
## derivations (hp_from_bone / attr_effects_text / confirm_summary_text_from),
## (b) verifies the new label nodes receive text/visibility per phase, and
## (c) re-pins the frozen geometry so any accidental constant drift reddens
## THIS test rather than silently passing.
##
## Fully headless: the scene is instantiated but never add_child'd into a tree,
## exercising creation.gd's call-order-independent _render() path (the @onready
## members are still null and the child nodes are resolved via get_node_or_null).

const CreationScene: PackedScene = preload("res://scenes/segments/creation.tscn")

const ATTR_KEYS := ["bone", "inner", "agility", "wisdom", "fortune"]


static func run() -> bool:
	var ok := true

	# --- 1. Formula pin (relative, full creation clamp range) -------------
	# The operand 5 IS the documented design/40_progression.md §7 formula
	# (气血 = 根骨 × 5) — asserted relatively across the whole 10..20 range.
	var s = CreationScene.instantiate()
	ok = _expect(ok, s is Control, "scene is a Control")
	for b in range(10, 21):
		ok = _expect(ok, s.hp_from_bone(b) == b * 5,
				"hp_from_bone(%d) == %d * 5" % [b, b])

	# --- 2. Effects composition (verbatim from _ATTR_DESCS) ----------------
	var fx: String = s.attr_effects_text()
	ok = _expect(ok, fx.contains("根骨"), "effects text contains 根骨")
	ok = _expect(ok, fx.contains("内力"), "effects text contains 内力")
	ok = _expect(ok, fx.contains("身法"), "effects text contains 身法")
	ok = _expect(ok, fx.contains("悟性"), "effects text contains 悟性")
	ok = _expect(ok, fx.contains("福缘"), "effects text contains 福缘")
	ok = _expect(ok, fx.contains("气血 = 根骨 × 5"), "effects text has the bone formula")
	ok = _expect(ok, fx.contains("内力值"), "effects text has 内力值")
	ok = _expect(ok, fx.contains("移动力"), "effects text has 移动力")
	ok = _expect(ok, fx.contains("学功法"), "effects text has 学功法")
	ok = _expect(ok, fx.contains("奇遇"), "effects text has 奇遇")
	ok = _expect(ok, not fx.contains("▶"), "effects text has no cursor marker ▶")

	# --- 3. Summary composition --------------------------------------------
	var sample := {"bone": 12, "inner": 10, "agility": 14, "wisdom": 10, "fortune": 10}
	var summary: String = s.confirm_summary_text_from(sample)
	ok = _expect(ok, summary.split("\n").size() == 5, "summary has exactly 5 lines")
	ok = _expect(ok, summary.contains("根骨 12"), "summary line 根骨 12")
	ok = _expect(ok, summary.contains("内力 10"), "summary line 内力 10")
	ok = _expect(ok, summary.contains("身法 14"), "summary line 身法 14")
	ok = _expect(ok, summary.contains("悟性 10"), "summary line 悟性 10")
	ok = _expect(ok, summary.contains("福缘 10"), "summary line 福缘 10")

	# --- 4. Scene wiring: ATTRS phase --------------------------------------
	var hp_label: Label = s.get_node("MouseBox/AttrBox/HpValueLabel") as Label
	var confirm_label: Label = s.get_node("MouseBox/ConfirmBox/ConfirmSummaryLabel") as Label
	var attr_desc_label: Label = s.get_node("MouseBox/AttrBox/AttrDescLabel") as Label
	ok = _expect(ok, hp_label != null, "HpValueLabel exists and is a Label")
	ok = _expect(ok, confirm_label != null, "ConfirmSummaryLabel exists and is a Label")

	s.attrs["bone"] = 15
	s._render()
	ok = _expect(ok, s.hp_value == 75, "hp_value == 75 after attrs[bone]=15")
	ok = _expect(ok, s.hp_text == "当前气血 75", 'hp_text == "当前气血 75"')
	if hp_label != null:
		ok = _expect(ok, hp_label.text == "当前气血 75", 'HpValueLabel.text == "当前气血 75"')
		ok = _expect(ok, hp_label.visible == true, "HpValueLabel.visible == true in ATTRS")
	if attr_desc_label != null:
		ok = _expect(ok, attr_desc_label.text == s.attr_effects_text(),
				"AttrDescLabel.text == attr_effects_text() in ATTRS")
	ok = _expect(ok, s.confirm_summary_text == s.confirm_summary_text_from(s.attrs),
			"confirm_summary_text == confirm_summary_text_from(attrs) in ATTRS")

	# --- 4b. Scene wiring: CONFIRM phase -----------------------------------
	s.phase = "CONFIRM"
	s._render()
	if confirm_label != null:
		ok = _expect(ok, confirm_label.visible == true, "ConfirmSummaryLabel.visible == true in CONFIRM")
		ok = _expect(ok, confirm_label.text.contains("根骨 15"),
				'ConfirmSummaryLabel.text contains "根骨 15"')
	if hp_label != null:
		ok = _expect(ok, hp_label.visible == false, "HpValueLabel.visible == false in CONFIRM")

	# --- 4c. New-label properties -------------------------------------------
	if hp_label != null:
		ok = _expect(ok, hp_label.mouse_filter == 2, "HpValueLabel.mouse_filter == 2 (ignore)")
		ok = _expect(ok, hp_label.clip_text == false, "HpValueLabel.clip_text == false")
		ok = _expect(ok, hp_label.text_overrun_behavior == 0, "HpValueLabel.text_overrun_behavior == 0")
		ok = _expect(ok, hp_label.horizontal_alignment == 1, "HpValueLabel horizontal_alignment == 1")
	if confirm_label != null:
		ok = _expect(ok, confirm_label.mouse_filter == 2, "ConfirmSummaryLabel.mouse_filter == 2")
		ok = _expect(ok, confirm_label.clip_text == false, "ConfirmSummaryLabel.clip_text == false")
		ok = _expect(ok, confirm_label.text_overrun_behavior == 0,
				"ConfirmSummaryLabel.text_overrun_behavior == 0")
		ok = _expect(ok, confirm_label.horizontal_alignment == 1,
				"ConfirmSummaryLabel horizontal_alignment == 1")

	# --- 5. Frozen-geometry regression pin (any drift reddens THIS test) ---
	var mouse_box: Control = s.get_node("MouseBox") as Control
	if mouse_box != null:
		ok = _expect(ok, mouse_box.offset_left == -280.0 and mouse_box.offset_top == -240.0
				and mouse_box.offset_right == 280.0 and mouse_box.offset_bottom == 240.0,
				"MouseBox offsets == -280/-240/280/240 (frozen)")
	var attr_box: Control = s.get_node("MouseBox/AttrBox") as Control
	if attr_box != null:
		ok = _expect(ok, int(attr_box.get_theme_constant("separation")) == 10,
				"AttrBox separation == 10 (frozen)")
	var confirm_box: Control = s.get_node("MouseBox/ConfirmBox") as Control
	if confirm_box != null:
		ok = _expect(ok, int(confirm_box.get_theme_constant("separation")) == 12,
				"ConfirmBox separation == 12 (frozen)")
	if attr_desc_label != null:
		ok = _expect(ok, attr_desc_label.custom_minimum_size == Vector2(0, 48),
				"AttrDescLabel.custom_minimum_size == (0,48) (frozen)")
	for i in 5:
		var row: Control = s.get_node("MouseBox/AttrBox/AttrRow%d" % i) as Control
		ok = _expect(ok, row != null and row.custom_minimum_size == Vector2(0, 44),
				"AttrRow%d.custom_minimum_size == (0,44) (frozen)" % i)
		var row_label: Label = s.get_node("MouseBox/AttrBox/AttrRow%d/AttrLabel" % i) as Label
		ok = _expect(ok, row_label != null and row_label.horizontal_alignment == 2
				and row_label.size_flags_horizontal == 3,
				"AttrRow%d/AttrLabel alignment 2 / size_flags 3 (frozen)" % i)
	var confirm_button: Button = s.get_node("MouseBox/ConfirmBox/ConfirmButton") as Button
	ok = _expect(ok, confirm_button != null and confirm_button.custom_minimum_size == Vector2(240, 44),
			"ConfirmButton.custom_minimum_size == (240,44) (frozen)")
	var back_button: Button = s.get_node("MouseBox/ConfirmBox/BackButton") as Button
	ok = _expect(ok, back_button != null and back_button.custom_minimum_size == Vector2(160, 44),
			"BackButton.custom_minimum_size == (160,44) (frozen)")
	var attr_nav: Control = s.get_node("MouseBox/AttrBox/AttrNavRow") as Control
	ok = _expect(ok, attr_nav != null and attr_nav.size_flags_horizontal == 4,
			"AttrNavRow.size_flags_horizontal == 4 (frozen)")

	# --- 6. Wrapped-height budget (measured, not estimated) ----------------
	# The all-five effects text must stay within the AttrDescLabel's 48px
	# minimum / ~51px worst case so the creation_box_fits budget holds.
	if attr_desc_label != null:
		attr_desc_label.text = s.attr_effects_text()
		var min_size: Vector2 = attr_desc_label.get_combined_minimum_size()
		ok = _expect(ok, min_size.y <= 51.0,
				"AttrDescLabel wrapped height %.1f <= 51 (budget)" % min_size.y)

	if ok:
		print("PASS: test_creation_info_texts")
	else:
		print("FAIL: test_creation_info_texts")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_creation_info_texts: " + msg)
	return false
