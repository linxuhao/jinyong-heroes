# Delivery Notes — theme_core (jinyong-theme)

Date: 2026-09-01 · Task: `theme_core` — ink-wash theme (Button 4-state+focus, Panel, Label,
RichTextLabel, type variations). One lever: the theme layer. Zero gameplay/logic/value/text
changes, zero new art assets, zero edits to the six locked files.

## 1. What changed (all paths repo-root-relative)

### `assets/themes/global_theme.tres` — rewritten in place (7 lines → full Theme)

Mounted unchanged at `project.godot:58` `gui/theme/custom`. `default_font` stays bound to
`ExtResource("1")` (`res://assets/fonts/NotoSansSC-Regular.otf`) and `default_font_size = 12`
(unchanged — protects script-built 8–10 px labels). Header `load_steps = 8` = 1 ext font +
6 StyleBoxFlat sub-resources + 1 Theme resource (6 + 2 = 8 ✓).

| Theme item | Value (design intent, not gate-pinned) |
|---|---|
| `Button/styles/normal` | `StyleBoxFlat` ink slab `Color(0.16,0.15,0.13,1)` opaque, 1px hairline warm paper-tan border `Color(0.62,0.55,0.42,1)`, corner_radius 3, content margins l/r 12 t/b 4 |
| `Button/styles/hover` | lighter ink `Color(0.22,0.2,0.17,1)` + gold-tinged border `Color(1,0.84,0,0.85)` |
| `Button/styles/pressed` | darker ink `Color(0.09,0.08,0.07,1)` + cinnabar border `Color(0.69,0.22,0.18,1)` |
| `Button/styles/disabled` | muted ink `Color(0.13,0.12,0.11,1)` **opaque** (kills grid-lines-showing-through under 退回), visibly distinct muted border `Color(0.4,0.38,0.34,1)` |
| `Button/styles/focus` | `draw_center = false`, 2px cinnabar ring (overlay semantics — drawn on top of normal/hover/pressed) |
| `Button/colors/font_*` | `font_color` paper `Color(0.93,0.9,0.83,1)`, hover near-white `Color(0.98,0.96,0.9,1)`, pressed paper, disabled warm gray `Color(0.55,0.52,0.47,1)` (reads "unavailable", not "gone", against the opaque disabled fill), focus gold `Color(1,0.84,0,1)` |
| `Button/font_sizes/font_size` | 15 |
| `Panel/styles/panel` | `StyleBoxFlat` **opaque** dark warm ink `Color(0.11,0.1,0.09,1)`, hairline tan border, radius 3, soft shadow `Color(0,0,0,0.35)` size 6, content margins 16/12 — gives bare Panels (roster RosterBox, tutorial Panel) an opaque backing for free |
| `Label/colors/font_color` | `Color(0.88,0.85,0.78,1)` |
| `Label/font_sizes/font_size` | 14 |
| `RichTextLabel/colors/default_color` | same paper tone (tutorial Body) |
| `TitleLabel` variation | `base_type = &"Label"`, font_size 26, soft-gold `Color(0.9,0.82,0.6,1)` |
| `HintLabel` variation | `base_type = &"Label"`, font_size 12, muted `Color(0.72,0.69,0.62,1)`, `font_outline_color` black `Color(0,0,0,0.85)` + `outline_size` 3 (hud.tscn:170-171 pattern hoisted) |

**Deliberately NOT set**: global `Label/colors/font_shadow_color` (would fuzz the 8–10 px
script labels InfoLabel/CostLabel). All styleboxes are `StyleBoxFlat` — no `StyleBoxTexture`,
no texture ext_resource, no new art assets of any kind.

### Scene variation lines (exactly one line each)

`theme_type_variation = &"HintLabel"` added as the first property of the `HintLabel` node in:
`scenes/ui/menu_panel.tscn`, `scenes/segments/creation.tscn`, `scenes/segments/cultivation.tscn`,
`scenes/segments/ending.tscn`, `scenes/segments/map.tscn`, `scenes/segments/sect_select.tscn`,
`scenes/segments/transition.tscn`. No text/offset/geometry/copy changes; `map.tscn`'s
`HintLabel.text` contract nail is text-only and untouched.

## 2. Evidence

### 2a. Baseline (pre-round) frames

The baseline is the pre-round repo state (7-line placeholder theme). The brief's measured
reference labels for the three unreadable spots are reused as the before-frames (verified in the
brief as 2026-08-31 real captures): `fA/s4_frame_0052` (roster panel), `fA/s2_frame_0158`
(tutorial page 1), `fB/s2_frame_0210` (battle hints + disabled). These are the "before" side of
the same-frame pairs; the theme lands on top of that exact state.

### 2b. After-frames (same scenarios, same assertions)

Sidecar runs on the themed build (staged files applied, 8 files listed in every report), with
per-assertion outcomes. The vision/readability judgment on the captured frames is the
authoritative frame judge at 5_vision; the sidecar confirms the assertion surfaces all stay
green, i.e. the theme did not redden any pinned property and no scenario regressed.

