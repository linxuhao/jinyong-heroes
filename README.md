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
`assets/fonts/LICENSE_OFL.txt`). The project is at roadmap stage 2 -
interaction: the player can read it, click it, and know what to press next.

## Latest round: jinyong-hud - battle HUD information presentation

Presentation-only change (no combat rules, no value changes, no art):

- **Skill buttons (UX-03)** - each button surfaces its effect description
  (`effect_text`, the technique's Chinese description, also shown as the
  tooltip), a short on-face effect summary (`effect_summary_text`, derived
  only from existing `SkillData` numbers, e.g. 「单体 45」) and the inner-force
  cost line (`cost_text`; `SkillData.cost` defaults to 0 -> 「无消耗」).
  No cost number was invented: no technique in `design/10_systems.md` §1 or
  the code defines one - the missing per-skill costs are a recorded content
  gap (`design/20_content.md` §5, also named in `final/delivery_notes.md`).
- **Locked slots 5-8 (UX-04)** - `lock_reason_text` (「第 4 轮解锁」) is
  derived every frame by the HUD from the same tutorial phase-lock predicate
  that disables the button; encounter battles and rounds >= 4 render an empty
  string (never a hardcoded always-on label).
- **Health bar (UX-05)** - `HpLabel` (a child of `Bar`) renders the **current HP
  value only** (e.g. `400`; a 64px bar cannot legibly show the 9-glyph `1000/1000`),
  light glyph on a strong dark outline, with `hp_text` / `hp_value` / `hp_max`
  observables written in `setup()` and `update_health()`. Every health playtest
  assertion is expressed relative to `max_health`. No geometry constant in
  `scripts/ui/health_bar.gd` /
  `scenes/ui/health_bar.tscn` / `tests/test_health_bar.gd` was touched - the
  68x24 widget, Bar 64x12 @(2,12), `EMPTY_CAP_PX` and expand margins are
  byte-identical.

- **Insufficient inner force (review follow-up)** - the `no_energy` button
  state is implemented: a sixth palette state (light purple bg
  `(0.72,0.62,0.92)`, BT.709 luma 0.6629 - pairwise >= 0.10 from every
  other state) with the 「内力不足」 tag (distinct from 「锁定」), a pure
  `no_energy_predicate(cost, energy)`, the `phase_locked > cooldown >
  hp_gated > no_energy > ready` priority chain in `derive_state()`, and a
  `no_energy` term in the HUD's `disabled` derivation. With current content
  every `SkillData.cost == 0`, so the state is real but unreachable in live
  play (documented in `design/20_content.md` §5) and proven by the unit
  test `tests/test_skill_button_no_energy.gd`.

Three new playtest scenarios pin the visibility of the three items
(`skill_button_effect_info`, `locked_slot_unlock_reason`,
`health_bar_numbers`; 47 -> 50 scenarios) plus three new headless unit
tests (`tests/test_skill_button_info.gd`, `tests/test_health_bar_text.gd`,
`tests/test_skill_button_no_energy.gd`).

Post-review hardening in the same round: the HP number was reworked to the
current-value-only route (`fix_hp_number_readability_v2`, recorded in
`design/30_presentation.md`) and four on-frame readability observables are
now asserted in playtest (`HealthBar.hp_text_width_ok`,
`HUD.nameplate_pairwise_overlap`, `HUD.hint_nameplate_overlap`,
`SettingsPanel.title_rows_overlap`) - measured ink-width / overlap checks
that do not depend on the (blind) vision gate. Note: this snapshot also
carries the sibling **jinyong-balance** round's tutorial-balance changes
(shen-diao regen 20 -> 0, melee damage reduction -50% -> -10%;
`design/99_changelog.md` / `final/terminal_victory_balance_notes.md`) -
combat values, outside this round's presentation-only scope.

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

Flow: main menu -> character creation (fixed point budget: attributes /
innate traits) -> tutorial battle as a fully mastered Yang Guo vs the Five
Masters (you are meant to win) -> transition -> sect choice -> cultivation.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check -> headless playtest of all 50 scenarios -> GDScript unit
suite). It fails loudly when the sidecar is unreachable - the code then ships
unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (stdlib-only pins)
```

## Key interfaces

- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`), `CombatManager` (battle state: `tutorial_battle`,
  `current_round`, `phase`, `is_player_turn()`), `GridManager` (grid /
  movement planning).
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections such as
  `debug_damage_player`), the observable surface whitelist and
  `scenario_order`; each `playtest/*.yaml` is one scenario (name ==
  basename, single-integer `at:`, a comparison operator on every assert
  line). Observables are plain vars on live nodes, e.g.
  `SkillButton1..12`: `state_text` / `state_tag_text` / `state_luma` /
  `fahui_text` / `cost_text` / `effect_text` / `effect_summary_text` /
  `lock_reason_text` / `hp_gated` / `disabled`; `HealthBar`:
  `bar_width` / `bar_height` / `empty_area_px` / `empty_cap_px` /
  `hp_text` / `hp_value` / `hp_max` / `hp_text_width_ok` (measured
  rendered-ink width of the HP number fits the 64 px bar).
