# Technical Architecture Design — Huashan Sword Tournament (华山论剑)

## Overview

A Godot 4.4 real-time-with-pause grid-based wuxia RPG combat demo. The player controls Yang Guo on a discrete TileMap grid against five AI opponents (the Five Greats). The architecture uses four autoload singletons for cross-cutting concerns, data-driven character/skill definitions, and traditional `.tscn` scene assembly. All visuals are procedurally generated via Godot built-in primitives (`Polygon2D`, `ColorRect`, `ImageTexture`) — zero binary assets.

---

## Directory Tree

```
./
  project.godot                  # Project config: autoloads, input map, main_scene
  README.md                      # Setup & play instructions
  .gitignore                     # Pre-existing
  #
  scenes/
    main.tscn                    # Root: CanvasLayer UI + Battlefield instance
    battlefield.tscn             # TileMap grid + environment (summit backdrop)
    player.tscn                  # Yang Guo character scene
    enemy.tscn                   # Generic enemy scene (configured per opponent)
    ui/
      hud.tscn                   # Health bars, skill buttons, pause button
      tutorial_overlay.tscn      # Reusable dimmable tutorial panel
  #
  scripts/
    autoload/
      game_manager.gd            # Game state machine, win/lose flow
      grid_manager.gd            # Tile occupancy, grid↔world conversion, AStar2D pathfinding
      combat_manager.gd          # Pause/tick system, action queue, speed ordering
      tutorial_manager.gd        # Step progression, overlay show/hide, input gating
    characters/
      player.gd                  # Player input, movement, skill execution
      enemy.gd                   # AI FSM, decision-making, skill execution
    ai/
      ai_base.gd                 # Abstract AI state machine base class
      ai_east_heretic.gd         # 东邪黄药师 — ranged poison, keeps distance
      ai_west_poison.gd          # 西毒欧阳锋 — aggressive rush, poison DoT
      ai_south_emperor.gd        # 南帝段智兴 — balanced melee, heals at low HP
      ai_north_beggar.gd         # 北丐洪七公 — high-damage melee, charges in
      ai_central_divine.gd       # 中神通王重阳 — area attacks, defensive stance
    data/
      character_data.gd          # Resource: per-character stats, skills, AI class ref
      skill_data.gd              # Resource: skill params (damage, range, cooldown, shape)
    ui/
      health_bar.gd              # ProgressBar linked to character health
      skill_button.gd            # Button with cooldown overlay + hotkey label
      pause_button.gd            # Toggle pause/unpause
      tutorial_step.gd           # Single tutorial overlay panel controller
      hud.gd                     # HUD root: wires health bars, skill bar, pause
```

---

## Architecture Diagram (text)

```
┌────────────────────────────────────────────────────────────┐
│  main.tscn  (root scene)                                   │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────────────┐│
│  │  HUD     │  │ Tutorial │  │  Battlefield (instance)    ││
│  │ CanvasLyr│  │ CanvasLyr│  │  ┌───────┐ ┌────────────┐ ││
│  │          │  │          │  │  │Player │ │ Enemy×5    │ ││
│  │ HealthBars│ │ Overlay  │  │  │(YangGuo)│(config'd)  │ ││
│  │ SkillBar │  │ panels   │  │  └───┬───┘ └─────┬──────┘ ││
│  │ PauseBtn │  │          │  │      │           │        ││
│  └────┬─────┘  └────┬─────┘  │  ┌───┴───────────┴────┐   ││
│       │             │        │  │    TileMap Layer    │   ││
│       │             │        │  └────────────────────┘   ││
│       │             │        └───────────────────────────┘│
└───────┼─────────────┼────────────────────────────────────┘
        │             │
   ┌────▼─────────────▼──────────┐
   │       AUTOLOADS             │
   │  GameManager  (state mach.) │
   │  GridManager  (tiles/path)  │
   │  CombatManager(pause/speed) │
   │  TutorialManager(steps)     │
   └─────────────────────────────┘
```

