# Delivery Notes — feat_conclusion_sweep (R5 closing sweep)

Date: 2026-09-04. Card: closing verification sweep (occlusion net, registry sync, no-temp-residue, consolidated record).

## 1. 改动清单 (Change list)

| File | Change |
|---|---|
| `playtest/consequence_screens_occlusion.yaml` | **NEW** — full-round occlusion net, 62 asserts, 9 assert frames, one per new R5 surface (table below). Boot = the proven main.tscn spine (battle-pause grammar → tutorial win → creation → two-press sect join → monthly drive to month 12 → SECT_SWITCH arm). |
| `playtest/_common.yaml` | `scenario_order` append-only: added `- consequence_screens_occlusion` (exactly once; no existing entry touched — verified by read of lines 1147–1266 before/after). **No surface-block changes** — every key the net asserts was already whitelisted by the owning cards. |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` ONLY-ADD: `"consequence_screens_occlusion"` appended once after `"enemy_hit_float_and_log_visible"`. Nothing else touched. |
| `final/delivery_notes_feat_conclusion_sweep.md` | **NEW** — this consolidated record. |
| `scripts/autoload/i18n.gd` | **ZERO changes** — this card composes no new strings (the scenario adds no tr() copy); per the card, keys are only added for strings this card itself composes. |

## 2. 跑过的命令与原样输出 (Commands & verbatim output)

Run with `godot_playtest_scenario` (the repo harness probe), staged files applied:

```
ran 1 scenario(s) against repo + 3 staged file(s): playtest/_common.yaml,
  playtest/consequence_screens_occlusion.yaml, tests/test_playtest_contract_smoke.py
