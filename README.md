# Huashan Sword Tournament (华山论剑)

A Godot 4.4 real-time-with-pause grid-based wuxia RPG combat demo. The player controls Yang Guo (杨过) at the iconic Huashan Sword Tournament, wielding signature martial arts skills to defeat all Five Greats (五绝) across a single battle scene.

---

## Requirements

- **Godot 4.4+** (download from [godotengine.org](https://godotengine.org/download))
- No additional dependencies or plugins required

---

## How to Play

1. Download and install Godot 4.4 or newer.
2. Open this project folder in Godot.
3. Press **F5** (Play) with `scenes/main.tscn` set as the main scene.
4. The game loads directly into the Huashan summit battlefield with the tutorial overlay active.

No manual scene setup, configuration, or asset import is needed.

---

## Controls

| Input | Action |
|-------|--------|
| **W / ↑** | Move Yang Guo 1 tile up |
| **S / ↓** | Move Yang Guo 1 tile down |
| **A / ←** | Move Yang Guo 1 tile left |
| **D / →** | Move Yang Guo 1 tile right |
| **1** | Select skill 1 — Sorrowful Palms (黯然销魂掌) |
| **2** | Select skill 2 — Heavy Iron Sword (玄铁剑法) |
| **Left-click** on an adjacent enemy | Execute basic attack or selected skill |
| **Space / Escape** | Toggle pause in battle; also advances tutorial steps |
| **Enter** | Advances tutorial steps |

**Tutorial**: When the tutorial overlay is active, pressing **Space** or **Enter** advances to the next step. A "Skip Tutorial" button is also available.

**Combat**: During battle, **Space** toggles the real-time-with-pause (RTWP) mechanic. While paused, you can survey the battlefield, select skills, and plan moves. Actions queue and execute when unpaused.

---

## Placeholder Art

All visuals in this prototype are procedurally generated at runtime using Godot built-in primitives. No binary art assets are used. To replace placeholders with real art, modify the following:

| Placeholder | Location | Replacement |
|-------------|----------|-------------|
| **Player sprite** (blue circle) | `scenes/player.tscn` — `Polygon2D` node | Replace `Polygon2D` with `Sprite2D` + Yang Guo character texture |
| **Enemy sprites** (colored diamonds) | `scenes/enemy.tscn` — `Polygon2D` node | Replace `Polygon2D` with `Sprite2D` + per-character texture; colors set via `CharacterData.color` |
| **Grid floor tiles** (green) | `scripts/battlefield.gd` — `_create_tile_textures()` function | Replace procedural `Image.create()` + `ImageTexture` with imported tile sheet textures |
| **Grid border tiles** (gray) | Same as above | Replace gray border with rock/edge tile textures |
| **Summit backdrop** (solid blue-gray) | `scenes/battlefield.tscn` — `SummitBackdrop` `ColorRect` | Replace `ColorRect` with `Sprite2D` + Huashan summit background art |
| **HUD panels** | `scenes/ui/hud.tscn` — `ColorRect`/`Panel` nodes | Replace `ColorRect` backgrounds with themed UI textures |
| **Health bars** | `scenes/ui/health_bar.tscn` | Customize `ProgressBar` theme with wuxia-style bar textures |
| **Skill buttons** | `scenes/ui/skill_button.tscn` | Replace default `Button` theme with styled buttons with icon support |

---

## Project Structure

```
.
├── project.godot                      # Project configuration, autoloads, input map
├── scenes/
│   ├── main.tscn                      # Root scene: Camera2D + HUD + Tutorial + Battlefield
│   ├── battlefield.tscn               # TileMap grid + summit backdrop + character instances
│   ├── player.tscn                    # Yang Guo character scene
│   ├── enemy.tscn                     # Generic enemy scene (configured per opponent)
│   └── ui/
│       ├── hud.tscn                   # Health bars, skill buttons, pause button
│       └── tutorial_overlay.tscn      # Reusable dimmable tutorial panel
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd            # Game state machine, win/lose flow
│   │   ├── grid_manager.gd            # Tile occupancy, grid↔world conversion, A* pathfinding
│   │   ├── combat_manager.gd          # Pause/tick system, action queue, DoT tracker
│   │   └── tutorial_manager.gd        # Step progression, overlay show/hide, input gating
│   ├── characters/
│   │   ├── player.gd                  # Player input, movement, skill execution
│   │   └── enemy.gd                   # AI FSM, decision-making, skill execution
│   ├── battlefield.gd                 # Battlefield script: grid setup, character init, AI wiring
│   ├── ai/
│   │   ├── ai_base.gd                 # Abstract AI state machine base class
│   │   ├── ai_east_heretic.gd         # 东邪黄药师 — ranged poison, keeps distance
│   │   ├── ai_west_poison.gd          # 西毒欧阳锋 — aggressive rush, poison DoT
│   │   ├── ai_south_emperor.gd        # 南帝段智兴 — balanced melee, heals at low HP
│   │   ├── ai_north_beggar.gd         # 北丐洪七公 — high-damage melee, charges in
│   │   └── ai_central_divine.gd       # 中神通王重阳 — area attacks, defensive stance
│   ├── data/
│   │   ├── character_data.gd          # Resource: per-character stats, skills, AI class ref
│   │   └── skill_data.gd              # Resource: skill parameters (damage, range, cooldown, shape)
│   └── ui/
│       ├── health_bar.gd              # ProgressBar linked to character health
│       ├── skill_button.gd            # Button with cooldown overlay + hotkey label
│       ├── pause_button.gd            # Toggle pause/unpause
│       ├── tutorial_step.gd           # Single tutorial overlay panel controller
│       └── hud.gd                     # HUD root: wires health bars, skill bar, pause
├── README.md                          # This file
└── resources.md                       # Asset replacement guide
```

---

## The Five Greats (五绝)

| Title | Name | AI Behavior |
|-------|------|-------------|
| 东邪 (East Heretic) | 黄药师 | Ranged poison attacks, keeps distance, retreats when cornered |
| 西毒 (West Poison) | 欧阳锋 | Aggressive rush to melee, applies poison DoT on hit, never retreats |
| 南帝 (South Emperor) | 段智兴 | Balanced melee with self-healing at low HP |
| 北丐 (North Beggar) | 洪七公 | High-damage melee, charges directly, uses Dragon Palm (降龙十八掌) |
| 中神通 (Central Divine) | 王重阳 | Defensive stance, counter-attacks, area burst skills |

---

## License & Credits

This is a demo prototype built for educational purposes. All visuals are procedurally generated — no external art assets are used. Character names and settings are from Jin Yong's *Condor Trilogy* (射雕三部曲), used in tribute.
