# Technical Architecture Design — 捏人屏排版返工 (row-level shrink-center) + 血条真实尺寸可读 (health bar at native 960×704)

Round goal (from `step1_sota.md`, baseline HEAD 21851a1): playtest 44 scenarios / 43 green
(`terminal_victory` stays deliberately red); vision gate Q5 is red at 17/26 — floating health
bars read as "solid green rectangles" at the native 960×704 size. Two defect classes, one
shared fix idiom:

1. **Creation screen re-layout (second pass).** The previous round fixed row-internal rhythm
   (right-aligned value label hugging its `-`/`+` cluster — that half is correct and stays),
   but the *whole-screen* layer is still broken: `AttrRow*` fills the full 560 px `MouseBox`,
   so the cluster is flung to the right edge (ink ≈ x 608..760) while nav buttons sit far left.
   The existing `points_attrs_gap_ok` stayed green through all of it because it compared
   *container* rects (both nominally centered at 480) — see `design/99_changelog.md` last row
   (容器矩形 ≠ 墨迹). Fix: **row-level `SHRINK_CENTER`** so each row shrinks to its ink and
   centers on the 480 axis; observables must measure **leaf ink** (label *text* rects via
   `Font.get_string_size`, button rects), never container rects.
2. **Health bar at real size.** Current: 64×8 bar, 6×8 px empty cap = 48 px², 4 px expand
   halo → invisible at native size; the "empty slot" is an *area* problem, not an existence
   problem. Fix: bar height 8→12, `EMPTY_CAP_PX` 6→10 (cap area 120 px², ×2.5), expand halo
   4→6, hover offset −28→−32 (keeps the 8 px hover gap). Same node types (`ProgressBar` +
   `EmptyCap` `ColorRect` + `StyleBoxFlat`), no art, no renames.

Both halves follow the repository's established idiom (previous round `jinyong-layout`):
property-only `.tscn` edits + additive per-frame geometry observables + append-only playtest
surface + in-place yaml extensions. **No new scene files, no node renames, no gameplay
changes.**

---

## 1. Architecture Diagram (text)

```
CREATION SCREEN (scenes/segments/creation.tscn, viewport 960×704)
  CreationScreen (full-viewport Control)
  └── MouseBox (VBoxContainer, 560 px wide, centered at x=480 — UNCHANGED)
      ├── AttrBox (VBox, fills 560 — UNCHANGED)
      │   ├── AttrRow0..4  [size_flags_horizontal = 4  NEW: shrink-center]
      │   │     ├── AttrLabel    alignment=2 + expand-fill=3  (UNCHANGED pair)
      │   │     │                custom_minimum_size.x: 180 -> 0   (NEW: hugs its text)
      │   │     └── AttrMinus{i} / AttrPlus{i}  44×34 (UNCHANGED)
      │   ├── AttrDescLabel   horizontal_alignment = 1  (NEW: center)
      │   └── AttrNavRow      size_flags_horizontal = 4  (NEW: shrink-center)
      │         └── AttrBackButton / AttrNextButton (UNCHANGED nodes)
      ├── TraitBox (VBox, fills 560)
      │   ├── TraitToggle0..12   size_flags_horizontal = 4  (NEW: shrink-center, each toggle)
      │   ├── TraitDescLabel     horizontal_alignment = 1  (NEW)
      │   └── TraitNavRow        size_flags_horizontal = 4  (NEW)
      └── ConfirmBox  (ConfirmButton/BackButton already shrink-center — UNCHANGED)
  -> every visible leaf's ink center lands on the x=480 axis in all three phases.

creation.gd _update_geometry_observables() (every _process frame, additive):
  _label_text_rect(l)  = Font.get_string_size(text) -> text sub-rect inside label rect,
                         honoring the label's horizontal_alignment (RIGHT/CENTER/LEFT)
  _row_ink_union(i)    = label text rect ∪ AttrMinus{i} rect ∪ AttrPlus{i} rect
  NEW observables: attr_cluster_center_ok / attr_cluster_width_ok /
                   nav_cluster_center_ok / trait_cluster_center_ok /
                   desc_center_ok / desc_alignment_ok
  points_attrs_gap_ok  = SAME name, internal rework: PointsLabel TEXT rect vs the
                         current phase's FIRST-ROW cluster (ink, not container rect)

HEALTH BAR (scenes/ui/health_bar.tscn + scripts/ui/health_bar.gd)
  HealthBar root 68×20 -> 68×24      (total_height 24 <= 26, pinned cap OK)
  ├── NameLabel 64×9 @ (2,0)         (UNCHANGED)
  └── Bar (ProgressBar) 64×8 -> 64×12 @ (2,12)
      └── EmptyCap (ColorRect) 6×8 -> 10×12 @ (54,0)   (pinned to right end in code)
  health_bar.gd constants: EMPTY_CAP_PX 6 -> 10, expand_margin_all 4 -> 6,
                           hover offset (-34,-28) -> (-34,-32)   [32 - 24 = 8 px hover]
  NEW observables: bar_height (= Bar.size.y), empty_area_px (= cap × bar height = 120)

GATES (append-only / in-place):
  playtest/_common.yaml        surface += HealthBar.{bar_height, empty_area_px, empty_cap_px}
                                        + CreationScreen.{attr_cluster_center_ok,
                                        attr_cluster_width_ok, nav_cluster_center_ok,
                                        trait_cluster_center_ok, desc_center_ok,
                                        desc_alignment_ok}
  ui_geometry_readability.yaml  IN-PLACE append to the f30 assert block
  creation_layout_readability.yaml  IN-PLACE append to f30 / f90 / f150 assert blocks
  tests/test_playtest_contract_smoke.py  ONE NEW additive test function
  tests/test_health_bar.gd      geometry sync (68×24 / 12 px / expand 6 / cap 10)
  No new scenario files -> scenario_order and ROUND_SCENARIOS UNCHANGED
```

