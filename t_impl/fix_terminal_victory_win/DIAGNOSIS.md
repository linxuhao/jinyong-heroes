# fix_terminal_victory_win — diagnosis & verification notes

## t1 verdict: branch (b) — frame-budget exhaustion, battle not finished by 2999

**Failing pins at frame 2999** (playtest_report.json, scenario
`terminal_victory_8_12_rounds_hp_15_40`):
- `GameManager.current_state == "WON"` → actual `false`
- `CombatManager.current_round >= 8 and <= 12` → **passes**
- `Player.health >= 75 and <= 200` → actual `false`
- `Player.turns_taken` → changed (baseline 0, current **10**)

**Deciding evidence:**
1. **Branch (c) ruled out.** `spine_to_ending` 32/32 and
   `tutorial_win_routes_to_transition` 8/8 reach WON through the normal
   damage/death pipeline (`apply_damage -> _handle_death -> unregister_enemy
   -> end_battle(true)`, combat_manager.gd ~1448). Win detection is not broken.
2. **Turn engine works (sibling conclusion).** `fix_enemy_turn_execution`'s
   revised diagnosis proves enemy turns DO execute: reaching round 2 in
   `each_unit_acts_once_per_round_initiative_order` requires every round-1
   unit to have acted, and `enemy_acts_only_after_player_ends_turn` is 9/9.
   The terminal failure is NOT a stalled turn loop.
3. **The full scripted sequence ran.** `turns_taken == 10` means all 10
   scripted player turns executed; `current_round` in [8,12] at 2999. The
   timeline's last scripted input is round 10's `end_turn` at frame 2630.
   Nothing is scripted after frame 2630, so if any enemy survives round 10,
   the battle rolls into round 11 and the player's event-driven turn waits
   forever for an `end_turn` that never comes — still `BATTLE` at 2999.
4. **Frame 2998 differs from mid-battle frames** (677 KB vs ~929 KB at frames
   30/600/1200): a mostly-cleared battlefield (straggler remains), not a
   defeat banner — consistent with battle-in-progress, not LOST.

**Conclusion:** the battle has not finished within the harness's frame budget
(round-window pin passes because the stall sits in round 11, still inside
[8,12]). Branch (b): re-time/extend the scripted inputs so the final kill
lands before 2999. The HP pin fails on the same root cause — the fight never
reached its designed end state (player HP 75-200 at WON), so sampling HP mid-
stall is meaningless.

## t2 fix (branch b, applied)

`playtest_spec.yaml`, scenario `terminal_victory_8_12_rounds_hp_15_40` only:

- **Round 11** (player first): `skill_7` (Wandering Valley, jump 3 + adjacent
  26 AoE) at 2870, `attack_confirm` 2885, `end_turn` 2900 — closes on a parked
  ranged straggler (East Heretic parks at range 3). skill_7 is cd3 and
  available from round 4 (unlocked).
- **Round 12** (player first): `skill_1` (Heavy Edge, cd1, always ready, no HP
  gate) at 2960, `attack_confirm` 2975, `end_turn` 2990 — final 59 from
  adjacency; last kill lands at 2975 < 2999, WON in round 12 ∈ [8,12].
- The 2999 assert row is **byte-identical** (WON / round 8-12 / HP 75-200 /
  turns_taken changed). No action names outside the spec `actions:` list.

Timing safety: the player's turn is event-driven and waits for input, so the
2870/2960 presses are safe as long as the respective round has begun; round-10
enemy turns finish ≤ ~2860 by the same 230-frame cadence as rounds 5-9 (fewer
enemies alive later → earlier). If the fight was already won by round 10, the
added presses are harmless no-ops on the WON overlay (which waits for
ui_accept before any scene swap — the Player node stays alive for the 2999
asserts).

## t3 static verification

1. Four 2999 asserts byte-identical — unchanged rows, grep:
   `current_state == "WON"` / `current_round >= 8 and current_round <= 12` /
   `health >= 75 and health <= 200` / `turns_taken: "changed"` (lines 464-467).
2. Diff outside `terminal_victory_8_12_rounds_hp_15_40` timeline: zero rows
   changed; the six protected tutorial scenarios untouched (edit anchored on
   the round-10 block, lines 456-459 only).
3. Branch (c) not taken → no combat_manager.gd / ai/*.gd diff, no numeric
   literals touched anywhere.
4. Final kill + assert within frame 2999 (kill at 2975; assert 2999).
5. HP feasibility: the HP pin requires the player to have absorbed 300-425
   damage; the design targets exactly that at WON in rounds 8-12. This fix
   only guarantees the fight REACHES its designed end state (WON by round 12
   so the sampled HP is meaningful); it changes no damage, no enemy HP, no
   player stats. If the HP pin still fails after this fix, the next check is
   `playtest_report.json`'s 2999 `Player.health` side (>200 = enemies under-
   engaging, <75 = player over-exposed) — but per the sibling's conclusion the
   turn engine and AI engagement are healthy, so the designed 15-40% intake is
   expected once the fight completes.

## Expected gate outcome (after ./run_tests.sh re-run, post sibling fix)

`terminal_victory_8_12_rounds_hp_15_40` 6/6; six protected tutorial scenarios
byte-identical; 0 runtime errors; 0 compile errors; `empty_round_stalls == 0`
preserved (no engine change).
