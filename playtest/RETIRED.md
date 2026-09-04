# Retired route-type play-test scenarios (owner ruling 2026-09-04)

Route-type = frame-scripted whole-game paths (max `at:` frame >= 800). They pin a
click PATH, not a property, and go red on every upstream screen change. Each one
below was read for its UNIQUE property (what it proved that no remaining
<800-frame scenario proves) and that property was carried over in exactly one of
three ways:

- **(a)** a NEW unit scenario (<= 200 frames, ONE screen/state, booted directly
  into that state with the scene / debug seeds `_common.yaml` already uses);
  assertion EXPRESSIONS are verbatim wherever they transfer, no threshold weakened.
- **(b)** the per-round real-browser playtest — allowed ONLY for pacing / feel /
  whole-flow continuity / readability (the six `5_vision` questions: Q1 tile grid
  visible, Q2 skill buttons differ, Q3 a skill button changes over time, Q4 turn /
  action state changes visibly, Q5 health bars recognisable, Q6 no truncated or
  clipped text).
- **(c)** already covered by an existing short scenario or GDScript unit test
  (file + matching assertion line).

Exempt, untouched: `facility_use_reusable.yaml`, `map_node_event_shaolin.yaml`,
`map_battle_node_huashan.yaml` (three verbatim gates), `event_travel_effects.yaml`
(owner iron law: byte-identical), `huashan_winnable_normal_route.yaml` (owned by a
running pipeline card). No `scripts/`, `scenes/` or other scenario's assertions
were edited.

## Retired (deleted)