---

## 2. Component List

### 3.1 `scenes/segments/creation.tscn` — row-level shrink-center (property-only)

**Responsibility:** make each row / leaf shrink to its own ink and center on the x=480 axis,
in all three phases, while the row-internal rhythm fixed last round (label hugging `-`/`+`)
stays byte-identical.

**Changes (all properties — zero renames, zero reparents, zero node additions):**

| Node | Property | Old | New |
|---|---|---|---|
| `AttrRow0..4` | `size_flags_horizontal` | *(absent = FILL)* | `4` (SHRINK_CENTER) |
| `AttrRow0..4/AttrLabel` | `custom_minimum_size` | `Vector2(180, 0)` | `Vector2(0, 0)` |
| `AttrRow0..4/AttrLabel` | `horizontal_alignment` / `size_flags_horizontal` | `2` / `3` | **unchanged** (pinned by `attr_label_alignment_ok`) |
| `AttrNavRow`, `TraitNavRow` | `size_flags_horizontal` | *(absent)* | `4` |
| `TraitToggle0..12` | `size_flags_horizontal` | *(absent)* | `4` |
| `AttrDescLabel`, `TraitDescLabel` | `horizontal_alignment` | *(absent = LEFT)* | `1` (CENTER) |

**Resulting geometry (derived; implementer re-measures):** each attr row min-width =
text width ("根骨 10" ≈ 52 px) + 6 + 44 + 6 + 44 ≈ 152 px → row centered at 480 → the row
*is* the ink (label rect == text rect, no slack) → cluster center = 480, width ≈ 152 ≤ 340.
All five rows have identical text shape (`2 CJK + space + 2 digits`, values 10..20) → rows
share left/right edges → `attr_rows_uniform` stays green. Nav pair ≈ 180 px centered;
CONFIRM pair already centered. Box tops unchanged → `phase_skeleton_same` /
`creation_box_fits` / `creation_in_viewport` unaffected.

**Why not the SOTA's alternative ("fixed-width ~280 column"):** a fixed-width column keeps
the ink right-heavy inside the column and forces observables to assert on the *column frame*
instead of the ink — the exact container-rect lie this round is reworking. Row-level
shrink-center makes ink and frame coincide, so ink-based assertions stay simple and true.

