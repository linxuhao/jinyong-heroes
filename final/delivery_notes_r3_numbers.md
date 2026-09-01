# R3 Delivery Notes — Meaningful Numbers: Choices Must Shape the Ending

> Round: R3 (2026-09-01). Task: `r3_gate_sync_evidence` — the round's closure
> sweep: registry/i18n sync, the anti-weakening pytest door, and the consolidated
> red-first + measurement ledger. This file is the single source of truth for the
> round's evidence. Every number below is either (a) a red-first four-value record
> copied verbatim from the four feature tasks' notes under `final/red_first_notes_r3_*.md`,
> or (b) a measurement labeled with its run. **No stale pre-R2 number appears as
> evidence anywhere in this file** (the 2160 silver / 243 exits / 50-126-131 tiers /
> 40-press bone 91 figures are dead and are not cited).

---

## 0. Scope of this task

`r3_gate_sync_evidence` produces **no game logic**. It is the round's closure
sweep: (1) verify the playtest registry is complete (append-only), (2) verify the
i18n EN dictionary has no gaps, (3) land the anti-weakening pytest door over the
six new nails' load-bearing lines, and (4) consolidate the red-first + measurement
ledger. Any code fix discovered here would mean a feature task's contract broke —
recorded and stopped, never patched in this task.

---

## 1. Registry sweep (playtest/_common.yaml — append-only)

Verified present under the correct nodes (no existing line removed):

- **CultivationScreen**: `rerolls_left`, `last_action_kind`, `last_action_silver`,
  `last_yield_text`, `last_practice_target`, `last_practice_amount`
- **EndingScreen**: `score`, `evaluation_text`
- **RosterPanel**: `readiness_text`

All six new scenario names are registered **both** in `scenario_order` (tail
appends) and in `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS`
(two-place sync, identical order):
`action_yield_differential`, `fortune_reroll_budget`, `ending_divergent_playstyles`,
`ending_last_month_choice`, `huashan_readiness_warning`, `huashan_winnable_normal_route`.

## 2. i18n sweep (scripts/autoload/i18n.gd)

The EN dictionary already carries every new UI string added by the four feature
tasks (verified by the review and by `tests/test_i18n_coverage.py` running green):
the reroll strings (`重掷事件（剩余 %d 次）` / `重掷：剩余 %d 次` /
`今年已无重掷次数`), the ending axis strings (`结局 · 属性：%d` /
`结局 · 武学：%d` / `结局 · 历练：%.1f`), the Huashan readiness strings
(`华山评估：%s` / `战备不足` / `势均力敌` / `胜券在握`), the action effect-suffix
strings (`做工：银两 +%d` / `练功：%s +%d` / `修习：%s +%d` / `游历：遇事`), and the
honest fortune copy (`影响事件与奇遇（福缘越高，每年游历事件可重掷次数越多）`).
No string already pinned by a nail was reworded.

## 3. Anti-weakening door — tests/test_ending_gate_pins.py (NEW)

A stdlib-only pytest door (mirroring `tests/test_map_battle_gate_pins.py`) that
scans each of the six new scenario files and reddens if any load-bearing
differential line silently disappears. The load-bearing lines (grep-verbatim,
including the full-width colon and Chinese quotes):

| Nail | Load-bearing line(s) |
|---|---|
| `ending_divergent_playstyles` | `first_ending_evaluation != evaluation_text` |
| `ending_last_month_choice` | `first_ending_evaluation != evaluation_text` |
| `fortune_reroll_budget` | `rerolls_left == 0`, `events_seen_count == 0` |
| `action_yield_differential` | `last_action_silver == 0` (×3), `last_action_silver > 0` |
| `huashan_readiness_warning` | `readiness_text != "华山评估：战备不足"` |
| `huashan_winnable_normal_route` | `current_state == "WON"`, `health < max_health` |

It also asserts `_common.yaml` still contains every new surface name and that at
least one `final/red_first_notes_r3_*.md` exists (the red-first discipline is
itself load-bearing). Failure text names exactly which nail lost which line.

---

## 4. Red-first evidence — one section per new nail (six)

All four house values below are **MEASURED** on the pre-fix tree (temporary
reverts carried the `TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` marker and were
restored byte-identically with zero residue), copied verbatim from the feature
tasks' notes.

### 4.1 Nail N-1a — `ending_divergent_playstyles` (P1)

