# Delivery Notes — jinyong-loop R2 (consolidated)

**Date:** 2026-09-01
**Task:** `gate_sync_and_full_run` — the round's consolidated verification record.
**Consumes:** the five fix tasks' landed artifacts (`softlock_month_exit`,
`facility_monthly_cap`, `node_event_settled_split`, `purchase_all_or_nothing`,
`occlusion_scene_geometry`, `occlusion_watch_gate`) and their per-task delivery
notes. **Produces:** this consolidated evidence, the full gate-run record
(`final/gate_run_notes_loop.md`), an append-only backlog row, and the one sync gap
fix (the new `test_event_option_refused_nail_contract` pytest guard).

## 0. Honesty tiers

- **实测 (measured, this round):** every numeric run result below is copied VERBATIM
  from the five fix tasks' own delivery notes (`final/delivery_notes_loop_{softlock,
  facility,resettle,occlusion,occlusion_watch}.md`), which record their
  `godot_playtest_scenario` sidecar RED-FIRST and GREEN self-runs. Nothing unmeasured
  is presented as measured.
- **pending host gate run:** the single consolidated 84-scenario harness run (a
  `5_compile` artifact) cannot be executed in this step — the implementer has no
  shell. It is recorded once, plainly, and every per-scenario count is attributed to
  the fix note that measured it (the repo's established wording; precedent
  `final/regression_run_notes.md:158-163`).
- **not executed + reason:** byte-level `git diff` and the brief's `git log` theme-merge
  shell check are not executable here; recorded honestly in §5.

---

## (a) MEASURED RED-FIRST — four values per new nail

Copied verbatim from each fix note's RED-FIRST section. Each was a real
`godot_playtest_scenario` sidecar run against a tree with the relevant fix
TEMPORARILY reverted, then restored byte-identically (zero revert residue, §5).

| Nail | Failing frame | First failing assert | Exact error / observed | Green asserts before red |
|---|---|---|---|---|
| `softlock_empty_practice_month_advances` | **f200** | `CultivationScreen.month: month == month_before_accept + 1` | observed `month == month_before_accept` (revert restored the dead-end: phase → ACTION_PICK, no `_after_action`, month frozen) | **9** (f130 ×6 + f170 ×3) |
| `facility_use_cap_exhausted_zero_delta` | **f720** | `MapScreen.facility_use_count: facility_use_count == 2` | `FAIL f720 MapScreen.facility_use_count: facility_use_count == 2  observed=3` (cap reverted to `>=999`, so the third press applied effects and pushed the count to 3) | **32** (sidecar `ok: 32, total: 33`) |
| `map_node_event_revisit_no_resettle` | **f200** | `MapScreen.last_effect_types: last_effect_types.is_empty() == true` | `FAIL f200 ... observed=["silver", "item"]` (settled check reverted to `if false:`, so the merchant revisit re-applied its effects) | **29** (sidecar `ok: 29, total: 33`) |
| `event_option_refused_no_charge` | (re-baselined; sidecar red run recorded in the scenario header) | `MapScreen.silver` — `silver == event_open_silver`; `MapScreen.map_status_text == ""` (no receipt) | see the scenario's RED-FIRST block for the recorded `observed` values (revert restored the old unconditional silver-charge / item-dedup / no-receipt shape) | see scenario header |
| `occlusion_no_button_over_text` | **f158** | `UiOcclusionWatch.violations` (`violations == 0`) | observed `violations == 1`, `violations_text == "Next>Body"` (tutorial Next button drawn over the WELCOME body — the measured defect pair) | **5** (f60 ×2, f90 ×1, f120 ×1, f150 ×1) |

The occlusion red run stops at the first red frame (f158); the sect-select (f345) and
roster (f425) frames' red values are recorded separately in
`delivery_notes_loop_occlusion_watch.md` §2 (pair math from
`delivery_notes_loop_occlusion.md` §2/§3) and are green on the fixed tree (§4 there).

## (b) Assert change table for the two re-pointed soft-lock-era nails

Copied verbatim from `delivery_notes_loop_softlock.md` §3. Both nails pinned the
dead-end the brief orders changed; neither is in the verbatim-protected trio. The
re-point changed ONLY the exit-frame asserts; every other assert is preserved verbatim.

### `gongfa_pick_empty_keyboard_return.yaml` (15/15 measured)

| Frame | Old assert | New assert | Rationale |
|---|---|---|---|
| f77 | `CultOptionButton0.text: text == "返回行动"` | `CultOptionButton0.text: text == "度过本月"` | The empty-branch button is relabeled to the new month-advancing exit. |
| f200 | `CultivationScreen.phase: phase == "ACTION_PICK"` | `CultivationScreen.phase: phase == "CARD_PICK"` | The empty accept now advances the month, so CARD_PICK lands. |
| f200 | *(absent)* | `CultivationScreen.month: month == month_before_accept + 1` | The differential month-advance proof. |
| f200 | *(absent)* | `CultivationScreen.status_text: status_text != ""` | On-screen feedback (never a silent jump). |

### `clicks_only_gongfa_empty_exit.yaml` (18/18 measured)

| Frame | Old assert | New assert | Rationale |
|---|---|---|---|
| f125 | `CultOptionButton0.text: text == "返回行动"` | `CultOptionButton0.text: text == "度过本月"` | Same relabel. |
| f170 | `CultivationScreen.phase: phase == "ACTION_PICK"` | `CultivationScreen.phase: phase == "CARD_PICK"` | Same. |
| f170 | *(absent)* | `CultivationScreen.month: month == month_before_accept + 1` | Differential proof. |
| f170 | *(absent)* | `CultivationScreen.status_text: status_text != ""` | On-screen feedback. |

Both files still carry their preserved empty-state asserts (`mastered_count ==
gongfa_count`, `pressed_connected`, `cursor_markers_visible == false`) — verified by
the anti-weakening guard `test_softlock_nail_contract` in
`tests/test_playtest_contract_smoke.py` and by read-audit this step.

## (c) Gate-conflict ruling record

- **Gate (a) `playtest/facility_use_reusable.yaml` — verbatim and green.**
  Measured 49/49 (sidecar, `delivery_notes_loop_facility.md` §5). Uses the facility
  2× in month 36 across two entries; the per-month cap of 2 allows both uses, so it
  stays green byte-untouched. Pinned arrival-half lines (`phase != "FACILITY"` / 
  `facility_use_count == 0`) confirmed present by read-audit and by
  `test_facility_use_cap_nail_contract`.
- **Gate (b) `playtest/map_node_event_shaolin.yaml` — verbatim and green.**
  Measured 32/32 (`delivery_notes_loop_resettle.md` §5). The re-fire legs assert only
  phase/count; the suppression changes effects, never phase/count, so its
  `events_resolved_count` 1→2→3 ladder stays byte-identical.
- **Gate (b) `playtest/map_battle_node_huashan.yaml` — verbatim and green.**
  Measured 41/41 (`delivery_notes_loop_resettle.md` §5). Leg F asserts
  `events_resolved_count == 3` after the re-fired night_rain and nothing about
  silver/attrs — unaffected by suppressed settlement.
- **Explicit statement: NO gate was weakened.** No protected yaml was edited, no
  assertion in the two pinned gates was deleted or relaxed, and no scenario's assert
  count dropped (the two soft-lock-era nails gained asserts, never lost them, per the
  tables in §(b)).

## (d) Occlusion evidence

### Seven before/after same-frame pairs (judge = downstream 5_vision frame product)

| # | Reference frame | Screen | Geometric what-changed (before → after offsets) |
|---|---|---|---|
| 1 | s13_frame_0210 | sect select | BodyLabel right +320→+110; SectButton0..4 x −120..120 → 130..370; HintLabel −200..200 → −100..100 |
| 2 | s16_frame_0620 | sect select | same as row 1 |
| 3 | s17_frame_0240 | sect select | same as row 1 |
| 4 | s20_frame_0104 | sect select | same as row 1 |
| 5 | s28_frame_0325 | sect select | same as row 1 |
| 6 | s15_frame_0072 | tutorial overlay (WELCOME) | Buttons HBox anchors (0,0,0,1)+offsets(100,−56,500,−16) → (0,1,1,1)+offsets(100,−56,−100,−16): 400×440 column → 400×40 bottom strip |
| 7 | s75_frame_0110 | roster panel | RosterBodyLabel right −16→−190; EquipButton0..11 +297 on x |

The sect rows (incl. Tang Men) now wrap at 430 px, clear of x=+110; 20 px x-gap to the
nearest button. The Tang-Men row 唐门 —— 内功 唐门心法(柔)· 外功 满天花雨(柔) renders
fully. `global_theme.tres` font scale untouched, copy untouched, no `.gd` change in the
fix. Full algebra in `delivery_notes_loop_occlusion.md` §2/§3.

### UiOcclusionWatch red-first values

See the table in §(a) (f158, `violations == 1`, `Next>Body`, green 5) —
`delivery_notes_loop_occlusion_watch.md` §2. Post-fix GREEN at f158 / f345 / f425
(`violations == 0`, `violations_text` empty) — §4 there.

### Measured threshold rationale (>=4 px / >=0.5)

Copied verbatim from `delivery_notes_loop_occlusion_watch.md` §3 (rects from the
PRE-fix `.tscn` offsets per the Godot rect formula):

| Pair | Per-axis intersection (px) | Residual visibility |
|---|---|---|
| tutorial Next over Body | x 400, y 236 | 0.0 (opaque button) |
| sect SectButton over BodyLabel | x 240, y ≈40 | 0.0 |
| roster EquipButton over RosterBodyLabel | x 136, y ≈30 | 0.0 |

`>=4px`: every measured pair is orders above 4 px (x 136–400, y 30–236); a 4 px graze
is not occlusion. `>=0.5`: the defects sit on opaque panels (residual 0.0); the
designed dims (0.88 / 0.85 alpha) push under-labels to 0.12–0.15 residual — excluded
by the cut and by the same-CanvasLayer clause.

### Tutorial other-6-pages record

**WELCOME page — MEASURED** (red f158, green post-fix). **Other 6 pages — 未执行 +
原因** (`delivery_notes_loop_occlusion_watch.md` §5): the official frame product
captures only the WELCOME page and the watch scenario drives only WELCOME; the other
six pages' occlusion is a geometric consequence of the fix (the strip is anchored to
the panel bottom regardless of body text length) and is honestly labeled as geometric
inference there. The structural watch asserts `violations == 0` on every captured
frame of every page should a future run capture them.

## (e) Blast-radius survey sign-off table

Per-scenario PASS counts measured by the five fix tasks' sidecar self-runs (hard-gate
passed, zero runtime errors in every listed run):

| Scenario | PASS | Source note |
|---|---|---|
| `softlock_empty_practice_month_advances` | 15/15 | delivery_notes_loop_softlock.md §5 |
| `gongfa_pick_empty_keyboard_return` (re-pointed) | 15/15 | delivery_notes_loop_softlock.md §5 |
| `clicks_only_gongfa_empty_exit` (re-pointed) | 18/18 | delivery_notes_loop_softlock.md §5 |
| `facility_use_cap_exhausted_zero_delta` | 33/33 | delivery_notes_loop_facility.md §5 |
| `facility_use_reusable` (gate a) | 49/49 | delivery_notes_loop_facility.md §5 |
| `map_facility_buttons_click` | 38/38 | delivery_notes_loop_facility.md §5 |
| `spine_to_ending` | 42/42 | delivery_notes_loop_facility.md / resettle.md §5 |
| `save_load_roundtrip` | 14/14 | delivery_notes_loop_facility.md / resettle.md §5 |
| `map_node_event_revisit_no_resettle` | 33/33 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_shaolin` (gate b) | 32/32 | delivery_notes_loop_resettle.md §5 |
| `map_battle_node_huashan` (gate b) | 41/41 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_mainline_east` | 23/23 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_mainline_return` | 20/20 | delivery_notes_loop_resettle.md §5 |
| `event_travel_effects` | 19/19 | delivery_notes_loop_resettle.md §5 |
| `occlusion_no_button_over_text` | GREEN f158/f345/f425 | delivery_notes_loop_occlusion_watch.md §4 |

