# Technical Architecture Design — Round: 把界面排出来 (Interface Layout)

**Project:** jinyong-clickmove round 2 — Godot 4 grid tactics ("Huashan Sword Tournament"). Viewport 960×704 (`canvas_items`/`keep`), HUD on CanvasLayer 10 (scale-1: HUD px == viewport px).

**Round goal** (from the brief + `step1_sota.md`, ground-truth frames `s42_frame_0030.png` / `s39_frame_0070.png`):

1. **Creation-screen re-layout** — five attr rows are crammed top-left, the `-`/`+` buttons visually disconnected from their row labels, the points label floats, a large black void dominates, and the three phases (ATTRS / TRAITS / CONFIRM) lay out differently. Fix with **property-only** layout changes (no reparenting / renaming / new containers between pinned path segments).
2. **Battle top bar** — "回合 1" unreadable against Wang Chongyang's portrait, the order line half-covered by the yellow ActiveLabel panel and low-contrast on the sky, the skill hint over Ouyang Feng's HP bar, HP-bar name labels over portraits. Fix by putting the five items (回合数 / 出手顺序 / 行动条 / 技能提示 / 血条姓名) into a non-overlapping, backed layout — the brief's "照这个形状补齐" = extend the existing `_update_geometry_observables()` pattern: one bool observable per fixed overlap pair, asserted `== false` in `ui_geometry_readability.yaml`.

**Stack (fixed):** Godot 4.4, GDScript, Chinese UI text, playtest gate (`playtest/*.yaml` + `tests/test_playtest_contract_smoke.py`), visual gate unchanged (six fixed questions — **no new questions this round**; single-frame spatial questions are judged numerically by playtest, per `design/30_presentation.md`).

All design below is grounded in verified repo reads: `scenes/ui/hud.tscn`, `scripts/ui/hud.gd`, `scripts/ui/round_indicator.gd`, `scripts/ui/health_bar.gd`, `scenes/segments/creation.tscn`, `scripts/segments/creation.gd`, `playtest/_common.yaml`, `playtest/ui_geometry_readability.yaml`, `playtest/creation_single_ui.yaml`, `tests/test_playtest_contract_smoke.py`.

---

## 1. Overview

Two independent geometry subsystems, one shared idiom:

- **Battle top strip.** Add one new `TopStrip` Panel node to `hud.tscn` (drawn behind all top widgets, `mouse_filter = 2`), semi-transparent dark backing `StyleBoxFlat`. Relocate the existing top widgets *by offsets/anchors only* so that RoundLabel / ActiveLabel / OrderLabel / ActionHintLabel / EnergyLabel all sit inside the strip band, pairwise non-overlapping. The ActionHintLabel moves **in position, not in path** (stays a direct child of HUD, per the SOTA recommendation). PauseButton stays where it is (never moved into the strip). EndTurn / Attack / SkillDesc shift down so nothing straddles the strip's bottom edge.
- **HP-bar discipline.** `health_bar.gd` gains a strip-aware bottom clamp (bar top ≥ strip bottom + 2) so floating bars never enter the strip zone, and the name label gets a small semi-transparent backing so it reads even where a portrait passes behind it.
- **Creation rhythm.** `creation.tscn` gets property-only rhythm: uniform row heights, expand-filled right-aligned value labels hugging the `-`/`+` cluster, container separations, PointsLabel repositioned onto the group, fixed-size centered CONFIRM buttons. `creation.gd` computes per-frame geometry observables (same shape as hud.gd).
- **Gate wiring.** Append-only surface additions in `playtest/_common.yaml`; extend `ui_geometry_readability.yaml` **in place** (no two-place sync); one new scenario `creation_layout_readability.yaml` (boots `res://scenes/segments/creation.tscn` directly — needs the two-place sync: `scenario_order` + `ROUND_SCENARIOS`, both appended at the end in the same order).

**No gameplay, no numbers, no assets, no visual-gate changes.** All edits are scene-property changes plus additive script observables. Every existing scenario asserts node names/paths or behavior, never pixel offsets — so property-level edits cannot break them (see §8 for the per-chain audit).

---

## 2. Architecture Diagram (text)

