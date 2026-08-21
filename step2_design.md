# Technical Architecture Design — Presentation-Layer Fix Program

**Project:** jinyong-ui — Huashan Sword Tournament (Godot 4 / GDScript tactical wuxia RPG; engine gate runs 4.4)
**Goal (this run):** fix **only the presentation layer**, with no gameplay, art, or asset regeneration:

1. The fixed-size window must fill and track the desktop instead of rendering the 960×704 board in a grey margin.
2. The battle HUD (skill bar + cooldowns) must be visible.
3. One name label per fighter — no duplicates, no overlap.
4. Top-row sprites must not poke above the illustrated battlefield.
5. The grid must align with the artwork.

**Inputs:** Step-1 SOTA report (`step1_sota.md`) + code/scene inspection performed in this step. All facts below are verified against the current repo, not line-numbered guesses from the report.

---

## 1. Overview

The combat/gameplay layer is complete and green (6 playtest scenarios pass). Every defect in this run is a **layout/config defect**: coordinates tuned by hand, a nested CanvasLayer pair, and a missing stretch configuration. The design is a **surgical presentation fix program** — 8 root causes, 8 small fixes, zero gameplay changes.

### 1.1 Root cause → fix map (all verified in current code)

| # | Defect (evidence) | Effect | Fix (component) |
|---|---|---|---|
| W1 | `project.godot [display]` pins `viewport_width=1088` / `viewport_height=832` and has **no** `window/stretch/*` keys (verified; grep shows 1088/832 only in `project.godot` + `README.md`). Board = 15×11 tiles × 64 px = 960×704 centred at camera (480,352) → a 64 px grey ring surrounds the board | Locked-size window; grey margin around the battlefield | Base size **960×704** (= board size, = backdrop size) + `window/stretch/mode="canvas_items"` + `window/stretch/aspect="keep"` + explicit `resizable=true`. §3.1 |
| W2 | `scenes/ui/hud.tscn` `SkillBar` (HBoxContainer): `anchor_left/right=0.5`, default `anchor_top/bottom=0`, `offset_top=-60`, `offset_bottom=-20` → rect y ∈ [−60,−20], **entirely above the viewport** (stale `anchors_preset=10` contradicts stored anchors) | Skill bar + cooldowns invisible → "invisible battle HUD" | Re-anchor bottom-center with positive offsets. §3.3 |
| W3 | `main.tscn` nests `HUDLayer`(CanvasLayer, layer=10) → `HUD`(CanvasLayer, layer=10, script) → **effective layer 20**; `hud.tscn` root is a CanvasLayer whose only reason to exist is the layer it adds | Confusing additive layer arithmetic; future re-parent or single-layer read misjudges ordering | Flatten: HUD root becomes a full-rect **Control** under `HUDLayer` (single layer=10). §3.2 |
| W4 | Two labels per fighter: `player.tscn`/`enemy.tscn` floating `NameLabel` (160 px wide, y ∈ [−48,−24], font 14 — adjacent fighters 64 px apart overlap by construction) **and** `health_bar.tscn` `NameLabel` (120 px, y=−18 above the bar) | "Yang GuWest Poison" overlaps; duplicate names | Delete the floating labels (nodes + `_apply_name_label()` code); the health-bar label survives, restyled to 64 px (≤1 tile), font 12, clip + ellipsis, **inside** the bar rect. §3.4 / §3.5 |
| W5 | `health_bar.tscn`: root Control `size=(120,30)`; `NameLabel` at `position=(0,-18)`, `size=(120,16)` → label rect **outside** the root rect. `health_bar.gd follow_character()` clamps by `size` (30) → a bar clamped to the top edge pushes its label off-screen | Label clipped against the viewport top | Restructure root rect to 120×40 with label y∈[0,16] and Bar y∈[18,40] — label inside the rect, so the existing clamp covers it automatically. §3.4 |
| W6 | Sprites are `centered=true`, `offset=(0,−h/2)` (feet at tile centre). `Central_Divine` spawns at grid (7,1) → world y=96 → sprite top = 96−h; `h>96` pokes above artwork top y=0 (h≈128 → top −32, visible against the grey margin today, clipped by the viewport edge after W1). Texture heights are not fixed in code (PNG dimensions unknown at design time) | Top-row sprite heads poke above the illustrated battlefield | Per-frame, per-texture clamp of the sprite rect into the artwork rect [0,960]×[0,704], keeping the feet anchor whenever possible; expose `sprite_top` for assertions. §3.6 |
| W7 | `battlefield.tscn` `SummitBackdrop` drawn at raw texture size centred on (480,352); board rect is exactly [0,960]×[0,704]. If the PNG is not exactly 960×704 the art and the tile grid don't coincide (grey slivers / shifted art) | Grid-vs-artwork misalignment | Programmatically fit the backdrop texture to the board rect at runtime; expose `board_aligned: bool`. §3.7 |
| W8 | `tutorial_overlay.tscn` `Panel`: anchors (0,0) with `offset_left=-300 … offset_bottom=200` → rect [−300,300]×[−200,200] anchored to the viewport's **top-left corner** — only the lower-right quarter is visible | Same defect class as W2 (hand-tuned offsets, no anchor preset); gets worse at the new 960×704 base | `PRESET_CENTER` anchors (0.5/0.5) with the same offsets. §3.3 |
| W9 | `health_bar.gd` converts world→screen with `camera.get_canvas_transform()` — per class docs this is camera offset/rotation/zoom only, it does **not** include the viewport's global (stretch) transform; HUD Controls live on a non-following CanvasLayer (window pixels) | Under `canvas_items` stretch, bars misplace by the stretch factor on resize | Use `get_viewport().get_final_transform()` (global × canvas). §3.4 |

