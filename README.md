# Huashan Sword Tournament (华山论剑)

A **Godot 4** tactical wuxia RPG — five Grandmasters face Yang Guo on a summit grid, and the duel is actually playable end-to-end. Real-time-with-pause grid combat with skills, per-Grandmaster enemy AI, floating health bars, and a keyboard-completable tutorial.

This build turns the previous art/audio-only demo into a working game: the player can attack from the keyboard, attacks change health, all five Grandmasters move/attack/retreat instead of sitting in `IDLE`, and the battle can be won or lost. It keeps the seeded, deterministic ink-painting art and generated sound from the prior run untouched.

## Quick Start

1. Open the project in **Godot 4.4+**.
2. Run the import/compile pass so Godot produces `.import` sidecars (the harness `--compile` step does this; in the editor it happens automatically on open).
3. Press **F5** (or click *Run Project*).
4. Advance the tutorial with **Enter / Space** (or click *Next*), then fight.

## How to Play

| Action | Input |
|--------|-------|
| Move | WASD / Arrow keys |
| Select skill | 1 / 2 (or click the HUD skill buttons) |
| Basic attack | **J** (left-click an enemy to target the same way) |
| Fire selected skill | **J** — fires at the nearest enemy in range (or left-click a specific target) |
| Advance tutorial | Enter / Space |
| Pause / unpause | Escape |

- Press `J` with no skill selected to perform a basic attack on the **nearest adjacent** enemy.
- Select a skill with `1`/`2`, then press `J` to fire it at the nearest enemy within that skill's range (auto-deselects after use).
- Defeat all five Grandmasters to win; let your health reach zero to lose. Victory/Defeat overlay text ends the battle.
- Health bars float above characters and follow them, clamped so they never clip off the top edge.

## The Five Grandmasters (live AI)

Each enemy is driven by a distinct AI controller (`scripts/ai/*.gd`) that becomes active once the battle starts:

| Grandmaster | Behaviour |
|-------------|-----------|
| West Poison (西毒欧阳锋) | Aggressive rush — never retreats, melee poison strikes |
| North Beggar (北丐洪七公) | High-damage brawler — Dragon Palm line-AoE with knockback |
| East Heretic (东邪黄药师) | Ranged poison specialist — kites at range 2-3, Poison Cloud DoT |
| South Emperor (南帝段智兴) | Balanced melee — self-heals once when low |
| Central Divine (中神通王重阳) | Defensive counter-attacker — stays IDLE until provoked |

## Project Structure

```
jinyong-play/
├── project.godot                 # Engine config, autoload singletons, input map (incl. basic_attack)
├── playtest_spec.yaml            # Headless playtest contract (actions / surface / scenarios)
├── run_tests.sh                  # CLI test runner (compile + headless playtest)
├── resources.md                  # Asset/tool reference notes
├── assets/
│   ├── characters/               # 6 generated character PNGs (true alpha)
│   ├── terrain/                  # 64×64 floor + border tiles
│   ├── backdrop/                 # 1088×832 summit backdrop
│   ├── audio/                    # SFX + music bed WAVs
│   └── seed_manifest.json        # path → seed → frozen prompt (determinism)
├── scenes/
│   ├── main.tscn                 # Entry point: HUD + tutorial overlay
│   ├── battlefield.tscn          # Grid, backdrop, character container
│   ├── player.tscn               # Yang Guo
│   ├── enemy.tscn                # Shared enemy scene (5 characters)
│   └── ui/                       # HUD, health bar, skill button, tutorial overlay
└── scripts/
    ├── battlefield.gd            # Terrain/tilemap build, character + AI wiring, HUD/tutorial hookup
    ├── autoload/
    │   ├── game_manager.gd       # State machine: TUTORIAL → BATTLE → WON | LOST
    │   ├── grid_manager.gd       # Grid coords, occupancy, static AStar2D pathfinding, range/AoE
    │   ├── combat_manager.gd     # Action queue, damage/heal/DoT/knockback, death handling
    │   ├── tutorial_manager.gd   # 7-step keyboard-completable tutorial + input gating
    │   └── audio_manager.gd      # SFX + music playback
    ├── characters/
    │   ├── player.gd             # Input, keyboard/click targeting, skill selection
    │   └── enemy.gd              # AI accumulator, FSM state, per-character visuals
    ├── ai/                       # ai_base + 5 per-Grandmaster controllers
    ├── data/                     # character_data.gd, skill_data.gd
    └── ui/                       # hud.gd, health_bar.gd, skill_button.gd, etc.
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`.

### Input actions (`project.godot` `[input]`)

