# Huashan Sword Tournament (华山论剑)

A **Godot 4** tactical wuxia RPG — five Grandmasters face Yang Guo on a summit grid, and the duel is playable end-to-end. **Turn-based grid combat** with per-round initiative order, a move + one action turn structure, per-Grandmaster deterministic AI, round-based cooldowns and damage-over-time, floating health bars, a round/actor HUD, and a keyboard-completable tutorial.

This build replaces the previous real-time-with-pause combat with a **strictly sequential turn engine**: every surviving unit acts exactly once per round in initiative order (highest 身法 first), each turn is a movement budget plus one action (basic attack / technique / wait), cooldowns and DoT tick by round at the unit's own turn start, and enemy AI decides exactly once per enemy turn (zero RNG).

## Quick Start

1. Open the project in **Godot 4.4+**.
2. Run the import/compile pass so Godot produces `.import` sidecars (the harness `--compile` step does this; in the editor it happens automatically on open).
3. Press **F5** (or click *Run Project*).
4. Advance the tutorial with **Enter / Space** (or click *Next*), then fight.

## How to Play

| Action | Input |
|--------|-------|
| Move (one tile per press, 4-tile budget) | WASD / Arrow keys |
| Select technique | **1–8** (or click the HUD skill buttons) |
| Execute selected technique / basic attack | **J** (left-click an enemy to target the same way) |
| End turn | **Space** |
| Advance tutorial | Enter / Space |
| Pause / unpause | Escape |

- Every turn = move up to your movement range **plus** one action, in any order. Space ends the turn at any point (with or without remaining budget).
- Press `J` with no skill selected to perform a basic attack on the **nearest adjacent** enemy.
- Select a skill with `1`–`8`, then press `J` to fire it at the nearest valid target (auto-deselects after use).
- **Two-phase unlock**: techniques `5`–`8` (Melancholy Palms) are locked until **round 4**; technique `8` (Seventeen Melancholy Forms) additionally requires HP **below 50%**.
- Each unit acts once per round in initiative order: Yang Guo (88) → East Heretic (85) → Central Divine (80) → South Emperor (76) → North Beggar (74) → West Poison (70).
- Defeat all five Grandmasters to win; let your health reach zero to lose.

## The Five Grandmasters (deterministic AI)

Each enemy is driven by a distinct AI controller (`scripts/ai/*.gd`) that decides **once per enemy turn** via a deterministic priority list over cooldown/range/HP facts — no timers, no RNG:

| Grandmaster | Behaviour |
|-------------|-----------|
| West Poison (西毒欧阳锋) | Melee poison strikes, Toad Squat charge, line-AoE knockback; reflects melee damage (蛤蟆反震) |
| North Beggar (北丐洪七公) | High-damage Dragon Palm brawler with line/AoE knockback + Dog-Beating Staff at range 2; −15% all damage taken (丐帮铁骨) |
| East Heretic (东邪黄药师) | Ranged specialist — Falling Petals, technique/movement seals, Peach Blossom Maze zones, global initiative debuff; counters attacks from ≤3 tiles (弹指神通) |
| South Emperor (南帝段智兴) | Balanced ranged — Solar Finger ignores DR, heals self/ally (先天调息), regenerates each round and heals once below 40% (一阳续命) |
| Central Divine (中神通王重阳) | Defensive sword + shield (罡气护体), global dispel; survives the first fatal blow at 1 HP (先天罡气) |

## Turn System

- **Round snapshot**: at round start, all living units are sorted by effective initiative (身法, minus 20 while a 碧海潮生 debuff is active) descending, ties broken by registration order (player first, then East → West → South → North → Central). Godot's `sort_custom` is unstable, so the engine uses a decorate-sort-undecorate insertion sort for determinism.
- **Turn-start lifecycle** (exact order): cooldown decrement (int rounds) → DoT/status ticks → constant regen (神雕之力 +26, 一阳续命 +13) → the unit acts.
- **Damage pipeline**: attack side `round(base × buffs × fa_hui_du)` → defense side `round(output × (1 − DR))`. 发挥度 (1.3 in the tutorial) applies to damage / heal / shield / DoT-tick values only — never cooldown, range, knockback, or duration.
- **Melee vs ranged** (design/10_systems.md §2.2): decided by the declaring external art's **weapon class** (刀/剑/长兵/拳掌/轻功/横练 = melee; 指/暗器/奇门毒/乐器 = ranged) — never by shape, reach, or damage. Basic attacks classify by the character's primary external art (主修外功).
- **Pause** is a boolean gate (no `Engine.time_scale`); the turn flow is event-driven and simply halts at unit boundaries while paused.