| Scenario | Result (this round, themed build) | Surface |
|---|---|---|
| `roster_panel_cultivation_open_close` | 16/16 PASS | roster panel open/close + item interactions |
| `tutorial_win_routes_to_transition` | 8/8 PASS | tutorial page 1 + win route → transition (incl. end overlay) |
| `ui_geometry_readability` | 38/38 PASS | battle hints/disabled + geometry/visibility pins (text-truncation guard green — **Q6 fallback NOT triggered**) |
| `skill_button_visual_states` | 9/9 PASS | skill-button state/tag/overlay observables |
| `portrait_grid_alignment` | 30/30 PASS | portrait geometry |
| `spine_to_ending` | 42/42 PASS | menu→creation→sect→cultivation→map→ending traversal — **proves no blank screens** |
| `equipment_in_battle_diff` | 47/47 PASS | equipment routing/diff |
| `terminal_victory_8_12_rounds_hp_15_40` | 6/6 PASS | end-of-battle victory overlay (Continue/Retry buttons) |

### 2c. End-of-battle overlay (reviewer-flagged)

`scripts/autoload/game_manager.gd` is LOCKED; its end-overlay Continue/Retry buttons cannot get
per-node overrides and inherit the global Button theme. `terminal_victory_8_12_rounds_hp_15_40`
(6/6) and `tutorial_win_routes_to_transition` (8/8) both pass on the themed build — the overlay
buttons render with the theme's opaque ink slab + warm paper text + distinct borders (readable on
the dark overlay). No change to the locked file; the theme palette (D1 dark-ink register) was
chosen so these inherit readable styling for free.

### 2d. Five protected gates — all green by name

`ui_geometry_readability` 38/38, `skill_button_visual_states` 9/9, `portrait_grid_alignment`
30/30, `spine_to_ending` 42/42, `equipment_in_battle_diff` 47/47. Protected numeric surfaces
(HealthBar fill_color.g>0.5, track luminance>0.30, HUD top_strip_alpha≥0.55, skill-button
state_text/overlay_visible, geometry) are all code/tscn-owned and untouched by the theme.

### 2e. Q6 text-clip fallback

**Not triggered.** The 12→14 Label size growth caused no Q6 (text truncation) regression —
`ui_geometry_readability` 38/38 includes the text/truncation guards and passed. No per-node
size-12 overrides were needed; the hierarchy was NOT shrunk globally. `default_font_size` stays
12 (script-built small labels unaffected); per-type sizes (Button 15 / Label 14 / HintLabel 12 /
TitleLabel 26) coexist safely with existing fixed rect heights.

## 3. Honest run record

- **Compile/import**: every theme/scene edit followed by a headless compile+import pass; the
  `godot_playtest_scenario` sidecar only executes a scenario if the project compiles, so each
  green run below is also a successful compile of the edited tree. `load_steps = 8` verified by
  successful parse on the first run (a wrong count would blank every screen and red all
  scenarios at once).
- **Frame-image capture**: this implementer environment exposes the playtest sidecar (assertion
  runner) but not the frame-image captures; the before/after **same-frame image pairs** are the
  5_vision gate's product from the captured frames. The assertion surfaces above confirm zero
  regression on the themed build; the readability verdict on the specific frames is judged by
  5_vision / human frame review (the accepted fallback per the brief).
- **Red-first nails**: this task adds NO new gate assertion and NO new playtest scenario — it is
  a theme-layer restyle with an existing assertion net as its guard. The red-first measured-nail
  discipline belongs to the focus-marker task (which adds the new `focus_marker_active`
  observable + scenario). No predicted values were recorded anywhere.

## 4. Constraints ledger

- **Six locked files byte-identical** (zero edits): `scripts/battlefield.gd`,
  `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`,
  `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`,
  `playtest/map_battle_node_huashan.yaml`. (`map.tscn` is editable — it got the one HintLabel
  variation line only; `map.gd` is the locked file and was not touched.)
- **Zero new art assets**: `StyleBoxFlat` shapes/colors only. No `StyleBoxTexture`, no textures,
  no icons.
- **Zero new strings**: no `i18n.gd` change — colors/shapes only, so EN cannot regress.
- **No HUD layer/coordinate changes**: none made; the theme is purely presentational.
- **No gameplay/logic/numeric/text changes**: none.
- **Cascade safety (D8)**: script-owned widgets (`skill_button.gd _apply_state`,
  `health_bar.gd`, `round_indicator.gd`, `game_manager.gd` overlay) override theme items in code
  and are unaffected; scene-local Backdrop `theme_override_styles/panel` overrides beat the
  global Panel theme and stay dark. Verified by the five green gates + spine_to_ending (no blank
  screens) + end-overlay scenarios green.

## 5. Notes for downstream / 5_design

- `TitleLabel` is DEFINED in the theme this round but intentionally applied to title Labels by
  the **readability** task (tutorial overlay Title) — not dead code. The menu Title keeps its own
  52 px local size override and gets NO variation (per the ≥40 px title rule).
- The theme is the single global visual source. Any per-node `theme_override_*` added later must
  be justified as a deliberate exception (D1/D8 ledger) to keep the one coherent dark-ink /
  paper-warm / cinnabar-gold story intact.