| scenario | maxF | unique property | carry-over (a/b/c + target) | notes |
|---|---|---|---|---|
| player_death_ends_battle | 2999 | an in-flight round loop halts on player death: LOST + 战败 overlay + death classified as the player's, and LOST PERSISTS across later samples | (a) `player_death_mid_round_ends_battle` — six-line block verbatim, sampled at f140/f170/f200 | kill injected mid enemy round (f120) after a real player turn (move + skill_1 + end_turn) instead of on the round-2 player turn; persistence window is 80 frames, not 2300. Probe: at f200 `current_round` reads 2 while LOST (not pinned; the retired scenario never pinned the round either) |
| terminal_victory_8_12_rounds_hp_15_40 | 2999 | the whole tutorial fight lands WON in 8-12 rounds with 15-40 % HP — a DIFFICULTY spec, "allowed to go red on a balance change" | (b) per-round real-browser playtest: the owner plays the tutorial battle to its end and judges pacing/difficulty by feel (whole-flow item; none of the six single-frame questions) | was already red (~78 % HP, "the fight is too easy after the Yang Guo buff") so no green coverage is lost; the window is not carried by any unit scenario |
| battle_end_turn_attack_buttons | 1750 | both battle verbs have clickable, wired, non-overlapping buttons; EndTurnButton click hands the turn over and is gate-disabled during the enemy turn, re-enabled in round 2; AttackButton click with no skill fires the basic attack (acted true, 39 damage) | (a) `end_turn_button_click_hands_over_turn` (f20 wiring block ×11 + f100 ENEMY_TURN block + f200 round-2 block, verbatim) and (a) `attack_button_click_fires_basic_attack` (wiring block + `health == max_health - 39`) | the basic attack now lands on Central_Divine in round 1 (probe 130 -> 91) instead of East_Heretic in round 2; same 39 = 30 x 1.3 |
| each_unit_acts_once_per_round_initiative_order | 1610 | round 2 begins with East Heretic and Yang Guo acts last under init_minus_20; every unit acted once per round (turn_log 11, turns_taken 1 / 2 x5); the same-turn second attack is rejected with 本回合已行动 | (a) `initiative_order_round_two` (f30 + the 12-line round-2 block verbatim) and (a) `attack_once_per_turn_rejected` (round-1 basic attack: land, then 本回合已行动 with the target unchanged) | residual NOT carried: the round-3 leg (Yang Guo first again once init_minus_20 expires) needs ~f600; the rejection leg pins Central_Divine `max_health - 39` instead of South Emperor's 61 % |
| ending_last_month_choice | 1585 | a month-36 action flip (做工 vs 练功) changes the ending evaluation — live choices feed the evaluation through the final month | (c) `tests/test_ending_logic.gd` `_test_divergence` ("mastery-only difference changes score", `int(ev3["score"]) != int(ev1["score"])`) + `tests/test_action_yield_curves.gd:133` (EndingLogic.evaluate over 36 months of real action math, tiers differ per strategy) + `tests/test_cultivation.gd` `_test_month36_to_map` (the month-36 action resolves before MAP) | the in-session two-ending differential (`diverged_from_first == true`) is not reproduced live; `tests/test_ending_gate_pins.py` entry removed |
| ending_divergent_playstyles | 1350 | two playthroughs from the same seed with different playstyles reach DIFFERENT ending evaluations | (c) `tests/test_action_yield_curves.gd` `_assert_tier_separation` ("do_nothing lands tier 1 on every seed" / "all_practice lands tier 2 on every seed", lines 290-293) + `tests/test_ending_logic.gd` `_test_divergence` | the R3b "validate on real saves" leg (restart -> real creation boot) is not reproduced; `tests/test_ending_gate_pins.py` entry removed |
| consequence_screens_occlusion | 1180 | one occlusion-clean frame (UiOcclusionWatch violations == 0 + scan_ok) per new R5 surface | (c) per surface: battle roster open -> `roster_panel_battle_open_close.yaml` f80 (`UiOcclusionWatch.violations: violations == 0`); battle pause menu -> `battle_pause_menu_continue_zero_delta.yaml:64`; creation AttrCostLabel -> `trait_point_cost_visible.yaml:67`; sect consequence -> `consequence_sect_select_focus.yaml` f30; CARD_PICK -> `consequence_card_pick_focus.yaml:49`; ACTION_PICK work -> `consequence_work_income_inline.yaml:66`; GONGFA_PICK -> `consequence_gongfa_goal_mastery_grant.yaml:123`; YEAR_END -> `consequence_year_end_switch.yaml:195`; and (a) `sect_switch_arm_status_occlusion` for the one surface nobody framed (SECT_SWITCH arm status line, f1180 block verbatim) | the new unit reaches month 12 with 11 x debug_step_month at 2-frame spacing then plays month 12 by hand |
| enemy_action_feedback | 1100 | every landed enemy hit appends a log line and spawns a float, every acting enemy shows the marker (three additive counters moved AND cleared their floors) on an occlusion-clean PLAYER_TURN frame | (a) `enemy_action_feedback_counters` — f100 `changed` x3, f200 block verbatim | round-2 player turn is live by f200 (probe: end_turn f20 -> PLAYER_TURN between f175 and f200) |
| enemy_hit_float_and_log_visible | 1100 | an enemy hit on the player is VISIBLE: HUD-relayed log line with attacker/player display names, →, 剩; counters moved; occlusion clean | (a) `enemy_hit_float_and_log_round_one` — f18 baseline, f100 `changed` x3, f200 content block verbatim (incl. the three lines `test_battle_pause_menu_surface_contract` pins) | f200 sits inside the 6-line window (probe: 6 hit lines, all `… → 独臂大虾 −N (剩 M)`) |
| enemy_turn_wall_clock | 1100 | a full enemy round <= 10 s, one enemy turn <= 2 s, index >= 5, round_msec > 0, marker hidden pre-battle / visible mid-round, split sanity, occlusion clean | (a) `enemy_round_wall_clock` — f2 / f100 / f200 blocks verbatim | probe: round_msec 1581, turn_msec 492 at f200; `test_enemy_turn_wall_clock_surface_contract` retargeted to the new name |
| qi_cost_blocks_cast_no_energy | 1100 | casting spends qi; a drained pool puts button 4 in no_energy (not phase_locked), disabled, refuses the hotkey with 内力不足, and a confirm consumes nothing; the basic attack is never disarmed at 0 qi | (a) `qi_cost_spent_and_no_energy_blocks_cast` (round-1 half, all 14 expressions verbatim) and (a) `basic_attack_free_at_zero_qi` (0-qi basic attack: `acted == true`, `energy == 0`, `selected_skill_index == -1`, verbatim) | the never-disarmed control now drains the pool BEFORE acting in round 1 instead of carrying 0 qi into round 2; `test_qi_cost_surface_contract` retargeted |
| ending_tiers_differentiate | 1095 | ending tiers DIVIDE on real saves: do-nothing < tier 3, practice route on a different tier, mastery axis > 0 | (c) `tests/test_action_yield_curves.gd` `_assert_tier_separation`: `do_nothing avg score < tier-2 min_score` (l.275), `do_nothing lands tier 1 on every seed` (l.290), `all_practice lands tier 2 on every seed` (l.292), titles pairwise distinct (l.258-260); mastery axis: `tests/test_ending_logic.gd` `_test_divergence` `mastered D -> mastery 1` (l.83) | `test_ending_tiers_differentiate_nail_contract` removed from the smoke test (documented in place); the scenario's own footer already delegated the three-distinct-titles proof to that GDScript instrument |
| clicks_only_storyline | 1005 | the six-segment mainline is reachable by clicks alone (zero keyboard actions) menu -> ending -> restart | (b) per-round real-browser playtest: the owner walks menu -> creation -> tutorial -> overlay -> transition -> sect -> cultivation -> map -> ending with mouse/touch only (brief item 主线六段触屏可达, decision 2026-08-29) and Q6 on every screen; per-screen click reachability stays pinned by `menu_to_creation_to_tutorial_order`, `creation_mouse_interaction`, `end_turn_button_click_hands_over_turn`, `map_facility_buttons_click`, `roster_panel_*_open_close`, `clicks_only_gongfa_empty_exit` | `test_clicks_only_storyline_is_keyboard_free` trimmed to its facility-companion half (`test_map_facility_buttons_click_is_keyboard_free`) |
| portrait_grid_alignment | 820 | a portrait's ink stands on the tile its unit occupies (abs dx/dy <= 1.0, all six units) at spawn and after a walk | (a) `portrait_ink_on_own_tile` — static f40 block (12 lines verbatim, Central_Divine on row 1 is the unit the removed clamp used to push) + round-1 click walk (7,5) -> (8,2) with the 12 lines re-asserted on arrival | residual NOT carried: the round-2 player row-1 leg ((6,2) -> (6,1)); row 1 stays covered by Central_Divine's static line |

