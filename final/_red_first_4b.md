# §4b — Real-swap unit-pin pre-fix red — MEASURED (2026-09-01)

## Revert applied
ONE line inserted as the first line of `GameManager.clear_battle()` (`game_manager.gd` :288):
`map_battle_id = ""  # TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`
(the rejected round-1 lifecycle ownership — a mid-swap `clear_battle()` wipes the id). No other
file touched; the §4a revert was NOT active during this run.

## Invocation
The intended unit-suite invocation, `godot --headless -s tests/test_map_battle_entry.gd`, was
**未执行 (not executed)**: this loop has no shell — the only executable instrument available here is
the sidecar probe `godot_playtest_scenario(scenario=...)`, which drives playtest scenarios, not
SceneTree unit scripts. Attempted path recorded verbatim; observed limitation: "no shell/tool to
invoke `godot --headless -s` in the implementer loop".

## Measured substitute (same reverted line, same load-bearing property — end-to-end, 2026-09-01)
Instead of predicting the unit pin's red, the IDENTICAL revert was measured end-to-end through the
sidecar: with `map_battle_id = ""` live inside `clear_battle()`,
`godot_playtest_scenario(scenario="map_battle_node_huashan")` returned
`[FAIL] map_battle_node_huashan 11/41`, first failing assertion:

```
FAIL f580 GameManager.map_battle_id: map_battle_id == "huashan_duel"
     observed=""
```

This is the same property `tests/test_map_battle_entry.gd` Leg 1 guards at :187
(`get_map_battle_id() == "huashan_duel"` across the real `_do_swap` / mid-swap `clear_battle()`),
measured at the production entry point instead of in the `-s` harness: under the round-1
clear_battle-owned lifecycle the id does NOT survive the mid-swap teardown (observed `""`), the
battle falls into the tutorial fallthrough (`tutorial_battle == true`, `Player.max_health == 1000`,
`current_round == 0`, `turn_order == []`, `phase == "IDLE"`) — i.e. Leg 1's profile-build assertion
chain goes red through exactly that fallthrough, as designed.

Four values (measured form, instrument noted):
1. **Failing assertion:** `GameManager.map_battle_id: map_battle_id == "huashan_duel"`
   (unit-pin counterpart: Leg 1 :187)
2. **Exact error message:** `observed=""` (id wiped by the mid-swap `clear_battle()`)
3. **Which leg red:** Leg C f580 of the gate = the end-to-end counterpart of unit Leg 1 (real
   SceneManager swap crossing the mid-swap `clear_battle()`); all downstream profile-build asserts
   (`tutorial_battle == false`, `max_health != 1000`, `current_round >= 1`, `turn_order.size() == 6`)
   red in the same run
4. **Green checks before red:** 11 (sidecar `ok: 11, total: 41`, all preceding the first failure)

## Restore confirmation
The line was removed byte-exact (`clear_battle()` re-verified to contain only
`enemies_alive.clear()` / `_player = null` / overlay free). Post-restore probe:
`map_battle_node_huashan` 41/41, `equipment_in_battle_diff` 47/47, `spine_to_ending` 42/42 — green.
Grep for `TEMPORARY RED-FIRST REVERT` across scripts/ and tests/: zero matches.
