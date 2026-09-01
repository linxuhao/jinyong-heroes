# Technical Architecture Design — jinyong-theme (2026-09-01)

## 0. Round identity

One lever: **the theme layer**. The round turns the 7-line placeholder `assets/themes/global_theme.tres` into a real ink-wash theme (Button four states + focus, Panel, Label, title/body hierarchy), fixes the three "text unreadable" spots (roster panel, tutorial page 1, battle hints + disabled state), and gives the cultivation option list a genuinely visible focus marker. Zero gameplay changes, zero new art assets, zero edits to the six locked files.

Deliverable clusters:
- **A** — `assets/themes/global_theme.tres` rewritten in place (the mandated entry, `project.godot:58` `gui/theme/custom`).
- **B** — Readability fixes: `roster_panel.tscn` + `tutorial_overlay.tscn` (opaque panel + real dim), battle hints/disabled (theme + `hud.tscn` shadow pair copied from the skill_button precedent).
- **C** — Focus marker: `ThemeManager` helper + `cultivation.gd:641` replacement, one new playtest nail.
- **D** — Evidence: before/after same-frame pairs, red-first measured values, docs.

Hard constraints carried verbatim from the brief into every task: no new textures/images/icons; no copy/logic/value changes; locked files byte-identical (`scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`); no HUD layer/coordinate changes; EN must not regress (this round adds **zero strings** — colors and shapes only, so no `i18n.gd` change is needed at all); 78/78 scenarios zero regression; gates pin properties, never form/color literals; every new nail measured red-first (two real runs), never predicted.

## 1. Verified current state (all anchors re-read today, 2026-09-01)

| Anchor | Fact |
|---|---|
| `assets/themes/global_theme.tres` | 7 lines: `default_font` (NotoSansSC) + `default_font_size = 12`. No styleboxes, no colors, no sizes, no variations. |
| `project.godot:58` | `theme/custom="res://assets/themes/global_theme.tres"` — global mount, restyles **every** Control incl. battle HUD. |
| `project.godot:33` | `ThemeManager="*res://scripts/autoload/theme_manager.gd"` — autoload key confirmed `ThemeManager`. |
| `scripts/autoload/theme_manager.gd` | 17 lines, font fallback only. Free to extend (not locked). |
| `scenes/ui/roster_panel.tscn:34` | `RosterDim` ColorRect `Color(0,0,0,0.55)`. |
| `scenes/ui/roster_panel.tscn:36` | `RosterBox` **bare Panel** — no `theme_override_styles/panel`; renders the engine default translucent panel → background text/buttons bleed through (fA/s4_frame_0052). |
| `scenes/ui/tutorial_overlay.tscn:14` | `Dim` ColorRect `Color(0,0,0,0.5)` on CanvasLayer layer=100 — portraits bleed through (fA/s2_frame_0158). |
| `scenes/ui/tutorial_overlay.tscn:17` | bare `Panel` (600×400) with Title Label / Body RichTextLabel / 2 Buttons. |
| `scenes/ui/menu_panel.tscn:14-18`, `scenes/segments/cultivation.tscn:15-20` | Full-screen dark Backdrop Panels carry **local** `theme_override_styles/panel = StyleBoxFlat(0.07,0.07,0.1)` — per-node overrides beat the global theme, so these stay dark no matter what the theme says. Same pattern in the other segment scenes. |
| `scripts/ui/skill_button.gd:508-526` | `_apply_state()` writes per-state StyleBoxFlat to `normal`+`disabled` **and** all five font-color overrides every frame → skill buttons are fully script-styled; the global Button theme cannot fight them (script overrides win). |
| `scripts/ui/health_bar.gd:286-360`, `scripts/ui/round_indicator.gd:213-214`, `game_manager.gd:574-587` | Same: script-owned styleboxes/colors. Theme-invisible. |
| Focus pattern | `modulate = 1.0 vs 0.72` at **four** sites: `cultivation.gd:641`, `creation.gd:730/:734`, `map.gd:502/:513/:524/:529`, `sect_select.gd:84`. `map.gd` is **locked**; `creation.gd` rows at :730 are plain Controls (not Buttons). |
| `cultivation.gd:582-646` | `_rebuild_options_box()` builds `CultOptionButton{i}` (`FOCUS_NONE`), `custom_minimum_size (240,40)`; :641 is the modulate line. `_sync_surface()` is the published-observable sink (UX-18 precedent). |
| `scripts/ui/skill_button.tscn:46-50, 95-102` | Precedents to copy: `font_shadow_color = Color(0,0,0,0.85)` + `shadow_offset_x/y = 1`; `SelectedMarker` gold ColorRect. |
| `scenes/ui/hud.tscn:169-179` | `SkillDescLabel` (outline 3 / black 0.9) and `MoveHintLabel` (outline 4 / black 0.8) — outlines exist yet fB/s2_frame_0210 still reads poorly: no shadow, and the disabled「退回」sits on the engine-default semi-transparent button plate with grid lines showing through. |
| Protected gate expressions (re-read, per Step-1 review suggestion) | `ui_geometry_readability`: `HealthBar.fill_color.g > 0.5 and > r`, `track_bg.get_luminance() > 0.30`, `HUD.top_strip_alpha >= 0.55`, `name_backing_alpha > 0.3`, `state_text == "phase_locked"/"ready"`, text `contains("…") == false`, geometry overlap pins — **all pinned on code/tscn-owned surfaces (HealthBar, HUD strip, skill button states), none on theme-owned styleboxes/colors**. `skill_button_visual_states`: state/tag/overlay observables — script-owned. `portrait_grid_alignment` / `spine_to_ending` / `equipment_in_battle_diff`: geometry/routing — untouched by theming. |

