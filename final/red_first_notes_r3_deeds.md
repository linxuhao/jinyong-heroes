# R3 — r3_deeds_schema — Red-First Evidence Note

> Task: persist `PlayerProfile.deeds` choice ledger with legacy-safe save repair.
> Date: 2026-09-01. Tree: current post-R2 tree.

## Honest no-nail statement

This task is **schema-only** (adds the `deeds` field + `to_dict`/`from_dict`
repair). It has **no red-first differential nail** — the choice-differential
value lands in the downstream consumer tasks (r3_action_rebalance,
r3_fortune_reroll, r3_ending_logic). Per the task card, I state this honestly
instead of inventing a red.

## Regression run

- `save_load_roundtrip` playtest scenario: **14/14 PASS** (measured 2026-09-01,
  with the staged `player_profile.gd` / `test_deeds_persistence.gd` /
  `unit_test_runner.gd` overlaid on the repo).
- The `deeds` field is additive + symmetric, so the round-trip stays green.

## What was delivered

- `scripts/data/player_profile.gd`:
  - `var deeds: Dictionary` with exactly the six String keys
    `work_months / cultivate_months / practice_months / travel_resolved /
    silver_earned / rerolls_used_this_year`, int values, clamp >= 0.
  - `to_dict()` exports `"deeds": deeds.duplicate()`.
  - `from_dict()` repairs: non-Dictionary src_deeds (null/String/Array/legacy
    missing key) keeps all six at 0; each known key int-or-float -> `maxi(int(v),0)`,
    else 0; unknown extra keys dropped.
  - `get_deed(key)` read-only accessor (defensive, clamps >= 0).
  - Zero RNG ops added (seeded stream op-order lifeline untouched).
- `tests/test_deeds_persistence.gd` (new): 6 groups — default zeros, exact
  round-trip, legacy-no-deeds repair, corrupted-value coercion, negative clamp,
  JSON round-trip. Plain `static func run() -> bool` contract (no SceneTree, no
  `quit()`).
- `tests/unit_test_runner.gd`: registered `res://tests/test_deeds_persistence.gd`.

## Scope discipline

Only `scripts/data/player_profile.gd`, `tests/test_deeds_persistence.gd`, and
`tests/unit_test_runner.gd` were touched. No producer/consumer code (those land
in downstream tasks). No other file modified.