### 3.2 `scripts/segments/creation.gd` — leaf-ink observables + `points_attrs_gap_ok` rework

**Responsibility:** compute per-frame, decidable creation-layout facts measured on *ink*
(leaf text rects and button rects), in the existing `_update_geometry_observables()` shape.
Additive: the existing six observables' code is untouched except `points_attrs_gap_ok`'s
internal implementation (its *assert lines* in yaml stay untouched).

**New helper (private):**

```gdscript
## Text sub-rect of a Label inside its global rect, honoring horizontal_alignment.
func _label_text_rect(l: Label) -> Rect2:
    var f: Font = l.get_theme_font("font")
    var fs: int = l.get_theme_font_size("font_size")
    var sz: Vector2 = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
    var lr: Rect2 = l.get_global_rect()
    match int(l.horizontal_alignment):
        HORIZONTAL_ALIGNMENT_RIGHT:   # 2
            return Rect2(lr.end.x - sz.x, lr.position.y + (lr.size.y - sz.y) * 0.5, sz.x, sz.y)
        HORIZONTAL_ALIGNMENT_CENTER:  # 1
            return Rect2(lr.position.x + (lr.size.x - sz.x) * 0.5, lr.position.y + (lr.size.y - sz.y) * 0.5, sz.x, sz.y)
        _:                            # 0 (LEFT)
            return Rect2(lr.position, sz)

## Ink union of attr row i: label text rect + minus rect + plus rect.
func _row_ink_union(i: int) -> Rect2: ...
#   label = MouseBox/AttrBox/AttrRow{i}/AttrLabel  (text rect via _label_text_rect)
#   minus = MouseBox/AttrBox/AttrRow{i}/AttrMinus{i}, plus = .../AttrPlus{i}
#   return text.merge(minus.get_global_rect()).merge(plus.get_global_rect())
```

**New surface vars (declared `var`, so the playtest Expression sees them):**

```gdscript
var attr_cluster_center_ok: bool = true   # ATTRS only (keeps last value otherwise)
var attr_cluster_width_ok: bool = true    # ATTRS only (B-class guard)
var nav_cluster_center_ok: bool = true    # current phase's nav pair (all three phases)
var trait_cluster_center_ok: bool = true  # TRAITS only (keeps last value otherwise)
var desc_center_ok: bool = true           # ATTRS only (keeps last value otherwise)
var desc_alignment_ok: bool = true        # always: both desc labels alignment == 1
```

Computation (inside `_update_geometry_observables`, after the existing six; viewport center
`var vcx: float = get_viewport().get_visible_rect().size.x * 0.5`):

1. **`attr_cluster_center_ok` (ATTRS):** for each `i` in 0..4, `u = _row_ink_union(i)`;
   all five satisfy `absf(u.get_center().x - vcx) <= 6.0`. Any missing/invisible node → false.
   *(Pre-fix ≈ 684 → red; post-fix 480 → green. A-class.)*
2. **`attr_cluster_width_ok` (ATTRS):** each `u.size.x <= 340.0`.
   *(Pre-fix 152 ≤ 340 → true; B-class guard against cluster re-expansion.)*
3. **`nav_cluster_center_ok` (always, per phase):** pair =
   ATTRS `AttrBackButton ∪ AttrNextButton`, TRAITS `TraitBackButton ∪ TraitNextButton`,
   CONFIRM `ConfirmButton ∪ BackButton` (button **rects**); `u = a.merge(b)`;
   `absf(u.get_center().x - vcx) <= 6.0 and u.size.x <= 240.0`.
   *(Pre-fix ATTRS/TRAITS: two FILL-stretched buttons span 200..760 → width 560 → false.
   CONFIRM was already correct → true. The width conjunct is what makes this robustly red
   pre-fix regardless of which pre-fix nav geometry the probe records.)*
