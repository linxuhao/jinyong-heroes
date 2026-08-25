# Health-Bar Geometry — Probe Notes (observed, not assumed)

**Task:** `health_bar_geometry` — probe the three health-bar surface observables
(`bar_height`, `empty_area_px`, `empty_cap_px`) on the **un-fixed** health bar
(baseline: root 68×20, Bar 64×8 @ (2,12), EmptyCap 6×8 @ (58,0), `EMPTY_CAP_PX`
6.0, track halo expand 4), record the observed pre-fix values with A/B labels,
then apply the geometry/contrast trio and re-probe. Probing runs in the **battle
scene** — the same boot the `playtest/ui_geometry_readability.yaml` gate (and the
5_vision Q5 frame it guards) runs under.

## Probe method

One inline run (`health_bar_probe`, passed as CLI text, never staged — inline
scenarios bypass the `_common.yaml` surface whitelist) booting
`res://scenes/main.tscn` with the same 7× `ui_accept` boot as
`ui_geometry_readability.yaml` (frames 3,5,7,9,11,13,15) and always-false
**contradiction asserts** at f30 (where `HealthBar.name_text == "杨过"` identifies
the player bar node):

```yaml
HealthBar.bar_height: bar_height >= 0 and bar_height < 0
HealthBar.empty_area_px: empty_area_px >= 0 and empty_area_px < 0
HealthBar.empty_cap_px: empty_cap_px >= 0 and empty_cap_px < 0
```

Every assert is a clean always-false bool expression whose only purpose is to
force the harness to print `observed`. The all-red output is the reading
mechanism, not a defect: `hard_passed=true` (harness ran clean — no runtime
errors, no timeout). The same probe was re-run after the geometry edit with the
staged files applied (`staged_files_applied: scenes/ui/health_bar.tscn,
scripts/ui/health_bar.gd`).

## Observed values (battle runtime, f30)

| Surface var | A/B | Pre-fix observed (battle) | Authored (tscn/headless) | Post-fix observed (battle) | Authored (post) |
|---|---|---|---|---|---|
| `bar_height` | pin | **22.0** | 8.0 | **22.0** | 12.0 |
| `empty_area_px` | A-class† | **132.0** | 48.0 | **220.0** | 120.0 |
| `empty_cap_px` | **A** | **6.0** | 6.0 | **10.0** | 10.0 |

Post-fix compatibility pins (same probe): `HealthBar.size` = [68, 24]
(`total_height` 24.0 ≤ 26 ✓), `bar_width` 64.0 (≤ 64 ✓), `fill_color` green
(g > 0.5 and g > r ✓), `track_bg` luminance > 0.30 ✓, hover gap 32 − 24 = 8 ✓.

† `empty_area_px` is A-class on the **authored/headless numbers** (48 < 120, red
pre-fix — that is the defect the design targets) but at **battle runtime it was
already 132 ≥ 120 pre-fix**, so as a battle-gate assert it behaves as a B-class
guard. The runtime A-class proof is `empty_cap_px` (6 < 10, red pre-fix → 10).
See caveats — this matters for the downstream `playtest_gate_wiring` task.

## The one probe finding that overrides the derived numbers

The task plan's pre-fix expectations were `bar_height 8.0 / empty_area_px 48.0 /
empty_cap_px 6.0` — **derived from the tscn**. The probe shows the battle
runtime disagrees on the first two:

- `Bar.size.y` reads **22.0** at runtime both pre-fix (authored 8) and post-fix
  (authored 12). Godot clamps a ProgressBar's `size.y` up to its theme minimum
  (~22 px) when it enters the scene tree; the authored 8/12 only survives in the
  **headless unit-test path** (`tests/test_health_bar.gd` instantiates without
  `add_child`, so it sees the authored geometry — which is why the plan's numbers
  matched that path). The root `HealthBar` Control is not clamped (Control min
  size 0), so `size.y` follows the tscn: 20 → 24.
- Consequence: the runtime bar has always rendered **22 px tall** (≥ the design's
  12 target), and the runtime empty-slot area was already 6×22 = 132 px² pre-fix.
  The changes that actually bite at runtime are the **cap width 6→10** (area
  132 → 220 px²) and the **halo 4→6**. The authored numbers (8→12, 48→120) are
  the contract the tscn and the headless unit-test sync pin; the runtime reads
  are taller already.

## Caveats / run notes

- No gate claims: playtest/pytest/vision are downstream. This file only records
  the probe readings the geometry task was asked to capture.
- `empty_cap_px` is the **only clean A-class runtime red** (6 → 10). Downstream
  wiring should label `bar_height >= 12` / `empty_area_px >= 120` as B-class
  guards **at the battle gate** (both were already green pre-fix at runtime) and
  keep `empty_cap_px >= 10` as the A-class proof there; the authored 8/48 red
  lives on the headless/unit-test path.
- `EmptyCap` stays a constant design element (like a border): never tied to
  `value/max_value`; `ProgressBar.value` still drives the fill truthfully. The
  cap is re-pinned by code to `bar.size.x - EMPTY_CAP_PX` (= 64 − 10 = 54, the
  new tscn position) and `cap.size.y = bar.size.y`, so tscn and runtime agree.
- All-red probe output is by construction; `hard_passed=true` on both runs.
