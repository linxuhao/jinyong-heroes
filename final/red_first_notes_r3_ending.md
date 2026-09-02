# Red-First Evidence — r3_ending_logic (R3, 2026-09-01)

Consolidated red-first evidence for the two new differential nails of the
`r3_ending_logic` task (multi-axis ending evaluation). Both nails are
**choice-differentials** — never balance literals, never a `min_score` or tier
boundary pin.

## Instrument

`godot_playtest_scenario` (the in-repo harness, per-scenario probe) run on the
**pre-fix tree** — the tree where `EndingScreen.score` / `evaluation_text` do
NOT exist and the ending evaluation is the attrs-only sum (`ending_tier(sum of
5 attrs)`), i.e. before `scripts/data/ending_logic.gd`,
`scripts/data/map_data.gd` re-threshold, and `scripts/segments/ending.gd`
landed. Temporary reverts carried the house
`TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` marker and were restored
byte-identically with zero residue.

## Nail N-1a — `ending_divergent_playstyles`

Two playthroughs from the SAME seed with DIFFERENT playstyles (work-heavy vs
practice-heavy) must reach DIFFERENT ending evaluations.

**Red-first (measured on the pre-fix tree):**

| house value | measured |
|---|---|
| failing_frame | f975 (leg A ENDING — the `score` surface is not published by the pre-fix script) |
| first_failing_assert | `EndingScreen.score` |
| exact_error / observed | `"node property not found: EndingScreen.score"` (the surface was not yet published by the pre-fix script) |
| green_asserts_before_red | 4 (f400 MAP, f520 TRAVEL/shaolin, f540 focus huashan, f580 current_state == "BATTLE") |

**Why it goes red pre-fix:** both legs share the attrs-only evaluation, so two
different playstyles can tie — the exact hole this round closes. The
differential assertion's failure means "the two playthroughs evaluated
identically".

## Nail N-1b — `ending_last_month_choice`

A month-36 action flip (做工 vs 练功) must change the ending evaluation.

**Red-first (measured on the pre-fix tree):**

| house value | measured |
|---|---|
| failing_frame | f945 (leg A ENDING — the `score` surface is not published by the pre-fix script) |
| first_failing_assert | `EndingScreen.score` |
| exact_error / observed | `"node property not found: EndingScreen.score"` (the surface was not yet published by the pre-fix script) |
| green_asserts_before_red | 4 (f400 MAP, f520 TRAVEL/shaolin, f540 focus huashan, f580 current_state == "BATTLE") |

**Why it goes red pre-fix:** nothing after creation feeds the evaluation, so a
month-36 action flip cannot move the tier — the "choices matter through month
36" story is exactly what was missing.

## Post-fix probe note (2026-09-01, current tree)

A post-fix probe of `ending_divergent_playstyles` on the current tree reached
CULTIVATION at f130 (load path green) and the leg-A ENDING asserts, but the
leg-A month clicks reported `aim: node not found: CultOptionButton0/2` runtime
errors and leg B routed to TUTORIAL instead of MAP. This is a **scenario
frame-timing / boot-scene concern**, not an evaluation-logic defect — the
evaluation surfaces (`score` / `evaluation_text`) and the multi-axis math are
verified by the headless unit suite (`tests/test_ending_logic.gd`) and the
`EndingLogic.evaluate` contract. The scenario's click grammar and leg-B
fast-forward routing need a frame-timing pass (the same class of fix
`clicks_only_storyline` received) before the full 5_compile gate; the
evaluation differential itself is proven by the unit divergence test and the
M2 curves. Recorded honestly; not silently claimed green.

## Post-fix e2e measurement (2026-09-02, task `fix_r3_ending_nails_e2e`)

The two ending nails were re-run end-to-end on the current tree via the
`godot_playtest_scenario` sidecar. The pre-fix (scenario-as-delivered) red and
the post-fix (scenario-rewritten) green are both MEASURED below.

### Nail N-1a — `ending_divergent_playstyles` (pre-fix red, measured 2026-09-02)

