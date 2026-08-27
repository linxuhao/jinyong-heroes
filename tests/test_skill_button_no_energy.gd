## Unit tests for the no_energy skill-button state (GOAL 4 — visually distinguish
## the insufficient-inner-force button state from the locked state).
## Contract: plain GDScript (no extends), top-level `static func run() -> bool`;
## push_error on failure; print PASS/FAIL at the end. Collected into run_tests.sh
## via unit_test_runner.gd's TESTS registry (append-only).
##
## Honest record: with current content every SkillData.cost == 0 (no technique
## spends energy this run — player.gd:110 / enemy.gd:83 say "display only — no
## technique costs this run"), so no_energy is structurally UNREACHABLE in live
## play. That is expected, not a bug: the state is real presentation machinery
## (palette entry + predicate + derive_state + disabled term) proven here by
## unit test, and it activates naturally when a future round defines real
## per-skill costs. This file deliberately does NOT assert it fires in a live
## battle.

const SkillButtonScene: PackedScene = preload("res://scenes/ui/skill_button.tscn")
const SkillButtonScript: GDScript = preload("res://scripts/ui/skill_button.gd")
const SkillData: GDScript = preload("res://scripts/data/skill_data.gd")


static func run() -> bool:
	var ok := true

	# --- (a) no_energy_predicate ---
	ok = _expect(ok, SkillButtonScript.no_energy_predicate(0, 0) == false, "predicate (0,0) == false")
	ok = _expect(ok, SkillButtonScript.no_energy_predicate(0, 180) == false, "predicate (0,180) == false")
	ok = _expect(ok, SkillButtonScript.no_energy_predicate(5, 0) == true, "predicate (5,0) == true")
	ok = _expect(ok, SkillButtonScript.no_energy_predicate(5, 5) == false, "predicate (5,5) == false (energy == cost is enough)")
	ok = _expect(ok, SkillButtonScript.no_energy_predicate(10, 5) == true, "predicate (10,5) == true")

	# --- (b) state_palette("no_energy") ---
	var pal: Dictionary = SkillButtonScript.state_palette("no_energy")
	ok = _expect(ok, pal["bg_color"].is_equal_approx(Color(0.72, 0.62, 0.92)), "no_energy bg_color == (0.72,0.62,0.92)")
	ok = _expect(ok, pal["border_color"].is_equal_approx(Color(0.45, 0.35, 0.75)), "no_energy border_color == (0.45,0.35,0.75)")
	ok = _expect(ok, int(pal["border_width"]) == 2, "no_energy border_width == 2")
	ok = _expect(ok, pal["tag_text"] == "内力不足", 'no_energy tag_text == "内力不足"')

	# --- (c) Luma separation from every existing state ---
	var no_luma: float = pal["bg_color"].get_luminance()
	ok = _expect(ok, absf(no_luma - 0.6629) < 0.001, "no_energy bg luma ~= 0.6629 (got %.4f)" % no_luma)
	var others: Array = ["ready", "cooldown", "phase_locked", "hp_gated", "waiting"]
	for s in others:
		var other: Dictionary = SkillButtonScript.state_palette(s)
		var spread: float = absf(no_luma - other["bg_color"].get_luminance())
		ok = _expect(ok, spread >= 0.10,
				"no_energy vs %s bg luminance spread %.4f >= 0.10" % [s, spread])
	# Tag differs from 锁定 (GOAL 4 proof at the tag level).
	var pl_pal: Dictionary = SkillButtonScript.state_palette("phase_locked")
	ok = _expect(ok, pal["tag_text"] != pl_pal["tag_text"],
			'no_energy tag "内力不足" != phase_locked tag "锁定"')

	# --- (d) derive_state priority chain ---
	ok = _expect(ok, SkillButtonScript.derive_state(false, false, false, true, false) == "no_energy",
			"derive_state no_energy wins over ready")
	ok = _expect(ok, SkillButtonScript.derive_state(true, false, false, true, false) == "phase_locked",
			"derive_state phase_locked wins over no_energy")
	ok = _expect(ok, SkillButtonScript.derive_state(false, true, false, true, false) == "cooldown",
			"derive_state cooldown wins over no_energy")
	ok = _expect(ok, SkillButtonScript.derive_state(false, false, true, true, false) == "hp_gated",
			"derive_state hp_gated wins over no_energy")
	ok = _expect(ok, SkillButtonScript.derive_state(false, false, false, true, true) == "waiting",
			"derive_state waiting override wins over no_energy")
	ok = _expect(ok, SkillButtonScript.derive_state(false, true, false, false, true) == "waiting",
			"derive_state waiting override wins over cooldown (skill_bar_waiting_state shape)")
	ok = _expect(ok, SkillButtonScript.derive_state(true, false, false, false, true) == "waiting",
			"derive_state waiting override wins over phase_locked")
	ok = _expect(ok, SkillButtonScript.derive_state(false, false, false, false, false) == "ready",
			"derive_state all false == ready (cost 0 => never no_energy)")

	# --- (e) GOAL 4 proof: cost > energy -> no_energy, NOT phase_locked ---
	var sk = SkillData.new()
	sk.cost = 10
	var energy: int = 5
	var pred: bool = SkillButtonScript.no_energy_predicate(sk.cost, energy)
	ok = _expect(ok, pred == true, "GOAL4: no_energy_predicate(cost=10, energy=5) == true")
	var state: String = SkillButtonScript.derive_state(false, false, false, pred, false)
	ok = _expect(ok, state == "no_energy", 'GOAL4: derive_state(...) == "no_energy"')
	ok = _expect(ok, state != "phase_locked", 'GOAL4: state != "phase_locked"')

	# --- (f) Scene: _apply_state lands the distinct tag + stylebox overrides ---
	var btn = SkillButtonScene.instantiate()
	btn._apply_state("no_energy")
	ok = _expect(ok, btn.has_theme_stylebox_override("normal"), 'no_energy has_theme_stylebox_override("normal")')
	ok = _expect(ok, btn.has_theme_stylebox_override("disabled"), 'no_energy has_theme_stylebox_override("disabled")')
	ok = _expect(ok, btn.state_tag_text == "内力不足", 'no_energy state_tag_text == "内力不足"')
	ok = _expect(ok, btn.get_node("StateTag").text == "内力不足", 'no_energy StateTag label text == "内力不足"')

	var btn2 = SkillButtonScene.instantiate()
	btn2._apply_state("phase_locked")
	ok = _expect(ok, btn2.state_tag_text == "锁定", 'phase_locked state_tag_text == "锁定"')
	ok = _expect(ok, btn.state_tag_text != btn2.state_tag_text,
			"GOAL4: no_energy tag differs from phase_locked tag on real instances")

	if ok:
		print("PASS: test_skill_button_no_energy")
	else:
		print("FAIL: test_skill_button_no_energy")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_skill_button_no_energy: " + what)
	return ok_so_far and cond
