# Delivery Notes — focus_marker_nail (jinyong-theme round)

**Date:** 2026-09-01
**Task:** `focus_marker_nail` — differential focus-marker nail scenario + surface append + contract sync + measured red-first.

## What was built

1. **`playtest/_common.yaml` — two append-only edits (no existing line touched):**
   - `  - focus_marker_active` appended to the `CultivationScreen:` surface block, immediately after the existing `  - focused_option_text` (now **line 782**; `MapScreen:` shifts to 783). The new observable is a real published render state — `var focus_marker_active: bool` in `scripts/segments/cultivation.gd` (declared :136, driven by the same `focused` bool that selects the stylebox in `_rebuild_options_box` :661, mirrored in `_render` :951).
   - `- theme_focus_marker_cultivation` appended to the tail of `scenario_order:` (now **line 1135**, the new last line), after `- event_pool_new_event_resolved`.

2. **`playtest/theme_focus_marker_cultivation.yaml` — new scenario** (basename == `name:`). Boots `menu.tscn`, seeds a fresh no-sect CULTIVATION save via `debug_seed_save` (f30), CLICKs `MenuEntry1` (f50) into CULTIVATION (mirrors `clicks_only_gongfa_empty_exit` verbatim), asserts CARD_PICK at f80, clicks `CultOptionButton0` (f90) -> ACTION_PICK, then:
   - f110: `phase == "ACTION_PICK"`, `focus_marker_active == true`, `focused_option_text != ""`, `CultOptionButton0.visible == true`.
   - f120: `move_down` (the keyboard twin of the clicks-only mirror — the focus marker is a keyboard-cursor property).
   - f140: `option_focus == 1` (cursor actually moved), `focused_option_text: changed` (mandatory differential — the focused text followed the cursor), `focus_marker_active == true` (the marker FOLLOWS the cursor — a differential on a real published surface, never a stuck constant).
   - f150 click `CultOptionButton0` (练功, index 0) -> f170 `phase == "GONGFA_PICK"` (a real click still advances the phase — the marker never blocks clicking).
   - **Zero** absolute style/color/alpha assertions (`== Color(...)` / stylebox-existence pins).

3. **`tests/test_playtest_contract_smoke.py` — two-place sync:**
   - `"theme_focus_marker_cultivation"` appended to the **tail** of `ROUND_SCENARIOS` (after `"event_pool_new_event_resolved"`), keeping the order match with `scenario_order` required by `test_round_scenarios_present_on_disk_and_in_order`.
   - New `FOCUS_MARKER_SURFACE_VARS` tuple + new `test_focus_marker_surface_contract()` (following the `FACILITY_SURFACE_VARS` / `_items_under` / `_surface_blocks` pattern): asserts `focus_marker_active` is whitelisted under the `CultivationScreen` block, the scenario is in `scenario_order` AND `ROUND_SCENARIOS`, the file exists with `name:` == basename, every timeline `at:` is a single int, and the file carries the mandatory `: changed` differential line.
   - Static verification (no pytest runner in this step — the real run is the 5_test gate): the test references only module-level names that already exist (`COMMON`, `PLAYTEST_DIR`, `ROUND_SCENARIOS`, `_surface_blocks`, `_items_under`, `re`, plus the new tuple); the four guard tests it feeds (`test_round_scenarios_present_on_disk_and_in_order`, `test_scenario_order_names_have_files`, `test_timeline_at_values_are_integers`, and the new `test_focus_marker_surface_contract`) all pass by construction. `test_whitelisted_observables_exist_in_scripts` is unaffected — `CultivationScreen` is not in `BLOCK_SCRIPT_MAP`, so the new whitelist entry is not var-checked against a mapped script.

## MEASURED RED-FIRST (two real runs, never a prediction)

**RED run** — `godot_playtest_scenario(scenario="theme_focus_marker_cultivation")` with the TEMPORARY RED-FIRST REVERT applied (see recipe below). Direct sidecar call (the same external impl the 5_compile gate drives). Result: **FAIL 12/14**.

| value | measured |
|---|---|
| failing_frame | **f110** |
| first_failing_assert | `CultivationScreen.focus_marker_active: focus_marker_active == true` |
| exact_error / observed | `observed=false` (focus_marker_active was false — the revert neutralized its publication) |
| green_asserts_before_red | **7** (f80 has 6 + f110 `phase == "ACTION_PICK"` = 7) |

Second red (same root cause): f140 `CultivationScreen.focus_marker_active` `observed=false`. Total 12/14.

**Honest finding on the revert scope (deviation from the literal recipe, documented):** `focus_marker_active` is published **independently** of the stylebox swap — `_rebuild_options_box` sets it from `not labels.is_empty()` (cultivation.gd:661) and `_render` mirrors it from `focused_option_text != ""` (:951). So reverting ONLY the stylebox swap to the old modulate ternary (plus the `option_style()` stub) would leave `focus_marker_active` reading `true` and the f110 `== true` assert would **NOT** red — the whole scenario would stay green, defeating the red-first. To produce a genuine pre-fix red (the modulate-only world in which no real marker is active), the revert ALSO set BOTH `focus_marker_active` publications to `false`. This is the faithful simulation of "no marker published", and it is what made the f110 assert red.

**Revert recipe (all touched lines marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`):**
- `scripts/segments/cultivation.gd` `_rebuild_options_box`: replaced the `var focused:` + `add_theme_stylebox_override("normal", …)` + `add_theme_color_override("font_color", …)` swap with `btn.modulate = Color(1, 1, 1) if i == _focused_index_for_phase() else Color(0.72, 0.72, 0.72)` (the old 2–3% brightness cue); AND set both `focus_marker_active` publications (end of `_rebuild_options_box` and end of `_render`) to `false`.
- `scripts/autoload/theme_manager.gd` `option_style(focused)`: stubbed to return the plain box for both true/false.

**Restore:** all four edits reversed byte-exactly (context-anchored so each reverse `old_str` matched exactly once). Restore verification: `grep "TEMPORARY RED-FIRST REVERT"` over `scripts/**/*.gd` -> **zero hits**. The only remaining `focus_marker_active = false` is cultivation.gd:591, the ORIGINAL `box == null` defensive early-return path (pre-existing, not revert residue).

**Green re-runs on the byte-exact-restored tree (this step, godot_playtest_scenario sidecar):**

| scenario | asserts | result |
|---|---|---|
| theme_focus_marker_cultivation | 14/14 | PASS (restored GREEN) |
| clicks_only_gongfa_empty_exit | 16/16 | PASS (revert-residue proof) |
| spine_to_ending | 42/42 | PASS (revert-residue proof) |

## Scope discipline
- Locked files untouched and byte-identical: `scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`.
- No other playtest yaml edited; no assertion in an existing scenario changed.
- EN/i18n untouched — zero new strings (the focus marker is colors/shapes only; `move_down` and `debug_seed_save` were already in the actions list, and `move_down` in `project.godot [input]`).
- At task end `scripts/` are byte-identical to task-start (restore verified); the only text carriers of the measured evidence are this delivery note and the scenario-header RED-FIRST EVIDENCE block.
- `design/` docs (changelog / roadmap / ux_backlog) belong to 5_design, not this task — untouched.
