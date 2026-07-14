# Technical Architecture Design — Godot 3→4 API Migration Fix

## Overview

A targeted fix for the single Godot 3→4 API mismatch found in the Huashan Sword Tournament codebase: `Camera2D.unproject_position()` in `scripts/ui/health_bar.gd:81`. The fix replaces the removed Godot 3 API with the Godot 4 canonical equivalent using `Camera2D.get_canvas_transform()`. A comprehensive audit of all 19 `.gd` files confirmed no other API mismatches exist.

---

## Problem Statement

**Runtime error**: `Invalid call. Nonexistent function 'unproject_position' in base 'Camera2D'.`

In Godot 3, `Camera2D.unproject_position(world_position)` converted a world coordinate to a screen/viewport coordinate. This method was **removed** from `Camera2D` in Godot 4. It still exists on `Camera3D` but not on `Camera2D`.

The affected code (`health_bar.gd`, method `follow_character()`):

```gdscript
# Line 81 — BROKEN in Godot 4:
var screen_pos: Vector2 = camera.unproject_position(_char_node.global_position)
global_position = screen_pos + Vector2(-60, -50)
```

This causes floating health bars to fail to follow characters on screen, and generates a runtime error on every frame.

---

## Architecture Diagram (text)

```
┌──────────────────────────────────────────────────────┐
│  health_bar.gd  :  follow_character()                │
│                                                      │
│  World Position  ──►  Canvas Transform  ──►  Screen  │
│  (_char_node         (camera.get_                    (viewport
│   .global_position)   canvas_transform())             coords)
│                                                      │
│  Screen Pos + Offset(-60,-50) → global_position      │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │  Fix: Replace camera.unproject_position()    │    │
│  │  with camera.get_canvas_transform() * pos    │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  Codebase Audit (all 19 .gd files)                   │
│                                                      │
│  Scripts checked:                                    │
│  scripts/ui/         health_bar.gd ← ONLY BUG        │
│                      hud.gd, skill_button.gd,        │
│                      pause_button.gd,                │
│                      tutorial_step.gd                │
│  scripts/autoload/   game_manager.gd,                │
│                      grid_manager.gd,                │
│                      combat_manager.gd,              │
│                      tutorial_manager.gd             │
│  scripts/characters/ player.gd, enemy.gd             │
│  scripts/ai/         ai_base.gd, ai_*.gd (×5)       │
│  scripts/data/       character_data.gd,              │
│                      skill_data.gd                   │
│  scripts/            battlefield.gd                  │
│                                                      │
│  All pass Godot 4 validation — zero mismatches.     │
└──────────────────────────────────────────────────────┘
```

---

## Component Specifications

### Component 1: `health_bar.gd` — Camera2D world-to-screen conversion fix

**File**: `scripts/ui/health_bar.gd`
**Lines affected**: 81 (one line)
**Risk**: Minimal — single-line change, deterministic behavior

**Current (broken) code** (line 81):
```gdscript
var screen_pos: Vector2 = camera.unproject_position(_char_node.global_position)
```

**Fix — Option A (recommended): `get_canvas_transform()`**

```gdscript
var screen_pos: Vector2 = camera.get_canvas_transform() * _char_node.global_position
```

This is the canonical Godot 4 approach. `get_canvas_transform()` returns a `Transform2D` that encodes the camera's position, zoom, rotation, and offset. Multiplying a world position by this transform yields the corresponding screen/viewport coordinate.

**Why this is the right choice**:
- **One-liner** — minimal diff, no refactoring needed
- **Correct at all zoom levels** — the transform inherently includes `camera.zoom`
- **Accounts for Camera2D smoothing** — `position_smoothing` and `drag_margins` are baked into the canvas transform automatically
- **Standard Godot 4 pattern** — documented in migration guides and official examples

**Fix — Option B (fallback): manual math**
```gdscript
var screen_pos: Vector2 = (_char_node.global_position - camera.global_position) * camera.zoom + camera.get_screen_center_position()
```

More explicit but fragile: `get_screen_center_position()` does NOT include zoom, so manual zoom multiplication is required. Option A is strictly better for this use case.

**Design decision**: Use Option A (`get_canvas_transform()`) exclusively. No fallback needed.

**Verification contract**:
- Health bars must follow their characters at the same `(-60, -50)` screen offset as before
- Must work correctly when the camera zooms (even though this project uses fixed zoom, correctness under zoom is a quality gate)
- Must NOT produce any runtime errors when `follow_character()` is called

**Edge cases handled by existing code (no changes needed)**:
- **Null camera** (line 78): `if camera == null: return` — unchanged
- **Invalid/dead character** (lines 68–75): `is_instance_valid` + health ≤ 0 check — unchanged
- **Screen edge clipping**: The `(-60, -50)` offset may push bars off-screen at edges — pre-existing behavior, out of scope

---

### Component 2: Codebase API Audit (verification-only, no code changes)

**Scope**: All 19 `.gd` files under `scripts/`
**Method**: Grep-based systematic scan for Godot 3→4 API patterns

**Audit checklist — all pass**:

