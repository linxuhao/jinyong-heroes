# Delivery Notes — theme_evidence_docs (jinyong-theme)

Date: 2026-09-01 · Task: `theme_evidence_docs` — evidence assembly for the jinyong-theme round.
This task is pure documentation: it assembles the round's evidence from the three prior tasks'
delivery notes (`final/delivery_notes_theme_core.md`, `final/delivery_notes_readability_overlays.md`,
`final/delivery_notes_focus_marker_nail.md`) plus `design/99_changelog.md` (for the drafted row's
column format), and appends exactly one record line to `design/40_ux_backlog.md`.

**Honesty tiers used throughout** (per the brief's discipline, `knowledge.md`: self-runs are
"recorded evidence but not the official gate products"):
- **本步实测** — measured by this step's own real run.
- **已录** — recorded by one of the three prior tasks (their sidecar runs, direct-to-sidecar
  `godot_playtest_scenario`, or red-first direct-sidecar runs).
- **待官方闸门** — the official 5_compile / 5_vision / 5_review products (`playtest_summary.md`,
  `vision_report.json`, repo diff) which do NOT exist during the task loop. Never presented as a
  this-step measurement.

---

## 1. Before/after same-frame table

One row per fix. The **before** side is the pre-round 7-line-placeholder-theme state, whose
measured reference frame labels are reused from the brief (verified 2026-08-31 real captures):
`fA/s4_frame_0052` (roster panel), `fA/s2_frame_0158` (tutorial page 1), `fB/s2_frame_0210`
(battle hints + disabled 退回). The **after** side is the same frame number re-captured on the
themed build at the same `at:` frame. Scenario → frame mapping for each after-capture is taken
from `readability_overlays.md`'s Reference-frame mapping table. Frame-image readability is judged
by the 5_vision gate or explicit human frame review — never a silent pass.

> This implementer step has **no frame-image capture** (frames are a 5_vision product). The rows
> below record the scenario → frame mapping + the assertion-surface evidence (已录 from the three
> tasks); the actual pixel readability verdict on those frames is deferred to **5_vision 闸门 /
> 人工看帧(待官方判)**. Reference frames that cannot be reproduced in-step use the honest
> scenario/frame mapping actually used by the prior tasks.

| fix | reference frame | reproduce scenario | frame | what changed | assertion-surface evidence (已录) | judge |
|---|---|---|---|---|---|---|
| 压字 #1 roster panel | fA/s4_frame_0052 | `roster_panel_cultivation_open_close` | 0052 | `Panel/styles/panel` opaque ink slab (theme) backs bare `RosterBox`; `RosterDim` alpha 0.55→0.85; no geometry/z-order change | `roster_panel_cultivation_open_close` 16/16 PASS (theme_core §2b) + 16/16 (readability probe) | 5_vision 闸门 / 人工看帧(待官方判) |
| 压字 #2 tutorial page 1 | fA/s2_frame_0158 | `tutorial_win_routes_to_transition` | 0158 | opaque `Panel/styles/panel` backs the bare tutorial Panel; `Dim` alpha 0.5→0.88 kills portrait bleed-through; Title gets `TitleLabel` variation; Body RichTextLabel gets `default_color` | `tutorial_win_routes_to_transition` 8/8 PASS (theme_core §2b) + 8/8 (readability probe) | 5_vision 闸门 / 人工看帧(待官方判) |
| 压字 #3 battle hints + disabled | fB/s2_frame_0210 | `ui_geometry_readability` / `skill_button_visual_states` family | 0210 | hud shadow pair (font_shadow_color 0,0,0,0.85 + offsets 1/1) copied verbatim from skill_button onto SkillDescLabel/MoveHintLabel (existing outlines kept); theme's **opaque** `Button/styles/disabled` + `font_disabled_color` warm gray make 退回 read "unavailable", not "gone" | `ui_geometry_readability` 38/38 PASS (incl. Q6 text-truncation guard green), `skill_button_visual_states` 9/9 PASS (theme_core §2b/§2d) | 5_vision 闸门 / 人工看帧(待官方判) |
| "someone designed this" — menu | spine_to_ending (traversal segment) | `spine_to_ending` | traversal frames | global Button four states + Panel backing + Label/HintLabel hierarchy restyle the menu for free | `spine_to_ending` 42/42 PASS — no blank screens (theme_core §2b) | 5_vision 闸门 / 人工看帧(待官方判) |
| "someone designed this" — cultivation | spine_to_ending (traversal segment) | `spine_to_ending` | traversal frames | Button states + focus marker + HintLabel/TitleLabel hierarchy; option list focus marker (see §2) | `spine_to_ending` 42/42 PASS + `theme_focus_marker_cultivation` 14/14 PASS (focus_marker_nail green re-run) | 5_vision 闸门 / 人工看帧(待官方判) |
| "someone designed this" — ending | spine_to_ending (traversal segment) | `spine_to_ending` | traversal frames | global theme restyles the ending scene; code-built end overlay inherits opaque Button/Panel styling | `spine_to_ending` 42/42 PASS + `terminal_victory_8_12_rounds_hp_15_40` 6/6 PASS (theme_core §2c) | 5_vision 闸门 / 人工看帧(待官方判) |

