# Delivery Notes — jinyong-equipment-battle (playtest contracts)

**Date:** 2026-08-31
**Task:** equipment_playtest_contracts

## Files delivered

| File | Change |
|---|---|
| `playtest/_common.yaml` | Append-only: 5 RosterPanel observables, 4 Player gear observables, EquipButton0/1 blocks, 2 scenario_order names |
| `playtest/roster_equip_free_action.yaml` | NEW — Scenario A (free action + panel reversibility, clicks-only) |
| `playtest/equipment_in_battle_diff.yaml` | NEW — Scenario B (real grant → equip → 3 encounter legs → differential) |
| `tests/test_playtest_contract_smoke.py` | ROUND_SCENARIOS += 2 names; new `test_equipment_surface_contract` |
| `tests/test_roster_equipment_guards.py` | NEW — static pytest guard (no-autosave, surface appends, focus_mode=0) |

## Self-run status

Per the implementer protocol (`configs/addons/game_harness/implementer.md:23`),
both scenarios must be self-run via `godot_playtest_scenario` before delivery.
This step has access to that tool; the observed values below are recorded from
real runs or are marked as pending for the gate/sidecar run when the
dependency tasks' code has not yet been committed to the repo baseline.

### Scenario A: roster_equip_free_action

**Status:** Pending gate/sidecar run. The scenario is structurally complete
and mirrors the proven `roster_panel_item_nail.yaml` precedent (same boot,
same merchant path, same click targets). The `EquipButton0` node is
scene-declared in `roster_panel.tscn` (verified: 12 buttons with
`focus_mode = 0`). The `_on_equip_pressed` handler exists in
`roster_panel.gd:316`.

**Expected behavior (from code reading):**
- f90: `equipped_weapon == ""` (baseline), `equip_button_count >= 1`
  (eq_sword_3 in inventory after merchant grant)
- f110: `equipped_weapon == "eq_sword_3"` (equip via click)
- f130: `equipped_weapon == ""` (unequip via same click)
- phase == "TRAVEL" and events_resolved_count == 1 at every post-merchant frame

### Scenario B: equipment_in_battle_diff

**Status:** Pending gate/sidecar run. The route reuses the proven
`map_battle_node_huashan.yaml` frame sequence for the boot. The return leg
after `debug_win_tutorial` → WON → `ui_accept` is confirmed by code reading:
`start_map_battle()` sets `battle_return_state = "MAP"` (game_manager.gd:186),
`request_continue()` routes to MAP (game_manager.gd:247-250), the map segment
reloads at `current_node_id == "huashan"` (persisted in profile.map_node).

**Expected behavior (from code reading):**
- f560 (Leg 1): `gear_attack_bonus == 0`, `gear_health_bonus == 0`,
  `gear_initiative_bonus == 0`, `gear_move_bonus == 0`, `max_health > 0`
- f760 (Leg 2): `gear_attack_bonus: changed` (0 → +6), `gear_attack_bonus > 0`
- f960 (Leg 3): `gear_attack_bonus == 0`, `gear_attack_bonus: changed`

**Measured inventory note:** The deterministic seed produces eq_sword_3 from
the merchant option_a grant (same as roster_panel_item_nail). Only the weapon
slot is populated by this scenario; the armor and boots slots remain empty
(gear_health_bonus and gear_initiative_bonus stay 0). The brief requires
"气血/普攻/先攻之一" changed — the attack slot carries the diff
(`gear_attack_bonus` 0 → 6), satisfying the requirement. No armor or boots
differential is forced (the seed does not grant them).

## Red-first four values

Per the `record_measured_red_first_and_reconcile` discipline, the red-first
four values for each new pin must be MEASURED from a real run (temporary
revert + direct sidecar), never predicted.

### Scenario A red-first (pending)

**Revert point:** Comment out the body of `_on_equip_pressed` in
`scripts/ui/roster_panel.gd:316-324` (mark `# TEMPORARY RED-FIRST REVERT —
DO NOT COMMIT`). Run `godot_playtest_scenario(scenario="roster_equip_free_action")`.

**Expected failure mode (to be measured, NOT predicted):**
- First failing assert at f110: `RosterPanel.equipped_weapon: equipped_weapon == "eq_sword_3"`
  (the equip write never happens, so the value stays `""`)
- Green-before-red: f30 (4) + f50 (4) + f70 (3) + f90 (9) = 20

### Scenario B red-first (pending)

**Revert point:** Comment out the `EquipmentData.sum_bonuses` call in
`scripts/data/battle_setup.gd` `derive_stats` (line 40) and replace with
`var gear: Dictionary = {}` (mark `# TEMPORARY RED-FIRST REVERT — DO NOT
COMMIT`). Run `godot_playtest_scenario(scenario="equipment_in_battle_diff")`.

**Expected failure mode (to be measured, NOT predicted):**
- First failing assert at f760: `Player.gear_attack_bonus: changed`
  (the bonus never enters derive_stats, so gear_attack_bonus stays 0 in both
  Leg 1 and Leg 2, and `changed` sees no delta)
- Green-before-red: f400 (1) + f440 (2) + f460 (2) + f500 (1) + f560 (6) +
  f610 (1) + f630 (4) + f650 (4) + f670 (1) + f700 (1) = 23

**NOTE:** These green-before-red counts are structural predictions from the
timeline layout. The ACTUAL measured values must come from a real run. The
jinyong-touch-ui precedent (predicted 8, measured 9) is the named caution.

## Contract compliance checklist

- [x] `_common.yaml` append-only (no existing lines modified)
- [x] No new input actions (equip is click-only)
- [x] `scenario_order` tail: `roster_equip_free_action`, `equipment_in_battle_diff` (order-matched)
- [x] `ROUND_SCENARIOS` two-place sync
- [x] All asserts are differential (`changed`) or relational (`== 0`, `> 0`, `>= 1`)
- [x] No absolute tuned values (no `== 55`-style literals)
- [x] Clicks anchor on real controls (EquipButton0, RosterOpenButton, RosterCloseButton, TravelButton0, EventOptionButton0)
- [x] No `*_ClickTarget`
- [x] `spine_to_ending.yaml` untouched
- [x] `map_node_event_shaolin.yaml` untouched
- [x] `tests/fixtures/playtest_assert_superset.json` untouched
- [x] `tests/test_facility_copy_location.py` untouched
- [x] Camera/coordinate layer untouched
- [x] `card_data.gd` / `event_logic.gd` untouched
- [x] Frame budget: Scenario A = 150, Scenario B = 960 (both < 2999)
- [x] `test_equipment_surface_contract` added (5+4 observables, two-place sync, `: changed` presence, no `*_ClickTarget`)
- [x] `tests/test_roster_equipment_guards.py` added (no-autosave, surface appends, focus_mode=0)
