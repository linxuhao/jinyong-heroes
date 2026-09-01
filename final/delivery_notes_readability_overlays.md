# Delivery notes — readability_overlays (2026-09-01)

## Changes made (scene-level presentational edits only)

1. `scenes/ui/roster_panel.tscn` — `RosterDim` color `Color(0, 0, 0, 0.55)` → `Color(0, 0, 0, 0.85)` (alpha only). `RosterBox` untouched: it is a bare `Panel` and receives its opaque ink-slab backing from `theme_core`'s `Panel/styles/panel`. No nodes added/removed, no geometry/z-order/mouse_filter change.
2. `scenes/ui/tutorial_overlay.tscn` — `Dim` color `Color(0, 0, 0, 0.5)` → `Color(0, 0, 0, 0.88)` (alpha only). `Title` Label got one added line: `theme_type_variation = &"TitleLabel"` (StringName form; the variation is defined in `assets/themes/global_theme.tres:117-119` — verified present). `Panel`, `Body` (RichTextLabel), CanvasLayer layer=100 untouched.
3. `scenes/ui/hud.tscn` — copied the `skill_button.tscn:48-50` shadow pattern verbatim onto both hint labels over the mountain ink strokes (3 lines each, existing outline lines byte-identical):
   - `SkillDescLabel` (kept `font_outline_color = Color(0,0,0,0.9)` / `outline_size = 3`): added `theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.85)`, `theme_override_constants/shadow_offset_x = 1`, `theme_override_constants/shadow_offset_y = 1`.
   - `MoveHintLabel` (kept `font_outline_color = Color(0,0,0,0.8)` / `outline_size = 4`, still `visible = false`): same three shadow lines.

`scripts/ui/skill_button.gd`: **zero changes** — no runtime frame evidence reached this step, so per the task card default its script-owned state palette stays as-is; the disabled「退回」hardening comes from the theme's opaque `Button/styles/disabled` + `font_disabled_color = Color(0.55,0.52,0.47,1)` on HUD buttons (HUD buttons are not script-styled). Skill buttons remain script-owned and untouched.

## Chosen values + rationale (for the evidence task)

- Roster dim alpha **0.85**: strong enough that background card buttons/text no longer bleed through the panel region at fA/s4_frame_0052, while still reading as an overlay rather than a hard black cut.
- Tutorial dim alpha **0.88**: kills the portrait bleed-through of fA/s2_frame_0158 with margin, keeping the panel as the clear information layer.
- These are judged by frames, not pinned; a future retune does not trip any pin (no color/alpha literal is asserted anywhere).

## Reference-frame mapping (AFTER captures owed to the evidence task)

| Reference frame | Scenario family to re-capture | Same frame number |
|---|---|---|
| fA/s4_frame_0052 (roster panel open) | roster_panel_cultivation_open_close | 0052 |
| fA/s2_frame_0158 (tutorial page 1) | tutorial_win_routes_to_transition | 0158 |
| fB/s2_frame_0210 (battle hints + disabled 退回) | ui_geometry_readability / skill_button_visual_states family | 0210 |

Readability judged by the vision gate or human frame review (accepted fallback): 年月/属性 rows must not collide with background text, portraits must not bleed through the tutorial scrim, hints must read over 皴笔, disabled must read as unavailable.

## Static self-checks performed (implementer has no shell/runtime)

- `search Color(0, 0, 0, 0.5[5]?)`: old alphas gone from both edited scenes; the only remaining `Color(0, 0, 0, 0.5)` in the repo is in `scenes/ui/skill_button.tscn:16` (the copy-source precedent, not in scope).
- `theme_type_variation = &"TitleLabel"` uses the required StringName literal form; variation verified in the theme file.
- Edit tool was used surgically; only the listed alpha/variation/shadow lines changed.

## Probe run (staged edits applied, `godot_playtest_scenario`)

- `roster_panel_cultivation_open_close`: PASS 16/16
- `tutorial_win_routes_to_transition`: PASS 8/8
- `ui_geometry_readability`: PASS 38/38 (protected gate, green with the hud shadow lines in place)
- staged files applied: scenes/ui/hud.tscn, scenes/ui/roster_panel.tscn, scenes/ui/tutorial_overlay.tscn

Constraints honored: zero new assets, zero strings, no gameplay/text changes, six locked files untouched, EN untouched.