4. **`trait_cluster_center_ok` (TRAITS):** union of all visible `TraitToggle*` rects;
   center ±6 of vcx AND width ≤ 340.
   *(Pre-fix: toggles fill 560 → false on width. Post-fix: widest toggle ≈ 120 centered → true.)*
5. **`desc_center_ok` (ATTRS):** `AttrDescLabel` text rect via `_label_text_rect`;
   `absf(text_rect.get_center().x - vcx) <= 6.0`. ATTRS desc texts are short single-line
   formulas → `get_string_size` is exact. (Wrapped TRAITS descriptions are deliberately
   NOT measured here — covered by the property pin below.)
   *(Pre-fix: left-aligned at 200 → center ≈ 260 → red; post-fix 480.)*
6. **`desc_alignment_ok` (always):** both `AttrDescLabel` and `TraitDescLabel` have
   `int(horizontal_alignment) == 1`.
   *(Pre-fix: both 0 → false. A-class property pin of the fix.)*

**`points_attrs_gap_ok` semantic rework (same var, same name, yaml asserts unchanged):**

```gdscript
# OLD (the never-red defect): compared PointsLabel.get_global_rect() center vs the
# phase BOX rect center — both are container rects centered at 480 by construction.
# NEW: measure PointsLabel's TEXT rect vs the current phase's FIRST-ROW cluster (ink).
if points_label != null:
    var cluster: Rect2
    match phase:
        "ATTRS":   cluster = _row_ink_union(0)
        "TRAITS":  cluster = (get_node_or_null("MouseBox/TraitBox/TraitToggle0") as Button).get_global_rect()
        "CONFIRM": cluster = (get_node_or_null("MouseBox/ConfirmBox/ConfirmButton") as Button).get_global_rect()
        _:         cluster = Rect2()
    if cluster.size != Vector2.ZERO:
        var p_rect: Rect2 = _label_text_rect(points_label)   # PointsLabel alignment == 1
        var gap: float = cluster.position.y - p_rect.end.y
        points_attrs_gap_ok = gap >= 4.0 and gap <= 24.0 \
                and absf(cluster.get_center().x - p_rect.get_center().x) <= 4.0
```

Post-fix all three phases give center 480 vs 480 and gap ≈ 8..13 px → `== true` holds at
f30 / f90 as asserted today. Pre-fix ATTRS gives cluster ≈ 684 vs 480 → false (the
reproducible red the old implementation could never produce).

### 3.3 `scenes/ui/health_bar.tscn` + `scripts/ui/health_bar.gd` — size + contrast trio

**Responsibility:** make the filled/empty split readable on a 960×704 native frame. Same
nodes, same types, same paths; only geometry and contrast.

**tscn edits:**

```
[node name="HealthBar"]   size = Vector2(68, 20) -> Vector2(68, 24)
[node name="Bar"]         position (2,12) UNCHANGED; size Vector2(64, 8) -> Vector2(64, 12)
[node name="EmptyCap"]    position Vector2(58, 0) -> Vector2(54, 0); size Vector2(6, 8) -> Vector2(10, 12)
[node name="NameLabel"]   UNCHANGED (2,0 / 64×9 / font 10 / clip_text false)
```

Label 9 + bar 12 = 21 ≤ 24 → no overlap (unit test asserts this sum).

**gd edits (constants + hover + observables + stale comments):**

| Line / item | Old | New |
|---|---|---|
| `EMPTY_CAP_PX` | `6.0` | `10.0` (cap area 10×12 = **120 px²**, ×2.5 vs 48) |
| `sb.set_expand_margin_all(...)` | `4.0` | `6.0` (track halo more visible) |
| hover offset in `follow_character()` | `Vector2(-34, -28)` | `Vector2(-34, -32)` (32 − 24 = 8 px hover, same gap as before) |
| stale comment "bar.size stays 64x6" | — | 64x12 |
| stale comment "STRIP_BOTTOM + 2 (= 82)" / "TopStrip offsets 0..80" | — | `(= 94)` / `0..92` (constant itself is correct at 92.0 — comment only) |
| `_TRACK_BG` / borders / fill bands / `STRIP_BOTTOM` / clamp | unchanged | unchanged (all existing playtest pins stay green) |