**Data flow**: Input → Player/Enemy scripts → CombatManager (action queue) → GridManager (validate moves) → Character state updates → HUD signals → UI refresh.

---

## Component Specifications

### 1. `GameManager` (autoload, `game_manager.gd`)

**Responsibility**: Top-level game state machine. Owns win/lose conditions, scene references, and battle lifecycle.

**State machine**:
```
TUTORIAL → BATTLE → (WON | LOST)
              ↑        ↓
              └──PAUSED─┘  (sub-state of BATTLE)
```

**Signals**:
- `battle_started()`
- `game_won()`
- `game_lost()`
- `state_changed(new_state: String)`

**Public API**:
- `start_battle()` — called after tutorial completes or is skipped
- `end_battle(won: bool)` — triggers win/lose UI
- `set_paused(paused: bool)` — delegates to CombatManager
- `register_enemy(node: Node)` / `unregister_enemy(node: Node)` — tracks living enemies
- `get_state() -> String`

**Edge cases**: If all enemies die before tutorial ends, tutorial auto-completes. Win triggers only when `enemies_alive == 0`.

---

### 2. `GridManager` (autoload, `grid_manager.gd`)

**Responsibility**: Grid coordinate system, tile occupancy, A* pathfinding, and move-range calculation.

**Constants**:
- `TILE_SIZE := 64` (pixels)
- `GRID_WIDTH := 15`
- `GRID_HEIGHT := 11`
- `GRID_ORIGIN := Vector2(32, 32)` (half-tile offset for centering)

**State**:
- `occupancy: Dictionary[Vector2i, Node]` — maps grid coords to occupying unit
- `astar: AStar2D` — rebuilt when obstacles/occupants change
- `tilemap_ref: TileMap` — set by battlefield on ready

**Public API**:
- `world_to_grid(world_pos: Vector2) -> Vector2i`
- `grid_to_world(grid_pos: Vector2i) -> Vector2` (returns pixel-center position)
- `is_occupied(grid_pos: Vector2i) -> bool`
- `is_in_bounds(grid_pos: Vector2i) -> bool`
- `reserve_tile(grid_pos: Vector2i, unit: Node) -> bool` — returns false if already occupied
- `free_tile(grid_pos: Vector2i)`
- `move_unit(unit: Node, from: Vector2i, to: Vector2i) -> bool`
- `find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]` — A* path, empty if unreachable
- `get_move_range(origin: Vector2i, move_points: int) -> Array[Vector2i]` — flood-fill for valid destinations
- `get_units_in_range(origin: Vector2i, range: int) -> Array[Node]` — targets for attacks/skills

**AStar2D sync strategy**: On `_ready`, iterate TileMap used cells and add AStar2D points. Connect 4-directional neighbors. On occupancy change, update point weight (occupied = disabled via `set_point_disabled`). This is called once per move, not per frame.

**Edge cases**:
- Movement to occupied tile: `reserve_tile` returns false, movement cancelled with feedback.
- Out-of-bounds input: `is_in_bounds` clamps before any operation.
- Unit death: `free_tile` called before unit is removed from scene tree.
- Multiple units targeting same tile simultaneously: CombatManager action queue serializes moves; first mover wins, second re-paths.

---

### 3. `CombatManager` (autoload, `combat_manager.gd`)

**Responsibility**: Real-time-with-pause time control, action queue, and speed-based turn ordering.

**State**:
- `is_paused: bool`
- `action_queue: Array[Dictionary]` — each entry: `{unit: Node, action: String, target: Node, params: Dictionary}`
- `active_tweens: Array[Tween]` — tracked for pause/resume safety

**Signals**:
- `paused()`
- `unpaused()`
- `action_executed(unit: Node, action: String)`

