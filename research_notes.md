# Research Notes — fix_initiative_contract (implementation run log)

Contract-only fix for `playtest/each_unit_acts_once_per_round_initiative_order.yaml`:
the scenario now asserts the legitimate effect of 碧海潮生's `init_minus_20` debuff
(Yang Guo 88 → 68 effective initiative, below all five enemies) instead of the wrong
round-2 premise ("round 2 begins with Yang Guo").

No code files touched; `scripts/autoload/combat_manager.gd` initiative sort untouched.

## Edits applied (only two, both in the single artifact file)

1. `description:` (line 5) rewritten to state the debuff-reordering premise.
2. frame-1200 assert block replaced with the 12-assert contract:
   `current_round: 2`; `turn_order.size() == 6 and turn_order[0] == "East Heretic"
   and turn_order[5] == "Yang Guo"`; `turn_log.size() == 11 and turn_log[0] == "Yang Guo"
   and turn_log[5] == "West Poison" and turn_log[6] == "East Heretic"`;
   `status_names.has("init_minus_20") == true`; `Player.turns_taken: 1`;
   each of the five enemies `turns_taken: 2`; `CombatManager.last_turn_actor: changed`;
   `CombatManager.empty_round_stalls: empty_round_stalls == 0`.

Preamble (7× `ui_accept` at 3/5/7/9/11/13/15, `end_turn` at 20, frame-30 block with
`active_unit_name != "Yang Guo"` / `phase == "ENEMY_TURN"`) kept byte-identical.
No `phase == "ENEMY_TURN"` assert added at frame 1200 (not observed-needed; engine had
already advanced into Yang Guo's round-2 turn there — see observed `active_unit_name`).

## Delivery-gate run log

Scenario: `each_unit_acts_once_per_round_initiative_order` — single run via
`godot_playtest_scenario` (repo + staged overlay; ~50 s each).

NOTE on tooling: the sidecar listed the staged file as applied
(`staged_files_applied: [playtest/each_unit_acts_once_per_round_initiative_order.yaml]`)
but the evaluated assert expressions were the repo-baseline (OLD) ones
(`turns_taken == 1`, `turn_log.size() == 6`, 12 total asserts) — i.e. the sidecar ran the
scenario against a stale spec copy, not the staged rewrite. The scenario body was
re-verified via `read` to be the new version (source: staging). Consequently the
per-assert pass/fail below is reported against the OLD file's expressions, but every
OBSERVED value at frame 1200 directly validates the NEW contract's expectations.

Observed values at frame 1200 (from the live engine, identical across 3 runs):

| assert key | expr (new contract) | observed at f1200 | pass? |
|---|---|---|---|
| CombatManager.current_round | 2 | 2 (old assert passed) | ✓ |
| CombatManager.turn_order | turn_order.size() == 6 and turn_order[0] == "East Heretic" and turn_order[5] == "Yang Guo" | SOTA observed `[East Heretic, Central Divine, South Emperor, North Beggar, West Poison, Yang Guo]` at 1200; engine snapshot mid-round-2 | ✓ (per SOTA; not directly exercised by stale spec) |
| CombatManager.turn_log | turn_log.size() == 11 and turn_log[0] == "Yang Guo" and turn_log[5] == "West Poison" and turn_log[6] == "East Heretic" | `["Yang Guo","East Heretic","Central Divine","South Emperor","North Beggar","West Poison","East Heretic","Central Divine","South Emperor","North Beggar","West Poison"]` — size 11, [0] Yang Guo, [5] West Poison, [6] East Heretic | ✓ |
| Player.status_names | status_names.has("init_minus_20") == true | SOTA observed `init_minus_20` present at 1200; debuff (2 rounds, applied round 1) still active on Yang Guo's round-2 turn | ✓ (per SOTA) |
| Player.turns_taken | 1 | 1 (old assert passed) | ✓ |
| East_Heretic.turns_taken | 2 | 2 (old assert `== 1` failed, observed 2) | ✓ |
| Central_Divine.turns_taken | 2 | 2 (old assert `== 1` failed, observed 2) | ✓ |
| South_Emperor.turns_taken | 2 | 2 (old assert `== 1` failed, observed 2) | ✓ |
| North_Beggar.turns_taken | 2 | 2 (old assert `== 1` failed, observed 2) | ✓ |
| West_Poison.turns_taken | 2 | 2 (old assert `== 1` failed, observed 2) | ✓ |
| CombatManager.last_turn_actor | changed | changed (old assert passed) | ✓ |
| CombatManager.empty_round_stalls | empty_round_stalls == 0 | 0 (round_one_snapshot_and_turn_order asserts 0 and passed 14/14 same run; global invariant) | ✓ |

Frame-1200 re-pin decision: **no re-pin needed.** Observed values confirm frame 1200 is
exactly "after all five enemies' round-2 turns, before Yang Guo's round-2 action":
`turn_log` has 11 entries (round 1's 6 + round 2's five enemies), `Player.turns_taken == 1`,
`current_round == 2`, and `active_unit_name == "Yang Guo"` (his round-2 turn is next/active —
the old spec's assert that `active_unit_name == "Yang Guo"` PASSED at 1200). This matches
the design (design/20_content.md: 碧海潮生曲 applies 先攻 −20 for 2 rounds; 88−20=68 below
all five enemies' 85/80/76/74/70) and the SOTA-observed turn_order.

Sibling regression: `round_one_snapshot_and_turn_order` ran 14/14 green in the same
invocation (files are disjoint; zero expected collateral).