**New observables (declared vars, written in `setup()` and refreshed in `follow_character()`):**

```gdscript
## Bar height in px (= Bar.size.y). 12.0 after this round.
var bar_height: float = 0.0
## Visible empty-slot area at the right end (EMPTY_CAP_PX × bar height).
## The area argument behind Q5: 48 px² was invisible at native size; >= 120 px² is not.
var empty_area_px: float = 0.0
```

- `setup()`: inside the existing bar guard — `bar_height = bar.size.y`,
  `empty_area_px = EMPTY_CAP_PX * bar_height`.
- `follow_character()`: alongside the existing `bar_width` refresh —
  `bar_height = _bar.size.y; empty_area_px = EMPTY_CAP_PX * bar_height`.
- `empty_cap_px` already exists on the surface-var list; no change to its semantics
  (constant design element — fill remains value-driven, cap never fakes HP).

**Compatibility with existing pins (verified against current asserts):**
`bar_width <= 64` (64 ✓), `total_height <= 26` (24 ✓), `track_bg luminance > 0.30` (✓),
`fill_color.g > 0.5 and g > r` (✓), `follow_delta <= 24` (player bar mid-board, clamp not
engaged, pre-clamp computation unchanged ✓), `top >= STRIP_BOTTOM + 2 = 94` (clamp
unchanged ✓), `hint_hpbar_overlap == false` (hint sits in the 0..92 strip, bars clamped
below ✓), `hpbar_strip_overlap == false` (✓).

**Hover height is the one coupling to remember:** widget height grows 20→24, so the −28
offset *must* move to −32 or the bar bottom sits 4 px off the character's feet.

### 3.4 `tests/test_health_bar.gd` — geometry sync (keep the suite green)

The unit test pins the old geometry; sync it (this is "keep existing suites green", not
gate-wiring — explicitly allowed by the SOTA):

- `bar.size == Vector2(68, 20)` → `Vector2(68, 24)`
- `bar.total_height == 20.0` → `24.0`
- `background expand_margin_all == 4.0` → `6.0`
- **Add:** `bar.bar_height == 12.0`, `bar.empty_area_px == 120.0`
  (is_equal_approx), `EmptyCap.size.y == bar.bar_height`
- Comment block "68x20 widget, 64x8 bar" → "68x24 widget, 64x12 bar"
- Everything else (cap right-alignment, cap visible at full HP, track ≠ fill, band colors,
  label clip behavior) is geometry-independent and stays green as-is.

### 3.5 `playtest/_common.yaml` — surface append (append-only)

```
  HealthBar:                      # append to the EXISTING block
  - bar_height
  - empty_area_px
  - empty_cap_px
  CreationScreen:                 # append to the EXISTING block
  - attr_cluster_center_ok
  - attr_cluster_width_ok
  - nav_cluster_center_ok
  - trait_cluster_center_ok
  - desc_center_ok
  - desc_alignment_ok
```

`scenario_order` untouched (no new scenario files).

### 3.6 `playtest/ui_geometry_readability.yaml` — IN-PLACE append

Append to the existing f30 assert block (after the current `HealthBar.*` lines; every
existing line stays byte-identical):

```yaml
    HealthBar.bar_height: bar_height >= 12
    HealthBar.empty_cap_px: empty_cap_px >= 10
    HealthBar.empty_area_px: empty_area_px >= 120
```

All three are red pre-fix (8 / 6 / 48) and green post-fix (12 / 10 / 120) — they pin the
fix itself. Every value contains a comparison operator (hard rule). The existing
`total_height <= 26` / `bar_width <= 64` / `top >= 94` family remains the B-guard envelope.

### 3.7 `playtest/creation_layout_readability.yaml` — IN-PLACE append

Append to the existing assert blocks (existing lines byte-identical):