`move_up`, `move_down`, `move_left`, `move_right`, `skill_1`, `skill_2`, `basic_attack` (physical key `J` = 74), `pause_game` (Escape), plus the built-in `ui_accept` (Enter/Space) for tutorial advancement. Every action the game reads is declared here.

### `CombatManager` public API

| Method | Behaviour |
|--------|-----------|
| `request_action(unit, action, target, params)` | Enqueue an action (`"move"`, `"basic_attack"`, `"skill"`) into the serialized FIFO queue |
| `is_unit_busy(unit) -> bool` | True if the unit is being processed, has a queued action, or is currently moving |
| `apply_damage(target, amount)` | Clamp health ≥ 0, emit `damage_dealt`/`health_changed`, handle death |
| `apply_dot(target, dmg, duration, tick_interval)` | Register a damage-over-time effect |
| `apply_knockback(target, direction, tiles)` | Tile-by-tile knockback respecting bounds/occupancy/walls |
| `apply_heal(target, amount)` | Clamp to `max_health`, emit `health_changed` |
| `pause()` / `unpause()` / `toggle_pause()` | Toggle `Engine.time_scale` with debounce |

Signals: `paused`, `unpaused`, `action_executed`, `damage_dealt`.

### `GridManager` public API

| Method | Behaviour |
|--------|-----------|
| `is_in_bounds(grid_pos)` | Inside the 15×11 grid rect |
| `is_walkable(grid_pos)` | In-bounds **and** not on the border wall ring |
| `is_occupied(grid_pos)` / `reserve_tile` / `free_tile` | Occupancy bookkeeping (does **not** mutate the AStar graph) |
| `find_path(from, to)` | AStar2D path over static geometry (walls disabled once) |
| `get_move_range(origin, points)` | BFS flood-fill respecting walls + occupancy |
| `get_units_in_range(origin, range)` / `get_units_in_aoe(...)` | Target queries (Chebyshev distance) |
| `grid_to_world` / `world_to_grid` | Pixel ↔ tile conversion |

### `GameManager` public API

`get_state()`, `start_battle()`, `end_battle(won)`, `register_enemy`, `unregister_enemy`, `get_enemies_alive()`, `set_player`, `get_player`. State machine: `TUTORIAL → BATTLE → WON | LOST`.

### Playtest surface contract (`playtest_spec.yaml`)

Observable nodes/variables: `HUD`, `Player` (`health`, `max_health`, `grid_pos`, `global_position`, `selected_skill_index`), `HealthBar`, the five per-enemy nodes (`East_Heretic`, `West_Poison`, `South_Emperor`, `North_Beggar`, `Central_Divine` — each exposing `fsm_state`, `health`, `max_health`, `grid_pos`), and `GameManager` (`current_state`).

## Technical Notes

- **Godot version**: targets 4.4 (the brief's pin); `project.godot` `config/features` records `4.7` — pre-existing and unrelated, and the project compiles/runs under the current toolchain.
- **Static AStar graph**: occupancy no longer disables graph points; only the border wall ring is disabled once in `setup_grid()`. Occupancy is re-checked at move time (`_move_toward`, `move_unit`, `_execute_move`, knockback).
- **Queue safety**: `_await_tween_safe()` caps every action-tween await at `TWEEN_TIMEOUT_SEC` (0.6 s) so a tween killed by a node's `queue_free()` can never hang the action queue. The damage-flash tween is bound to `CombatManager` (never freed).
- **Keyboard targeting**: `_pick_nearest_enemy_in_range()` resolves the nearest living enemy deterministically (registration order tie-break) — no facing state.
- **Layout**: the border ring is non-walkable (matching the painted stone walls), health bars are clamped to the viewport, and the viewport is pinned to 1088×832 (the backdrop's native size) — no top-edge clipping.
- **Names**: every HUD/floating/enemy label is data-driven from `CharacterData.character_name`; no label renders the placeholder text `"Name"` or `"Enemy"`.
- **Anchoring**: sprites are feet-anchored at their tile centre via `offset.y = -height/2`.
- **Tweens/async**: `create_tween()` + `await` (Godot 4 API), no `yield`.

## Testing

```bash
./run_tests.sh
```

Runs a compile check (which triggers the Godot import pass) followed by a headless playtest against `playtest_spec.yaml`. The playtest scenarios prove, via differential (`changed`) and terminal assertions, that: an enemy's `fsm_state` leaves `IDLE`, the player's `basic_attack` key damages an enemy, enemy actions damage the player, and a terminal scenario reaches `LOST` (defeat). A passing run requires a clean compile and a playtest that executes frames with no `input_dead` scenarios and zero runtime errors.