**Public API**:
- `pause()` — sets `Engine.time_scale = 0`, emits `paused`
- `unpause()` — sets `Engine.time_scale = 1.0`, emits `unpaused`, drains action queue
- `toggle_pause()`
- `request_action(unit: Node, action: String, target: Node, params := {})` — enqueues; if unpaused and no tween active, executes immediately
- `is_unit_busy(unit: Node) -> bool` — true if unit has active tween or pending action

**Pause mechanics**:
- `Engine.time_scale = 0` freezes `_process(delta)` and `Tween` playback globally.
- Input is NOT gated by CombatManager — input gating is done by TutorialManager during tutorial and by CombatManager.is_unit_busy() + is_paused during battle.
- On unpause: drain action queue FIFO. Each action creates a Tween for movement/animation; next action starts only after current tween finishes (via `tween.finished` signal).

**Edge cases**:
- Pause mid-tween: `Engine.time_scale = 0` freezes Godot's Tween engine natively — resumes cleanly.
- Rapid pause toggle: debounce via `Time.get_ticks_msec()` — minimum 100ms between toggles.
- Action queue overflow: hard cap at 10 queued actions; excess requests are rejected with a UI message "Cannot queue more actions."

---

### 4. `TutorialManager` (autoload, `tutorial_manager.gd`)

**Responsibility**: Step-by-step tutorial overlay system. Gates input, shows instructional panels, highlights relevant UI areas.

**Tutorial steps** (enum):
1. `WELCOME` — intro text, "华山论剑 begins!"
2. `MOVEMENT` — teach WASD/arrow grid movement, highlight battlefield
3. `BASIC_ATTACK` — teach clicking an adjacent enemy to attack
4. `SKILL_1` — teach 黯然销魂掌 (Sorrowful Palms), highlight skill button 1
5. `SKILL_2` — teach secondary skill, highlight skill button 2
6. `PAUSE` — teach pause toggle, highlight pause button
7. `COMBAT_START` — final prompt, dismiss overlay, begin battle

**State**:
- `current_step: int`
- `step_completed: Array[bool]`
- `is_active: bool`
- `input_gated: bool`

**Signals**:
- `step_shown(step_id: int)`
- `step_completed(step_id: int)`
- `tutorial_finished()`
- `tutorial_skipped()`

**Public API**:
- `start()` — begin from step 0, show first overlay, gate all game input
- `advance()` — mark current step complete, show next
- `skip()` — mark all complete, hide overlay, ungating input, emit `tutorial_finished`
- `is_input_allowed(action: String) -> bool` — called by Player script; returns true only for actions taught so far
- `highlight_node(node_path: String)` — draws a pulsing border around a UI element
- `show_overlay(title: String, body: String, highlight_paths: Array[String])`

**Overlay implementation**: A `CanvasLayer` (layer 100) with a semi-transparent `ColorRect` dimming the game, and a centered `Panel` containing `Label` for title, `RichTextLabel` for body, and `Button` ("Next" / "Skip Tutorial"). Highlight areas use a `ReferenceRect` with an animated border.

**Edge cases**:
- Tutorial step gating: During MOVEMENT step, attack/skill inputs are silently ignored.
- Skip: Available from step 1 onward (not step 0 welcome).
- All enemies dead mid-tutorial: `advance()` skips remaining combat-teaching steps, jumps directly to COMBAT_START.

---

### 5. `Player` (`characters/player.gd`, attached to `player.tscn`)

**Responsibility**: Yang Guo's movement, targeting, skill execution. Processes input, validates against GridManager and TutorialManager, delegates action requests to CombatManager.

**Visual**: `Polygon2D` (circle, radius 28, blue fill) + `Label` showing "杨过".

**State**:
- `grid_pos: Vector2i`
- `health: int`
- `max_health: int`
- `skills: Array[SkillData]` — loaded from CharacterData resource
- `skill_cooldowns: Array[float]` — remaining cooldown per skill (seconds)
- `is_moving: bool` — true during tween animation
- `selected_skill_index: int` — -1 means basic attack

