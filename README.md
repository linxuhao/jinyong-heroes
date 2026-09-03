# jinyong — Wuxia Crossover Tactics (Godot 4)

**▶ Play it in your browser: https://linxuhao.github.io/jinyong-heroes/**
(中文/English — auto-detected from your browser language, switchable in 设置/Settings)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. You create your own nobody, borrow the
fully mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, join a great sect, spend three in-game
years (36 cultivation periods) training, and finally walk the jianghu map to an
ending. Visuals use placeholder art; UI text is Chinese (NotoSansSC, SIL OFL).

## 本轮变更（R4，2026-09-03）

- **Card 0 (L1) — enemy turns are fast.** Three wall-clock observables (`debug_enemy_turn_msec`, `debug_enemy_round_msec`, `debug_enemy_turn_index`) + `playtest/enemy_turn_wall_clock.yaml` pin a full 5-enemy round ≤ 10 s and a single enemy ≤ 2 s; measured variants 1792/1417/1600 ms round, 659/583/499 ms per enemy. Camera audit proved the follower is a snap (no clip). Web wall-clock ships via console prints — not fabricated in-round.
- **江湖不称名,只称号 — shrimp nicknames on screen.** Display layer only: 杨过→独臂大虾, 五绝→东邪虾/西毒虾/南帝虾/北丐虾/中神通虾; walk-ons coined 侠客→侠客虾 (Wanderer Shrimp), 陪练弟子→陪练虾 (Sparring Shrimp), plus two `_DISPLAY_ALIASES`/`_ORDER_TOKENS` leak fixes for raw `ProgressionHero`/`Sparring Partner`. `character_name`, node names, `turn_order` tokens and the three verbatim gates untouched; exactly two gate literals flipped (`round_one_snapshot_and_turn_order.yaml:41`, `ui_geometry_readability.yaml:42`). Settings screen now shows a build stamp (`版本 R4 · 2026-09-03`).
- **Denylist pin.** `tests/test_display_no_personal_names.py` scans display-layer strings in `scripts/`, `scenes/`, `design/20_content.md` for the six personal names (`.gd` comments stripped, internal keys out of scope); red-first against the pre-rename tree, green after the rename.
- **Enemy-turn feedback (presentation only).** New `CombatLog`, `FloatingNumber`, acting-unit marker; wall-clock Tween fades, no frame-counted waits; three additive surface observables. No damage/AI/turn-order value changed.
- **design/ ledger slimming.** `90_decisions.md` 97,131 → 7,152 B, `40_ux_backlog.md` 109,879 → 17,056 B; superseded/CLOSED content moved verbatim to `design/archive/`; `tests/test_design_ledger_budget.py` enforces the per-file and total (≤ 340 KB excl. append-only changelog) budgets.
- **Roadmap record (record-only).** Owner's six 2026-09-02 playtest items logged verbatim in `design/00_roadmap.md` backlog + the R4→R5→R6 queue; line-3 broken link fixed to `01_process.md`.

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

Flow: main menu → character creation (30-point budget, traits, confirm) → tutorial
battle as Yang Guo vs the Five Masters → overlay → transition → sect choice →
36-month cultivation → the jianghu map → tiered ending → restart. The whole
storyline is playable with pointer/touch alone; keyboard paths sit alongside
(camera follows the acting unit; left-click to move/attack, 结束回合 to end turn).

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check → headless playtest of all scenarios → GDScript unit suite).

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite
```

## Key interfaces

- **GameManager** — scene flow, `get_player()`, `get_enemies_alive()`, end-game overlay.
- **CombatManager** — battle state: `tutorial_battle`, `current_round`, `phase`, `is_player_turn()`.
- **SaveManager** — profile, slots, `rng`, autosave.
- **EventLogic** — pure statics over `EventData.TABLE`: `validate_option`, `apply_option_effects`, `add_practice`.
- **BattleSetup** — `derive_stats`, `build_character`, `readiness()`.
- **ProgressionMath** — `GRADE_POINTS`, `mastery_points`, `work_income`, `readiness_power`.
- **UiOcclusionWatch** — per-frame `violations` / `scan_ok` over the live tree.
- **ThemeManager** — `option_style(focused)`, `OPTION_FONT_FOCUS` / `OPTION_FONT_DIM`.
- **MapBattleData** — `roster_ids(battle_id)`, `position_for(battle_id, name_key)`.
- **Coord** — pure statics `world_to_screen` / `screen_to_world` over the canvas transform.
- **GridManager** — grid / movement planning, `world_to_grid`, `grid_to_world`, `board_rect()`.

