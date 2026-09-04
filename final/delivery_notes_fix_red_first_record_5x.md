# Delivery Notes — fix_red_first_record_5x

Date: 2026-09-04. Card: create `final/_red_first_5x.md`, the R5 consolidated red-first record
(transcription-only; zero re-measurement, zero code/scenario changes).

## 1. 改动清单 (Change list)

| File | Change |
|---|---|
| `final/_red_first_5x.md` | **NEW** — the R5 consolidated red-first record. 28 scenario sections + a round-scope note + a "no red-first record found" section. Per-entry shape mirrors `final/_red_first_4a.md` (invocation / four MEASURED values / restore-or-green confirmation) with a source pointer and green-count per entry. Header states: round R5 (jinyong-nav), date 2026-09-04, every value TRANSCRIBED from in-tree records, no new measurements. |
| `final/delivery_notes_fix_red_first_record_5x.md` | **NEW** — this file. |

Nothing else was written. No yaml, delivery note, script, or `design/` file was edited
(read-only sweep); no root `playtest_spec.yaml` was created.

## 2. 汇编方法 (Union-building method — which files were read for the union)

The union was built by sweeping exactly the sources named in the task card and the
source-pointer table in `task_plan.md`:

1. **Yaml headers (red-first blocks):**
   - `playtest/softlock_empty_practice_returns.yaml` (R2 block L40–57 + R5 block L91–107 — both
     four-value sets transcribed),
   - `playtest/clicks_only_gongfa_empty_exit.yaml` (R2 measured block L31–47 + R5 block L101–110),
   - `playtest/gongfa_pick_empty_keyboard_return.yaml` (R5 block L58–68; no separate R2
     four-value block is cited for it in the plan table).
   The remaining R5 scenario yaml headers listed in the plan table were located (all names exist
   under `playtest/` — confirmed by directory listing; the t_plan review independently verified
   their headers against the note tables) and are cited as secondary pointers; per the plan's
   rule, the delivery-note tables are the authoritative transcription source.
2. **Delivery-note red-first sections (authoritative tables):**
   - `final/delivery_notes_feat_c3_backs_confirmations.md` §3(1) table (L75–84) — 8 scenarios;
   - `final/delivery_notes_feat_c1_cultivation_sect_consequences.md` §2 table (L38–45) — 6
     scenarios with greens-before-red + green-count columns;
   - `final/delivery_notes_feat_c1_creation_point_cost.md` "Red-first four values (planned
     record for the pre-fix tree)" (L46–55) — 1 planned-only record;
   - `final/delivery_notes_feat_map_travel_hints.md` §4 (L91–107) — 3 scenarios;
   - `final/delivery_notes_feat_c4_roster_battle_ending.md` §4 (L42–48) — 2 scenarios;
   - `final/delivery_notes_feat_battle_pause_menu_feedback.md` "Red-first four values per
     scenario" table (L66–71, with raw red output pasted at L51–57) — 4 scenarios;
   - `final/delivery_notes_feat_conclusion_sweep.md` §2 (62/62 measured green) + §5 acceptance
     row 1 (the §5.1-area red-not-re-measured finding; the review note that §5.1 is a hedge was
     honored by anchoring on the acceptance table row and §3 "NOT in this net" rows) — 1
     green-only entry.
3. **Structure reference:** `final/_red_first_4a.md` (read in full; per-entry shape copied).
4. **Coverage cross-check:** `final/` directory listing confirmed
   `final/delivery_notes_card_0b_enemy_turn_pacing.md` does NOT exist (recorded as a no-record
   finding); the `playtest/` directory listing confirmed every R5 scenario name cited by the
   plan table exists as a file.

## 3. 并集清单 (Full union list — scenario → source pointer)

28 entries in `final/_red_first_5x.md`:

