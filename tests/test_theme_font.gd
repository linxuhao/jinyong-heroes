## Unit tests for the theme_font display-layer helpers.
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh by a later subtask; this file only delivers the
## script plus the assertion contract from task_plan.md acceptance criterion 2.
##
## The fahui formatter is a pure static function on SkillButton (extends
## Button), so it is testable without instantiating any scene. Exactly
## representable decimals are used throughout, so the %.2f-then-strip
## formatting is unambiguous for every asserted value.

const SkillButton = preload("res://scripts/ui/skill_button.gd")


static func run() -> bool:
	var ok := true

	ok = _expect(ok, SkillButton.fa_hui_du_label(0.9) == "发挥 ×0.9",
		"fa_hui_du_label(0.9) == 发挥 ×0.9")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.0) == "发挥 ×1.0",
		"fa_hui_du_label(1.0) == 发挥 ×1.0")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.2) == "发挥 ×1.2",
		"fa_hui_du_label(1.2) == 发挥 ×1.2")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.3) == "发挥 ×1.3",
		"fa_hui_du_label(1.3) == 发挥 ×1.3")
	ok = _expect(ok, SkillButton.fa_hui_du_label(2.0) == "发挥 ×2.0",
		"fa_hui_du_label(2.0) == 发挥 ×2.0")

	# Two-decimal cascade values render exactly (0.85 = 缺1 ladder,
	# design/10_systems.md §4): the formatter uses %.2f then strips trailing
	# zeros, so 0.99 -> "0.99" and 1.21 -> "1.21" (never rounded to 1 decimal).
	ok = _expect(ok, SkillButton.fa_hui_du_label(0.99) == "发挥 ×0.99",
		"fa_hui_du_label(0.99) == 发挥 ×0.99")
	ok = _expect(ok, SkillButton.fa_hui_du_label(1.21) == "发挥 ×1.21",
		"fa_hui_du_label(1.21) == 发挥 ×1.21")

	if ok:
		print("PASS: test_theme_font")
	else:
		print("FAIL: test_theme_font")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_theme_font: " + what)
	return ok_so_far and cond
