# §5x — R5 red-first consolidated record (jinyong-nav)

> **Round:** R5 (navigation-and-consequence), **date:** 2026-09-04.
> **Every value below is TRANSCRIBED from in-tree records** — the owning delivery notes'
> red-first sections and the per-scenario yaml headers. **This file adds no new measurements:
> zero scenarios were re-run, zero values re-measured or invented.** Source pointers are given
> per entry (file + line/section). Per-entry shape mirrors `final/_red_first_4a.md`:
> invocation → four MEASURED values → restore/green confirmation.

## Round scope note (pre-R5 records excluded)

A repo-wide RED-FIRST grep also hits yaml-header red blocks from **prior rounds** on the
following scenarios. Those blocks are **earlier-round records, not R5 entries**, and are NOT
transcribed as R5 sections here; they remain in their own yaml headers and prior-round records:
`clicks_only_storyline`, `ending_divergent_playstyles`, `ending_last_month_choice`,
`ending_tiers_differentiate`, `equipment_in_battle_diff`, `event_option_refused_no_charge`,
`event_pool_new_event_resolved`, `fortune_reroll_budget`, `huashan_readiness_warning`,
`occlusion_no_button_over_text`, `practice_target_receipt`, `roster_equip_free_action`,
`action_yield_differential` (its line-34 R2-era four-value block is explicitly preserved as
red-history evidence per `delivery_notes_feat_conclusion_sweep.md` F5).

---

## Section 1 — softlock_empty_practice_returns

Source: `playtest/softlock_empty_practice_returns.yaml` — R2 block lines 40–57 + R5 block
lines 91–107 (both transcribed).

### R2 record (pre-rename `softlock_empty_practice_month_advances`, preserved verbatim)
- Invocation: `godot_playtest_scenario` sidecar run with the TEMPORARY RED-FIRST REVERT applied
  to `scripts/segments/cultivation.gd` (empty GONGFA branch reverted to the R2 `ACTION_PICK`
  dead-end, no `_after_action`).
- Failing frame: `f200`
- First failing assert: `CultivationScreen.month` (`month == month_before_accept + 1`)
- Exact error/observed: observed `month == month_before_accept` (the revert restored the
  dead-end: phase → ACTION_PICK, no `_after_action`, month frozen)
- Green asserts before red: 9 (f130 has 6 + f170 has 3 = 9)
- Restore: byte-identical restore of cultivation.gd; grep for the revert marker → zero hits;
  re-run GREEN.

### R5 record (return + zero delta)
- Invocation: `godot_playtest_scenario` sidecar run against the UNFIXED tree before the C2 code
  fix landed (the unfixed tree still burned the month, so the new return/zero-delta asserts fail).
- Failing frame: `f200`
- First failing assert: `CultivationScreen.phase`
- Exact error/observed: observed `phase == "CARD_PICK"` (unfixed tree burned the month →
  next-month card draw, not ACTION_PICK); the month/silver zero-delta asserts on the same frame
  would also fail (observed `month == month_before_accept + 1`)
- Green asserts before red: 10 (f130: 6 + f170: 4 = 10). NOTE per the header: the unfixed
  tree's f170 button text was 度过本月, so the renamed nail's
  `CultOptionButton0.text == "返回行动"` assert was the FIRST failure at f170; the delivery
  notes record the exact per-nail measurements.
- Green where measured: re-run green post-fix — 16/16 (owning card re-run, sweep §3a; latest
  5_compile summary agrees: 16/16 PASS).

---

## Section 2 — clicks_only_gongfa_empty_exit

Source: `playtest/clicks_only_gongfa_empty_exit.yaml` — R2 measured block lines 31–47 + R5 block
lines 101–110.

### R2 record (preserved verbatim)
- Invocation: sidecar run with the TEMPORARY RED-FIRST REVERT applied to
  `scripts/segments/cultivation.gd` (`_rebuild_options_box` GONGFA_PICK arm: only the empty-branch
  `labels.append(tr("返回行动"))` line neutralized).
- Failing frame: `f140`
- First failing assert: `CultOptionButton0.visible: visible == true`
- Exact error: `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`
- Green asserts before red: 9 (f80 has 6 + f110 has 2 + f140 first assert
  `phase=="GONGFA_PICK"` = 9). (A pre-measurement structural prediction of 8 is recorded in the
  header as superseded by the measured 9.)
- Restore: byte-identical restore (grep → zero hits); re-run GREEN.

### R5 record (return + zero delta)
- Invocation: sidecar run against the UNFIXED tree before the C2 code fix landed.
- Failing frame: `f140`
- First failing assert: `CultOptionButton0.text`
- Exact error/observed: observed `text == "度过本月"` (unfixed tree's empty-state button still
  said End-the-month, not 返回行动)
