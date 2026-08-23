## Unit tests for the four skill-button visual states (fix_skill_button_states).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh via unit_test_runner.gd's TESTS registry.
##
## Pure checks on state_palette() / SELECTED_BORDER_COLOR + one scene test on a
## fresh skill_button.tscn instance (never added to a tree — the headless
## instantiate-only pattern, same as test_health_bar.gd): _apply_state must land
## per-state StyleBoxFlat overrides on BOTH "normal" and "disabled" (a disabled
## button renders the "disabled" stylebox), write the Chinese state_tag_text,
## and set the gold border on both overrides when selected. _apply_state
## resolves child labels via get_node_or_null (the file's defensive pattern), so
## the tree-less path exercises the real rendering code.

const SkillButtonScene: PackedScene = preload("res://scenes/ui/skill_button.tscn")
const SkillButtonScript: GDScript = preload("res://scripts/ui/skill_button.gd")

const GOLD := Color(1.0, 0.84, 0.0, 1.0)


static func run() -> bool:
	var ok := true

	# --- Acceptance 1: palette contract, pairwise-distinct backgrounds, and
	# --- Chinese tags (界面文字一律中文).
	var ready: Dictionary = SkillButtonScript.state_palette("ready")
	var cooldown: Dictionary = SkillButtonScript.state_palette("cooldown")
	var phase_locked: Dictionary = SkillButtonScript.state_palette("phase_locked")
	var hp_gated: Dictionary = SkillButtonScript.state_palette("hp_gated")

	ok = _expect(ok, ready["bg_color"].is_equal_approx(Color(0.20, 0.24, 0.30)), "ready bg_color")
	ok = _expect(ok, ready["border_color"].is_equal_approx(Color(0.35, 0.40, 0.48)), "ready border_color")
	ok = _expect(ok, int(ready["border_width"]) == 1, "ready border_width == 1")
	ok = _expect(ok, ready["tag_text"] == "", 'ready tag_text == ""')

	ok = _expect(ok, cooldown["bg_color"].is_equal_approx(Color(0.16, 0.16, 0.20)), "cooldown bg_color")
	ok = _expect(ok, cooldown["border_color"].is_equal_approx(Color(0.42, 0.42, 0.46)), "cooldown border_color")
	ok = _expect(ok, int(cooldown["border_width"]) == 1, "cooldown border_width == 1")
	ok = _expect(ok, cooldown["tag_text"] == "", 'cooldown tag_text == ""')

	ok = _expect(ok, phase_locked["bg_color"].is_equal_approx(Color(0.32, 0.32, 0.34)), "phase_locked bg_color")
	ok = _expect(ok, phase_locked["border_color"].is_equal_approx(Color(0.55, 0.55, 0.58)), "phase_locked border_color")
	ok = _expect(ok, int(phase_locked["border_width"]) == 2, "phase_locked border_width == 2")
	ok = _expect(ok, phase_locked["tag_text"] == "锁定", 'phase_locked tag_text == "锁定"')

	ok = _expect(ok, hp_gated["bg_color"].is_equal_approx(Color(0.40, 0.12, 0.12)), "hp_gated bg_color")
	ok = _expect(ok, hp_gated["border_color"].is_equal_approx(Color(0.75, 0.25, 0.25)), "hp_gated border_color")
	ok = _expect(ok, int(hp_gated["border_width"]) == 2, "hp_gated border_width == 2")
	ok = _expect(ok, hp_gated["tag_text"] == "气血", 'hp_gated tag_text == "气血"')

	# Pairwise-distinct backgrounds across the four states.
	var bgs: Array = [ready["bg_color"], cooldown["bg_color"], phase_locked["bg_color"], hp_gated["bg_color"]]
	for i in range(bgs.size()):
		for j in range(i + 1, bgs.size()):
			ok = _expect(ok, not bgs[i].is_equal_approx(bgs[j]),
					"bg_color %d and %d pairwise distinct" % [i, j])

	# Unknown state falls back to the ready palette.
	var unknown: Dictionary = SkillButtonScript.state_palette("bogus_state")
	ok = _expect(ok, unknown["bg_color"].is_equal_approx(ready["bg_color"]), "unknown state -> ready bg_color")
	ok = _expect(ok, unknown["tag_text"] == "", 'unknown state tag_text == ""')

	# --- Acceptance 2: SELECTED_BORDER_COLOR constant.
	ok = _expect(ok, SkillButtonScript.SELECTED_BORDER_COLOR.is_equal_approx(GOLD),
			"SELECTED_BORDER_COLOR == gold")

	# --- Acceptance 3: fresh instance, _apply_state("phase_locked") lands
	# --- stylebox overrides on BOTH normal and disabled; state_tag_text.
	var btn = SkillButtonScene.instantiate()
	btn._apply_state("phase_locked")
	ok = _expect(ok, btn.has_theme_stylebox_override("normal"), 'has_theme_stylebox_override("normal")')
	ok = _expect(ok, btn.has_theme_stylebox_override("disabled"), 'has_theme_stylebox_override("disabled")')
	ok = _expect(ok, btn.state_tag_text == "锁定", 'state_tag_text == "锁定"')
	ok = _expect(ok, btn.get_node("StateTag").text == "锁定", 'StateTag label text == "锁定"')

	# Selected: BOTH override styleboxes carry the gold border.
	btn.selected = true
	btn._apply_state("phase_locked")
	var normal_sb: StyleBox = btn.get_theme_stylebox("normal")
	var disabled_sb: StyleBox = btn.get_theme_stylebox("disabled")
	ok = _expect(ok, normal_sb is StyleBoxFlat, "normal override is StyleBoxFlat")
	ok = _expect(ok, disabled_sb is StyleBoxFlat, "disabled override is StyleBoxFlat")
	if normal_sb is StyleBoxFlat:
		ok = _expect(ok, normal_sb.border_color.is_equal_approx(GOLD),
				"normal override border gold when selected")
	if disabled_sb is StyleBoxFlat:
		ok = _expect(ok, disabled_sb.border_color.is_equal_approx(GOLD),
				"disabled override border gold when selected")

	# --- Acceptance 4: cooldown round number + label visibility; ready clears.
	var btn2 = SkillButtonScene.instantiate()
	btn2.cooldown_remaining = 1
	btn2._apply_state("cooldown")
	ok = _expect(ok, btn2.cooldown_label_text == "1", 'cooldown_label_text == "1"')
	ok = _expect(ok, btn2.get_node("CooldownLabel").visible == true, "CooldownLabel visible on cooldown")
	ok = _expect(ok, btn2.get_node("CooldownLabel").text == "1", "CooldownLabel text == \"1\"")
	btn2._apply_state("ready")
	ok = _expect(ok, btn2.cooldown_label_text == "", 'cooldown_label_text cleared on ready')
	ok = _expect(ok, btn2.state_tag_text == "", 'state_tag_text cleared on ready')
	ok = _expect(ok, btn2.get_node("CooldownLabel").visible == false, "CooldownLabel hidden on ready")

	if ok:
		print("PASS: test_skill_button_states")
	else:
		print("FAIL: test_skill_button_states")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_skill_button_states: " + what)
	return ok_so_far and cond