## 功法 (Gongfa) Data Structure

`scripts/data/gongfa_data.gd` models internal/external martial arts. Internal arts produce the energy pool (内力 180 for Yang Guo) and a passive id; external arts produce technique lists. Every art exposes `get_fa_hui_du()` which returns **1.3** — an interface-only stub (the 甲乙丙丁 prerequisite cascade is deliberately not implemented this run).

## HUD

- **Grid overlay** (`GridLines`, a `Node2D` child of `scenes/battlefield.tscn` drawn above the floor tiles / backdrop): 1 px semi-transparent cell-boundary lines across the 15×11 board plus a slightly stronger border ring, so the grid reads over the summit painting. Exposed as the `Battlefield.grid_lines_visible` observable.
- **Skill bar** (8 buttons, `SkillButton1..8`): technique name, hotkey, a 发挥度 rating label (`ERRATIC` / `NORMAL` / `OVERDRIVE` + multiplier — all tutorial arts show `OVERDRIVE x1.3`), and a round-based cooldown overlay with a **remaining-rounds number** (`CooldownLabel`) plus a **state tag** (`LOCKED` / `HP`). Each button exposes `state_text` — one of `"ready"`, `"cooldown"`, `"phase_locked"`, `"hp_gated"` — and `cooldown_remaining`, and renders five pairwise-distinct visuals: ready (normal), cooldown (dark fill + number), phase-locked (gray tint + `LOCKED` tag), HP-gated (red tint + `HP` tag), and selected (golden border when `player.selected_skill_index == skill_index`). Button text is shortened to fit without truncation (`17 Forms` instead of `Seventeen Melancholy Forms`).
- **Health bars** (one per character, `HealthBar`): a **64 px wide** bar (one grid cell; `HealthBar.bar_width`) with the **name label above** the bar (never overlapping, font 10, no clipping/ellipsis), fill color green→yellow→red by HP fraction. Bars follow their character via the stretch-aware `get_final_transform()` projection with edge clamping; `HealthBar.follow_delta` reports the pre-clamp pixel distance from the character's projected screen position.
- **Round indicator** (top-center): `Round N`, `Active: <name> · Move <m> · Act ✓/End`, and `Order: <short aliases>` in a compact no-ellipsis format inside its box. The indicator rect never overlaps `PauseButton` (guarded by the `HUD.round_pause_overlap` observable).
- **Energy label**: `Qi: 180` (display only — no technique costs this run).
- All new HUD text is English + digits only.

### Health-bar display aliases

Health-bar name labels use short English aliases (no ellipsis — design/30_presentation.md explicitly allows shorter names). Display-only: `character_data.character_name`, node names, turn-order names and `order_names` stay canonical and unchanged (playtest asserts on the canonical names stay green).

| Canonical name | Health-bar alias |
|----------------|------------------|
| Yang Guo | Yang Guo |
| East Heretic | E. Heretic |
| West Poison | W. Poison |
| South Emperor | S. Emperor |
| North Beggar | N. Beggar |
| Central Divine | C. Divine |

## Project Structure

