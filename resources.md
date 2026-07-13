# Resources & Asset Replacement Guide

This document lists every procedurally generated visual element in the Huashan Sword Tournament demo and provides detailed instructions for replacing each with real art assets.

---

## 1. Player Sprite — Yang Guo (杨过)

**Current implementation**: A blue circle (`Polygon2D`) with a "Yang Guo" label.

**File**: `scenes/player.tscn`

**Node to replace**: `Polygon2D` (named "Sprite")

**Replacement steps**:
1. Open `scenes/player.tscn` in the Godot editor.
2. Delete or disable the `Polygon2D` node.
3. Add a `Sprite2D` node as a child of the root `Node2D`.
4. Assign your Yang Guo character texture to the `Sprite2D.texture` property.
5. Adjust `centered` and `offset` to align with the grid (tile size: 64×64 px).
6. (Optional) Add an `AnimationPlayer` for idle/run/attack animations.

---

## 2. Enemy Sprites — The Five Greats (五绝)

**Current implementation**: Colored diamonds (`Polygon2D`) with name labels. Each enemy gets a distinct color via `CharacterData.color`.

**File**: `scenes/enemy.tscn`

**Node to replace**: `Polygon2D` (named "Sprite")

**Per-character configuration**: `scripts/data/character_data.gd` — `color` field

**Replacement steps**:
1. Open `scenes/enemy.tscn` in the Godot editor.
2. Delete or disable the `Polygon2D` node.
3. Add a `Sprite2D` node as a child of the root `Node2D`.
4. Assign a per-character texture based on the enemy's identity (e.g., 黄药师 gets a different sprite than 欧阳锋).
5. Use the enemy's `CharacterData` resource to map character identity → texture path.
6. Adjust alignment to match 64×64 px grid tiles.

**Enemy reference**:

| Enemy | Title | Current Color | Suggested Art Direction |
|-------|-------|---------------|------------------------|
| 黄药师 | 东邪 East Heretic | Teal / Cyan | Elegant scholar in blue robes, holding a flute |
| 欧阳锋 | 西毒 West Poison | Purple / Magenta | Fierce fighter in dark robes, poisoned aura |
| 段智兴 | 南帝 South Emperor | Gold / Yellow | Regal monk in imperial yellow robes |
| 洪七公 | 北丐 North Beggar | Red / Orange | Ragged beggar in red, powerful stance |
| 王重阳 | 中神通 Central Divine | White / Silver | Taoist immortal in white robes, divine aura |

---

## 3. Grid Floor Tiles

**Current implementation**: Green-colored tiles generated at runtime via `Image.create()` + `ImageTexture` in the `_create_tile_textures()` function.

**File**: `scripts/battlefield.gd` — function `_create_tile_textures()`

**Replacement steps**:
1. Open `scripts/battlefield.gd`.
2. Locate the `_create_tile_textures()` function (or equivalent tile texture generation code).
3. Replace the procedural `Image.create()` / `ImageTexture` calls with `load("res://path/to/tile_sheet.png")` or a `TileSet` resource.
4. In the `TileMap` node (`scenes/battlefield.tscn`), assign the imported `TileSet` and map tile IDs accordingly.
5. Ensure tile size matches the game's `TILE_SIZE` constant (64 px).

---

## 4. Grid Border Tiles

**Current implementation**: Gray-colored tiles around the perimeter of the battlefield, generated alongside the floor tiles.

**File**: `scripts/battlefield.gd` — same `_create_tile_textures()` function

**Replacement steps**:
1. Follow the same process as floor tiles (above).
2. Prepare separate textures for edge/rock tiles (e.g., stone walls, mountain edges, fencing).
3. Assign different tile IDs in the `TileSet` for border vs. floor tiles.

---

## 5. Summit Backdrop

**Current implementation**: A large solid blue-gray `ColorRect` behind the grid, representing the Huashan mountain sky.

**File**: `scenes/battlefield.tscn`

**Node to replace**: `SummitBackdrop` (`ColorRect`)

**Replacement steps**:
1. Open `scenes/battlefield.tscn` in the Godot editor.
2. Delete or disable the `ColorRect` node.
3. Add a `Sprite2D` node at the same position.
4. Assign a Huashan summit background texture (e.g., mountain peaks, cloudy sky, ancient temple).
5. Set the `Sprite2D` to stretch or tile as needed to fill the screen.
6. (Optional) Add a `ParallaxBackground` for a depth effect.
7. Ensure the backdrop renders behind the grid (`z_index` or node order).

---

## 6. HUD Panels

**Current implementation**: `ColorRect` and `Panel` nodes with flat colors for the game's heads-up display.

**File**: `scenes/ui/hud.tscn`

**Nodes to replace**: `ColorRect` backgrounds and `Panel` nodes

**Replacement steps**:
1. Open `scenes/ui/hud.tscn` in the Godot editor.
2. For each `ColorRect` / `Panel` background node:
   - Open the inspector.
   - Under `Theme Overrides`, set custom `StyleBox` resources (e.g., `StyleBoxTexture`).
   - Assign themed UI textures (wooden frames, parchment backgrounds, silk panels).
3. For text nodes (`Label`, `RichTextLabel`), customize fonts and colors to match the wuxia theme.
4. Adjust margins and padding as needed.

---

## 7. Health Bars

**Current implementation**: Standard Godot `ProgressBar` nodes linked to character health via `scripts/ui/health_bar.gd`.

**File**: `scenes/ui/health_bar.tscn`

**Script**: `scripts/ui/health_bar.gd`

**Replacement steps**:
1. Open `scenes/ui/health_bar.tscn` in the Godot editor.
2. In the `ProgressBar` inspector, under `Theme Overrides`:
   - Set the `fill` stylebox to a custom texture (e.g., a red/green bar with wuxia styling).
   - Set the `background` stylebox to a dark/empty bar frame.
3. Adjust the bar size to fit the character's name label.
4. (Optional) Add a `TextureProgressBar` for more advanced styling with under/over textures.

---

## 8. Skill Buttons

**Current implementation**: Default Godot `Button` nodes displaying skill names, with cooldown overlay via `scripts/ui/skill_button.gd`.

**File**: `scenes/ui/skill_button.tscn`

**Script**: `scripts/ui/skill_button.gd`

**Replacement steps**:
1. Open `scenes/ui/skill_button.tscn` in the Godot editor.
2. Replace the standard `Button` with a custom-styled version:
   - Apply `StyleBoxTexture` with themed button frames.
   - Add an `icon` texture representing each skill (e.g., a palm print for 黯然销魂掌, a sword for 玄铁剑法).
3. Adjust the cooldown overlay (`ColorRect`) to match the button size and theme.
4. Update the hotkey label font and color to be readable against the themed background.

---

## Credits

All visuals in this prototype are procedurally generated at runtime using Godot built-in primitives:
- **`Polygon2D`**: Player and enemy placeholder sprites (circles, diamonds)
- **`ColorRect`**: Summit backdrop, HUD backgrounds, cooldown overlays
- **`Image.create()` + `ImageTexture`**: Grid floor and border tiles

**No external art assets are used in this demo.**

Character names, settings, and martial arts skills are from Jin Yong's *Condor Trilogy* (射雕三部曲: 射雕英雄传, 神雕侠侣, 倚天屠龙记), used in tribute.

---

*For questions about the code or asset pipeline, refer to `scripts/data/character_data.gd` and `scripts/data/skill_data.gd` for character and skill data structures.*
