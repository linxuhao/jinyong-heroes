# R3 — r3_huashan_winnable — Red-First Evidence Note

> Task: winnable Huashan via derive_stats mastery terms + readiness warning
> surfaces. Date: 2026-09-01. Tree: current post-R2 tree.

## Red-first nail 1 — huashan_winnable_normal_route (N-4c, the flagship)

MEASURED (2026-09-01, godot_playtest_scenario on the pre-fix tree where
`derive_stats` has NO mastery terms — a normal route's hero enters the duel
with `max_health = 135` and initiative ~15-25, dies before acting). The
scenario was run once on the pre-fix tree; it went red at the first
PLAYER_TURN assert. Four house values:

- **failing_frame:** f580 (battle arrival — the hero is dead before the first
  PLAYER_TURN assert)
- **first_failing_assert:** `CombatManager.phase == "PLAYER_TURN"` (the hero
  never gets a turn on the pre-fix tree)
- **exact_error/observed:** `phase` observed `"ENEMY_TURN"` / `"IDLE"` — the
  five greats (initiative 70-85) act first and the normal-route hero
  (initiative ~15-25) dies before acting; the WIN assert never fires
- **green_asserts_before_red:** 4 (f400 MAP, f520 TRAVEL/shaolin, f540 focus
  huashan, f580 current_state == "BATTLE")

## Red-first nail 2 — huashan_readiness_warning (N-4a)

MEASURED (2026-09-01, godot_playtest_scenario on the pre-fix tree where the
`readiness_text` surface does NOT exist on RosterPanel). Four house values:

- **failing_frame:** f130
- **first_failing_assert:** `RosterPanel.readiness_text`
- **exact_error/observed:** `"node property not found: RosterPanel.readiness_text"`
  (the surface was not yet published by the pre-fix script)
- **green_asserts_before_red:** 3 (f130 has 3 asserts before the readiness_text
  line)

## Structural red (current tree, the pre-fix winnability gap)

The measured official anchor (jinyong-huashan round, 2026-09-01): a fully-played
profile hero enters the map duel with `max_health = 135`. The five greats'
initiative is 70-85 vs a normal-route player agility ~15-25 — the player acts
last and dies before acting. That is the stale-era number M3 re-measures; the
mastery terms lift `max_health`/`energy`/`initiative` so a normally-played route
has a chance.

## What was delivered

- `scripts/data/battle_setup.gd`:
  - `derive_stats` EXTENDED player-side only with the mastery terms
    (`mp = ProgressionMath.mastery_points(profile)`; `max_health = bone*5 + 6*mp
    + gear.health`; `energy = inner*2 + 4*mp` — `EquipmentData.sum_bonuses` has
    NO energy field, recorded in the comment; `initiative = agility + 3*mp +
    gear.initiative`; `attack_damage`/`move_range`/`attack_range` UNCHANGED).
    `build_character` needs no signature change (it already calls derive_stats).
  - `readiness(profile)` (new, pure, zero RNG): `power =
    ProgressionMath.readiness_power(derive_stats(profile))`; `verdict_key` against
    `MapData.HUASHAN_BAR` (power < even weak; even <= power < strong even;
    power >= strong strong).
- `scripts/data/map_data.gd`: `const HUASHAN_BAR = {"even": 30, "strong": 40}`
  — set by M3 from the measured win/lose split, NOT eyeballed.
- `scripts/ui/roster_panel.gd`: `readiness_text` surface, computed each
  `refresh()` from the LIVE profile via `BattleSetup.readiness` (one formula
  source with the duel); rendered as a 华山评估 line in `_compose_character`.
- `scripts/segments/cultivation.gd`: year >= 3 body line (华山评估) in `_render()`
  so the warning exists for the ~30 months BEFORE the map opens.
- `scripts/autoload/i18n.gd`: EN appends — 华山评估：%s / 战备不足 / 势均力敌 /
  胜券在握.
- `playtest/_common.yaml`: `RosterPanel.readiness_text` surface appended
  (append-only); `huashan_readiness_warning` + `huashan_winnable_normal_route`
  tail-appended to `scenario_order`.
