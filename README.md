# jinyong - Wuxia Crossover Tactics (Godot 4)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. This is a fan-crossover brawler, not
a recreation of any single novel. You create your own nobody, borrow the fully
mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, receive a chance to join a great
sect, and spend three in-game years (36 cultivation periods) training. The
six-segment spine: creation -> tutorial battle -> transition -> sect choice ->
cultivation -> battles/map (`design/00_overview.md`).

Visuals are deliberately **color blocks** (roadmap stage 4 will produce art);
UI text is Chinese, rendered with the bundled NotoSansSC font (SIL OFL, see
`assets/fonts/LICENSE_OFL.txt`). The project is at roadmap stage 3 - game
content: the move table now carries real numbers, starting with inner-qi
costs.

## Latest round: jinyong-spend-qi - the inner-qi pool actually gets spent

One numerical lever, and only that lever: inner-qi costs. No health, damage,
cooldown, or enemy-strength value changed.

- **The cost table (docs first, `design/20_content.md` §7 is the source of
  truth, landed before any code)** - all 8 tutorial player moves now carry an
  inner-qi cost:

  | Move (button) | Art | Cost (qi) | Tier |
  |---|---|---|---|
  | 重剑无锋 (1) | 玄铁剑法 | **0** | free basic - the plainest move of the art, kept free by the existing 「无消耗」 pin (§7.3; the never-fully-disarmed guarantee itself belongs to the cost-0 basic attack, not this move) |
  | 大巧不工 (2) | 玄铁剑法 | 15 | light line AoE |
  | 力斩千钧 (3) | 玄铁剑法 | 20 | mid cross AoE |
  | 四海无量 (4) | 玄铁剑法 | 25 | 绝招, cd 6 |
  | 心惊肉跳 (5) | 黯然销魂掌 | 10 | cheapest single, cd 1 |
  | 拖泥带水 (6) | 黯然销魂掌 | 15 | light utility + slow |
  | 徘徊空谷 (7) | 黯然销魂掌 | 20 | mid jump utility + AoE |
  | 黯然销魂十七式 (8) | 黯然销魂掌 | 30 | most expensive - the ultimate 绝招 (HP-gated, cd 8) |

  Ladder: light 10-15 < mid 20 < 绝招 25/30. All 23 enemy techniques and all
  progression (encounter) techniques stay cost 0 (enemies have energy 0;
  progression pricing is a later round's lever). The pool (Yang Guo: 180)
  does **not** regenerate within a battle - recorded gap in §7.4.
  `design/10_systems.md` §1 now says the pool **stores AND spends**
  (「内力池既存也耗」) - the old "只存不耗" statement is gone.
- **Casting actually spends qi** - `combat_manager.gd::_execute_skill()` (the
  single execution point for player and AI casts) gained: an insufficient-qi
  gate before any side effect (the cast is refused, nothing consumed - no
  cooldown, no qi, no action), and a success-only clamped deduction beside
  the cooldown start. Costs are set in `battlefield.gd`
  `_create_all_skill_data()` (the data factory); the pure math lives in
  `SkillData.insufficient_energy(cost, energy)` / `SkillData.spend(current,
  cost)` - one value, three consumers (executor gate, select-time rejection,
  HUD `no_energy` state), no drift.
- **`no_energy` is now reachable in live play** - with all costs 0 the state
  was unreachable (built and unit-tested in the jinyong-hud round, inert).
  With real costs it fires: the button enters `no_energy` (not `phase_locked`)
  with the 「内力不足」 tag and is disabled; the hotkey select is refused with
  the visible reason 「内力不足」. The top-strip EnergyLabel now refreshes
  every frame (a setup-only write would freeze the number at the starting
  pool once casts deduct).
- **Regression net** - one new playtest scenario
  `playtest/qi_cost_blocks_cast_no_energy.yaml` (53 -> 54 scenarios) pins it
  in a real battle: a real cast deducts the pool (`energy < energy_max`,
  cap-relative asserts), a drained pool drives button 4 into `no_energy`
  (explicitly `!= "phase_locked"`) + disabled + tag, the refused select
  leaves nothing consumed, and the free basic stays `ready` as the
  never-disarmed negative control. One new headless unit test
  `tests/test_qi_costs_match_design.gd` pins the cost table against the
  design doc, pins cost 0 for every other skill id by enumeration, and pins
  the insufficient/spend truth tables (18 -> 19 files in the TESTS registry).
  Contract sync: `scenario_order` + smoke-test `ROUND_SCENARIOS` both append
  the new scenario at the tail; `Player.energy_max` whitelisted;
  `debug_spend_player_qi` drain action added (goes through the same shared
  spend path as real casts). None of the 53 pre-existing scenario files was
  touched.
- **Tutorial winnability budget** - the win path's 12 casts spend 170 of 180
  qi (margin 10); every cast passes the gate (`energy == cost` is castable,
  only `energy < cost` is blocked), so damage/cooldown/HP trajectories are
  unchanged and `terminal_victory_8_12_rounds_hp_15_40` keeps its green
  baseline. If a future retune breaks it, the fix is the cost table, never
  HP or enemies.

History: the jinyong-clarity round added the creation-screen information
layer (UX-06/07/08); jinyong-hud added the battle-HUD information layer
(UX-03/04/05) including the originally-inert `no_energy` state. Both are
recorded in `design/99_changelog.md` and the `final/*` notes history.

## Requirements

- Godot 4.x. No external dependencies, no build step.

## Install

```bash
git clone <this repo> jinyong && cd jinyong
# open project.godot in the Godot 4 editor (import happens automatically)
```

## Run

Open the project in the Godot 4 editor and press Play - the game boots into
the main menu (新的冒险 / 读取存档 / 设置 / 退出). Headless:

```bash
godot --path .
```

Flow: main menu -> character creation (fixed 30-point budget: five attributes
with live effect explanations and current HP, 13 innate trait/flaw toggles,
and a confirm page listing the final values before you commit) -> tutorial
battle as a fully mastered Yang Guo vs the Five Masters (you are meant to
win) -> transition -> sect choice -> cultivation. In battle, casting a move
spends its inner-qi cost from the pool shown in the top strip (内力: N);
when the pool drops below a move's cost, that button greys into 「内力不足」
and cannot be cast - the free basic 重剑无锋 always stays available.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check -> headless playtest of all 54 scenarios -> GDScript unit
suite of 19 collected files). It fails loudly when the sidecar is unreachable
- the code then ships unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (stdlib-only pins)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite
```

## Key interfaces

- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`), `CombatManager` (battle state: `tutorial_battle`,
  `current_round`, `phase`, `is_player_turn()`, and the qi spend path
  `spend_unit_energy(unit, cost)` + the `debug_spend_player_qi()` drain
  fixture), `GridManager` (grid / movement planning).