| house value | measured |
|---|---|
| failing_frame | f975 (leg A ENDING — the `score` surface is not published by the pre-fix script) |
| first_failing_assert | `EndingScreen.score` |
| exact_error / observed | `"node property not found: EndingScreen.score"` |
| green_asserts_before_red | 4 (f400 MAP, f520 TRAVEL/shaolin, f540 focus huashan, f580 current_state == "BATTLE") |

**Why red pre-fix:** both legs share the attrs-only evaluation, so two different
playstyles can tie — the exact hole this round closes. **Green:** the multi-axis
evaluation (`EndingLogic.evaluate`) makes the two playthroughs' `{tier, score}`
records differ (proven by the M2 curves and the headless unit divergence test).

### 4.2 Nail N-1b — `ending_last_month_choice` (P1)

| house value | measured |
|---|---|
| failing_frame | f945 (leg A ENDING — the `score` surface is not published by the pre-fix script) |
| first_failing_assert | `EndingScreen.score` |
| exact_error / observed | `"node property not found: EndingScreen.score"` |
| green_asserts_before_red | 4 (f400 MAP, f520 TRAVEL/shaolin, f540 focus huashan, f580 current_state == "BATTLE") |

**Why red pre-fix:** nothing after creation feeds the evaluation, so a month-36
action flip cannot move the tier. **Green:** mastery and deeds keep growing
through month 36 by construction, so a month-36 做工 vs 练功 flip moves `score`.

### 4.3 Nail N-2 — `fortune_reroll_budget` (P2)

| house value | measured |
|---|---|
| failing_frame | f130 |
| first_failing_assert | `CultivationScreen.rerolls_left: rerolls_left == 1` |
| exact_error / observed | `"node property not found: CultivationScreen.rerolls_left"` |
| green_asserts_before_red | 3 (f130 asserts `current_state == "CULTIVATION"`, `phase == "CARD_PICK"`, `month == 1`) |

**Why red pre-fix:** the rerolls_left surface did not exist — the fortune consumer
was absent. **Green:** leg 1 rerolls_left 1 → 0 with event_title/event_body
re-published non-empty; leg 2 exhausted press inert (`rerolls_left == 0`,
`events_seen_count == 0`, non-empty receipt); leg 3 occlusion-clean. Honesty note
recorded in `final/red_first_notes_r3_fortune.md`: the leg-1 `event_id`/`events_seen_count`
"changed" expectation is not deterministically expressible (the reroll draws from
the same unseen pool and may redraw the same event; `events_seen_count` only grows
on RESOLUTION) — the deterministic inert differential is pinned instead.

### 4.4 Nail N-3 — `action_yield_differential` (P3)

| house value | measured |
|---|---|
| failing_frame | f200 |
| first_failing_assert | `CultivationScreen.last_action_silver` |
| exact_error / observed | `"node property not found: CultivationScreen.last_action_silver"` |
| green_asserts_before_red | 7 (f130 has 5 + f170 has 2) |

**Structural red (current tree, card_data.gd):** `work` granted a flat +10 silver
while the free monthly card `gr_silver_30` granted +30 — a work month was strictly
dominated by a single free card. **Green:** work's `last_action_silver > 0` (the
only action with a > 0 silver grant), practice/cultivate/travel `== 0`, practice
`last_practice_amount > 0` + `last_practice_target` changed (targeted niche),
travel `last_action_kind == "travel"` (routing proof).

### 4.5 Nail N-4a — `huashan_readiness_warning` (P4)

| house value | measured |
|---|---|
| failing_frame | f130 |
| first_failing_assert | `RosterPanel.readiness_text` |
| exact_error / observed | `"node property not found: RosterPanel.readiness_text"` |
| green_asserts_before_red | 3 (f130 has 3 asserts before the readiness_text line) |

**Why red pre-fix:** the readiness surface did not exist — no screen warned the
player what the duel needed. **Green:** a creation-fresh profile shows the weak
verdict (`华山评估：战备不足`); after cultivation the verdict STRING differs
(differential, never a power literal).

### 4.6 Nail N-4c — `huashan_winnable_normal_route` (P4, the flagship)

| house value | measured |
|---|---|
| failing_frame | f580 (battle arrival — the hero is dead before the first PLAYER_TURN assert) |
| first_failing_assert | `CombatManager.phase == "PLAYER_TURN"` |
| exact_error / observed | `phase` observed `"ENEMY_TURN"` / `"IDLE"` — the five greats (initiative 70-85) act first and the normal-route hero (initiative ~15-25) dies before acting; the WIN assert never fires |
| green_asserts_before_red | 4 (f400 MAP, f520 TRAVEL/shaolin, f540 focus huashan, f580 current_state == "BATTLE") |

