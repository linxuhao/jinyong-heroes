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
## This round appends the §3.B2 click-priority and Defect-C hover-preview
## pins (test_click_priority.gd, test_trait_hover_preview.gd) to the registry.
extends SceneTree

const TESTS: Array[String] = [
	"res://tests/test_battle_setup.gd",
	"res://tests/test_card_data.gd",
	"res://tests/test_click_priority.gd",
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
	"res://tests/test_trait_hover_preview.gd",
	"res://tests/test_visibility_probe_canvas_layer.gd",
	"res://tests/test_facility_data.gd",
	# touch-reach 2026-08-29: the map screen's click-delegate buttons
	# (TravelButton{i} / EventOptionButton{i} / the three facility delegates)
	# and the FacilityEnterButton guard mirror, proven handler-side.
	"res://tests/test_map_facility_buttons.gd",
	# roster 2026-08-30: pure _compose_body / resolver / read-only pins
	# for the read-only roster panel (scripts/ui/roster_panel.gd).
	"res://tests/test_roster_panel.gd",
	# equipment 2026-08-31: the tier->effect formula module (EquipmentData)
	# and the PlayerProfile.equipped slots (round-trip / hostile / validation).
	"res://tests/test_equipment_data.gd",
	"res://tests/test_player_profile_equipment.gd",
	# equipment battle layer 2026-08-31: BattleSetup.derive_stats with gear
	# bonuses (legacy equality, direction matrix, reversibility, build_character
	# mirrors, tutorial-shape CharacterData defaults).
	"res://tests/test_battle_setup_equipment.gd",
	# map battle 2026-08-31: the huashan_duel roster module (MapBattleData) —
	# exact five-greats roster, unknown-id fail-safe, position invariants.
	"res://tests/test_map_battle_data.gd",
	# R3 deeds schema 2026-09-01: PlayerProfile.deeds choice ledger (default
	# zeros, round-trip, legacy repair, corrupted/negative coercion, JSON).
	"res://tests/test_deeds_persistence.gd",
	# R3 progression math 2026-09-01: the pure-static single numeric source
	# (GRADE_POINTS / mastered_count / mastery_points / work_income /
	# deed_score / readiness_power) — monotonicity + differential asserts only.
	"res://tests/test_progression_math.gd",
	# R3 action rebalance M1 2026-09-01: the per-action yield-curve instrument
	# (36 seeded months × 5 strategies) — prints the yield table and asserts
	# structural facts only (finite/non-negative, mastered-heavy work income >
	# fresh, travel <= 36 events). Never balance literals.
	"res://tests/test_action_yield_curves.gd",
	# R3 fortune reroll 2026-09-01: the pure-static budget curve
	# (fortune 0/5 -> 1, 10 -> 1, 20 -> 2, 30 -> 3; deep_fortune adds exactly 1).
	"res://tests/test_fortune_budget.gd",
	# R3 huashan winnable 2026-09-01: derive_stats mastery terms (mp==0 legacy,
	# strict increase, texture preserved, gear additivity) + readiness verdict
	# (single-source power, weak<even<strong band ordering).
	"res://tests/test_battle_setup_readiness.gd",
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
