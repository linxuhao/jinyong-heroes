# jinyong — Wuxia Crossover Tactics (Godot 4)

**▶ Play it in your browser: https://linxuhao.github.io/jinyong-heroes/**
(中文/English — auto-detected from your browser language, switchable in 设置/Settings)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. You create your own nobody, borrow the
fully mastered body of 独臂大虾 for a tutorial duel against the Five Master
Shrimp on Mount Hua's summit, then fall from the sky, join a great sect, spend
three in-game years (36 cultivation periods) training, and finally walk the
jianghu map to an ending. Visuals use placeholder art; UI text is Chinese
(NotoSansSC, SIL OFL) with a full English translation.

## 本轮变更（R5，2026-09-04）

- **C1 — 点之前知道后果.** Focused options now show their consequence, composed
  from data: monthly cards (effect fields), travel events (cost/gain, 银两不足
  visible before the click), sect selection (gongfa + three-year teaching),
  year-end sect switch (keeps learned gongfa; next-year grade from the new sect),
  work (exact 10+3×月数 numbers), training goals (what 大成 grants), and point
  cost beside the +/- buttons in creation; map travel labels the node type
  (华山=战斗 · 少林/武当=门派设施 · 事件 · 此去即结局) via a scene-layer
  sibling (`map_travel_hints.gd` — `map.gd` untouched); selecting a skill
  highlights its range tiles before casting.
- **C2 — no more burned month.** With every gongfa mastered, the practice
  screen's 返回行动 returns to ACTION_PICK with month/silver zero delta; the
  three nails were re-derived to pin return + zero delta
  (`softlock_empty_practice_returns` renamed from `…_month_advances`;
  `clicks_only_gongfa_empty_exit`, `gongfa_pick_empty_keyboard_return`; change
  tables in each yaml header, no burned-month assertion kept).
- **C3 — returnable screens, confirmed commits.** A visible 返回 button +
  ui_cancel on attribute/gongfa/card pick, year-end and sect switch (zero
  phase/month/silver delta); EVENT keeps its no-exit ruling (reaffirmed in code,
  pinned by `event_phase_no_exit_reaffirmed`); year-end switch and
  travel-to-ending require a confirming second press; the initial sect join
  stays single-press on every input path (the three verbatim gates pin it for
  the game; safety comes from the on-screen consequence preview and a visible
  返回主菜单 back button); the battle pause button opens a real menu
  (继续 / 返回主菜单, second press to confirm).
- **C4 — character panel on battle & ending.** The roster panel is instanced
  read-only into `hud.tscn` and `ending.tscn` (HUD/panel layer;
  `battlefield.gd` untouched) and closes with zero battle-state diff.
- **Battle feedback.** Floating damage numbers + combat-log lines (attacker →
  target, damage, remaining HP; status-caused 移动 0 explained).