```yaml
# f30 block (ATTRS), after the existing six asserts:
    CreationScreen.attr_cluster_center_ok: attr_cluster_center_ok == true
    CreationScreen.attr_cluster_width_ok: attr_cluster_width_ok == true
    CreationScreen.nav_cluster_center_ok: nav_cluster_center_ok == true
    CreationScreen.desc_center_ok: desc_center_ok == true
    CreationScreen.desc_alignment_ok: desc_alignment_ok == true
# f90 block (TRAITS):
    CreationScreen.nav_cluster_center_ok: nav_cluster_center_ok == true
    CreationScreen.trait_cluster_center_ok: trait_cluster_center_ok == true
    CreationScreen.desc_alignment_ok: desc_alignment_ok == true
# f150 block (CONFIRM):
    CreationScreen.nav_cluster_center_ok: nav_cluster_center_ok == true
```

### 3.8 `tests/test_playtest_contract_smoke.py` — ONE additive test function

New function (existing functions untouched; `ROUND_SCENARIOS` untouched):

```python
def test_creation_rework_and_bar_surface_contract() -> None:
    text = COMMON.read_text(encoding="utf-8")
    blocks = _surface_blocks(text)
    health_items = blocks.get("HealthBar", [])
    for var in ("bar_height", "empty_area_px", "empty_cap_px"):
        assert var in health_items, "HealthBar.%s not whitelisted on the surface" % (var,)
    creation_items = blocks.get("CreationScreen", [])
    for var in ("attr_cluster_center_ok", "attr_cluster_width_ok",
                "nav_cluster_center_ok", "trait_cluster_center_ok",
                "desc_center_ok", "desc_alignment_ok"):
        assert var in creation_items, "CreationScreen.%s not whitelisted on the surface" % (var,)
```

### 3.9 Documentation

- `README.md`: update the health-bar line (64 px wide, **12 px tall**, fixed 10 px empty
  cap, 6 px track halo) and the creation-layout observables paragraph (add the six new vars).
- `design/30_presentation.md`: amend the 血条 section (see §5 Design Changes — the old
  "高 ≤ 8 / 整体 ≤ 20" conclusion is superseded by native-size evidence) and add one row to
  the 顶栏/捏人屏 layout description (rows shrink-centered on the 480 axis).
- `design/99_changelog.md`: one new row for this round.
- `final/delivery_notes.md`: pre-fix probe table (A/B class per observable) + evidence
  chain summary.

---

## 3. Observable Contract (interface spec — implementers match names exactly, PM fills thresholds)

| Node.var | Type | Formula (per frame) | A/B | Pre-fix (derived) | Post-fix |
|---|---|---|---|---|---|
| `CreationScreen.attr_cluster_center_ok` | bool | 5× `_row_ink_union(i)` centers all within ±6 px of vcx=480 | **A** | ≈ 684 → false | 480 → true |
| `CreationScreen.attr_cluster_width_ok` | bool | each row ink union width ≤ 340 px | B | true (152) | true (152) |
| `CreationScreen.nav_cluster_center_ok` | bool | phase nav pair union: center ±6 of 480 AND width ≤ 240 | **A** | ATTRS/TRAITS false (width 560) | true (~180) |
| `CreationScreen.trait_cluster_center_ok` | bool | visible toggles union: center ±6 of 480 AND width ≤ 340 | **A** | false (width 560) | true (~120) |
| `CreationScreen.desc_center_ok` | bool | AttrDescLabel text rect center ±6 of 480 (ATTRS only) | **A** | ≈ 260 → false | true |
| `CreationScreen.desc_alignment_ok` | bool | both desc labels `horizontal_alignment == 1` | **A** | false (both 0) | true |
| `CreationScreen.points_attrs_gap_ok` | bool | (reworked internals) PointsLabel text rect vs phase first-row cluster: gap ∈ [4,24] ∧ center Δ ≤ 4 | **A** (rework) | false (684 vs 480) | true (480 vs 480) |
| `CreationScreen.attr_rows_uniform` … `creation_box_fits` | — | existing six: **byte-identical code** | B (keep green) | — | green |
| `HealthBar.bar_height` | float | `Bar.size.y` | pin | 8 | 12 |
| `HealthBar.empty_cap_px` | float | `EMPTY_CAP_PX` | pin | 6 | 10 |
| `HealthBar.empty_area_px` | float | `EMPTY_CAP_PX × bar_height` | **A** | 48 → red | 120 → green |
| `HealthBar.total_height` / `bar_width` / `track_bg` / `fill_color` / `follow_delta` / `name_backing_alpha` | — | existing: unchanged semantics | B (keep green) | green | green |