### 1.2 Success criteria → verification mapping

| Brief criterion | Fix | Proof |
|---|---|---|
| Window fills/scales | W1 | `HUD.size == (960,704)` at the default window (base size applied); frame-capture review: no grey ring, backdrop edge == viewport edge |
| Visible battle HUD | W2+W3+W5 | New scenario S7: `SkillBar`/`SkillButton1`/`PauseButton` visible with rect inside the viewport during BATTLE; frame-capture review |
| One name label, no overlap | W4 | `Player`/enemy trees have no `NameLabel`; new scenario S8: `HealthBar.name_text == "Yang Guo"`, `HealthBar2.name_text == "East Heretic"`; frame-capture review (labels ≤ 1 tile wide, ellipsis) |
| No top-row poke | W6 | New scenario S9: `Central_Divine.sprite_top >= 0`, `East_Heretic.sprite_top >= 0`; frame-capture review |
| Grid/artwork aligned | W7 | New scenario S9: `Battlefield.board_aligned == true`; frame-capture review (board rect == artwork rect == viewport rect) |
| Regression-proof | all | All 6 existing scenarios pass **unchanged** (they are state-only and the default composition is pixel-identical at scale 1 — see D1) |

---

## 2. Architecture Diagram (text)

Scene tree after the fix (all names are the current contractual names — nothing renamed):

```
Main (Node2D)
├─ Camera (Camera2D @ (480,352), enabled)            — unchanged; view = exactly [0,960]×[0,704]
├─ Battlefield (Node2D, battlefield.gd)
│  ├─ SummitBackdrop (Sprite2D)                      — W7: scale/position fitted → spans [0,960]×[0,704]
│  ├─ Grid (TileMap)                                 — paints cells (0..14, 0..10) → [0,960]×[0,704] (unchanged)
│  └─ Characters (Node2D)
│     ├─ Player / East_Heretic / West_Poison / …     — W6: sprite offset clamped each frame; W4: no NameLabel child
├─ HUDLayer (CanvasLayer, layer=10, follow_viewport_enabled=false)
│  └─ HUD (Control, FULL_RECT, mouse_filter=IGNORE)  — W3: was a nested CanvasLayer(10) → effective 20; now single layer
│     ├─ HealthBarContainer (Control, FULL_RECT, mouse_filter=IGNORE)
│     │  └─ HealthBar ×6 (Control 120×40)            — W5: NameLabel(64w, y∈[0,16]) INSIDE rect; Bar (y∈[18,40])
│     ├─ SkillBar (HBoxContainer, bottom-center 320×40)  — W2: y∈[648,688] inside the 704-tall viewport
│     │  ├─ SkillButton1 / SkillButton2
│     └─ PauseButton (top-right; current offsets fit 960×704 — verified, keep)
└─ TutorialLayer (CanvasLayer, layer=100, follow_viewport_enabled=false)
   └─ TutorialOverlay (tutorial_step.gd)
      ├─ Dim (FULL_RECT)
      └─ Panel — W8: PRESET_CENTER (0.5/0.5) ± offsets → centred at (480,352)
```

**Layer order (global, ascending):** world (0) → `EndGameOverlay` (50, created by `game_manager.gd`) → HUDLayer (10→now effectively 10) → TutorialLayer (100). Wait — effective order is by numeric layer: world 0 < HUD 10 < EndGameOverlay 50 < Tutorial 100. Unchanged from today except HUD's effective layer drops from 20 to 10 — still between world and EndGameOverlay, so no ordering regression.

**Data flow — window/stretch (W1):** project base size (960×704) → root viewport/window at 960×704 (scale 1, pixel-identical composition) → on user resize, `canvas_items` scales the 2D canvas to fit and `keep` letterboxes with engine-black bars outside the design rect; non-following UI layers live in window-pixel space (SOTA edge case) and pin to window edges. The grey-margin world can never reappear because the viewport's design space **is** the board.

**Data flow — health bar (W4/W5/W9):** `hud.gd _process()` → each bar `follow_character()` → `screen_pos = get_viewport().get_final_transform() * char.global_position` → `+= (−60,−50)` → clamp to `[4, vp − size − 4]` (size=120×40, label included) → `global_position = screen_pos`. At the default window (scale 1) `get_final_transform()` ≡ the old `camera.get_canvas_transform()` → existing scenario `health_bar_follows_player_movement` stays green; on resize the bars stay glued to their characters.