**Consequence:** a theme that only adds `Button`/`Panel`/`Label` items cannot break any pinned surface numerically; the real cascade risks are (a) global font sizes/colors reaching the battle screen, and (b) `.tres` syntax errors blanking all 78 scenarios at once. Both are handled in §3-D2/§6.

## 2. Architecture

```
project.godot:58  gui/theme/custom
        │
        ▼
assets/themes/global_theme.tres   (REWRITTEN — single source of visual truth)
  ├── Button: styles normal/hover/pressed/disabled + focus overlay; 5 font colors; font_size 15
  ├── Panel: styles panel (opaque ink slab + hairline border + shadow)
  ├── Label: font_color, font_size 14
  ├── RichTextLabel: default_color
  └── type variations: TitleLabel (base Label), HintLabel (base Label, outline)
        │  cascades into ALL Controls
        ├──────────────────────────► 7 non-battle scenes (menu/creation/cultivation/map/
        │                              sect_select/transition/ending) — restyled for free;
        │                              their dark Backdrops survive via local overrides (D1)
        ├──► roster_panel.tscn / tutorial_overlay.tscn — bare Panels get the opaque slab;
        │    Dim ColorRects raised in-scene (D3)
        └──► battle screen — HUD buttons & hints restyle (D4); script-styled widgets
             (skill buttons, health bars, round indicator) unaffected (they override)

scripts/autoload/theme_manager.gd   (EXTENDED — script-side theme home)
  └── option_style(focused: bool) -> StyleBoxFlat  (two cached boxes, built once)
        │
        ▼
scripts/segments/cultivation.gd:641   (ONE LINE replaced)
  modulate 1.0/0.72  →  stylebox + font-color swap driven by _focused_index_for_phase()
        └── publishes focus_marker_active via _sync_surface() → playtest surface
```

Data flow for evidence: the four before/after frame pairs come from the existing 78-scenario playtest capture (same `at:` frames), judged by the vision gate or human frame review; the one new differential nail rides `playtest/_common.yaml`'s surface whitelist (append-only, two-place sync with `tests/test_playtest_contract_smoke.py`).

## 3. Design decisions

### D1 — Palette register: dark ink, ONE text-color story (deviation from Step 1 recorded)

