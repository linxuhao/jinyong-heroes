# Technical Architecture Design - jinyong-spend-qi (Spend the Inner-Qi Pool)

Round goal: give the 8 player moves real inner-qi costs, wire combat casting to
actually spend qi (insufficient qi blocks the cast), and make the `no_energy`
HUD state reachable in a real battle and pinned by a new playtest scenario.
**This round moves exactly one numerical lever: qi costs.** No health, damage,
cooldown, move-range, or enemy-strength values change.

Everything below was verified against the repo at design time (file paths,
line anchors, scenario timelines, and the playtest contract are real, not
assumed). Paths are relative to the repo root (`./`).

---

## 1. Overview

The presentation layer for costs is already shipped and inert
(`SkillData.cost` schema field, `CostLabel` "内力 N" rendering,
`no_energy_predicate` + 6-state palette + unit test
`tests/test_skill_button_no_energy.gd`). What is missing is **content**
(the 8 cost values), **enforcement** (a cast-time gate + deduction), and
**proof** (a real-battle scenario that pins `no_energy`).

This round is therefore a *data-table + one-gate* change, decomposed as:

1. **Docs first** (hard rule from the brief): the cost table lands in
   `design/20_content.md` and the "只存不耗" paragraph is replaced in
   `design/10_systems.md §1` **before** any code changes.
2. **Data**: 7 of the 8 Yang Guo moves get non-zero `cost` in
   `scripts/battlefield.gd::_create_all_skill_data()` (additive property
   assignments, same pattern as `is_finisher` / `hp_gate_below_ratio`).
   重剑无锋 (button 1) stays 0 - see §2.3.
3. **Engine**: `scripts/autoload/combat_manager.gd::_execute_skill()` gains
   an insufficient-qi gate (failure -> skill NOT consumed, returns null) and
   a success-only clamped deduction next to the cooldown start.
4. **Player-facing**: `scripts/characters/player.gd::_skill_reject_reason()`
   gains an "内力不足" rejection reason (mirrors the existing acted-gate
   two-level pattern: visible reason at select time, hard gate at execute
   time), plus a `energy_max` observable for cap-relative asserts.
5. **Display tracking**: `scripts/ui/hud.gd` refreshes the top-strip
   EnergyLabel per frame (a setup()-only write would freeze the number at
   the starting pool once casts start deducting).
6. **Proof**: one new playtest scenario (`qi_cost_blocks_cast_no_energy`,
   the 54th scenario), one new debug injection action
   (`debug_spend_player_qi`), one new unit test
   (`tests/test_qi_costs_match_design.gd`, 18 -> 19 files in the TESTS
   registry), and the two-place contract sync
   (`playtest/_common.yaml` `scenario_order` +
   `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS`).

Nothing is rebuilt in `skill_button.gd` / `hud.gd` palette / scenes - the
machinery this round activates already exists and is unit-tested.

---

## 2. Design changes (docs-first) - the cost table

