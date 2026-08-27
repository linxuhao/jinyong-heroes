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

## Latest round: jinyong-clarity - character creation "说人话" (UX-06/07/08)

Presentation-only information round on the second screen the player meets
(after jinyong-hud closed the battle-HUD trio UX-03/04/05): no game-rule
change, no numeric-value change, no art, no frozen-geometry edit.

- **Attribute effects (UX-06)** - the ATTRS description slot (`AttrDescLabel`)
  now lists **all five attribute effects at rest** (name-prefixed; segments
  verbatim from `creation.gd::_ATTR_DESCS` = `design/10_systems.md` §1
  meanings + `design/40_progression.md` §7 formulas - nothing invented;
  `design/20_content.md` §6 records the explicit "no content gap" note).
  The list no longer follows focus: every attribute's meaning is on the page
  while you decide where to spend points.
- **Current HP (UX-07)** - a new additive `HpValueLabel` directly below the
  effects list shows 「当前气血 N」, derived live from the build
  (`hp_value = hp_from_bone(attrs["bone"]) = attrs["bone"] × 5`, the §7
  formula; `hp_text` pins the exact rendered format). Every numeric playtest
  assert is relative to the live `attrs` dict - zero absolute HP literals.
- **Confirm summary (UX-08)** - a new additive `ConfirmSummaryLabel` is
  `ConfirmBox`'s first child (above 「确认踏上江湖」), one 「名 值」 line per
  attribute (`confirm_summary_text`, five lines) - the final-value checklist
  the confirm page was missing. Per-attribute asserts are relative
  (`contains("根骨 " + str(attrs["bone"]))`).
- **One declared measurement change** - the `points_attrs_gap_ok` CONFIRM-phase
  first-row ink cluster re-points from `ConfirmButton`'s rect to
  `ConfirmSummaryLabel`'s rect (same observable, same yaml assert lines,
  `ConfirmButton` fallback retained; the jinyong-layout-r2
  measured-quantity-change precedent, recorded in `design/30_presentation.md`).
- **Regression net** - three new playtest scenarios
  (`creation_attr_effect_info`, `creation_hp_value_displayed`,
  `creation_confirm_summary`; 50 -> 53 scenarios, appended to
  `scenario_order` and the smoke test's `ROUND_SCENARIOS` in the same order)
  plus one new headless unit test `tests/test_creation_info_texts.gd`, which
  pins the pure derivations, the per-phase label wiring, and **every frozen
  creation-geometry constant** so accidental drift reddens the test.
- **Fossil evidence removed** - `final/verify_report.json`, a jinyong-events-era
  verdict the pipeline could never refresh (`repo_apply` ignores `final/*`),
  was replaced by a tombstone pointer note carrying no verdict fields: the
  only authoritative gate evidence is the pipeline step products. The decision
  is recorded in `design/90_decisions.md` (Out of scope) and
  `design/99_changelog.md`.

The previous jinyong-hud round's battle-HUD information layer (UX-03/04/05:
skill-button effect/cost text, lock reasons, HP numbers on a frozen
health-bar geometry, plus the `no_energy` button state) is recorded in
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
and a confirm page listing the final values before you commit) -> tutorial
battle as a fully mastered Yang Guo vs the Five Masters (you are meant to
win) -> transition -> sect choice -> cultivation.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check -> headless playtest of all 53 scenarios -> GDScript unit
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
  `hp_text` / `hp_value` / `hp_max` / `hp_text_width_ok`; `CreationScreen`:
  `phase` / `points_left` / `attr_index` / `attrs` / `trait_ids` plus the
  round-2/3 geometry observables and the new clarity layer `hp_value` /
  `hp_text` / `confirm_summary_text`; the node blocks `AttrDescLabel` /
  `HpValueLabel` / `ConfirmSummaryLabel` expose `visible` + `text`.
- **Creation info derivations** (`scripts/segments/creation.gd`): pure
  `hp_from_bone(bone)` (= bone × 5, `design/40_progression.md` §7),
  `attr_effects_text()` (all five effects, verbatim segments) and
  `confirm_summary_text_from(attrs)` (five 「名 值」 lines), written into the
  two additive labels by `_render()` - display-only, no rule or stored-value
  change.