**Input handling** (`_unhandled_input`):
- WASD / Arrow keys: grid movement (4-dir, 1 tile per press)
- Number keys 1-2: select skill
- Left-click on enemy: execute selected action (basic attack or selected skill)
- Space / Escape: pause toggle (via CombatManager)

**Movement flow**:
1. Input direction → calculate target `grid_pos + direction`
2. Check `TutorialManager.is_input_allowed("move")`
3. Check `GridManager.is_in_bounds(target)` and `!GridManager.is_occupied(target)`
4. Request `GridManager.move_unit(self, current, target)`
5. GridManager creates Tween (0.15s tile-to-tile), sets `is_moving = true`
6. On tween finished: `is_moving = false`, snap position

**Attack flow**:
1. Left-click on enemy → if in range, request `CombatManager.request_action(self, action, target)`
2. CombatManager executes: apply damage, play flash animation, check death
3. If target dead: `GameManager.unregister_enemy(target)`, `GridManager.free_tile(target.grid_pos)`

**Skills**:
- Skill 1: **黯然销魂掌 (Sorrowful Palms)** — melee (adjacent tiles), high damage, 4s cooldown, applies knockback (1 tile)
- Skill 2: **玄铁剑法 (Heavy Iron Sword)** — 2-tile line AoE, moderate damage, 3s cooldown

**Cooldown tick**: In `_process(delta)`, if unpaused: decrement each `skill_cooldowns[i]` by `delta`, clamp to ≥ 0.

---

### 6. `Enemy` (`characters/enemy.gd`, attached to `enemy.tscn`)

**Responsibility**: AI-driven opponent. Uses an FSM pattern with pluggable AI behavior scripts for the five distinct Greats.

**Visual**: `Polygon2D` (diamond shape, 28px, distinct color per enemy) + `Label` showing name.

**State**:
- `grid_pos: Vector2i`
- `health: int`, `max_health: int`
- `skills: Array[SkillData]`
- `skill_cooldowns: Array[float]`
- `ai_controller: AIController` — the pluggable behavior script
- `fsm_state: String` — one of: IDLE, APPROACH, ATTACK, SKILL, RETREAT

**AI FSM (`ai/ai_base.gd`)**:

Base class with virtual methods overridden per enemy:

```
IDLE ──(player detected)──► APPROACH
APPROACH ──(in range)──► ATTACK or SKILL
APPROACH ──(path blocked, no ranged skill)──► IDLE
ATTACK ──(cooldown elapsed)──► IDLE (re-evaluate)
SKILL ──(cooldown elapsed)──► IDLE
Any ──(health < 25%)──► RETREAT
RETREAT ──(safe distance)──► IDLE
```

**Decision tick**: Every 0.5s (not every frame), the AI evaluates: find nearest player, check range, choose action based on weighted priorities defined in the per-enemy script.

**Per-enemy AI behaviors**:

| Enemy | AI Class | Behavior |
|-------|----------|----------|
| 东邪黄药师 (East Heretic) | `ai_east_heretic.gd` | Prefers range 2-3. Uses poison cloud skill (AoE DoT). Retreats if player closes to melee. |
| 西毒欧阳锋 (West Poison) | `ai_west_poison.gd` | Aggressive rush to melee. Applies poison DoT on hit. Never retreats. |
| 南帝段智兴 (South Emperor) | `ai_south_emperor.gd` | Balanced approach. Heals self when HP < 30% (once per battle). Mix of melee and ranged. |
| 北丐洪七公 (North Beggar) | `ai_north_beggar.gd` | High damage melee. Charges directly. Uses 降龙十八掌 (Dragon Palm) skill — 3-tile line, massive damage, long cooldown. |
| 中神通王重阳 (Central Divine) | `ai_central_divine.gd` | Defensive stance: waits for player to approach. Counter-attacks. Area burst skill when surrounded. |

**Execution flow**:
1. `_process(delta)`: if unpaused, tick cooldowns, run `ai_controller.evaluate(self, player_ref, delta)`
2. AI returns `{action: String, target: Vector2i, skill_index: int}`
3. Enemy calls `CombatManager.request_action(self, action_data)`