- **Honest status (post-review fix round, 2026-09-04).** The main-round
  integration blockers are fixed on this tree: F1 — the EVENT renderer reads the
  typed `opt.effects` (sidecar re-runs: save_load_roundtrip 14/14,
  consequence_event_option_visible 9/9, event_phase_no_exit_reaffirmed 8/8,
  event_travel_effects 19/19); F4 — the initial sect join is single-press on
  every input path and the three verbatim gates are byte-identical green
  (facility_use_reusable 49/49, map_node_event_shaolin 32/32,
  map_battle_node_huashan 41/41), with the re-derived sect nail
  `sect_join_needs_confirm` 8/8. The post-fix review's blockers are also
  resolved: (a) both static-pin pytest reds cleared — the superseded
  `## Open questions` heading no longer appears in `design/90_decisions.md`
  (renamed; archive byte-untouched) and `tests/test_ending_gate_pins.py` drops
  its two retired-scenario entries behind dated carve-outs; the dead i18n EN
  key `⚠ 再按一次确认拜入「%s」` was removed. (b) The fixed-frame route reds
  are resolved per the 2026-09-04 owner route-retirement ruling (feedback
  round #6): `huashan_winnable_normal_route` and `ending_last_month_choice`
  are retired (yamls + both registry lines deleted); `cultivation_year_end_stay`
  and `sect_switch_same_school_connects` re-anchored with byte-identical assert
  blocks — 8/8 each on staged sidecar runs, regression net green (verbatim
  gates 49/49 · 32/32 · 41/41, RNG lifelines 14/14 · 19/19). Evidence:
  `final/delivery_notes_fix_static_ledger_and_gate_pins.md`,
  `final/delivery_notes_fix_route_timeline_anchors.md`,
  `final/delivery_notes_fix_f1_event_option_effects_read.md`,
  `final/delivery_notes_fix_f4_sect_join_single_press.md`. The official
  post-fix full sweep (expected 118 scenarios, 0 runtime errors — all 27 prior
  errors belonged to the retired huashan route) and the compile/vision/test
  gate reports are produced by the downstream steps (5_compile / 5_vision /
  5_test) and are not claimed here.

## Requirements

- Godot 4.x. No external dependencies, no build step.

## Install

```bash
git clone <this repo> jinyong && cd jinyong
# open project.godot in the Godot 4 editor (import happens automatically)
```

## Run

Open the project in the Godot 4 editor and press Play — the game boots into the
main menu (新的冒险 / 读取存档 / 设置 / 退出). Headless: `godot --path .`

Flow: main menu → character creation (30-point budget, traits, confirm) →
tutorial battle as 独臂大虾 vs the five grandmaster shrimp → overlay →
transition → sect choice (single-press join, consequence preview + 返回主菜单 back) →
36-month cultivation (every pick shows its consequence and can be backed out
of before committing) → the jianghu map (travel hints; the ending node asks
确认) → tiered ending (查看角色 opens the read-only panel) → restart.
The whole storyline is playable with pointer/touch alone; keyboard paths sit
alongside (camera follows the acting unit; left-click to move/attack,
结束回合 to end turn; ui_cancel backs out of uncommitted screens).

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check → headless playtest of all scenarios → GDScript unit suite).

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static pins (denylist, budgets, README contract…)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite
```

Static pins worth knowing: `test_playtest_contract_smoke.py` (scenario registry
sync — every new R5 scenario is registered in both `playtest/_common.yaml` and
`ROUND_SCENARIOS`), `test_display_no_personal_names.py` (no personal name in
any display-layer string), `test_design_ledger_budget.py` (`90_decisions.md`
≤ 25 KB, `40_ux_backlog.md` ≤ 20 KB, `design/*.md` total ≤ 340 KB excl.
append-only changelog), `test_readme_is_a_manual.py` (≤ 200 lines, one
本轮变更 section, round headings verbatim in `docs/ROUNDS.md`). The R5
map-leg occlusion net lives at
`playtest/consequence_screens_occlusion_map.yaml`; the multi-screen general
net `consequence_screens_occlusion.yaml` was retired with the route-type
scenarios per the 2026-09-04 owner ruling (per-screen nails +
`playtest/occlusion_no_button_over_text.yaml` carry the rest).

## Key interfaces

- **GameManager** — scene flow, `get_player()`, `get_enemies_alive()`, end-game overlay.
- **CombatManager** — battle state: `tutorial_battle`, `current_round`, `phase`,
  `is_player_turn()`; enemy-turn wall-clock counters `debug_enemy_turn_msec`,
  `debug_enemy_round_msec`, `debug_enemy_turn_index`; combat-log/floating-number
  feedback hooks.
- **SaveManager** — profile, slots, `rng`, autosave.
- **EventLogic** — pure statics over `EventData.TABLE`: `validate_option`,
  `apply_option_effects`, `add_practice`.
- **BattleSetup** — `derive_stats`, `build_character`, `readiness()`.
- **ProgressionMath** — `GRADE_POINTS`, `mastery_points`, `work_income`,
  `readiness_power`.
- **UiOcclusionWatch** — per-frame `violations` / `scan_ok` over the live tree.
- **ThemeManager** — `option_style(focused)`, `OPTION_FONT_FOCUS` / `OPTION_FONT_DIM`.
- **MapBattleData** — `roster_ids(battle_id)`, `position_for(battle_id, name_key)`.
- **Coord** — pure statics `world_to_screen` / `screen_to_world` over the canvas transform.
- **GridManager** — grid / movement planning, `world_to_grid`, `grid_to_world`,
  `board_rect()`.
- **CultivationScreen** (R5) — `consequence_text`, `consequence_matches_focus`,
  `back_button_visible`, `back_target_phase`, `switch_confirm_armed`;
  `_consequence_text(phase, index)` composes consequence copy from
  CardData/EventData/ProgressionGongfaData/ProgressionMath.
- **SectSelectScreen** (R5) — `consequence_text`, `consequence_matches_focus`,
  `back_button_visible` (single-press join per the F4 ruling: the three
  verbatim gates pin it for the game, preview-before-press + back make it safe;
  the year-end sect switch keeps its two-press confirm).
- **MapTravelHints** (R5, `map.tscn` sibling) — `travel_hint_text`,
  `travel_gate_visible`, `travel_gate_armed`; end-node travel gate with
  确认启程/返回 dialog.
- **Hud** (R5) — `pause_menu_open`, `pause_menu_armed`, `roster_panel_open`;
  hosts the read-only `RosterPanel` instance and `PauseMenu`.
- **RosterPanel** (R5) — `read_only` export (interactive in
  cultivation/map, read-only in hud/ending: equip pool binds zero buttons).