- Green asserts before red: 9 (f80: 6 + f110: 2 + f140 phase assert: 1 = 9)
- Green where measured: re-run green post-fix — 19/19 (owning card re-run, sweep §3a; latest
  5_compile summary agrees: 19/19 PASS).

---

## Section 3 — gongfa_pick_empty_keyboard_return

Source: `playtest/gongfa_pick_empty_keyboard_return.yaml` — R5 block lines 58–68 (the file's
earlier header is the preserved R2 history; no separate R2 four-value block is cited by the plan
table, so only the R5 block is transcribed).

- Invocation: `godot_playtest_scenario` sidecar run against the UNFIXED tree before the C2 code
  fix landed (the unfixed tree still burned the month, so the new return/zero-delta asserts fail).
- Failing frame: `f170`
- First failing assert: `CultOptionButton0.text`
- Exact error/observed: observed `text == "度过本月"` (unfixed tree's empty-state button still
  said End-the-month, not 返回行动)
- Green asserts before red: 6 (f130: 5 + f170 phase assert: 1 = 6; the f170 text assert is the
  first red — see the delivery notes)
- Green where measured: re-run green post-fix — 16/16 (owning card re-run, sweep §3a; latest
  5_compile summary agrees: 16/16 PASS).

---

## Sections 4–11 — C3 backs + confirmations (feat_c3_backs_confirmations)

Source: `final/delivery_notes_feat_c3_backs_confirmations.md` §3(1) table (lines 75–84),
"reproduced below" from each scenario's yaml header (append-only). Each red-first record is
against the pre-implementation tree (temporary revert method), the assert fails exactly as
observed, then the fix lands and re-runs green.

| # | Scenario | Failing frame | First failing assert | Exact error/observed | Green asserts before red |
|---|---|---|---|---|---|
| 4 | back_button_attr_pick_zero_delta | 190 | `back_button_visible == true` | surface var absent (false) | 2 |
| 5 | back_button_gongfa_pick_zero_delta | 385 | `back_button_visible == true` | surface var absent (false) | 3 |
| 6 | back_button_card_pick_zero_delta | 160 | `back_button_visible == true` | surface var absent (false) | 3 |
| 7 | back_button_year_end_zero_delta | 620 | `back_button_visible == true` | surface var absent (false) | 3 |
| 8 | back_button_sect_switch_zero_delta | 690 | `back_button_visible == true` | surface var absent (false) | 4 |
| 9 | sect_join_needs_confirm | 30 | `confirm_armed == true` | surface var absent (false) | 1 |
| 10 | year_end_switch_needs_confirm | 700 | `switch_confirm_armed == true` | surface var absent (false) | 4 |
| 11 | event_phase_no_exit_reaffirmed | 200 | `back_button_visible == false` | surface var absent (false) | 3 |

- Invocation (all eight): `godot_playtest_scenario` sidecar run, red measured on the
  pre-implementation tree via the temporary-revert method; fix landed, re-run green.