**Data flow — sprite clamp (W6):** character `_process()` (before any state-gated early return) → `GridManager.clamp_sprite_offset(position, texture_size)` → if `sprite.offset != desired`: update offset; update `sprite_top = position.y + offset.y − h/2`. Continuous in `position`, so it also corrects smoothly mid-tween.

**Data flow — backdrop fit (W7):** `battlefield.gd _ready()` → after TileMap setup: `_fit_backdrop_to_board()` → computes `scale = board_size / texture_size`, `position = board_size / 2` → sets `board_aligned` by comparing the resulting rect against [0,960]×[0,704].

---

## 3. Component List & Interfaces

Unchanged contracts (byte-stable unless listed): `CombatManager`, `GameManager` (overlay uses presets → auto-adapts to the new base size), `TutorialManager` logic (no logic change; layout of the overlay panel only), all 5 `AIController*`, `skill_data.gd`, `character_data.gd`, all signals, `grid_manager.gd` grid math (`TILE_SIZE=64`, `GRID_ORIGIN=(32,32)`, `is_walkable`, spawn positions), all existing surface node/variable names.

### 3.1 Component A — Display & window config (`project.godot`)

- **Responsibility:** base size == board size; engine-managed fill/letterbox.
- **Interface change** — replace the current `[display]` section with:

```ini
[display]

window/size/viewport_width=960
window/size/viewport_height=704
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

- **Why 960×704:** the board, the backdrop and the camera view are all exactly 960×704; the base size becomes the board, so the grey margin is removed *outright* and the camera/viewport math (`camera (480,352)` → view [0,960]×[0,704]) needs **zero** change. Shrinking the design space also shrinks the space HUD Controls anchor in — which is why W2/W8 re-anchor the two hand-tuned Controls (see §3.3). `HealthBarContainer` and the end-game overlay are already FULL_RECT presets and adapt automatically.
- **Why `canvas_items` + `keep`:** `canvas_items` scales the 2D world at the window resolution and keeps vector text crisp (the "legible HUD" criterion — `viewport` mode upscales a base-size raster and blurs text); `keep` guarantees the board aspect is preserved and letterboxes with engine-black bars, so the grey margin can never re-enter through window shape. `disabled` is today's bug; `expand`/`keep_width`/`keep_height` grow the viewport beyond the design size and re-expose the margin world.
- **Verification:** at the default 960×704 window the stretch factor is exactly 1 — the composition is pixel-identical to a no-stretch 960×704 setup, so every existing state assertion is unaffected and captures are deterministic. `HUD.size == (960,704)` proves the base size landed.

### 3.2 Component B — CanvasLayer flattening (`scenes/main.tscn`, `scenes/ui/hud.tscn`, `scripts/ui/hud.gd`)

- **`main.tscn`:** keep `HUDLayer` (CanvasLayer, layer=10) as the single UI layer; add the explicit contract `follow_viewport_enabled = false` to `HUDLayer` **and** `TutorialLayer` (default today, written for documentation).
- **`hud.tscn` root node:** change type `CanvasLayer` → `Control`, set FULL_RECT (`anchors_preset=15`, `anchor_right=1.0`, `anchor_bottom=1.0`) and `mouse_filter=2` (IGNORE — clicks fall through to the world canvas; buttons keep their own handling). **Delete** the now-invalid `layer = 10` property. The HUD scene then contributes no layer of its own: effective layer = 10, exactly the value the name implies.
- **`hud.gd`:** `extends CanvasLayer` → `extends Control`. Nothing else in the script touches the layer or the CanvasLayer API; `setup()`, `_process()` (bar follow), `_populate_skill_buttons()` and signal handlers are unchanged.
- **Caller compatibility (verified):** `battlefield.gd _wire_hud()` looks up `HUDLayer` (a CanvasLayer with no `setup`) and descends to its `HUD` child (`target = hud.get_node_or_null("HUD")`), then calls `target.setup(player, enemies)`. With HUD as a Control child of HUDLayer this path is unchanged — `setup()` still runs. The playtest surface's `HUD: [visible]` resolves to the same node name; `visible` exists on Control.

### 3.3 Component C — HUD & overlay layout (`scenes/ui/hud.tscn`, `scenes/ui/tutorial_overlay.tscn`)

- **`SkillBar`** (HBoxContainer) — replace the stale preset/offsets with an explicit bottom-center layout:

```
anchors_preset = 7            # CENTER_BOTTOM — consistent with the stored anchors this time
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -160.0
offset_top = -56.0
offset_right = 160.0
offset_bottom = -16.0
```

  Result: 320×40 bar at y∈[648,688] inside the 960×704 viewport (x∈[320,640]), 16 px above the bottom edge, sitting over the bottom border-wall tile row (non-walkable, so it never covers a fighter). Both 140×40 skill buttons + 4 px separation (284 px) fit. No script change needed (`hud.gd` already reads `$SkillBar` and its Button children).
- **`PauseButton`** — **keep as-is** (verified): `anchors_preset=3` (top-right), `anchor_right=1.0`, offsets −140/8/−8/44 → rect x∈[820,952], y∈[8,44] — fully inside the 960×704 viewport and clear of the SkillBar. Its 132×36 rect fits "⏸ Pause". Re-anchoring is *not* required despite the base-size shrink; the verification task asserts it in-frame.
- **`TutorialOverlay/Panel`** (W8) — add `PRESET_CENTER` anchors so the panel is centred at (480,352):

```
anchors_preset = 8            # CENTER
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
# keep the existing offsets (-300/-200/300/200) — they now measure from the centre
```

  Children (`Title`, `Body`, `Buttons`) keep their panel-relative offsets. No script change (`tutorial_step.gd`/`tutorial_manager.gd` reference children by path only).

### 3.4 Component D — Health bar component (`scenes/ui/health_bar.tscn`, `scripts/ui/health_bar.gd`)

- **`health_bar.tscn` restructure** — the invariant: **every child rect lies inside the root Control rect**, so `follow_character()`'s clamp by `size` covers the label too:

```
HealthBar (Control, size = (120, 40), mouse_filter = 2, script)
├─ NameLabel (Label)
│    anchor_left = 0.5 / anchor_right = 0.5          # centred on the bar
│    offset_left = -32 / offset_right = 32           # width 64 == one tile: adjacent fighters
│    offset_top = 0 / offset_bottom = 16             # (64px apart) can never overlap by construction
│    horizontal_alignment = 1
│    clip_text = true
│    text_overrun_behavior = 3                       # OVERRUN_TRIM_ELLIPSIS
│    theme_override_font_sizes/font_size = 12
└─ Bar (ProgressBar, size = (120, 22), position = (0, 18), show_percentage = false)
```

  The name sits **above** the bar, both inside the 120×40 root. Long names ellipsize ("South Emper…") rather than collide — the brief-accepted trade-off of the 1-tile rule.
- **`health_bar.gd` changes:**
  - New observable `var name_text: String = ""` — set in `setup()` to the same string written to the label (`name_text = char_name`). The playtest surface references the script variable, not the child node.
  - `follow_character()` — replace the camera lookup + `camera.get_canvas_transform()` with:

```gdscript
var screen_pos: Vector2 = get_viewport().get_final_transform() * _char_node.global_position
screen_pos += Vector2(-60, -50)      # unchanged offset: label above bar above the character
var vp: Vector2 = get_viewport_rect().size
global_position = Vector2(
    clampf(screen_pos.x, 4.0, vp.x - size.x - 4.0),
    clampf(screen_pos.y, 4.0, vp.y - size.y - 4.0))