```
jinyong-play/
├── project.godot                 # Engine config, autoload singletons, input map, display/stretch
├── playtest_spec.yaml            # Headless playtest contract (actions / surface / 10 scenarios)
├── run_tests.sh                  # CLI test runner (compile + headless playtest)
├── resources.md                  # Asset/tool reference notes
├── assets/
│   ├── characters/               # 6 generated character PNGs (true alpha)
│   ├── terrain/                  # 64×64 floor + border tiles
│   ├── backdrop/                 # summit backdrop (fitted to the board at runtime)
│   ├── audio/                    # SFX + music bed WAVs
│   └── seed_manifest.json        # path → seed → frozen prompt (determinism)
├── scenes/
│   ├── main.tscn                 # Entry point: HUD + tutorial overlay (CanvasLayers)
│   ├── battlefield.tscn          # Grid, GridLines overlay, backdrop, character container
│   ├── player.tscn               # Yang Guo
│   ├── enemy.tscn                # Shared enemy scene (5 characters)
│   └── ui/                       # HUD, health bar, skill button, tutorial overlay
└── scripts/
    ├── battlefield.gd            # Terrain/tilemap build, character + skill data, AI wiring, HUD/tutorial hookup
    ├── grid_lines.gd             # Cell-boundary overlay drawn above tiles/backdrop (_draw)
    ├── autoload/
    │   ├── game_manager.gd       # State machine: TUTORIAL → BATTLE → WON | LOST
    │   ├── grid_manager.gd       # Grid coords, occupancy, AStar2D, range/AoE (origin/size/team), sprite clamp
    │   ├── combat_manager.gd     # Turn engine + damage/status/passive pipeline + death handling
    │   ├── tutorial_manager.gd   # 7-step keyboard-completable tutorial + input gating
    │   └── audio_manager.gd      # SFX + music playback
    ├── characters/
    │   ├── player.gd             # Turn budgets, 1-8 input, J, Space, gates, targeting, sprite clamp
    │   └── enemy.gd              # Turn state, per-character visuals, sprite clamp
    ├── ai/                       # ai_base + 5 per-Grandmaster deterministic controllers
    ├── data/                     # character_data.gd, skill_data.gd, gongfa_data.gd
    └── ui/                       # hud.gd, health_bar.gd, skill_button.gd, round_indicator.gd, etc.
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`.

### Input actions (`project.godot` `[input]`)

`move_up`, `move_down`, `move_left`, `move_right`, `skill_1`..`skill_8` (digits 1–8), `basic_attack` (J), `end_turn` (Space), `pause_game` (Escape), `tutorial_next` (Enter), plus the built-in `ui_accept`.

### `CombatManager` public API

| Member | Behaviour |
|--------|-----------|
| `current_round` / `phase` / `active_unit_name` / `turn_order` / `turn_log` / `last_turn_actor` | Observable turn-engine state (assertable surface) |
| `is_player_turn()` | True while the player's turn is active |
| `end_current_turn()` | End the active unit's turn (Space for the player; engine for enemies) |
| `begin_turn(unit)` | Turn-start lifecycle: cooldown → DoT/status → regen |
| `execute_move_path(unit, path)` / `execute_action(unit, action, target, params)` | Execute movement / `"basic_attack"` / `"skill"` with tween-awaited animation |
| `apply_damage(target, amount, source, is_melee, ignore_dr)` | Two-stage damage pipeline + fatal guard + counter/reflect |
| `apply_heal` / `apply_shield` / `apply_dot` / `apply_status` | Heal / shield / DoT / status application |
| `get_fa_hui_du(gongfa)` | Delegates to the `GongfaData` stub (1.3) |
| `pause()` / `unpause()` / `toggle_pause()` | Boolean pause gate (no `Engine.time_scale`) |

Signals: `round_started`, `turn_started`, `turn_ended`, `phase_changed`, `action_executed`, `damage_dealt`, `paused`, `unpaused`.

### `GridManager` public API

`is_in_bounds`, `is_walkable`, `is_occupied` / `reserve_tile` / `free_tile`, `find_path`, `get_move_range`, `get_units_in_range`, `get_tiles_in_aoe`, `get_units_in_aoe` (origin / shape / size / direction / team filter), `grid_to_world` / `world_to_grid`, `clamp_sprite_offset`.

### `GameManager` public API

`get_state()`, `start_battle()`, `end_battle(won)`, `register_enemy`, `unregister_enemy` (auto-win on empty list), `get_enemies_alive()`, `set_player`, `get_player`.

### Playtest surface contract (`playtest_spec.yaml`)

Observable nodes/variables include `CombatManager` (`current_round`, `phase`, `active_unit_name`, `turn_order`, `turn_log`, `last_turn_actor`, plus the debug counters `debug_await_total`, `debug_await_timeouts`, `debug_await_frames`, `debug_round_frame`, `debug_reflect_hits`), per-unit `health`/`grid_pos`/`turns_taken`/`acted`/`skill_cooldowns`/`shield`/`status_names`, the 8 `SkillButton*` nodes (`text`, `fahui_text`, `disabled`, `hp_gated`, `state_text`, `cooldown_remaining`), `RoundIndicator`, `EnergyLabel`, `HUD` (`visible`, `size`, `skill8_right_edge`, `round_pause_overlap`), `HealthBar` (`visible`, `global_position`, `size`, `name_text`, `bar_width`, `follow_delta`), and `Battlefield` (`board_aligned`, `grid_lines_visible`). All geometric questions in the spec are answered by these GDScript-computed live-node observables — never raw `get_global_rect()` expressions in YAML.

