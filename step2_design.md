# Technical Architecture Design — "Make It Playable" Fix Program

**Project:** jinyong-play — Huashan Sword Tournament (Godot 4 GDScript tactical wuxia RPG)
**Goal:** Make the game actually playable end-to-end: keyboard basic attack, live enemy AI, winnable/losable battle, real character names in the HUD, legible top-edge layout, all proven by the `run_tests.sh` gate (`--compile` + `--playtest` against `playtest_spec.yaml`).

**Inputs:** Step-1 SOTA report (`step1_sota.md`). The repo has since progressed through the art/audio phase (Sprite2D characters, generated PNG/WAV assets, `AudioManager` autoload), so the SOTA line numbers are stale — every fix below is specified against **current** function/behavior, verified by code inspection in this step.

---

## 1. Overview

The combat, AI, and UI systems are *written* but four defects keep them from running, plus two presentation defects violate the brief's visible success criteria. This design is a **surgical fix program**: no AI rewrite, no combat rebalance, no new autoloads, no asset changes. Every existing node name / script-variable name / signal name that the playtest gate can observe is preserved; the only surface *additions* are new enemy instance names and one new input action.

### 1.1 Root cause → fix map

| # | Defect (current code) | Effect | Fix (component) |
|---|---|---|---|
| F1 | `CombatManager.is_unit_busy()`: `if unit.has_method("get_is_moving") or ...: return true` — every `Player`/`Enemy` *defines* `get_is_moving()`, so the check is unconditionally true | Enemy `_process()` gate (`enemy.gd`) never passes → `_evaluate_ai()` never runs → `fsm_state` stuck `"IDLE"`; every `AIController*.evaluate()` guard also returns `{}` | Test the **return value** of `is_moving`/`get_is_moving()` instead of method existence (single point, unblocks both gates). **§4.1** |
| F2 | `GridManager.reserve_tile()` / `free_tile()` toggle `astar.set_point_disabled()` for **occupancy**, including the player's tile | `AStar2D.get_id_path()` returns `[]` when an endpoint is disabled → `find_path(enemy, player)` always empty → `ai_base._move_toward()` returns `{}` → enemies never approach | Keep the AStar graph **static geometry**: occupancy no longer mutates it; border tiles become permanently disabled walls. **§4.2** |
| F3 | `HUD._create_health_bar()` calls `bar.setup()` **before** `add_child()`; `enemy.setup()`/`player.setup()` run before `add_child` (battlefield instantiates then calls `setup`) → `@onready` refs (`_name_label`, `_bar`) are null inside `setup()` | Health bars keep `.tscn` defaults (`text="Name"`, `max_value=100`); enemy name labels keep `"Enemy"`; HUD hardcodes player name `"Yang Guo"` instead of reading data | Reorder `add_child` before `setup` in HUD + `get_node_or_null` fallbacks inside every `setup()`; data-driven names. **§4.3** |
| F4 | No keyboard path for the game's central verb: no `basic_attack` action in `project.godot [input]`; `player._unhandled_input` handles movement / skill select / pause / left-click only | User story "press a key, attack the enemy in front of me" impossible; playtest gate can only drive combat via mouse | Declare `basic_attack` (key `J`, physical 74) + deterministic nearest-enemy targeting routine reusing the existing click pipeline. **§4.4** |
| F5 | Lethal hit soft-locks the queue: `_damage_flash()` returns a tween `bind_node(target)`; `_handle_death` → `queue_free()` kills a bound tween **without emitting `finished`** → `_drain_action_queue()`'s `await tween.finished` never resumes → `_processing_action` stays `true` forever | After the first kill, combat silently stops (queue drains nothing) | Bind the flash tween to `CombatManager` (never freed) **and** replace the blind await with a frame-capped watchdog (`_await_tween_safe`). **§4.1** |
| F6 | Border tiles (row 0 / row 10 / col 0 / col 14) are painted as stone walls (`battlefield._setup_tilemap`) but are **walkable** (`is_in_bounds` admits the whole rect); sprites are feet-anchored with `offset.y = −texture_height/2` (top at world y = −32 on row 0); `HealthBar.follow_character()` places bars 50 px above characters with no clamp; viewport size is not pinned | Units can stand on row 0 and their heads clip above the view; floating bars clip off the top edge | Block the border ring via a new `GridManager.is_walkable()` + disable border points in the AStar graph; clamp health-bar screen positions; pin `[display]` viewport to 1088×832 (matches the 1088×832 backdrop). **§4.2 / §4.3 / §4.5** |
| F7 | `pause_game` is bound to **Space** (physical 32) **and** Space is part of the built-in `ui_accept`; the tutorial advances on `ui_accept` | A harness `ui_accept` press (Space) advances the tutorial *and* toggles `Engine.time_scale = 0` → headless scenarios freeze mid-tutorial | Rebind `pause_game` to Escape-only; update tutorial copy. **§4.5** |

