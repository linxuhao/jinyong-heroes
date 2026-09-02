# Delivery Notes — fix_c5_winnable_huashan_route (R3b C5)

Date: 2026-09-02. Deliverable: `playtest/huashan_winnable_normal_route.yaml`
(full rewrite, single file; `name:`/`scene:` lines preserved). Registry: the
scenario name is already registered (`_common.yaml` + ROUND_SCENARIOS) — zero
registry edits. Zero edits to any `scripts/**`, `design/**`, `_common.yaml`,
`tests/**`, or the locked `playtest/map_battle_node_huashan.yaml`.

## STATUS: BLOCKED — escalation clause exercised

The C5 escalation clause is triggered. The Huashan duel cannot be won by the
player side on a real save without trivializing combat, so per the brief the
scenario is delivered as an honest attempt whose WIN is a measured red, NOT a
fake win and NOT a redefinition of victory. **Owner action requested: unlock
`scripts/data/map_battle_data.gd` (the five-greats roster data).** This was
pre-declared in the brief ("if after C1 the player side still cannot win without
trivializing combat, stop and ask me to unlock map_battle_data.gd, I will
approve").

## Head/body fix (the R3 defect this card closes) — DONE
The old card booted `menu.tscn` on a main-timeline keyboard spine (stuck at
TUTORIAL, 13 reds; "win" was a debug victory). The rewrite is clicks-only
(`clicks:`), boots `menu.tscn`, and matches its title: a real-save practice
route (36 practice months) → 华山 duel with real skill/target clicks. The
boot now runs green: 12 asserts pass through menu → creation → tutorial → join
少林 → cultivation (the prior "stuck at TUTORIAL" 13-red state is gone).

## RED-FIRST — measured four-values

### (1) Honest timeline red (the DELIVERED clicks-only scenario, current C1/C4/C7 tree)
A direct `godot_playtest_scenario(scenario="huashan_winnable_normal_route")` run
on the delivered file reaches 华山 and loses the duel honestly (28/39 asserts
green; the route, battle arrival, round-1 PLAYER_TURN, round-2, and the C4
`current_round >= 3` boundary all pass — the red is the hero dying):
- failing_frame: f1600 (C4 boundary frame) — first post-duel-arrival red
- first_failing_assert: `Player.health: health > 0` (round-3 frame)
- observed: `Player.health == 0` and `CombatManager.phase == "ENEMY_TURN"` — the
  hero was killed in round 3 (it survives rounds 1-2, reaching round 3, but dies
  there). The WIN frame f2100 then observes `current_state == "LOST"`, and the
  post-Continue MAP asserts observe "LOST" (never returned).
- green_asserts_before_red: 28
- (Minor timing cosmetic: f1070 asserts MAP/focus but the travel-onto-华山
  auto-fires the duel a few frames early, so f1070 observes "BATTLE"; the
  battle-arrival asserts at f1110 pass. No assertion was deleted/loosened.)

### (1b) Interim red (before the year-3 month-count fix) — recorded
An earlier run of the same scenario had the 36-month practice route drift ~1
month short of MAP (f975 observed "CULTIVATION"). The month click grammar is
ONE `CultOptionButton0` per `at:` frame (bundling 3 clicks into one frame drops
the month-boundary click — measured). Year-3 corrected to 37 single-click frames
(m1 augment+card+练功+row=4, m2..m11=3×10, m12 card+练功+row=3); after the fix
the route reaches the duel as in (1).

### (2) The decisive duel measurement (why WIN is unreachable) — MEASURED
Using the harness with the strongest achievable hero (debug_fast_forward = ALL
gongfa mastered, which over-produces any legitimate 36-month real-save route),
reaching 华山 (verified: `huashan_duel`, `tutorial_battle == false`, hero
`max_health` = 327, `initiative` = 46) and fighting with real clicks only:
- `turn_order` (initiative-descending) =
  `[East Heretic(86), Central Divine(80), South Emperor(72), North Beggar(70),
  West Poison(68), ProgressionHero(46)]` — the hero acts LAST every round, so
  all five greats burst it before it acts.
- Round 1: hero 327 → 265 (round-1 damage floor 62); hero's PLAYER_TURN arrives
  (f720). Round 2: hero 265 → ~133-143. Round 4: **hero health 0, state LOST.**
- All five greats remained at FULL health through the hero's death:
  East 95/95, West 115/115, South 100/100, North 120/120, Central 130/130. The
  hero landed ZERO damage: the melee hero (attack_range 1, shaolin palm school)
  cannot close the ~4-5 tile gap to the greats within `moves_left` 2, and the
  proven adjacency-gated body-click attack (click_targeting_fixed: deals 39 ONLY
  when adjacent) never connects because no great is adjacent when the hero acts.
- A genuine real-save 36-month PRACTICE route is far weaker than the above
  (it masters only ~4 arts, `mp`≈6 → `max_health`≈111, not 327), so it loses
  faster.

### Escalation determination (per the brief's C5 clause)
No legitimate player-side lever available this round changes the result:
- C1 mastery terms (live): +health/energy/initiative, but the initiative gap to
  the greats (46 vs 68-86) is unbridgeable on a 36-month real route.
- C4 readiness bands (fixed, `{even:38,strong:55}`): readiness scores the hero
  "strong" but the verdict is not the duel's outcome — the melee-vs-ranged 5v1
  still kills the hero.
- C7 route composition: a bone-cultivate / agility-cultivate / mixed route raises
  attack/health/initiative but, per (2), the hero acts LAST and cannot reach the
  greats → cannot trade damage fast enough against 560 total enemy HP.
The only remaining lever is the ENEMY DATA (roster composition, initiative,
range, per-great HP), which is the locked `map_battle_data.gd`. Trivializing
combat (reducing enemy count/HP/range) is out of scope ("不加系统"; the locked
file) and is explicitly NOT permitted to manufacture a green. Therefore: STOP,
deliver BLOCKED with this evidence, request the unlock.

## Tutorial-skirmish debug fallback — EXERCISED
Per the architecture-gate ruling, the tutorial skirmish is skipped with ONE
`debug_win_tutorial` (f220, before the Huashan segment) — the same documented
seed `clicks_only_storyline.yaml` f245 uses. This is the ONLY debug in the
timeline. The Huashan duel is NOT debug-assisted (the WIN-red is honest).
Recorded here, in the scenario header, and as C8 changelog material.

## Text-property self-checks (in-repo, pass)
- `debug_win_tutorial`: exactly 1 occurrence, f220 (pre-Huashan tutorial leg).
- `debug_fast_forward`: 0 occurrences.
- `ui_accept` / `move_*`: 0 occurrences (the timeline is clicks-only).
- Huashan segment (focus_id huashan → WIN, f1070–f2100): zero non-empty
  `actions:` (all `clicks:`).
- `Player.health == <number>`: 0 (only `health < max_health` / `health > 0`).
- No round literal pinned as a goal (uses `>= 2`/`>= 3` boundaries + `changed`).
- `scene:` = `res://scenes/menu.tscn`; `name:` unchanged; basename unchanged.

## Regression / lock (static self-check, this card touches ONE file)
- `playtest/map_battle_node_huashan.yaml`: byte-untouched (locked gate; read for
  pacing only).
- Six-file lock (`scripts/battlefield.gd`, `game_manager.gd`, `scene_manager.gd`,
  `map.gd`, `map_battle_data.gd`): untouched — this card made zero code edits.
- No revert markers anywhere (this card needs none; its red is a direct run).
- C4 boundary nail (`current_round >= 3` + `health > 0`) is authored at f1600 in
  the duel segment.

## After an unlock (if the owner approves) — re-run recipe
Re-run `godot_playtest_scenario(scenario="huashan_winnable_normal_route")`; the
only expected change is f2100 flipping WON + the f2140/f2220 ContinueButton → MAP
return asserts landing. The clicks-only spine, 36-month route, and Huashan fight
grammar stay as authored; no assertions are deleted or loosened to fit a result.

## For C8 (changelog row material)
R3b C5: rewrote `huashan_winnable_normal_route` into an honest clicks-only,
real-save, real-skill Huashan attempt (menu boot green, one sanctioned
tutorial-seed debug, zero debug in the Huashan segment). Duel measured
UNWINNABLE on the current data (maxed hero dies round 4 vs five greats
unscratched, acts last at initiative 46 vs 68-86, melee cannot close range) →
C5 escalation clause exercised: delivered BLOCKED pending owner unlock of
`map_battle_data.gd`; no fake win.