- **Skill data**: `scripts/data/skill_data.gd` - `@export` schema incl. the
  new `cost: int = 0` (inner-force cost; 0 = undefined this round).
- **Unit tests**: GDScript test files with a top-level
  `static func run() -> bool` are collected by `tests/unit_test_runner.gd`'s
  explicit append-only `TESTS` registry (17 files, incl. the new
  `test_skill_button_info.gd` / `test_health_bar_text.gd` /
  `test_skill_button_no_energy.gd`), run headless via
  `godot --headless --path . -s res://tests/unit_test_runner.gd`.

## Verification status (honest)

The only authoritative gate evidence is the pipeline step products —
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` — pipeline artifacts, not repo files. The repo file
`final/verify_report.json` is deliberately NOT a delivery verdict: it is a
tombstone pointer note (`superseded_pointer_note`) stating it does not
represent the current delivery state, because the pipeline's `repo_apply`
ignores `final/*` and can never refresh it. In short:

- The three information layers (effect/cost, lock reason, HP numbers) are
  implemented and pinned by playtest assertions and unit tests; the frozen
  health-bar geometry and the "no invented numbers" constraint are honored.
- The insufficient-inner-force button state (`no_energy`, visually distinct
  from 锁定) **is implemented** (post-review continuation): sixth palette
  state (luma 0.6629, pairwise >= 0.10 from every other state), predicate +
  priority chain + `disabled` term, proven by
  `tests/test_skill_button_no_energy.gd`. It is unreachable in live play
  with current content (every `SkillData.cost == 0`,
  `design/20_content.md` §5) - expected, not a defect.
- `design/40_ux_backlog.md` shows UX-03 / UX-04 / UX-05 as
  **CLOSED(jinyong-hud)** with evidence paths (the three scenario yamls +
  `final/hud_info_probe_notes.md`), closed by the post-gate evidence task
  from a measured playtest run (50/50 scenarios green, incl.
  `skill_button_effect_info` 5/5, `locked_slot_unlock_reason` 8/8,
  `health_bar_numbers` 5/5, `spine_to_ending` 32/32).
- Compile / playtest / unit / vision gates run after the verifier step;
  their products (`compile_report.json` / `test_report.json` /
  `playtest_summary.md` / `vision_report.json`) are pipeline artifacts, not
  repo files, and none is on disk at this step. The reviewer-recorded run
  (compile 72/72 scripts 0 errors, unit tests 12/12, playtest hard gate
  passed 50/50 as above, `terminal_victory_8_12_rounds_hp_15_40` green
  after the sibling jinyong-balance round) predates the post-review
  `no_energy` addition; that addition is additive and inert with current
  data (all `SkillData.cost == 0`), but the fresh downstream gate run is
  the authoritative confirmation - which is why the verdict stays
  `all_goals_met = false`. The vision gate was blind (endpoint
  unreachable): the rendered-ink legibility of the new labels was never
  machine-adjudicated - the round compensates with measured observables
  (`hp_text_width_ok`, nameplate/hint overlap pins), not a vision verdict.
- Known doc drift (cosmetic, no code inconsistency): the pre-continuation
  records `final/delivery_notes.md` §1/§5/§6/§7/§8.5 and the jinyong-hud
  changelog rows still describe the `no_energy` state as deferred and the
  backlog as OPEN (both were landed by the post-review continuation);
  `final/hud_info_probe_notes.md` §1/§2 additionally still carry the
  pre-rework `cur/max` `hp_text` wording, and the changelog has no
  appended row for the `no_energy` follow-up implementation itself. The
  authoritative records are the code, `design/20_content.md` §5,
  `design/30_presentation.md`, `design/40_ux_backlog.md`; the only
  authoritative gate evidence is the pipeline step products, never
  `final/verify_report.json` (tombstone pointer note).

## Repository layout

- `scripts/` - game code (`autoload/`, `characters/`, `data/`, `ui/`,
  `segments/`, `ai/`, `battlefield.gd`)
- `scenes/` - Godot scenes (`ui/`, `segments/`, `main.tscn`)
- `playtest/` - 50 headless playtest scenarios + the `_common.yaml` contract
- `tests/` - GDScript unit suites + `test_playtest_contract_smoke.py`
- `design/` - the design archive (`00_overview.md` ... `99_changelog.md`);
  `40_ux_backlog.md` tracks player-eye UX debt, `20_content.md` §5 the
  inner-force cost content gap
- `final/` - per-round delivery notes, probe notes and `verify_report.json`
- `assets/` - color-block textures, NotoSansSC font, audio, seed portraits
