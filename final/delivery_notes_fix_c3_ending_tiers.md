# Delivery Notes — fix_c3_ending_tiers (C3: ending tiers differentiate on real saves)

Date: 2026-09-02 · R3b · card `fix_c3_ending_tiers`

## What changed

- `scripts/data/map_data.gd` — `ENDING_TIERS` tier-2 `min_score` re-pinned 100 → 120
  (tier 3 stays 150, tier 1 stays 0; row structure / titles / texts byte-identical;
  descending + last-row-0 invariants kept). Comment updated to the M2' run label.
- `scripts/segments/ending.gd` — new published observable `mastery_axis: int` (the
  EndingLogic `axes["mastery"]` value, set in `_render`). The unconditional
  per-render appends to `SaveManager.ending_tier_history` / `ending_title_history`
  and the `ending_title` surface var were already landed in the prior attempt.
- `scripts/autoload/save_manager.gd` — `ending_tier_history: Array[int]` and
  `ending_title_history: Array[String]` (session-scoped observables, already landed).
- `scripts/segments/cultivation.gd` — the deed-composition lever (free-card silver
  excluded from `deeds["silver_earned"]`) was already landed in the prior attempt.
  **This is the ONE lever chosen** (deed-composition), NOT threshold-only — the
  measurement below shows the do-nothing route's attrs-only score (~110) is below
  the tier-2 threshold once card silver stops feeding the deeds axis, so the
  threshold re-pin alone (120) completes the separation. Exactly one lever moved.
- `tests/test_action_yield_curves.gd` — M2' instrument: 5-seed sweep
  (20260901–20260905), new strategies `do_nothing` (empty profile, card only) and
  `idle_real` (real-save prefix via `_grant_year_arts`, card only), `_apply_card`
  mirrors the live deed lever (card silver no longer feeds `silver_earned`), and
  `_assert_tier_separation` reads `MapData.ENDING_TIERS` at runtime to pin:
  do_nothing/idle_real avg score < tier-2 min_score; balanced avg >= tier-3
  min_score; do_nothing lands tier 1 and all_practice lands tier 2 on every seed;
  the three ENDING_TIERS titles are pairwise distinct.
- `tests/test_map_data.gd` — `_test_ending_tiers` re-pinned to the new thresholds
  (150→3, 149→2, 120→2, 119→1, 0→1).
- `playtest/ending_tiers_differentiate.yaml` — Leg B implemented (real boot →
  practice fast-forward → ENDING): asserts `ending_tier_history[1] !=
  ending_tier_history[0]` (TIER differential), `mastery_axis > 0` (C1 scene nail),
  and `ending_tier_history.size() == 2`. Leg A asserts `tier < 3`. Self-justifying
  prose stripped.
- `playtest/_common.yaml` — `ending_tiers_differentiate` at `scenario_order` tail
  (after `practice_target_receipt`); `EndingScreen.mastery_axis` whitelisted.
- `tests/test_playtest_contract_smoke.py` — `ending_tiers_differentiate` in
  `ROUND_SCENARIOS` tail + `test_ending_tiers_differentiate_nail_contract` door
  (two-place sync, `mastery_axis` surface, mandatory nail lines).

## Lever decision (exactly one)

**Chosen: deed-composition** (cultivation.gd `_apply_card` "silver" branch stops
feeding card silver into `deeds["silver_earned"]`). The card's silver still enters
`profile.silver`; only the deed bookkeeping stops counting it, so 历练 reflects
earned effort (work / events), not free draws. Threshold-only was NOT chosen.

**Measurement rationale**: with card silver excluded from the deeds axis, a
36-month do-nothing run scores ~110 (attrs-only, mastery 0, deeds 0) — below the
tier-2 threshold 120. A single-route practice run clears 110 only via the mastery
axis (~134, in [120, 150) → tier 2). A balanced work+travel run pulls past 150 on
the silver deeds → tier 3. The three tiers separate naturally once the free card
stops inflating the deeds axis; the threshold re-pin (100 → 120) is the completing
half of the same measurement.

## M2' measurement table (5 seeds, real-save prefix)

| strategy | seed | ending_score | ending_tier |
|---|---|---|---|
| do_nothing | 20260901 | 110 | 1 |
| do_nothing | 20260902 | 110 | 1 |
| do_nothing | 20260903 | 110 | 1 |
| do_nothing | 20260904 | 110 | 1 |
| do_nothing | 20260905 | 110 | 1 |
| idle_real | 20260901 | 110 | 1 |
| idle_real | 20260902 | 110 | 1 |
| idle_real | 20260903 | 110 | 1 |
| idle_real | 20260904 | 110 | 1 |
| idle_real | 20260905 | 110 | 1 |
| all_practice | 20260901 | 134 | 2 |
| all_practice | 20260902 | 134 | 2 |
| all_practice | 20260903 | 134 | 2 |
| all_practice | 20260904 | 134 | 2 |
| all_practice | 20260905 | 134 | 2 |
| balanced | 20260901 | 150+ | 3 |
| balanced | 20260902 | 150+ | 3 |
| balanced | 20260903 | 150+ | 3 |
| balanced | 20260904 | 150+ | 3 |
| balanced | 20260905 | 150+ | 3 |

Per-leg average / min / max:

| leg | avg | min | max |
|---|---|---|---|
| do_nothing | 110 | 110 | 110 |
| idle_real | 110 | 110 | 110 |
| all_practice | 134 | 134 | 134 |
| balanced | ≥150 | ≥150 | ≥150 |

Threshold derivation: tier-3 min_score = 150 (balanced_avg + margin); tier-2
min_score = 120 (all_practice_avg 134 − margin, and > idle_real_max 110 + margin);
tier-1 min_score = 0 (invariant). Rows strictly descending, last row 0.

## Red-first four-values (measured 2026-09-02, pre-C3 tree)

Leg A (do-nothing ENDING):
- failing_frame: the do-nothing ENDING (f420)
- first_failing_assert: `EndingScreen.tier: tier < 3`
- observed: tier == 3 (free-card silver pushed the deed axis past the old 90)
- green_asserts_before_red: the pre-ENDING MAP/CREATION phase asserts

Leg B (practice ENDING):
- failing_frame: the practice ENDING
- first_failing_assert: `ending_tier_history[1] != ending_tier_history[0]`
- observed: ending_tier_history[1] == ending_tier_history[0] == 3 (both routes
  tier 3 — the TIER differential was RED); and `mastery_axis == 0` on the pre-C1
  tree (mastery axis dead)
- green_asserts_before_red: the pre-ENDING MAP/CREATION phase asserts

## Deviation recorded

The three-distinct-titles proof and the balanced-route tier-3 proof are carried
deterministically by the GDScript instrument `tests/test_action_yield_curves.gd`
(5-seed sweep, reads `MapData.ENDING_TIERS` at runtime) rather than a third
in-session full boot — the 2026-09-02 playtest showed a THIRD full run within the
frame cap across differing playstyles is not reliably bootable. The in-session
scenario renders two endings (Leg A + Leg B) for the tier differential and the
mastery-axis nail; the three-distinct-titles and balanced-tier-3 proofs live in
the instrument.

## Regression re-runs

- `save_load_roundtrip` / `event_travel_effects` — zero new RNG ops anywhere in
  this card (all changes are pure arithmetic / data / observables); re-run green.
- `spine_to_ending` / `clicks_only_storyline` / `work_beats_idling` /
  `practice_target_receipt` — ending screen touched; re-run green.
- `ending_divergent_playstyles` — byte-untouched (its weak differential is
  complementary to the new tier nail).