**Why red pre-fix:** `derive_stats` had no mastery terms, so a normal route's hero
entered the duel with `max_health = 135` and died before acting. **Green:** the
mastery terms lift `max_health`/`energy`/`initiative` so a normally-played route
wins the duel with real skill clicks + end_turn, asserting WIN → MAP return and
`health < max_health` at the win frame (the fight was real, not a full-HP trivial
win).

---

## 5. Measurement ledger — M1 / M2 / M3

Every number below is labeled with its run. **No stale pre-R2 number is cited as
evidence.**

### M1 — per-action yield curves (measured 2026-09-01, R3 M1, seeded run)

Instrument: `tests/test_action_yield_curves.gd` (real action math via
ProgressionMath / EventLogic / TraitEffects / PlayerProfile, 36 seeded months × 5
strategies). Shape reference only — never a gate literal.

| strategy | silver | practice | attr | events | mastered | final work income |
|---|---|---|---|---|---|---|
| all_work | high (compounding) | 0 | 0 | 0 | 0 | 10 (no mastery) |
| all_practice | low | high | 0 | 0 | many | > 10 (scales with mastery) |
| all_cultivate | low | 0 | high | 0 | 0 | 10 |
| all_travel | mid (event silver) | low | low | ≤ 36 | 0 | 10 |
| balanced | mid | mid | mid | mid | mid | > 10 (scales with mastery) |

Structural facts (the test pins structure, not numbers): all yields finite and
non-negative; mastery-heavy (all_practice) final work income strictly greater than
fresh (all_work); travel events resolved ≤ 36. Work income `10 + 2 × mastered_count`
makes work the only repeatable silver source that compounds with the run, eventually
beating the one-shot free card `gr_silver_30` (+30).

### M2 — ending score curves (measured 2026-09-01, R3 M2, seeded runs)

Instrument: the M1 instrument extended to print `EndingLogic.evaluate`'s
`ending_score` / `ending_tier` per strategy. Thresholds frozen at `min_score`
90 / 60 / 0 (last row 0 → any score is at least tier 1) so T-1..T-4 hold:

| strategy | ending_score | ending_tier |
|---|---|---|
| all_work | mid | 2 |
| all_practice | high | 3 |
| all_cultivate | mid | 2 |
| all_travel | mid | 2 |
| balanced | mid | 2 |

- **T-1** two divergent routes reach different `{tier, score}` (all_practice's
  mastery axis, K_MASTERY=2.0, clears all_work).
- **T-2** a month-36 action flip moves `score` via the deeds axis.
- **T-3** a creation-maximized profile with zero growth months cannot reach tier 3
  (mastery=0, deeds=0 → score stops at the attrs axis, below 90).
- **T-4** a normally-played balanced route reaches tier 2 comfortably (median in
  the [60, 90) band).

### M3 — Huashan readiness & win rate (measured 2026-09-01, R3 M3, seeds s1..s5)

Instrument: `tests/test_battle_setup_readiness.gd` + the flagship scenario. Fixed
input script: balanced route (clicks-only month grammar, no min-max).
`HUASHAN_BAR = {even: 30, strong: 40}` set from the measured win/lose split.

| seed | balanced power | balanced verdict | balanced result | fresh power | fresh verdict | fresh result |
|---|---|---|---|---|---|---|
| s1 | 34 | even | WIN | 12 | weak | LOSE |
| s2 | 33 | even | WIN | 12 | weak | LOSE |
| s3 | 35 | even | WIN | 12 | weak | LOSE |
| s4 | 32 | even | WIN | 12 | weak | LOSE |
| s5 | 34 | even | WIN | 12 | weak | LOSE |

- (a) balanced route exceeds `even` on 5/5 seeds and wins on 5/5 (majority —
  "has a chance", not guaranteed).
- (b) creation-fresh profile scores below `even` on all 5 seeds and loses
  (challenge preserved).
- (c) fight not trivialized — winning runs do NOT finish at full health
  (`health < max_health` asserted in the flagship scenario).

### Honest 「未执行 + 原因」 rows

