# Delivery notes — touch-single-surface (full round)

**Task:** `design_docs_and_delivery` — the full round note for the touch-single-surface
round (buttons as the sole option surface, the GONGFA_PICK empty-list exit, the
clicks-only nail, the property-based coverage gate, and the carried-over
`tails_corrections`). **Date:** 2026-08-30.

## Part A — nail_scenarios (task slice, preserved verbatim)

**Task (slice):** `nail_scenarios` — clicks-only GONGFA_PICK empty-exit nail + keyboard twin.
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

Boot: `scene: res://scenes/menu.tscn` — seeds a fresh no-sect CULTIVATION save via
`debug_seed_save` (the one sanctioned non-click debug action, like
`debug_win_tutorial` in `clicks_only_storyline`), then CLICKS the 读取存档 entry
(`MenuEntry1`) to load directly into CULTIVATION via `menu_load_game` (bypassing
SEGMENT_PREDECESSORS). A fresh profile has `sect_id == ""`, so
`_grant_year_arts()` grants nothing and `_unmastered_ids()` is empty — the empty
`GONGFA_PICK` needs zero setup.

Timeline (16 asserts across 4 assert blocks):
- f30 — `debug_seed_save` (the one non-click action).
- f50 — click `MenuEntry1` (读取存档 → routes into CULTIVATION).
- f80 — 6 asserts: `current_state == "CULTIVATION"`, `current_scene == "cultivation"`,
  `phase == "CARD_PICK"`, `visible == true`, `CultOptionButton0.visible == true`,
  `cursor_markers_visible == false`.
- f90 — click `CultOptionButton0` (card).
- f110 — 2 asserts: `phase == "ACTION_PICK"`, `cursor_markers_visible == false`.
- f120 — click `CultOptionButton0` (练功 = ACTION_PICK index 0).
- f140 — 6 asserts: `phase == "GONGFA_PICK"`, `CultOptionButton0.visible == true`,
  `CultOptionButton0.text == "返回行动"`, `mastered_count == gongfa_count`
  (RELATIVE — never an absolute count), `pressed_connected["CultOptionButton0"]
  == true`, `cursor_markers_visible == false`.
- f150 — click `CultOptionButton0` (返回行动 = the exit).
- f170 — 2 asserts: `phase == "ACTION_PICK"` (the PHASE DIFF — the nail; a
  merely-present button does not satisfy it), `cursor_markers_visible == false`.

Zero keyboard actions; every step is `clicks:` or an assert-only block (the sole
`actions:` entry is `debug_seed_save`, a debug seed, not a keyboard input).

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

**MEASURED values (2026-08-30, `godot_playtest_scenario` sidecar run with the
TEMPORARY RED-FIRST REVERT applied):**
- failing_frame: **f140**
- first_failing_assert: **`CultOptionButton0.visible: visible == true`**
- exact_error: **`aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`**
- green_asserts_before_red: **9** (f80 has 6 + f110 has 2 + f140 first assert
  `phase == "GONGFA_PICK"` = 9 before the first `CultOptionButton0` failure)

[was predicted, superseded by the measured run] The structural prediction was
f90 / `CultOptionButton0.visible` / same error string / 6 green before red
(based on the earlier direct-cultivation.tscn boot shape). The actual landed
YAML boots through `menu.tscn` + `debug_seed_save` + `MenuEntry1` click,
shifting all frames by +60; the measured green count is 9, not the predicted 6
(the f140 phase assert `phase == "GONGFA_PICK"` passes even with the revert,
adding 1 to the pre-block count of 8).

**GREEN values (measured, 2026-08-30, `godot_playtest_scenario` on the restored
tree):**
- `clicks_only_gongfa_empty_exit`: **16/16 PASS** (f80 6 + f110 2 + f140 6 + f170 2
  = 16 asserts, all green; hard gate `passed: true`).
- `gongfa_pick_empty_keyboard_return`: **13/13 PASS** (all asserts green; hard
  gate `passed: true`).

## 5. SELF-RUN requirement (implementer.md:23 hard condition)