- **Qi-cost layer** (jinyong-spend-qi): `SkillData.cost: int` carries the
  table (source of truth `design/20_content.md` §7; 7 of 8 moves 10-30,
  重剑无锋 0 = free basic); `SkillData.insufficient_energy(cost, energy)`
  (cost > 0 and energy < cost - never blocks free moves or enemies);
  `SkillData.spend(current, cost)` (clamped at 0); `Player.energy` / the
  once-written `Player.energy_max` cap observable for cap-relative asserts;
  `_execute_skill()` gates and deducts on the single cast path.
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections such as
  `debug_damage_player` and `debug_spend_player_qi`), the observable surface
  whitelist and `scenario_order`; each `playtest/*.yaml` is one scenario
  (name == basename, single-integer `at:`, a comparison operator on every
  assert line). Observables are plain vars on live nodes, e.g.
  `SkillButton1..12`: `state_text` / `state_tag_text` / `state_luma` /
  `fahui_text` / `cost_text` / `effect_text` / `effect_summary_text` /
  `lock_reason_text` / `hp_gated` / `disabled`; `HealthBar`:
  `bar_width` / `bar_height` / `empty_area_px` / `empty_cap_px` /
  `hp_text` / `hp_value` / `hp_max` / `hp_text_width_ok`; `CreationScreen`:
  `phase` / `points_left` / `attr_index` / `attrs` / `trait_ids` plus the
  geometry observables and the clarity layer `hp_value` / `hp_text` /
  `confirm_summary_text`; `Player`: `energy` / `energy_max` (qi asserts are
  cap-relative, mirroring the `max_health` discipline).
