# Creation Leaf-Ink Observables — Pre-fix Probe Notes (observed, not assumed)

**Task:** `creation_observables` — probe the six new leaf-ink creation-layout
observables plus the reworked `points_attrs_gap_ok` on the **un-fixed** creation
screen (baseline layout: rows FILL the 560px MouseBox, nav/toggle buttons
FILL-stretched, desc labels left-aligned), and record the observed pre-fix values
with A/B class labels. These readings are the pre-fix baseline the
`creation_layout` task must flip to green and the threshold source for
`playtest_gate_wiring`.

**No scene, playtest yaml, or test files were written by this task.** The only
code change is `scripts/segments/creation.gd` (additive observables + helpers +
`points_attrs_gap_ok` internals rework); the layout itself is untouched.
Probing was done via `godot_playtest_scenario` with `inline_scenario` (YAML
passed as CLI text, never staged, never written to the repo). The only repo file
produced by this task is this notes file.

## Probe method

One inline run (`creation_observables_probe`) booting
`res://scenes/segments/creation.tscn` directly (the proven direct-boot path,
mirroring `playtest/creation_layout_readability.yaml`):

| Frame | Action | Phase | Asserts (all always-false diagnostics) |
|---|---|---|---|
| f30 | — | ATTRS | `attr_cluster_center_ok`, `attr_cluster_width_ok`, `nav_cluster_center_ok`, `desc_center_ok`, `desc_alignment_ok`, `points_attrs_gap_ok` |
| f40 | click `AttrNextButton` | → | (phase-transition latency 20 frames, proven pattern) |
| f90 | — | TRAITS | `nav_cluster_center_ok`, `trait_cluster_center_ok`, `desc_alignment_ok`, `points_attrs_gap_ok` |
| f100 | click `TraitNextButton` | → | |
| f150 | — | CONFIRM | `nav_cluster_center_ok`, `points_attrs_gap_ok` |

Every assert is an **always-false contradiction** (`x and not x` — a clean bool
expression, no type error) whose only purpose is to force the harness to print
the `observed` value. The run reports 0/12 passed, `hard_passed=true` — the red
is the intentional reading mechanism, not a defect. `staged_files_applied:
scripts/segments/creation.gd` (the observables were live; the layout was the
pre-fix baseline).

## Observed values (pre-fix, un-fixed layout)

| Surface var | A/B | f30 ATTRS | f90 TRAITS | f150 CONFIRM | Post-fix target |
|---|---|---|---|---|---|
| `attr_cluster_center_ok` | **A** | **false** | (phase-gated, keeps last) | (kept) | true |
| `attr_cluster_width_ok` | **B** | **true** | (kept) | (kept) | true (guard) |
| `nav_cluster_center_ok` | **A** | **false** | **false** | true* | true |
| `trait_cluster_center_ok` | **A** | (phase-gated) | **false** | (kept) | true |
| `desc_center_ok` | **A** | **false** | (kept) | (kept) | true |
| `desc_alignment_ok` | **A** | **false** | **false** | (kept) | true |
| `points_attrs_gap_ok` (reworked) | **A** | **false** | true† | true† | true |

\* CONFIRM pre-fix is already correct: `ConfirmButton`/`BackButton` carry
shrink-center + fixed width (unchanged by design), so their union is centered and
~180px wide → true even pre-fix.

† TRAITS/CONFIRM `points_attrs_gap_ok` reads **true pre-fix** — expected, not a
probe failure. Those phases' gap clusters are **button rects** (per the signed
design: shrink-centered buttons have no expand-fill slack, so rect == ink
post-fix). Pre-fix the toggles/ConfirmButton are FILL-stretched across the 560px
row, so their rect center equals the container center (480) by construction — the
same container-rect lie. The A-class proof of the rework lives in the ATTRS arm,
which measures **ink**: `points_attrs_gap_ok == false` at f30 (PointsLabel text
center 480 vs first-row ink cluster center ≈ 684).

## Derived vs observed

| Fact | Derived (geometric estimate) | Observed | Match |
|---|---|---|---|
| `attr_cluster_center_ok` | false (cluster center ≈ 684) | **false** @f30 | ✓ |
| `attr_cluster_width_ok` | true (≈152 ≤ 340) | **true** @f30 | ✓ |
| `nav_cluster_center_ok` | ATTRS/TRAITS false (union width 560 > 240); CONFIRM true | **false** @f30, **false** @f90, **true** @f150 | ✓ |
| `trait_cluster_center_ok` | false (width 560 > 340) | **false** @f90 | ✓ |
| `desc_center_ok` | false (text center ≈ 260) | **false** @f30 | ✓ |
| `desc_alignment_ok` | false (both labels alignment 0) | **false** @f30, **false** @f90 | ✓ |
| `points_attrs_gap_ok` (reworked) | false (684 vs 480, ATTRS arm) | **false** @f30; true @f90/f150 (button-rect arms, see above) | ✓ |

All A-class facts are **observed false** at their own phase pre-fix; the B-class
guard (`attr_cluster_width_ok`) is **observed true** pre-fix (it is a
regression guard, not a defect proof — the SOTA A/B discipline: B-class facts
must never be cited as defect evidence).

## Caveats / run notes

- Probe output is all-red by construction; `hard_passed=true` (harness ran
  clean — no runtime errors, no timeout, last sample f150 ≤ 2999).
- The contradiction diagnostics print the var's actual value as `observed`;
  frame numbers are run-specific but phase-transition latency (20 frames) is the
  proven pattern from `creation_traits_back_next_buttons`.
- `desc_alignment_ok` is computed every phase (not phase-gated): f90 re-reads
  false because both desc labels are still left-aligned on the un-fixed layout.
- The reworked `points_attrs_gap_ok` yaml assert lines are unchanged — only the
  measured quantities differ, so the existing f30/f90 asserts
  (`== true`) keep their meaning: green once the layout fix lands (ATTRS ink
  cluster center 684 → 480).
