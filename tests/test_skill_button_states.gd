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
const RoundIndicatorScript: GDScript = preload("res://scripts/ui/round_indicator.gd")

const GOLD := Color(1.0, 0.84, 0.0, 1.0)


static func run() -> bool:
	var ok := true

	# --- Acceptance 1: palette contract, pairwise bg luminance spread >= 0.10,
	# --- and Chinese tags (界面文字一律中文). The verbatim values come from
	# --- task_plan fix_vision_gate_readability / research_notes (pre-computed
	# --- Rec.709 luminance table) — deviating from them fails the Q3
	# --- distinguishability objective (review-fix 1: cooldown bg was darkened
	# --- to (0.08,0.08,0.10) so cooldown vs hp_gated spread clears 0.10).
	var ready: Dictionary = SkillButtonScript.state_palette("ready")
	var cooldown: Dictionary = SkillButtonScript.state_palette("cooldown")
	var phase_locked: Dictionary = SkillButtonScript.state_palette("phase_locked")
	var hp_gated: Dictionary = SkillButtonScript.state_palette("hp_gated")

	ok = _expect(ok, ready["bg_color"].is_equal_approx(Color(0.30, 0.40, 0.52)), "ready bg_color")
	ok = _expect(ok, ready["border_color"].is_equal_approx(Color(0.50, 0.60, 0.72)), "ready border_color")
	ok = _expect(ok, int(ready["border_width"]) == 1, "ready border_width == 1")
	ok = _expect(ok, ready["tag_text"] == "", 'ready tag_text == ""')

	ok = _expect(ok, cooldown["bg_color"].is_equal_approx(Color(0.08, 0.08, 0.10)), "cooldown bg_color")
	ok = _expect(ok, cooldown["border_color"].is_equal_approx(Color(0.32, 0.32, 0.36)), "cooldown border_color")
	ok = _expect(ok, int(cooldown["border_width"]) == 1, "cooldown border_width == 1")
	ok = _expect(ok, cooldown["tag_text"] == "", 'cooldown tag_text == ""')

	ok = _expect(ok, phase_locked["bg_color"].is_equal_approx(Color(0.55, 0.53, 0.48)), "phase_locked bg_color")
	ok = _expect(ok, phase_locked["border_color"].is_equal_approx(Color(0.68, 0.66, 0.60)), "phase_locked border_color")
	ok = _expect(ok, int(phase_locked["border_width"]) == 2, "phase_locked border_width == 2")
	ok = _expect(ok, phase_locked["tag_text"] == "锁定", 'phase_locked tag_text == "锁定"')

	ok = _expect(ok, hp_gated["bg_color"].is_equal_approx(Color(0.58, 0.10, 0.10)), "hp_gated bg_color")
	ok = _expect(ok, hp_gated["border_color"].is_equal_approx(Color(0.85, 0.28, 0.28)), "hp_gated border_color")
	ok = _expect(ok, int(hp_gated["border_width"]) == 2, "hp_gated border_width == 2")
	ok = _expect(ok, hp_gated["tag_text"] == "气血", 'hp_gated tag_text == "气血"')

	# Pairwise luminance spread across the four states (all 6 ordered pairs
	# >= 0.10 — the Q3 visibility contract; computed live from the actual
	# palette via Color.get_luminance()).
	var state_names: Array = ["ready", "cooldown", "phase_locked", "hp_gated"]
	var palettes: Array = [ready, cooldown, phase_locked, hp_gated]
	for i in range(state_names.size()):
		for j in range(i + 1, state_names.size()):
			var lum_i: float = palettes[i]["bg_color"].get_luminance()
			var lum_j: float = palettes[j]["bg_color"].get_luminance()
			var spread: float = absf(lum_i - lum_j)
			ok = _expect(ok, spread >= 0.10,
					"%s vs %s bg luminance spread %.4f >= 0.10" % [state_names[i], state_names[j], spread])

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

	# --- Acceptance 5 (strengthen_skill_button_state_change_rendering): the
	# --- SelectedMarker gold top bar mirrors `selected` across EVERY state
	# --- (ready/cooldown/phase_locked/hp_gated), and the gold border covers
	# --- both normal + disabled overrides on each state, so an
	# --- unselected->selected frame diff is unmistakable.
	var btn3 = SkillButtonScene.instantiate()
	var marker: ColorRect = btn3.get_node("SelectedMarker")
	for s in state_names:
		btn3.selected = false
		btn3._apply_state(s)
		ok = _expect(ok, marker.visible == false, "SelectedMarker hidden on %s when unselected" % s)
		btn3.selected = true
		btn3._apply_state(s)
		ok = _expect(ok, marker.visible == true, "SelectedMarker shown on %s when selected" % s)
		var sel_normal: StyleBox = btn3.get_theme_stylebox("normal")
		var sel_disabled: StyleBox = btn3.get_theme_stylebox("disabled")
		if sel_normal is StyleBoxFlat:
			ok = _expect(ok, sel_normal.border_color.is_equal_approx(GOLD),
					"normal override border gold on %s when selected" % s)
		if sel_disabled is StyleBoxFlat:
			ok = _expect(ok, sel_disabled.border_color.is_equal_approx(GOLD),
					"disabled override border gold on %s when selected" % s)

	# Cooldown number enlarged (>= 24) + bright gold over the dark top-fill so a
	# ready->cooldown diff is unmistakable; contract observables unchanged.
	var btn4 = SkillButtonScene.instantiate()
	btn4.cooldown_remaining = 1
	btn4._apply_state("cooldown")
	var cd_label: Label = btn4.get_node("CooldownLabel")
	ok = _expect(ok, cd_label.get_theme_font_size("font_size") >= 24, "CooldownLabel font size >= 24")
	ok = _expect(ok, cd_label.get_theme_color("font_color").is_equal_approx(Color(1.0, 0.85, 0.25, 1.0)),
			"CooldownLabel font_color bright gold")
	ok = _expect(ok, cd_label.visible == true, "CooldownLabel visible on cooldown (contract)")
	ok = _expect(ok, btn4.cooldown_label_text == "1", 'cooldown_label_text == "1" (contract)')

	# --- Acceptance 6 (Q6 no-ellipsis): every Label in the button scene renders
	# without "..." / U+2026 "…", and no Label clips (clip_text == false,
	# text_overrun_behavior == 0 — the two properties the vision gate checks).
	# The sweep runs on a REAL setup() + _apply_state("cooldown") instance so the
	# button text, hotkey, fahui label, state tag and cooldown number are the
	# strings that actually render.
	var btn5 = SkillButtonScene.instantiate()
	btn5.setup({"skill_name": "总诀式", "description": "独孤九剑·总诀式"}, "9", 1.3)
	btn5.cooldown_remaining = 2
	btn5._apply_state("cooldown")
	var rendered: Array[String] = [str(btn5.text)]
	for child in btn5.get_children():
		if child is Label:
			rendered.append(str(child.text))
			ok = _expect(ok, child.clip_text == false,
					"Q6: Label %s has clip_text == false" % child.name)
			ok = _expect(ok, int(child.text_overrun_behavior) == 0,
					"Q6: Label %s has text_overrun_behavior == 0" % child.name)
	for t in rendered:
		ok = _expect(ok, not t.contains("…") and not t.contains("..."),
				"Q6: rendered text %s is free of ellipsis (…/...)" % t)

	# --- Acceptance 7 (Q4 round indicator): the active line renders the move
	# budget (digit + "·" pips) and the acted suffix (行动 ✓ / 结束), and the
	# move_pips observable mirrors moves_left. _active_text reads the live
	# GameManager autoload's player node — a minimal fake player carrying the two
	# properties is injected directly (the first-call-wins guard is bypassed via
	# set("_player", ...)) and restored to null afterwards. The fake must carry
	# DECLARED properties: round_indicator.gd probes them with the `in` operator
	# ("moves_left" in player), and `in` on an Object only sees properties the
	# object actually declares — dynamic set()-only values on a bare Node are
	# invisible to it, which renders "移动 0" and fails the pips assert. A tiny
	# scripted fake (compiled at runtime, no extra repo file) represents the
	# real player node the code is designed for.
	var ri = RoundIndicatorScript.new()
	var fake_script := GDScript.new()
	fake_script.source_code = "extends Node\nvar moves_left: int = 0\nvar acted: bool = false\n"
	fake_script.reload()
	var fake_player := Node.new()
	fake_player.set_script(fake_script)
	fake_player.moves_left = 4
	fake_player.acted = false
	var gm: Node = null
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		gm = (main_loop as SceneTree).root.get_node_or_null("GameManager")
	ok = _expect(ok, gm != null, "Q4: GameManager autoload reachable in unit-test context")
	if gm != null:
		gm.set("_player", fake_player)
		var t_active: String = ri._active_text("Yang Guo")
		gm.set("_player", null)
		ok = _expect(ok, t_active.contains("移动"),
				'Q4: active line contains "移动"')
		ok = _expect(ok, t_active.ends_with("行动 ✓"),
				'Q4: un-acted active line ends "行动 ✓" (U+2713)')
		ok = _expect(ok, ri.move_pips == "·".repeat(4),
				'Q4: move_pips == "·".repeat(moves_left)')
		fake_player.set("acted", true)
		gm.set("_player", fake_player)
		var t_done: String = ri._active_text("Yang Guo")
		gm.set("_player", null)
		ok = _expect(ok, t_done.ends_with("结束"),
				'Q4: acted active line ends "结束"')
	fake_player.free()

	if ok:
		print("PASS: test_skill_button_states")
	else:
		print("FAIL: test_skill_button_states")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_skill_button_states: " + what)
	return ok_so_far and cond