| Godot 3 API | Godot 4 Replacement | Status |
|---|---|---|
| `Camera2D.unproject_position()` | `get_canvas_transform() * pos` | **FOUND in health_bar.gd:81 — to fix** |
| `camera.unproject_position()` (any form) | — | Only the one instance above |
| `emit_signal("name", args)` | `signal_name.emit(args)` | ✓ All use `.emit()` |
| `.instance()` | `.instantiate()` | ✓ All use `.instantiate()` |
| `yield(...)` | `await ...` | ✓ No `yield` found |
| `onready var x` | `@onready var x` | ✓ All use `@onready` |
| `export var x` | `@export var x` | ✓ All use `@export` |
| `array.empty()` | `array.is_empty()` | ✓ All use `is_empty()` |
| `node.free()` (for deferred) | `node.queue_free()` | ✓ No inappropriate `free()` |
| `Tween.new()` (old manual Tween) | `create_tween()` | ✓ All use `create_tween()` |
| `signal.connect(obj, "method")` | `signal.connect(callable)` | ✓ All use Callable syntax |
| `TileMap.set_cellv()` | `TileMap.set_cell()` | ✓ All use `set_cell()` |
| `ImageTexture.new()` then `.create_from_image()` | `ImageTexture.create_from_image()` static | ✓ All use static method |
| `Color("gold")` string | `Color.GOLD` constant | ✓ All use constants |
| `HALIGN_CENTER` etc. | `HORIZONTAL_ALIGNMENT_CENTER` | ✓ All use Godot 4 enum names |

**Conclusion**: The ONLY Godot 3→4 API mismatch in the entire codebase is `camera.unproject_position()` at `scripts/ui/health_bar.gd:81`.

---

## Data Flow (health bar screen positioning)

```
Every frame:
  HUD._process(delta)
    └► health_bar.follow_character()
         │
         ├─ 1. Validate _char_node is valid & alive
         ├─ 2. Get Camera2D via get_viewport().get_camera_2d()
         ├─ 3. Null-guard: if camera == null → return
         ├─ 4. Convert world → screen:
         │      screen_pos = camera.get_canvas_transform() * _char_node.global_position
         ├─ 5. Apply offset:
         │      global_position = screen_pos + Vector2(-60, -50)
         └─ 6. Set visible = true
```

No changes to any other file. The HUD calls `follow_character()` in `_process()` — that call site is unchanged.

---

## Technical Stack

| Concern | Choice | Rationale |
|---|---|---|
| World-to-screen conversion | `Camera2D.get_canvas_transform()` | Canonical Godot 4 API; one-liner; correct under zoom, smoothing, drag |
| Verification method | Grep-based audit (19 files, 12 patterns) | Comprehensive; matches Step 1 SOTA methodology |
| Risk mitigation | Single-line change, no refactoring | Zero risk of regressions in other systems |

---

## Rollback Plan

The fix is a single-line substitution in one file. Rollback means reverting that one line. No schema changes, no data migration, no irreversible operations.

If the fix were to be reverted, the original line is:
```gdscript
var screen_pos: Vector2 = camera.unproject_position(_char_node.global_position)
```

No backup/snapshot needed — standard version control (git) suffices.

---

## Extensibility Notes

- **If other scripts ever need world-to-screen conversion**: They should use the same `camera.get_canvas_transform() * world_pos` pattern. A static utility function on `GridManager` could be added in the future if this pattern appears more than once, but for now the single use site in `health_bar.gd` does not warrant a shared utility.
- **If multiple viewports are added**: `get_viewport().get_camera_2d()` already returns the correct camera for the current viewport, so the fix is viewport-safe.
- **If camera anchor mode changes**: `get_canvas_transform()` inherently accounts for `anchor_mode`, so the fix works regardless of anchor configuration.

---

## Deliverable Documents (unchanged from existing)

The existing `README.md` and `resources.md` do not need modification — they describe gameplay and asset replacement, not internal API details.

---

## Playtest Specification (`playtest_spec.yaml`)

### scene
```yaml
scene: "res://scenes/main.tscn"
```

### actions
```yaml
actions:
  - move_up
  - move_down
  - move_left
  - move_right
  - skill_1
  - skill_2
  - pause_game
  - ui_accept
```

### surface (observable nodes and their script variables)
```yaml
surface:
  HUD:
    - visible
  HealthBar:
    - visible
    - global_position
  YangGuo:
    - health
    - grid_pos
    - global_position
```

### scenarios (skeleton — PM fills assertion thresholds)

```yaml
scenarios:
  - name: "health_bar_visibility_on_startup"
    description: "Verify floating health bars are visible and positioned correctly when the game starts."
    timeline:
      - at: 5
        actions: []
        assert:
          # PM: assert that HUD health bars are visible and near expected screen positions

  - name: "health_bar_follows_player_movement"
    description: "After the player moves, the health bar should update its screen position."
    timeline:
      - at: 3
        actions: [ui_accept]   # advance past tutorial welcome
      - at: 5
        actions: [ui_accept]   # advance past movement tutorial
      - at: 7
        actions: [ui_accept]   # advance past basic attack tutorial
      - at: 9
        actions: [ui_accept]   # advance past skill 1 tutorial
      - at: 11
        actions: [ui_accept]   # advance past skill 2 tutorial
      - at: 13
        actions: [ui_accept]   # advance past pause tutorial
      - at: 15
        actions: [ui_accept]   # start battle
      - at: 17
        actions: [move_right]
        assert:
          # PM: assert health bar screen position changed after move

  - name: "no_runtime_errors_on_launch"
    description: "The project should launch without any 'Invalid call' or 'Nonexistent function' errors."
    timeline:
      - at: 2
        actions: []
        assert:
          # PM: assert no runtime errors in Godot output
```