No 5_vision gate product exists in the task loop; the per-frame readability verdict on the above
same-frame pairs is the official 5_vision judge (or the accepted human frame-review fallback),
recorded as **待官方闸门** — this step does not claim to have "seen" the frames.

## 2. Red-first records (transcribed verbatim from `focus_marker_nail.md`, measured)

The new focus nail `theme_focus_marker_cultivation` was measured red-first via the temporary
revert + direct sidecar run (`godot_playtest_scenario`), then byte-exact restore, then green
re-run. Four measured values (RED run — **FAIL 12/14**):

| value | measured |
|---|---|
| failing_frame | **f110** |
| first_failing_assert | `CultivationScreen.focus_marker_active: focus_marker_active == true` |
| exact_error / observed | `observed=false` (focus_marker_active was false — the revert neutralized its publication) |
| green_asserts_before_red | **7** (f80 has 6 + f110 `phase == "ACTION_PICK"` = 7) |

Second red (same root cause): f140 `CultivationScreen.focus_marker_active` `observed=false`. Total 12/14.

**Honest finding on revert scope (deviation from the literal recipe, documented in focus_marker_nail):**
`focus_marker_active` is published **independently** of the stylebox swap — `_rebuild_options_box`
sets it from `not labels.is_empty()` (cultivation.gd:661) and `_render` mirrors it from
`focused_option_text != ""` (:951). So reverting ONLY the stylebox swap would leave
`focus_marker_active` reading `true` and the f110 assert would NOT red. To produce a genuine
pre-fix red (the modulate-only world with no real marker), the revert ALSO set BOTH
`focus_marker_active` publications to `false` — the faithful simulation of "no marker published".
Restore was byte-exact (`grep "TEMPORARY RED-FIRST REVERT"` → zero hits; the only remaining
`focus_marker_active = false` is the pre-existing defensive early-return path at cultivation.gd:591).

Green re-runs on the byte-exact-restored tree (recorded by focus_marker_nail, direct sidecar):

| scenario | asserts | result |
|---|---|---|
| theme_focus_marker_cultivation | 14/14 | PASS (restored GREEN) |
| clicks_only_gongfa_empty_exit | 16/16 | PASS (revert-residue proof) |
| spine_to_ending | 42/42 | PASS (revert-residue proof) |

## 3. Alpha rationale (reviewer-flagged)

- **RosterDim alpha 0.85** (`roster_panel.tscn`): strong enough that background card buttons/text
  no longer bleed through the panel region at fA/s4_frame_0052, while still reading as an overlay
  rather than a hard black cut.
- **Tutorial Dim alpha 0.88** (`tutorial_overlay.tscn`): kills the portrait bleed-through of
  fA/s2_frame_0158 with margin, keeping the panel as the clear information layer.

Both are **judged by frames (readability), NOT pinned as literals**. No color/alpha literal is
asserted anywhere in the round's playtest/gate surface, so a legitimate future retune of these
values (or a different legal approach to opacity) does NOT trip the no-literal gate discipline.

## 4. Locked-file ledger

Six files named, **byte-identical (zero edits)**:

- `scripts/battlefield.gd`
- `scripts/autoload/game_manager.gd`
- `scripts/autoload/scene_manager.gd`
- `scripts/segments/map.gd`
- `scripts/data/map_battle_data.gd`
- `playtest/map_battle_node_huashan.yaml`

**Basis (已录):** independent declarations in all three prior tasks — `theme_core` §4 (constraints
ledger), `readability_overlays` 约束段 (Constraints honored: six locked files untouched), and
`focus_marker_nail` 作用域段 (Locked files untouched and byte-identical, same six). The
**authoritative machine check** is the repo diff reviewed at 5_review / 5_compile; this step has
no git shell, so byte-identical is marked **待官方 diff 复核** (not claimed as a this-step measure).