---

### 7. Data Resources (`data/character_data.gd`, `data/skill_data.gd`)

**CharacterData** (extends `Resource`):
```gdscript
class_name CharacterData
@export var character_name: String
@export var max_health: int
@export var move_range: int          # tiles per move action
@export var attack_damage: int
@export var attack_range: int        # tiles
@export var skills: Array[SkillData] # 1-2 skills
@export var ai_class: String         # e.g. "ai_east_heretic"
@export var color: Color             # placeholder shape color
```

**SkillData** (extends `Resource`):
```gdscript
class_name SkillData
@export var skill_name: String
@export var description: String
@export var damage: int
@export var range: int               # max tiles
@export var cooldown: float          # seconds
@export var aoe_shape: String        # "single", "line", "cross", "square"
@export var aoe_size: int            # radius in tiles (1 = self+adjacent 3×3)
@export var knockback: int           # tiles pushed back (0 = none)
@export var dot_damage: int          # damage per tick (0 = none)
@export var dot_duration: float      # seconds
@export var heal_amount: int         # 0 = not a heal
```

Resources are created as `.tres` files or instantiated in code via `CharacterData.new()` in the battlefield's `_ready()`. For simplicity and diff-ability, we create them programmatically in a factory method on the battlefield script.

---

### 8. UI Components

#### HUD (`ui/hud.gd`, `ui/hud.tscn`)
- Lives on `CanvasLayer` (layer 10)
- Contains:
  - `health_bar.gd` × 6 (player + 5 enemies) — simple ProgressBar with name label, positioned near each character in screen space via `Camera2D.get_camera_screen_center()` offset math
  - `skill_button.gd` × 2 — player skill buttons, show cooldown as a gray overlay that shrinks as cooldown ticks down
  - `pause_button.gd` — "⏸ Pause" / "▶ Unpause" toggle button
- Listens to character health signals to update bars

#### Health Bar (`ui/health_bar.gd`)
- `setup(character_name: String, max_hp: int)`
- `update_health(current: int, max_hp: int)` — sets ProgressBar.value, changes color (green > 50%, yellow > 25%, red < 25%)
- Listens to character's `health_changed(new_hp)` signal

#### Skill Button (`ui/skill_button.gd`)
- `setup(skill: SkillData, hotkey: String)`
- `update_cooldown(remaining: float, total: float)` — overlays a gray rect from top, height proportional to remaining/total
- Disabled when cooldown > 0 or during enemy turn or paused
- Emits `skill_selected(skill_index: int)` on press

#### Tutorial Overlay (`ui/tutorial_overlay.tscn`, `ui/tutorial_step.gd`)
- `CanvasLayer` (layer 100)
- `ColorRect` (full screen, black, alpha 0.5)
- `Panel` (centered, 600×400)
  - `Label` (title)
  - `RichTextLabel` (body, supports bbcode for key highlights)
  - `HBoxContainer` with `Button("Next")` and `Button("Skip Tutorial")`
- Highlight areas: `ReferenceRect` nodes positioned to frame UI elements, with a `Tween` pulsing the border color

---

### 9. Scene Specifications

#### `project.godot`
```ini
[application]
config/name="Huashan Sword Tournament"
run/main_scene="res://scenes/main.tscn"

[input]
move_up={...}
move_down={...}
move_left={...}
move_right={...}
skill_1={...}
skill_2={...}
pause={...}

[autoload]
GameManager="*res://scripts/autoload/game_manager.gd"
GridManager="*res://scripts/autoload/grid_manager.gd"
CombatManager="*res://scripts/autoload/combat_manager.gd"
TutorialManager="*res://scripts/autoload/tutorial_manager.gd"
```