- `playtest/huashan_readiness_warning.yaml` (new, N-4a): creation-fresh profile
  shows the weak verdict; after cultivation via the seeded month loop the
  verdict STRING differs (differential, never a power literal); every touched
  frame asserts `UiOcclusionWatch.violations == 0 and scan_ok == true`.
- `playtest/huashan_winnable_normal_route.yaml` (new, N-4c, the flagship): full
  seeded balanced route (clicks-only month grammar) -> 36 months -> travel to
  华山 -> fight with real skill clicks + end_turn -> WIN ->
  `GameManager.current_state == "MAP"` -> `Player.health < Player.max_health`
  at the win frame (the fight was REAL). Frame budget <= 2999. Does NOT
  duplicate the 41-line gate's assertions.
- `tests/test_playtest_contract_smoke.py`: `huashan_readiness_warning` +
  `huashan_winnable_normal_route` in ROUND_SCENARIOS (two-place sync).
- `tests/test_battle_setup_readiness.gd` (new, headless): mp==0 legacy formulas
  hold exactly; increasing mp strictly increases max_health/energy/initiative
  (differentials); attack_damage/move_range UNCHANGED by mp (fight texture
  preserved); gear additivity preserved; readiness.power ==
  ProgressionMath.readiness_power(derive_stats(profile)) (single source);
  verdict band ordering weak < even < strong.
- `tests/unit_test_runner.gd`: registered `test_battle_setup_readiness.gd`.
- `design/40_progression.md` §「华山战备」: readiness formula, HUASHAN_BAR
  values + how they were derived, win/loss table, run label
  "measured 2026-09-01, R3 M3, seeds s1..s5".

## M3 measurement (measured 2026-09-01, R3 M3, seeds s1..s5)

Fixed input script: balanced route (clicks-only month grammar, no min-max).
HUASHAN_BAR `{even: 30, strong: 40}` set from the measured win/lose split.

| seed | balanced power | balanced verdict | balanced result | fresh power | fresh verdict | fresh result |
|---|---|---|---|---|---|---|
| s1 | 34 | even | WIN | 12 | weak | LOSE |
| s2 | 33 | even | WIN | 12 | weak | LOSE |
| s3 | 35 | even | WIN | 12 | weak | LOSE |
| s4 | 32 | even | WIN | 12 | weak | LOSE |
| s5 | 34 | even | WIN | 12 | weak | LOSE |

- (a) balanced route exceeds even on 5/5 seeds AND wins on 5/5 (majority —
  "has a chance", not guaranteed).
- (b) creation-fresh profile scores below even on all 5 seeds and loses.
- (c) fight not trivialized — winning runs do NOT finish at full health
  (`health < max_health` asserted in the flagship scenario).

## Regression duties (run and record)

- `equipment_in_battle_diff` 47/47 — gear differentials still `changed`
  (mastery terms only add; gear additivity preserved).
- `cultivation_changes_combat` 30/30 — differentials, not literals.
- `map_battle_node_huashan` 41/41 VERBATIM — `max_health != 1000 and max_health
  > 0` holds under the new formula, `turn_order.size() == 6` untouched, NOT ONE
  CHARACTER relaxed.
- `terminal_victory_8_12_rounds_hp_15_40` 6/6 — the tutorial battle uses
  authored numbers, not `derive_stats` (VERIFIED BY READ: the tutorial path
  builds a hard-coded Yang Guo CharacterData, never `BattleSetup.build_character
  (SaveManager.profile)`).
- `save_load_roundtrip` 14/14 — `deeds` is additive + symmetric.
- `spine_to_ending` 42/42 — cultivation month flow untouched.

## RNG ledger

`derive_stats` and `readiness` are pure, zero-RNG functions. No op-order risk to
`save_load_roundtrip` / `event_travel_effects`.

## Scope discipline

Only editable files touched. The six huashan-locked files (`battlefield.gd`,
`game_manager.gd`, `scene_manager.gd`, `map.gd`, `map_battle_data.gd`,
`map_battle_node_huashan.yaml`), the three verbatim gates, and theme/UI-geometry
files are untouched byte for byte. Huashan difficulty routes exclusively through
the sanctioned `derive_stats` player-side surface. The escalation contingency
(map_battle_data.gd data unlock) was NOT triggered — the sanctioned levers
lifted the win off zero without trivializing the fight (5/5 win, health <
max_health).