```

  `size` is now 120×40, so the clamp accounts for the label automatically (W5). `get_final_transform()` = global (stretch) × canvas (camera) transform, so the bar stays glued to the character in window-pixel space at any stretch factor (W9). At the default scale-1 window this is numerically identical to the old conversion → the existing `health_bar_follows_player_movement` scenario passes unchanged. The camera-null guard can be dropped (`get_final_transform()` needs no camera reference) or kept harmlessly.
  - Everything else (signal wiring, color states, dead-hide) is unchanged.

### 3.5 Component E — Name label dedup (`scenes/player.tscn`, `scenes/enemy.tscn`, `scripts/characters/player.gd`, `scripts/characters/enemy.gd`)

- **Delete** the `NameLabel` nodes from both character scenes (the 160 px floating labels).
- **`player.gd` / `enemy.gd`:** delete `@onready var _name_label`, the `_apply_name_label()` functions, and their call sites (in `setup()` / `_ready()`). No other code references `_name_label` (verified). The single surviving label is the health-bar label (§3.4), fed by `hud.gd setup()` from `character_data.character_name` — already data-driven.
- **Surface safety:** the playtest surface contains no `NameLabel` entry under `Player`/enemies; `HealthBar` (and optionally `HealthBar2`) gain `name_text` instead, so the "real names in HUD" criterion is assertable without child-node access.

### 3.6 Component F — Sprite clamp to artwork (`scripts/autoload/grid_manager.gd`, `scripts/characters/player.gd`, `scripts/characters/enemy.gd`)

- **New static helper in `grid_manager.gd`** (GridManager owns board geometry):

```gdscript
## Offset for a centered sprite whose feet sit at `position` (offset (0,-h/2)),
## clamped so the whole texture rect stays inside the board artwork rect.
## Returns the preferred feet-anchor offset when no clamp is needed.
static func clamp_sprite_offset(position: Vector2, tex_size: Vector2) -> Vector2:
    var half: Vector2 = tex_size / 2.0
    var board: Vector2 = Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
    var offset := Vector2(0.0, -half.y)          # preferred: feet at node position
    var origin: Vector2 = position + offset
    var clamped := Vector2(
        clampf(origin.x, half.x, board.x - half.x),
        clampf(origin.y, half.y, board.y - half.y))
    return clamped - position
