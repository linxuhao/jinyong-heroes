# 32_theme.md — Ink-wash UI theme (added by jinyong-theme, 2026-09-01)

Before this round the theme layer was a 7-line placeholder
(`assets/themes/global_theme.tres`: `default_font` + `default_font_size = 12`,
mounted globally at `project.godot:58`), so every screen outside the battle
rendered engine-default buttons and one-size left-aligned small text. This
round fills the theme, fixes three "text unreadable" spots and replaces the
2–3% brightness focus trick with a real marker. All numbers in §6 are the
official 2026-09-01 gate results, not intentions.

## 1. Single source of visual truth

- `assets/themes/global_theme.tres` (`load_steps=8`) restyles EVERY Control.
  Type variations: `TitleLabel` and `HintLabel` (both base `Label`).
- Escape hatches are by design, not accidents: script-styled battle widgets
  (skill buttons via `skill_button.gd _apply_state`, health bars, round
  indicator) and the scene-local dark Backdrop panels override the theme and
  win — the battle screen stays the anchor it already was.

## 2. Palette register — one light-on-dark ink story

Anchored to the battle screen's existing vocabulary (ink slab / paper-warm
text / hairline paper-tan border / cinnabar 朱印 + gold accents):

- Ink slabs for structure (panels, buttons) — **opaque, never translucent**:
  a layer that carries information must not let the layer below bleed through.
- Paper-warm text (`≈0.88,0.85,0.78`) on ink; near-white on hover; readable
  warm gray for disabled (`≈0.55,0.52,0.47`) so a disabled button reads as
  "unavailable", not "gone".
- Cinnabar for pressed borders and the focus marker; muted gold for hover
  borders and titles.
- Deliberately NOT rice-paper light panels: every non-battle scene keeps a
  dark backdrop and HUD text is light; a light register would demand per-node
  font-color exceptions across 7 scenes + HUD. Ruling recorded in
  `90_decisions.md` (Step-1 rice-paper suggestion consciously superseded).

## 3. Theme inventory

| Item | Value (intent, not gate-pinned) |
|---|---|
| `Button/styles/normal·hover·pressed·disabled` | four visually distinct opaque ink slabs — paper-tan / gold-tinged / cinnabar / muted-distinct borders, radius 3 |
| `Button/styles/focus` | `draw_center=false` cinnabar 2px ring (overlay drawn on top of the state box) |
| `Button/colors/font_*` (5) | paper family; focus gold; disabled readable gray |
| `Button/font_sizes/font_size` | 15 |
| `Panel/styles/panel` | **opaque** ink slab, hairline tan border, radius 3, soft shadow, content margins 16/12 — the backing that fixed the bare `RosterBox` and tutorial `Panel` |
| `Label` | paper color, size 14 |
| `RichTextLabel/colors/default_color` | paper (tutorial body) |
| `TitleLabel` variation | 26px warm gold — hierarchy top |
| `HintLabel` variation | 12px muted + black outline 0.85 / size 3 (the `hud.tscn` outline pattern hoisted into the theme) |
| `default_font_size` | stays 12 — protects script-built 8–10px labels |

Hierarchy: title 26 > button 15 > body 14 > hint 12. `TitleLabel` sits only on
top-of-screen titles whose rect fits it (tutorial title); the hint labels of
menu + the six segment scenes wear `HintLabel`. No copy and no geometry
changed — only what the same words look like.

## 4. Text-over-art rule (压字)

Any text sitting on art (皴笔 strokes, blood bars, portraits) gets outline +
shadow — the `hud.tscn:170-179` / `skill_button.tscn:46-50` pattern, hoisted
into `HintLabel` and applied per-node where art sits (the two battle hint
labels gained the shadow pair verbatim). Panels that back information are
opaque (global theme Panel + dims raised to 0.85 / 0.88 in roster_panel /
tutorial_overlay). No z-order, layer or coordinate change anywhere.

## 5. Focus marker form

`ThemeManager.option_style(focused) -> StyleBoxFlat`: two cached,
never-mutated boxes with identical geometry (min-size stable); focused =
3px cinnabar left bar + cinnabar border, plus `OPTION_FONT_FOCUS` /
`OPTION_FONT_DIM`. Applied in `cultivation.gd _rebuild_options_box` and
`sect_select.gd`, replacing the `modulate 1.0 vs 0.72` ternary at
`cultivation.gd:641`. Residual: `map.gd` (locked jinyong-huashan file) and
`creation.gd` (plain Control rows) keep the old modulate pattern — UX-21
stays OPEN with that residual recorded.

## 6. Gate evidence (official run, 2026-09-01)

- Compile: **98/98 scripts, 0 errors, 0 warnings**.
- Playtest: hard gate `passed: true`, 0 runtime errors; **78/79 PASS**. The
  one advisory FAIL is `creation_layout_readability` **21/22** (f90
  `creation_box_fits` observed `False` — the theme's Label 12→14 / Button 15
  growth overran the fixed creation rect; → UX-31 OPEN, fix route = the D6
  per-node font-size fallback).
- Five protected gates all green: `ui_geometry_readability` 38/38,
  `skill_button_visual_states` 9/9, `portrait_grid_alignment` 30/30,
  `spine_to_ending` 42/42, `equipment_in_battle_diff` 47/47.
- New differential nail `theme_focus_marker_cultivation` **14/14** (measured
  red-first: RED FAIL 12/14 — f110 `CultivationScreen.focus_marker_active ==
  true` observed `false`, 7 greens before red, second red f140; byte-exact
  restore, then green 14/14 with revert-residue proofs 16/16 and 42/42).
- Vision: **passed**, non-blind, 79 scenarios / 316 frames, all six questions
  `failed: false`; Q6 text truncation **78 good / 1 bad** — the single bad is
  a battle frame in `tutorial_loss_restarts_tutorial` ("text cut off by the
  screen edge"), not a themed screen. Every roster / tutorial / themed-screen
  scenario answered Q6 good, which is the official frame verdict that the
  three 压字 spots read cleanly on the delivered build.

### Post-fix closure (2026-09-01, 5_design)

The one advisory FAIL above (`creation_layout_readability` 21/22, UX-31) was
fixed by the review round with the D6-named fallback: `creation.tscn` now
carries exactly 14 per-node `theme_override_font_sizes/font_size = 12` pins
(13 TraitToggles + TraitDescLabel) — zero geometry/text/node/theme changes,
the hierarchy is NOT shrunk globally. Measured red-first: **21/22 FAIL**
(f90 `creation_box_fits` observed `false`, 21 greens before red) → **22/22**
green (same-frame pair: frame 90 `creation_box_fits` false→true;
`final/delivery_notes_theme.md` §7).

Official post-fix gate artifacts (this step's `5_compile` products): playtest
**79/79 scenarios PASS** (hard gate `passed: true`, `spec_used: true`, 180
frames, 0 runtime errors) with `creation_layout_readability` **22/22**, the
five protected gates green and `theme_focus_marker_cultivation` 14/14;
compile **98/98**, 0 errors, 0 warnings. `40_ux_backlog.md` **UX-31 →
CLOSED(jinyong-theme)**. Honest boundary: the vision artifact in §6 above is
still the pre-fix official run; the post-fix Q6 re-check was NOT executed
(endpoint unreachable, recorded in `final/delivery_notes_theme.md` §7.5) —
UX-31's closure rests on playtest assertions and the measured red-first pair,
not on an unexecuted vision verdict. pytest / GDScript unit-suite official
results belong to the `5_test` product (`test_report.json`) and are not
claimed here.