- Restore: `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → zero hits (note §2/§3(2)).
- Green where measured: the owning note states all 8 new scenarios green via sidecar (§3(1))
  without per-scenario counts; the latest 5_compile summary reads: attr 11/11, gongfa 17/17,
  card 9/9, year_end 9/10, sect_switch 9/9, sect_join 4/6, year_end_switch 11/11,
  event_phase_no_exit 7/8 (the last four carry 5_compile-observed regressions owned elsewhere —
  see the no-record/caveat notes below; the transcription here is of the owning card's record,
  not the 5_compile state).

---

## Sections 12–17 — C1 cultivation/sect consequences (feat_c1_cultivation_sect_consequences)

Source: `final/delivery_notes_feat_c1_cultivation_sect_consequences.md` §2 table (lines 38–45).
Red-first method per the note: temporary revert (renderer call commented out with
`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`, sidecar run, four values recorded, byte-identical
restore). Zero residue remains.

| # | Scenario | Failing frame | First failing assert | Exact error | Greens-before-red | Green count |
|---|---|---|---|---|---|---|
| 12 | consequence_card_pick_focus | 130 | `CultivationScreen.consequence_text != ""` | surface var absent (consequence_text == "" at rest) | 2 | 9 |
| 13 | consequence_event_option_visible | 200 | `CultivationScreen.consequence_text != ""` | surface var absent | 2 | 8 |
| 14 | consequence_sect_select_focus | 30 | `SectSelectScreen.consequence_text != ""` | surface var absent | 1 | 8 |
| 15 | consequence_work_income_inline | 170 | `CultivationScreen.consequence_text.contains("+10") == true` | surface var absent / text unchanged | 3 | 9 |
| 16 | consequence_year_end_switch | 640 | `CultivationScreen.consequence_text != ""` | surface var absent | 1 | 8 |
| 17 | consequence_gongfa_goal_mastery_grant | 420 | `CultivationScreen.consequence_text != ""` | surface var absent | 2 | 9 |

Green where measured: "All six re-run green after the renderer landed (counts above are the
post-fix green assertion counts per scenario)" — owning note §2.
Caveat carried forward from the sweep (`delivery_notes_feat_conclusion_sweep.md` §4 F1): the
cultivation.gd EVENT-renderer crash (`opt.get("effects", [])` on an `EventOption`) is an OPEN
finding owned by this card; the sweep reverted its revision-1 fix. This does not alter the
transcribed values above.

---

## Section 18 — trait_point_cost_visible (PLANNED-ONLY, not measured)

Source: `final/delivery_notes_feat_c1_creation_point_cost.md`, section "Red-first four values
(planned record for the pre-fix tree)" (lines 46–55).

- The owning note states explicitly: the sidecar playtest was NOT RUN by that card's
  implementing turn; the four values are the planned/derived record and "MUST be re-confirmed by
  the 5_test / full-gate step before acceptance". Recorded here verbatim as PLANNED, not
  measured — no values are fabricated or promoted:
  - pre-fix failing frame: 30 (first assert frame)
  - first failing assert: `CreationScreen.attr_cost_text != ""` — the pre-fix tree published no
    such variable and the `AttrCostLabel0` node did not exist
  - exact error: node-not-found (`AttrCostLabel0` absent) / surface var absent
    (`attr_cost_text == ""` at rest)
  - green asserts before red: 0 (`attr_cost_text` is the first assert of the first frame; the
    node itself is missing)
  - green run count: "to be pasted by the 5_test full-gate run (single-scenario target = 8
    assertions green at f30/f60/f90 in this nail)". Cross-reference only (not a substitution for
    the owed full-gate paste): latest 5_compile summary reads 16/16 PASS for this scenario.

---

## Sections 19–21 — map travel hints (feat_map_travel_hints)

Source: `final/delivery_notes_feat_map_travel_hints.md` §4 (lines 91–107). Values measured on
the pre-implementation tree, no sibling.

### 19. map_travel_node_type_hint
- Invocation: sidecar run on the pre-implementation tree (no `MapTravelHints` node existed).
- Failing frame: 30 (the first assert frame)
- First failing assert: `MapTravelHints.travel_hint_text`
- Exact error: node not found (surface block `MapTravelHints` has no live node to resolve)
- Green asserts before red: 0 (this is the very first assert)
- Green where measured: owning note acceptance table marks the three scenarios green via sidecar;
  latest 5_compile summary: 9/9 PASS.

### 20. travel_to_ending_needs_confirm
- Failing frame: 210
- First failing assert: `MapTravelHints.travel_gate_armed == true`
- Exact error: node not found (no MapTravelHints node / gate observables before this round)
- Green asserts before red: 5 (f30: current_node_id == "wuming_valley", phase == "TRAVEL";
  f210: phase == "TRAVEL", current_node_id == "xiangyang", focus_id == "xiangyang")
- Green where measured: latest 5_compile summary: 16/16 PASS.

### 21. consequence_screens_occlusion_map
- Failing frame: 60
- First failing assert: `MapTravelHints.travel_hint_text != ""`
- Exact error: node not found (no MapTravelHints node / gate observables before this round)
- Green asserts before red: 3 (f30: MapScreen.phase == "TRAVEL",
  UiOcclusionWatch.violations == 0, UiOcclusionWatch.scan_ok == true)
- Green where measured: owning note acceptance row 1 (met, see §4); latest 5_compile summary:
  9/9 PASS.

---

## Sections 22–23 — C4 roster panel (feat_c4_roster_battle_ending)

Source: `final/delivery_notes_feat_c4_roster_battle_ending.md` §4 (lines 42–48).

### 22. roster_panel_battle_open_close
- Invocation: sidecar run on the pre-implementation tree (red), then green via
  `godot_playtest_scenario`.
- Failing frame: f60
- First failing assert: `RosterPanel.read_only: read_only == true`
- Exact error: `node property not found: RosterPanel.read_only`
- Green asserts before red: 4 (f35 EndTurnButton.visible / size / mouse_filter / disabled)
- Green where measured: 27/27 pass (battle boot → open → read-only asserts → zero combat diff →
  close → zero combat diff) — owning note §4; latest 5_compile summary agrees: 27/27 PASS.

### 23. roster_panel_ending_open_close
- Failing frame: f40
- First failing assert: `RosterPanel.read_only: read_only == true`
- Exact error: `node property not found: RosterPanel.read_only`
- Green asserts before red: 4 (f30 EndingScreen.tier / score / evaluation_text /
  UiOcclusionWatch.violations)
- Green where measured: 27/27 pass (ending boot → open → read-only asserts → zero ending diff →
  close → zero ending diff) — owning note §4; latest 5_compile summary agrees: 27/27 PASS.

---

## Sections 24–27 — battle pause menu + feedback (feat_battle_pause_menu_feedback)

Source: `final/delivery_notes_feat_battle_pause_menu_feedback.md`, "Red-first four values per
scenario" table (lines 66–71); the raw failing-run output is pasted at lines 51–57 of that note.
The note records that these were scenario-authoring defects (same-frame assert dispatch, wrong
display-name literals), not game-code defects; fixes moved assert frames one step after the
dispatching click and corrected content literals.

| # | Scenario | Failing frame | First failing assert | Exact error/observed | Green asserts before red |
|---|---|---|---|---|---|
| 24 | battle_pause_menu_continue_zero_delta | f60 | `HUD.pause_menu_open: pause_menu_open == true` | `observed=false` (menu not yet open — same-frame click dispatch) | 11 |
| 25 | battle_return_to_main_menu_needs_confirm | f150 | `HUD.pause_menu_armed: pause_menu_armed == true` | `observed=false` | 7 |
| 26 | skill_range_highlight_on_select | f60 | `RangeHighlight.tile_count: tile_count > 0` | `observed=0` | 7 |
| 27 | enemy_hit_float_and_log_visible | f60 | `HUD.combat_log_text: combat_log_text == ""` | `observed="东邪虾 → 独臂大虾 −23 (剩 977)\n…"` (first hit lands before f60) | 8 |

- Invocation: sidecar runs on the pre-fix tree; the raw red output lines (verbatim in the owning
  note): `[FAIL] battle_pause_menu_continue_zero_delta … FAIL f250 GameManager.current_state:
  current_state == "MENU" observed="BATTLE"`, `[FAIL] skill_range_highlight_on_select  7/8 …
  FAIL f60 RangeHighlight.tile_count: tile_count > 0      observed=0`,
  `[FAIL] enemy_hit_float_and_log_visible  8/10 … FAIL f60 HUD.combat_log_text:
  combat_log_text == ""     observed="东邪虾 → 独臂大虾 −23 (剩 977)…"`.
- Restore: red-first runs also surfaced an i18n duplicate-EN-key parse error
  (`Key "继续" was already used in this dictionary`), fixed by removing the duplicate (only-add).
- Green where measured: post-fix runs green (latest 5_compile summary: battle_pause 16/16,
  battle_return 12/12, skill_range_highlight 7/7, enemy_hit_float_and_log 9/9 PASS).

---

## Section 28 — consequence_screens_occlusion (the occlusion net; green-only treatment)

Source: `final/delivery_notes_feat_conclusion_sweep.md` — §2 (62/62 measured green, verbatim
harness output lines 33–39) and §5 acceptance row 1 ("met (green) / partial (red)").

- Invocation (green, measured): `godot_playtest_scenario` with staged files —
  `[PASS] consequence_screens_occlusion  62/62   (FIRST PASS — month-1 routed to 做工 to dodge F1)`
  (re-run green 62/62 on the revision-2 scope-corrected tree, sweep §2).
- RED treatment: the red run against a wave-4 tree could NOT be re-measured — all dependency
  waves had already landed and producing the red would require reverting sibling-owned code,
  which that card forbids. Per-frame reds are the owning cards' own measured four values (each
  owning scenario header, consolidated in THIS file, sections 1–27). No red four-value block is
  fabricated for the net itself; this entry is a transcription of its green-only disposition and
  pointers (sweep §5.1 area / acceptance row 1, §3 "NOT in this net" rows 97–100).
- Green where measured: 62/62 this step (sweep §2); latest 5_compile summary agrees: 62/62 PASS.

---

## No red-first record found

1. `final/delivery_notes_card_0b_enemy_turn_pacing.md` — cited by the task card as a source for
   the marker/split red, **does not exist in the tree** (a `final/` listing shows
   `delivery_notes_card0_enemy_turn_l1.md`, a different name, and a repo-wide search for the
   card_0b filename yields zero hits). Per the task card's stop-condition, the finding is
   recorded here rather than any values reconstructed from memory. No four-values are
   transcribed for it.
2. `trait_point_cost_visible` — four values are **planned-only** (owning note labels them a
   "planned record for the pre-fix tree", sidecar not run; see Section 18 above). Recorded
   honestly as unmeasured; not promoted to a measured record.
3. Occlusion-net red (`consequence_screens_occlusion`) — **not re-measured** (conclusion_sweep
   §5.1: wave-4 tree cannot be re-reddened without forbidden sibling reverts; per-frame reds
   belong to the owning cards). Only its green-only disposition and pointers are transcribed
   (Section 28); no red four-values are invented.