```
BATTLE HUD (CanvasLayer 10, scale-1 — all rects below share ONE coordinate system;
no Node2D↔Control conversion anywhere in this design — see decision E5)

hud.tscn (sibling draw order = tree order; TopStrip inserted as FIRST child => drawn
behind everything else on the layer):

  HUD (Control, full-screen, mouse_filter=2)
  ├── TopStrip        [NEW Panel, full-width 0..80, mouse_filter=2,
  │                    StyleBoxFlat bg (0.07,0.07,0.10,0.60)]      <- backing band
  ├── HealthBarContainer   (unchanged tree order; bars clamp BELOW strip at runtime)
  ├── SkillBar / rows      (unchanged)
  ├── ActionHintLabel      (anchors moved: center-top, y 62..78 — inside strip)
  ├── RoundIndicator       (center-top 400px, y 0..56: RoundLabel 0..20 /
  │                         ActiveLabel 22..42 / OrderLabel 44..60)
  ├── EnergyLabel          (y 4..24)
  ├── PauseButton          (y 8..44, unchanged position — sits ON the strip band)
  ├── EndTurnButton        (y 52..88  ->  84..120, clears strip bottom edge)
  ├── AttackButton         (y 96..132 -> 124..160)
  └── SkillDescLabel       (y 140..320 -> 164..344, clears AttackButton)

health_bar.gd (per floating widget):
  desired pos = above sprite top (existing) -> clamp y >= STRIP_BOTTOM + 2 (= 82)
  NameLabel += backing StyleBoxFlat (semi-transparent, built once in setup)

hud.gd _update_geometry_observables() (runs FIRST in _process, before the player
null-check — readable pre-battle; guards: null/invalid/visible per widget):
  per-frame write of: top_text_pairwise_overlap, top_text_in_strip,
  top_strip_alpha, hint_hpbar_overlap, hpbar_strip_overlap   (+ existing 5 vars)

CREATION SCREEN (direct creation.tscn boot in the playtest):

creation.tscn (property-only; tree/paths byte-identical):
  MouseBox (VBox, 560x480 centered) -> separation 14
  ├── AttrBox:    separation 10; rows min-height 44, HBox separation 6;
  │               AttrLabel min 180 + horizontal_alignment=2 + size_flags=3
  │               (value text right-aligned, hugging -/+ cluster at row right);
  │               buttons min 44x34; AttrNavRow min-height 44
  ├── TraitBox:   separation 4; toggles min-height 24 (13 rows fit; no overflow)
  └── ConfirmBox: separation 12; ConfirmButton/BackButton
                  size_flags_horizontal=4 (shrink-center) + min (240,44)
  PointsLabel -> offsets so it sits 8..24 px above MouseBox top, x-centered.

creation.gd _update_geometry_observables() (every _process):
  per-frame write of: attr_rows_uniform, attr_label_alignment_ok,
  points_attrs_gap_ok, phase_skeleton_same, creation_in_viewport, creation_box_fits

GATES:
  playtest/_common.yaml   surface += HUD.* (5) / HealthBar.* (1) / TopStrip block /
                          CreationScreen.* (6); scenario_order += creation_layout_readability
  ui_geometry_readability.yaml   extended IN PLACE (existing asserts untouched)
  creation_layout_readability.yaml  NEW (scene boot, clicks: AttrNextButton/TraitNextButton)
  tests/test_playtest_contract_smoke.py  ROUND_SCENARIOS += creation_layout_readability
                          + test_topbar_layout_surface_contract()
```

---

## 3. Component List

### 3.1 `scenes/ui/hud.tscn` — top strip + widget repositioning (property-only)

**Responsibility:** make the battle top texts live inside one backed band, pairwise non-overlapping, without touching node identity.

**Changes (all offsets/anchors; no renames, no reparents, no type changes):**