Minor, documented-not-fixed (per SOTA): `ai_central_divine.gd._last_attacked_time` is never written → Central Divine is deliberately passive unless the player enters range 2 — fine, his "defensive" personality. Differential assertions target the four aggressive Greats.

### 1.2 Success criteria → verification mapping

| Brief criterion | Fix | Proof |
|---|---|---|
| Keyboard attack | F4 | New playtest scenario `keyboard_basic_attack_hits_enemy`: after tutorial, move adjacent to Central Divine, press `basic_attack`, assert his `health < max_health` |
| Live enemy AI | F1+F2 | New scenario `enemy_ai_approaches_player`: `West_Poison.fsm_state` leaves `"IDLE"` and `Player.health` drops without any input |
| Win / lose | F5 (+F1/F2) | Terminal scenario `defeat_by_standing_still`: player stands still after tutorial → `GameManager.current_state == "LOST"` (also proves AI convergence + kill path + queue stays alive). Optional victory scenario if frame budget allows |
| Real HUD names | F3 | Assert `HealthBar` labels show real names (skeleton asserts e.g. `HealthBar.NameLabel.text != "Name"`); frame-capture review |
| Legible layout | F6 | Frame-capture review: no sprite/bar clipping on top row; all 6 bars on-screen |
| Proof-by-playtest | all | `run_tests.sh` green with ≥1 differential (`changed:`-style) assertion per new scenario and 1 terminal scenario |

---

## 2. Architecture Diagram (text)

```
                         INPUT LAYER
   Keyboard (harness injects actions by name from playtest_spec.yaml `actions`)
   basic_attack (J, NEW)  move_*/skill_1/skill_2 (existing)  ui_accept (tutorial)  pause_game (Esc only)
        │                                                          │
        ▼                                                          ▼
   player.gd _unhandled_input ────────────────┐          tutorial_manager.gd (advance → start_battle)
        │ _try_move / _try_select_skill       │
        │ _try_keyboard_attack (NEW)          │
        ▼                                     ▼
   _pick_nearest_enemy_in_range (NEW)   _handle_click_targeting (existing, refactored)
        └──────────────► _try_attack_target (NEW, shared by keyboard + click)
                                    │
                                    ▼
                        CombatManager.request_action(unit, action, target, params)
                                    │
                 ┌──────────────────┴───────────────────┐
                 ▼                                      ▼
   PLAYER-DRIVEN ACTIONS                      AI-DRIVEN ACTIONS
   (FIFO action_queue, _drain_action_queue)   enemy.gd _process: state==BATTLE, !paused,
                                              accumulator ≥0.5s, !is_unit_busy(self)  ← F1 fix
                                              → _evaluate_ai → ai_controller.evaluate()
                                              (5 personalities, untouched) → decision dict
                                              {move | basic_attack | skill}
                 └──────────────────┬───────────────────┘
                                    ▼
      _execute_move / _execute_basic_attack / _execute_skill  (+ _await_tween_safe ← F5 fix)
                                    │
        ┌───────────────────────────┼────────────────────────────┐
        ▼                           ▼                            ▼
   GridManager (static AStar ← F2,   apply_damage/DoT/knockback    AudioManager (existing hooks,
   border walls + is_walkable ← F6)   → health_changed             untouched)
        │                                │
        ▼                                ▼
   ai_base._move_toward/_move_away    _handle_death → unregister_enemy / end_battle
   (unchanged logic, now reachable)       │
                                          ▼
                                 GameManager.current_state: TUTORIAL→BATTLE→WON|LOST
                                          │
                                          ▼
                      HUD: HealthBar.setup (add_child first ← F3) + follow_character (clamped ← F6)

Data flow of one keyboard attack:
  basic_attack press → _try_keyboard_attack → nearest enemy in range (selected skill range, else 1)
  → _try_attack_target (tutorial gate, cooldown, range re-check, execute, skill auto-deselect)
  → CombatManager.request_action → _execute_basic_attack/_execute_skill → apply_damage
  → damage_dealt / health_changed → HealthBar.update_health → _handle_death → GameManager win/lose.

Data flow of one AI tick:
  enemy._process (0.5 s accumulator) → _evaluate_ai → ai_controller.evaluate
  → {action:"move", params:{to: path[1]}} or {action:"basic_attack"/"skill", target: player}
  → CombatManager.request_action → same execution pipeline → reset_ai_timer() after each action.
```

---

## 3. Component List & Interfaces

