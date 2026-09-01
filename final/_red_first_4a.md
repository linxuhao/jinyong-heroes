# §4a — Yaml-gate pre-fix red — MEASURED (2026-09-01)

## Revert combination used (single-revert isolation)
Only ONE line was reverted for this red run (no §4b revert active, no battlefield.gd revert needed):
- `scripts/autoload/game_manager.gd` `start_map_battle()` — line `map_battle_id = battle_id`
  replaced by `# map_battle_id = battle_id  # TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`.
  Field stayed `""` → the battle fell into the pre-fix tutorial fallthrough (tutorial_battle == true,
  hard-coded Yang Guo) — the observed defect state. The battlefield `_ready()` map branch did NOT
  need a second revert: the scenario went red with this one line.

## Invocation (sidecar, measured)
`godot_playtest_scenario(scenario="map_battle_node_huashan")` against the sidecar with the staged
revert applied (`staged_files_applied: ["scripts/autoload/game_manager.gd"]`).
Sidecar output: `[FAIL] map_battle_node_huashan  11/41`, `ok: 11, total: 41`.

## The four MEASURED values
1. **Failing frame:** `f580`
2. **First failing assertion:** `GameManager.map_battle_id: map_battle_id == "huashan_duel"`
   (NOT the predicted-alternative `tutorial_battle` — the id assert fires first in file order;
   `tutorial_battle == false` observed=true is the SECOND failing assertion at the same frame)
3. **Exact error string (character-for-character):**
   ```
   FAIL f580 GameManager.map_battle_id: map_battle_id == "huashan_duel"
        observed=""
   ```
4. **Green asserts before red:** 11 (sidecar `ok: 11, total: 41`; all 11 passing asserts precede the
   first failing one — the kept pre-f580 leg A/B asserts and the three kept f580 asserts, which
   precede the added failing line in the file).

Downstream of the first red, the run also observed the whole pre-fix defect chain (all recorded from
the same run, `observed=` verbatim): `tutorial_battle == true`, `Player.max_health == 1000`,
`current_round == 0`, `turn_order == []`, `phase == "IDLE"`, `active_unit_name == ""`,
`EndTurnButton.disabled == true`, and every WIN/LOST MAP-return assertion red
(`node not found: MapScreen` at f925/f985/f1165). This includes Leg C's
`map_battle_id == "huashan_duel"` pre-fix red — the end-to-end guarantee for the real-swap property.

## Restore confirmation
`game_manager.gd` restored byte-exact (line 215 re-read: `map_battle_id = battle_id`, no marker).
Post-restore probe: `map_battle_node_huashan` 41/41, `equipment_in_battle_diff` 47/47,
`spine_to_ending` 42/42 — all green (run of 2026-09-01, see §4c/§6 of delivery notes).