**MET.** The `godot_playtest_scenario` sidecar was invoked (2026-08-30) with the
TEMPORARY RED-FIRST REVERT applied (RED run: f140 first failure, 12/16, hard gate
False), then the revert was restored byte-identically (zero `TEMPORARY RED-FIRST
REVERT` hits confirmed by grep) and both scenarios re-run GREEN on the restored
tree (16/16 and 13/13, hard gate True). The measured values above are from those
real runs. Both green re-runs happened strictly on the restored (fixed) tree —
never on the reverted tree. The `5_compile` full gate also confirms 16/16 and
13/13 (see `playtest_summary.md`).

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

## Part B — Full round note (touch-single-surface, 2026-08-30)

### 1. Per-screen before/after

**Cultivation** (`scripts/segments/cultivation.gd`)
- **Before:** `_render()` printed every option list into `BodyLabel` with a `▶` cursor on
  the focused row (ACTION_PICK 7 space-separated labels, GONGFA_PICK per-art rows,
  ATTR_PICK 5 `▶ 根骨 12` rows, EVENT 2 rows, YEAR_END 2 rows, SECT_SWITCH 5 rows), while
  `_rebuild_options_box()` re-created buttons with the **same** labels — the player saw
  every list twice.
- **After:** the option rows + `▶` markers are gone from `BodyLabel`; each list renders
  once as `CultOptionButton{i}` (built + modulate-highlighted + wired in
  `_rebuild_options_box`, `cultivation.gd:560-615`). Selection is expressed **on the
  button** via `modulate` (bright for the focused index, dim `Color(0.72,0.72,0.72,1)`
  otherwise). Keyboard focus stays an int var driven by `_cycle_focus`; the highlight
  moves with it.
- **Kept** (descriptive, not option lists): phase titles, event title/prose, stats
  header, the two-step 删档 warning, card category labels, and the per-phase keyboard
  hint lines.
- New observables: `cursor_markers_visible` (false when no `▶` remains), `option_focus`,
  `focused_option_text` (`cultivation.gd:859-860`).

**Map** (`scripts/segments/map.gd`)
- **Before:** EVENT panel printed two `▶ option` rows; FACILITY printed `▶ <verb>`;
  TRAVEL printed `▶ name（此处）` and `（可前往）` focus markers — all duplicating
  `EventOptionButton{0,1}` / `FacilityUseButton` / `TravelButton{i}`.
- **After:** the EVENT composite key is shortened to title + prose + hint (the two option
  slots are **deleted from the key**, never fed `""`); the FACILITY `▶`-verb slot is
  deleted (title + prose + cost/effect summary + hint remain); the TRAVEL node list stays
  as a descriptive overview but the `▶` glyph and `（可前往）` focus markers are removed
  and the current-node row reads `  %s（当前所在）`. Focus lives on the highlighted
  `TravelButton{i}` (`map.gd:483`).
- **Kept:** event title/prose, facility cost/effect summary, the map overview node list,
  the footer `HintLabel` (the one-line-per-screen hint).

**Sect select** (`scripts/segments/sect_select.gd`)
- **Before:** body rows carried a `▶` marker duplicating `SectButton0..4`.
- **After:** the `▶` marker is removed; the per-sect info lines (name —— 内功 X · 外功 Y)
  are kept as descriptive prose (buttons carry the name only); focus is expressed on the
  highlighted `SectButton{i}` via `modulate`.

**Creation** (`scripts/segments/creation.gd`)
- Already single-surface (the precedent this round copies). No code change; parity check
  only — `cursor_markers_visible` probe already publishes "no `▶` anywhere".

### 2. Measured affected-assertion table

Re-run of the §7.1 grep over `playtest/*.yaml` for
`BodyLabel.text|ActionHintLabel.text|MoveHintLabel.text|HintLabel.text|MenuPanel.hint_text`:
- 18 hits, **none of which pins a removed option row**: battle HUD rejection reasons
  (`ActionHintLabel` ×8), battle movement hints (`MoveHintLabel` ×3), menu hint
  (`MenuPanel.hint_text` ×2 — descriptive, kept), the map single-hint invariant
  (`map_hint_single.yaml` — a NEGATIVE `contains("回车启程") == false` that stays true,
  plus the EVENT hint line that stays), and the footer text pin
  (`map_node_event_mainline_return.yaml:33`).
