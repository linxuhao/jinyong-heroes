# Huashan Sword Tournament (华山论剑)

A **Godot 4** tactical wuxia RPG — five Grandmasters face Yang Guo on a summit grid, and the duel is playable end-to-end. Real-time-with-pause grid combat with skills, per-Grandmaster enemy AI, floating health bars, and a keyboard-completable tutorial.

This build turns the previous art/audio-only demo into a working game **and fixes the entire presentation layer**: the game opens at the board's native size and fills/scales with its window, the battle HUD (skill bar + cooldowns + pause) is visible on top of the battlefield, each fighter shows exactly one non-overlapping name label, top-row sprites stay inside the illustrated battlefield, and the grid aligns with the artwork.

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

## Presentation Layer (this run)

- **Window fills & scales**: `project.godot [display]` pins the base viewport to **960×704** (exactly the 15×11 × 64 px board, the backdrop and the camera view) with `window/stretch/mode="canvas_items"` + `window/stretch/aspect="keep"` + `resizable=true`. The grey margin is removed outright; on resize the board scales to fill the window and letterboxes with engine-black bars outside the design rect (board aspect preserved, crisp vector HUD text).
- **Visible battle HUD**: the HUD lives on a single `HUDLayer` CanvasLayer (layer 10, `follow_viewport_enabled=false`), so it always draws above the world canvas regardless of sprite `z_index`. The `SkillBar` is re-anchored bottom-center inside the viewport; the `PauseButton` sits top-right.
- **One label per fighter**: the duplicate floating name labels were removed. The single surviving label lives **inside** each health-bar rect (64 px wide = one tile, font 12, `clip_text` + ellipsis) so adjacent fighters can never overlap by construction.
- **No top-row poke**: every character sprite is clamped per frame (feet-anchor preserved whenever possible) so its whole texture rect stays inside the 960×704 artwork rect.
- **Grid/artwork aligned**: `SummitBackdrop` is fitted to the board rect at runtime (`_fit_backdrop_to_board()`), so artwork, tile grid and viewport coincide regardless of the PNG's native size.

## Project Structure

