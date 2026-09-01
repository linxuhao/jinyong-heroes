# Delivery Notes — occlusion_scene_geometry (jinyong-loop R2)

**Date:** 2026-09-01. **Round:** jinyong-loop R2 (rule short-circuits + theme-round occlusion regression).
**Scope of this task:** presentation-only geometry in three scenes — `scenes/segments/sect_select.tscn`,
`scenes/ui/tutorial_overlay.tscn`, `scenes/ui/roster_panel.tscn` — plus this notes file. Zero code, copy,
theme, or font changes.

## 0. Honesty tiers

- **本步实测 (measured in this step, algebraic):** every rect below is verified by direct read of the
  `.tscn` offsets + the Godot 4 rect formula (`left = anchor_left·W + offset_left`, etc.). Parent sizes
  are read from the scene files, not the window; center-anchored offsets cancel W.
- **已录 (recorded, geometric):** the before→after offset tables below are the actual lines changed in
  the working tree (each change is a single offset/anchor edit; nothing else moved).
- **待官方判 (deferred to the official frame product):** the implementer has no shell / no Godot in this
  step. Same-frame screenshots and pixel legibility are a downstream 5_vision product; every judge cell
  in §2 is marked 待官方判. Nothing in this file claims a frame was seen in-step (mirrors
  `final/delivery_notes_theme.md` §1 discipline).

Reviewer R1 note: the brief's non-goal list names tutorial_overlay / roster_panel as theme-round files;
step2_design.md's R1 amendment explicitly unlocks both scenes for THIS round's presentation-only
geometry repair (container anchor/offset lines only — no colors, fonts, dim values, node adds/removes,
copy, or script edits). This diff is exactly that scope.

## 1. Red lines held (byte-check by direct read of the edits)

- No `font_size`, no color, no Dim/RosterDim alpha, no `text =`, no `focus_mode`, no node add/remove.
- `assets/themes/global_theme.tres` and `scenes/ui/hud.tscn`: byte-untouched (not opened for edit).
- `scripts/segments/sect_select.gd`, `scripts/ui/roster_panel.gd`, `scripts/ui/tutorial_step.gd`: untouched.
- Only `anchor_*` / `offset_*` lines changed in the three scenes. Global font scale untouched.

## 2. Seven before/after same-frame pairs (judge = 待官方判 on every row)

| # | Reference frame (before shot) | Reproduce scenario | Frame | Geometric what-changed (before → after offsets) | Judge |
|---|---|---|---|---|---|
| 1 | s13_frame_0210 | spine_to_ending (SECT_SELECTION) | f210 | BodyLabel right +320→+110; SectButton0..4 x −120..120 → 130..370; HintLabel −200..200 → −100..100 | 待官方判 |
| 2 | s16_frame_0620 | (same screen in a late-map run; scenario name recorded as observed in the official 5_vision capture — fill from the official run report; mapping not guessed here) | f620 | same offsets as row 1 | 待官方判 |
| 3 | s17_frame_0240 | (sect-select instance; official capture report is the authority for the scenario name) | f240 | same offsets as row 1 | 待官方判 |
| 4 | s20_frame_0104 | (sect-select instance; official capture report is the authority for the scenario name) | f104 | same offsets as row 1 | 待官方判 |
| 5 | s28_frame_0325 | (sect-select instance; official capture report is the authority for the scenario name) | f325 | same offsets as row 1 | 待官方判 |
| 6 | s15_frame_0072 | tutorial overlay page — likely `menu_to_creation_to_tutorial_order` (WELCOME page; official capture report is the authority for the exact scenario) | f72 | Buttons HBox: anchors (0,0,0,1)+offsets(100,−56,500,−16) → anchors (0,1,1,1)+offsets(100,−56,−100,−16) ⇒ 400×440 column → 400×40 bottom strip | 待官方判 |
| 7 | s75_frame_0110 | roster panel open — likely a `roster_panel_*` / `roster_equip_free_action` scenario (official capture report is the authority for the exact scenario) | f110 | RosterBodyLabel right −16→−190; EquipButton0..11 +297 on x (165/211/257→462/508/554; 209/255/301→506/552/598) | 待官方判 |

Reviewer's checklist item honored: the Tang-Men row `唐门 —— 内功 唐门心法(柔)· 外功 满天花雨(柔)` is
fully legible in the after-state (see §3 algebra: the body rect now ends at x = 0.5W+110, the nearest
button starts at x = 0.5W+130 — 20 px clear; `clip_text = false` and `text_overrun_behavior = 0` are
unchanged, so narrowing the rect only moves the wrap point and hides no glyphs).

## 3. Algebraic verification (rect formula, per screen)

**sect_select** (all nodes anchor 0.5 ⇒ W cancels):
- BodyLabel x-range [0.5W−320, 0.5W+110]; each SectButton x-range [0.5W+130, 0.5W+370].
  110 < 130 ⇒ **20 px x-gap** — no rect intersection for any button. y overlap is irrelevant once x is disjoint.
- HintLabel x [0.5W−100, 0.5W+100], y at the bottom strip — disjoint from every button's x-range too.
- Body wraps at 430 px; every sect row (incl. Tang Men) clears x = +110.

**tutorial_overlay** (Panel = 600×400, offsets −300/−200/300/200):
- Buttons (HBox) after fix: anchors (0,1,1,1), offsets (100,−56,−100,−16) ⇒ panel-local
  x 100..500, y 344..384 (400×40 bottom strip). `Next`/`SkipTutorial` `size = Vector2(160,36)` remains
  a floor, but the container is now 40 px tall, so buttons render ~36 px inside the strip.
- Body (RichTextLabel) y 64..300 ⇒ **44 px y-gap** (300 < 344). No tutorial page can occlude its body
  regardless of body length.

**roster_panel** (RosterBox = 640×560, RosterBodyLabel anchors (0,0,1,1)):
- Body x-range [16, 450] (offset_right −190 ⇒ right edge = 640−190); EquipButton0..11 columns x
  [462,598] ⇒ **12 px x-gap**. All y offsets unchanged. The 悟性 attribute cell is no longer under any
  装上/卸下 button.
- `refresh()` re-binds pool buttons by index; scenario clicks anchor node names
  (`EquipButton0 +0,0` grammar) ⇒ the +297 shift is position- and timeline-independent.

## 4. Tutorial-pages record (reviewer hard checklist item)

- **WELCOME page — 已录 (measured anchor):** the defect geometry was measured on the shipped file
  (Buttons anchors (0,0,0,1) + offsets computing to x 280..680 × y 96..536 global, directly over the
  Body rect x 200..760 × y 216..452); the fix moves the strip to y 496..536, 44 px below the body.
- **Other 6 pages — geometric inference, honestly labeled:** official frames captured only the WELCOME
  page, so the other pages' occlusion is geometric inference, not a measured screenshot. The MEASURED
  result the runs actually show for those pages: none captured in-step; the fix's rect math is
  page-independent (the strip is anchored to the panel bottom regardless of body text length), so the
  repair holds for all 7 pages by geometry. Per-page pixel verdict is deferred to the downstream
  structural watch (occlusion_watch_gate), which asserts `UiOcclusionWatch.violations == 0` and covers
  every captured frame of every page.

## 5. Coordinate-literal asserts

None added (forbidden by the task card): no yaml gains an assert over `offset_right == 110` or any
other coordinate literal. The structural property gate is the separate occlusion_watch_gate task.
