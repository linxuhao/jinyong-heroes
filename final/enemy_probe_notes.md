# Enemy `acted` Probe Notes — observed, not assumed

**Task:** `enemy_acted_probe` — confirm with a probe that enemies act **at most once per
turn** (design `10_systems.md` §5.1: a turn = move + one action), and record the
observed `acted` / `turns_taken` / damage-event values. **No game code and no
playtest scenario files were written.** All probing was done via
`godot_playtest_scenario` with `inline_scenario` (YAML passed as CLI text, never
staged, never written to the repo). The only repo file produced by this task is
this notes file.

**Probe method (all three runs):** boot `res://scenes/main.tscn` (default scene),
advance the tutorial with 7× `ui_accept` (f3–f15), press `end_turn` at f20 to end
the player's round-1 turn, then sample surface values on fixed frames. Every
assert is an **always-false diagnostic** (`== -1` / `== "NEVER_NAME"` /
`str(x) == "NEVER"`) whose only purpose is to force the harness to print the
`observed` value — so every run reports **0/N passed, hard_passed=true**
(playtest ran clean; the red is the intentional reading mechanism, not a
defect). No `click:` / mouse input was used anywhere.

| Run | inline scenario name | Grid | Asserts | Purpose |
|---|---|---|---|---|
| 1 | `enemy_acted_probe_inline` | 10-frame grid f25–f1195 + f1200 boundary | 268 (0/268, expected) | turn-order / turn-window attribution, coarse damage count |
| 2 | `enemy_acted_probe_fine` | 2-frame grid f21–f185 + f1200 boundary | 184 (0/184, expected) | discrete per-turn damage-event counts, turns_taken/acted boundary |
| 3 | `enemy_acted_lifecycle_probe` | acted flags at f30/60/90/110/150/200/1200 | 51 (0/51, expected) | `acted` turn-end true / turn-start reset lifecycle |

All numbers below are `observed` values taken from the run reports. Frames are
run-specific (headless pacing jitters turn boundaries by ±~10 frames between
runs); attribution always uses that run's own `CombatManager.active_unit_name`
samples, which reproduced the documented order exactly:
round 1 = Yang Guo, East Heretic, Central Divine, South Emperor, North Beggar,
West Poison (player first); round 2 = East Heretic … West Poison, Yang Guo
(player last, from 碧海潮生's `init_minus_20`) — matching
`each_unit_acts_once_per_round_initiative_order` (f1200: `turn_log` 11 entries,
`current_round == 2`, `empty_round_stalls == 0`).

## Observed per-enemy-turn data (run 2 — 2-frame resolution)

`Player.health` samples per enemy turn window (observed frame range in
parentheses; "before" = last sample of the previous turn / first sample of this
turn; "after" = last sample of this turn):

| Enemy | Round | Turn window (frames, observed) | HP before | HP after | Negative deltas (damage events) |
|---|---|---|---|---|---|
| East Heretic | 1 | f20–f22 (f21) | 1000* | 977 | **1** (−23) |
| Central Divine | 1 | f23–f24 (f23) | 977 | 957 | **1** (−20) |
| South Emperor | 1 | f25–f36 (f25–f35) | 957 | 957 | **0** (wait / self-heal turn) |
| North Beggar | 1 | f37–f74 (f37–f73) | 957 | 926 | **1** (−31) |
| West Poison | 1 | f75–f80 (f75–f79) | 926 | 926 | **0** (approach / buff turn) |
| East Heretic | 2 | f81–f94 (f81–f93) | 926 | 897 | **1** (−29) |
| Central Divine | 2 | f95–f130 (f95–f129) | 897 | 880 | **1** (−17) |
| South Emperor | 2 | f131–f138 (f131–f137) | 880 | 841 | **1** (−39) |
| North Beggar | 2 | f139–f142 (f139–f141) | 841 | 810 | **1** (−31) |
| West Poison | 2 | f143–f172 (f143–f171) | 810 | 810 | **0** (wait / buff turn) |

\* 1000 is the player's `max_health` (observed `Player.max_health == 1000` in
the surface); the player entered round 1 at full health (the +26 神雕之力 regen
at the player's own turn start caps at max). The −23 drop is fully inside East
Heretic's turn window and is the only drop in it; it is reported as one event.
Every other "before" value in the table is a directly observed sample.

**Every enemy turn window contains at most ONE negative `Player.health` delta.**
10 enemy turns observed: 7 with exactly one damage event, 3 with zero (wait /
buff turns: South Emperor's 先天调息 self-heal turn, West Poison's approach
turns). **No turn ever showed two damage events.** East Heretic's round-1 turn
was the only one whose start was not bracketed by samples; its single −23 drop
is one event per the one-action-per-turn engine path.

## Observed `acted` lifecycle (runs 2 + 3)

`acted` is **true at the end of a unit's own turn and stays true until that same
unit's next turn start** (it is only reset by that unit's own `begin_turn`,
combat_manager.gd L691-692), so it is directly sampleable:

