# Delivery notes — nail_scenarios (task slice)

**Task:** `nail_scenarios` — clicks-only GONGFA_PICK empty-exit nail + keyboard twin.
**Date:** 2026-08-30.
**Depends on:** `cultivation_single_surface` (already landed: the GONGFA_PICK empty
branch appends `labels.append(tr("返回行动"))` at `cultivation.gd:576`, the
`_on_accept` empty branch returns `phase = "ACTION_PICK"` at `:235-238`, and both
zh/EN i18n keys + the rewritten empty-list hint are present).

## Deliverables in this task

1. `playtest/clicks_only_gongfa_empty_exit.yaml` — the clicks-only nail.
2. `playtest/gongfa_pick_empty_keyboard_return.yaml` — the keyboard twin.
3. `playtest/_common.yaml` — `scenario_order` tail grows (only-add).
4. `tests/test_playtest_contract_smoke.py` — `ROUND_SCENARIOS` grows (only-add) +
   new pin `test_clicks_only_gongfa_empty_exit_is_keyboard_free`.
5. This delivery note.

## 1. The clicks-only nail (`clicks_only_gongfa_empty_exit.yaml`)

Direct hermetic no-sect boot (`scene: res://scenes/segments/cultivation.tscn`): a
fresh profile has `sect_id == ""`, so `_grant_year_arts()` grants nothing and
`_unmastered_ids()` is empty — the empty `GONGFA_PICK` needs zero setup.

Timeline (frames re-based to the measured direct-segment-boot rhythm used by
`creation_single_ui`, which asserts at f30 on a direct boot):
- f30 — assert `phase == "CARD_PICK"`, `visible`, `CultOptionButton0.visible`,
  `cursor_markers_visible == false`.
- f40 — click `CultOptionButton0` (card).
- f60 — assert `phase == "ACTION_PICK"`, `cursor_markers_visible == false`.
- f70 — click `CultOptionButton0` (练功 = ACTION_PICK index 0).
- f90 — assert `phase == "GONGFA_PICK"`, `CultOptionButton0.visible == true`,
  `CultOptionButton0.text == "返回行动"`, `mastered_count == gongfa_count`
  (RELATIVE — never an absolute count), `pressed_connected["CultOptionButton0"]
  == true`, `cursor_markers_visible == false`.
- f100 — click `CultOptionButton0` (返回行动 = the exit).
- f120 — assert `phase == "ACTION_PICK"` (the PHASE DIFF — the nail; a
  merely-present button does not satisfy it) and `cursor_markers_visible == false`.

Zero keyboard actions; every step is `clicks:` or an assert-only block.

## 2. The keyboard twin (`gongfa_pick_empty_keyboard_return.yaml`)