Assert thresholds above are the architect's spec; PM confirms them against probed values.

---

## 4. Edge Cases (from `step1_sota.md`) → how this design handles them

- **E1 Label rects lie (expand-fill) → must measure text rects.** `_label_text_rect` via
  `Font.get_string_size`, honoring alignment; `attr_cluster_center_ok` / `desc_center_ok` /
  reworked `points_attrs_gap_ok` all use it. The A-class pre-fix red (cluster ≈ 684) is
  reproducible on the old layout precisely because the 180-min label's *rect* would still
  center at 480 while its *text* sits at 608..660.
- **E2 Hidden VBox children don't occupy space.** No observable sums widths across boxes;
  every union is built from the *visible* phase's leaves only (existing `visible` gating
  convention kept).
- **E3 Two layers, fixed separately.** Row-internal hug = `horizontal_alignment=2` +
  `expand=3` (unchanged, pinned by `attr_label_alignment_ok`); whole-screen centering =
  row `SHRINK_CENTER` (new, pinned by the cluster observables). Changing only one layer
  would recur the other.
- **E4 Empty slot is an area problem.** Three levers together: height 8→12, cap 6→10
  (48→120 px²), halo 4→6. Geometry/contrast only — no art, no node-type change
  (`ProgressBar` + `EmptyCap` + `StyleBoxFlat` all preserved).
- **E5 Existing pins.** Enumerated in 3.3: 64 ≤ 64, 24 ≤ 26, luminance/colors/follow_delta/
  strip clamp all untouched; the only coupling is the hover offset −28→−32.
- **E6 Full HP is the hardest sample.** The cap is a *constant* design element (like a
  border), never driven by `value/max_value`; fill stays value-driven — no faked HP.
  Acceptance is on 960×704 native frames, never zoomed evidence.
- **E7 A/B classification discipline.** Table in §3; implementer must run the probe on
  the un-fixed code (observables added first, layout changed second) and record measured
  pre-fix values in `final/delivery_notes.md` with A/B labels. Derived values in this doc
  are marked as such.
- **E8 Node name/path freeze.** All edits are property-level; zero renames/reparents;
  observables append-only on the `_common.yaml` surface.
- **E9 `points_attrs_gap_ok` semantic fix without touching assert lines.** Same var name,
  same `== true` assert lines; only the measured quantities change. New layout must keep it
  true (480 vs 480) — verified above.
- **E10 VBox hidden-child skipping vs fixed-width fallback.** We do NOT give the three
  boxes fixed widths (the SOTA alternative): it would make ink right-heavy inside the
  column and resurrect container-rect assertions. Row-level shrink-center keeps ink == frame.
- **E11 Every new assert value contains an operator.** All new yaml values are
  `== true` / `>= N` chains — never bare scalars (the harness hard rule from
  `design/30_presentation.md`).

---

## 5. Design Changes (declared for `5_design`)

1. **`design/30_presentation.md` "血条:必须做小" conclusion is amended.**
   - Was: 细条高 ≤ 8, 整体高度 ≤ 20, expand margin 3 (later 4), cap 6 px.
   - Now: 条高 **12**, 部件 68×**24**, 空尾 **10** px, 光环 **6** px, hover offset −32
     (unchanged 8 px gap). Reason: the old numbers were derived at comparison scale; at the
     native 960×704 the 48 px² cap + 8 px bar reads as solid green (Q5 17/26). The playtest
     envelope (`total_height <= 26`) already permitted the change — only the doc numbers move.
     The historical conclusion stays as history with an amendment block after it.