Step 1 suggested rice-paper panels + ink-dark text for the non-battle screens. **Rejected on cascade grounds**, with reasoning for the record: every non-battle scene keeps a full-screen dark Backdrop via a *local* `theme_override_styles/panel` (verified §1), HUD text sits on the dark TopStrip, skill buttons are script-styled dark, and health-bar/round-indicator text is script-colored light. Flipping the global font to ink-dark would demand a large per-node light-color exception inventory across 7 scenes + HUD + script widgets — each missed node is an unreadable frame and a Q6 red. Instead the theme adopts the **battle screen's own vocabulary** (dark ink slab, warm paper text, hairline paper-tan borders, cinnabar + gold accents), giving one coherent light-on-dark story everywhere with **zero per-node font-color exceptions**.

This does **not** repeat the brief's worst failure ("black replaced by another black"): the differentiator is structure, not hue — opaque backed panels with borders, four genuinely distinct button states, a real focus marker, and a font-size hierarchy. The brief itself names the register to align with: 宣纸/墨/朱印 (paper-warm text, ink slabs, cinnabar seals).

### D2 — `assets/themes/global_theme.tres` content (the round's core artifact)

`StyleBoxFlat` sub-resources only (shapes/colors — the only legal material; `StyleBoxTexture` banned). Palette anchored to the battle screen's existing values (TopStrip ink `0.07,0.07,0.1`, gold accent `1,0.84,0`, skill-button text `0.92,0.92,0.92`):