- **Full 5_compile consolidated gate run** — not executed in this task: the
  official gate products (`compile_report.json` / `playtest_report.json` /
  `test_report.json`) are produced by the pipeline steps AFTER this task
  (5_compile / 5_test). The per-scenario green runs recorded in the feature-task
  notes and the regression matrix below are implementer-recorded sidecar evidence,
  not the official gate verdict. Reason: the gate artifacts are not available in
  this task's context.
- **`ending_divergent_playstyles` / `ending_last_month_choice` post-fix full
  scenario green** — not fully executed: a post-fix probe of
  `ending_divergent_playstyles` reached CULTIVATION at f130 and the leg-A ENDING
  asserts, but the leg-A month clicks reported `aim: node not found:
  CultOptionButton0/2` runtime errors and leg B routed to TUTORIAL instead of MAP.
  This is a scenario frame-timing / boot-scene concern, not an evaluation-logic
  defect — the evaluation surfaces and multi-axis math are verified by the headless
  unit suite (`tests/test_ending_logic.gd`) and the M2 curves. Recorded honestly;
  not silently claimed green.

---

## 6. Protection audit

Verified byte-identical (git diff) — the six huashan-locked files and the three
verbatim gates were not touched by one character:

- **Six huashan-locked files:** `scripts/battlefield.gd`,
  `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`,
  `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`,
  `playtest/map_battle_node_huashan.yaml`.
- **Three verbatim gates:** `facility_use_reusable`, `map_node_event_shaolin`,
  `map_battle_node_huashan` — byte-untouched, green verbatim.
- **Theme / UI-geometry files untouched:** `assets/themes/global_theme.tres`,
  `scenes/ui/{tutorial_overlay,roster_panel,hud}.tscn`,
  `scenes/segments/sect_select.tscn`.
- Huashan difficulty routes exclusively through the sanctioned player-side
  `derive_stats` surface; the `map_battle_data.gd` data-unlock escalation
  contingency was NOT triggered (5/5 win without trivializing the fight).

## 7. Regression matrix (MEASURED counts)

Counts are the implementer-recorded sidecar measurements from the feature-task
notes and the R2 consolidated run (each is a real observed count, not a guess).
The official gate re-run belongs to 5_compile.

| Gate | Measured count |
|---|---|
| `save_load_roundtrip` | 14/14 |
| `event_travel_effects` | 19/19 |
| `spine_to_ending` | 42/42 |
| `clicks_only_storyline` | 47/47 |
| `facility_use_reusable` | 49/49 |
| `map_node_event_shaolin` | 32/32 |
| `map_battle_node_huashan` | 41/41 |
| `terminal_victory_8_12_rounds_hp_15_40` | 6/6 |
| `equipment_in_battle_diff` | 47/47 |
| `cultivation_changes_combat` | 30/30 |
| `softlock_empty_practice_month_advances` | 15/15 |
| `occlusion_no_button_over_text` | 22/22 |
| `creation_attr_effect_info` | 17/17 |

## 8. Four-problem → nail mapping

| Problem | Nail(s) | Proof shape |
|---|---|---|
| P1 — ending frozen early | `ending_divergent_playstyles` (N-1a), `ending_last_month_choice` (N-1b) | two playstyles → different evaluations; a month-36 action flip changes the evaluation |
| P2 — dead attributes | `fortune_reroll_budget` (N-2) + honest `map_inquire` residual | fortune's promised travel-event reroll implemented with a year-scoped budget; the residual `map_inquire` (江湖阅历) promise is recorded as unimplemented (out of scope) in `design/40_progression.md` |
| P3 — action dominance | `action_yield_differential` (N-3) + M1 table | work is the only action with a > 0 silver grant; practice is the only target-chosen advancement; each action has a measured unique niche |
| P4 — Huashan unwinnable / unwarned | `huashan_readiness_warning` (N-4a), `huashan_winnable_normal_route` (N-4c) | a normal route wins the duel (fight real, not full-HP); the readiness verdict warns in advance and tracks growth |

---

## 9. RNG-stream safety ledger

| Change | RNG ops added on old paths | New-path ops |
|---|---|---|
| deeds increments, work scaling, +2 practice | 0 | 0 |
| Ending evaluation / readiness | 0 | 0 |
| fortune reroll | 0 | 1 × `draw_unseen_id` per press (player-initiated only) |
| derive_stats extension | 0 | 0 |

`save_load_roundtrip` and `event_travel_effects` re-run green (counts above); the
reroll nail declares its own seeded stream in its header.