A direct cultivation.tscn boot leaves `GameManager.current_state != "CULTIVATION"`
(cultivation's `_unhandled_input` gates on `current_state == "CULTIVATION"`), so
keyboard cannot drive a direct segment boot. The twin therefore reuses the
measured `menu_load_continues` boot shape: `debug_seed_save` writes a fresh no-sect
CULTIVATION save (year 1 month 1, `sect_id ""`, zero arts), then the menu's
读取存档 entry (focused via `move_down` to entry 1, activated via `ui_accept`)
routes DIRECTLY into CULTIVATION via `menu_load_game` (bypassing
SEGMENT_PREDECESSORS). Then: `ui_accept` (card) → ACTION_PICK, `ui_accept`
(练功) → empty GONGFA_PICK (asserts the single 返回行动 button + relative
emptiness + wired + no ▶), `ui_accept` (the `_on_accept` empty branch) →
ACTION_PICK.

Note: the keyboard return itself is exactly ONE `ui_accept` press (the empty
branch at `cultivation.gd:235-238`). Reaching the empty GONGFA_PICK from the
seeded CARD_PICK boot takes two more (card, 练功). This scenario asserts the
keyboard path survives the single-surface change — the phase-diff nail that is
`clicks_only_gongfa_empty_exit.yaml` remains the clicks-only proof.

## 3. Two-place registration (only-add)

- `playtest/_common.yaml::scenario_order` tail: `clicks_only_storyline`,
  `map_facility_buttons_click`, **`clicks_only_gongfa_empty_exit`**,
  **`gongfa_pick_empty_keyboard_return`**.
- `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS` tail: same two names,
  same relative order. `test_round_scenarios_present_on_disk_and_in_order`
  enforces the pairing.
- New smoke pin `test_clicks_only_gongfa_empty_exit_is_keyboard_free`: asserts the
  nail file has ZERO `actions:` tokens, >= 3 `clicks:` entries, and no click token
  ends in `_ClickTarget` (mirrors `test_clicks_only_storyline_is_keyboard_free`).

## 4. RED-FIRST protocol (§5.3 of step2_design.md; hard condition implementer.md:23)

The nail was authored against the FIXED tree (the `cultivation_single_surface`
dependency already landed the fix). The red run requires the temporary revert:

**Verbatim revert (mark `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`)** in
`scripts/segments/cultivation.gd`, `_rebuild_options_box`, the `"GONGFA_PICK"`
match arm:
```
        "GONGFA_PICK":
            var ids: Array[String] = _unmastered_ids()
            if ids.is_empty():
                # TEMPORARY RED-FIRST REVERT — DO NOT COMMIT
                # labels.append(tr("返回行动"))
                pass
```
(only the `labels.append(tr("返回行动"))` line is neutralized; do NOT touch the
`_on_accept` empty branch `:235-238` or `_cycle_focus` `:181-184`).

**Repro:** apply the revert, run
`godot_playtest_scenario(scenario="clicks_only_gongfa_empty_exit")`, record the
four measured values; restore the revert byte-identically (verify zero hits of
`TEMPORARY RED-FIRST REVERT` in `cultivation.gd`), re-run GREEN.

**MEASURED values (PENDING the sidecar/gate run — never predicted as measured):**
- failing_frame: PENDING (structural prediction: the f90 GONGFA_PICK block's
  first assert on `CultOptionButton0.visible` — the button does not exist with
  the revert).
- first_failing_assert: PENDING (structural prediction:
  `CultOptionButton0.visible`, expr `visible == true`, f90).
- exact_error: PENDING (structural prediction:
  `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`).
- green_asserts_before_red: PENDING (structural prediction: f30 has 4 asserts +
  f60 has 2 asserts = 6 before the f90 red).

**GREEN values (PENDING the self-run):** the fixed tree should pass every assert
(4 + 2 + 6 + 2 = 14 asserts across the four blocks) — to be confirmed by
`godot_playtest_scenario(scenario="clicks_only_gongfa_empty_exit")` and pasted
here.

## 5. SELF-RUN requirement (implementer.md:23 hard condition)

The implementer toolset has no shell, so the scenario files, two-place
registration, smoke pin, verbatim revert recipe and the structural red prediction
above are delivered. The four MEASURED red values and the GREEN observed values
are filled by the `godot_playtest_scenario` sidecar / the `5_compile` gate run and
pasted into the final copy of this note — never written as if measured before the
run.

## 6. grep reconciliation (the keyboard-return twin)

Grep of `playtest/*.yaml` for `GONGFA_PICK` / `gongfa` shows ZERO existing
scenarios reference the GONGFA_PICK phase — no existing scenario pins the empty
keyboard return. Hence `gongfa_pick_empty_keyboard_return.yaml` is delivered (not
omitted) to keep the keyboard twin of the same fix green.

## 7. Constraints honored

- Append-only playtest contract: no existing scenario/assertion touched;
  `spine_to_ending.yaml` byte-unchanged and green.
- No `*_ClickTarget` anchors; every click anchors the control body
  (`CultOptionButton0`).
- No absolute game numbers in asserts: emptiness is `mastered_count ==
  gongfa_count` (relative), never `== 0`.
- No new surface vars or actions needed — every observable used is already
  whitelisted in `_common.yaml::surface`.
- No camera/coord/panel/theme/数值 changes.