- **Skill data**: `scripts/data/skill_data.gd` - `@export` schema incl.
  `cost: int` (inner-force cost; 7 of the 8 tutorial player moves carry real
  values 10-30, 重剑无锋 stays 0 = free basic; see `design/20_content.md` §7).
- **Unit tests**: GDScript test files with a top-level
  `static func run() -> bool` are collected by `tests/unit_test_runner.gd`'s
  explicit append-only `TESTS` registry (18 files, incl. the new
  `test_creation_info_texts.gd` and the jinyong-hud trio), run headless via
  `godot --headless --path . -s res://tests/unit_test_runner.gd`.

## Verification status (honest)

The only authoritative gate evidence is the pipeline step products -
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` - pipeline artifacts, not repo files; none is on disk at
the verifier step (the gates run after it). The repo file
`final/verify_report.json` is deliberately NOT a delivery verdict: it is a
tombstone pointer note (`superseded_pointer_note`,
`represents_current_delivery: false`) stating it does not represent the
current delivery state, because the pipeline's `repo_apply` ignores `final/*`
and can never refresh it. In short:

- The three creation information layers (attribute effects, current HP,
  confirm summary) are implemented and pinned by playtest assertions and a
  headless unit test; the frozen creation geometry is untouched (and
  re-pinned by `tests/test_creation_info_texts.gd`); the attribute-effect
  text is verbatim from existing definitions - no content gap
  (`design/20_content.md` §6).
- `design/40_ux_backlog.md` shows UX-06 / UX-07 / UX-08 as **OPEN** with
  「修复已落,post-fix 闸门证据待验」 (fix landed, post-fix gate evidence
  pending). Per backlog rule 2, `CLOSED(jinyong-clarity)` is written only by
  the post-gate evidence task from measured `playtest_summary.md`
  per-scenario counts (`creation_attr_effect_info`,
  `creation_hp_value_displayed`, `creation_confirm_summary`) - an honest
  OPEN beats an evidence-less CLOSED.
- Compile / playtest / unit / vision gates run after the verifier step, so
  this round's measured pass (53/53 scenarios green incl. `spine_to_ending`
  32/32 and the seven existing creation/menu scenarios; 18/18 GDScript unit
  tests; pytest smoke green) is **pending, not claimed**. The last fully
  measured final-tree run (jinyong-hud's rerun: compile 73/73 scripts 0
  errors, playtest 50/50 scenarios green) predates this round; the clarity
  changes are additive by construction (two scene labels, three script
  vars, three scenario files, one unit test), but the authoritative
  confirmation is the fresh downstream gate run - which is why the round
  verdict stays `all_goals_met = false`.
- The vision gate may be blind (`endpoint_unreachable`, same stance as
  jinyong-hud): the three findings are information-presence pins (text
  non-empty / value present) judged by playtest asserts; rendered-ink
  concerns are compensated by the existing measured geometry observables
  (`points_attrs_gap_ok`, `creation_box_fits`, `desc_center_ok`,
  `nav_cluster_center_ok`, ...), not by a vision verdict.

## Repository layout

- `scripts/` - game code (`autoload/`, `characters/`, `data/`, `ui/`,
  `segments/`, `ai/`, `battlefield.gd`)
- `scenes/` - Godot scenes (`ui/`, `segments/`, `main.tscn`)
- `playtest/` - 53 headless playtest scenarios + the `_common.yaml` contract
- `tests/` - GDScript unit suites (18 files) + `test_playtest_contract_smoke.py`
- `design/` - the design archive (`00_overview.md` ... `99_changelog.md`);
  `40_ux_backlog.md` tracks player-eye UX debt, `20_content.md` §5 the
  inner-force cost content gap (§6: attribute effects - no gap)
- `final/` - per-round delivery notes and probe notes; `verify_report.json`
  is a tombstone pointer note, not a verdict
- `assets/` - color-block textures, NotoSansSC font, audio, seed portraits