| Theme item | Value (intent, not gate-pinned) |
|---|---|
| `default_font` / `default_font_size` | unchanged (NotoSansSC / 12) — protects script-built 8–10 px labels |
| `Button/styles/normal` | ink slab `≈Color(0.16,0.15,0.13)`, opaque, hairline paper-tan border 1px, corner radius 3, content margins l/r 12 t/b 4 |
| `Button/styles/hover` | lighter ink + gold-tinged border |
| `Button/styles/pressed` | darker ink + cinnabar border |
| `Button/styles/disabled` | muted ink, **opaque** (kills grid-lines-showing-through), visibly distinct border; `font_disabled_color` warm gray ≈`0.55,0.52,0.47` — reads as *unavailable*, not *gone* |
| `Button/styles/focus` | draw_center=false cinnabar 2px ring (overlay semantics, godot-proposals #8134) |
| `Button/colors/font_color/hover/pressed/disabled/focus` | paper `≈0.93,0.90,0.83` family; hover near-white; focus gold |
| `Button/font_sizes/font_size` | 15 |
| `Panel/styles/panel` | **opaque** dark warm ink `≈Color(0.11,0.10,0.09,1)`, hairline tan border, radius 3, soft shadow, content margins 16/12 |
| `Label/colors/font_color` | `≈Color(0.88,0.85,0.78)` |
| `Label/font_sizes/font_size` | 14 |
| `RichTextLabel/colors/default_color` | same paper tone (tutorial Body) |
| `TitleLabel` variation (`base_type &"Label"`) | size 26, soft-gold tone — hierarchy top |
| `HintLabel` variation (`base_type &"Label"`) | size 12, muted `≈0.72,0.69,0.62`, outline black 0.85 size 3 (hud.tscn pattern hoisted) |

`.tres` mechanics: header `load_steps = sub_resource_count + 2` (1 ext font + N styleboxes + resource) — every stylebox added bumps it; wrong count = blank screens = all 78 red. Protocol: each theme edit followed immediately by headless import + compile, then the full suite once the theme lands. No `Label/colors/font_shadow_color` globally — it would fuzz the 8–10 px script labels (`InfoLabel`, `CostLabel`); shadows go only where art sits (D4).

### D3 — Roster panel & tutorial overlay (压字 #1, #2)

Two-layer structural fix, not an alpha twiddle:
1. **Opaque backing via the global theme** — `RosterBox` and the tutorial `Panel` are bare Panels, so `Panel/styles/panel` gives them a real opaque ink slab + border for free. This is the fix that makes the panel an information layer (UX-22's actual defect).
2. **Dim raised in-scene** — `roster_panel.tscn:34` `0.55 → ≈0.85`, `tutorial_overlay.tscn:14` `0.5 → ≈0.88`: one value each, presentational, no z-order/layer/coordinate change (CanvasLayer 100 stays). Exact values are chosen so the after-frames read cleanly; the judge is the frame, not the number.

No node added, none removed, no geometry touched — `roster_panel_cultivation_open_close` / `roster_panel_item_nail` / tutorial scenarios keep every assertion. Tutorial Body is a RichTextLabel → gets `RichTextLabel/colors/default_color`; Title Label → `TitleLabel` variation (560×40 rect fits 26 px).

### D4 — Battle hints & disabled state (压字 #3, fB/s2_frame_0210)

- **Hints**: copy the skill_button.tscn:48-50 shadow pair verbatim onto `hud.tscn`'s two hint labels (SkillDescLabel ~:170, MoveHintLabel ~:178): `theme_override_colors/font_shadow_color = Color(0,0,0,0.85)` + `theme_override_constants/shadow_offset_x/y = 1`, alongside their existing outlines. Outline+shadow compound is exactly the brief's prescribed pattern for text over 皴笔; no hierarchy/coordinate change; no gate pins hint colors (`ui_geometry_readability` pins geometry/visibility only).
- **Disabled**: the theme's opaque disabled stylebox + readable `font_disabled_color` (D2) fixes「退回」reading as *gone* (light-gray-on-translucent-plate with grid lines through it). This also de-fogs every HUD button's disabled state globally.
- The implementer captures the same fB frame before/after; if the pre-frame already reads acceptably, the delivery note says so honestly and the shadow pair remains the low-risk hardening.

### D5 — Focus marker (cultivation.gd:641)

- `ThemeManager` gains `option_style(focused: bool) -> StyleBoxFlat` — two cached, never-mutated-after-build StyleBoxFlats (plain = the theme's own Button-normal geometry so min-size is byte-stable; focused = same margins + 3px cinnabar left bar + gold border, the `SelectedMarker`-sanctioned form family: border/backing). Plus the two font-color constants (focus paper / dim `≈0.62,0.60,0.55`).
- `cultivation.gd:641` (inside `_rebuild_options_box`, the exact line the brief names) replaces the `modulate` ternary with the stylebox+font-color swap on `i == _focused_index_for_phase()`. Same sync points, same `FOCUS_NONE`, no behavior change; the 2–3 % brightness trick is gone.
- New observable `focus_marker_active: bool` on `CultivationScreen`, published in `_sync_surface()` (true iff the focused row's focused variant is applied) — a real render state the script genuinely drives, enabling the sanctioned *differential* nail.
- `sect_select.gd:84` (same Button pattern, editable) adopts the same helper so the language is coherent across the two list phases — no new nail, existing sect scenarios are the regression net.
- **Explicitly out of scope**: `creation.gd:730/:734` (AttrRow is a plain Control — different mechanism, would be invention) and `map.gd` (locked, zero-change). Consequence recorded for 5_design: UX-21 may close only for the covered sites or stay OPEN with the map/creation residual noted — decided from this round's actual results, not predicted.

### D6 — Title/body hierarchy without geometry risk

Per-type sizes: Button 15, Label 14, hints 12 via `HintLabel`, titles 26 via `TitleLabel`; `Theme.default_font_size` stays 12. Application rule for scene edits (one line per node, `theme_type_variation = &"HintLabel"` / `&"TitleLabel"`): apply `TitleLabel` only to top-of-screen title Labels whose rect height ≥ 40 px (verified today: tutorial Title; menu Title keeps its own 52 px override and needs no variation); apply `HintLabel` to the segments' bottom HintLabels (menu, cultivation, map — map's `HintLabel.text` contract nail is text-only, unaffected). **Named fallback**: if any geometry/Q6 pin reddens from the 12→14 Label growth (HUD top labels are the only tight rects), the fallback is pinning those few nodes back to 12 via per-node size overrides — never shrinking the hierarchy globally.

### D7 — What is intentionally NOT built

No textures/images/icons (StyleBoxFlat only); no `ThemeDB`/runtime theme swapping; no new type variations beyond the two; no global Label shadow (D2); no font/copy/string changes anywhere (zero `i18n.gd` delta; EN cannot regress because nothing textual changes); no HUD restructure; no changes to `battlefield.gd`/`game_manager.gd`/`scene_manager.gd`/`map.gd`/`map_battle_data.gd`/`map_battle_node_huashan.yaml` (byte-identical, verified by the contract smoke test); no new art pipeline steps.

### D8 — Cascade safety ledger (who escapes the global theme, by design)

Script-owned (win over theme, unaffected): `skill_button.gd _apply_state` (per-state stylebox + 5 font colors), `health_bar.gd`, `round_indicator.gd`, `game_manager.gd` overlay panel/labels (locked file — its Buttons still gain the theme for free, its pinned panel style does not move), scene-local Backdrop overrides. Gate surfaces pinned today are all in this ledger or geometry-owned, which is why the five protected gates survive a palette change by construction — verified expression-by-expression in §1. The remaining risk is size growth (D6 fallback) and `.tres` syntax (§6 protocol).

## 4. Component list & interfaces (repo-root-relative)

| File | Change | Interface / contract |
|---|---|---|
| `assets/themes/global_theme.tres` | rewrite in place | Theme items per D2; `load_steps` arithmetic exact; ext_resource id `1` = NotoSansSC unchanged |
| `scripts/autoload/theme_manager.gd` | additive | keep `_ready()` fallback byte-behavior; add `option_style(focused: bool) -> StyleBoxFlat` + `OPTION_FONT_FOCUS/OPTION_FONT_DIM` constants; no signals, no state |
| `scripts/segments/cultivation.gd` | one line at :641 + publish | replace modulate ternary with `add_theme_stylebox_override("normal", ThemeManager.option_style(focused))` + font-color override; add `var focus_marker_active: bool` synced in `_sync_surface()`; phase logic/RNG untouched |
| `scripts/segments/sect_select.gd` | one line at :84 | same helper swap on `SectButton{i}` |
| `scenes/ui/roster_panel.tscn` | one value | `RosterDim.color.a ≈ 0.85`; everything else untouched |
| `scenes/ui/tutorial_overlay.tscn` | one value + one variation line | `Dim.color.a ≈ 0.88`; `Title` gets `theme_type_variation = &"TitleLabel"` |
| `scenes/ui/hud.tscn` | two lines | shadow pair (D4) on SkillDescLabel + MoveHintLabel; all other hud content untouched |
| `scenes/ui/menu_panel.tscn`, `scenes/segments/*.tscn` | variation lines only | `HintLabel` on bottom hint labels; `TitleLabel` on verified ≥40 px title Labels (rule D6) |
| `playtest/_common.yaml` | append-only surface | `CultivationScreen.focus_marker_active` (+ `scenario_order` tail append for the new scenario) — two-place sync with `tests/test_playtest_contract_smoke.py` |
| `playtest/theme_focus_marker_cultivation.yaml` | new scenario | skeleton in §5; name == basename |
| `final/delivery_notes_theme.md` | new | before/after same-frame table, red-first four values, ledger of untouched files |

No other files change. `design/` docs are 5_design's job (changelog: exactly one appended line; roadmap phase-4 numbers only from gate artifacts; UX-21/UX-22 status only per results).

## 5. Playtest contract (Architect-owned observables + skeleton)

**Surface append (whitelist, append-only):** `CultivationScreen.focus_marker_active: bool`.

**New scenario skeleton — `theme_focus_marker_cultivation`** (PM fills exact `at:` frames by mirroring `clicks_only_gongfa_empty_exit`'s boot/seed timing; keyboard twin of the existing focus ladder):
- boot to menu → load the sanctioned fresh save (same seeds as existing cultivation scenarios, RNG stream untouched) → advance to `ACTION_PICK`.
- assert at frame A: `CultivationScreen.phase == "ACTION_PICK"`, `focus_marker_active == true`, `focused_option_text` non-empty.
- `move_down` → assert at frame B: `focused_option_text: changed` **and** `focus_marker_active == true` (the marker follows the cursor; differential proves the visual state moved with focus, not a stuck constant).
- one real click on `CultOptionButton0` → phase advances (the marker never blocks clicking — clicks-only path intact).
- No absolute style/color assertions anywhere (no `== Color(...)`, no alpha literals, no "stylebox exists" forms).

**Red-first protocol** (mandatory, measured): temporary revert = restore the :641 modulate ternary / stub `option_style()` to return the plain box for both values, marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`; direct sidecar run (`godot_playtest_scenario`, same channel as prior rounds) → record failing frame / first failing assert / exact error / greens-before-red; restore byte-exact; re-run green; record both runs in the delivery note. Vision endpoint unreachable → human frame review is the accepted fallback (knowledge.md precedent), never a silent pass.

**Before/after same-frame pairs (the round's primary acceptance):**

| Frame | Shows | Judge |
|---|---|---|
| `fA/s4_frame_0052` | roster panel: 年月/属性 rows vs bleed-through card buttons | vision gate Q-contrast or human |
| `fA/s2_frame_0158` | tutorial page 1: body vs HP bar, portraits through dim | same |
| `fB/s2_frame_0210` | battle hints on 皴笔 + disabled 退回 | same |
| menu / cultivation / ending frames (this round's run) | "someone designed this" — button states, panel backing, hierarchy | same |

## 6. Test plan & safety

1. **After every `.tres`/scene edit**: headless import + `godot --check-only` equivalent compile gate; a broken theme blanks all screens, so theme edits land in small verifiable steps (theme file → compile → scenes → compile).
2. **Unit suite**: no new GDScript test files planned (the differential nail + frames carry the round; a stylebox-shape unit test would be a form pin). Compile count stays at the current 98-file baseline.
3. **Full playtest suite**: 78/78 zero regression; five protected gates re-verified by name (`ui_geometry_readability`, `skill_button_visual_states`, `portrait_grid_alignment`, `spine_to_ending`, `equipment_in_battle_diff`).
4. **Rollback**: all changes are single-commit text edits; the temporary-revert protocol for red-first requires byte-exact restore and a full-suite re-run afterward (repo_apply is `git add -A` — no revert residue may survive).
5. **Contract smoke**: `_common.yaml` appends keep `tests/test_playtest_contract_smoke.py` in two-place sync (surface + `scenario_order`).

## 7. Suggested task split for PM

- **T1 Theme core**: D2 theme file + compile protocol + D8 cascade verification (menu/cultivation/ending frames already look themed).
- **T2 Readability**: D3 (roster + tutorial) + D4 (hud shadow pair); before/after frames captured.
- **T3 Focus marker**: D5 helper + cultivation/sect swap + surface append + new scenario, red-first measured.
- **T4 Evidence & docs**: frame pairs, delivery notes, gate runs; 5_design handoff notes (UX-21/UX-22 disposition inputs, changelog line draft).

T2/T3 are parallelizable after T1; T4 last. Every task's acceptance = its gate evidence, never "looks done".

## 8. Design-doc alignment (for 5_design)

No `design/` contradiction: this round is presentation-layer inside roadmap phase 4's scope (UI/主题), touching none of `10_`/`20_` systems or content. 5_design will: append one `99_changelog.md` line; fill phase-4 numbers from gate artifacts; resolve UX-21 (focus) / UX-22 (roster panel) statuses strictly per results — including the honest residual that `map.gd` (locked) and `creation.gd` (Control-row mechanism) keep the old modulate pattern this round. The Step-1 rice-paper recommendation is consciously superseded by D1; record the ruling in `90_decisions.md` via the normal evidence step.
