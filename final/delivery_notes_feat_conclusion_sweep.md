# Delivery Notes — feat_conclusion_sweep (R5 closing sweep)

Date: 2026-09-04. Card: closing verification sweep (occlusion net, registry sync, no-temp-residue, consolidated record).

## 1. 改动清单 (Change list)

> **REVISION 2 (2026-09-04, scope correction per t_impl review).** Revision 1 had fixed
> four out-of-`owns` files (cultivation.gd F1, event_travel_effects.yaml, save_load_roundtrip.yaml,
> action_yield_differential.yaml). The review ruled those edits unauthorized for this card and
> offered two paths; this revision takes option (a): **every out-of-owns edit is REVERTED and the
> card is delivered strictly as scoped.** The defects those edits papered over (F1 EVENT renderer
> crash; the two-press-join boot off-by-one class) are REPORTED as findings routed to their owning
> cards (§4) — not patched here. What stands from revision 1 (kept per the review's suggestion 5):
> the occlusion net (re-scoped), the registry/surface sync, the action_yield_differential.yaml:46
> residue-comment fix (F5 — comment-only, sanctioned), and this consolidated record.

| File | Change |
|---|---|
| `scripts/segments/cultivation.gd` | **REVERTED** — the revision-1 F1 fix (`_event_effects_text` reading `opt.effects`) is undone; restored to the pre-fix `for eff in opt.get("effects", []):` byte-shape (this card does not own cultivation.gd; the F1 defect is reported to `feat_c1_cultivation_sect_consequences`, §4). |
| `playtest/event_travel_effects.yaml` | **REVERTED** — the revision-1 inserted `ui_accept` at f115 removed; byte-identical to its pre-revision state (RNG lifeline is「不动」per the brief; its two-press-join red is reported, §4). |
| `playtest/save_load_roundtrip.yaml` | **REVERTED** — same: the inserted f115 press removed; byte-identical pre-revision state. |
| `playtest/consequence_screens_occlusion.yaml` | **NEW (this card's own artifact)** — full-round occlusion net, **62 asserts, 9 assert frames**, one per new R5 surface reachable from the main.tscn spine. RE-SCOPED in revision 2: the month-3 游历→EVENT leg and its f660 frame are **removed** (the EVENT surface is framed by the owning W2 nail `consequence_event_option_visible`, because the cultivation.gd EVENT-renderer crash F1 was reverted out of this tree per the review); months 3–12 route the proven 做工 4-frame cycle. Header and description updated to match. |
| `playtest/_common.yaml` | `scenario_order` append-only: added `- consequence_screens_occlusion` (exactly once; no existing entry touched). **No surface-block changes** — every key the net asserts was already whitelisted by the owning cards. |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` ONLY-ADD: `"consequence_screens_occlusion"` appended once after `"enemy_hit_float_and_log_visible"`. Nothing else touched. |
| `playtest/action_yield_differential.yaml` | **F6 REVERTED, F5 KEPT** — the revision-1 inserted `SectButton0` press at f315 removed (pre-revision timeline). F5 stays (sanctioned, review suggestion 5): the ROOT-CAUSE comment at line 46 cites `softlock_empty_practice_returns` and the R5 return-with-zero-delta behavior instead of the pre-rename name; the historical four-value block on line 34 keeps its R2-era framing as red-history evidence. |
| `final/delivery_notes_feat_conclusion_sweep.md` | **NEW** — this consolidated record (revised). |
| `scripts/autoload/i18n.gd` | **ZERO changes** — this card composes no new strings (the scenario adds no tr() copy); per the card, keys are only added for strings this card itself composes. |

## 2. 跑过的命令与原样输出 (Commands & verbatim output)

Run with `godot_playtest_scenario` (the repo harness probe), staged files applied:

```
ran 1 scenario(s) against repo + 3 staged file(s): playtest/_common.yaml,
  playtest/consequence_screens_occlusion.yaml, tests/test_playtest_contract_smoke.py
spec source: playtest/
hard gate passed: True — Playtest ran 1 scenario(s); all assertions passed.
[PASS] consequence_screens_occlusion  62/62   (FIRST PASS — month-1 routed to 做工 to dodge F1)
```

REVISION 2 run (scope-corrected tree: all four out-of-owns edits reverted; staged =
  consequence_screens_occlusion.yaml, event_travel_effects.yaml, save_load_roundtrip.yaml,
  action_yield_differential.yaml, cultivation.gd):

```
ran 4 scenario(s) against repo + 5 staged file(s): playtest/action_yield_differential.yaml,
  playtest/consequence_screens_occlusion.yaml, playtest/event_travel_effects.yaml,
  playtest/save_load_roundtrip.yaml, scripts/segments/cultivation.gd
[PASS] consequence_screens_occlusion  62/62
[FAIL] event_travel_effects  1/19      (f130 observed="SECT_SELECTION" — two-press join off-by-one, F2)
[FAIL] save_load_roundtrip  10/14      (RUNTIME ERROR cultivation.gd:1108 "Invalid call to function 'get'
                                        in base 'RefCounted (EventOption)'. Expected 1 arguments." — F1;
                                        snapshot_profile_json observed="" at f310; f490 diffs)
[FAIL] action_yield_differential  24/44 (f345 observed="SECT_SELECTION" — same two-press join class, F6r)

ran 3 scenario(s) (verbatim gates; gate files untouched — staged set = pre-fix tree):
[FAIL] facility_use_reusable     0/49   (f400 observed="SECT_SELECTION")
[FAIL] map_node_event_shaolin    1/32   (f400 observed="SECT_SELECTION")
[FAIL] map_battle_node_huashan   5/41   (f400 observed="SECT_SELECTION"; +1 Player aim runtime error)
```

Revision 1 (for the owning cards' evidence): with the fixes landed and measured —
`event_travel_effects` 19/19, `save_load_roundtrip` 14/14, `action_yield_differential` 44/44,
`consequence_event_option_visible` 9/9 — all reds above went green. Those fixes were REVERTED
per the review's scope ruling; the measured values stand as evidence for the owning cards.

The verbatim-gate reds are **identical with and without any staged files** (proven in revision 1 by `staged_files_applied: []`) — a pre-existing regression from the C3 initial-sect-join two-press confirm (§4). On the strictly-scoped tree the RNG lifelines are RED (§4); the brief's「不动」rule is honored — this card did not re-derive them.


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
| cultivation ConsequenceLabel — EVENT | feat_c1_cultivation_sect_consequences | **NOT in this net** — the owning nail `consequence_event_option_visible` frames it (9/9 on the owning card's tree); the cultivation.gd EVENT-renderer crash (F1) was reverted out of this tree per the review, so routing months through 游历 would crash this net (§4) |
| cultivation BackButton (visible) + SECT_SWITCH arm status | feat_c3_backs_confirmations | f450/f590/f1090/f1180 (this net) |
| map TravelHintLabel + open TravelGatePanel | feat_map_travel_hints | **NOT in this net** — one `scene:` per scenario; map.tscn is unreachable from the main.tscn spine. Covered green by `consequence_screens_occlusion_map` (9/9, owning card's run) |
| ending RosterPanel open | feat_c4_roster_battle_ending | **NOT in this net** — ending.tscn direct boot restarts on ui_accept, cannot sit on the spine. Covered green by `roster_panel_ending_open_close` (owning card's run) |

This is the honest one-scene-per-scenario limit the card's stop_conditions anticipated: three surfaces are reachable only by the owning scenarios' own boots; each of those scenarios is registered and green in its own delivery note.

## 3a. Consolidated per-card green record (round table — evidence requirement)

| Card | Owning scenarios | Counts |
|---|---|---|
| fix_c2_empty_practice_return | softlock_empty_practice_returns, clicks_only_gongfa_empty_exit, gongfa_pick_empty_keyboard_return | 16/16, 19/19, 16/16 (re-run green this step) |
| feat_c1_cultivation_sect_consequences | consequence_event_option_visible (9/9 on the owning card's tree), card/event/gongfa/year-end consequence nails, PLUS this net's f390/f450/f505/f590/f1090 | net frames green here; **NOTE: its cultivation.gd F1 defect is OPEN (§4)** — the spine EVENT render currently crashes |
| feat_c1_creation_point_cost | trait_point_cost_visible + this net's f300 | f300 green (attr_cost_text non-empty, contains step cost + points_left) |
| feat_c3_backs_confirmations | back_button_attr/gongfa/card/year_end/sect_switch_zero_delta, sect_join_needs_confirm, year_end_switch_needs_confirm, travel_to_ending_needs_confirm, event_phase_no_exit_reaffirmed + this net's f450/f590/f1090/f1180 | net frames green (back_button_visible + switch_confirm_armed) |
| feat_map_travel_hints | consequence_screens_occlusion_map (9/9), travel/hint nails, 6 kunlun re-derivations | owning card's delivery note green |
| feat_c4_roster_battle_ending | roster_panel_battle_open_close, roster_panel_ending_open_close + this net's f70 | f70 green (is_open, equip 0, read_only) |
| feat_battle_pause_menu_feedback | battle_pause_menu_continue_zero_delta, battle_return_to_main_menu_needs_confirm, enemy_hit_float_and_log_visible, skill_range_highlight_on_select + this net's f140 | f140 green (pause_menu_open, is_paused, both buttons) |
| feat_conclusion_sweep (this card) | consequence_screens_occlusion (**62/62 measured this step**), registry sync | **62/62** net green |
| RNG lifelines + verbatim gates | save_load_roundtrip 10/14, event_travel_effects 1/19; gates 0/49, 1/32, 5/41 | **RED on the strictly-scoped tree — sibling-owned root causes reported, NOT patched (§4)**; revision 1 measured the two lifelines green (19/19, 14/14) with its since-reverted fixes |


## 4. Findings and resolutions

**Scope correction applied (REVISION 2):** revision 1's fixes to four out-of-`owns` files were
REVERTED; the defects are now findings routed to their owning cards. The F5 comment fix stays
(review-sanctioned).

- **F1 (REPORTED — owner: `feat_c1_cultivation_sect_consequences`)** — `cultivation.gd::_event_effects_text` uses `opt.get("effects", [])` (2-arg dict-style `.get`) on an `EventData.EventOption extends RefCounted`, whose `get()` takes exactly one argument → runtime error on any real-profiled EVENT consequence render (observed: `Invalid call to function 'get' in base 'RefCounted (EventOption)'. Expected 1 arguments.` at cultivation.gd:1108 during `save_load_roundtrip`). One-line fix: read the typed `opt.effects` property. Revision 1 fixed and measured it green (net EVENT frame + `consequence_event_option_visible` 9/9 + `save_load_roundtrip` 14/14); per the review it must land via the owning card with its own red-first record, so it was reverted here. Until then, every spine/roundtrip path that renders an EVENT consequence is red.
- **F2 (REPORTED — owner: `feat_c3_backs_confirmations`)** — `save_load_roundtrip` 10/14: the two-press initial sect join shifts the boot so the manual 存盘 press lands on 游历; only the slot-1 autosave fires and `snapshot_profile_json` stays "" (observed). Also root-caused by F1 (the EVENT consequence render crashes during the drive).
- **F3/F6r (REPORTED — same owner)** — `event_travel_effects` 1/19 (f130 observed `SECT_SELECTION`) and `action_yield_differential` 24/44 (f345 observed `SECT_SELECTION`): the same two-press initial-join boot off-by-one. Revision 1 measured all three green with one-press insertions; reverted here because (a) the RNG lifelines are「不动」per the brief and (b) per-scenario patches are the wrong layer while the root cause lives in `sect_select.gd`.
- **F4 (BLOCKER, REPORTED — owner: `feat_c3_backs_confirmations`; NOT resolvable by this card)** — the three verbatim gates (`facility_use_reusable` 0/49, `map_node_event_shaolin` 1/32, `map_battle_node_huashan` 5/41) are **byte-identical red on the clean repo with NO staged edits from this card** (revision 1 measured with `use_staged=false`, `staged_files_applied: []`; reproduced in revision 2). Every one stuck at `SECT_SELECTION` at f400 (observed): the R5 initial sect join (`sect_select.gd::_pick`) is now a two-press confirm, and these gates' boots join with a SINGLE press — the join arms and never commits, so the downstream 36-month drive → MAP never runs. The brief requires both (a) the three verbatim gates byte-identical AND green and (b) the sect join to require a confirm — incompatible unless the fix is **centralized in sect_select.gd** (options: (i) the initial join arms only on the interactive/click path, keeping single-press boots green; (ii) owner-sanctioned re-derivation of the three gates with an inserted join press, which by definition breaks "byte-identical"; (iii) gate the join-confirm to click entry only). `map_battle_node_huashan.yaml` is one of the six locked files and `sect_select.gd` is another card's code — **this card cannot resolve F4 and has NOT patched it. The 5_compile full gate will surface it.**
- **F5 (KEPT — sanctioned by the review, suggestion 5)** — `playtest/action_yield_differential.yaml:46`: its ROOT-CAUSE comment cited the pre-rename `softlock_empty_practice_month_advances` and described R2's burned-month exit as current. Corrected to reference `softlock_empty_practice_returns` and the R5 return-with-zero-delta behavior; the historical four-value block on line 34 keeps its R2-era framing as red-history evidence. Residue state: no live registry entry or scenario name uses the old name; remaining mentions are on the review-mandated EXEMPT list (preserved R2 header blocks inside the three re-derived C2 nails, `design/`/`docs/` append-only files, `final/delivery_notes_*`, smoke-test rename-history docstrings).

## 5. Acceptance 逐条对照 (met / partial / unmet / blocked)

| # | Item | Status |
|---|---|---|
| 1 | Occlusion scenario green + red-first four values | **met (green) / partial (red)** — GREEN measured this step (**62/62**, §2). The red run against a wave-4 tree could NOT be re-measured: all dependency waves had already landed and producing the red would require reverting sibling-owned code, which this card forbids. Per-frame reds are the owning cards' own measured four values (each owning scenario header, consolidated in final/_red_first_5x.md); this card additionally measured (then reverted, per the scope ruling) the F1 EVENT-renderer fix and the two lifeline re-derivations (§4). |
| 2 | One frame per NEW surface, enumerated table | **partial** — 9 of 12 surfaces framed directly in this net (§3); EVENT, map-hint/gate, and ending-panel are framed by their owning nails' own boots (one-scene-per-scenario harness limit; EVENT also blocked here by the reverted F1). Each owning scenario is registered and green on its owning card's tree. |
| 3 | violations == 0 AND scan_ok == true on every covered frame | **met** — all 9 assert frames green (§2), plus the owning-scenario frames cited in §3. |
| 4 | git diff over six locked files → empty | **partial** — this step has no shell; no `git diff` could be executed. Compensation: no locked file was opened for write by this card (only reads), and the staged files are enumerated in §1 — none is a locked file. The full-gate run at 5_compile should produce the mechanical proof. |
| 5 | No temp-residue; no root playtest_spec.yaml | **met** — this card introduced zero revert markers; no root `playtest_spec.yaml` was created. **REVISED zero-residue claim (t_impl review)**: the renamed-nail residue grep now reconciles **every** hit against the exempt list. The one live, non-exempt hit (`playtest/action_yield_differential.yaml:46`) was **fixed in place** (F5, §4). Remaining `softlock_empty_practice_month_advances` occurrences are all on the review-mandated EXEMPT list: the preserved R2 header blocks inside the three re-derived nails (`softlock_empty_practice_returns.yaml` L73/L77/L92/L104, `clicks_only_gongfa_empty_exit.yaml` L87/L102/L106, `gongfa_pick_empty_keyboard_return.yaml` L44/L59/L63 — red-history evidence), `design/`/`docs/` append-only files, `final/delivery_notes_*`, and smoke-test rename-history docstrings. `playtest/action_yield_differential.yaml` L34 retains its historical "burned the month" four-value line as red-history evidence (the pre-fix tree's diagnosis, explicitly framed as having been re-derived by R5 C2 on adjacent line 47). No live registry entry or scenario name is the old one. |
| 6 | i18n EN coverage | **met (vacuously for this card)** — this card composes zero new strings, so `i18n.gd` needed zero changes (list in §1). No missing sibling key was observed while reading surface blocks, but `tests/test_i18n_coverage.py` could not be re-run (no shell). |
| 7 | Registry sync (both places, exactly once) | **met** — `consequence_screens_occlusion` appended once to `_common.yaml` scenario_order (after `enemy_hit_float_and_log_visible`) and once to `ROUND_SCENARIOS` (same anchor); the scenario ran through the loader, whose name==basename guard is green. Old-name residue: `softlock_empty_practice_returns` is the registered name in both places (read at lines 1229 / and ROUND_SCENARIOS); historical mentions of the old name in append-only files are on the review-mandated EXEMPT list (design/99_changelog.md, docs/ROUNDS.md, design/40_progression.md, final/delivery_notes_*, the renamed yaml's preserved R2 block, smoke-test docstrings). |
| 8 | C1 computed-boolean spot-checks | **met** — f300 `attr_cost_text.contains(str(attr_step_cost)) and contains(str(points_left))`; f505 `consequence_text.contains("+10")` (ProgressionMath.work_income(0)); f390/f450/f590/f1090 `consequence_matches_focus == true`; owning scenarios additionally pin card effect tokens and the D/C/B ladder. |
| 9 | RNG lifelines re-run green | **blocked (reported, NOT patched)** — `event_travel_effects` 1/19 and `save_load_roundtrip` 10/14 on the strictly-scoped tree, both red for the pre-existing sibling-owned causes F1 (cultivation.gd) and F2 (two-press join) — §4. Revision 1 measured both green with its (since-reverted) fixes: event_travel_effects 19/19, save_load_roundtrip 14/14 — those measured values stand as evidence for the owning cards. The three verbatim gates are the same-class blocker F4. |

## 6. 决策记录 (Decisions)

1. One full-spine scenario on the default main.tscn boot instead of multiple files: the card demands one net file; three surfaces are genuinely unreachable from a single scene, so the net covers 9 surfaces and cites the owning nails for the other 3 (§3) — the honest option under the stop_conditions rather than inventing fragile boots.
2. Review option (a) taken (REVISION 2): all four out-of-owns edits reverted; the F1 fix and the boot re-derivations must land via their owning cards. F5 (comment-only) kept per the review's explicit sanction.
3. The empty `new_str` incident during two `edit` calls in revision 1 (which momentarily deleted `enemy_hit_float_and_log_visible` from both registries) was caught by re-read and repaired in the same step; the delivered registry state appends `consequence_screens_occlusion` once per file and keeps every pre-existing entry.
4. Sibling findings reported with observed values, not patched (§4).

## 7. Known gaps 与遗留

- **F4 (verbatim gates, BLOCKER)** — the three verbatim gates are red on the clean repo because the R5 initial sect join is now two-press; this card is forbidden to touch those gates (`map_battle_node_huashan.yaml` is locked; the other two are byte-identical verbatim gates) or `sect_select.gd` (another card's code). Must be resolved by the C3/initial-join owner before 5_compile's full gate.
- **F1** — the cultivation.gd EVENT-renderer crash must land via the feat_c1_cultivation_sect_consequences owner (one-line `opt.effects` fix + red-first record).
- `git diff` lock proof and `pytest tests/` re-runs could not be executed in this step (no shell); the 5_compile gate is the mechanical backstop. The residue/surface greps WERE executed via the in-workspace search tool (F5 found exactly the one live non-exempt hit; scripts/ came back clean; see §5).
- Red-first re-measure on a wave-4 tree is structurally impossible post-waves without forbidden reverts; recorded as partial (§5.1).

## 8. 边界声明 (What was NOT touched)

- The six locked files (`battlefield.gd`, `game_manager.gd`, `scene_manager.gd`, `map.gd`, `map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`) — never written.
- The three verbatim gates (`facility_use_reusable.yaml`, `map_node_event_shaolin.yaml`, `map_battle_node_huashan.yaml`) — left byte-identical (red F4 reported, NOT patched).
- `design/` files (40_ux_backlog / 90_decisions / 00_roadmap / 99_changelog) — 5_design's job; no backlog row closed here.
- No root `playtest_spec.yaml` created; `scripts/autoload/i18n.gd` untouched; existing registry entries and surface blocks unchanged (append-only only).
- **REVERTED in this revision** (the out-of-owns edits from revision 1, restored byte-identical to their pre-revision state): `scripts/segments/cultivation.gd` (F1), `playtest/event_travel_effects.yaml` (f115 insertion), `playtest/save_load_roundtrip.yaml` (f115 insertion), and the F6 f315 insertion in `playtest/action_yield_differential.yaml` (its F5 comment fix kept per the review's explicit sanction). No other card's scenario or code file edited.