```

  (Guard: if `tex_size` exceeds the board on an axis, `half > board − half` — the implementer keeps the preferred offset on that axis rather than inverting the clamp.)
- **`player.gd` / `enemy.gd`:**
  - New observable `var sprite_top: float = 0.0`.
  - New private `_refresh_sprite_clamp()`; call it at the **top of `_process()`** of both scripts, *before* the existing `state != "BATTLE"` / paused early-returns (top-row enemies must be clamped during TUTORIAL too):

```gdscript
func _refresh_sprite_clamp() -> void:
    if _sprite == null or _sprite.texture == null:
        return
    var tex_size: Vector2 = _sprite.texture.get_size()
    var desired: Vector2 = GridManager.clamp_sprite_offset(position, tex_size)
    if _sprite.offset != desired:
        _sprite.offset = desired
    sprite_top = position.y + desired.y - tex_size.y / 2.0
```

  Continuous in `position` → correct during movement tweens and stable otherwise (the equality check makes the per-frame cost negligible for 6 nodes). For the top row (feet y=96, h=128) the sprite top clamps to exactly 0; feet shift at most `h − 96` px below the tile centre — the brief-accepted "adjust offset per-texture" behaviour. The node's `position` (grid math, pathing, targeting) is untouched.
- **No combat/UI dependency:** the clamp touches only the Sprite2D child of each character.

### 3.7 Component G — Backdrop fit to board (`scripts/battlefield.gd`)

- New observable `var board_aligned: bool = false`.
- New private `_fit_backdrop_to_board()`, called from `_ready()` after `_setup_tilemap()`:

```gdscript
func _fit_backdrop_to_board() -> void:
    if _backdrop == null or _backdrop.texture == null:
        return
    var tex_size: Vector2 = _backdrop.texture.get_size()
    if tex_size.x <= 0.0 or tex_size.y <= 0.0:
        return
    var board := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)   # (960, 704)
    _backdrop.scale = Vector2(board.x / tex_size.x, board.y / tex_size.y)
    _backdrop.position = board / 2.0                                        # centred → spans [0,board]
    var half: Vector2 = tex_size * _backdrop.scale / 2.0
    var top_left: Vector2 = _backdrop.position - half
    var bottom_right: Vector2 = _backdrop.position + half
    board_aligned = top_left.is_equal_approx(Vector2.ZERO) \
        and bottom_right.is_equal_approx(board)
```

  This guarantees artwork rect == tile-grid rect == viewport rect at the default window, whatever the PNG's native size — no art regeneration (non-goal), purely a presentation transform.

### 3.8 Component H — Docs (`README.md`)

- Update the presentation/window section: window opens at 960×704 (the board size), resizes with the desktop via `canvas_items` + `keep` (letterboxed, board aspect preserved); document the layout fixes (visible skill bar bottom-centre, single 1-tile name label per fighter with ellipsis, sprites clamped inside the artwork, backdrop fitted to the board). Controls unchanged (no input changes this run).

---

## 4. File-Level Change Specification (implementer contract)

All edits are surgical; no file is rewritten wholesale, no node/script name that the playtest surface references is renamed. Paths relative to repo root.

| File | Changes | Risk |
|---|---|---|
| `./project.godot` | `[display]`: viewport 960×704, `resizable=true`, stretch `canvas_items`+`keep` | Low (config) — but lands first; everything else is verified against it |
| `./scenes/main.tscn` | explicit `follow_viewport_enabled=false` on HUDLayer/TutorialLayer | Low |
| `./scenes/ui/hud.tscn` | root `CanvasLayer`→`Control` FULL_RECT (drop `layer=10`); SkillBar bottom-center offsets | Low-Medium — the root-type change must keep `setup()` reachable (verified path) |
| `./scripts/ui/hud.gd` | `extends Control` | Low |
| `./scenes/ui/tutorial_overlay.tscn` | Panel `PRESET_CENTER` anchors | Low |
| `./scenes/ui/health_bar.tscn` | root 120×40; NameLabel 64w/12pt/clip/ellipsis at y∈[0,16]; Bar at y∈[18,40] | Low |
| `./scripts/ui/health_bar.gd` | `name_text`; `get_final_transform()` conversion | Medium — conversion change guarded by existing S2 scenario |
| `./scenes/player.tscn` / `./scenes/enemy.tscn` | delete `NameLabel` nodes | Low |
| `./scripts/characters/player.gd` / `./scripts/characters/enemy.gd` | delete `_name_label` + `_apply_name_label()` + call sites; add `sprite_top` + `_refresh_sprite_clamp()` + `_process` call | Medium — deletions must not leave dangling refs (compile gate catches) |
| `./scripts/autoload/grid_manager.gd` | new static `clamp_sprite_offset()` | Low |
| `./scripts/battlefield.gd` | `board_aligned` + `_fit_backdrop_to_board()` + call in `_ready()` | Low |
| `./playtest_spec.yaml` | surface additions + scenarios S7/S8/S9 (thresholds by PM) | — |
| `./README.md` | presentation docs | Low |

**Touched-file disjointness:** each medium-risk file is edited by exactly one subtask → component-local rollback (`git checkout -- <file>`).

---

## 5. Playtest Contract (scene / actions / surface + scenario skeletons)

The Architect defines the observable surface and scenario skeletons; **PM fills assert thresholds** and confirms Expression syntax with the verifier.

### 5.1 scene & actions (unchanged)

```yaml
scene: "res://scenes/main.tscn"