- **Playtest-scenario assertion churn: ZERO edits.**

| Line | Before | After | Equivalence reason |
|---|---|---|---|
| (no playtest line changed) | — | — | no playtest assert pinned a removed option row (no equality `BodyLabel.text` assert on a map/cultivation option list) |

**Reconciliation vs the brief's "~15 estimate":** the estimate was built from
pre-change BodyLabel option-row pins. The measured set shows every such hit was either a
descriptive label (out of scope per the brief) or a negative / contains assert that
survives the composite-key shortening intact. The two unit tests that DID pin the
duplication are re-targeted in §3 below — that is the full affected set.

### 3. Re-targeted unit tests

| Test | Before expression | After expression | Why equivalent |
|---|---|---|---|
| `tests/test_map_node_event.gd` (`:388-408`) | pinned the `▶` marker inside the map EVENT `BodyLabel` text | assert `EventOptionButton0/1` texts + `cursor_markers_visible == false` | the option list now renders once as buttons; the buttons carry the same labels the `▶` rows used to, and `cursor_markers_visible` proves no `▶` remains |
| `tests/test_map_facility_buttons.gd` (`:431-437`) | pinned the FACILITY `▶ ` body advertisement | assert `FacilityUseButton.text` + `cursor_markers_visible == false` | the verb now lives on the button; the no-`▶` observable is the runtime proof the duplicate row is gone |

### 4. Measured first-red values for `clicks_only_gongfa_empty_exit`

PENDING the sidecar / gate run — **carried from the nail slice (Part A §4), never
invented**. Structural prediction + verbatim revert recipe reproduced:

- failing_frame: **PENDING** (structural prediction: f90, the GONGFA_PICK block's first
  assert on `CultOptionButton0.visible` — the button does not exist with the revert).
- first_failing_assert: **PENDING** (structural prediction: `CultOptionButton0.visible`,
  expr `visible == true`, f90).
- exact_error: **PENDING** (structural prediction:
  `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`).
- green_asserts_before_red: **PENDING** (structural prediction: f30 4 asserts + f60 2 =
  6 before the f90 red).

Revert recipe (see Part A §4 for the verbatim block): neutralize only the
`labels.append(tr("返回行动"))` line in the `"GONGFA_PICK"` arm, marked
`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`; run
`godot_playtest_scenario(scenario="clicks_only_gongfa_empty_exit")`, record the four
values, restore the revert byte-identically, re-run GREEN.

### 5. Self-run observed values

**PENDING** the sidecar / gate run — never fabricated. The fixed tree should pass every
assert across the four blocks (4 + 2 + 6 + 2 = 14 asserts) of
`clicks_only_gongfa_empty_exit`; the values are pasted here by the run that confirms
them. The keyboard twin (`gongfa_pick_empty_keyboard_return`) is likewise confirmed by
its self-run before the full `5_compile` gate.

### 6. Keyboard-hint rationale

The keyboard hints (「上下选择，回车执行」 and the per-phase equivalents) are **kept**.
They are one-line operation summaries, **not** duplicated option rows — removing them
would leave desktop players with no instruction for which keys drive the on-button
selection. Keeping them is not a re-introduction of the parallel UI: the buttons remain
the only rendering of each option list, and the hint merely names the shortcut layer.
The residual copy debt (hints still phrased keyboard-first on screens that also have
tappable controls) is **UX-12**, an OPEN measure-only backlog item — explicitly not in
scope to fix this round (see `design/90_decisions.md` 2026-08-30 touch-single-surface
(a) and `design/40_ux_backlog.md`).

### 7. 肉眼可见 walkthrough

Enter 养成 → month 1 card → 本月行动 → tap **练功** → 【练功】 shows
「暂无未大成武功。点击「返回行动」回到本月行动。」 with **ONE** button **返回行动** →
tap it once → back at 【本月行动】 → tap 修习 / 做工 / 游历 → keep playing.
**Zero keyboard.**
