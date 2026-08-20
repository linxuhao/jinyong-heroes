# Huashan Sword Tournament (华山论剑)

A Godot 4 wuxia RPG tactical battleground — five Grandmasters face off on a summit grid, now rendered with seeded, deterministically generated ink-painting art and sound. Real-time-with-pause grid combat with skills, AI opponents, floating health bars, and a tutorial system.

This build replaces every presentation-layer placeholder (procedural polygon sprites, flat `ColorRect` backdrop, `Image.create()` terrain, and silence) with real generated assets. Combat rules, turn/AI behaviour, node names, script variable names, input mapping, and `playtest_spec.yaml` are unchanged.

## Quick Start

1. Open the project in **Godot 4.4+**.
2. Run the import/compile pass so Godot produces `.import` sidecars for the new PNG/WAV assets (the harness `--compile` step does this; in the editor it happens automatically on open).
3. Press **F5** (or click *Run Project*).
4. Click through the tutorial, then fight!

## How to Play

| Action | Input |
|--------|-------|
| Move | Arrow keys / WASD |
| Select skill | 1 / 2 number keys (or click the HUD skill buttons) |
| Confirm / Attack | Space / Enter (left-click an enemy to target) |
| Pause | Space / Esc |

- Move your character on the grid and use skills to defeat the five Grandmasters.
- Each character has unique skills with cooldowns and area effects.
- Health bars float above characters and follow them on screen.

## Generated Art & Audio

All binary assets are produced by `gen_image_asset` / `gen_audio_asset` from frozen prompts and **unique fixed seeds**, recorded in `assets/seed_manifest.json`. Re-running that manifest with the same seed + prompt + model reproduces the same cast byte-for-byte.

| Type | Assets |
|------|--------|
| Character sprites (transparent=true) | `assets/characters/{yang_guo,east_heretic,west_poison,south_emperor,north_beggar,central_divine}.png` |
| Terrain tiles | `assets/terrain/{floor,border}.png` (64×64, seamless) |
| Summit backdrop | `assets/backdrop/summit.png` (1088×832) |
| Sound effects | `assets/audio/{hit,hurt,move,select,victory}.wav` |
| Music bed | `assets/audio/music.wav` |

All characters share one style block — *"Chinese wuxia ink-painting style, flat colors, clean bold outlines, dramatic lighting"* — with per-character subject blocks so the five Grandmasters stay visually distinguishable.

## Project Structure

```
jinyong-assets/
├── project.godot                 # Engine config, autoload singletons, input map
├── playtest_spec.yaml            # Playtest assertions (UNCHANGED)
├── run_tests.sh                  # CLI test runner for headless Godot
├── assets/
│   ├── characters/               # 6 generated character PNGs (true alpha)
│   ├── terrain/                  # 2 generated 64×64 tile PNGs
│   ├── backdrop/                 # 1 generated summit PNG
│   ├── audio/                    # 5 SFX WAVs + 1 music bed WAV
│   └── seed_manifest.json        # path → seed → frozen prompt (determinism)
├── scenes/
│   ├── main.tscn                 # Entry point: HUD + tutorial overlay
│   ├── battlefield.tscn          # Battlefield: grid, backdrop, character container
│   ├── player.tscn               # Player character (Sprite2D + ext_resource)
│   ├── enemy.tscn                # Enemy character (Sprite2D, texture set at runtime)
│   └── ui/
│       ├── hud.tscn              # Heads-up display
│       ├── health_bar.tscn       # Floating health bar
│       ├── skill_button.tscn     # Skill hotkey button
│       └── tutorial_overlay.tscn # Tutorial step overlay
└── scripts/
    ├── battlefield.gd            # Battlefield init, terrain loads, backdrop, character wiring
    ├── autoload/
    │   ├── game_manager.gd       # Game state, win/loss
    │   ├── grid_manager.gd       # Grid logic, pathfinding, tile management
    │   ├── combat_manager.gd     # Damage/skill resolution, flash, hit/move SFX hooks
    │   ├── tutorial_manager.gd   # Step-by-step tutorial flow
    │   └── audio_manager.gd      # Audio playback owner (NEW)
    ├── characters/
    │   ├── player.gd             # Player controller, input, skill selection, select SFX
    │   └── enemy.gd              # Enemy base + per-character texture map
    ├── ai/                       # Per-Grandmaster AI controllers
    ├── data/
    │   ├── character_data.gd     # Character stats and definitions
    │   └── skill_data.gd         # Skill definitions
    └── ui/                       # HUD, health bar, skill button, tutorial
```

## Key Interfaces

### Autoload singletons (`project.godot` `[autoload]`)

`GameManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`.

### `AudioManager` public API (callable from any script)

| Method | Behaviour |
|--------|-----------|
| `play_hit()` | Plays the hit SFX (wired to skill + basic-attack execution). |
| `play_hurt()` | Plays the hurt SFX, throttled to ≥150 ms (guards DoT-tick spam). |
| `play_move()` | Plays the move SFX (wired to player + AI movement). |
| `play_select()` | Plays the select SFX (shared by HUD buttons and 1/2 keys). |
| `play_victory()` | Stops music and plays the victory jingle. |
| `play_music()` | Starts the music bed if not already playing. |
| `stop_music()` | Stops the music bed. |

It preloads the six WAVs, runs SFX on a player with `max_polyphony = 8`, keeps the music bed ~10 dB under SFX, and restarts the bed on `finished` (no authored loop point — a small seam gap is intentional).

### Scene resource references

- `scenes/player.tscn` references `assets/characters/yang_guo.png` via `ext_resource`.
- `scenes/battlefield.tscn` references `assets/backdrop/summit.png` via `ext_resource`.
- Enemy textures are assigned at runtime in `enemy.gd`'s `TEXTURE_PATHS` map (one shared scene, five characters).
- Terrain textures are `load()`ed at runtime in `battlefield.gd` (the TileSet is code-built).

## Technical Notes

- **Godot version**: 4.4.
- **Filtering**: characters/backdrop use per-node Linear filtering (`texture_filter = 2`); the terrain atlas stays Nearest to avoid tile-edge bleeding; the global `default_texture_filter` is unchanged.
- **Anchoring**: sprites are feet-anchored at their tile centre via `centered = true` + `offset.y = -height/2`.
- **Autoload singletons**: `GameManager`, `GridManager`, `CombatManager`, `TutorialManager`, `AudioManager`.
- **Health bar positioning**: uses `Camera2D.get_canvas_transform()` for world-to-screen conversion (Godot 4 canonical approach).
- **Tween animations**: all use `create_tween()` (Godot 4 Tween API).
- **Async**: uses `await` (not `yield`).
- **Signals**: uses `signal.emit()` and `signal.connect(Callable)` (Godot 4 syntax).
- **Determinism**: every asset has a unique fixed seed in `assets/seed_manifest.json`.

## Testing

```bash
./run_tests.sh
```

Runs a compile check (which triggers the Godot import pass for the new PNG/WAV assets) then a headless 5-second playtest against `playtest_spec.yaml`, checking for parse and runtime errors.