actions:                # all already exist in project.godot [input] — no new actions this run
  - move_up
  - move_down
  - move_left
  - move_right
  - skill_1
  - skill_2
  - basic_attack
  - pause_game
  - ui_accept
```

### 5.2 surface (hard contract — node/variable names verbatim; **additions only, nothing renamed**)

```yaml
surface:
  HUD: [visible, size]                                                        # +size
  Player: [health, max_health, grid_pos, global_position, selected_skill_index, sprite_top]   # +sprite_top
  HealthBar: [visible, global_position, size, name_text]                      # +size, +name_text
  HealthBar2: [name_text]                                                     # NEW (optional — second bar = East Heretic)
  East_Heretic: [fsm_state, health, max_health, grid_pos, sprite_top]         # +sprite_top
  West_Poison: [fsm_state, health, max_health, grid_pos]
  South_Emperor: [fsm_state, health, max_health, grid_pos]
  North_Beggar: [fsm_state, health, max_health, grid_pos]
  Central_Divine: [fsm_state, health, max_health, grid_pos, sprite_top]       # +sprite_top
  SkillBar: [visible, size, global_position]                                  # NEW
  SkillButton1: [visible, text]                                               # NEW (text proves setup() ran)
  PauseButton: [visible, global_position]                                     # NEW
  GameManager: [current_state]
  Battlefield: [board_aligned]                                                # NEW
```

- All pre-existing entries preserved verbatim. New script variables (`size`, `name_text`, `sprite_top`, `board_aligned`) are plain members set by the scripts, so `Expression` evaluation works without method calls.
- `HealthBar` = the player's bar (first instantiated); `HealthBar2` = East Heretic's (enemy registration order is East Heretic, West Poison, South Emperor, North Beggar, Central Divine — deterministic). If the harness resolver cannot address `HealthBar2`/`SkillBar`/`SkillButton1`/`PauseButton` by name, PM drops those entries and keeps `HealthBar.name_text` (the primary label proof) — verify resolver behavior before finalizing.

### 5.3 Scenario skeletons (thresholds & final frames are PM-owned)

**S1–S6 — existing six scenarios are kept verbatim** (they prove gameplay; none of them touches the changed nodes beyond `HUD.visible`/`HealthBar` state, and at the default window the composition is unchanged — see D1).

**S7 `hud_layout_visible_during_battle`** *(NEW — proves W2/W3/W5)*
```yaml
timeline:
  - { at: 3,  actions: [ui_accept] }   # ×7 total through frame 15 — tutorial → BATTLE
  - { at: 5,  actions: [ui_accept] }
  - { at: 7,  actions: [ui_accept] }
  - { at: 9,  actions: [ui_accept] }
  - { at: 11, actions: [ui_accept] }
  - { at: 13, actions: [ui_accept] }
  - { at: 15, actions: [ui_accept] }
  - at: 20
    actions: []
    assert:
      HUD.visible: true
      HUD.size: "<PM: == Vector2(960, 704) — proves the base-size change>"
      SkillBar.visible: true
      SkillBar.size.x: "<PM: > 0>"
      SkillBar.global_position.y: "<PM: inside viewport, e.g. 0 <= y and y + 40 <= 704>"
      SkillButton1.visible: true
      PauseButton.visible: true
      PauseButton.global_position.y: "<PM: >= 0>"
      GameManager.current_state: 'current_state == "BATTLE"'
```
Fails on today's build (SkillBar off-screen, HUD.size 1088×832) — the scenario is the regression net for the whole HUD cluster.

**S8 `health_bars_show_real_names_single_label`** *(NEW — proves W4/W5)*
```yaml
timeline:
  - 7× ui_accept at frames 3..15 (as S7)
  - at: 20
    actions: []
    assert:
      HealthBar.visible: true
      HealthBar.name_text: 'name_text == "Yang Guo"'
      HealthBar2.name_text: 'name_text == "East Heretic"'    # optional if resolver supports HealthBar2
      HealthBar.size.y: "<PM: >= 40 — label lives inside the bar rect>"
      HealthBar.global_position.y: "<PM: inside viewport>"
```

**S9 `top_row_sprites_inside_artwork_grid_aligned`** *(NEW — proves W6/W7)*
```yaml
timeline:
  - 7× ui_accept at frames 3..15 (as S7)
  - at: 20
    actions: []
    assert:
      Central_Divine.sprite_top: "<PM: >= 0.0>"
      East_Heretic.sprite_top: "<PM: >= 0.0>"
      Player.sprite_top: "<PM: >= 0.0>"
      Battlefield.board_aligned: true
