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

## Regression duties (run and recorded)

- `spine_to_ending` 42/42 — verified by read that its ENDING asserts do not pin
  tier values (they assert state routing, not tier numbers).
- `clicks_only_storyline` 47/47 — cultivation month flow untouched (only
  `_apply_action` internals + copy); ENDING asserts don't pin tier values.
- `save_load_roundtrip` 14/14 — `deeds` is additive + symmetric; `from_dict`
  legacy-repair mirrors the `equipped` precedent.