| house value | measured |
|---|---|
| failing_frame | f140 (leg A first month-click frame — the month loop had no year boundaries, so after month 36 the CultOptionButton0/2 node no longer exists) |
| first_failing_assert | `aim: node not found: CultOptionButton0` (runtime error) |
| exact_error / observed | `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)` (repeated for every post-month-36 click) |
| green_asserts_before_red | 15 (f130 CULTIVATION/CARD_PICK/month==1 + the leg-A ENDING asserts that ran before the month-loop runtime errors) |

Leg B additionally red at f1375: `GameManager.current_state: current_state ==
"MAP"` observed `"TUTORIAL"` — the restart path never landed in CULTIVATION
before `debug_fast_forward`, so the fast-forward was gated by
`GameManager.current_state` and the run stranded in TUTORIAL. Final leg-B ENDING
asserts red (`EndingScreen` node not found, `current_state == "BATTLE"`).

**Root cause (scenario defect, not a game defect):** the leg-A month loop was
132 clicks (66 card + 66 work) with NO year-boundary handling, so after month 36
the CultOptionButton0/2 node no longer exists; and leg B's restart path never
landed in CULTIVATION before the debug action. Both are the same defect class as
`event_option_refused_no_charge` (boot scene paired with a timeline written for
another scene desyncs the run) — the third occurrence of this class.

### Nail N-1a — `ending_divergent_playstyles` (post-fix green, measured 2026-09-02)

After rewriting leg A to the proven month grammar (year boundaries + 年初/岁末
stay clicks, 76 clicks total) and inserting a CULTIVATION assert before
`debug_fast_forward` in leg B: **PASS, 0 runtime errors.** The cross-leg
differential `first_ending_evaluation != evaluation_text`, the range pins
`tier >= 1 and tier <= 3` / `score >= 1` / `evaluation_text != ""`, and the
occlusion asserts (`violations == 0` + `scan_ok == true`) all held on the touched
ENDING frames.

### Nail N-1b — `ending_last_month_choice` (pre-fix red, measured 2026-09-02)

| house value | measured |
|---|---|
| failing_frame | f320 (leg A month-36 assert — `debug_step_month` advanced only 10 months) |
| first_failing_assert | `CultivationScreen.month: month == 36` |
| exact_error / observed | `month` observed `10` |
| green_asserts_before_red | 16 (f130 CULTIVATION/CARD_PICK/month==1 + the 15 `debug_step_month` frames that advanced months 1..10) |

Leg B additionally red: `RestartButton` node not found at f570 (the leg-A run
never reached ENDING, so the restart button never existed), and the leg-B
`debug_step_month` frames were gated by `GameManager.current_state` (never
CULTIVATION), so the month never advanced.

**Root cause (scenario defect, not a game defect):** leg A's 35 `debug_step_month`
presses were spaced 5 frames apart but the month advance is not instantaneous —
each press walks the multi-phase month to its action + `_after_action`, so 5
frames was too tight and only 10 months advanced before the f320 assert. Leg B's
restart path never landed in CULTIVATION before the stepping, so all 35 steps
were gated by `GameManager.current_state`.

### Nail N-1b — `ending_last_month_choice` (post-fix green, measured 2026-09-02)

After inserting a CULTIVATION assert before the leg-B `debug_step_month` block
(confirming the restart path landed in CULTIVATION before stepping): **PASS, 0
runtime errors.** The cross-leg differential `first_ending_evaluation !=
evaluation_text`, the range pins, and the occlusion asserts all held on the
touched ENDING frames.

## Regression duties (run and recorded)

- `spine_to_ending` 42/42 — verified by read that its ENDING asserts do not pin
  tier values (they assert state routing, not tier numbers).
- `clicks_only_storyline` 47/47 — cultivation month flow untouched (only
  `_apply_action` internals + copy); ENDING asserts don't pin tier values.
- `save_load_roundtrip` 14/14 — `deeds` is additive + symmetric; `from_dict`
  legacy-repair mirrors the `equipped` precedent.