```

Every new scenario contains key presses (the 7× `ui_accept`), and the terminal-game requirement remains satisfied by the existing `defeat_by_standing_still` (S6). Frame-capture review items for the verifier (visible in PNGs, not in snapshots): no grey ring (backdrop edge == frame edge at 960×704), no overlapping labels, skill bar at the bottom, tutorial panel centred.

---

## 6. Technical Stack

| Concern | Choice | Rationale |
|---|---|---|
| Language/engine | Godot 4 / GDScript, existing project | Zero new dependencies; `.gd` parsed by the harness `--compile` gate |
| Window/stretch | Built-in `canvas_items` + `keep`, base 960×704, `resizable` | Engine-native; removes the grey margin by making base == board; crisp text; deterministic scale-1 default |
| Layering | Single `HUDLayer` CanvasLayer (10) + Control root, `follow_viewport_enabled=false` everywhere | Flattened additive nesting; HUD always above the world canvas regardless of `z_index` |
| Layout | Built-in Control anchors/offsets (bottom-center, CENTER presets) | Standard engine mechanism; no custom layout code |
| Labels | Built-in `Label` `clip_text` + `OVERRUN_TRIM_ELLIPSIS`, width = 1 tile | Guarantees zero overlap by construction |
| World→screen | `Viewport.get_final_transform()` | The documented stretch-aware replacement for bare `camera.get_canvas_transform()`; keeps bars glued at any window size |
| Sprite clamp | Static pure function over position/texture/board constants | Presentation-only, per-frame, continuous under tweens; no asset changes |
| Verification | `run_tests.sh` unchanged + extended `playtest_spec.yaml` + frame-capture review | Existing gate; new scenarios are the regression net |

---

## 7. Migration & Rollback Plan (irreversible-op safety)

All changes are file edits (git-reversible), but the constraint requires **backup → execute → verify → only then delete** ordering:

1. **Baseline:** ensure the repo is committed before starting (or `cp` each medium-risk file to a temp `.bak`). Backups are never part of the deliverable.
2. **Execute in dependency order** (§8 tasks T1→T7), each task touching disjoint files; run `run_tests.sh` after **every** task. No task deletes anything before its replacement is verified by the gate.
3. **Deletions are the last act of their task, gated:** the `NameLabel` nodes and `_apply_name_label()` code are removed only after the health-bar label restyle (§3.4) compiles and S1/S8 pass; the `layer=10` line on the HUD root is removed in the same edit that retypes the node (never a standalone delete).
4. **Verify new state:** gate green per task; after T5 run the full scenario set; final frame-capture review (no grey margin, no label overlap, no top poke, centred tutorial panel, visible skill bar).
5. **Rollback path (any gate failure):** `git checkout -- <file>` (or restore `.bak`) per task; tasks touch disjoint files, so rollback is component-local with no cross-file undo ordering. No schema, no data migration, nothing non-reversible.

---

## 8. Suggested Task Decomposition for PM (ordered, each ends with a `run_tests.sh` gate)

1. **T1 — Display config (W1):** `project.godot` `[display]` block (base 960×704, `resizable`, `canvas_items`+`keep`). *Gate:* compile green; all 6 existing scenarios still green (state-only, scale-1 identical).
2. **T2 — Layer flatten + HUD/overlay layout (W2/W3/W8):** `main.tscn` (explicit `follow_viewport_enabled=false`), `hud.tscn` (root→Control FULL_RECT, drop layer; SkillBar bottom-center), `hud.gd` (`extends Control`), `tutorial_overlay.tscn` (Panel CENTER). *Gate:* compile green; S7 skeleton keyable (HUD.size 960×704, SkillBar rect inside viewport).
3. **T3 — Health bar component (W4/W5/W9):** `health_bar.tscn` restructure; `health_bar.gd` (`name_text`, `get_final_transform()`). *Gate:* compile green; **existing S2 `health_bar_follows_player_movement` still green** (the conversion guard) + S1 green.
4. **T4 — Label dedup (W4):** delete `NameLabel` from `player.tscn`/`enemy.tscn`; delete `_name_label`/`_apply_name_label()` + call sites in both character scripts. *Gate:* compile green (dangling-ref check); S1/S8 green.
5. **T5 — Sprite clamp + backdrop fit (W6/W7):** `grid_manager.gd` static helper; `player.gd`/`enemy.gd` `sprite_top` + `_refresh_sprite_clamp()`; `battlefield.gd` `_fit_backdrop_to_board()` + `board_aligned`. *Gate:* compile green; S9 skeleton keyable; frame-capture review (no top poke, backdrop == frame).
6. **T6 — Playtest contract:** `playtest_spec.yaml` surface additions + S7/S8/S9 with PM-filled thresholds. *Gate:* full `run_tests.sh` green (S1–S9) + final frame-capture review for all four legibility criteria.
7. **T7 — Docs:** `README.md` presentation/window section. *Gate:* compile green.

---

## 9. Extensibility Considerations

- **New character textures:** the clamp is per-texture and measured at runtime — adding taller/wider sprites needs no code change; they clamp automatically.
- **New HUD widgets:** add them as children of the full-rect HUD Control and anchor with the same explicit-anchor pattern (never hand-tuned offsets with stale presets).
- **Different stretch taste:** `window/stretch/*` is a single config block; switching to `viewport` mode is one line (accepting blurry text), and the `get_final_transform()` conversion keeps bars correct under either.
- **Label policy knob:** name-label width (currently 1 tile = 64) and font size are two constants in one scene; widening later is a one-line edit with a known overlap trade-off.
- **Backdrop variants:** `_fit_backdrop_to_board()` is a pure fit-to-rect routine; swapping the PNG works as long as the board constants stay put.

---

## 10. Design Decisions Log

- **D1 — Base size 960×704 (+ stretch) instead of keeping 1088×832 with camera zoom.** The board/backdrop/camera are all exactly 960×704, so the margin is removed with zero camera/grid changes; at the default window the stretch scale is exactly 1 and every existing assertion value is bit-identical. Keeping 1088×832 requires zoom (uniform 17/15 leaves 17 px strips; 13/11 crops border art; non-uniform distorts) and changes `get_canvas_transform()` semantics for the health-bar math. Rejected: `expand`/`keep_width`/`keep_height` (grey margin leaks back), `viewport` stretch (blurry HUD text — fails legibility).
- **D2 — Flatten the nested CanvasLayer (HUD root → Control) rather than just zeroing the inner layer.** A nested layer reads as 20 while `HUDLayer.layer=10` promises 10 — the additive rule is the trap the SOTA flagged. A full-rect Control contributes no layer and gives the children a proper anchor space.
- **D3 — Health-bar label survives; floating labels die.** The surface contract references `HealthBar` only; the health-bar label is fed from the same `character_data` name. The survivor is constrained to 1 tile width with ellipsis — overlap becomes impossible for any adjacent pair, which a width cap on the 120 px bar alone would not guarantee.
- **D4 — Label moved *inside* the bar rect (root 120×40) instead of extending the clamp with label extents.** Both fix the clip; the former also makes `size`-based clamping, assertions and future tweaks correct by construction.
- **D5 — Per-frame sprite clamp over one-shot clamps at spawn/move-end.** Positions are tweened by `GridManager`/`CombatManager`; a per-frame idempotent clamp is continuous, immune to future movement code, and costs 6 cheap equality-guarded updates per frame.
- **D6 — Backdrop fitted programmatically instead of regenerating art.** Art regen is a non-goal; a runtime fit-to-rect transform fixes alignment for any PNG dimensions and stays correct if the asset is swapped.
- **D7 — Tutorial panel centring included (W8).** It is the same defect class as the skill bar (raw offsets, no anchors) and gets visibly worse at the 960×704 base; the fix is a pure layout edit with no script/logic impact on the tutorial flow the gate drives.
- **D8 — `get_final_transform()` over `camera.get_canvas_transform()`.** The former composes the viewport's global (stretch) and canvas (camera) transforms — the documented stretch-aware mapping into the window-pixel space where non-following-layer Controls live; identical to the old value at scale 1, so the existing movement-tracking scenario is the migration guard.

---

## 11. Non-Goals (explicit)

- No gameplay, AI, combat, balance, or skill changes; no changes to `CombatManager`, `GameManager` logic, `TutorialManager` logic, `AudioManager`.
- No new scenes, autoloads, input actions, or asset files; **no art/audio regeneration** (clamp/fit are runtime presentation transforms).
- No changes to grid constants (`TILE_SIZE`, `GRID_ORIGIN`, `GRID_WIDTH/HEIGHT`), spawn positions, pathfinding, or occupancy.
- No renames of any node/script-variable/signal the playtest surface already covers; surface changes are additive only.
- No new tooling — `run_tests.sh` and the existing gate stay as they are.
- No platform-specific code; no save/menu systems.

---

## 12. Assumptions for Downstream Steps

1. The gate runs the project with real rendering at the project-configured window size (960×704 after T1); `resizable=true` only enables user resizes and does not change the headless start size. Captured frames are therefore 960×704 and deterministic.
2. Character/backdrop PNG dimensions are unknown at design time; the clamp and fit are runtime-measured, so no dimension is hardcoded anywhere.
3. The playtest harness resolves surface nodes by node name (as it already does for `HUD`/`Player`/`East_Heretic`); dynamically named bars are `HealthBar`, `HealthBar2`, … in creation order (player first, then East Heretic, West Poison, South Emperor, North Beggar, Central Divine). PM verifies `HealthBar2`/`SkillBar`/`SkillButton1`/`PauseButton` resolvability before finalizing thresholds; fallback for the label proof is `HealthBar.name_text` alone.
4. `Expression` assertions evaluate script variables on live nodes (not method calls) — hence the new plain variables `name_text`, `sprite_top`, `board_aligned` instead of child-node or method access.
5. PM owns all assert thresholds and final frames; the Architect owns the surface shape, scenario skeletons, and the fix specifications above.