Unchanged components (contracts that stay byte-stable unless listed): `GameManager`, `TutorialManager` gating logic, `AudioManager`, all 5 `AIController*` scripts, `skill_data.gd`, `character_data.gd`, `hud.tscn`/`health_bar.tscn`/`player.tscn`/`enemy.tscn`/`battlefield.tscn`/`main.tscn` node trees, all signals (`health_changed`, `damage_dealt`, `action_executed`, `battle_started`, `game_won`, `game_lost`, `state_changed`, `cooldowns_updated`, `step_shown`, `step_completed`, `tutorial_finished`).

### 3.1 Component A — `CombatManager` (scripts/autoload/combat_manager.gd)

- **Responsibility (unchanged):** pause state, FIFO action queue, damage/heal/DoT/knockback, death handling. **Changes:** busy-check semantics (F1), queue-drain robustness (F5), wall-awareness in move/knockback (F6).
- **Interface changes (all internal, no signature changes to the public API):**
  - `is_unit_busy(unit: Node) -> bool` — *behavior fix only* (F1). New body (keep the `_current_action_unit` and pending-queue checks verbatim, replace the tail):
    ```gdscript
    # Test the unit's ACTUAL moving state — not has_method, which is true for
    # every Player/Enemy (both define get_is_moving()) and made everything busy.
    if "is_moving" in unit and bool(unit.is_moving):
        return true
    if unit.has_method("get_is_moving") and bool(unit.get_is_moving()):
        return true
    return false
    ```
  - `_drain_action_queue()` — replace `if tween != null and is_instance_valid(tween): await tween.finished` with `await _await_tween_safe(tween)`.
  - New private `_await_tween_safe(tween: Tween) -> void` (F5): connect `finished` to a `done` flag, arm `get_tree().create_timer(TWEEN_TIMEOUT_SEC, true)` (process-always), then `while not done and timer.time_left > 0.0: await get_tree().process_frame`. `const TWEEN_TIMEOUT_SEC := 0.6` (longest action tween: 0.15 s move + 0.1 s flash ⇒ 0.6 s cap is generous). A killed tween never emits `finished` → the timer caps the wait → the queue can never stall.
  - `_damage_flash(target) -> Tween` — change `flash_tween.bind_node(target)` → `flash_tween.bind_node(self)` (F5). `CombatManager` is never freed, so its tween always completes; the modulate-restore callback already guards `is_instance_valid(poly)`. (Watchdog stays as belt-and-braces for move tweens bound to units that could die mid-move.)
  - `_execute_move()` — add `if not GridManager.is_walkable(to_pos): return null` after the existing `is_in_bounds` check (F6).
  - `apply_knockback()` — in the per-tile walk loop, add `or not GridManager.is_walkable(next_pos)` to the break condition (F6).
- **Data flow:** unchanged; queue entries `{unit, action, target, params}` keep their shape.

### 3.2 Component B — `GridManager` (scripts/autoload/grid_manager.gd)

- **Responsibility (unchanged):** grid coordinate system, occupancy, AStar2D pathfinding, movement validation, range/AoE queries. **Changes:** graph becomes static geometry + wall ring (F2, F6).
- **Interface changes:**
  - `reserve_tile(grid_pos, unit) -> bool` — **delete** the `astar.set_point_disabled(..., true)` block (occupancy no longer mutates the graph). `free_tile(grid_pos)` — **delete** the corresponding re-enable block. Occupancy enforcement already happens at move time (`move_unit`, `_execute_move`, `_move_toward`, `_move_away`, `apply_knockback`, `get_move_range`) — the graph's job is only *geometry*.
  - `setup_grid()` — after connecting neighbors, permanently disable the border-ring points:
    ```gdscript
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            if not is_walkable(Vector2i(x, y)):
                astar.set_point_disabled(y * GRID_WIDTH + x, true)
    ```
    Player/enemy tiles are never on the ring (spawns are interior), so `find_path(enemy, player)` endpoints are always enabled → non-empty path while a route exists. `find_path()` itself is unchanged.
  - **New** `is_walkable(grid_pos: Vector2i) -> bool`: `false` if out of bounds, or if `grid_pos.x == 0 or grid_pos.x == GRID_WIDTH-1 or grid_pos.y == 0 or grid_pos.y == GRID_HEIGHT-1`; else `true`. (Matches the painted stone-wall ring; `is_in_bounds` keeps its current meaning "inside the 15×11 rect".)
  - `move_unit()` — add `if not is_walkable(to_pos): return false` (defense in depth; player already checks in `_try_move`).
  - `get_move_range()` — BFS skips `not is_walkable(next_pos)`.