Per the addon contract, these are the declared design-archive changes the
`5_design` step applies surgically after the run passes. **The docs task
lands before the code tasks** (brief: "必须先写进 design/20_content.md,
再写进代码").

### 2.1 The cost table (the verbatim contract implementers copy)

Inner-qi costs for the 8 tutorial player moves. Yang Guo's pool is 180
(`battlefield.gd` `cd.energy = 180`, design/20_content.md §1 内力值 180).

| # | Button | Skill id (battlefield.gd) | Art | Cost (qi) | Rationale (tier) |
|---|--------|---------------------------|-----|-----------|------------------|
| 1 | SkillButton1 | `heavy_edge` (重剑无锋) | 玄铁剑法 | **0** | free basic strike - see §2.3 |
| 2 | SkillButton2 | `grand_simplicity` (大巧不工) | 玄铁剑法 | **15** | light line AoE |
| 3 | SkillButton3 | `thousand_force_cleave` (力斩千钧) | 玄铁剑法 | **20** | mid cross AoE |
| 4 | SkillButton4 | `boundless_seas` (四海无量) | 玄铁剑法 | **25** | 绝招 (self-origin radius-2 AoE, cd 6) |
| 5 | SkillButton5 | `heart_rending_strike` (心惊肉跳) | 黯然销魂掌 | **10** | cheapest single (cd 1) |
| 6 | SkillButton6 | `dragging_mire` (拖泥带水) | 黯然销魂掌 | **15** | light utility single + slow |
| 7 | SkillButton7 | `wandering_valley` (徘徊空谷) | 黯然销魂掌 | **20** | mid jump utility + AoE |
| 8 | SkillButton8 | `seventeen_melancholy_forms` (黯然销魂十七式) | 黯然销魂掌 | **30** | most expensive - the ultimate 绝招 (adjacent AoE, hp-gated, cd 8) |

Ladder: light 10-15 < mid 20 < 绝招 25/30; 十七式 (30) is the single most
expensive move in the game, honouring "重招贵、轻招便宜、绝招最贵".
All 23 enemy/other techniques and all progression (encounter) techniques
**stay cost 0** - enemies have `energy = 0` and progression pricing is a
later round's lever.

### 2.2 Win-path budget (why these numbers are safe - verified cast-by-cast)

`terminal_victory_8_12_rounds_hp_15_40.yaml` is the cost-sensitive gate
(baseline today: **green 6/6**; the scenario's own header still carries the
stale "red at ~78%" note from the pre-jinyong-balance era - the measured
current state is green). Its scripted chain casts (in order):
`skill_1, skill_4, skill_3, skill_8, skill_1, skill_3, skill_7, skill_4,
skill_5, skill_1, skill_7, skill_1`. With the table above:

| Cast | Cost | Cumulative | Energy before cast (cap 180) | Passes gate? |
|------|------|-----------|------------------------------|--------------|
| f620 skill_4 | 25 | 25 | 180 | 25 ≤ 180 yes |
| f970 skill_3 | 20 | 45 | 155 | yes |
| f1045 skill_8 | 30 | 75 | 135 | yes |
| f1300 skill_1 | 0 | 75 | 105 | free |
| f1560 skill_3 | 20 | 95 | 105 | yes |
| f1820 skill_7 | 20 | 115 | 85 | yes |
| f2080 skill_4 | 25 | 140 | 65 | yes |
| f2340 skill_5 | 10 | 150 | 40 | yes |
| f2600 skill_1 | 0 | 150 | 30 | free |
| f2870 skill_7 | 20 | 170 | 30 | 20 ≤ 30 yes |
| f2960 skill_1 | 0 | 170 | 10 | free |

**Total spend 170 / 180, margin 10.** Every cast passes the gate
(`energy == cost` is castable; the predicate blocks only `energy < cost`),
so damage/cooldown/HP trajectories are byte-identical and the scenario stays
6/6. The win path nearly exhausts the pool by design - the costs are a real
constraint (a wasteful player can run dry) without breaking winnability.
The other two skill-casting scenarios are far under budget:
`central_divine_innate_qi_fatal_guard` spends 15+20 = 35 (plus free
`skill_1` casts); `skill_rejection_reason_texts` casts only free `skill_1`.

**Fallback rule (from the brief, restated for PM):** if any regression run
reddens the tutorial win, the COST TABLE is wrong - revise costs only.
Never touch HP, damage, cooldowns, or enemies this round.

### 2.3 Why 重剑无锋 stays free (documented zero-cost decision, non-goal 3)

1. **Existing pin**: `playtest/skill_button_effect_info.yaml` line 42 pins
   `SkillButton1.cost_text == "无消耗"`, and existing yamls are immutable
   this round. A non-zero cost for button 1 would redden an existing
   scenario - the only resolution satisfying both constraints is cost 0.
2. **Content rationale (record it, don't invent a number)**: it is the
   basic strike of the sword art ("重剑无锋,大巧不工" - the plainest
   verb), cd 1, and the design property that **the player is never fully
   disarmed**: at 0 qi there is always one castable move. This property is
   pinned as a negative control in the new scenario (§5.2).
3. All 12 skill-bar slots beyond the 8 player moves keep cost 0
   (progression arts - the 养成 round's lever, not this round's).

### 2.4 Archive edits (the docs task, exact targets)

| File | Edit |
|------|------|
| `design/10_systems.md` §1 | Replace the paragraph starting "**内力池本轮只存不耗。**" with the new statement: the pool stores AND spends - casting deducts per the `20_content.md` cost table, insufficient qi blocks the cast at the execution point (button shows 「内力不足」), 重剑无锋 is free (rationale in 20_content), and the pool **does not regenerate within a battle** (recorded gap - regen mechanics belong to a later round). |
| `design/20_content.md` §1 | Add an inner-force-cost column to both move tables (玄铁剑法 4 rows, 黯然销魂掌 4 rows) with the §2.1 values. |
| `design/20_content.md` | Append a dated section (2026-08-27, jinyong-spend-qi): the full §2.1 table + rationale, the win-path budget (170/180), the 重剑无锋 free rationale (§2.3), enemy/progression techniques stay 0, and the no-regen gap. Also append a dated note inside §5 that the "内容缺口" it recorded is now CLOSED by this round (the original text stays as the jinyong-hud historical record). |
| `design/30_presentation.md` | Amend the no_energy bullet ("当前内容下不可达……刻意不写任何伪装它在实战中触发的 playtest 断言") with a dated note: real costs now defined, no_energy is reachable in live play and pinned by `qi_cost_blocks_cast_no_energy` (not a伪装 assert - the costs are real content). |
| `design/99_changelog.md` | Append the jinyong-spend-qi row (what/why, one-lever discipline, budget math). |
| `design/40_ux_backlog.md` | Append a 记录 row: UX-03's `cost_text` now shows real costs on 7 of 8 slots; button 1 stays 「无消耗」 by the documented pin + rationale. |
| `README.md` | Update the skill-data bullet: `cost: int` now carries real values (see `design/20_content.md`); 0 = free/undefined. |

In-archive text follows the archive's existing (Chinese) convention; the
numbers and structure above are the contract. Code-comment sync (the now-
false "display only - no technique costs this run" comments) is listed in
C6.

---

## 3. Architecture / data flow (text diagram)

```
design/20_content.md §cost table  (SOURCE OF TRUTH, lands first)
        |
        v
battlefield.gd :: _create_all_skill_data()        [C1 - data]
        sets .cost on 7 SkillData resources (heavy_edge untouched = 0)
        |
        v
SkillData.cost  (existing @export field, one value, three consumers)
        |
        +--> skill_button.gd :: no_energy_predicate -> SkillData.insufficient_energy
        |       (HUD per-frame derivation: state_text / disabled / 内力不足 tag)   [C5]
        |
        +--> player.gd :: _skill_reject_reason                                      [C4]
        |       select-time gate -> action_hint "内力不足" (visible reason)
        |
        +--> combat_manager.gd :: _execute_skill                                    [C3]
                GATE  (failure -> return null, nothing consumed):
                  "energy" in unit and SkillData.insufficient_energy(cost, energy)
                SUCCESS BLOCK (beside cooldown start, acted = true):
                  unit.energy = SkillData.spend(unit.energy, cost)   [clamped >= 0]
                shared spend_unit_energy() helper  <-- debug_spend_player_qi (C3b)
                                                      (injection goes through
                                                       the same spend path)

player.gd :: energy / energy_max (NEW observable, cap-relative asserts)  [C4]
hud.gd    :: EnergyLabel "内力: %d" refreshed PER FRAME                   [C5]

playtest/qi_cost_blocks_cast_no_energy.yaml  (54th scenario)             [C7]
_common.yaml (surface: Player.energy_max; actions: debug_spend_player_qi;
              scenario_order append) + test_playtest_contract_smoke.py
              ROUND_SCENARIOS append + new contract test                 [C8]
tests/test_qi_costs_match_design.gd  (data pin, TESTS 18 -> 19)          [C8]
```

Cast chain (verified): UI button / hotkey -> `player.select_skill()`
(rejection reasons) -> J / click target -> `player._execute_skill()` ->
`CombatManager._execute_action()` -> `combat_manager.gd::_execute_skill()`
(the single execution point for player AND AI casts - the `cost > 0` guard
makes enemies, whose techniques are all cost 0 and whose energy is 0,
byte-identical in behavior).

---

## 4. Component list

### C0 · Docs-first task (§2.4) - BLOCKS all code tasks
Single task, lands before C1. No code may land before it (brief hard rule).

### C1 · `scripts/battlefield.gd` - the 8 cost values
- **Where**: `_create_all_skill_data()` (~L227-378). Set `.cost`
  additively after `_skill()` returns - the exact pattern already used for
  `is_finisher` / `hp_gate_below_ratio` / `jump_tiles` /
  `status_applied`. The 10-positional-arg `_skill()` factory signature is
  NOT extended (per the SOTA: additive property assignment, not a new arg).
- **What** (verbatim):
  ```gdscript
  # heavy_edge: no cost line - the free basic (design/20_content.md cost table)
  skills["grand_simplicity"].cost = 15
  skills["thousand_force_cleave"].cost = 20
  skills["boundless_seas"].cost = 25    # set alongside its is_finisher block
  skills["heart_rending_strike"].cost = 10
  skills["dragging_mire"].cost = 15     # alongside status_applied
  skills["wandering_valley"].cost = 20  # alongside jump_tiles
  skills["seventeen_melancholy_forms"].cost = 30  # alongside hp_gate/is_finisher
  ```
  (Where a local var already exists - boundless_seas, dragging_mire,
  wandering_valley, seventeen_forms - assign on the local before storing;
  equivalent.)
- **Not touched**: all 23 enemy/other technique entries, `_skill()`
  itself, every damage/cooldown/HP value. Interface: none new - the
  existing `SkillData.cost` field.

### C2 · `scripts/data/skill_data.gd` - two pure cost statics
Additive, next to the `cost` field:
```gdscript
## Insufficient-inner-force predicate (single source of truth,
## jinyong-spend-qi): true when the skill costs inner force (cost > 0) and
## the pool is strictly below it. cost == 0 never blocks (free basic,
## enemy/progression techniques). Shared by the executor gate, the player's
## select-time rejection, and skill_button.no_energy_predicate (which
## delegates here - its public API and unit tests stay unchanged).
static func insufficient_energy(cost: int, energy: int) -> bool:
	return cost > 0 and energy < cost

## Spend math (pure): pool minus cost, clamped at 0; negative costs read
## as 0. The executor's deduction and the debug drain both go through this.
static func spend(current: int, cost: int) -> int:
	return maxi(current - maxi(cost, 0), 0)
```

### C3 · `scripts/autoload/combat_manager.gd` - gate + deduction + debug drain
1. **Gate** in `_execute_skill()` (~L1310-1320), appended to the existing
   gate block after the `hp_gate_below_ratio` check (mirrors the HUD
   priority order phase > cooldown > hp_gated > no_energy):
   ```gdscript
   # --- Execution gate (failure -> skill NOT consumed): insufficient inner
   # force (jinyong-spend-qi). cost == 0 never gates, so enemies (energy 0,
   # all techniques free) and the free basic are unaffected.
   if "energy" in unit \
   		and SkillData.insufficient_energy(int(skill.cost), int(unit.energy)):
   	return null
   ```
   (`skill_data.gd` is preloaded/available; add the const preload if the
   file lacks one.)
2. **Deduction** in the success block (~L1416, beside the cooldown start),
   success-only (failed gates spend nothing, start no cooldown, never set
   `acted`):
   ```gdscript
   # --- Spend inner force (only on successful execution, clamped >= 0) ---
   spend_unit_energy(unit, int(skill.cost))
   ```
3. **Shared spend path** (single helper both the cast and the debug action
   use - the roadmap's "injection goes through the normal pipeline" rule):
   ```gdscript
   ## Spend `cost` inner force from `unit` through the ONE spend path every
   ## cast uses. Clamped at 0. Returns the new pool value (-1 when the unit
   ## exposes no energy / is gone - nothing spent).
   func spend_unit_energy(unit: Node, cost: int) -> int:
   	if unit == null or not is_instance_valid(unit) or not ("energy" in unit):
   		return -1
   	if int(cost) <= 0:
   		return int(unit.energy)
   	unit.energy = SkillData.spend(int(unit.energy), int(cost))
   	return int(unit.energy)
   ```
4. **Debug injection action** `debug_spend_player_qi()` next to
   `debug_damage_player()` (~L399): no-op unless a battle is active and the
   player exists; drains the player's whole remaining pool through
   `spend_unit_energy(player, int(player.energy))` (drain-to-zero is robust
   against any future cost retuning - every costed move becomes
   insufficient). Three-place wiring, same as every existing debug action:
   `project.godot [input]` (empty-events entry, harness-only),
   `scripts/autoload/game_manager.gd` `_process`
   (`if Input.is_action_just_pressed("debug_spend_player_qi"): CombatManager.debug_spend_player_qi()`),
   and `playtest/_common.yaml` `actions:` list (append).

### C4 · `scripts/characters/player.gd` - select gate + energy_max
1. **`energy_max` observable** (cap-relative asserts, mirrors the
   `max_health` discipline):
   ```gdscript
   ## 内力池上限: the pool this battle started with. Playtest surface for
   ## cap-relative qi asserts (energy < energy_max), mirroring max_health.
   ## Written once in setup(); the pool does not regenerate in battle
   ## (recorded gap, design/20_content.md).
   var energy_max: int = 0
   ```
   In `setup()` beside `energy = data.energy` (~L214): `energy_max = data.energy`.
   (Enemy units are NOT touched - the surface asserts only the Player's
   pool; enemy energy is 0 and their techniques are free.)
2. **Select-time rejection reason** in `_skill_reject_reason()` (~L278),
   inserted after the HP-gate block and before the technique-seal check
   (mirroring the HUD priority; visible reason instead of a silent no-op -
   the acted-gate precedent from the 2026-08-24 changelog row):
   ```gdscript
   # jinyong-spend-qi: insufficient inner force. Selecting a skill whose
   # cost exceeds the current pool is refused with the visible reason; the
   # HUD already renders the same fact (no_energy state + 内力不足 tag) and
   # the engine hard-gates the cast (CombatManager._execute_skill).
   if skill != null and SkillData.insufficient_energy(int(skill.cost), int(energy)):
   	return "内力不足"   # 8th rejection reason; grep-able acceptance point
   ```
   Add `const SkillData = preload("res://scripts/data/skill_data.gd")` if
   not already present (skill_data.gd has no dependencies - no cycle).

### C5 · `scripts/ui/hud.gd` - live EnergyLabel
The top-strip `EnergyLabel` ("内力: %d") is currently written only in
`setup()` (~L371-381, comment "display only; no technique costs this run").
Once casts deduct, a setup()-only write freezes the number at the starting
pool - exactly the "assertion green, player can't see it" defect class this
repo hunts. Refactor: extract the guarded write into
`_refresh_energy_label(player: Node)`, call it from `setup()` AND from the
per-frame refresh that calls `_refresh_skill_button_states(player)`
(~L700-711). No rects, nodes, or geometry constants change - text content
only (shorter strings shrink the label rect; the existing
`top_text_pairwise_overlap` / `top_text_in_strip` pins read rects and stay
green). The skill-button state derivation (`no_energy`, `disabled`,
`derive_state`) is ALREADY per-frame - zero changes there.

### C6 · Comment sync (no logic) - stale "display only" claims
Update the now-false doc-comments so the next round doesn't get misled
(each is a one-line comment edit, grep-verified targets):
`player.gd:110`, `enemy.gd:83`, `data/character_data.gd:18`,
`data/gongfa_data.gd:18`, `hud.gd` energy-label comment, and the
"with current content every SkillData.cost == 0" notes in
`skill_button.gd` (`no_energy` var, `no_energy_predicate`,
`cost_label_text`) and `hud.gd` (`_refresh_skill_button_states`).
`skill_button.gd::no_energy_predicate` delegates to
`SkillData.insufficient_energy` (one-line body change; public signature,
palette, priority chain, and `tests/test_skill_button_no_energy.gd` all
unchanged and stay green).

### C7 · `playtest/qi_cost_blocks_cast_no_energy.yaml` - the new scenario
Full skeleton in §5. Boots `res://scenes/main.tscn` (default scene),
7x `ui_accept` boot prefix, all within round 1's player turn (~f400, far
under the 3000-frame cap).

### C8 · Contract + unit tests
- `playtest/_common.yaml`: append `debug_spend_player_qi` to `actions:`;
  append `energy_max` to the `Player:` surface block; append
  `qi_cost_blocks_cast_no_energy` to `scenario_order` (tail).
  Counting note (per Step-1 review): the dir currently holds **53 scenario
  yamls + `_common.yaml` = 54 files**; this round makes it **54 scenarios +
  _common = 55 files** (the "53 existing scenarios" in the brief = the
  53 pre-existing scenario files, all of which must stay green).
- `tests/test_playtest_contract_smoke.py`: append
  `qi_cost_blocks_cast_no_energy` to `ROUND_SCENARIOS` (tail - same order
  as scenario_order); add `test_qi_cost_surface_contract()` mirroring
  `test_hud_info_surface_contract`: pins `Player.energy_max` whitelisted,
  `debug_spend_player_qi` in the actions list, the new yaml's existence,
  `name:` == basename, single-integer `at:` values, and a comparison
  operator (or `changed`/`unchanged` token) on every 4-space dotted assert
  line.
- `tests/test_qi_costs_match_design.gd` (new, `static func run() -> bool`,
  registered in `tests/unit_test_runner.gd` `TESTS` in alphabetical
  position - 18 -> 19 files): instantiates
  `preload("res://scripts/battlefield.gd").new()` (never added to the
  tree, so `_ready` never runs; `_create_all_skill_data()` is pure data),
  pins all 8 costs against the §2.1 table, pins `cost == 0` for EVERY other
  skill id in the returned dict (robust enumeration, not a spot check),
  and pins the `SkillData.insufficient_energy` / `SkillData.spend` truth
  tables (0-cost never blocks; energy == cost castable; clamp at 0;
  negative cost reads as 0).
  Rationale for pinning the numbers at the unit layer: the playtest
  scenario stays **cost-agnostic** (asserts the mechanic only) so future
  cost retuning reddens exactly one greppable unit file, not the
  regression net.

### C9 · Docs closure
The §2.4 archive edits ride with C0 (docs-first); after the gates run, the
round record lands in `99_changelog.md` / `40_ux_backlog.md` 记录 /
`30_presentation.md` amendment (already listed in §2.4 - same edits, one
pass). `final/` delivery notes per repo convention (optional, PM).

---

## 5. Playtest contract (architect-owned surface + scenario skeleton)

Surface/action additions (the hard contract for implementers - names must
match verbatim):
- `actions:` += `debug_spend_player_qi` (must ALSO exist in
  `project.godot [input]` as an empty-events entry, and be handled in
  `game_manager.gd` `_process`).
- `surface: Player:` += `energy_max` (`energy` is already whitelisted).
- `scenario_order:` += `qi_cost_blocks_cast_no_energy` (tail).

### 5.1 Scenario skeleton - `playtest/qi_cost_blocks_cast_no_energy.yaml`

Name: `qi_cost_blocks_cast_no_energy` (basename == name). Boots the default
scene (real tutorial battle). All action frames follow the measured
terminal_victory / fahui_du cadence; PM may shift frames after a probe run
but the assert set and their order are the contract.

```yaml
name: qi_cost_blocks_cast_no_energy
description: >-
  Real-battle proof that casting spends inner qi and that insufficient qi
  blocks the move: a real skill_2 cast deducts the pool (energy <
  energy_max); after draining the pool through the shared spend path
  (debug_spend_player_qi), button 4 (never cast, never phase-locked, no HP
  gate) enters no_energy - NOT phase_locked - and is disabled; the hotkey
  select is refused (visible reason 内力不足, selection unchanged) and
  nothing is consumed (energy unchanged, no cooldown started). The free
  basic (button 1) stays ready - the player is never fully disarmed.
timeline:
- at: 3 / 5 / 7 / 9 / 11 / 13 / 15   # 7x ui_accept (boot: menu -> creation -> tutorial)
- at: 30
  assert:                            # baseline: full pool, no no_energy anywhere
    Player.energy: 'energy == energy_max'
    SkillButton4.state_text: 'state_text != "no_energy"'
    SkillButton4.disabled: false
- at: 46 / 61 / 76                   # move_up x3 -> player (7,2), Central Divine adjacent
- at: 91
  actions: [skill_2]                 # select 大巧不工 (cost > 0)
- at: 106
  actions: [attack_confirm]          # real cast lands on Central Divine
- at: 150
  assert:                            # THE deduction: a real cast spent qi
    Player.energy: 'energy < energy_max'
    Player.acted: true
    CombatManager.current_round: 1
- at: 170
  actions: [debug_spend_player_qi]   # drain pool to 0 via the shared spend path
- at: 240
  assert:                            # THE state: no_energy, not phase_locked, disabled
    Player.energy: 'energy >= 0 and energy < energy_max'
    SkillButton4.state_text: 'state_text == "no_energy"'
    SkillButton4.state_text: 'state_text != "phase_locked"'
    SkillButton4.disabled: true
    SkillButton4.state_tag_text: 'state_tag_text == "内力不足"'
    SkillButton1.disabled: false     # free basic never gated (negative control)
    SkillButton1.state_text: 'state_text == "ready"'
- at: 260
  actions: [skill_4]                 # hotkey attempt on the blocked move
- at: 280
  assert:                            # select refused with the visible reason
    ActionHintLabel.text: 'text == "内力不足"'
    Player.selected_skill_index: 'selected_skill_index != 3'
- at: 300
  actions: [attack_confirm]          # confirm attempt (acted gate rejects - nothing happens)
- at: 360
  assert:                            # nothing consumed: no spend, no cooldown, still blocked
    Player.energy: unchanged
    SkillButton4.cooldown_remaining: 0
    SkillButton4.state_text: 'state_text == "no_energy"'
```

Why this shape holds (verified against the code):
- Button 4 is array index 3 -> `phase_locked` requires `i >= 4`, so it is
  NEVER phase-locked; it is never cast in this scenario (cooldown 0
  throughout) and has no `hp_gate_below_ratio` - the only predicate that
  can be true at f240 is `no_energy`. The `waiting` override is false
  throughout (player's turn: the skill_2 cast sets `acted` but the turn
  persists until `end_turn`, which this scenario never presses).
- The f300 `attack_confirm` reaches the acted gate ("本回合已行动",
  set by the f106 cast) before any basic attack executes - no side effects;
  the f360 asserts prove skill 4 itself never fired.
- All qi asserts are cap-relative (`energy_max`); the exact cost values are
  deliberately NOT asserted here (see C8 rationale).
- Every assert line carries a comparison operator (or the `unchanged`
  differential token), satisfying the smoke-test discipline.

---

## 6. Technology stack

In-place Godot 4 / GDScript - no new dependencies, no new scenes, no new
nodes, no new signals (the HUD refreshes per frame already; the EnergyLabel
joins that path). Reused as-is per the SOTA: `SkillData.cost` schema field,
the 6-state button palette + `derive_state` + `no_energy_predicate`, the
per-frame HUD derivation, the debug-action injection pattern
(`project.godot [input]` + `game_manager.gd` `_process` +
`combat_manager.gd` fixture), the rejection-reason machinery, and the
headless playtest/pytest harness. Nothing external is warranted for a
data-table + one-gate change.

Linter manifest (see `linter_manifest.json`): `.py` -> ruff,
`.yaml`/`.json`/`.md` -> basic. `.gd` is deliberately NOT in the manifest -
the `gdscript_check` gate parses every GDScript file with
`godot --check-only` after each implementation step (host-controlled, per
the addon guidance).

---

## 7. Edge cases (Step-1 SOTA -> how this design answers each)

| # | SOTA edge case | Answer |
|---|----------------|--------|
| 1 | `skill_button_effect_info.yaml` pins `SkillButton1.cost_text == "无消耗"` | 重剑无锋 stays cost 0 (§2.3) - only button 1 is pinned; the other 7 moves are free to take costs without touching any existing yaml. |
| 2 | Enemies have `energy = 0`; a cost on any enemy skill would permanently block enemy casting | The gate is `cost > 0`-guarded and per-unit; all 23 enemy techniques stay 0 (pinned by enumeration in the new unit test). Enemies are byte-identical. |
| 3 | `spine_to_ending` cost-insensitive; `terminal_victory` cost-sensitive | Win-path budget verified cast-by-cast (§2.2): 170/180, all gates pass; baseline green 6/6; if it reddens, revise costs (never HP/enemies). |
| 4 | `_skill()` is the factory, not the cast point | Costs set additively in `_create_all_skill_data()` (C1); gate + deduction live in `_execute_skill()` (C3) - the single execution point for player and AI. |
| 5 | Deduction must be success-only and floored | Deduction sits in the success block beside the cooldown start; `SkillData.spend` clamps at 0 and treats negative costs as 0 (C2). Failed gates return null having spent nothing. |
| 6 | `phase_locked` masks `no_energy` in the priority chain | The scenario asserts on SkillButton4 (index 3, never phase-locked, never cast, no HP gate) and pins `state_text != "phase_locked"` explicitly. |
| 7 | No qi-cap observable for relative asserts | `player.gd::energy_max` added + whitelisted (C4); all qi asserts are cap-relative. |
| 8 | Presentation is done - don't rebuild it | Zero palette/scene/label changes; the only presentation edit is making the existing EnergyLabel track the live pool per frame (C5) - without it the round's own feature would be invisible. |
| 9 | Playtest contract is a multi-place sync | scenario_order + ROUND_SCENARIOS + surface whitelist + `project.godot [input]` + `game_manager` handler + `_common.yaml` actions (C3/C7/C8); counting clarified (53 -> 54 scenarios). |
| 10 | Tutorial budget bounds the table | Ladder 10/15/20/25/30; win path spends 170/180 (§2.2); the free basic keeps the player never-disarmed. |

Additional verified-non-risks: the only existing scenarios casting
non-free moves are `terminal_victory` (budgeted), `central_divine_innate_qi_fatal_guard`
(spends 35), and `skill_rejection_reason_texts` (free `skill_1` only) - a
repo-wide grep for `skill_[2-8]` across `playtest/*.yaml` confirms no
others. `CostLabel` renders "内力 15" style text inside its pinned
(26,2)-(62,14) rect (font 9 - 2 CJK + digits fits; `clip_text=false`,
`text_overrun_behavior=0` already set, no-ellipsis discipline respected).
Save games are unaffected (battles are ephemeral; `PlayerProfile` carries
no battle-pool field). Encounter battles (progression techniques, cost 0)
are unaffected - the gate is data-driven, so a future round can price them
without touching the engine (extensibility, no premature work now).

---

## 8. Rollback / safety

No irreversible operations. Every change is a file edit (git-revertible);
no schema migration, no data rewrite, no file deletion:
- New files: 1 scenario yaml, 1 unit test.
- Append-only edits: `_common.yaml` (actions/surface/scenario_order),
  smoke test (ROUND_SCENARIOS + one new test function),
  `unit_test_runner.gd` TESTS, `project.godot [input]`.
- In-place edits: `battlefield.gd` (7 property assignments),
  `combat_manager.gd` (one gate + one helper + one debug fixture + one call
  in the success block), `player.gd` (one var + one setup line + one gate
  branch), `hud.gd` (extract + per-frame call), `skill_button.gd` (one-line
  delegation), `skill_data.gd` (two statics), comments.
- The only content replacement is the `10_systems.md §1` paragraph
  (old text quoted in §2.4, recoverable via git and re-stated verbatim in
  the task).
- Rollback = revert the commit; the inert-before/inert-after property
  holds in reverse (with all costs 0 the predicate is identically false
  and every code path is byte-identical to today's).

Ordering safety: C0 (docs) blocks C1; the cost values in code must match
the landed doc table exactly (the unit test enforces it).

---

## 9. Regression criteria + at-risk scenario list

**Must-stay-green (the round's success gate):**
- All 53 existing scenarios green (54 after the append; 55 yaml files incl.
  `_common.yaml`).
- `spine_to_ending` **32/32** (force-wins via `debug_win_tutorial` - cost
  insensitive).
- `terminal_victory_8_12_rounds_hp_15_40` **6/6** (baseline green; budget
  math in §2.2; a new red here means the cost table is wrong - revise
  costs, nothing else).
- GDScript unit suite 18 -> 19 files, all pass; pytest smoke suite green.
- The new scenario `qi_cost_blocks_cast_no_energy` green.

**At-risk focus list for re-runs during implementation** (Step-1 review
suggestion - the full suite is mandatory anyway; these are the ones whose
timelines interact with costs):
`terminal_victory_8_12_rounds_hp_15_40` (12 casts, 170 qi),
`central_divine_innate_qi_fatal_guard` (casts skill_2 + skill_3),
`skill_rejection_reason_texts` (free casts + reason texts - the new
"内力不足" reason must not fire at a full pool), `skill_button_effect_info`
(the 无消耗 pin), `fahui_du_multiplies_damage` (free skill_1 + damage pin),
`skill_button_visual_states` / `skill_bar_waiting_state` /
`skill_button_turn_overlay` / `two_phase_skill_unlock_and_hp_gate` /
`locked_slot_unlock_reason` / `skill_hint_and_range_highlight` /
`skill_description_visible` / `ui_geometry_readability` (button-state
readers - all assert at a full 180 pool, where `no_energy` is false), and
`spine_to_ending`.

---

## 10. Task decomposition (for PM)

| Task | Content | Depends on |
|------|---------|-----------|
| T1 `docs_costs_first` | §2.4 archive edits: 20_content cost tables + dated section + §5 gap-closure note; 10_systems §1 paragraph replacement; 30_presentation no_energy amendment; 99_changelog row; 40_ux_backlog 记录; README bullet. | - (BLOCKS all code) |
| T2 `skill_data_statics` | C2: `insufficient_energy` + `spend` statics (+ comment sync of the "display only" lines in character_data/gongfa_data). | T1 |
| T3 `battlefield_costs` | C1: 7 cost assignments + free-basic comment. | T1, T2 |
| T4 `executor_gate_spend` | C3: gate, success-block deduction via `spend_unit_energy`, helper, `debug_spend_player_qi` + project.godot/game_manager wiring. | T2, T3 |
| T5 `player_select_gate_observable` | C4: `energy_max` var + setup write; `_skill_reject_reason` "内力不足" branch (+ player.gd:110 comment). | T2, T3 |
| T6 `hud_live_energy_label` | C5 (+ energy-label comment); C6 skill_button delegation + stale comments. | T2 |
| T7 `playtest_scenario` | C7: new yaml; `_common.yaml` surface/actions/scenario_order appends. | T4, T5 |
| T8 `contract_and_unit_tests` | C8: smoke-test ROUND_SCENARIOS + `test_qi_cost_surface_contract`; `tests/test_qi_costs_match_design.gd` + TESTS registration. | T3, T7 |
| T9 `regression_run` | §9: full playtest (54 scenarios), unit suite (19 files), spine 32/32, terminal_victory 6/6, new scenario green; record baseline-vs-after for terminal_victory (no misattribution of pre-existing state). | T1-T8 |

Sequencing note: T4/T5/T6 are independent of each other (all depend on
T2/T3); T7 needs T4 (the drain action) and T5 (the select reason +
`energy_max`); T8 needs T3 (the data pin) and T7 (the scenario file).
