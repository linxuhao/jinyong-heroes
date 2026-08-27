# jinyong - Wuxia Crossover Tactics (Godot 4)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. This is a fan-crossover brawler, not
a recreation of any single novel. You create your own nobody, borrow the fully
mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, receive a chance to join a great
sect, spend three in-game years (36 cultivation periods) training, and finally
walk the six-node jianghu map to an ending (`design/00_overview.md`).

Visuals are deliberately **color blocks** (roadmap stage 4 will produce art);
UI text is Chinese, rendered with the bundled NotoSansSC font (SIL OFL, see
`assets/fonts/LICENSE_OFL.txt`). The project is at roadmap stage 3 - game
content: the move table carries real inner-qi costs, and every map node stop
on the main story (plus the 少林 branch) triggers content on entry.

## Latest round: jinyong-nodes - the five main story nodes also have content

One lever only: mainline node event binding. The five declared-but-inert
mainline event slots from the previous round are now live - four with
deterministic pool-row bindings, and 昆仑 (the terminal) argued as an explicit
non-trigger so the ending can never be blocked. No numeric tuning, no combat
rule change, no month-loop change, no art, zero new event prose.

- **The binding table (data-first, all text verbatim from the existing pool).**
  `scripts/data/map_data.gd` `NODES` event slots (each a literal `event_id`
  row - **deterministic binding, never a pool draw**, so the node-event and
  cultivation-bag channels stay independent):

  | Node | event | battle | facility |
  |---|---|---|---|
  | 无名谷 `wuming_valley` | **`active` / `tomb_bed`** 古墓寒玉 (attr 内力 +2) | `declared` / `""` | `declared` / `""` |
  | 洛阳 `luoyang` | **`active` / `merchant`** 行商路过 (silver −20 + item, no attr) | `declared` / `""` | `declared` / `""` |
  | 武当 `wudang` | **`active` / `quanzhen_scripture`** 全真抄经 (attr 悟性 +2) | `declared` / `""` | `declared` / `""` |
  | 襄阳 `xiangyang` | **`active` / `dragon_scrap`** 降龙残谱 (practice +4) | `declared` / `""` | `declared` / `""` |
  | 昆仑 `kunlun` (terminal) | `declared` / `""` | `declared` / `""` | `declared` / `""` |
  | 少林 `shaolin` (branch) | `active` / `night_rain` (unchanged) | `declared` / `""` | `declared` / `""` |

  Every binding was chosen for content fit (a hidden valley concealing an
  ancient tomb, a trade hub with a passing merchant cart, the Taoist
  scripture-copying elder, the 神雕侠侣 climax city's book-stall palm manual)
  and recorded doc-first in `design/20_content.md` §8.2b. 洛阳 deliberately
  binds an **attr-free** option A so the shaolin scenario's `attr_bone`
  differential keeps its exact meaning.

- **昆仑 is an argued non-trigger, and the ending is safe by structure.**
  `map.gd::_travel()` routes an end node to ENDING (`ended = true`,
  `GameManager.enter_segment("ENDING")`) **before** `_maybe_start_entry_event()`
  runs - so a 昆仑 binding would be structurally dead, and the ending IS the
  terminal's content. The machine pin `MapData.active_event_id("kunlun") ==
  ""` stays green and stays (the readable form of the terminal rule). 无名谷
  fires **only on return travel** (its slot is honest: never at boot/load),
  pinned by the new return scenario.

- **Two authorized yaml re-budgets (the round owner's exception), doc-first.**
  Only `playtest/spine_to_ending.yaml` and `playtest/map_node_event_shaolin.yaml`
  were modified - the only two scenarios that walk the map (grep-verified), so
  the other 53 frozen yamls cannot redden via a live mainline event. The
  rationale (why, what, and the one literal re-base) was written in `design/`
  BEFORE the yamls moved (`20_content.md` §8.3/§9, `40_progression.md` §5,
  `90_decisions.md` 2026-08-29, `99_changelog.md`). Assertions were **only
  added, never removed or relaxed**: the spine gains three event blocks
  (f440/f480/f520) and keeps its ENDING block verbatim at f580 - still the
  six-segment connectivity proof with the ending reachable. The single
  existing-assert literal change is shaolin's `events_resolved_count == 1` ->
  `== 2` (洛阳 now resolves an event before 少林's), still an **exact
  equality**, counterbalanced by a NEW `== 1` ladder pin at 洛阳 (f460) so the
  +1-per-resolution ladder is pinned tighter, not looser. The rule
  "only add, never remove" is machine-enforced:
  `tests/test_playtest_contract_smoke.py::test_edited_scenarios_assert_superset`
  checks every frozen pre-edit baseline line of both files (42 lines, the one
  documented exception) against the current files via
  `tests/fixtures/playtest_assert_superset.json`.

- **Map bottom hint unified with the panel text.** The bottom line read
  「左右选择 · 回车启程」 (left/right only) while the panel read
  「左右/上下选择相邻去处，回车启程」 (left/right AND up/down).
  `scenes/segments/map.tscn` `HintLabel.text` is now **byte-identical** to the
  `map.gd::_render()` panel string (full-width comma included), width-safe in
  the existing 400px centered label, and pinned at f30 of the new return
  scenario (`HintLabel.text == "左右/上下选择相邻去处，回车启程"`). The
  same commit updated the stale docstring in `map.gd::_apply_hint_visibility()`
  - no logic change (the visibility toggle is untouched).

- **Two independent event channels, one pool and one effect path.**
  Cultivation's 游历 channel keeps its RNG bag draw + `flags["events_seen"]`
  bookkeeping; the map node channel is a deterministic binding that touches
  neither the bag nor the RNG stream (`EventLogic.apply_option_effects` performs
  zero RNG calls). Both share `EventData` and `EventLogic` and nothing else -
  pinned by the unit suite's D6 bag-independence leg.

- **Honest gaps, recorded not faked (`design/20_content.md` §8.3, §5 style).**
  battle slots: declared, unimplemented. facility (门派设施) slots: declared,
  unimplemented. 昆仑's event slot: declared **on purpose** (terminal
  guarantee - see above; NOT the old spine-budget reason). Plus the node-event
  re-fire policy (every arrival re-fires - the four mainline nodes are
  re-visitable content sites, which is why all new numeric asserts are
  differential) and the 打听 trait action (declared, out of scope). No new
  event text was authored: gaps are recorded, never invented.

- **Regression net.** Two NEW appended scenarios (55 -> 57, append-only):
  `playtest/map_node_event_mainline_east.yaml` (direct-boots
  `map.tscn`, walks 无名谷 -> 洛阳 -> 武当 -> 襄阳, pins each deterministic
  binding + the `events_resolved_count` ladder, ends with 昆仑 one press away
  and `ended == false`) and `playtest/map_node_event_mainline_return.yaml`
  (pins no-fire-at-boot, the 无名谷 return-travel `tomb_bed` binding, and the
  unified hint). Both use relative/differential asserts only (the hint string
  is a text contract, not a game value). Two-place contract sync
  (`scenario_order` + smoke-test `ROUND_SCENARIOS`) appends both names at the
  tail; the pytest smoke pins them plus the superset rule; the GDScript unit
  pins were re-based in the same change set (`tests/test_map_data.gd`
  active_count == 5 + binding pins; `tests/test_map_node_event.gd` live-leg,
  gap-list and bag-independence pins).

Previous round (jinyong-map-events): node entry-content declarations + the
shared `EventLogic` core + the map EVENT phase, with 少林's `night_rain` the
only live binding. Earlier rounds: jinyong-spend-qi (real inner-qi costs),
jinyong-clarity (creation-screen information layer), jinyong-hud (battle-HUD
information layer), jinyong-events (event pool 4 -> 16 rows). All recorded in
`design/99_changelog.md` and the `final/*` notes history.

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
and a confirm page listing the final values) -> tutorial battle as a fully
mastered Yang Guo vs the Five Masters (you are meant to win) -> transition ->
sect choice -> 36-month cultivation -> the jianghu map. In battle, casting a
move spends its inner-qi cost (内力: N in the top strip; a too-expensive move
greys into 「内力不足」; the free basic 重剑无锋 always stays available). On
the map, 左右/上下 cycle the adjacent nodes and 回车 travels; **every mainline
stop now opens its node event on arrival** (洛阳 行商路过 / 武当 全真抄经 /
襄阳 降龙残谱; 无名谷 fires on the return trip; 少林 off the 洛阳 branch still
fires 破庙夜雨) - resolve the event with 上下选择，回车定夺 to continue.
Entering 昆仑 routes **straight to the tiered ending** (end-node routing runs
before entry content, so nothing can block it), and events fire only on
travel - never on boot or load, so save/load roundtrips don't re-trigger.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check -> headless playtest of all 57 scenarios -> GDScript unit
suite). It fails loudly when the sidecar is unreachable - the code then ships
unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (incl. the superset pin)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite
godot --headless --path . -s res://tests/test_cultivation.gd  # SceneTree-style suites
```

## Key interfaces

- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`), `CombatManager` (battle state: `tutorial_battle`,
  `current_round`, `phase`, `is_player_turn()`, and the qi spend path
  `spend_unit_energy(unit, cost)` + the `debug_spend_player_qi()` drain
  fixture), `GridManager` (grid / movement planning), `SaveManager`
  (profile, slots, `rng`, autosave).
- **Map entry-content layer**: `MapData.NODES` rows carry
  `entry_content` = `{event|battle|facility: {status, <type>_id}}`;
  `MapData.entry_content(id) -> Dictionary` (deep copy),
  `MapData.active_event_id(id) -> String` (non-empty iff slot active AND
  `EventData.def(id) != null` - a typo'd binding reads as inert, never
  crashes), `MapData.declared_gap_types(id) -> Array[String]`. Five live
  event bindings as delivered: wuming_valley/luoyang/wudang/xiangyang +
  shaolin (see the table above). Source of truth: `design/20_content.md`
  §8.1/§8.2b / `design/40_progression.md` §5.
- **Shared event resolution**: `EventLogic` (`scripts/data/event_logic.gd`,
  pure statics) - `draw_unseen_id(profile, rng)` (no-repeat bag, one RNG op),
  `apply_option_effects(profile, opt)` (the 5 effect types: silver clamped
  >= 0, attr, item append-once, practice, none; zero RNG calls),
  `add_practice(profile, amount)`. Used by BOTH the cultivation 游历 channel
  and the map node-entry channel (one path, no fork; the node channel never
  calls the bag draw). Event text lives only in
  `scripts/data/event_data.gd` (`EventData.TABLE`, 16 rows, 2 options each).
- **MapScreen node-event phase** (`scripts/segments/map.gd`): `phase`
  (`"TRAVEL"` | `"EVENT"`), `event_id`, `event_focus` (0/1),
  `entry_declared_gap_types`, `last_effect_types`,
  `events_resolved_count`, plus the profile mirrors `silver` /
  `attr_bone..attr_fortune` for differential asserts. End-node routing to
  ENDING runs before entry content; events fire only on arrival by travel.
  The bottom hint (`HintLabel`) shows the unified
  「左右/上下选择相邻去处，回车启程」 in TRAVEL and hides during EVENT.
- **Qi-cost layer** (jinyong-spend-qi): `SkillData.cost: int` (source of
  truth `design/20_content.md` §7); `SkillData.insufficient_energy(cost,
  energy)`; `SkillData.spend(current, cost)` (clamped at 0);
  `Player.energy` / `Player.energy_max` (cap-relative asserts);
  `_execute_skill()` gates and deducts on the single cast path.
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections such as
  `debug_damage_player` and `debug_spend_player_qi`), the observable surface
  whitelist and `scenario_order`; each `playtest/*.yaml` is one scenario
  (name == basename, single-integer `at:`, a comparison operator or
  changed/unchanged token on every assert line). Observables are plain vars
  on live nodes, e.g. `SkillButton1..12`: `state_text` / `state_tag_text` /
  `state_luma` / `fahui_text` / `cost_text` / `effect_text` /
  `effect_summary_text` / `lock_reason_text` / `hp_gated` / `disabled`;
  `HealthBar`: `bar_width` / `bar_height` / `empty_area_px` /
  `empty_cap_px` / `hp_text` / `hp_value` / `hp_max` / `hp_text_width_ok`;
  `CreationScreen`: `phase` / `points_left` / `attr_index` / `attrs` /
  `trait_ids` / geometry observables / `hp_value` / `hp_text` /
  `confirm_summary_text`; `MapScreen`: `current_node_id` / `focus_id` /
  `ended` / the node-event observables above; `HintLabel`: `visible` /
  `text`; `Player`: `energy` / `energy_max` (cap-relative, mirroring the
  `max_health` discipline).
- **Unit tests**: GDScript test files with a top-level
  `static func run() -> bool` are collected by `tests/unit_test_runner.gd`'s
  explicit append-only `TESTS` registry (20 files as delivered, including
  `tests/test_map_node_event.gd`), run headless
  via `godot --headless --path . -s res://tests/unit_test_runner.gd`.
  SceneTree-extending integration suites (`test_cultivation.gd`,
  `test_encounter.gd`, `test_save_manager.gd`, `test_game_manager_fsm.gd`)
  are auto-discovered by the sidecar and driven with their own `-s`
  invocation. The pytest smoke (`tests/test_playtest_contract_smoke.py`)
  statically pins the scenario contract and - new this round - the
  "assertions only added" rule for the two authorized-edited yamls
  (`test_edited_scenarios_assert_superset` against
  `tests/fixtures/playtest_assert_superset.json`).

## Verification status (honest)

The only authoritative gate evidence is the pipeline step products -
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` - pipeline artifacts, not repo files; none is on disk at
the verifier step (the gates run after it). The verifier's own round verdict
is written fresh to `final/verify_report.json` this step (per
`design/90_decisions.md`, `repo_apply` ignores `final/*`, so any repo copy is
never refreshed by a run - gate reports, not `final/` files, are the
authoritative evidence). In short:

- Every implementation-level goal of this round is direct-read verified by
  this step's verifier: the four live deterministic mainline bindings (all
  resolving in the untouched 16-row pool; zero new prose), 昆仑's argued
  non-trigger with the routing-first order confirmed in `map.gd::_travel()`,
  the docs-first `design/` rationale preceding the two authorized yaml
  re-budgets, the only-added assertion discipline (spine ENDING block intact
  at f580; the one re-based literal stays exact equality and is
  counterbalanced by a new ladder pin), the machine superset pin, the
  byte-identical hint unification, the two appended scenarios with
  two-place sync, the re-based unit pins (incl. the D6 bag-independence pin),
  and the delivery notes with the persistent-text audit
  (「查过,只此一处」 - the MAP segment's two persistent labels both yield
  after EVENT -> TRAVEL).
- The round's **measured** pass - all 57 scenarios green (the 55 pre-existing
  minus the two authorized re-budgets, plus the two new ones),
  `spine_to_ending` green with the ending block still proving the six
  segments connected and the ending reachable, compile zero errors, pytest
  smoke green, unit suite green - is **pending the downstream gate run, not
  claimed**. The last fully measured final-tree run (jinyong-map-events:
  55/55 scenarios, 77/77 scripts) predates this round; the mainline bindings
  are additive and the RNG stream / bag are untouched by construction, but
  the authoritative confirmation is the fresh downstream gate run.
- If the downstream playtest gate reddens `spine_to_ending` or any existing
  scenario, that is a mainline-binding defect by this round's constraint:
  make the offending mainline slot inert again (`status: "declared"`), never
  remove or relax an assertion, and never touch HP, damage, cooldowns, or
  the month loop.

## Repository layout

- `scripts/` - game code (`autoload/`, `characters/`, `data/` (incl.
  `map_data.gd`, `event_data.gd`, `event_logic.gd`), `ui/`, `segments/`
  (incl. `map.gd`), `ai/`, `battlefield.gd`)
- `scenes/` - Godot scenes (`ui/`, `segments/` (incl. `map.tscn`),
  `main.tscn`)
- `playtest/` - 57 headless playtest scenarios + the `_common.yaml` contract
  (58 yaml files total); the only two ever modified scenarios are
  `spine_to_ending.yaml` and `map_node_event_shaolin.yaml` (this round's
  authorized exception)
- `tests/` - GDScript unit suites (20 files in the TESTS registry, incl.
  `test_map_data.gd` / `test_map_node_event.gd`, + SceneTree-style
  integration suites), `test_playtest_contract_smoke.py` and the frozen
  `fixtures/playtest_assert_superset.json` baseline
- `design/` - the design archive (`00_overview.md` ... `99_changelog.md`);
  `20_content.md` §8 is the map node entry-content record (binding table,
  rationale, honest gaps), §8.2b the four mainline binding reasons, §9 the
  yaml re-budget frame tables; `40_progression.md` §5 the per-node
  declaration table; `90_decisions.md` the round decisions (deterministic
  binding, 昆仑 ruling, two-file yaml exception, single re-base)
- `final/` - per-round delivery notes and probe notes;
  `verify_report.json` carries the verifier step's round verdict - per
  `design/90_decisions.md` it is never refreshed by `repo_apply`, so the
  gate products, not `final/` files, are the authoritative evidence
- `assets/` - color-block textures, NotoSansSC font, audio, seed portraits
