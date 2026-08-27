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

Three new playtest scenarios pin the visibility of the three items
(`skill_button_effect_info`, `locked_slot_unlock_reason`,
`health_bar_numbers`; 47 -> 50 scenarios) plus two new headless unit tests
(`tests/test_skill_button_info.gd`, `tests/test_health_bar_text.gd`).

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
- **Unit tests**: any `tests/*.gd` extending `SceneTree` with a top-level
  `static func run() -> bool` is auto-discovered by the sidecar's `/script`
  gate (see `tests/unit_test_runner.gd`).

## Verification status (honest)

`final/verify_report.json` records this round's verdict:
**all_goals_met = false, ready_for_deploy = false**. In short:

- The three information layers (effect/cost, lock reason, HP numbers) are
  implemented and pinned by playtest assertions and unit tests; the frozen
  health-bar geometry and the "no invented numbers" constraint are honored.
- The insufficient-inner-force button state (`no_energy`, visually distinct
  from 锁定) was **deferred, not implemented** - no skill defines a cost yet
  (`design/20_content.md` §5), which leaves that MVP goal unmet this round.
- `design/40_ux_backlog.md` keeps UX-03/UX-04/UX-05 **OPEN** with
  「修复已落,post-fix 闸门证据待验」: per backlog rule 2, closing them needs
  the full playtest gate products (`playtest_report.json` /
  `playtest_summary.md`) on disk with the three scenarios green - artifacts
  produced downstream of the verifier step, not repo files.
- Compile / playtest / unit / vision gates run after the verifier step; the
  reviewer-recorded results quoted in `final/delivery_notes.md` §3
  (compile 71/71 scripts, unit 11/11, playtest hard gate passed with the
  three new scenarios and `spine_to_ending` green, only the then-sanctioned
  `terminal_victory_8_12_rounds_hp_15_40` red) are pipeline artifacts, not
  repo files, and are not counted as verified here. The tree has also
  evolved since those runs (HP current-value rework, on-frame readability
  observables, the sibling jinyong-balance round), so the downstream gate
  re-run is the authoritative confirmation. The vision gate was blind
  (endpoint unreachable): the rendered-ink legibility of the new labels was
  never machine-adjudicated - the round partially compensates with measured
  observables (`hp_text_width_ok`, nameplate/hint overlap pins), not a
  vision verdict.
- Known doc drift (cosmetic, no code inconsistency): `final/delivery_notes.md`
  §1/§7/§8.1 and the jinyong-hud changelog row still describe `hp_text` as
  `cur/max`, while the shipped code/scenario/design record the
  current-value-only route (`fix_hp_number_readability_v2`).

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