| Node | Change |
|---|---|
| `TopStrip` (NEW) | Insert as **first child** of HUD (drawn behind everything). `type="Panel"`, anchors preset 10 (left=0, right=1), offsets `0,0,0,80`. `mouse_filter = 2` (mandatory — a full-width Control would otherwise eat battlefield clicks; the SegmentHost lesson, changelog 2026-08-25). `theme_override_styles/panel` = new `StyleBoxFlat` sub_resource: `bg_color = Color(0.07, 0.07, 0.10, 0.6)` (semi-transparent — see decision E6), no border. `load_steps` bumps 4 → 5. |
| `RoundIndicator` | `offset_top` 8 → 0, `offset_bottom` 72 → 56 (width/anchors unchanged: 400px centered — CJK order line verified to fit at font 10, no re-verify needed). |
| `RoundIndicator/OrderLabel` | `offset_bottom` 64 → 60 (16px line, font 10). |
| `ActionHintLabel` | Anchors from bottom-center (preset 7) to top-center (preset 5): `anchor_left=0.5, anchor_right=0.5`, offsets `left=-200, top=62, right=200, bottom=78`. Keep `mouse_filter = 2`, `clip_text = false`, `visible = false` default. |
| `EnergyLabel` | `offset_top` 8 → 4, `offset_bottom` 28 → 24. |
| `EndTurnButton` | y 52..88 → 84..120. |
| `AttackButton` | y 96..132 → 124..160. |
| `SkillDescLabel` | y 140..320 → 164..344 (clears AttackButton's new bottom edge). |
| `PauseButton` | **Unchanged** (y 8..44; sits on the strip band — fine, it is not one of the five text items). |

Resulting strip content (y): RoundLabel 0..20, ActiveLabel 22..42, OrderLabel 44..60, hint 62..78 — all inside strip 0..80, ≥2px vertical gaps between every pair.

**Interface:** none (pure scene). Nodes keep exact names/paths; `hud.gd`'s `$` refs all still resolve.

### 3.2 `scripts/ui/hud.gd` — battle geometry observables

**Responsibility:** per-frame, decidable non-overlap facts for the playtest gate (the brief's "照这个形状补齐" — same shape as `round_pause_overlap` / `hud_button_overlap`).

**New surface vars (append-only; declared at the top next to the existing five):**

```gdscript
var top_text_pairwise_overlap: bool = false  # any pair of the top text rects visually overlaps
var top_text_in_strip: bool = true           # every top text rect ⊆ TopStrip rect (±2px)
var top_strip_alpha: float = 1.0             # backing alpha read from the strip stylebox
var hint_hpbar_overlap: bool = false         # visible hint rect ∩ any visible bar rect
var hpbar_strip_overlap: bool = false        # any visible bar rect ∩ TopStrip rect
```

**`_update_geometry_observables()` extension** (after the existing block; same guard style — `get_node_or_null` re-resolution + `is_instance_valid` + `visible` gates; runs before the player null-check so it is readable pre-battle):

- Resolve `TopStrip` via `get_node_or_null("TopStrip") as Panel`; cache in a member.
- **Overlap convention (single, documented):** a pair "overlaps" iff the two rects intersect after each is inset by 1px on all sides — helper `_inset_overlap(a: Rect2, b: Rect2) -> bool: return a.grow(-1.0).intersects(b.grow(-1.0))`. `Rect2.intersects()` is inclusive of touching edges; two stacked labels with a 2px gap must not read as overlapping (SOTA edge case E1). This helper is the ONLY overlap predicate used by every new observable.
- `top_text_pairwise_overlap`: pairwise `_inset_overlap` over {RoundLabel, ActiveLabel, OrderLabel, EnergyLabel} plus ActionHintLabel **only when `visible`** (hidden widgets still have rects — a hidden hint at an old position would false-positive; SOTA E2). Labels resolved via `_round_indicator` children and existing members.
- `top_text_in_strip`: for the same set (hint again only when visible): `strip.grow(2.0).encloses(r)` AND `r.size.x > 0`. True by construction after 3.1; pins it.
- `top_strip_alpha`: `sb = strip.get_theme_stylebox("panel")`; `top_strip_alpha = sb.bg_color.a if sb != null else 1.0`.
- `hint_hpbar_overlap`: **only evaluated when the hint is visible** — iterate `_health_bars` (existing array of instantiated HealthBar Controls), skip invalid, test `_inset_overlap(hint rect, bar.get_global_rect())`; any hit → true. When the hint is hidden, keep the last value (or false) — it is only asserted at frames where the hint is visible (E2 convention: skip non-visible, never assert a hidden-hint frame).
- `hpbar_strip_overlap`: any valid visible bar's rect vs TopStrip rect via `_inset_overlap`. With the 3.3 clamp this is structurally false; the observable pins it (a bar under the strip would be dimmed by the backing — the readability defect moved, not fixed).

All rects live on the same CanvasLayer-10 scale-1 space — no coordinate conversion anywhere in this component.

### 3.3 `scripts/ui/health_bar.gd` — strip clamp + name-label backing

**Responsibility:** keep floating HP widgets out of the strip zone and make name labels readable on artwork.

**Changes:**

1. **Constant** `const STRIP_BOTTOM: float = 80.0` (strip height in viewport px — the battle HUD's top band; documented as the pair of hud.tscn's TopStrip offsets).
2. **Clamp** in `follow_character()`: after the existing viewport edge-clamps, add `root.position.y = maxf(root.position.y, STRIP_BOTTOM + 2.0)`. `follow_delta` stays computed BEFORE any clamp (existing semantics preserved — the player's mid-board bar at f30 never engages the new clamp, so `HealthBar.follow_delta <= 24` in `ui_geometry_readability` is untouched).
3. **Name backing** in `setup()` (idempotent, same defensive `get_node_or_null` pattern): build one cached `StyleBoxFlat` (bg `Color(0.05, 0.05, 0.08, 0.7)`, corner radius 2, `content_margin_all(2.0)`) and `add_theme_stylebox_override("normal", ...)` on `_name_label`. New surface var written unconditionally in `setup()`:
   ```gdscript
   var name_backing_alpha: float = 0.0   # 0.7 once the backing exists; 0.0 fallback
   ```

**Interface:** additive only. Existing unit tests (`test_health_bar.gd` pins the 68×20 widget geometry, labels 9px, bar y=12) are unaffected — the backing is a stylebox override, not layout; the clamp only engages for sprites whose bar would reach y < 82.

### 3.4 `scenes/segments/creation.tscn` — layout rhythm (property-only)

**Responsibility:** uniform, breathing layout across ATTRS / TRAITS / CONFIRM without touching the pinned tree (`MouseBox/AttrBox/AttrRow0/AttrMinus0` … paths must stay byte-identical — no reparenting, no renaming, no new container between pinned path segments; only sibling-level additions would be legal and none are needed).

**Changes:**

| Node | Change |
|---|---|
| `MouseBox` | `theme_override_constants/separation = 14` (breathing between the phase blocks and PointsLabel rhythm). |
| `PointsLabel` | Keep node + name + anchors preset 8; offsets `top=-268, bottom=-248` → rect y 84..104, bottom 8px above MouseBox top (112). x stays `-200..200` (centered == MouseBox center). |
| `AttrBox` | `theme_override_constants/separation = 10`. |
| `AttrRow0..4` | `custom_minimum_size = Vector2(0, 44)` (uniform row height — kills the "crammed" look and the void); `theme_override_constants/separation = 6`. |
| `AttrRow*/AttrLabel` | Keep `custom_minimum_size = Vector2(180, 0)`; add `horizontal_alignment = 2` (right) + `size_flags_horizontal = 3` (expand-fill). The value text ("根骨 10") right-aligns and the row's `-`/`+` cluster hugs it at the row's right edge — label and buttons read as one group (the reported "`-`/`+` disconnected from row labels" defect). |
| `AttrRow*/AttrMinusN` / `AttrPlusN` | `custom_minimum_size = Vector2(44, 34)` (uniform, grouped touch targets; rows stretch them to 44). Keep `focus_mode = 0`. |
| `AttrNavRow` | `custom_minimum_size = Vector2(0, 44)`. |
| `AttrDescLabel` | `custom_minimum_size = Vector2(0, 48)` (reserved rhythm when visible; hidden children occupy no layout space, so the default-hidden state is unaffected). |
| `TraitBox` | `theme_override_constants/separation = 4`; each `TraitToggle0..12` `custom_minimum_size = Vector2(0, 24)` (13 × 24 + 12 × 4 + desc + nav stays inside the 480-tall box with desc visible — verified by the `creation_box_fits` observable). |
| `TraitNavRow` | `custom_minimum_size = Vector2(0, 44)`. |
| `ConfirmBox` | `theme_override_constants/separation = 12`; `ConfirmButton` / `BackButton`: `size_flags_horizontal = 4` (shrink-center — fixed width instead of full-width stretch) + `custom_minimum_size = Vector2(240, 44)` (BackButton 160, 44). |

**Interface:** none. `creation.gd`'s `get_node("MouseBox/…")` paths all still resolve — nothing was moved, renamed, or re-typed.

### 3.5 `scripts/segments/creation.gd` — creation geometry observables

**Responsibility:** per-frame, decidable rhythm facts for the new scenario (same pattern as hud.gd).

**New surface vars (append-only):**

```gdscript
var attr_rows_uniform: bool = true          # all 5 visible attr rows: same height/left/right (±1px)
                                            #   and height >= 32 (grouping + touch size)
var attr_label_alignment_ok: bool = true    # all five AttrRow*/AttrLabel: horizontal_alignment == 2
                                            #   AND size_flags_horizontal == 3 — pins the FIX ITSELF.
                                            #   Probed at HEAD (scenes/segments/creation.tscn): AttrLabel
                                            #   carries ONLY custom_minimum_size = Vector2(180, 0) — no
                                            #   alignment, no size_flags. The reported ~190px void between
                                            #   text and "-" is INSIDE the label rect, so a rect-gap
                                            #   observable is green before the fix and proves nothing.
var points_attrs_gap_ok: bool = true        # PointsLabel bottom .. current phase box top in [4,24]
                                            #   and x-centers within 4px
var phase_skeleton_same: bool = true        # visible phase box top offset == recorded ATTRS top (±2px)
var creation_in_viewport: bool = true       # MouseBox rect inside viewport inset 16
var creation_box_fits: bool = true          # current visible phase box content bottom <= MouseBox bottom - 8
```

**`_update_geometry_observables()`** — new private method called from `_process` (creation.gd already has a `_process` for the DEBUG action). Logic:

- Resolve phase boxes via the existing `get_node("MouseBox/AttrBox")`-style paths (they already exist in `_wire_mouse_widgets`); gate every measurement on `visible` (TraitBox/ConfirmBox are hidden in ATTRS; hidden Controls still report rects — E2).
- `attr_rows_uniform` / `attr_label_alignment_ok`: computed only when `phase == "ATTRS"` (rows only exist there); otherwise keep last value. `attr_label_alignment_ok` resolves each row label via `get_node("MouseBox/AttrBox/AttrRow%d/AttrLabel" % i)` and requires `horizontal_alignment == 2 and size_flags_horizontal == 3` on ALL FIVE rows. It is a computed bool rather than direct `AttrLabel.*` node asserts because all five labels share the bare name `AttrLabel` and the harness's recursive bare-name search cannot disambiguate five matches (the same unique-name requirement that forces `_ClickTarget` suffixes on click hit-surfaces).
- `points_attrs_gap_ok`: compare `PointsLabel` rect against the CURRENT visible phase box (AttrBox / TraitBox / ConfirmBox) — same invariant in every phase.
- `phase_skeleton_same`: on the first frame with `phase == "ATTRS"`, record `_ref_box_top = AttrBox.get_global_rect().position.y`; in other phases compare the visible box's top against it (±2px).
- `creation_in_viewport` / `creation_box_fits`: always computed from `MouseBox` / visible phase box rects.

**Interface:** no behavior change — `_render`, phase transitions, wiring, and all existing surface vars stay byte-identical.

### 3.6 `playtest/_common.yaml` — surface + scenario order (append-only)

**Surface additions** (append-only direction, sanctioned by the SOTA):

```yaml
  HUD:                # append to existing block
  - top_text_pairwise_overlap
  - top_text_in_strip
  - top_strip_alpha
  - hint_hpbar_overlap
  - hpbar_strip_overlap
  TopStrip:           # NEW block
  - visible
  - size
  HealthBar:          # append to existing block
  - name_backing_alpha
  CreationScreen:     # append to existing block
  - attr_rows_uniform
  - attr_label_alignment_ok
  - points_attrs_gap_ok
  - phase_skeleton_same
  - creation_in_viewport
  - creation_box_fits
```

**`scenario_order`:** append `creation_layout_readability` at the END (after `creation_single_ui`).

### 3.7 `playtest/ui_geometry_readability.yaml` — extend IN PLACE

Same file, same scenario, no two-place sync. Append new asserts to the existing f30 block and add one hint-visible block (skeleton — PM fills/verifies exact frames by probing, 先取值再动手):

```yaml
    # ---- appended to the existing f30 assert block (existing 24 asserts untouched) ----
    HUD.top_text_pairwise_overlap: top_text_pairwise_overlap == false
    HUD.top_text_in_strip: top_text_in_strip == true
    HUD.top_strip_alpha: top_strip_alpha >= 0.55  # single-sided lower bound: pins that a backing exists.
    # NO upper bound — making the strip more opaque is the better direction and must stay legal
    # (design/30_presentation.md precedent: tutorial panel = 不透明底色)
    HUD.hpbar_strip_overlap: hpbar_strip_overlap == false
    TopStrip.visible: visible == true
    HealthBar.name_backing_alpha: name_backing_alpha > 0.3
# ---- new entries after the existing f85 block ----
- at: 100
  actions:
  - skill_1            # selecting a skill makes the hint line visible
- at: 115
  actions: []
  assert:
    ActionHintLabel.visible: visible == true
    HUD.hint_hpbar_overlap: hint_hpbar_overlap == false
```

Rules obeyed: every assert value contains a comparison operator (the `30_presentation.md` hard rule); `hint_hpbar_overlap` is only asserted while the hint is visible (E2); `round_pause_overlap`'s existing assert stays byte-identical (RoundIndicator width unchanged → still false).

### 3.8 `playtest/creation_layout_readability.yaml` — NEW scenario

Direct `creation.tscn` boot (proven pattern from `creation_single_ui`; asserts hold at f30 on a direct boot). Skeleton with placeholders for PM:

```yaml
name: creation_layout_readability
description: >-
  creation.tscn direct boot: the three phases share one vertical skeleton — uniform
  attr rows with the value label hugging its -/+ cluster, the points label attached
  to the block, everything inside the viewport, and no phase overflows its box.
scene: res://scenes/segments/creation.tscn
timeline:
- at: 30
  actions: []
  assert:
    CreationScreen.phase: phase == "ATTRS"
    CreationScreen.attr_rows_uniform: attr_rows_uniform == true
    CreationScreen.attr_label_alignment_ok: attr_label_alignment_ok == true
    CreationScreen.points_attrs_gap_ok: points_attrs_gap_ok == true
    CreationScreen.creation_in_viewport: creation_in_viewport == true
    CreationScreen.creation_box_fits: creation_box_fits == true
- at: 40
  clicks:
  - AttrNextButton        # real mouse event on the 下一步 button -> TRAITS
- at: 90
  actions: []
  assert:
    CreationScreen.phase: phase == "TRAITS"
    CreationScreen.phase_skeleton_same: phase_skeleton_same == true
    CreationScreen.points_attrs_gap_ok: points_attrs_gap_ok == true
    CreationScreen.creation_box_fits: creation_box_fits == true
- at: 100
  clicks:
  - TraitNextButton       # -> CONFIRM
- at: 150
  actions: []
  assert:
    CreationScreen.phase: phase == "CONFIRM"
    CreationScreen.phase_skeleton_same: phase_skeleton_same == true
    CreationScreen.creation_box_fits: creation_box_fits == true
```

Has real input (clicks — satisfies the "every scenario must press something" rule). Click targets `AttrNextButton` / `TraitNextButton` are whitelisted surface blocks and buttons (bare-name recursive search finds them wherever layout puts them — moving them does not invalidate the click). Frame numbers are placeholders; PM probes observed values before pinning.

**Two-place sync (mandatory):** append the name to `playtest/_common.yaml` `scenario_order` AND to `ROUND_SCENARIOS` in `tests/test_playtest_contract_smoke.py`, same order (end of both lists).

### 3.9 `tests/test_playtest_contract_smoke.py` — contract pin

1. `ROUND_SCENARIOS` += `"creation_layout_readability"` (appended last, matching `scenario_order`).
2. New test `test_topbar_layout_surface_contract()` (mirrors the existing `test_click_move_surface_contract` shape):

```python
def test_topbar_layout_surface_contract() -> None:
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    assert "TopStrip" in blocks, "surface has no TopStrip block"
    hud_items = blocks.get("HUD", [])
    for var in ("top_text_pairwise_overlap", "top_text_in_strip", "top_strip_alpha",
                "hint_hpbar_overlap", "hpbar_strip_overlap"):
        assert var in hud_items, "HUD.%s not whitelisted on the surface" % var
    creation_items = blocks.get("CreationScreen", [])
    for var in ("attr_rows_uniform", "attr_label_alignment_ok", "points_attrs_gap_ok",
                "phase_skeleton_same", "creation_in_viewport", "creation_box_fits"):
        assert var in creation_items, "CreationScreen.%s not whitelisted on the surface" % var
    assert "name_backing_alpha" in blocks.get("HealthBar", []), \
        "HealthBar.name_backing_alpha not whitelisted on the surface"
```

---

## 4. Observable Contract (interface spec — PM fills thresholds, implementers match names exactly)

All names below are the **hard contract** between implementation, `_common.yaml` surface, and scenario asserts (Expression evaluation on live nodes — names must match verbatim).

| Node | Var | Type | Meaning (convention) | Asserted as |
|---|---|---|---|---|
| HUD | `top_text_pairwise_overlap` | bool | any pair of {RoundLabel, ActiveLabel, OrderLabel, EnergyLabel, ActionHintLabel*} `_inset_overlap`s (* only when visible) | `== false` (f30 + hint-visible frame) |
| HUD | `top_text_in_strip` | bool | every top text rect ⊆ TopStrip.grow(2) | `== true` |
| HUD | `top_strip_alpha` | float | strip panel `bg_color.a` (1.0 fallback) | `>= 0.55` (single-sided: pins that a backing exists; NO upper bound — an upper bound forbids the strictly-better direction of a more opaque strip, cf. the 不透明底色 tutorial-panel precedent) |
| HUD | `hint_hpbar_overlap` | bool | visible hint ∩ any visible bar (inset convention) | `== false` (only while hint visible) |
| HUD | `hpbar_strip_overlap` | bool | any visible bar ∩ TopStrip | `== false` |
| TopStrip | `visible` / `size` | — | strip node presence | `visible == true` |
| HealthBar | `name_backing_alpha` | float | backing stylebox alpha written in `setup()` | `> 0.3` |
| CreationScreen | `attr_rows_uniform` | bool | 5 rows equal height/left/right ±1px and height ≥ 32px (ATTRS only) | `== true` |
| CreationScreen | `attr_label_alignment_ok` | bool | all five AttrRow*/AttrLabel: `horizontal_alignment == 2` AND `size_flags_horizontal == 3` — pins the fix itself; a rect-gap check is green pre-fix (the void sits inside the label rect) | `== true` |
| CreationScreen | `points_attrs_gap_ok` | bool | PointsLabel bottom → phase box top ∈ [4,24]; x-centers ≤ 4px apart | `== true` |
| CreationScreen | `phase_skeleton_same` | bool | visible box top == recorded ATTRS top ±2px | `== true` (TRAITS/CONFIRM frames) |
| CreationScreen | `creation_in_viewport` | bool | MouseBox ⊆ viewport inset 16 | `== true` |
| CreationScreen | `creation_box_fits` | bool | visible phase content bottom ≤ MouseBox bottom − 8 | `== true` |

**Conventions (decided here, binding):** overlap = `Rect2` intersect after 1px inset on each side (`_inset_overlap`); hidden widgets are skipped, never asserted; all battle rects share the layer-10 scale-1 coordinate space (no conversions); the five existing HUD observables (`round_pause_overlap`, `skill8_right_edge`, `skill12_right_edge`, `hud_button_overlap`, `hud_desc_overlap`) keep their exact semantics. Label/button grouping on the creation screen is pinned by the fix's own properties, not by rect gaps: `attr_label_alignment_ok` reads `horizontal_alignment == 2` and `size_flags_horizontal == 3` on all five `AttrRow*/AttrLabel` nodes — a rect-gap observable measures nothing here, the defect void sits inside the label's own 180px rect (probed at HEAD: `AttrLabel` carries only `custom_minimum_size`, no alignment/size_flags). Strip backing alpha is pinned single-sided (`>= 0.55`, no upper bound): the gate proves a backing exists and must never forbid making it more opaque.

---

## 5. Edge Cases (from `step1_sota.md`) and how this design handles them

- **E1 `Rect2.intersects()` inclusive of touching edges** → single `_inset_overlap` convention, 1px inset per side, used by every new pair; stacked labels with 2px gaps never read as overlapping.
- **E2 Hidden widgets still have rects** → hint excluded from pairwise/strip membership when hidden; `hint_hpbar_overlap` evaluated and asserted only on visible-hint frames; creation phase boxes gated on `visible`.
- **E3 Coordinate spaces (HUD vs world)** → avoided entirely: no observable compares a Control rect to a Node2D sprite rect. Text-vs-portrait readability is encoded structurally (`top_text_in_strip` + `top_strip_alpha`), because the strip legitimately overlaps top-row portraits (see E6).
- **E4 "Covered by an opaque bar" vs "geometrically non-overlapping"** → the architect's chosen formulation, documented: text-to-text pairs are strict (`== false`), text-vs-strip is containment (`== true`), text-vs-portrait is the structural fact (text in backed strip + backing alpha pinned), hint-vs-HP-bar and HP-bar-vs-strip are strict (`== false`). These are different assertions and the doc records which one each observable encodes.
- **E5 HP bars are dynamic** → strip assertions are mode/position-agnostic; `hint_hpbar_overlap` is sampled only at a deterministic frame where the hint is visible; no bar-vs-bar assert exists (adjacent units' 68px widgets can legitimately touch at 64px cell spacing — not pinned).
- **E6 Two-row vs single-row skill bar** → all new observables are top-strip only; the skill bar is untouched, so the observables are mode-agnostic by construction.
- **E7 Node identity pinned, layout not** → every change is a property change (offsets, anchors, `size_flags`, `theme_override_constants`, alignment, min sizes). No reparenting, renaming, type changes, or containers inserted between pinned path segments (`MouseBox/AttrBox/AttrRow0/AttrMinus0` …, `HUD.*` names, `RoundIndicator/*` names). The one new node (`TopStrip`) is a sibling addition at a path nothing pins.
- **E8 New clickable / full-screen host disciplines** → `TopStrip.mouse_filter = 2` (full-width host); no new clickables introduced (PauseButton stays where it is); all existing buttons keep `focus_mode = 0`.
- **E9 Assertions must contain operators** → every new assert value is `== false` / `== true` / a comparison chain; never a bare scalar.
- **E10 New scenario two-place sync** → `creation_layout_readability` appended to both `scenario_order` and `ROUND_SCENARIOS` (same order); the in-place extension of `ui_geometry_readability` avoids sync for the battle half.
- **E11 Pre-battle frames** → HUD observables computed before the player null-check (existing ordering preserved); TopStrip exists in the scene from load, so all reads are safe pre-battle.
- **E12 Baseline protection** → see §8.
- **E13 CJK fit** → RoundIndicator keeps its 400px width (order line already verified at font 10); hint strings fit the 400px band at font 12 (longest ~"已出手,无法退回" ≈ 100px); no text_overrun changes.
- **E14 PointsLabel/HintLabel not buttons** → names kept, repositioned via anchors/offsets only; `PointsLabel` stays visible in ATTRS (`creation_single_ui` asserts `visible` + `text.contains("剩余点数")` — unchanged).

---

## 6. Safety, Baseline Protection, Rollback

**No irreversible operations exist in this design** — no schema/data migrations, no deletions, no rewrites of user data. All changes are (a) `.tscn` property edits, (b) additive script vars + one new method, (c) append-only playtest/test edits. Rollback = `git revert` of any component independently; the components are order-independent (3.1/3.2/3.3 are battle-side, 3.4/3.5 are creation-side, 3.6–3.9 are gate-side and only pin what already exists). Where an edit is destructive (hud.tscn offsets change), the pre-change values are in VCS history; no "delete-then-write" sequence exists anywhere.

**Order of work (the "先取值,再动手" discipline):** probe observed values first — re-measure the defect frames (`5_compile/frames/s42_frame_0030.png`, `s39_frame_0070.png`) and the current rects before editing; after editing, re-probe and confirm the new observables are green before pinning asserts.

**Must stay green (audited, not assumed):**

| Chain | Why it survives property-only changes |
|---|---|
| `click_move_*` (10/10, 9/9), `click_targeting_fixed` | clicks aim at node rect centers — buttons/bars moved still receive the event; `TopStrip.mouse_filter = 2` means the new full-width Control eats nothing |
| five creation scenarios incl. `creation_single_ui` (16/16) | they assert phase/points/attrs/visible/wiring/`cursor_markers_visible` — no pixel offsets; node paths unchanged |
| `ui_geometry_readability` (24/24) | existing asserts kept byte-identical; `round_pause_overlap` unchanged (RoundIndicator width/pause position untouched); `HealthBar.*` geometry asserts read the player's mid-board bar (new clamp never engages there); `follow_delta` computed pre-clamp |
| `skill_hint_and_range_highlight`, `skill_rejection_reason_texts` | they assert `ActionHintLabel.visible/text` — text paths untouched, only position moved |
| `battle_end_turn_attack_buttons`, `skill_description_visible` | they assert size/disabled/mouse_filter/visible/text — not position |
| `spine_to_ending`, tutorial chain, `terminal_victory` (deliberately red) | no gameplay/state/frame-count changes; pure layout |
| GDScript unit suite (12/12 via `run_tests.sh` → sidecar) | `test_health_bar` pins widget geometry (68×20, labels 9px, bar y=12) — backing is a stylebox override, clamp is runtime-positional; both out of the test's static assertions |
| pytest 5/5 | smoke test changes are additive (new test + one list append) |

**Baseline expectations to verify before/after:** 42/43 green, `terminal_victory` red (that's its job), pytest 5/5, `creation_single_ui` 16/16, `ui_geometry_readability` 24/24 + new asserts.

---

## 7. Design Notes for 5_design (declared presentation changes)

These are implementation-level presentation changes within the brief's mandate; no game rules/numbers change. On delivery, `5_design` may update `design/30_presentation.md`'s layout table with:

1. **New battle HUD element: a full-width top strip (0..80px, semi-transparent dark backing, `mouse_filter = IGNORE`)** hosting 回合数 / 行动(行动条面板) / 出手顺序 / 技能提示 / 内力. PauseButton remains top-right on the band; EndTurn/Attack/技能说明 sit below the band on the right.
2. **ActionHintLabel relocated** from bottom-center to the strip (position only — node name/path unchanged).
3. **Floating HP widgets clamp below the strip** (`top ≥ strip_bottom + 2`) — the top-row exception to "floats above the sprite" (no headroom above a viewport-top sprite); the name label gains a semi-transparent backing so it reads on artwork.
4. **Creation screen rhythm:** uniform 44px attr rows, value text right-aligned hugging its `-`/`+` cluster, PointsLabel attached 8px above the block, one shared vertical skeleton for the three phases, fixed-width centered CONFIRM buttons.

---

## 8. Suggested Task Decomposition (for PM)

Each subtask is independently verifiable by the playtest gate or the smoke test:

1. **Battle scene layout** — 3.1 (`hud.tscn` TopStrip + offsets). Verify: game boots, no parse errors, existing battle scenarios stay green.
2. **Battle observables** — 3.2 (`hud.gd` + 3.6 surface additions). Verify: whitelist + f30 assert block green.
3. **HP-bar discipline** — 3.3 (`health_bar.gd`). Verify: `HealthBar.name_backing_alpha > 0.3` assert + unit suite 12/12.
4. **Creation scene layout** — 3.4 (`creation.tscn`). Verify: five creation scenarios green.
5. **Creation observables** — 3.5 (`creation.gd` + 3.6 surface). Verify: whitelist present.
6. **Gate wiring** — 3.7 (extend `ui_geometry_readability.yaml`), 3.8 (new scenario + two-place sync), 3.9 (smoke test). Verify: pytest 5/5 → 6/6, new scenario green, extended scenario green.
7. **Probe & baseline** — re-measure frames before/after (先取值再动手), confirm 42/43 + pytest + unit suite, confirm `terminal_victory` still red for the same reason only. Keep frames in `5_compile/frames/` for the human review: creation ATTRS and creation TRAITS one each + one battle top-bar frame. The delivery notes must NOT claim "geometry asserts green ⇒ layout is good" — green geometry asserts prove non-overlap only; layout quality is judged by the human on those frames.

Dependencies: 6 depends on the observable names from 2/3/5 (they are fixed by this document — the contract in §4); everything else is independent.

## 9. Out of Scope / Not This Round

- No new assets, no art, no audio (the strip is a `StyleBoxFlat`, not a texture).
- No visual-gate changes (six fixed questions unchanged; spatial questions stay playtest-judged).
- No gameplay/numeric changes; `design/10_systems.md` / `20_content.md` untouched.
- No changes to skill-bar layout, tutorial overlay, menu, settings, or any other screen.
- No changes to `run_tests.sh` or the sidecar wiring.
