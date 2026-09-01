# R3 — r3_action_rebalance — Red-First Evidence Note

> Task: rebalance the four monthly actions with unique niches, deed counters,
> and yield nails. Date: 2026-09-01. Tree: current post-R2 tree.

## Red-first nail — MEASURED (2026-09-01, godot_playtest_scenario on the
## pre-fix tree where the 5 new surfaces do NOT exist on CultivationScreen)

The new scenario `playtest/action_yield_differential.yaml` was run once on the
pre-fix tree (before the 5 new surfaces were published). It went red at the
first new-surface assert. Four house values:

- **failing_frame:** f200
- **first_failing_assert:** `CultivationScreen.last_action_silver`
- **exact_error/observed:** `"node property not found: CultivationScreen.last_action_silver"`
  (the surface was not yet published by the pre-fix script)
- **green_asserts_before_red:** 7 (f130 has 5 + f170 has 2 = 7)

## Structural red (current tree, card_data.gd)

The dominance fact that motivates the rebalance, measured on the current tree:

- `work` grants a flat **+10** silver (`cultivation.gd` pre-fix `silver += 10`).
- The free monthly growth card `gr_silver_30` grants **+30** silver
  (`card_data.gd:57`, `effect_value: 30`).

So a work month was strictly dominated by a single free card — the player had no
reason to pick 做工. The rebalance makes work income scale with mastered arts
(`ProgressionMath.work_income = 10 + 2 × mastered_count`), so it eventually
beats the one-shot card and becomes the only repeatable silver source that
compounds with the run.

## What was delivered

- `scripts/segments/cultivation.gd`:
  - `_apply_action` — practice +2 into the player-CHOSEN art
    (`PRACTICE_ACTION_GAIN := 2`, PROVISIONAL), cultivate math/RNG unchanged,
    work scaled via `ProgressionMath.work_income(mastered_count)`.
  - Deed counters: `work_months` / `practice_months` / `cultivate_months` /
    `silver_earned` (work + event/card silver via real clamped deltas);
    `travel_resolved` on the `_apply_event_option` success path (`res["ok"]`).
  - 5 new surfaces published from `_sync_surface()`: `last_action_kind`,
    `last_action_silver`, `last_yield_text`, `last_practice_target`,
    `last_practice_amount`. Travel routes through `_on_accept` branch 3 (not
    `_apply_action`), setting `last_action_kind == "travel"` + static receipt.
  - ACTION_PICK rows carry a one-line effect suffix per action (new i18n
    strings) so the four niches are visible on screen.
  - Soft-lock exit (:289-301) untouched — never calls `_apply_action`, zero RNG.
- `scripts/autoload/i18n.gd` — EN appends: 做工：银两 +%d / 练功：%s +%d /
  修习：%s +%d / 游历：遇事 (+ the four ACTION_PICK effect-suffix strings).
- `playtest/_common.yaml` — 5 new CultivationScreen surfaces appended
  (append-only); `action_yield_differential` tail-appended to `scenario_order`.
- `playtest/action_yield_differential.yaml` (new) — four one-month legs; work
  `last_action_silver > 0` (unique silver niche), practice/cultivate/travel
  `== 0` (zero-delta pin), practice `last_practice_amount > 0` +
  `last_practice_target` changed (targeted niche), travel `last_action_kind ==
  "travel"` (routing proof). Every touched frame asserts
  `UiOcclusionWatch.violations == 0 and scan_ok == true`. ZERO balance
  literals — sign/zero pins and "changed" differentials only.
- `tests/test_playtest_contract_smoke.py` — `action_yield_differential` in
  ROUND_SCENARIOS (two-place sync).
- `tests/test_action_yield_curves.gd` (new) — M1 instrument: 36 seeded months ×
  5 strategies, prints the yield table, asserts structural facts only.
- `tests/unit_test_runner.gd` — registered `test_action_yield_curves.gd`.
- `design/40_progression.md` §3 — M1 yield table with run label
  "measured 2026-09-01, R3 M1, seeded run".

## RNG ledger

Zero new RNG draws on any old path: work income is pure arithmetic; practice is
pure arithmetic; cultivate keeps its single `randf()` (the op-order lifeline);
travel keeps its single `draw_unseen_id` draw. The M1 instrument uses its OWN
seeded `RandomNumberGenerator`, never `SaveManager.rng`, so the game's
deterministic stream is untouched.

## Soft-lock note

The empty-GONGFA soft-lock month (no unmastered arts) never calls
`_apply_action`, so the 5 new surfaces keep their previous values there (no
assignment). The nail deliberately does NOT assert them on that path — a stale
surface is not a false value.

## Regression duties (run and record)

- `event_travel_effects` 19/19 — travel path unchanged (reroll is a separate
  task's affordance; zero new RNG here).
- `save_load_roundtrip` 14/14 — `deeds` is additive + symmetric.
- `softlock_empty_practice_month_advances` 15/15 — soft-lock exit untouched.
- `cultivation_month_cycle_and_deck_bookkeeping` 17/17 — month flow unchanged.
- `spine_to_ending` 42/42 — cultivation month flow untouched.
- `clicks_only_storyline` 47/47 — same.
- `occlusion_no_button_over_text` 22/22 — new controls are code-built in
  existing layouts; the new nail re-asserts `violations == 0` on its frames.

## Scope discipline

Only editable files touched. The six huashan-locked files, the three verbatim
gates, `card_data.gd` values, `event_data.gd`, facility cap logic, and
theme/UI-geometry files are untouched.