- **Unit tests**: GDScript test files with a top-level
  `static func run() -> bool` are collected by `tests/unit_test_runner.gd`'s
  explicit append-only `TESTS` registry (19 files, incl.
  `test_qi_costs_match_design.gd`, `test_creation_info_texts.gd` and the
  jinyong-hud trio), run headless via
  `godot --headless --path . -s res://tests/unit_test_runner.gd`.

## Verification status (honest)

The only authoritative gate evidence is the pipeline step products -
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` - pipeline artifacts, not repo files; none is on disk at
the verifier step (the gates run after it). The verifier's own round verdict
is written fresh to `final/verify_report.json` this step (the
jinyong-clarity-era tombstone pointer note was archived with a numeric
suffix on replace): `all_goals_met = false` / `ready_for_deploy = false`,
**solely because the measured regression pass awaits the gate products
listed above** - every implementation-level goal is direct-read verified.
Per the decision recorded in `design/90_decisions.md`, `repo_apply` ignores
`final/*`, so any repo copy is never refreshed by a run: gate reports, not
any `final/` file, are the authoritative evidence. In short:

- The cost table is documented in `design/20_content.md` (§1 move tables +
  §7, landed docs-first) and byte-identical in code
  (`battlefield.gd::_create_all_skill_data()`) and in the unit-test pin
  (`tests/test_qi_costs_match_design.gd` `DESIGN_COSTS`).
  `design/10_systems.md` §1 no longer says the pool is never spent.
- The engine change is verified by direct read: the insufficient-qi gate
  returns before any side effect (cost>0-guarded, so enemies and the free
  basic are unaffected), and the success-only clamped deduction sits beside
  the cooldown start on the single cast path (`_execute_skill()`), reached
  through the one shared `spend_unit_energy()` helper.
- The new scenario pins `no_energy` in a real battle with cap-relative qi
  asserts; the win-path budget (170/180) is design-documented so the
  tutorial stays winnable without touching HP, damage, cooldowns or enemies.
- The round's **measured** pass - all 54 scenarios green (the 53 pre-existing
  untouched + the new one), `spine_to_ending` 32/32,
  `terminal_victory_8_12_rounds_hp_15_40` 6/6, 19/19 unit tests, pytest
  smoke green, compile zero errors - is **pending the downstream gate run,
  not claimed**. The last fully measured final-tree run (jinyong-clarity's:
  53/53 scenarios, 74/74 scripts) predates this round; the qi-cost changes
  are additive by construction (data + one gate + one deduction), but the
  authoritative confirmation is the fresh downstream gate run - which is why
  the round verdict stays `all_goals_met = false` until those reports land.
- If the downstream playtest gate reddens `terminal_victory` or any existing
  scenario, that is a cost-table defect by the round's fallback rule: revise
  the qi costs in `design/20_content.md` + `battlefield.gd` +
  `test_qi_costs_match_design.gd` - never HP, damage, cooldowns, or enemies.

## Repository layout

- `scripts/` - game code (`autoload/`, `characters/`, `data/`, `ui/`,
  `segments/`, `ai/`, `battlefield.gd`)
- `scenes/` - Godot scenes (`ui/`, `segments/`, `main.tscn`)
- `playtest/` - 54 headless playtest scenarios + the `_common.yaml` contract
  (55 yaml files total)
- `tests/` - GDScript unit suites (19 collected files) +
  `test_playtest_contract_smoke.py`
- `design/` - the design archive (`00_overview.md` ... `99_changelog.md`);
  `40_ux_backlog.md` tracks player-eye UX debt, `20_content.md` §7 is the
  inner-qi cost table (source of truth; §5's old cost gap is closed, §7.4
  records the no-regen gap)
- `final/` - per-round delivery notes and probe notes;
  `verify_report.json` carries the verifier step's round verdict (the old
  tombstone pointer note was archived on replace) - per
  `design/90_decisions.md` it is never refreshed by `repo_apply`, so the
  gate products, not `final/` files, are the authoritative evidence
- `assets/` - color-block textures, NotoSansSC font, audio, seed portraits
