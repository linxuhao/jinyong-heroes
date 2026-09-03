# jinyong — Wuxia Crossover Tactics (Godot 4)

**▶ Play it in your browser: https://linxuhao.github.io/jinyong-heroes/**
(中文/English — auto-detected from your browser language, switchable in 设置/Settings)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. You create your own nobody, borrow the
fully mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, join a great sect, spend three in-game
years (36 cultivation periods) training, and finally walk the jianghu map to an
ending. Visuals use placeholder art; UI text is Chinese (NotoSansSC, SIL OFL).

## 本轮变更（R3b，2026-09-02）

- **C1 — one grade vocabulary** (`progression_math.gd`): `GRADE_POINTS` derives its keys from `PRACTICE_TO_MASTER` (D/C/B/A), so mastery is non-zero on real saves.
- **C2 — practice hits what you picked** (`event_logic.gd::add_practice`): the chosen art's row advances; the receipt shows its display name, not the raw id.
- **C3 — endings actually tier** (`map_data.gd::ENDING_TIERS` 150/120/0): free-card silver no longer inflates the 历练 axis; do-nothing → 1, single → 2, strong → 3.
- **C4 — Huashan readiness tells the truth** (`HUASHAN_BAR` {even: 61, strong: 124}): every creation-fresh profile reads 战备不足 by construction.
- **C5 — winnable-route card matches its title** (`huashan_winnable_normal_route`): clicks-only, real skill clicks. Honest status: unlock granted, levers landed, WON overlay not reached — recorded LOST per the 2026-09-03 owner re-scope, not a measured WIN.
- **C6 — the receipt is on the screen** (`cultivation.gd::_render`): `last_yield_text` drawn under the status block with display names, UiOcclusionWatch-clean.
- **C7 — work out-earns idling** (`ProgressionMath.work_income = 10 + 3 × work_months`): the free card is untouched; 36×work silver > 1.5× 36×do-nothing.
- **C8 — design records**: `40_progression.md` M2'/M3' tables, `90_decisions.md` two rulings, `00_roadmap.md` re-queued, `99_changelog.md` append-only R3b row.

**Status (honest):** last official run (pre-iteration-4 tree) — hard gate green, 91/93 scenarios, pytest 67/67, vision passed. Iteration-4 (2026-09-03): the trait pin was re-derived as a differential (22/22 sidecar), the C5 tail was re-anchored to the honest measured LOST state per the 2026-09-03 owner re-scope (the WIN goal moves to the next round with its 36/48 baseline), README was manualized (1727 → 72 lines; round history lives in docs/ROUNDS.md). Zero game code changed since the 91/93 run; the 93-scenario official re-run of this tree is the remaining gate.

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