- **Callers updated:** `player._try_move`, `ai_base._move_away`, `CombatManager._execute_move`, `CombatManager.apply_knockback` (see respective components). `ai_base._move_toward` needs no change: it walks `path[1]` of a wall-free graph and re-validates occupancy.
- **Accepted behavior (documented):** with occupancy out of the graph, a path may route *through* an occupied intermediate tile; `_move_toward` only ever takes `path[1]` (the immediate neighbor) and re-checks occupancy there, so an enemy blocked by a teammate stalls for that tick and retries next tick (0.5 s later). This is the existing stall semantic, just triggered less often.

### 3.3 Component C — AI layer (scripts/ai/*.gd)

- **Zero logic changes.** F1+F2 unblock the existing framework: `enemy.gd:_process` gate (`not CombatManager.is_unit_busy(self)`), the `is_unit_busy` guards inside each `evaluate()`, and `_move_toward`'s path all become reachable. Personalities (West Poison rush, East Heretic kite, North Beggar line-AoE, South Emperor heal-once, Central Divine defensive) stay as authored.
- **One call-site update (F6):** `ai_base._move_away()` — replace the `GridManager.is_in_bounds(target_pos)` check with `GridManager.is_walkable(target_pos)` so retreat never steps onto the wall ring.

### 3.4 Component D — Player keyboard attack (scripts/characters/player.gd + project.godot)

- **New input action** in `project.godot [input]` — same `Object(InputEventKey,...)` format as existing entries:
  ```
  basic_attack={
  "deadzone": 0.5,
  "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":74,"key_label":0,"unicode":106,"location":0,"echo":false,"script":null)
  ]
  }
  ```
  Key `J` (physical 74) — collision-free (WASD/arrows/1/2/Space/Esc all taken). `basic_attack` is already the tutorial gate name used by the click path (`TutorialManager.is_input_allowed("basic_attack")`) — no gating-table change needed.
- **`player.gd` interface changes:**
  - `_unhandled_input` — new branch (after skill selection, before pause):
    ```gdscript
    elif event.is_action_pressed("basic_attack"):
        _try_keyboard_attack()
        get_viewport().set_input_as_handled()
    ```
  - **New** `_try_keyboard_attack() -> void`: range = selected skill's `skill.range` if `selected_skill_index >= 0` else `1`; `var target := _pick_nearest_enemy_in_range(range)`; if non-null → `_try_attack_target(target)`.
  - **New** `_pick_nearest_enemy_in_range(range_val: int) -> Node`: iterate `GameManager.get_enemies_alive()` (stable registration order: East Heretic, West Poison, South Emperor, North Beggar, Central Divine); compute Chebyshev distance; return the strictly-nearest valid enemy with `dist <= range_val`; ties break to the first in iteration order (**deterministic**). No facing state, no fallback randomness.
  - **Refactor (behavior-neutral):** extract the inner body of `_handle_click_targeting()` (the `selected_skill_index >= 0` skill branch *and* the basic-attack branch, including tutorial gates, cooldown check, range re-check, `_execute_skill`/`_execute_basic_attack` call, skill auto-deselect) into **new** `_try_attack_target(enemy: Node) -> void`. The click path becomes: find enemy at clicked tile → `_try_attack_target(enemy)` → `break`. Identical semantics, one shared routine for both input paths.
  - `_try_move()` — change `if not GridManager.is_in_bounds(target)` to `if not GridManager.is_walkable(target)` (F6).
  - **New** `_apply_name_label() -> void` (F3): resolve `_name_label` with a `get_node_or_null("NameLabel") as Label` fallback and set `text = character_data.character_name`; call at the end of `setup()` (replacing the current null-guarded block) and defensively from `_ready()` (no-op second time).