**Zero new art assets:** all theme additions are `StyleBoxFlat` shapes/colors only; no
`StyleBoxTexture`, no textures, no icons. The diff contains no image additions (no `.png` /
`.jpg` / `.wav` / `.import` additions from this round's changes). **零 i18n delta:** the round
adds **zero strings** (colors and shapes only), so `i18n.gd` has no change and EN cannot regress.

## 5. Full regression record

**This step's own run: 未执行 + 原因** — this documentation task has no batch runner / sidecar
available (no shell, no network; it only reads repo files and writes the two artifacts). No
this-step PASS/FAIL counts are claimed. Per the brief, "零 runtime error" is claimed **only** when
actually run this step — it was not, so it is not claimed.

**Supporting self-run counts (已录, from the three prior tasks' direct sidecar runs — recorded
evidence, NOT the official gate verdict):**

| scenario | asserts | recorded by |
|---|---|---|
| roster_panel_cultivation_open_close | 16/16 | theme_core §2b + readability probe |
| tutorial_win_routes_to_transition | 8/8 | theme_core §2b + readability probe |
| ui_geometry_readability | 38/38 | theme_core §2b/§2d (protected gate) |
| skill_button_visual_states | 9/9 | theme_core §2b/§2d (protected gate) |
| portrait_grid_alignment | 30/30 | theme_core §2b/§2d (protected gate) |
| spine_to_ending | 42/42 | theme_core §2b + focus_marker_nail green re-run |
| equipment_in_battle_diff | 47/47 | theme_core §2b/§2d (protected gate) |
| terminal_victory_8_12_rounds_hp_15_40 | 6/6 | theme_core §2b |
| theme_focus_marker_cultivation | 14/14 | focus_marker_nail green re-run |

**Five protected gates re-verified by name** (all green in the prior tasks' self-runs): `ui_geometry_readability`
(38/38), `skill_button_visual_states` (9/9), `portrait_grid_alignment` (30/30), `spine_to_ending`
(42/42), `equipment_in_battle_diff` (47/47). Protected numeric surfaces are all code/tscn-owned and
untouched by the theme.

**Full-suite verdict + zero-error confirmation: 待官方闸门** — the official 78+1 full run and the
`playtest_summary.md` / `vision_report.json` / repo-diff products are produced by 5_compile /
5_vision AFTER this step. Self-runs are not the gate verdict (per `knowledge.md`).

## 6. 5_design handoff

### UX-21 / UX-22 disposition inputs (this round's results)

- **UX-21 (焦点高亮低于可感知阈值)** — the focus marker landed: `ThemeManager.option_style(focused)`
  stylebox + font-color swap replaces the 2–3 % brightness `modulate` at `cultivation.gd:641`
  (`_rebuild_options_box`) and the same helper is adopted at `sect_select.gd:84`. New differential
  scenario `theme_focus_marker_cultivation` (14/14) + new published surface
  `CultivationScreen.focus_marker_active` (real render state). **Honest residual:** `map.gd`
  (LOCKED, zero-change this round) and `creation.gd` (AttrRow is a plain Control, not a Button —
  a different mechanism) both keep the old `modulate` pattern. So UX-21 may be closed **at most for
  the covered sites** (cultivation/sect_select), or kept OPEN with the map/creation residual noted
  — decided by 5_design strictly from this round's actual results.
- **UX-22 (角色页面板透明、背景串字)** — fixed structurally, not an alpha twiddle: the global
  `Panel/styles/panel` gives bare `RosterBox` an opaque ink slab + border, and `RosterDim` 0.55→0.85;
  the tutorial overlay gets the same opaque panel + `Dim` 0.5→0.88. Frame-readability verdict is the
  judge (see §1/§3). Status decision (CLOSED vs OPEN) is 5_design's call from the official
  `playtest_summary.md` / frame judgment.

### Draft changelog row (DRAFT — for 5_design to append; NOT written to `design/99_changelog.md`)

Column format taken from `design/99_changelog.md` (4 columns: Run | Date | Change | Why). Draft
only; 5_design appends it after confirming gate products:

```
| jinyong-theme | 2026-09-01 | (DRAFT — 待闸门证据收口后由 5_design 追加)界面真主题:7 行 global_theme.tres → 完整 Button 四态+焦点 / Panel / Label / RichTextLabel + TitleLabel·HintLabel 分级;roster_panel(不透明 Panel 底板 + dim 0.85)/ tutorial_overlay(dim 0.88 + TitleLabel)压字结构性修复;战场提示 hud 描边+投影(照 skill_button 先例)、禁用态不透明可辨;养成/拜师焦点 stylebox+字色换装(替 2–3% modulate)+ 新差分场景 theme_focus_marker_cultivation。零新资产、零 i18n delta、六锁定文件 byte-identical。 | 三处「压字读不了」+ 焦点低于可感知阈值,全为呈现层,改的是字长什么样不改说什么。 |
```

5_design: append exactly **one** line to `design/99_changelog.md` (do not touch existing rows),
fill `00_roadmap.md` phase-4 numbers from gate artifacts only (no prediction), and resolve
UX-21/UX-22 statuses strictly per results — including the honest residual above.