#### `main.tscn`
- Root: `Node2D` "Main"
  - `Camera2D` (centered on battlefield, zoom to fit 15×11 grid at 64px tiles: 960×704 viewport ideally)
  - Instance `battlefield.tscn` as child
  - `CanvasLayer` "HUDLayer" → instance `hud.tscn`
  - `CanvasLayer` "TutorialLayer" → instance `tutorial_overlay.tscn` (hidden by default)

#### `battlefield.tscn`
- Root: `Node2D` "Battlefield"
  - `TileMap` "Grid" — procedurally populated in `_ready()` with simple colored tiles (grass-green base, gray border rocks)
  - `ColorRect` "SummitBackdrop" — large rect behind grid, gradient from sky blue to mountain gray
  - Instance `player.tscn` "YangGuo"
  - Instance `enemy.tscn` × 5 "EastHeretic", "WestPoison", "SouthEmperor", "NorthBeggar", "CentralDivine"
- Script `battlefield.gd`: In `_ready()`, generate tile visuals, position characters at starting grid positions, initialize all enemy AI controllers, signal `GameManager` that battlefield is ready.

#### `player.tscn`
- Root: `Node2D` "Player"
  - `Polygon2D` "Sprite" — circle via `set_polygon()` in code
  - `Label` "NameLabel"
  - Script: `player.gd`

#### `enemy.tscn`
- Root: `Node2D` "Enemy"
  - `Polygon2D` "Sprite" — diamond via `set_polygon()` in code
  - `Label` "NameLabel"
  - Script: `enemy.gd`

---

## Data Flow Summary

```
[Player Input]
     │
     ▼
┌──────────────┐    ┌──────────────┐
│ TutorialMgr  │───▶│ Input allowed?│
│ (gate check) │    └──────┬───────┘
└──────────────┘           │ yes
                           ▼
                    ┌──────────────┐
                    │ GridManager  │
                    │ (validate    │
                    │  movement,   │
                    │  pathfind)   │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ CombatManager│
                    │ (enqueue,    │
                    │  execute,    │
                    │  tween anim) │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐ ┌──────────┐ ┌──────────┐
        │Character│ │GridMgr   │ │ HUD/UI   │
        │health/  │ │occupancy │ │ update   │
        │position │ │update    │ │ bars/btns│
        └────┬────┘ └──────────┘ └──────────┘
             │
             ▼
      ┌──────────────┐
      │ GameManager  │
      │ (check win/  │
      │  lose cond.) │
      └──────────────┘
```

---

## Technical Stack

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Engine | Godot 4.4 | Required by spec |
| Language | GDScript | Agent-friendly, no compilation, fast iteration |
| Grid system | TileMap + custom GridManager | Built-in; KidsCanCode recipe adapted |
| Pathfinding | AStar2D (built-in) | No dependencies; sync from TileMap used cells |
| Pause | `Engine.time_scale = 0` | Native Godot; freezes physics, process, tweens |
| Animation | `Tween` (built-in) | Smooth tile-to-tile, damage flash, UI transitions |
| AI | Custom FSM per enemy | Simpler than beehave addon for 5 fixed behaviors |
| UI | CanvasLayer + Control nodes | Built-in; tutorial overlays, HUD, skill bar |
| Placeholder art | Polygon2D + ColorRect + ImageTexture | Zero binary assets; distinct shapes & colors |
| Data | Custom Resources (CharacterData, SkillData) | Editor-visible, diffable, reusable |

---

## Non-Normative Extensibility Notes

- **More characters**: Add new `CharacterData` resources + instantiate `enemy.tscn` with that config. No code changes needed if the AI pattern already exists.
- **More skills**: Add entries to `SkillData` arrays per character. The `skill_button.gd` can handle up to N buttons if the HUD iterates over `skills.size()`.
- **Multi-scene campaign**: `GameManager` can load different `.tscn` files for different battles. The autoloads are scene-agnostic.
- **Real art assets**: Replace `Polygon2D` nodes with `Sprite2D` + imported textures. No code changes — the visual node is isolated from game logic.
- **Online multiplayer**: Not designed for; would require significant rework of CombatManager's action queue to support network serialization.