2. **`design/30_presentation.md` creation-screen layout row** gains: rows shrink-centered on
   the x=480 axis (label min-width hugs text, nav/toggle rows `SHRINK_CENTER`, desc labels
   center-aligned).
3. `design/99_changelog.md` gets one row (this round, with the 容器矩形→墨迹 lesson as the
   reason line).

---

## 6. Safety, Baseline Protection, Rollback

- **No irreversible operations.** No schema/data migration, no deletions, no rewrite of
  user data. Every change is (a) a `.tscn` property edit, (b) additive script vars + one
  private helper, (c) append-only playtest/test edits, (d) test-geometry sync. Rollback =
  `git revert` per component; components are independent (3.1/3.2 creation-side,
  3.3/3.4 bar-side, 3.5–3.8 gate-side).
- **Probe-first workflow (mandatory order):** (1) add observables to `creation.gd` /
  `health_bar.gd` (additive, no behavior change) → (2) probe pre-fix values by booting
  `res://scenes/segments/creation.tscn` / the battle scene via the playtest harness and
  recording the new vars → (3) record values + A/B labels in delivery notes → (4) apply the
  layout/geometry edits → (5) re-probe (must be green) → (6) only then pin asserts.
- **Baseline protection:** 43/44 scenarios must stay green (`terminal_victory` remains the
  single deliberate red). Audited risks: the five creation scenarios assert phase/points/
  attrs/wiring/visible/text — no pixel offsets, and `clicks:` targets aim at live node rect
  centers, so moved buttons still receive the clicks; `ui_geometry_readability` HealthBar
  asserts are all compatible with 68×24 (see 3.3); `spine_to_ending` untouched (no state
  changes anywhere); unit suite stays 12 tests green after the sync in 3.4.

---

## 7. Suggested Task Decomposition (for PM)

1. **T1 — creation observables + `points_attrs_gap_ok` rework** (`scripts/segments/creation.gd`): new vars + `_label_text_rect` / `_row_ink_union` helpers + reworked gap computation. Verify: compiles; probe pre-fix values recorded (A/B labels).
2. **T2 — creation layout** (`scenes/segments/creation.tscn`): the property table in 3.1. Verify: re-probe all creation observables green; `creation_layout_readability` (existing asserts) still green.
3. **T3 — creation gate wiring**: 3.5 surface append + 3.7 yaml in-place appends + 3.8 smoke-test function. Verify: pytest green; scenario green with new asserts.
4. **T4 — health-bar geometry trio** (`scenes/ui/health_bar.tscn` + `scripts/ui/health_bar.gd`): tscn sizes, `EMPTY_CAP_PX`/halo/hover constants, new observables, stale comments. Probe `bar_height`/`empty_area_px` pre-fix first (add vars before changing constants).
5. **T5 — unit-test sync** (`tests/test_health_bar.gd`, 3.4). Verify: GDScript suite 12/12.
6. **T6 — health-bar gate wiring**: 3.5 HealthBar surface append + 3.6 yaml in-place appends. Verify: `ui_geometry_readability` green (old + new asserts).
7. **T7 — docs + delivery notes** (3.9): README, `30_presentation.md` amendment, changelog row, probe table.

T1 must precede T2 (probe needs the observables on un-fixed layout); T4's var additions must precede its constant changes for the same reason.

---

## 8. Out of Scope / Not This Round

No new assets, no `TextureProgressBar`, no `_draw()` bar, no new scenes, no vision-gate
question changes, no gameplay/state/number changes, no node renames or reparents, no
keyboard/text-list resurrection, no touching `terminal_victory` (stays deliberately red).

## 9. Acceptance Evidence Chain

playtest 44 scenarios → 43 green + `terminal_victory` unchanged-red; pytest green (with the
new smoke function); GDScript unit suite 12/12; vision Q5 passes on 960×704 native frames
(17/26 → all); pre-fix probe table in delivery notes proves every A-class observable was
red before the fix; creation screen and health bar native-size frames human-verifiable.