## Technical Notes

- **Godot version**: targets 4.4 (the brief's pin); `project.godot` `config/features` records `4.7` — pre-existing and unrelated, and the project compiles/runs under the current toolchain.
- **Stable initiative sort**: decorate-sort-undecorate with a registration-index tie-break (Godot's `sort_custom` is unstable, and 碧海潮生's −20 debuff can create ties mid-battle).
- **Freed-object safety**: `queue_free()` is deferred, so any stored node reference (turn-order queue heads, occupancy-dict values, cached AI heal targets) is validated with `is_instance_valid()` **before** any `as` cast or typed assignment — the check-then-cast idiom is applied repo-wide (turn engine, grid queries, AI controllers, and UI scripts).
- **Tween safety**: `_await_tween_safe()` caps every action tween at `TWEEN_TIMEOUT_SEC` (0.25 s) so a tween killed by `queue_free()` can never hang the turn loop; `CombatManager.debug_await_total / debug_await_timeouts / debug_await_frames / debug_round_frame` expose the round-frame budget for re-timing the playtest timeline.
- **Deterministic AI**: zero RNG — pure priority lists over cooldown/range/HP facts; the terminal playtest scenario is reproducible by construction.
- **Rounding**: GDScript `round()` rounds half away from zero; `45 * 1.3` is exactly 58.5 in double → canonical 59.
- **Static AStar graph**: only the border wall ring is disabled once; occupancy is re-checked at move time.
- **Layout**: border ring is non-walkable; the skill bar sits over the bottom border row; the `GridLines` overlay draws cell boundaries above the backdrop/tiles; health bars (≤ 64 px wide, one cell) are clamped to the viewport with their name label above the bar.
- **Tweens/async**: `create_tween()` + `await` (Godot 4 API), no `yield`.

## Testing

```bash
./run_tests.sh
```

Runs a compile check (which triggers the Godot import pass) followed by a headless playtest against `playtest_spec.yaml`. Ten scenarios cover: round-one snapshot + initiative order, enemy-acts-only-after-player-ends-turn, each-unit-acts-once-per-round, cooldown-by-round, DoT-at-victim-turn-start, the 1.3× damage multiplier, the two-phase unlock + HP gate, 先天罡气 fatal guard, a terminal victory within 8–12 rounds with player HP between 15% and 40% (**75–200 of 500**), and the `ui_geometry_readability` scenario (grid overlay visible, health bar ≤ 64 px and tracking a scripted move, 8th skill button inside the viewport, round indicator vs pause button non-overlap, four skill-button states data-distinct).

A passing run requires a clean compile and a playtest that executes frames with no `input_dead` scenarios, zero runtime errors (including no `Trying to cast a freed object`), and every assertion green.

> **Verification status: RED — 5_vision gate not re-run (no vision_report.json found in workspace).** The external 5_vision readability gate was not re-run after the visual-fix tasks landed, and no `playtest_report.json` is present in the workspace to back the prior checks — so no shipped / all_goals_met / ready_for_deploy claim is made. The final gate record (`final/verify_report.json`) is unverified pending a fresh gate re-run staged by the pipeline. To re-run the whole gate after any change:

```bash
./run_tests.sh
```

Re-run instructions: `run_tests.sh` compiles/imports the project headlessly, runs the full playtest against `playtest_spec.yaml`, and writes `playtest_report.json` (pass/fail + per-scenario asserts + any runtime errors). Expect it to finish green; if a scenario fails, the report lists the exact assertion and frame. After tuning AI decision tables (`scripts/ai/*.gd`) or the scene button timeline (`playtest_spec.yaml`), re-run and confirm: (a) `playtest_report.json` shows no `Trying to cast a freed object` errors, (b) the terminal scenario reports `WON` / round in `[8,12]` / HP in `[75,200]`, (c) the six protected scenarios stay green, and (d) `ui_geometry_readability` is green.