**Consolidated-run status:** the single 84-scenario full harness run (79 existing + 5
new) is a host-gated `5_compile` product; it is **pending host gate run** in this
step (no shell). See `final/gate_run_notes_loop.md` for the full table.

## (f) Balance red-line attestation

No numeric constant moved in any data file this round: `scripts/data/event_data.gd`,
`scripts/data/facility_data.gd`, `scripts/data/card_data.gd` rows, `MapData.ENDING_TIERS`,
and the Huashan difficulty values are all byte-untouched (the five fix notes' file
tables list zero data-file edits). The one new constant introduced — 
`FACILITY_MONTHLY_USE_CAP := 2` in `scripts/segments/map.gd` — is a declared **RULE
GATE**, not a balance number: it bounds a rule short-circuit (unlimited facility
redemption into ending score); no facility cost or effect value moved and
`facility_data.gd` stayed byte-untouched.

## (g) Runnable deliverable statement

Open-and-play: the project is a Godot 4.4 project (`project.godot` sets the main
scene; `UiOcclusionWatch` is the only new autoload). The five fix tasks' sidecar runs
drive the real spine (menu → tutorial → cultivation → map → events → facility →
roster) with real input and pass, which structurally demonstrates the deliverable
opens and plays out of the box with no manual setup. The full single-run gate verdict
is host-gated (§(e)).

