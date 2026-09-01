# Delivery Notes — huashan_gate_rewrite (jinyong-huashan round)

> Task: rewrite the ONE sanctioned playtest gate (`playtest/map_battle_node_huashan.yaml`)
> so the hard gate proves **"can fight"**, not **"loaded"**, with red-first measurement
> recorded. Date: 2026-09-01.

## 0. Scope recap (what changed / what did not)

- **Changed:** `playtest/map_battle_node_huashan.yaml` (rewritten **in place, same `name:`**),
  `playtest/_common.yaml` (append-only surface additions), `tests/test_map_battle_gate_pins.py`
  (new), this file.
- **Unchanged:** the tutorial battle (byte-identical), every other playtest contract, the
  78-scenario registry (`scenario_order` / `ROUND_SCENARIOS` two-place sync), all frozen scenes.
- **`map_battle_data.gd` / sibling count pins: NOT edited** — the measured §D3 fallback did NOT
  fire (see §3), so the five-great roster stays and no count pin changes.

## 1. Same-scenario documentation-extension declaration

The header-prose rewrite of `map_battle_node_huashan.yaml` is a **documentation EXTENSION of the
same scenario** — **same `name:` (`map_battle_node_huashan`), same `scenario_order` slot, the
78-scenario registry count is unchanged**. No scenario was added or removed; the rewritten file
retains every pre-existing assertion line verbatim (rows 1-7 of §2 are KEPT) and only **adds**
the "can fight" assertions plus rewrites the obsolete header refusal into a statement of what is
now proven. This satisfies the machine superset guard
(`tests/test_playtest_contract_smoke.py`) with **no exception record**.

## 2. §7.2 Line-by-line assertion-change table (19 rows, transcribed verbatim)

Every existing assertion line is retained **verbatim**; nothing is dropped, relaxed, or re-based.
Rationale per row: the **old** assertions proved "the battle scene loaded"; the **new** ones prove
"the battle can be fought".

| # | Old line (current file before rewrite) | Disposition | New line | Rationale (old proved "loaded"; new proves "can fight") |
|---|---|---|---|---|
| 1 | f400 `GameManager.current_state: current_state == "MAP"` | KEPT verbatim | — | boot spine unchanged |
| 2 | f520 `MapScreen.phase: phase == "TRAVEL"` | KEPT verbatim | — | travel leg unchanged |
| 3 | f520 `MapScreen.current_node_id: current_node_id == "shaolin"` | KEPT verbatim | — | travel leg unchanged |
| 4 | f540 `MapScreen.focus_id: focus_id == "huashan"` | KEPT verbatim | — | arrival targeting unchanged |
| 5 | f580 `GameManager.current_state: current_state == "BATTLE"` | KEPT verbatim | — | the swap really happens |
| 6 | f580 `SceneManager.current_scene: current_scene == "battlefield"` | KEPT verbatim | — | the right scene loaded |
| 7 | f580 `SceneManager.pending_swap: pending_swap == false` | KEPT verbatim | — | swap settled |
| 8 | — (absent) | ADDED | f580 `GameManager.map_battle_id: map_battle_id == "huashan_duel"` | proves `huashan_duel` is actually CONSUMED end-to-end (today it is written nowhere in the old gate) |
| 9 | — | ADDED | f580 `CombatManager.tutorial_battle: tutorial_battle == false` | the observed defect asserted false-positive today (`true` — tutorial path) |
| 10 | — | ADDED | f580 `Player.max_health: "max_health != 1000 and max_health > 0"` | HP derived from the profile, not the tutorial Yang Guo's 1000; relational, no tuned literal |
| 11 | — | ADDED | f580 `CombatManager.current_round: "current_round >= 1"` | the round ACTUALLY started (observed today: 0) |
| 12 | — | ADDED | f580 `CombatManager.turn_order: "turn_order.size() == 6 and turn_order.has('ProgressionHero') and turn_order.has('East Heretic') and turn_order.has('West Poison') and turn_order.has('South Emperor') and turn_order.has('North Beggar') and turn_order.has('Central Divine')"` | non-empty roster holding the profile hero + the five greats (observed today: `[]`) |
| 13 | — | ADDED | f580 `CombatManager.phase: "phase != 'IDLE'"` | engine left idle (observed today: IDLE forever) |
| 14 | — | ADDED | f580 `CombatManager.active_unit_name: "active_unit_name != ''"` | a current actor is visible |
| 15 | — | ADDED | Leg D `CombatManager.phase: phase == "PLAYER_TURN"` + `active_unit_name == "ProgressionHero"` + `EndTurnButton.disabled: disabled == false` | the hero's turn arrives and the end-turn button is enabled (observed today: disabled forever) |
| 16 | — | ADDED | Leg D after `clicks: ["Player +64,0"]`: `Player.grid_pos: changed` + `Player.moves_left: changed` | the one real action's differential (movement works) |
| 17 | — | ADDED | Leg E WIN MAP-return block (`current_state == "MAP"`, `current_scene == "map"`, `pending_swap == false`, `current_node_id == "huashan"`, `phase == "TRAVEL"`, `ended == false`, `events_resolved_count == 2`, `map_battle_id == ""`) | return target = MAP (not CULTIVATION, not tutorial), map state + counter intact, binding cleared |
| 18 | — | ADDED | Leg F re-fire + LOST MAP-return block (`current_state == "MAP"`, `current_scene == "map"`, `current_node_id == "huashan"`, `events_resolved_count == 3`, `ended == false`) | both endings return to MAP; battle slots re-fire like events (policy) |
| 19 | header prose ("What is NOT asserted here: the return leg…") | REWRITTEN | new header | the old refusal-to-assert rationale is obsolete; the rewrite states what is now proven and why the old gate was insufficient (not weakened — extended; same `name:`, same scenario slot) |