- **Contract:** `basic_attack` appears in both `project.godot [input]` and `playtest_spec.yaml actions`; gate hard-fails `input_dead` otherwise. Pressing `basic_attack` with no enemy in range is silently ignored (mirrors the click path's out-of-range ignore).

### 3.5 Component E — HUD & labels (scripts/ui/hud.gd, scripts/ui/health_bar.gd, scripts/characters/*.gd)

- **`hud.gd` `_create_health_bar()`** — reorder (F3):
  ```gdscript
  _health_bar_container.add_child(bar)
  bar.setup(display_name, max_hp, character)
  _health_bars.append(bar)
  ```
  And in `setup()`: replace the hardcoded `"Yang Guo"` with `player.character_data.character_name` (fallback `"Player"` if the field is absent).
- **`health_bar.gd` `setup()`** — defensive resolution so it works regardless of call order (F3): `var bar := _bar; if bar == null: bar = get_node_or_null("Bar") as ProgressBar`; same for the name label; set `bar.max_value = max_hp` **and** `bar.value = max_hp` (fresh bars must show the character's real max, e.g. East Heretic 80, not the `.tscn` default 100). Signal wiring unchanged.
- **`health_bar.gd` `follow_character()`** — clamp the computed screen position (F6):
  ```gdscript
  var viewport_size := get_viewport_rect().size
  screen_pos += Vector2(-60, -50)
  global_position = Vector2(
      clampf(screen_pos.x, 4.0, viewport_size.x - size.x - 4.0),
      clampf(screen_pos.y, 4.0, viewport_size.y - size.y - 4.0))
  ```
- **`enemy.gd` / `player.gd`** — `_apply_name_label()` helper (see §3.4), mirroring the existing `_apply_character_visuals()` `get_node_or_null` pattern; replaces the `if _name_label != null` block in `setup()`.
- **`battlefield.gd` `_instantiate_enemies()`** — give each enemy instance a unique, surface-addressable node name for deterministic assertions (extension, not a rename of shared names):
  ```gdscript
  enemy.name = data.character_name.replace(" ", "_")   # "East_Heretic", ...
  ```
  Set before `add_child`. Gameplay is unaffected; the existing playtest spec has no `Enemy` surface entry, so nothing breaks.

### 3.6 Component F — Input/config & copy (project.godot, tutorial_manager.gd, README.md)

- **`project.godot`**:
  - `[input]`: add `basic_attack` (§3.4). Remove the Space (`physical_keycode=32`) event from `pause_game`, keeping Escape (`4194305`) — action stays declared (F7).
  - **New** `[display]` section pinning the viewport: `window/size/viewport_width=1088`, `window/size/viewport_height=832` (matches the 1088×832 summit backdrop exactly; makes screen-space math and frame captures deterministic).
- **`tutorial_manager.gd`** copy updates only (no logic):
  - `STEP_BASIC_ATTACK` body → "Move adjacent to an enemy, then press **[b]J[/b]** (or [b]left-click[/b] them) to perform a basic attack.\n\nTry attacking an enemy!"
  - `STEP_SKILL_1` / `STEP_SKILL_2` → mention pressing `J` fires the selected skill at the nearest enemy in range (or click a target).
  - `STEP_PAUSE` → "Press [b]Escape[/b] to pause/unpause combat…" (Space no longer pauses).
- **`README.md`** — update controls table (J = basic attack; Esc = pause), note the AI is live and the battle ends in Victory/Defeat, list which files changed. Required deliverable per project guidance.

---

## 4. File-Level Change Specification (implementer contract)

All edits are **surgical**; no file is deleted or rewritten wholesale. Paths relative to repo root.

| File | Changes | Risk |
|---|---|---|
| `./project.godot` | +`basic_attack` `[input]` block; remove Space event from `pause_game`; +`[display]` viewport 1088×832 | Low (config) |
| `./scripts/autoload/grid_manager.gd` | `is_walkable()` new; `setup_grid()` disables ring; drop `set_point_disabled` from `reserve_tile`/`free_tile`; walkable checks in `move_unit`/`get_move_range` | **Medium** — central to movement; must keep `is_in_bounds` semantics intact |
| `./scripts/autoload/combat_manager.gd` | `is_unit_busy` tail replaced; `_await_tween_safe` new; `_drain_action_queue` await replaced; `_damage_flash` binds `self`; walkable checks in `_execute_move`/`apply_knockback` | **Medium** — queue/await area; watchdog must be frame-driven (process-always timer) |
| `./scripts/characters/player.gd` | `basic_attack` branch; `_try_keyboard_attack`, `_pick_nearest_enemy_in_range`, `_try_attack_target` (extraction), `_apply_name_label`; `_try_move` walkable check | Medium — refactor of `_handle_click_targeting` must preserve exact click semantics |
| `./scripts/characters/enemy.gd` | `_apply_name_label()`; call from `setup()` | Low |
| `./scripts/ui/hud.gd` | `add_child` before `setup`; data-driven player name | Low |
| `./scripts/ui/health_bar.gd` | setup fallbacks + explicit `value`; `follow_character` clamp | Low |
| `./scripts/ai/ai_base.gd` | `_move_away` walkable check | Low |
| `./scripts/battlefield.gd` | unique enemy instance names | Low |
| `./scripts/autoload/tutorial_manager.gd` | 3 step-body strings | Low |
| `./playtest_spec.yaml` | `actions` + `surface` + new scenarios (thresholds by PM) | — |
| `./README.md` | controls/status docs | Low |

**Touched-file disjointness:** each of the medium-risk files is edited by exactly one subtask → component-local rollback (`git checkout -- <file>`).

---

## 5. Playtest Contract (scene / actions / surface + scenario skeletons)

The Architect defines the observable surface and scenario skeletons; **PM fills assert thresholds** and confirms the harness's max-frame budget with the verifier (defeat estimate: 7 tutorial presses + ~15–30 s of sim ⇒ 900–1800+ frames @60 fps).

### 5.1 scene & actions

```yaml
scene: "res://scenes/main.tscn"

actions:                # every name must exist in project.godot [input]
  - move_up
  - move_down
  - move_left
  - move_right
  - skill_1
  - skill_2
  - basic_attack        # NEW — hard contract with project.godot [input]
  - pause_game
  - ui_accept
```

### 5.2 surface (hard contract — node names / script-variable names must match verbatim)

```yaml
surface:
  HUD:            [visible]
  Player:         [health, max_health, grid_pos, global_position, selected_skill_index]
  HealthBar:      [visible, global_position]
  East_Heretic:   [fsm_state, health, max_health, grid_pos]   # NEW — enemy instance names set in battlefield.gd
  West_Poison:    [fsm_state, health, max_health, grid_pos]
  South_Emperor:  [fsm_state, health, max_health, grid_pos]
  North_Beggar:   [fsm_state, health, max_health, grid_pos]
  Central_Divine: [fsm_state, health, max_health, grid_pos]
  GameManager:    [current_state]                             # NEW — autoload node in tree
```

- All pre-existing names (`HUD`, `Player`, `HealthBar`, `visible`, `health`, `max_health`, `grid_pos`, `global_position`, `selected_skill_index`) are preserved.
- `HealthBar` resolves to the first (player's) bar; label-text asserts (if the harness supports child access) use e.g. `HealthBar.NameLabel.text` — PM verifies expression syntax with the verifier; fallback is bar-visibility asserts.
- If per-enemy named surface entries turn out unsupported, fallback is a single `Enemy` entry (first match = East Heretic) — PM confirms with verifier before finalizing.

### 5.3 Scenario skeletons (thresholds & final frames are PM-owned)

**S1 `health_bar_visibility_on_startup`** *(existing, keep)* — frame 5, no presses, HUD+HealthBar visible, HealthBar at non-zero position. PM: optionally add `HealthBar.NameLabel.text != "Name"` (label-fix proof).

**S2 `health_bar_follows_player_movement`** *(existing, keep)* — 7× `ui_accept` at frames 3,5,7,9,11,13,15 (tutorial → battle starts), `move_right` at 17, assert at 20. (Space-free `pause_game` guarantees `ui_accept` can't freeze the sim — F7 is load-bearing here.)

**S3 `no_runtime_errors_on_launch`** *(existing, keep)* — frame 2, HUD visible, no `Invalid call`/`Nonexistent function`.

**S4 `enemy_ai_approaches_player`** *(NEW, differential)*
```yaml
timeline:
  - { at: 3,  actions: [ui_accept] }
  - { at: 5,  actions: [ui_accept] }   # ×7 total through frame 15 (battle starts)
  - ... (frames 7,9,11,13,15)
  - { at: 120, actions: [], assert: { West_Poison.fsm_state: "<PM: != 'IDLE' (changed-style differential)>" } }
  - { at: 300, actions: [], assert: { Player.health: "<PM: < Player.max_health>" } }
```
Proves: F1+F2 unblocked AI (West Poison rushes from (11,2)); player untouched → health only drops if enemies act.

**S5 `keyboard_basic_attack_hits_enemy`** *(NEW — the user story)*
```yaml
timeline:
  - 7× ui_accept at frames 3..15 (tutorial complete)
  - { at: 20, actions: [move_up] }     # (7,5) → (7,4); ≥0.25 s cadence between moves (is_moving gate)
  - { at: 35, actions: [move_up] }     # (7,3)
  - { at: 50, actions: [move_up] }     # (7,2) — adjacent to Central Divine (7,1), who does not kite
  - { at: 65, actions: [basic_attack] }
  - { at: 200, actions: [], assert: { Central_Divine.health: "<PM: < Central_Divine.max_health>" } }
```
Deterministic: Central Divine is the unique nearest enemy from (7,2) (dist 1 vs ≥4), passive, and `enemies_alive` order makes ties impossible. PM may add a second `basic_attack` press + assert for the skill path (press `skill_1`, then `basic_attack` fires Sorrowful Palms at nearest).

**S6 `defeat_by_standing_still`** *(NEW — terminal scenario)*
```yaml
timeline:
  - 7× ui_accept at frames 3..15, then NO further input (player stands at (7,5))
  - { at: 300,  actions: [], assert: { West_Poison.fsm_state: "<PM: != 'IDLE'>" } }
  - { at: 600,  actions: [], assert: { Player.health: "<PM: < initial>" } }
  - { at: <PM: terminal frame>, actions: [], assert: { GameManager.current_state: "<PM: == 'LOST'>" } }
```
Aggressive AIs (West Poison, North Beggar, South Emperor + East Heretic at his attack range) converge and kill the standing player; `GameManager.current_state` flips to `"LOST"`. Terminal frame ≈ 900–1800 @60fps; **PM must confirm the gate's max-frames budget with the verifier** — if budget is too tight, drop the `600` checkpoint rather than the terminal assert. This scenario also regression-tests F5: no soft-lock after lethal damage.

**S7 `victory_by_keyboard`** *(OPTIONAL — include only if the frame budget allows ~60–120 s sim)*: tutorial, then scripted movement + `basic_attack`/`skill_1`/`skill_2` presses until all five Greats die; terminal assert `GameManager.current_state == "WON"`. Lower priority than S6 (defeat is the faster, equally valid terminal proof).

**Timing notes for PM:** AI tick = 0.5 s; move tween 0.15 s; shared FIFO queue serializes all 6 actors (≈0.75–1.25 s per full cycle); DoT ticks can kill the player between AI actions; keep scenarios pause-free (headless determinism); stop pressing after terminal frames (input is ignored in WON/LOST anyway).

---

## 6. Technical Stack

| Concern | Choice | Rationale |
|---|---|---|
| Language/engine | Godot 4 / GDScript, existing project | Zero new dependencies; `.gd` parsed by the harness `--compile` gate |
| Input | Godot InputMap actions declared in `project.godot [input]` (`basic_attack`, physical `J=74`) | The gate injects actions by name; built-in `_unhandled_input` flow reused — no custom key system |
| Pathfinding | Existing `AStar2D` graph kept as **static geometry**; occupancy enforced at move time; border ring disabled once in `setup_grid()` | Fixes the disabled-endpoint empty-path bug (F2) with the smallest possible change; `_move_toward`'s `path[1]` + occupancy re-check remains the safety net |
| Targeting | Nearest-enemy-in-range with stable tie-break over `enemies_alive` order | Deterministic for the playtest gate; no facing state added (explicit non-goal) |
| Queue safety | Tween `bind_node(self)` for the flash + `_await_tween_safe` frame-capped watchdog (`create_timer(0.6, true)`) | Killed tweens never emit `finished`; the cap guarantees the queue drains after any death |
| Layout | Border ring non-walkable + health-bar clamp + pinned 1088×832 viewport | Matches painted walls and the backdrop's native size; no zoom hacks |
| Verification | `run_tests.sh` unchanged (`--compile` + `--playtest`) + frame-capture review | Existing gate; new scenarios are the regression net |

---

## 7. Migration & Rollback Plan (irreversible-op safety)

All changes are file edits (git-reversible), but the constraint requires **backup → execute → verify → only then delete** ordering. Protocol for the implementer:

1. **Baseline:** before starting, ensure the repo is committed (or `cp` each medium-risk file to a temp backup, e.g. `combat_manager.gd.bak`) so every edit has a restore point. Backups are never part of the deliverable.
2. **Execute in dependency order** (see §8 tasks T1→T7), each task touching disjoint files; run `run_tests.sh` after **every** task. No task deletes anything before its replacement is verified by the gate.
3. **Verify new state:** gate green per task; after T4 verify the keyboard path (S5 scenario), after T1/T2 verify AI approach (S4), after all tasks run the full scenario set + frame-capture review (names legible, no top-edge clipping, Victory/Defeat overlay text correct).
4. **Only after verification:** remove now-dead lines if any (the only deletions are the two `set_point_disabled` lines in `reserve_tile`/`free_tile` and the Space binding — each is verified by the task gate before the next task starts). No file is ever "delete then rewrite".
5. **Rollback path (any gate failure):** `git checkout -- <file>` (or restore from the `.bak` copy) per task; because tasks touch disjoint files, rollback is component-local with no cross-file undo ordering. No schema, no data migration, nothing non-reversible.

---

## 8. Suggested Task Decomposition for PM (ordered, each ends with a `run_tests.sh` gate)

1. **T1 — GridManager walls & static graph (F2, F6):** `is_walkable()`; ring-disabled `setup_grid()`; drop occupancy point-toggling; walkable checks in `move_unit`/`get_move_range`; `ai_base._move_away` walkable check. *Gate:* compile + existing scenarios still green (no behavior observable yet — walls only exclude tiles nothing uses).
2. **T2 — CombatManager unblock + queue safety (F1, F5, F6):** busy-check fix; `_await_tween_safe` + drain replacement; flash binds `self`; walkable checks in `_execute_move`/`apply_knockback`. *Gate:* compile green; S4 (AI approach) becomes meaningful after T3 lands.
3. **T3 — Input & config (F4 decl, F7, F6 viewport):** `project.godot`: +`basic_attack`, `pause_game` → Escape-only, +`[display]` viewport. *Gate:* compile green (action unused yet).
4. **T4 — Keyboard attack (F4):** `player.gd` branches + refactor (`_try_attack_target` extraction must be behavior-neutral for clicks), `_try_move` walkable check. *Gate:* S2 still green (click path untouched) + S5 skeleton keyable.
5. **T5 — Labels & HUD (F3):** `hud.gd` reorder + data-driven name; `health_bar.gd` setup fallbacks + clamp; `enemy.gd`/`player.gd` `_apply_name_label()`; `battlefield.gd` unique enemy names. *Gate:* compile + S1 green (label asserts optional here).
6. **T6 — Copy & docs:** `tutorial_manager.gd` step bodies; `README.md` update. *Gate:* compile green.
7. **T7 — Playtest contract:** `playtest_spec.yaml` actions/surface/scenarios with PM-filled thresholds. *Gate:* full `run_tests.sh` green with S4/S5/S6 (+S7 if budget allows) + final frame-capture review for the legibility criteria.

---

## 9. Extensibility Considerations

- **Facing-based targeting later:** `_try_keyboard_attack` is a single entry point; adding "prefer enemy in last-move direction" is a local change to `_pick_nearest_enemy_in_range` without touching the click path.
- **New characters/enemies:** add a `CharacterData` + position entry in `battlefield.gd` (names become surface entries automatically via the `character_name` → node-name rule).
- **More input bindings:** new actions follow the same `Object(InputEventKey,...)` block pattern; the gating table in `TutorialManager` already supports arbitrary action names.
- **AI tuning:** personalities remain pluggable `RefCounted` controllers; nothing in this design constrains future `evaluate()` changes.
- **Watchdog constant:** `TWEEN_TIMEOUT_SEC` is the single knob if action animations ever grow beyond 0.6 s.

---

## 10. Design Decisions Log

- **D1 — Nearest-enemy targeting over facing.** No facing state exists in the codebase; adding one (last-move direction + fallback) increases surface and nondeterminism. Nearest-in-range with `enemies_alive`-order tie-break is fully deterministic and shares one routine with the click path.
- **D2 — Static AStar graph (remove occupancy disabling) vs. endpoint re-enable.** Static geometry matches "grid geometry is static"; `_move_toward` already re-validates occupancy per step, so graph-level occupancy was redundant and only broke endpoint queries (Godot returns `[]` when an endpoint is disabled).
- **D3 — Wall ring as `is_walkable()` + AStar-disable, not an `is_in_bounds` change.** `is_in_bounds` is consumed everywhere with "inside the rect" semantics; a new predicate confines the behavioral change to movement call sites and matches the painted walls.
- **D4 — Both tween-safety mechanisms (bind `self` + watchdog).** Binding the flash to `CombatManager` makes the common kill path safe by construction; the watchdog additionally covers move tweens bound to units that die mid-move (DoT ticks) and any future bound tween. Awaiting a killed tween hangs silently — this is a class of bug, so the queue gets a hard cap.
- **D5 — Enemy instance names (`East_Heretic`, …) as a surface extension.** Per-enemy assertions would otherwise be ambiguous (five nodes all named `Enemy`); the existing spec has no `Enemy` entry, so this is additive and gameplay-neutral.
- **D6 — Viewport pinned to 1088×832.** Matches the backdrop's native size exactly (no letterboxing math), keeps the camera at (480,352) untouched, and makes screen-space clamps deterministic in headless captures.
- **D7 — `pause_game` Escape-only.** Space must be free for `ui_accept` (tutorial advancement) — a Space press that both advances the tutorial and freezes `Engine.time_scale` would desync every scenario. The action remains declared (scenario surface unchanged).
- **D8 — Label fix uses both reorder and `get_node_or_null`.** Reorder fixes HUD bars; `get_node_or_null` fallbacks make `setup()` order-independent for every future caller (the enemy/player pattern already exists for visuals).

---

## 11. Non-Goals (explicit)

- No AI rewrite or rebalancing (personalities, ranges, damages, cooldowns stay as authored).
- No new autoloads, scenes, assets, or UI layout redesign (bars, buttons, overlays keep their structure).
- No gamepad/touch support, no save system, no menus, no multi-scene flow.
- No facing system; no target-cursor UI.
- No changes to `resources.md`, `run_tests.sh`, or the three existing scenarios' observable semantics.
- Central Divine's passive `_last_attacked_time` behavior is documented, not "fixed".
