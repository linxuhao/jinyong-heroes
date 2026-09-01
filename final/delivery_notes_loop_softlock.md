# Delivery Notes — jinyong-loop R2 · softlock_month_exit

**Date:** 2026-09-01
**Task:** `softlock_month_exit` — fix the cultivation soft-lock: empty-practice
Enter must advance the month with on-screen feedback (never a silent jump).

## 1. What was built

The cultivation soft-lock defect (`scripts/segments/cultivation.gd:272-275`):
the `_on_accept()` GONGFA_PICK branch read `var ids = _unmastered_ids()` /
`if ids.is_empty(): phase = "ACTION_PICK"` — it never called `_after_action()`,
so the month never advanced and Enter looped forever (f482 and f1130
byte-identical after ~80 Enters). The escape hatch existed ONLY on the debug
path (`_fast_forward` does `ATTR_PICK` + `_after_action`), which is why all 78
prior scenarios were green — they reach late states via `debug_fast_forward`.

The fix (design D1) mirrors the debug twin's transition minus its free reward:

1. **`_on_accept()` GONGFA_PICK empty branch** — when `_unmastered_ids()` is
   empty: `status_text = tr("无可修习的功法，本月照常过去")`; `phase = "ATTR_PICK"`;
   `_attr_focus = 0`; `_after_action()`; `return`. **NO `_apply_action` call**
   (zero RNG ops, zero attribute gain — the seeded RNG stream's op order is the
   lifeline of `event_travel_effects` 19/19 and `save_load_roundtrip` 14/14).
   `_after_action` is the single month-advance path; month 12 → YEAR_END and
   y3/m12 → `_finish_to_map()` inherit for free — no special-casing.
2. **New published vars** — `month_before_accept: int` (assigned as the FIRST
   line of `_on_accept()`, before the phase match; never re-assigned, never
   written by `_sync_surface` which re-reads the profile's month and would
   clobber the snapshot) and `status_text: String = ""` (cleared at the top of
   `_on_accept()`; rendered by `_render()` as an appended body line whenever
   non-empty). Both follow the existing `facility_result_text` composition
   pattern: `tr()` at the composition site; nails assert shape-only (`!= ""`).
3. **`_rebuild_options_box()` GONGFA_PICK empty branch** — the single exit
   button relabeled `tr("返回行动")` → `tr("度过本月")`. ONLY that label line;
   the theme-owned focus-style stylebox-swap portion (`:582-646`,
   `ThemeManager.option_style` consumption at `:649-651`) stays byte-untouched.
4. **`_render()` GONGFA_PICK body** — the empty-list line
   `tr("暂无未大成武功。点击「返回行动」回到本月行动。")` → `tr("功法均已大成，无可修习")`,
   so 练功 at ACTION_PICK is explained on screen instead of being a silent no-op.
5. **i18n** — three new EN-dictionary entries (Chinese-as-key, appended):
   `无可修习的功法，本月照常过去` / `度过本月` / `功法均已大成，无可修习`. No U+2026
   ellipsis characters.
6. **`_fast_forward` and `_debug_step_month` stay byte-identical** (debug twins
   are not the defect).

## 2. Files changed

