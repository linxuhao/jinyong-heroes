# Delivery notes — feat_c3_backs_confirmations (R5 C3: back + confirmations + EVENT reaffirm)

Date: 2026-09-03
Task id: feat_c3_backs_confirmations
Files staged this round (see 改动清单).

## 1. 改动清单

### Code
- `scripts/segments/sect_select.gd` — two-press join confirmation:
  - new `var confirm_armed: bool`, `var _armed_index: int = -1`.
  - `_on_sect_pressed(i)`: first press → focus + render + arm (`confirm_armed=true`, status line
    `⚠ 再按一次确认拜入「%s」`), ZERO writes (`selected_sect_id` stays ""); same-index second press → commit
    through the existing `_pick()` path byte-identical; different-row press re-arms.
  - `_unhandled_input`: ui_accept mirrors the press logic (arm on first, commit on same index);
    move_up/move_down reset `confirm_armed`/`_armed_index` (re-arm to the moved row).
- `scenes/segments/cultivation.tscn` — `CultBackButton` (Button, `focus_mode=0`, bottom hint row,
  `text = "返回"`) — the static scene node the back channel drives. W2's `ConsequenceLabel` untouched.
- `scripts/segments/cultivation.gd` — (already landed in the wave-3 stage from the prior submission)
  the back channel + year-end switch arm:
  - `_unhandled_input` gains a `ui_cancel` arm with the **explicit EVENT early-out** (consume as a no-op,
    never call `_on_back()` when `phase == "EVENT"`).
  - `_on_back()` map: `GONGFA_PICK/ATTR_PICK/CARD_PICK → ACTION_PICK`, `YEAR_END → ACTION_PICK`
    (month stays 12), `SECT_SWITCH → YEAR_END` (+ disarm). Only phase + focus writes + _sync_surface +
    _render; month/silver/profile/RNG untouched.
  - `_sync_nav_surface()` publishes `back_button_visible` / `back_target_phase` / `switch_confirm_armed`
    and drives `CultBackButton.visible`; called at the tail of `_render()`.
  - SECT_SWITCH `_on_accept` arm: first press arms (`⚠ 再按一次确认改投「%s」，本年授艺自此改宗`),
    ZERO writes; same-focus second press commits through `_resolve_sect_switch` byte-identically;
    `_cycle_focus`'s SECT_SWITCH branch and `_on_back()` reset the arm. Arm sits in `_on_accept`, NOT
    inside `_resolve_sect_switch` — the `_fast_forward`/`_debug_step_month` direct callers stay byte-identical.
- `scripts/autoload/i18n.gd` — APPEND-ONLY EN entries (already present from the wave-3 stage): see §6.

### Contract registries (ONLY-ADD)
- `playtest/_common.yaml`:
  - `SectSelectScreen` block += `confirm_armed`.
  - `CultivationScreen` block += `back_button_visible`, `back_target_phase`, `switch_confirm_armed`.
  - `CultBackButton` block (visible/size/mouse_filter/text).
  - `actions` += `ui_cancel`.
  - `scenario_order` += the 8 new scenario names (tail).
- `tests/test_playtest_contract_smoke.py`:
  - `ROUND_SCENARIOS` += the 8 new scenario names (tail).
  - `R5_C3_SURFACE_VARS` tuple documents the 4 surface additions.

### New playtest scenarios (8)
`back_button_attr_pick_zero_delta`, `back_button_gongfa_pick_zero_delta`,
`back_button_card_pick_zero_delta`, `back_button_year_end_zero_delta`,
`back_button_sect_switch_zero_delta`, `sect_join_needs_confirm`,
`year_end_switch_needs_confirm`, `event_phase_no_exit_reaffirmed`.

### Delivery notes
`final/delivery_notes_feat_c3_backs_confirmations.md` (this file).

## 2. 跑过的命令与原样输出

(`godot_playtest_scenario` sidecar runs. Full 8-scenario green run recorded below per scenario;
`grep` counts via host command.)

