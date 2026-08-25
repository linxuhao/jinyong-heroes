# Delivery notes — 捏人屏排版返工 + 血条在真实尺寸下能读 (creation re-layout + native-size health bar)

Task: consolidate the round's delivery record and update the docs (README,
design/30_presentation.md, design/99_changelog.md). The round itself was landed by
sibling tasks: `creation_layout` (creation.tscn row-level shrink-center + six
leaf-ink observables + `points_attrs_gap_ok` internals rework), `health_bar_geometry`
(bar 8→12, widget 68×20→68×24, empty cap 6→10, halo 4→6, hover −28→−32,
`bar_height` / `empty_area_px` / `empty_cap_px` observables), `health_bar_unit_tests`
(`tests/test_health_bar.gd` geometry sync), and `playtest_gate_wiring` (in-place
extension of `creation_layout_readability.yaml` + `ui_geometry_readability.yaml`,
append-only `_common.yaml` surface). This task writes the closing record only — no
game code, no scenario files, no tests.

## 1. Round summary

Sibling tasks delivered: creation screen row-level shrink-center (all three phases'
content centered on the x=480 axis), the health-bar geometry trio (bar 8→12, widget
68×20→68×24, empty cap 6→10, halo 4→6, hover −28→−32), the six leaf-ink creation
observables plus the reworked `points_attrs_gap_ok`, the in-place extension of the
two readability scenarios, and the `test_health_bar` geometry sync. This file is the
closing record and only changes docs.

## 2. Pre-fix probe table (预修探针表) — A/B per observable, numbers verbatim from the probe notes

### Creation (7 rows — `final/creation_probe_notes.md`)

| Surface var | A/B | Pre-fix observed |
|---|---|---|
| `attr_cluster_center_ok` | **A** | **false** @f30 (ATTRS) |
| `attr_cluster_width_ok` | **B** | **true** @f30 (regression guard) |
| `nav_cluster_center_ok` | **A** | **false** @f30 / **false** @f90 / true @f150 (CONFIRM already shrink-centered) |
| `trait_cluster_center_ok` | **A** | **false** @f90 (TRAITS) |
| `desc_center_ok` | **A** | **false** @f30 (ATTRS) |
| `desc_alignment_ok` | **A** | **false** @f30 / **false** @f90 (both desc labels left-aligned) |
| `points_attrs_gap_ok` (reworked) | **A** | **false** @f30 (ATTRS ink arm — PointsLabel text 480 vs first-row ink ≈ 684); true @f90/f150 (button-rect arms = the container-rect lie) |

### HealthBar (3 rows — `final/health_bar_probe_notes.md`)

| Surface var | A/B | Pre-fix runtime (battle) | Authored (tscn/headless) |
|---|---|---|---|
| `bar_height` | pin | **22.0** | 8.0 (→ 12.0 post) |
| `empty_area_px` | A-class† | **132.0** | 48.0 (→ 120.0 post) |
| `empty_cap_px` | **A** | **6.0** | 6.0 (→ 10.0 post) |

† `empty_area_px` is A-class on the authored/headless numbers (48 < 120, red
pre-fix — the defect the design targets), but at battle runtime it was already
132 ≥ 120 pre-fix, so as a battle-gate assert it behaves as a **B-class guard**.
The runtime A-class proof is `empty_cap_px` (6 < 10, red pre-fix → 10).

## 3. Key probe finding — Godot clamps ProgressBar height at runtime

`Bar.size.y` reads **22.0** at battle runtime both pre-fix (authored 8) and
post-fix (authored 12): Godot clamps a ProgressBar's `size.y` up to its theme
minimum (~22 px) when it enters the scene tree, so the authored 8→12 / 48→120 only
survive in the **tscn + headless unit-test path** (`tests/test_health_bar.gd`
instantiates without `add_child`). Consequence: at the battle gate `bar_height >= 12`
/ `empty_area_px >= 120` are **B-class guards** (both already green pre-fix at
runtime) and `empty_cap_px >= 10` stays the A-class proof. `EmptyCap` remains a
constant design element (like a border) — never tied to `value/max_value`;
`ProgressBar.value` still drives the fill truthfully.

## 4. Evidence chain (证据链)

- playtest **44 scenarios / 43 green**; `terminal_victory` stays **deliberately red
  at 5/6** (untouched difficulty contract).
- pytest green (including the smoke surface contract); GDScript suite **12/12**.
- vision Q5 passes on **960×704 native frames** (17/26 → all) — the health bar's
  empty slot now reads as filled-and-empty at native size; no zoomed evidence.
- Native-size frames human-verifiable; every A-class observable was red pre-fix per
  the table above and green post-fix.

## 5. Closing note

This task changed **docs only** (README, design/30_presentation.md,
design/99_changelog.md, and this file). The probe notes
(`final/creation_probe_notes.md`, `final/health_bar_probe_notes.md`) and the
scenario/test files are untouched; the previous round's delivery record is preserved
by git history and the sibling `final/delivery_notes_each_unit_acts_once_double_attack.md`.

