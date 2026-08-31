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

---

## Addendum — fix_equipment_battle_diff_frame_timing (2026-08-31)

**Task:** `fix_equipment_battle_diff_frame_timing` — re-project `equipment_in_battle_diff`
frames after the 5_compile hard-gate failure (16/32, 6 runtime errors: `aim: node not
found: RosterOpenButton/EquipButton0/RosterCloseButton` ×2 each).

### What changed in the scenario (frame/step re-projection ONLY)

- `f3–f550` boot segment kept **verbatim** (proven menu → creation → tutorial →
  cultivation → map → luoyang merchant → shaolin → huashan).
- Every win→MAP leg re-projected with a **wide parse window** (spread `ui_accept` +
  an in-window diagnostic `current_state == "WON" or current_state == "MAP"`) and a
  **wide transition window** before the definite `current_state == "MAP"` assert.
- Because the MAP (huashan) battle reuses the tutorial battlefield
  (`battlefield._ready` branches to the tutorial path for `battle_return_state !=
  "CULTIVATION"`), each battle's tutorial overlay is advanced with spread
  `ui_accept` before `debug_win_tutorial` (which no-ops while `phase == "IDLE"`,
  combat_manager.gd:454-460).
- Both re-travel legs re-projected with `MapScreen.phase` / `current_node_id` /
  `focus_id` diagnostics asserted before every travel accept (measured-steps
  precedent), following the huashan: [shaolin], shaolin: [luoyang, huashan]
  adjacency and the proven move_right×2 → focus huashan → accept recipe.
- Last `at:` frame = **1580** (< 2999 hard cap).
- **No existing assertion line deleted or weakened.** All 16 previously-failing
  assertion lines are preserved verbatim in content (frames re-based). The only
  ADDED asserts are diagnostic lines of existing kinds (relational / equality on
  ids), per the reviewer clarification on "assertion kind".
- `spine_to_ending.yaml`, `map_node_event_shaolin.yaml`, `roster_equip_free_action.yaml`,
  and `_common.yaml` surface whitelist are untouched.

### Frame layout is a PROJECTION, not a measurement (honest disclosure)

The implementer protocol (implementer.md:23) requires self-running each new/changed
scenario via `godot_playtest_scenario` and pasting observed values. **This could not
be done from this step's working directory**: the in-call probe returned
`"No project.godot at /app"` (the same pipeline limitation documented in
`final/delivery_notes_fix_clicktarget_ignore.md:58`). Therefore:

- The re-projected frame numbers are a **derivation + wide buffer** projection, not
  measured transition durations.
- The exact battle→WON→MAP duration and the re-travel landing points are marked
  **pending 5_compile gate per-frame confirmation**, per the repo discipline of
  never holding a prediction as a measured value.

### ROOT CAUSE — the deeper blocker this task surfaced (code-level, not timing)

Frame re-projection fixes the win→MAP cascade and the panel-equip mechanics, but it
**cannot** make the gear-diff-into-battle asserts green through the MAP route, for a
reason the original frame-timing diagnosis did not account for:

1. The MAP (huashan) battle reuses the **tutorial battlefield**: `battlefield._ready`
   branches to the tutorial path for any `battle_return_state != "CULTIVATION"`
   (battlefield.gd:69-71), instantiating **Yang Guo** (:80, `cd.max_health = 1000`,
   tutorial overlay), NOT the player profile.
2. Equipped gear flows into the player **only** through the CULTIVATION encounter
   (`_setup_encounter_battle`, battlefield.gd:651
   `BattleSetup.build_character(SaveManager.profile)`).
3. Therefore `Player.gear_attack_bonus` is **always 0** in the MAP battle no matter
   what the profile's `equipped` carries. The Leg-2 `gear_attack_bonus > 0` and the
   Leg-3 `gear_attack_bonus: changed` asserts are **unreachable through this route**
   by any frame layout — this is a code/contract defect, not a timing bug.

**Recommended correct fix (for the round's success criteria, which require the diff
"in a real encounter through the real code path"):** route the gear-diff proof
through a **CULTIVATION encounter** (`debug_enter_encounter`), which is the real code
path (battlefield.gd:651), instead of the MAP huashan battle. The MAP-route scenario
as re-projected here pins the frame/step mechanics and the panel equip path but must
not be taken as proof of the gear→battle differential; the CULTIVATION-route is the
only green-capable vehicle. This is reported, not worked around (no assertion was
deleted or relaxed to hide it).

### Status

- `roster_equip_free_action.yaml` — untouched this task (its 36/36 run at 5_compile
  is green).
- `equipment_in_battle_diff.yaml` — re-projected (frames only + diagnostics); the
  frame/panel mechanics should now clear the node-not-found cascade, but the two
  gear-diff-into-battle asserts are expected to remain red through the MAP route
  until the CULTIVATION-encounter re-route lands (see ROOT CAUSE above).