| Sample (run 3) | active unit | East Heretic | Central Divine | South Emperor | North Beggar | West Poison | Player |
|---|---|---|---|---|---|---|---|
| f30 (r1) | Central Divine | `true` (r1 done) | `true` (r1 done) | `false` (r1 not yet) | `false` | `false` | `false` |
| f60 (r1) | South Emperor | `true` | `true` | `true` (r1 just acted, ending) | `false` | `false` | `false` |
| f90 (r1) | West Poison | `true` | `true` | `true` | `true` | `true` (r1 just acted, ending) | `false` |
| f110 (r2) | Central Divine | `true` (r2 done) | **`false` (r2 active — reset at turn start)** | `true` | `true` | `true` | `false` |
| f150 (r2) | West Poison | `true` | `true` | `true` | `true` | **`false` (r2 active — reset)** | `false` |
| f200 (r2) | Yang Guo | `true` | `true` | `true` | `true` | `true` | **`false` (player turn start reset)** |
| f1200 (r2) | Yang Guo | `true` | `true` | `true` | `true` | `true` | `false` |

Directly observed: **acted is reset to `false` at a unit's own turn start**
(Central Divine r2 at f110, West Poison r2 at f150, Player r2 at f200 — all
active with `acted == false`), and **stays `true` from turn end until then**
(all five enemies `true` at f200/f1200 during the player's turn; full set `true`
at f90 as round 1 completed; East Heretic still `true` at f110 after its r2 turn
ended). The reset is the same `begin_turn` line for every unit, so the pattern
observed for three enemies + the player holds uniformly (East Heretic / South
Emperor / North Beggar's own active windows were not individually sampled in run
3, but they act once per round per `turns_taken` below and their `acted` shows
the same lifecycle at every other sample).

**`turns_taken` (run 2, f1200 boundary):** East Heretic = 2, Central Divine = 2,
South Emperor = 2, North Beggar = 2, West Poison = 2 — exactly **+1 per round**
for every enemy (0 after round 1's start → 1 → 2; `Player.turns_taken == 1` at
f1200 because the player's round-2 turn was live but had not yet ended).
`CombatManager.current_round == 2`, `turn_log` = [Yang Guo, East Heretic,
Central Divine, South Emperor, North Beggar, West Poison, East Heretic, Central
Divine, South Emperor, North Beggar, West Poison] (11 entries), `phase ==
"PLAYER_TURN"`, `empty_round_stalls == 0`.

**Player.health trajectory (run 2, all observed):** 977 → (CD r1) 957 → (SE r1)
957 → (NB r1) 926 → (WP r1) 926 → (EH r2) 897 → (CD r2) 880 → (SE r2) 841 →
(NB r2) 810 → (WP r2) 810 → **836 at the player's round-2 turn start (+26 —
神雕之力 passive regen, a POSITIVE delta, not a damage event; confirms the
"count only negative deltas" rule)**. No DoT/poison damage was observed on the
player in either round.

## Mechanism conclusion

- **Enemies act at most once per turn — CONFIRMED by observation.** Across 10
  enemy turns (2 full rounds), `Player.health` shows at most **one** negative
  delta per enemy turn window at 2-frame resolution (7 turns with one event, 3
  with zero); no enemy produced two damage events in a single turn.
- **`acted` semantics observed:** `true` from a unit's turn end until its own
  next turn start; reset to `false` by `begin_turn` at that next turn start
  (directly observed for Central Divine, West Poison, and the player; uniform
  code path for all units).
- **`turns_taken` increments by exactly +1 per enemy turn** (all five enemies
  at 2 after two rounds), consistent with one turn per round per unit.
- **Structural explanation (matches code reading, combat_manager.gd `_next_turn`
  L595-637):** the enemy turn is "AI evaluates once → at most one
  `execute_action` is awaited → `acted = true` → `end_current_turn()`". The
  budget is enforced by the **caller** for enemies; the player turn, by
  contrast, is event-driven (input can fire `execute_action` any number of times
  while the turn is open) — which is exactly the asymmetry that caused the
  player-side multi-action defect and why enemies never had it. This is the
  caller-side invariant the engine-side `acted` guard (engine_acted_guard
  sibling task) now makes unconditional for any future caller.

## Defect finding

**None.** No enemy showed two damage events in a single turn in any probe run.
If one had, it would be an engine-caller bug — precisely the class of defect the
engine-side `acted` guard protects against. No such case was observed.

## Caveats / run notes

- Probe output is all-red by construction (always-false diagnostics); each run
  reported `hard_passed=true` (harness ran clean — no runtime errors, no
  timeout, frame cap respected; last sample frame 1200 ≤ 2999).
- Frame numbers are run-specific: headless pacing shifts enemy turn boundaries
  ±~10 frames between runs (e.g. Central Divine's round-1 turn sat at f23–f24 in
  run 2 but was still active at f30 in run 3). Attribution within a run is
  deterministic and based on that run's own `active_unit_name` samples, which
  reproduced the documented turn order exactly.
- Damage magnitudes (e.g. East Heretic −23 r1 / −29 r2, South Emperor −39 r2)
  reflect the enemies' skills (some turns use skills, not basic attacks); only
  the COUNT of negative deltas per turn window is used for the one-action
  verdict.
- South Emperor's 先天调息 and West Poison's buff turns produced zero player
  damage — recorded as 0-event turns, not counter-evidence.
- No `click:` / mouse assertions were used (mouse battle path is untestable this
  round per SOTA); the probe uses only keyboard/engine-driven turns and surface
  sampling.
