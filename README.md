# Huashan Sword Tournament (华山论剑)

A Godot 4 wuxia RPG tactical battleground — five Grandmasters face off on a summit grid. Turn-based combat with skills, AI opponents, floating health bars, and a tutorial system.

## Quick Start

1. Open the project in **Godot 4.4+**.
2. Press **F5** (or click *Run Project*).
3. Click through the tutorial, then fight!

## How to Play

| Action | Input |
|--------|-------|
| Move | Arrow keys / WASD |
| Select skill | 1 / 2 number keys |
| Confirm / Attack | Space / Enter |
| Pause | Esc |

- Move your character on the grid and use skills to defeat the five Grandmasters.
- Each character has unique skills with cooldowns and area effects.
- Health bars float above characters and follow them on screen.

## Project Structure

```
huashan-sword-tournament/
├── project.godot                 # Engine config, autoload singletons, input map
├── scenes/
│   ├── main.tscn                 # Entry point: HUD + tutorial overlay
│   ├── battlefield.tscn          # Battlefield: grid, backdrop, character container
│   ├── player.tscn               # Player character (Node2D)
│   ├── enemy.tscn                # Enemy character (Node2D)
│   └── ui/
│       ├── hud.tscn              # Heads-up display
│       ├── health_bar.tscn       # Floating health bar
│       ├── skill_button.tscn     # Skill hotkey button
│       └── tutorial_overlay.tscn # Tutorial step overlay
├── scripts/
│   ├── battlefield.gd            # Battlefield initialization and management
│   ├── autoload/
│   │   ├── game_manager.gd       # Game state, turn management, win/loss
│   │   ├── grid_manager.gd       # Grid logic, pathfinding, tile management
│   │   ├── combat_manager.gd     # Damage calculation, skill resolution, animations
│   │   └── tutorial_manager.gd   # Step-by-step tutorial flow
│   ├── characters/
│   │   ├── player.gd             # Player controller, input handling, skill selection
│   │   └── enemy.gd              # Enemy base class with health and death
│   ├── ai/
│   │   ├── ai_base.gd            # Base AI decision framework
│   │   ├── ai_central_divine.gd  # Central Divine AI personality
│   │   ├── ai_east_heretic.gd    # East Heretic AI personality
│   │   ├── ai_north_beggar.gd    # North Beggar AI personality
│   │   ├── ai_south_emperor.gd   # South Emperor AI personality
│   │   └── ai_west_poison.gd     # West Poison AI personality
│   ├── data/
│   │   ├── character_data.gd     # Character stats and definitions
│   │   └── skill_data.gd         # Skill definitions (damage, range, cooldown)
│   └── ui/
│       ├── hud.gd                # HUD: health bars, skill bar, pause
│       ├── health_bar.gd         # Floating health bar that follows characters
│       ├── skill_button.gd       # Skill hotkey button with cooldown overlay
│       ├── pause_button.gd       # Pause/resume button
│       └── tutorial_step.gd      # Single tutorial step overlay
└── run_tests.sh                  # CLI test runner for headless Godot
```

## Technical Notes

- **Godot version**: 4.4.
- **All code uses Godot 4 APIs** — no deprecated Godot 3 methods remain (verified 2025).
- **Autoload singletons**: `GameManager`, `GridManager`, `CombatManager`, `TutorialManager`.
- **Health bar positioning**: Uses `Camera2D.get_canvas_transform()` for world-to-screen conversion (Godot 4 canonical approach).
- **Tween animations**: All use `create_tween()` (Godot 4 Tween API).
- **Async**: Uses `await` (not `yield`).
- **Signals**: Uses `signal.emit()` and `signal.connect(Callable)` (Godot 4 syntax).

## Testing

```bash
./run_tests.sh
```

Runs the project headlessly and checks for errors in Godot's output log.