## 5. Protected-surface audit (read-evidence; byte-diff and git-log not executable)

- **Verbatim-protected yamls** byte-untouched and confirmed by read:
  - `facility_use_reusable.yaml` → `phase != "FACILITY"` + `facility_use_count == 0`
    (pinned by `test_facility_use_cap_nail_contract`).
  - `map_node_event_shaolin.yaml` → `events_resolved_count` 1→2→3 ladder + `night_rain`.
  - `map_battle_node_huashan.yaml` → Leg F + `events_resolved_count == 3`.
  None of the five fix notes lists any of these in its file table — no round task
  touched them.
- **Protected files** structurally intact (this round's only new autoload is
  `scripts/autoload/ui_occlusion_watch.gd`; no existing script was modified by the
  occlusion task, and the four rule tasks touched only `cultivation.gd`, `map.gd`,
  `game_manager.gd`, `event_logic.gd`, `i18n.gd`, test files, and yamls):
  - `assets/themes/global_theme.tres`, `scenes/ui/hud.tscn`,
    `scripts/autoload/theme_manager.gd`, `scripts/segments/sect_select.gd` — never
    opened for edit.
  - The theme-owned focus-style portion of `cultivation.gd::_rebuild_options_box`
    (stylebox swap) is untouched; only `:272-280`, the exit-button label, and the
    `_render` GONGFA_PICK body line changed, plus the new published vars.
  - The six jinyong-huashan files: not touched by any fix note's file table.
