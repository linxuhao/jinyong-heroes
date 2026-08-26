## Unit tests for the additive skill-button info layer (UX-03).
## Contract: top-level static func run() -> bool; push_error on failure;
## print PASS/FAIL at the end; never relies on assert() (stripped in release).
## Collected into run_tests.sh via unit_test_runner.gd's TESTS registry.
##
## This round is presentation-only: the skill button gains a per-skill inner-force
## cost label and an on-face effect summary. Both are pure static functions on
## skill_button.gd — cost_label_text() renders the cost line from SkillData.cost
## (0 = undefined/no cost -> "无消耗"), and effect_summary() derives a short
## Chinese line from EXISTING SkillData numbers (damage / heal_amount / aoe_shape /
## jump_tiles). Numbers are presented verbatim, never invented. The state machine
## (state_palette / state_luma_value) is UNCHANGED this round, so this file
## deliberately asserts nothing about any state palette.
##
## Fully headless: preloads the GDScript and calls the statics directly; a real
## tutorial SkillData Resource (重剑无锋 = damage 45, aoe_shape "single") is built
## with SkillDataClass.new() to pin the "单体 45" summary.

const SkillButtonScript: GDScript = preload("res://scripts/ui/skill_button.gd")
const SkillDataClass: GDScript = preload("res://scripts/data/skill_data.gd")


static func run() -> bool:
	var ok := true

	# --- cost_label_text: 0 -> "无消耗", n > 0 -> "内力 <n>" ---------------
	ok = _expect(ok, SkillButtonScript.cost_label_text(0) == "无消耗",
			'cost_label_text(0) == "无消耗"')
	ok = _expect(ok, SkillButtonScript.cost_label_text(25) == "内力 25",
			'cost_label_text(25) == "内力 25"')

	# --- effect_summary on a real tutorial SkillData (重剑无锋) ------------
	# damage 45, range 1, cooldown 1, aoe_shape "single", knockback 1 ->
	# effect_summary == "单体 45".
	var skill = SkillDataClass.new()
	skill.damage = 45
	skill.aoe_shape = "single"
	var summary: String = SkillButtonScript.effect_summary(skill)
	ok = _expect(ok, summary == "单体 45", 'effect_summary(重剑无锋) == "单体 45" (got "%s")' % summary)
	ok = _expect(ok, not summary.is_empty(), "effect_summary(重剑无锋) non-empty")
	ok = _expect(ok, summary.length() <= 6,
			"effect_summary(重剑无锋) length() <= 6 (got %d)" % summary.length())
	ok = _expect(ok, summary.contains("45"),
			'effect_summary(重剑无锋) contains "45" (got "%s")' % summary)

	# --- effect_summary(null) == "" (graceful undefined) --------------------
	ok = _expect(ok, SkillButtonScript.effect_summary(null) == "",
			'effect_summary(null) == ""')

	if ok:
		print("PASS: test_skill_button_info")
	else:
		print("FAIL: test_skill_button_info")
	return ok


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_skill_button_info: " + what)
	return ok_so_far and cond
