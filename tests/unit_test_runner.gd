## Static unit-test collector for the Godot test gate.
##
## Run from the repo root (project autoloads are loaded by -s mode, but this
## runner does not depend on any of them):
##   godot --headless --path . -s res://tests/unit_test_runner.gd
##
## Contract of every collected file: a top-level `static func run() -> bool`
## that push_error()s on failure and returns true iff all checks passed.
## The two SceneTree-style integration tests (test_save_manager.gd,
## test_game_manager_fsm.gd) are NOT collected here — run_tests.sh drives each
## of them with its own `-s` invocation, because they need a full deferred
## SceneTree lifecycle and their own quit() exit codes.
##
## Load order is the explicit TESTS registry below (deterministic, no
## reflection/scanning). A file that fails to load, whose run() returns false,
## or whose run() raises a runtime error (the call then yields null -> FAIL)
## makes the whole gate exit 1.
extends SceneTree

const TESTS: Array[String] = [
	"res://tests/test_battle_setup.gd",
	"res://tests/test_card_data.gd",
		"res://tests/test_creation_info_texts.gd",
	"res://tests/test_event_data.gd",
	"res://tests/test_gongfa_cascade.gd",
	"res://tests/test_health_bar.gd",
	"res://tests/test_health_bar_text.gd",
	"res://tests/test_map_data.gd",
	"res://tests/test_map_node_event.gd",
	"res://tests/test_player_profile.gd",
	"res://tests/test_progression_gongfa_data.gd",
	"res://tests/test_qi_costs_match_design.gd",
	"res://tests/test_skill_button_info.gd",
	"res://tests/test_skill_button_no_energy.gd",
	"res://tests/test_skill_button_states.gd",
	"res://tests/test_settings_title_overlap.gd",
	"res://tests/test_theme_font.gd",
	"res://tests/test_trait_data.gd",
	"res://tests/test_trait_effects.gd",
	"res://tests/test_visibility_probe_canvas_layer.gd",
]


func _initialize() -> void:
	# Defer so the root tree (and every autoload) is fully up before running.
	call_deferred("_run")


func _run() -> void:
	var passed := 0
	var failed := 0
	for path in TESTS:
		var script: GDScript = load(path)
		if script == null:
			push_error("unit_test_runner: failed to load " + path)
			print("FAIL " + path.get_file().get_basename())
			failed += 1
			continue
		# Static func run() -> bool, invoked directly on the GDScript resource.
		# If run() raises at runtime, Godot logs the error and the call yields
		# null here, which is falsy -> counted as FAIL (exit 1).
		var ok = script.run()
		if ok == true:
			print("PASS " + path.get_file().get_basename())
			passed += 1
		else:
			print("FAIL " + path.get_file().get_basename())
			failed += 1
	print("UNIT TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