| # | Scenario | Source pointer |
|---|---|---|
| 1 | softlock_empty_practice_returns | yaml header L40–57 (R2) + L91–107 (R5) |
| 2 | clicks_only_gongfa_empty_exit | yaml header L31–47 (R2) + L101–110 (R5) |
| 3 | gongfa_pick_empty_keyboard_return | yaml header L58–68 (R5) |
| 4 | back_button_attr_pick_zero_delta | c3 note §3(1) table L77 |
| 5 | back_button_gongfa_pick_zero_delta | c3 note §3(1) table L78 |
| 6 | back_button_card_pick_zero_delta | c3 note §3(1) table L79 |
| 7 | back_button_year_end_zero_delta | c3 note §3(1) table L80 |
| 8 | back_button_sect_switch_zero_delta | c3 note §3(1) table L81 |
| 9 | sect_join_needs_confirm | c3 note §3(1) table L82 |
| 10 | year_end_switch_needs_confirm | c3 note §3(1) table L83 |
| 11 | event_phase_no_exit_reaffirmed | c3 note §3(1) table L84 |
| 12 | consequence_card_pick_focus | c1-cultivation note §2 table L40 |
| 13 | consequence_event_option_visible | c1-cultivation note §2 table L41 |
| 14 | consequence_sect_select_focus | c1-cultivation note §2 table L42 |
| 15 | consequence_work_income_inline | c1-cultivation note §2 table L43 |
| 16 | consequence_year_end_switch | c1-cultivation note §2 table L44 |
| 17 | consequence_gongfa_goal_mastery_grant | c1-cultivation note §2 table L45 |
| 18 | trait_point_cost_visible (PLANNED-ONLY) | c1-creation note L46–55 |
| 19 | map_travel_node_type_hint | map note §4 L91–95 |
| 20 | travel_to_ending_needs_confirm | map note §4 L97–101 |
| 21 | consequence_screens_occlusion_map | map note §4 L103–107 |
| 22 | roster_panel_battle_open_close | c4 note §4 L42–44 |
| 23 | roster_panel_ending_open_close | c4 note §4 L46–48 |
| 24 | battle_pause_menu_continue_zero_delta | battle note table L68 |
| 25 | battle_return_to_main_menu_needs_confirm | battle note table L69 |
| 26 | skill_range_highlight_on_select | battle note table L70 |
| 27 | enemy_hit_float_and_log_visible | battle note table L71 |
| 28 | consequence_screens_occlusion (green-only treatment) | conclusion_sweep §2 (L33–39, 62/62) + §5 acceptance row 1 + §3 NOT-in-this-net rows (L97–100) |

Excluded by the round-scope note (pre-R5 yaml-header red blocks, not transcribed as R5
entries): clicks_only_storyline, ending_divergent_playstyles, ending_last_month_choice,
ending_tiers_differentiate, equipment_in_battle_diff, event_option_refused_no_charge,
event_pool_new_event_resolved, fortune_reroll_budget, huashan_readiness_warning,
occlusion_no_button_over_text, practice_target_receipt, roster_equip_free_action,
action_yield_differential.

## 4. 分节数 (Section count)

`final/_red_first_5x.md` contains **28 scenario sections** (sections 1–28, of which section 18
is planned-only and section 28 is a green-only treatment), plus a header, a round-scope note,
and one "No red-first record found" section with three items.

## 5. 零重测声明 (Zero re-measurement statement)

**Zero values were re-measured or invented.** Every four-value block was transcribed verbatim
from its cited delivery-note table or yaml-header block; no scenario was run; no yaml, delivery
note, script, or `design/` file was edited; no root `playtest_spec.yaml` was created. Where the
consolidation adds a "green where measured" line, it either quotes the owning source's own green
statement or cross-references the latest 5_compile playtest summary, explicitly labeled as a
cross-reference and never as a substitute for a source value.

## 6. No-record list

1. `final/delivery_notes_card_0b_enemy_turn_pacing.md` — cited by the task card as a source;
   does not exist in the tree (`final/` has `delivery_notes_card0_enemy_turn_l1.md`, a
   different file; repo-wide search for the card_0b name: zero hits). Recorded as a finding;
   no values reconstructed.
2. `trait_point_cost_visible` — four values are planned-only per its owning note
   ("MUST be re-confirmed by the 5_test / full-gate step"); recorded as unmeasured in
   Section 18, not promoted.
3. Occlusion-net red — not re-measured (wave-4 tree cannot be re-reddened without forbidden
   sibling reverts; conclusion_sweep §5.1/acceptance row 1). Only the green-only disposition and
   pointers transcribed in Section 28.

## 7. Known gaps 与遗留

- Section 28 intentionally carries **no red four-values** — the red is structurally
  unre-measurable post-waves; the per-frame reds live in the owning scenarios' own records
  (consolidated here as sections 1–27).
- The C3 note's table lacks per-scenario post-fix green counts; the consolidation cites the
  5_compile summary as an explicitly-labeled cross-reference (including four scenarios that are
  red there — back_button_year_end 9/10, sect_join 4/6, event_phase_no_exit 7/8 — which are
  5_compile-observed regressions owned elsewhere, not alterations of the transcribed records).
- `trait_point_cost_visible`'s owed full-gate green paste remains the 5_test/verification
  steps' obligation (owning note's own wording).

## 8. 边界声明 (What was NOT touched)

No yaml (including the three re-derived C2 nails and all other scenario headers), no delivery
note, no script, no `design/` file, no `playtest_spec.yaml`, no code — read-only sweep; the only
writes are `final/_red_first_5x.md` and this file.