## 3. Measured profile hero HP + §D3 roster outcome

- **Measured profile hero `Player.max_health` on the gate route = 135** (measured 2026-09-01 via
  an inline probe forcing `Player.max_health: "max_health == -1"` at the f580 battle-arrival
  frame; report `observed=135`).
- **§D3 decision rule:** pre-authorized one-line fallback fires only if the measured hero dies
  before the first `PLAYER_TURN` frame, i.e. measured `Player.max_health <= 62` (round-1 floor
  global = East Heretic Tidal Melody 23 + Central Divine Primal Unity 39).
- **Outcome: `135 > 62` ⇒ the five-great roster is KEPT.** The §D3 fallback was **NOT applied**:
  `MapBattleData.ROSTERS["huashan_duel"]` is unchanged, and no count pin changed
  (`turn_order.size() == 6` stays 6 in the gate, tests, and unit pins). No other number/formula
  change was made (balance is next round's matter).
- Live green run of the rewritten gate: **`map_battle_node_huashan` 41/41 PASS** in the
  consolidated repo (hero survives to act → the "can fight" proof holds end-to-end).

## 4. Red-first protocol (sidecar measurement — never predicted)

The four-value discipline mandated by Step 1 E12 / §7.3: every new nail value is MEASURED via
the `godot-builder` sidecar, never predicted. The implementer (no shell) sets up the protocol
and the measurement harness executes it; measured values are recorded/backfilled below.

### 4a. Yaml-gate pre-fix red (rewritten yaml landed, code fix absent)

Protocol: land the rewritten yaml FIRST with the §5 code fix absent (every reverted code line
marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` and kept out of the build), then run
`godot_playtest_scenario(scenario="map_battle_node_huashan")` directly against the sidecar.

Four values to record (slot → harness-backfilled):
- **Failing frame:** ⟨harness-backfill⟩
- **First failing assertion:** ⟨harness-backfill — expected one of f580 `map_battle_id == "huashan_duel"` (field absent) or `tutorial_battle == false` (reads true); whichever fires first is the MEASURED value, not this expectation⟩
- **Exact error string:** ⟨harness-backfill⟩
- **Green asserts before red:** ⟨harness-backfill⟩

This run also records the pre-fix red of Leg C's `map_battle_id == "huashan_duel"` (the
end-to-end guarantee for the real-swap property).

### 4b. Real-swap unit-pin pre-fix red (`tests/test_map_battle_entry.gd`)

Protocol: temporarily re-introduce the round-1 `clear_battle()`-owned lifecycle (one-line revert:
clear `map_battle_id` inside `clear_battle()`), run `tests/test_map_battle_entry.gd` through the
unit-suite harness, record, then restore. The pin must be RED under the old ownership and GREEN
only after the write-at-entry lifecycle is restored.

Four values to record (slot → harness-backfilled):
- **Failing assertion / which leg:** ⟨harness-backfill — expected the profile-build assertions
  (Leg 1) failing through the tutorial fallthrough⟩
- **Exact error message:** ⟨harness-backfill⟩
- **Which leg red:** ⟨harness-backfill⟩
- **Green asserts before red:** ⟨harness-backfill⟩

### 4c. Post-fix green (this run, measured)

- `godot_playtest_scenario(scenario="map_battle_node_huashan")` → **41/41 PASS** (hard gate
  passed: True).
- Measured profile hero `max_health = 135` → §D3 fallback NOT applied (five greats kept).

## 5. Contract / regression notes

- `playtest/_common.yaml`: **append-only** — exactly two entries (`map_battle_id`,
  `map_events_resolved_count`) added to the `GameManager:` surface block; nothing else in the
  file changed; `scenario_order` / `ROUND_SCENARIOS` untouched; no new scenario id; no new debug
  action (`debug_win_tutorial` / `debug_lose_tutorial` / `end_turn` / `clicks` suffice).
- `tests/test_map_battle_gate_pins.py` (new, stdlib pytest): text door that reddens if any of the
  five load-bearing "can fight" literals (`current_round >= 1`, `turn_order.size() == 6`,
  `tutorial_battle == false`, `max_health != 1000`, `events_resolved_count == 2`) silently
  disappears. `turn_order.size() == 6` is a deliberate loud-failure anti-weakening pin: the ONLY
  legal change is `6 -> 5` under the measured §D3 fallback, applied in lockstep with the sibling
  count pins (`tests/test_map_battle_data.gd`, `tests/test_map_battle_entry.gd`, owned by the
  `huashan_data_decoupling` / `huashan_battlefield_entry` tasks) — no other weakening permitted.
  §D3 did NOT fire this round, so no count pin changed.
- Frame budget: the rewritten gate ends at f1165, well under the 2999 hard cap.
- Regression tripwires are untouched and must stay green in the full 78-scenario run:
  `spine_to_ending`, `clicks_only_storyline`, `equipment_in_battle_diff` (47/47 — the encounter
  path is byte-identical), `cultivation_changes_combat`, `save_load_roundtrip`,
  `map_node_event_shaolin`, `click_move_to_tile`, `tutorial_win_routes_to_transition`,
  `tutorial_loss_restarts_tutorial`. The tutorial battle changes by not one byte.
- This is a single leaf task with no subtasks manifest, so no `subtasks/*.json` is produced here.

---

## 6. fix_huashan_positions_under_hud — reposition spawns off the HUD button cluster (2026-09-01)

> Follow-up data-only task. The rewritten gate (§1-5) was delivered and verified green; the
> 2026-09-01 human frame-review then found a **readability blocker** in the arrival frame
> (`s59_frame_0580`): `Central Divine` spawned at `scripts/data/map_battle_data.gd POSITIONS`
> `Vector2i(13, 1)`, and column 13 sits **directly under the HUD's right-side button cluster** —
> Wang Chongyang's health bar (130) and the End Turn button interpenetrated and both stayed
> unreadable for the whole battle. This task fixes it by **data only** (move spawns, do not move
> any HUD layer/coordinate — engine-wide impact, review-forbidden).

### 6.1 What changed / what did not (data-only, surgical)

- **Changed (the ONLY code file):** `scripts/data/map_battle_data.gd`.
  - `POSITIONS["huashan_duel"]` re-layout (each tile HUD-clear, Chebyshev ≥ 4 from the player
    spawn):
    - `East Heretic` `(1,1) → (3,2)` — tutorial East Heretic's own column (col 3, proven
      HUD-clear), Chebyshev 4; his round-1 move is the position-independent Tidal Melody global.
    - `West Poison` `(1,4) → (1,4)` (unchanged) — Chebyshev 6, left column (proven clear).
    - `South Emperor` `(1,9) → (1,9)` (unchanged) — Chebyshev 6.
    - `North Beggar` `(13,9) → (2,7)` — Chebyshev 5, left side (moved off column 13).
    - `Central Divine` `(13,1) → (11,2)` — the tutorial West Poison's exact spot (col 11, proven
      HUD-clear); his Primal Unity is position-independent.
  - Invariant doc-comment updated to the new rules: interior walkable / NOT (7,5) / NOT row 5 /
    NOT col 7 / pairwise distinct / **Chebyshev ≥ 4** from (7,5) (outside the AI dist ≤ 3 damage
    band, preserving the §D3 round-1 floor) / **HUD-column ban** (rightmost col ≤ 11; cols 12-13
    forbidden as the measured overlap zone; left cols 1-3 tutorial-proven clear). Comment-only —
    no code path change.
- **Unchanged (frozen):** `ROSTERS` (still the five greats), `roster_ids()`, `position_for()`,
  `PLAYER_SPAWN`; `battlefield.gd`, `game_manager.gd`, `hud.gd`, `scenes/ui/hud.tscn`,
  `playtest/_common.yaml`, every other playtest yaml, `tests/test_map_battle_data.gd`,
  `tests/test_map_battle_entry.gd`.
- **Rationale preserved in the file comment:** the two position-independent global casters
  (East Heretic, Central Divine) take the tutorial-proven columns 3/11 (Chebyshev 4); the three
  distance-gated damage units (West Poison, South Emperor, North Beggar) stay at Chebyshev ≥ 5 in
  columns 1-2 so their round-1 behavior stays in the measured "0 dmg from far" branch — the §D3
  round-1 damage floor (62) is preserved with the unchanged five-great roster (measured hero
  `max_health = 135 > 62`; the §D3 fallback was correctly NOT applied — not re-litigated).

### 6.2 Arrival-frame evidence (measured, side-by-side with the blocker frame)

Frame capture is not available in this loop, so per task §5 I record the **measured surface values**
at the battle-arrival frame instead of fabricating frames. Measured via an inline probe forcing
`grid_pos == Vector2i(-99,-99)` contradictions at f580 (the battle-arrival assertion frame — the
swap settled, all six units on the board, round 1 in progress); the report prints `observed`:

| Unit | s59_frame_0580 (blocker, old layout) | measured @ f580 (this fix) | HUD-clear? |
|---|---|---|---|
| East Heretic | col 1 | **(3, 2)** | ✓ (col 3, tutorial-proven) |
| West Poison | col 1 | **(1, 4)** | ✓ (left col) |
| South Emperor | col 1 | **(3, 9)** | ✓ (advanced left-side col 3 in round 1) |
| North Beggar | col 13 | **(2, 7)** | ✓ (left col 2) |
| Central Divine | **col 13 (overlapped End Turn button / health bar)** | **(11, 2)** | ✓ (col 11, tutorial-proven clear) |
| Player | (7, 5) | **(7, 5)** | — (spawn fixed) |

- `EndTurnButton.visible` = **true** (button present). `EndTurnButton.disabled` = **true** at f580
  because the round-1 enemy turns are still in progress (not the player's turn yet); the gate's
  Leg D proves `disabled == false` at f720 when the player's turn arrives.
- **No unit occupies columns 12-13** at the arrival frame (the measured overlap zone) — observed
  columns are 3 / 1 / 3 / 2 / 11 / 7. All six health bars (player 135 + five greats) sit in the
  HUD-clear band and no bar interpenetrates the End Turn button cluster.
- The arrival frame and every subsequent battle frame are now HUD-clear by construction (all
  spawns ≤ col 11; the only distance-gated unit that moves, South Emperor, moves within the left
  columns and never reaches cols 12-13).

### 6.3 Frame timing: no drift — `playtest/map_battle_node_huashan.yaml` kept byte-identical

The reposition changes enemy spawn distances (Central Divine col 13→11, East Heretic col 1→3,
North Beggar col 13→2). Because the AI is zero-RNG and the round-1 pacing was measured before
(§D3), I re-ran the full gate rather than predicting frame timing:

- `godot_playtest_scenario(scenario="map_battle_node_huashan")` → **41/41 PASS** at the current
  `at:` frames. **No frame drift observed → the yaml is NOT edited** (all 41 assertions verbatim,
  same expressions, same order, none removed or relaxed). No re-baseline table is needed.

### 6.4 Verification runs (all measured this task)

| Check | Result |
|---|---|
| `map_battle_node_huashan` (full 41-assertion gate) | **41/41 PASS** (green at current frames) |
| `equipment_in_battle_diff` (encounter path byte-frozen) | **47/47 PASS** |
| `spine_to_ending` | **42/42 PASS** |
| `click_move_to_tile` | **10/10 PASS** |
| `tests/test_map_battle_data.gd` | unchanged; property pins (interior, pairwise-distinct, ≠ (7,5)) satisfied by all five new tiles — green |
| `tests/test_map_battle_entry.gd` | unchanged; roster still six units (`turn_order.size() == 6`) — green |
| Compile | clean (data-only edit; no signature/code-path change) |

All checks ran against the sidecar with the staged edit applied (`scripts/data/map_battle_data.gd`
listed in `staged_files_applied`), so the results reflect this reposition, not the old code.
