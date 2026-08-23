## Unit tests for the theme_font display-layer helpers.
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by a later subtask; this file only delivers the
## script plus the assertion contract from task_plan.md acceptance criterion 2.
##
## The fahui formatter is a pure static function on SkillButton (extends
## Button), so it is testable without instantiating any scene. Only
## exactly-representable decimals are used (0.9 / 1.0 / 1.2 / 1.3 / 2.0) so the
## `%.1f` formatting is unambiguous.

const SkillButton = preload("res://scripts/ui/skill_button.gd")


static func run() -> bool:
	var ok := true

	ok = _expect(ok, SkillButton.fa_hui_du_label(0.9) == "失常 ×0.9",
		"fa_hui_du_label(0.9) == 失常 ×0.9")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.0) == "正常 ×1.0",
		"fa_hui_du_label(1.0) == 正常 ×1.0")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.2) == "正常 ×1.2",
		"fa_hui_du_label(1.2) == 正常 ×1.2")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.3) == "超常 ×1.3",
		"fa_hui_du_label(1.3) == 超常 ×1.3")
	ok = _expect(ok, SkillButton.fa_hui_du_label(2.0) == "超常 ×2.0",
		"fa_hui_du_label(2.0) == 超常 ×2.0")

	# Band boundaries are exclusive the same way setup() applies them: < 1.0 is
	# 失常, 1.0..1.2 is 正常, > 1.2 is 超常.
	ok = _expect(ok, SkillButton.fa_hui_du_label(0.99) == "失常 ×1.0",
		"fa_hui_du_label(0.99) == 失常 ×1.0")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.21) == "超常 ×1.2",
		"fa_hui_du_label(1.21) == 超常 ×1.2")

	if ok:
		print("PASS: test_theme_font")
	else:
		print("FAIL: test_theme_font")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_theme_font: " + what)
	return ok_so_far and cond