| File | Change |
|---|---|
| `scripts/segments/cultivation.gd` | Soft-lock fix: empty-GONGFA accept advances the month via `_after_action()` + `status_text` feedback; new `month_before_accept` / `status_text` published vars; empty-branch button relabeled 度过本月; GONGFA_PICK empty-list body line. |
| `scripts/autoload/i18n.gd` | 3 EN-dictionary appends (Chinese-as-key). |
| `playtest/gongfa_pick_empty_keyboard_return.yaml` | Re-pointed: f77 text assert 返回行动 → 度过本月; f200 block `phase == "ACTION_PICK"` → `phase == "CARD_PICK"` + `month == month_before_accept + 1` + `status_text != ""`. All other asserts preserved verbatim. |
| `playtest/clicks_only_gongfa_empty_exit.yaml` | Re-pointed identically: f125 text assert → 度过本月; f170 block re-pointed. All other asserts preserved verbatim. |
| `playtest/_common.yaml` | Append-only: `month_before_accept` + `status_text` to the CultivationScreen surface block; `softlock_empty_practice_month_advances` to the scenario_order tail. |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` tail append + new `test_softlock_nail_contract` anti-weakening guard. |
| `playtest/softlock_empty_practice_month_advances.yaml` | NEW — the round's core deliverable: real-input soft-lock nail. |
| `final/delivery_notes_loop_softlock.md` | This note. |

## 3. Nail change table (the two re-pointed soft-lock-era nails)

Both nails pin the dead-end the brief orders changed; they are NOT in the
verbatim-protected trio. The re-point changed ONLY the exit-frame asserts; every
other assert (the GONGFA_PICK empty-state block incl. `mastered_count ==
gongfa_count`, `pressed_connected`, `cursor_markers_visible == false`) is
preserved verbatim. jinyong-huashan precedent: in-place rewrite with a
line-by-line change table.

### `gongfa_pick_empty_keyboard_return.yaml`

| Frame | Old assert | New assert | Rationale |
|---|---|---|---|
| f77 | `CultOptionButton0.text: text == "返回行动"` | `CultOptionButton0.text: text == "度过本月"` | The empty-branch button is relabeled to describe the new month-advancing exit. |
| f200 | `CultivationScreen.phase: phase == "ACTION_PICK"` | `CultivationScreen.phase: phase == "CARD_PICK"` | The empty accept now advances the month, so the next month's card draw lands (CARD_PICK), not the dead-end ACTION_PICK. |
| f200 | *(absent)* | `CultivationScreen.month: month == month_before_accept + 1` | The differential month-advance proof — the nail's core. |
| f200 | *(absent)* | `CultivationScreen.status_text: status_text != ""` | The player saw the notice (never a silent jump). |

All other asserts (f130 boot block, f170 GONGFA_PICK empty-state block incl.
`mastered_count == gongfa_count`, `pressed_connected["CultOptionButton0"] ==
true`, `cursor_markers_visible == false`) preserved verbatim.

### `clicks_only_gongfa_empty_exit.yaml`

| Frame | Old assert | New assert | Rationale |
|---|---|---|---|
| f125 | `CultOptionButton0.text: text == "返回行动"` | `CultOptionButton0.text: text == "度过本月"` | Same relabel. |
| f170 | `CultivationScreen.phase: phase == "ACTION_PICK"` | `CultivationScreen.phase: phase == "CARD_PICK"` | Same month-advancing exit. |
| f170 | *(absent)* | `CultivationScreen.month: month == month_before_accept + 1` | Differential month-advance proof. |
| f170 | *(absent)* | `CultivationScreen.status_text: status_text != ""` | On-screen feedback. |

All other asserts (f80 boot block, f140 GONGFA_PICK empty-state block incl.
`mastered_count == gongfa_count`, `pressed_connected`, `cursor_markers_visible
== false`) preserved verbatim.

## 4. New nail — `softlock_empty_practice_month_advances`

The round's core deliverable. Boots `menu.tscn`, seeds a fresh no-sect
CULTIVATION save via `debug_seed_save` (a sanctioned SEED action, same role as
`debug_win_tutorial` — NOT a state skip), loads it by keyboard (move_down +
ui_accept), then drives with pure real `ui_accept`: CARD_PICK → ACTION_PICK →
empty GONGFA_PICK → accept. **`debug_fast_forward` is FORBIDDEN anywhere in
this file** — the existing 78 greens are green precisely because they bypass
this path, so a nail that reached the state by fast-forward would prove nothing.

Asserts are differential, zero literals:
- `CultivationScreen.month: month == month_before_accept + 1` — the month
  really advanced (the differential proof).
- `CultivationScreen.phase: phase == "CARD_PICK"` — the next month's card draw
  landed.
- `CultivationScreen.status_text: status_text != ""` — the player saw the
  notice (never a silent jump).

The differential is asserted at f200, AFTER `_stage_next_month` has landed
CARD_PICK and incremented the month, so `month_before_accept`'s published value
is genuinely the pre-accept month at read time (per the t_plan_review
suggestion).

## 5. RED-FIRST evidence (measured, never predicted)

### New nail `softlock_empty_practice_month_advances`

Measured via the `godot_playtest_scenario` sidecar with the TEMPORARY
RED-FIRST REVERT applied to `scripts/segments/cultivation.gd` (the empty
branch restored to the old `phase = "ACTION_PICK"` dead-end, no `_after_action`
call), then restored byte-identically.

| # | Value |
|---|---|
| 1. Failing frame | **f200** |
| 2. First failing assert | `CultivationScreen.month: month == month_before_accept + 1` |
| 3. Exact error / observed | observed `month == month_before_accept` (the revert restored the dead-end: phase → ACTION_PICK, no `_after_action`, month frozen) |
| 4. Green asserts before red | **9** (f130 has 6 + f170 has 3 = 9) |

### Re-pointed nails' OLD exit asserts against the fixed tree

Both re-pointed nails' OLD exit asserts (`phase == "ACTION_PICK"` at f200/f170)
red against the fixed tree — the empty accept now advances the month to
CARD_PICK, so the old dead-end assert can no longer hold. This is the expected
red of the change table in §3; the re-pointed asserts are green on the fixed
tree.

### Green self-run (measured, this step)

Via the `godot_playtest_scenario` sidecar on the delivered tree (repo + staged
files):

| Scenario | Result |
|---|---|
| `softlock_empty_practice_month_advances` | **15/15** PASS |
| `gongfa_pick_empty_keyboard_return` | **15/15** PASS |
| `clicks_only_gongfa_empty_exit` | **18/18** PASS |

All three hard-gate passed with zero runtime errors.

## 6. Pre-landing check

`git log` confirms the jinyong-theme round has merged (in-tree evidence:
`cultivation.gd:649-651` and `sect_select.gd:88-89` already consume
`ThemeManager.option_style`). The fix zone (`:272-280` / `_after_action` /
`_rebuild_options_box` empty-branch label) does not overlap the theme-owned
focus-style work (`:582-646` stylebox swap, `:649-651` option_style
consumption), which stays byte-untouched.

## 7. Red lines honored

- **Verbatim-protected trio untouched**: `playtest/facility_use_reusable.yaml`,
  `playtest/map_node_event_shaolin.yaml`, `playtest/map_battle_node_huashan.yaml`.
- **Protected files untouched**: `assets/themes/global_theme.tres`,
  `scenes/ui/{roster_panel,tutorial_overlay,hud}.tscn`,
  `scripts/autoload/theme_manager.gd`, `scripts/segments/sect_select.gd`, the
  focus-style portion of `cultivation.gd::_rebuild_options_box`, the six
  jinyong-huashan files.
- **No balance numbers move** (ending thresholds, attribute formulas, card
  rewards, Huashan difficulty are R3).
- **No U+2026 ellipsis characters** in any new string.
- **Zero RNG ops added** — the empty branch does not call `_apply_action`, so
  the seeded RNG stream's op order is unchanged.