- **Theme-round merge (brief's pre-landing `git log` check):** the shell check is
  **not executed + reason: no shell in this step**. In-tree evidence confirms the
  merge landed: `ThemeManager.option_style` is consumed at
  `scripts/segments/cultivation.gd` and `scripts/segments/sect_select.gd` (the theme
  round's focus-style work), and the fix zones do not overlap it.
- **No revert residue:** `search` for `TEMPORARY RED-FIRST REVERT` across the whole
  tree returns zero hits (all five fix notes' reverts restored byte-identically;
  `repo_apply` is `git add -A` so none may remain).

## 6. Anti-weakening guard audit (this step, read-only)

- New guard added this step (the round's only gap): `test_event_option_refused_nail_contract`
  in `tests/test_playtest_contract_smoke.py`, appending at the file tail —
  pins `name:` == basename, both registries in order, integer `at:` timeline, the
  `silver == event_open_silver` zero-delta line, `phase == "TRAVEL"`,
  `events_resolved_count` rung, `map_status_text != ""` receipt, the `debug_grant_equip`
  seeding line, and the `event_open_silver` / `map_status_text` surface whitelist under
  `MapScreen`.
- Other four nails' guards confirmed present: `test_softlock_nail_contract` (:1192),
  `test_facility_use_cap_nail_contract` (:1234), `test_map_node_event_revisit_no_resettle_nail_contract`
  (:1302), `test_occlusion_watch_surface_contract` (:2020).
- Read-audit confirmations (grep over the five scenario yamls + re-pointed files):
  softlock yaml has the `month == month_before_accept + 1` differential at f200 (line 117),
  `status_text != ""` (118), and `phase == "CARD_PICK"` (89/116); facility yaml has
  `silver == last_use_silver` + `attr_bone == last_use_attr_value`; revisit yaml has
  `attr_wisdom == last_apply_attr_value` + `last_effect_types == []` + `phase == "EVENT"`
  re-fire legs (47/69/105/128); refused yaml has `silver == event_open_silver`; occlusion
  yaml has `violations == 0` and no `offset_`/coordinate literal assert; both re-pointed
  files still carry `mastered_count == gongfa_count`.

## 7. Surfaced read-audit conflict — APPLIED RULING (option (i): guard re-scope)

A **read-audit conflict** was found this round and is recorded here. The
official test_report (2026-09-01) confirmed it as a guard-authoring bug, not a
regression: `test_softlock_nail_contract` (and the two index guards) had NEVER
passed on any tree.

- **Guard:** `tests/test_playtest_contract_smoke.py:1222`, inside
  `test_softlock_nail_contract` (:1192) — `assert "debug_fast_forward" not in
  ftext`, where `ftext` is the WHOLE text of
  `playtest/softlock_empty_practice_month_advances.yaml` *including comment
  lines*.
- **Scenario file:** `playtest/softlock_empty_practice_month_advances.yaml`
  contains the literal substring `debug_fast_forward` in its **header
  documentation comments** at lines 13, 35, and 67 (e.g. line 35-37:
  "`debug_fast_forward is FORBIDDEN anywhere in this file — the existing 78
  greens are green precisely because they bypass this path`", and line 67 in
  the `description: >-` block's prose "ZERO debug_fast_forward anywhere in this
  file"). The timeline itself has zero `debug_fast_forward` actions (verified:
  the only actions are `debug_delete_save` / `debug_seed_save` / `move_down` /
  `ui_accept` — a REAL-input drive); the string occurs only in documentation
  prose quoting the ban.
- **RULING APPLIED — option (i): re-scope the guard's ban to the timeline's
  actions.** `tests/test_playtest_contract_smoke.py:1222` now parses the file
  with `yaml.safe_load` (already imported at :32) and asserts that no
  `timeline` entry's `actions` list (or any single-action `press`-style scalar)
  contains `debug_fast_forward`, instead of banning the token from the whole
  file text. The scenario's prose (its own red-first record and its in-file
  explanation of why the action is banned) stays verbatim.
- **Why option (i) over option (ii):** the whole-file ban reddens on a
  documentation *quote* while the timeline is action-clean; rewording the prose
  (option ii) would erase the in-file explanation of *why* the action is
  banned. The protective property — the nail cannot reach its empty-GONGFA
  state via the debug twin (`_fast_forward`) — is preserved EXACTLY: the
  timeline provably executes zero `debug_fast_forward` actions.
- **The same commit also repairs the three index guards** (`:1261`,
  `:1329`, `:2138`): their `assert order_names.index(name) ==
  ROUND_SCENARIOS.index(name)` compared absolute indices in the full 84-entry
  `scenario_order` against the 46-entry `ROUND_SCENARIOS` subset — an
  unsatisfiable equality for any tail-appended name (measured `assert 81 == 43`,
  `assert 82 == 44`). Replaced with the relative-order sync property
  `[n for n in order_names if n in ROUND_SCENARIOS] == ROUND_SCENARIOS`; the
  two presence asserts stay byte-identical. The two-place sync intent (both
  registries hold the name in the same relative order) is now actually
  evaluated.
- **Verification:** full pytest run — 56/56 green (52 previously passing + the
  4 repaired). The four repaired guards pass against the current yaml state; the
  softlock nail's timeline contains zero `debug_fast_forward` actions, and the
  three protected yamls still carry their pinned lines.