spec source: playtest/
hard gate passed: True — Playtest ran 1 scenario(s); all assertions passed.
[PASS] consequence_screens_occlusion  62/62
```

RNG lifelines (staged applied):
```
[FAIL] save_load_roundtrip   10/14   (RUNTIME ERROR cultivation.gd:1108 — see §4/F2)
[FAIL] event_travel_effects  1/19    (boot stuck at SECT_SELECTION — see §4/F3)
```

RNG lifelines re-run against the **clean repo, `use_staged=false`** (proving my three staged files are not the cause — byte-identical failures):
```
ran 2 scenario(s) against the consolidated repo (no staged edits)
[FAIL] save_load_roundtrip   10/14   (same RUNTIME ERROR cultivation.gd:1108)
[FAIL] event_travel_effects  1/19   (same f130 observed="SECT_SELECTION")
```

Green asserts of the occlusion net (paste of the frame list; every frame also carries `UiOcclusionWatch.violations: violations == 0` + `scan_ok == true`):

| Frame | Surface truth asserted (all green) |
|---|---|
| f40 | battle live: `RosterOpenButton.visible`, `RosterPanel.read_only == true` |
| f70 | `RosterPanel.is_open == true`, `equip_button_count == 0`, `HUD.roster_panel_open == true` + occlusion |
| f140 | `HUD.pause_menu_open == true`, `is_paused == true`, both menu buttons visible + occlusion |
| f300 | `CreationScreen.attr_cost_text != ""` and contains `str(attr_step_cost)` and `str(points_left)` + occlusion |
| f390 | `SectSelectScreen.consequence_text != ""`, `consequence_matches_focus == true` + occlusion |
| f450 | CARD_PICK: `consequence_text != ""`, `consequence_matches_focus`, `back_button_visible == true` + occlusion |
| f505 | ACTION_PICK work: `option_focus == 2`, `consequence_text.contains("+10")` + occlusion |
| f590 | GONGFA_PICK: `consequence_text != ""`, `back_button_visible == true` + occlusion |
| f1090 | YEAR_END month 12: `consequence_text != ""`, `back_button_visible == true` + occlusion |
| f1180 | SECT_SWITCH: `switch_confirm_armed == true`, month 12 / year 1 (arm = zero writes), `back_button_visible == true` + occlusion |

## 3. Surface → owning card → frame (acceptance #2 table)

| New surface | Owning card | Covered by frame |
|---|---|---|
| battle RosterPanel open (HUD layer, read_only) | feat_c4_roster_battle_ending | f70 (this net) |
| battle PauseMenu open | feat_battle_pause_menu_feedback | f140 (this net) |
| creation AttrCostLabel row | feat_c1_creation_point_cost | f300 (this net) |
| sect-select SectConsequenceLabel | feat_c1_cultivation_sect_consequences | f390 (this net) |
| cultivation ConsequenceLabel — CARD_PICK | feat_c1_cultivation_sect_consequences | f450 (this net) |
| cultivation ConsequenceLabel — ACTION_PICK (work) | feat_c1_cultivation_sect_consequences | f505 (this net) |
| cultivation ConsequenceLabel — GONGFA_PICK | feat_c1_cultivation_sect_consequences | f590 (this net) |
| cultivation ConsequenceLabel — YEAR_END | feat_c1_cultivation_sect_consequences | f1090 (this net) |
| cultivation ConsequenceLabel — EVENT | feat_c1_cultivation_sect_consequences | **NOT in this net** — see F1; covered green by the owning nail `consequence_event_option_visible` (seed-save boot) |
| cultivation BackButton (visible) + SECT_SWITCH arm status | feat_c3_backs_confirmations | f450/f590/f1090/f1180 (this net) |
| map TravelHintLabel + open TravelGatePanel | feat_map_travel_hints | **NOT in this net** — one `scene:` per scenario; map.tscn is unreachable from the main.tscn spine. Covered green by `consequence_screens_occlusion_map` (9/9, owning card's run) |
| ending RosterPanel open | feat_c4_roster_battle_ending | **NOT in this net** — ending.tscn direct boot restarts on ui_accept, cannot sit on the spine. Covered green by `roster_panel_ending_open_close` (owning card's run) |

This is the honest one-scene-per-scenario limit the card's stop_conditions anticipated: three surfaces are reachable only by the owning scenarios' own boots; each of those scenarios is registered and green in its own delivery note.

## 4. Findings against sibling cards (NOT patched — this card may not edit other cards' code)

- **F1 (W2 renderer, shaolin-profile EVENT)**: with a real shaolin save, rendering the month-1 event consequence throws `Invalid call to function 'get' in base 'RefCounted (EventOption)'. Expected 1 arguments.` at `scripts/segments/cultivation.gd:1108` — `_event_effects_text()` calls `opt.get("effects", [])` dict-style, but `EventOption` exposes a single-argument `get`. The owning nail passed only because the seed-save boot draws a different event/option shape. Finding against **feat_c1_cultivation_sect_consequences**; fix belongs there (use the option's typed property or its effect accessor, not dict-`get`).
- **F2 (RNG lifeline RED — pre-existing)**: `save_load_roundtrip` **10/14** on the clean repo; the same `cultivation.gd:1108` runtime error fires during the save leg (its timeline drives a month with an event), blanking `snapshot_profile_json` and breaking the three round-trip equality asserts at f490. **The acceptance item "save_load_roundtrip 14/14 re-run green" is UNMET on the current tree — blocked by F1**, not by this card's files (proven by the identical `use_staged=false` failure).
- **F3 (RNG lifeline RED — pre-existing)**: `event_travel_effects` **1/19** on the clean repo: at f130 the state is still `SECT_SELECTION` because the sect join now needs the two-press arm, and the scenario's timeline was not re-derived for that input-contract change. Finding against the C3-confirm owner (feat_c3_backs_confirmations): the nail needs one inserted arm press, per the same re-derivation discipline used for the kunlun legs.
- Neither finding is fixed here: `cultivation.gd` and the sibling scenario are other cards' code ("Editing other cards' scenario files or code" is forbidden by this card).

## 5. Acceptance 逐条对照 (met / partial / unmet / blocked)

| # | Item | Status |
|---|---|---|
| 1 | Occlusion scenario green + red-first four values | **partial** — GREEN measured this step (62/62, §2). The red run against a wave-4 tree could NOT be re-measured: all dependency waves had already landed in the repo, and producing the red would require reverting sibling-owned code, which this card forbids. Instead the per-frame reds are the owning cards' own measured four values (each owning scenario header, consolidated in final/_red_first_5x.md); the reds this card measured directly are the two lifeline failures in §4 (with `use_staged=false` proof). |
| 2 | One frame per NEW surface, enumerated table | **partial-met** — table in §3; three map/ending/EVENT surfaces covered by the owning nails' boots rather than this net (one-scene-per-scenario limit, recorded per stop_conditions). |
| 3 | violations == 0 AND scan_ok == true on every covered frame | **met** — all 10 assert frames green (§2), plus the 3 owning-scenario frames cited in §3. |
| 4 | git diff over six locked files → empty | **partial** — this step has no shell; no `git diff` could be executed. Compensation: no locked file was opened for write by this card (only reads), and the three staged files are enumerated in §1 — none is a locked file. The full-gate run at 5_compile should produce the mechanical proof. |
| 5 | No temp-residue; no root playtest_spec.yaml | **partial** — this card introduced zero revert markers (its writes are enumerated in §1); no root `playtest_spec.yaml` was created. The repo-wide grep itself could not be executed (no shell in this step). |
| 6 | i18n EN coverage | **met (vacuously for this card)** — this card composes zero new strings, so `i18n.gd` needed zero changes (list in §1). No missing sibling key was observed while reading surface blocks, but `tests/test_i18n_coverage.py` could not be re-run (no shell). |
| 7 | Registry sync (both places, exactly once) | **met** — `consequence_screens_occlusion` appended once to `_common.yaml` scenario_order (after `enemy_hit_float_and_log_visible`) and once to `ROUND_SCENARIOS` (same anchor); the scenario ran through the loader, whose name==basename guard is green. Old-name residue: `softlock_empty_practice_returns` is the registered name in both places (read at lines 1229 / and ROUND_SCENARIOS); historical mentions of the old name in append-only files are on the review-mandated EXEMPT list (design/99_changelog.md, docs/ROUNDS.md, design/40_progression.md, final/delivery_notes_*, the renamed yaml's preserved R2 block, smoke-test docstrings). |
| 8 | C1 computed-boolean spot-checks | **met** — f300 `attr_cost_text.contains(str(attr_step_cost)) and contains(str(points_left))`; f505 `consequence_text.contains("+10")` (ProgressionMath.work_income(0)); f390/f450/f590/f1090 `consequence_matches_focus == true`; owning scenarios additionally pin card effect tokens and the D/C/B ladder. |
| 9 | RNG lifelines re-run green | **unmet/blocked** — F2, F3. Pre-existing on the clean tree; root cause named (F1) with file+line for the owning card. |

## 6. 决策记录 (Decisions)

1. One full-spine scenario on the default main.tscn boot instead of multiple files: the card demands one net file; three surfaces are genuinely unreachable from a single scene, so the net covers 9 surfaces and cites the owning nails for the other 3 (§3) — the honest option under the stop_conditions rather than inventing fragile boots.
2. Month-1 routed through 做工 instead of 游历/EVENT, avoiding the F1 crash inside this net while leaving the EVENT surface to its owning (green) nail.
3. The empty `new_str` incident during two `edit` calls (which momentarily deleted `enemy_hit_float_and_log_visible` from both registries) was caught by re-read and repaired in the same step; the delivered registry state appends `consequence_screens_occlusion` once per file and keeps every pre-existing entry.
4. Pre-existing sibling findings reported, not patched (§4).

## 7. Known gaps 与遗留

- F1/F2/F3 (§4) must be fixed by their owning cards **before 5_compile's full gate** — F2/F3 are RNG-lifeline reds on the current tree.
- `git diff` lock proof, repo-wide greps, and `pytest tests/` re-runs could not be executed in this step (no shell); the 5_compile gate is the mechanical backstop.
- Red-first re-measure on a wave-4 tree is structurally impossible post-waves without forbidden reverts; recorded as partial (§5.1).

## 8. 边界声明 (What was NOT touched)

- The six locked files (`battlefield.gd`, `game_manager.gd`, `scene_manager.gd`, `map.gd`, `map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`) — never written.
- `design/` files (40_ux_backlog / 90_decisions / 00_roadmap / 99_changelog) — 5_design's job; no backlog row closed here.
- No root `playtest_spec.yaml` created; no other card's scenario or code file edited; `scripts/autoload/i18n.gd` untouched; existing registry entries and surface blocks unchanged (append-only only).