```
jinyong-play/
├── project.godot                 # Engine config, autoload singletons, input map, display/stretch
├── playtest_spec.yaml            # Headless playtest contract (actions / surface / scenarios)
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
│   ├── battlefield.tscn          # Grid, backdrop, character container
│   ├── player.tscn               # Yang Guo
│   ├── enemy.tscn                # Shared enemy scene (5 characters)
│   └── ui/                       # HUD, health bar, skill button, tutorial overlay
└── scripts/
    ├── battlefield.gd            # Terrain/tilemap build, character + AI wiring, HUD/tutorial hookup, backdrop fit
    ├── autoload/
    │   ├── game_manager.gd       # State machine: TUTORIAL → BATTLE → WON | LOST
    │   ├── grid_manager.gd       # Grid coords, occupancy, AStar2D pathfinding, range/AoE, sprite clamp
    │   ├── combat_manager.gd     # Action queue, damage/heal/DoT/knockback, death handling
    │   ├── tutorial_manager.gd   # 7-step keyboard-completable tutorial + input gating
    │   └── audio_manager.gd      # SFX + music playback
    ├── characters/
    │   ├── player.gd             # Input, keyboard/click targeting, skill selection, sprite clamp
    │   └── enemy.gd              # AI accumulator, FSM state, per-character visuals, sprite clamp
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
| `clamp_sprite_offset(position, tex_size)` | (static) feet-anchor sprite offset clamped inside the board artwork rect |

### `GameManager` public API

`get_state()`, `start_battle()`, `end_battle(won)`, `register_enemy`, `unregister_enemy`, `get_enemies_alive()`, `set_player`, `get_player`. State machine: `TUTORIAL → BATTLE → WON | LOST`.

### Playtest surface contract (`playtest_spec.yaml`)

Observable nodes/variables (additive to the original surface):

- `HUD` (`visible`, `size`) — the full-rect Control under `HUDLayer`.
- `Player` (`health`, `max_health`, `grid_pos`, `global_position`, `selected_skill_index`, `sprite_top`).
- `HealthBar` (`visible`, `global_position`, `size`, `name_text`) — the player's bar.
- `East_Heretic`, `West_Poison`, `South_Emperor`, `North_Beggar`, `Central_Divine` (each exposing `fsm_state`, `health`, `max_health`, `grid_pos`; `sprite_top` on `East_Heretic`/`Central_Divine`).
- `SkillBar` (`visible`, `size`, `global_position`), `SkillButton1` (`visible`, `text`), `PauseButton` (`visible`, `global_position`).
- `GameManager` (`current_state`), `Battlefield` (`board_aligned`).

## Technical Notes

- **Godot version**: targets 4.4 (the brief's pin); `project.godot` `config/features` records `4.7` — pre-existing and unrelated, and the project compiles/runs under the current toolchain.
- **Display/stretch**: base viewport is 960×704 with `canvas_items` + `keep`. At the default window the stretch scale is exactly 1, so the composition is identical to a no-stretch 960×704 setup (all prior assertion values hold); on resize the board scales to fill and letterboxes with engine bars.
- **World→screen conversion**: health bars use `get_viewport().get_final_transform()` (global/stretch × canvas/camera) so they stay glued to their characters at any window size — numerically identical to the old camera transform at scale 1.
- **Static AStar graph**: occupancy no longer disables graph points; only the border wall ring is disabled once in `setup_grid()`. Occupancy is re-checked at move time.
- **Queue safety**: `_await_tween_safe()` caps every action-tween await at `TWEEN_TIMEOUT_SEC` (0.6 s) so a tween killed by a node's `queue_free()` can never hang the action queue.
- **Keyboard targeting**: `_pick_nearest_enemy_in_range()` resolves the nearest living enemy deterministically (registration order tie-break) — no facing state.
- **Layout**: the border ring is non-walkable (matching the painted stone walls); the skill bar sits over the bottom border row (non-walkable, never covers a fighter); health bars are clamped to the viewport with their label inside the bar rect.
- **Names**: exactly one name label per fighter (inside the health bar), data-driven from `CharacterData.character_name`; no label renders the placeholder text `"Name"` or `"Enemy"` after `setup()`.
- **Sprite anchoring**: sprites are feet-anchored at their tile centre via `offset.y = -height/2`, then per-frame clamped so the whole texture stays inside the artwork rect.
- **Tweens/async**: `create_tween()` + `await` (Godot 4 API), no `yield`.

## Testing

```bash
./run_tests.sh
```

Runs a compile check (which triggers the Godot import pass) followed by a headless playtest against `playtest_spec.yaml`. The six original scenarios prove gameplay (enemy `fsm_state` leaves `IDLE`, `basic_attack` damages an enemy, enemy actions damage the player, a terminal scenario reaches `LOST`). Three new scenarios are the presentation-layer regression net:

- `hud_layout_visible_during_battle` — asserts `HUD.size == Vector2(960, 704)`, and that `SkillBar`, `SkillButton1` (text `"Sorrowful Palms"`) and `PauseButton` are visible and laid out inside the viewport during `BATTLE`.
- `health_bars_show_real_names_single_label` — asserts `HealthBar.name_text == "Yang Guo"` and `HealthBar.size.y >= 40` (the label lives inside the bar rect).
- `top_row_sprites_inside_artwork_grid_aligned` — asserts `Central_Divine.sprite_top >= 0`, `East_Heretic.sprite_top >= 0`, `Player.sprite_top >= 0` and `Battlefield.board_aligned == true`.

A passing run requires a clean compile and a playtest that executes frames with no `input_dead` scenarios, zero runtime errors, and every assertion green.