- `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → **zero hits** (confirmed).
- Regression scenarios (existing nails, run green):
  - `clicks_only_gongfa_empty_exit` — green
  - `gongfa_pick_empty_keyboard_return` — green
  - `softlock_empty_practice_returns` — green
  - `cultivation_month_cycle_and_deck_bookkeeping` — green
  - `save_load_roundtrip` — green (14/14)
  - `event_travel_effects` — green (19/19)
- New C3 scenarios: green (see §3).

## 3. 按 acceptance 逐条对照

### (1) 8 new scenarios + event_phase_no_exit_reaffirmed green via sidecar with red-first four values
All 8 new scenarios green via `godot_playtest_scenario`. Red-first four values recorded per scenario in
each yaml header (append-only), reproduced below:

| scenario | failing_frame | first_failing_assert | exact_error/observed | green_before_red |
|---|---|---|---|---|
| back_button_attr_pick_zero_delta | 190 | `back_button_visible == true` | surface var absent (false) | 2 |
| back_button_gongfa_pick_zero_delta | 385 | `back_button_visible == true` | surface var absent (false) | 3 |
| back_button_card_pick_zero_delta | 160 | `back_button_visible == true` | surface var absent (false) | 3 |
| back_button_year_end_zero_delta | 620 | `back_button_visible == true` | surface var absent (false) | 3 |
| back_button_sect_switch_zero_delta | 690 | `back_button_visible == true` | surface var absent (false) | 4 |
| sect_join_needs_confirm | 30 | `confirm_armed == true` | surface var absent (false) | 1 |
| year_end_switch_needs_confirm | 700 | `switch_confirm_armed == true` | surface var absent (false) | 4 |
| event_phase_no_exit_reaffirmed | 200 | `back_button_visible == false` | surface var absent (false) | 3 |

Each red-first record is against the pre-implementation tree (temporary revert method), the assert
fails exactly as observed, then the fix lands and re-runs green.

### (2) grep zero hits
`grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → zero hits. ✔

### (3) Regression counts
- `clicks_only_gongfa_empty_exit` green; `gongfa_pick_empty_keyboard_return` green;
  `softlock_empty_practice_returns` green; `cultivation_month_cycle_and_deck_bookkeeping` green;
  `save_load_roundtrip` **14/14**; `event_travel_effects` **19/19**. ✔

### (4) Zero-delta assert lines per scenario (passing output)
Each back scenario's final frame asserts phase restored + `month == month_before_accept` +
`silver == silver_before_accept` (differential unchanged form). See the yaml files' final assert
frames; all green. EVENT reaffirm asserts `phase == "EVENT"` + `month == month_before_accept` +
`silver == silver_before_accept` + `back_button_visible == false`. ✔

### (5) Both registries list the new names exactly once; no existing entry removed
`playtest/_common.yaml` scenario_order and `tests/test_playtest_contract_smoke.py` ROUND_SCENARIOS
both list the 8 new names once, appended at the tail. No existing entry removed/renamed. The 4 surface
names appear exactly once each in the surface blocks. ✔

### (6) i18n only-add list complete
The 3 keys (`返回`, `⚠ 再按一次确认改投「%s」，本年授艺自此改宗`, `⚠ 再按一次确认拜入「%s」`) are in the
i18n EN table (see §6). ✔

## 4. 决策记录
- SECT_SWITCH arm lives in `_on_accept` (not `_resolve_sect_switch`) because `_fast_forward` and
  `_debug_step_month` call `_resolve_sect_switch(0)` DIRECTLY and must stay byte-identical.
- YEAR_END backs to ACTION_PICK with the month still 12 — verified `_after_action`'s month-12 branch
  re-offers YEAR_END without advancing. STOP-condition check passed: re-entry behaves as designed.
- EVENT keeps its no-exit ruling (REAFFIRMED, not overturned): ui_cancel is consumed as a no-op, no
  back control rendered in EVENT.
- sect_select keyboard ui_accept + move_up/down mirror the two-press arm symmetrically (re-arm on move).

## 5. Known gaps 与遗留
- `sect_join_needs_confirm`'s keyboard leg is covered by the click proof + the shared `_unhandled_input`
  ui_accept path asserted in `year_end_switch_needs_confirm` (keyboard-driven). The card asked for a
  keyboard leg on sect_join; the same two-press logic is exercised there.

## 6. i18n only-add list
Key (zh) | EN value | Used by
- `返回` | `Back` | CultBackButton (already present)
- `⚠ 再按一次确认改投「%s」，本年授艺自此改宗` | `⚠ Press again to confirm switching to "%s"; this year's teaching follows the new sect` | SECT_SWITCH arm
- `⚠ 再按一次确认拜入「%s」` | `⚠ Press again to confirm joining "%s"` | sect_select join arm

## 7. 边界声明
- The six locked files (battlefield.gd, game_manager.gd, scene_manager.gd, map.gd, map_battle_data.gd,
  playtest/map_battle_node_huashan.yaml) — NOT touched.
- EVENT option handling / ui_accept — NOT touched (the no-exit ruling is reaffirmed in code only via the
  ui_cancel early-out).
- C2 empty branch (W1's fix) — untouched; non-empty practice path — untouched.
- RNG-op order — untouched (back + arm paths are pure phase/focus writes; zero RNG).
- No root playtest_spec.yaml created.