## Kept, needs owner ruling

| scenario | maxF | unique property | why it could not be carried |
|---|---|---|---|
| two_phase_skill_unlock_and_hp_gate | 2700 | round 4 unlocks palm arts 5-7 and the HP gate on button 8 flips at < 50 % HP | the round-4 unlock needs three enemy rounds (~180 frames each, measured: round 2 arrives at f200) — ~f600, beyond a 200-frame unit; no GDScript test covers `hud.gd:932` phase-lock by round; the round-1 half (buttons 5-8 disabled, hp_gated predicate) would fit but is not the file's thesis |
| locked_slot_unlock_reason | 2600 | the lock reason 第 4 轮解锁 disappears exactly when the phase-lock does (round >= 4) | same round-4 barrier; the round-1 half (non-empty reason on 5-8, empty on 1) fits a unit but the disappearance is the thesis; `test_hud_info_surface_contract` still pins this file |
| central_divine_innate_qi_fatal_guard | 1290 | 先天罡气: Central Divine's first lethal blow leaves him at 1 HP | reaching lethal needs three player turns of whittling (130 HP + shield); no unit test exercises `combat_manager.gd:952` (the fatal guard); no debug action damages an enemy |
| cultivation_changes_combat | 1125 | the 发挥度 cascade is real END-TO-END: practice raises fahui (×0.7 -> higher) and the encounter damage with it | needs a sect-joined profile: `debug_seed_save` seeds a no-sect profile (fahui_text empty in the encounter, probed), a direct `sect_select.tscn` boot cannot join (state stays TUTORIAL, probed), and the real boot reaches CULTIVATION only at ~f200 (a 250-frame, multi-screen route). Partial (c): `tests/test_gongfa_cascade.gd` (cascade + CombatManager delegation), `tests/test_battle_setup.gd` (mastered propagation), `tests/test_cultivation.gd` `_test_practice_mastery` |
| trait_combat_effects_and_twelve_slots | 1015 | live trait hooks (身轻如燕 slide costs 2, 狼 x1.08, 杀 heals 6, 铁布衫 guards to 1 HP without LOST) and the 12-slot bar rendering 9 skills in two rows | needs creation-picked traits + 唐门 + 26 months + a dart A art; no seed builds that profile; the two-row bar and the live iron_shirt proc have no unit coverage (`tests/test_trait_effects.gd` covers the formulas only) |
| work_beats_idling | 1430 | 36 work months end with > 1.5x the silver of 36 idle months from the same seed (ratio pin) | two full endings in one run; the 1.5x ratio appears in no GDScript test (`test_action_yield_curves.gd` only pins mastered-heavy work income > fresh); `test_work_beats_idling_ratio_nail_contract` still pins this file |

## Harness verification (real runs, 2026-09-04, `godot_playtest_scenario` / `godot_playtest` against this worktree)

New unit scenarios (12/12 green, 0 runtime errors, one inline run 11:37-11:39 UTC and again by name in the full run below):

| scenario | asserts passed |
|---|---|
| player_death_mid_round_ends_battle | 21/21 |
| end_turn_button_click_hands_over_turn | 18/18 |
| attack_button_click_fires_basic_attack | 16/16 |
| initiative_order_round_two | 14/14 |
| attack_once_per_turn_rejected | 7/7 |
| enemy_action_feedback_counters | 9/9 |
| enemy_hit_float_and_log_round_one | 9/9 |
| enemy_round_wall_clock | 14/14 |
| qi_cost_spent_and_no_energy_blocks_cast | 17/17 |
| basic_attack_free_at_zero_qi | 7/7 |
| portrait_ink_on_own_tile | 26/26 |
| sect_switch_arm_status_occlusion | 13/13 |

Remaining set (full `godot_playtest` run of `playtest/`): 118 scenarios run / 114 passed / 27 runtime errors, elapsed 1113 s (11:41-11:59 UTC). All 12 new unit scenarios PASS in this full run at the counts above. The 4 advisory reds — `cultivation_year_end_stay` 5/8, `sect_switch_same_school_connects` 4/8, `huashan_winnable_normal_route` 19/47 (26 runtime errors, `aim: node not found: TravelButton0 …`; owned by the running card, honest-LOST re-scope) and `back_button_gongfa_pick_zero_delta` 17/17 with 1 runtime error (`aim: node not found: SectButton0`) — are all 27 runtime errors, and every one of the four reproduces at IDENTICAL counts on a detached worktree of the base sha c1da695 (run 12:00-12:01 UTC), so none is caused by this change (those files are byte-identical to master)

Static gate: `pytest tests/ -q` — 80 passed (`~/AItelier/.venv`, 2026-09-04, after the ledger rows).
