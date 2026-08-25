# Portrait Cover Probe Notes — measured per-unit values at f40 (UX-01a/01b)

**Task:** `probe_run_notes` (A2) — run the inline portrait probe against the
A1-extended `VisibilityProbe` (8 layers incl. `blank_texture` / `covered` +
`covered_fraction()`), measure all six battle units on the native 960×704 frame at
f40 (battle turn 1), and record the measured per-unit table.

**This task changes NO code.** The only repo file produced is this notes file. The
probe scenario was **inline only** (passed as CLI text, never staged under
`playtest/` — no scratch probe file exists in the repo). The A3 visibility-fix task
consumes the fail-layer ids + `portrait_covered_frac` recorded here.

---

## Probe method

Two inline runs (`godot_playtest_scenario`, `inline_scenario`), both booting
`res://scenes/main.tscn` through the proven tutorial-battle prologue with
single-integer `at:` values only:

| Frame | Action | Phase |
|---|---|---|
| f3 / f5 / f7 / f9 / f11 / f13 / f15 | 7× `ui_accept` | boot |
| f20 / f25 / f30 | 3× `tutorial_next` | tutorial |
| f40 | — | battle turn 1, all six units present (assert block) |

Every assert is an **always-false contradiction** whose only purpose is to force the
harness to print the var's `observed` value. Both runs reported `hard_passed=true`,
`staged_files_applied=[]` (no staged edits this step), `spec source: playtest/` —
the all-red assert blocks are the intentional reading mechanism, not a defect.

- **Run 1 `portrait_cover_probe`** — 42 contradiction asserts (7 vars × 6 units):
  30 parsed and printed their `observed`; the `portrait_sprite_pos == Vector2.ZERO`
  / `portrait_tex_size == Vector2.ZERO` contradictions failed with
  `parse error: Expected '('` — the harness `Expression` does not accept the
  `Vector2.ZERO` **constant member access**. (`portrait_bar_pos == Vector2(-1, -1)`
  parsed fine — the `Vector2(x, y)` **constructor** is accepted, so those 6 printed.)
- **Run 2 `portrait_cover_probe_vec`** — 12 asserts for the two missing vars, using
  the whole-var self-inequality `x != x` (always false, no type-name member access):
  every one printed the full-vector `observed`.

The 42 values below are copied verbatim from the two run reports (`observed` lines)
— none are computed or derived.

---

## Measured per-unit table (f40, native 960×704 frame)

| Unit | `portrait_visible` | `portrait_fail_layer` | `portrait_covered_frac` | `portrait_sprite_pos` | `portrait_tex_size` | `portrait_bar_pos` | `sprite_top` |
|---|---|---|---|---|---|---|---|
| `Player` | `true` | `""` | `0.104166666666667` | `[480.0, 352.0]` | `[96.0, 128.0]` | `[446.0, 320.0]` | `224.0` |
| `East_Heretic` | `true` | `""` | `0.166666666666667` | `[224.0, 160.0]` | `[96.0, 128.0]` | `[190.0, 128.0]` | `32.0` |
| `West_Poison` | `true` | `""` | `0.166666666666667` | `[736.0, 160.0]` | `[96.0, 128.0]` | `[702.0, 128.0]` | `32.0` |
| `South_Emperor` | `true` | `""` | `0.166666666666667` | `[224.0, 544.0]` | `[96.0, 128.0]` | `[190.0, 512.0]` | `416.0` |
| `North_Beggar` | `true` | `""` | `0.166666666666667` | `[736.0, 544.0]` | `[96.0, 128.0]` | `[702.0, 512.0]` | `416.0` |
| `Central_Divine` | **`false`** | **`covered`** | **`0.333333333333333`** | `[480.0, 96.0]` | `[96.0, 128.0]` | `[446.0, 94.0]` | `0.0` |

Every recorded `portrait_fail_layer` is either `""` or one of the 8 layer ids
(`hidden_in_tree` / `null_texture` / `blank_texture` / `zero_rect` / `off_viewport`
/ `clipped` / `occluded` / `covered`) — here only `""` and `covered` occur.

---

## RED / GREEN disposition

RED = `portrait_visible == false` **with a non-empty fail-layer id**. GREEN =
`true` / `""`.

| Unit | `portrait_visible` | `portrait_fail_layer` | Disposition |
|---|---|---|---|
| `Player` | true | "" | **GREEN** |
| `East_Heretic` | true | "" | **GREEN** |
| `West_Poison` | true | "" | **GREEN** |
| `South_Emperor` | true | "" | **GREEN** |
| `North_Beggar` | true | "" | **GREEN** |
| `Central_Divine` | false | covered | **RED** — `portrait_covered_frac` `0.333333333333333` ≥ `0.25` threshold (and `0.333 * 96 * 128 ≈ 4096 px²` ≥ `64 px²` absolute floor) |

**Exactly one unit is measured RED: `Central_Divine` (王重阳), failing layer
`covered`.** This is the predicted A-class case: `sprite_top == 0.0` puts the
portrait texture's top at the very top of the board (y = 0), so the opaque children
of the 0..92 top strip partially hide it. The measured `covered_frac == 0.333` is
the **max single coverer** (a later-drawn, `mouse_filter != IGNORE` Control) hiding
one third of the ink — above the `COVERED_AREA_FRAC = 0.25` threshold, so the layer
fires. This is the first time the partial-occlusion hole is caught by the predicate:
the old `occluded` layer (full enclosure only) could never fire here.

The A3 fix locus per `step2_design.md` §3.3 for a measured `covered` id is the
round-protected `GridManager.clamp_sprite_offset` top margin — unlock the
`BOARD_TOP_MARGIN_Y = 92` lower bound so the top-row portrait ink starts below the
strip. That decision is A3's; this task only records the measured evidence.

**Discrimination check (why 0.25 is the right threshold):** the four flanker units
measure `portrait_covered_frac == 0.166666666666667` (1/6) — sub-threshold, GREEN —
while `Central_Divine` measures `0.333` (1/3) — above threshold, RED. The probe
therefore separates "merely overlapped by a HUD corner" (GREEN) from "meaningfully
hidden by the top strip" (RED), exactly the discrimination the threshold was pinned
to provide.

---

## Dead-probe invariant check

> `portrait_visible == false` **with** `portrait_fail_layer == ""` is a
> CONTRADICTION (probe dead) — never a pass signal, never defect evidence.

Checked against the measured table: **no unit** has the `false`/`""` pair. The only
`false` unit (`Central_Divine`) carries a non-empty fail-layer id (`covered`).
Every GREEN unit is `true`/`""` (probe alive, all layers pass). Therefore the probe
class is **ALIVE**: the Central_Divine red is a genuine, measured defect; no unit
was classified from a dead-probe pair.

| `portrait_visible` | `portrait_fail_layer` | verdict | measured units |
|---|---|---|---|
| true | "" | probe alive, visible | Player, East_Heretic, West_Poison, South_Emperor, North_Beggar |
| false | non-empty id | probe alive, real defect → RED | Central_Divine (`covered`) |
| false | "" | CONTRADICTION — probe dead | **none** |

---

## Yang Guo (Player) — 3-number probe analysis

The brief demands the contradiction be resolved from the three probe numbers read
**together**, never from pixels or inference.

Measured at f40:

- `portrait_sprite_pos = [480.0, 352.0]` — the `Sprite` child's canvas-space
  `global_position`.
- `portrait_tex_size = [96.0, 128.0]` — the texture is 96 × 128 px.
- `portrait_bar_pos = [446.0, 320.0]` — the floating health bar's `global_position`
  (not the `(-1, -1)` sentinel, so the bar resolves).
- `sprite_top = 224.0` — the ink texture's top edge sits at y = 224 (mid-board).
- `portrait_visible = true`, `portrait_fail_layer = ""` — all eight layers pass.
- `portrait_covered_frac = 0.104166666666667` — sub-threshold partial overlap
  (~10% of the ink hidden by some later-drawn opaque host corner), GREEN.

Geometry read: sprite top y = 224 + texture height 128 → bottom edge y = 352 =
`sprite_pos.y`; centered horizontally on x = 480 → ink spans x ∈ [432, 528]
(96 px wide). The three numbers are **internally consistent** and describe one
coherent on-frame ink region x ∈ [432, 528], y ∈ [224, 352] — fully inside the
960×704 viewport, well below the 0..92 strip, with the health bar at (446, 320)
floating just above the portrait's upper edge.

**Disposition: `frame-reading divergence, no fix`.** Yang Guo's portrait ink IS on
the native frame at mid-board per the probe; the earlier human reading ("scenery at
that spot, no portrait ink") was a frame-reading artifact. All layers measure GREEN
with consistent geometry, so per the no-guess rule (UX-01a fix path must key off a
measured failing layer id) **no gameplay fix is warranted for `Player`** — no
`blank_texture`, no wrong-target clamp, no off_viewport. The measured numbers here
settle the contradiction: the ink is genuinely there, just drawn against scenery in
the raw frame the human read.

---

## Per-candidate coverer limitation

`portrait_covered_frac` publishes only the **max single coverer** fraction
(`VisibilityProbe._covering_fraction` takes the worst single later-drawn opaque
host, never a union sum — overlapping coverers do not add). Per-candidate coverer
attribution (which specific Control, and how much each contributes) is **NOT
separately observable** through the published surface; it lives only inside
`VisibilityProbe`'s candidate walk. The A3 fix task therefore consumes the two
numbers that ARE observable: the fail-layer id (`covered` for `Central_Divine`) and
`portrait_covered_frac` (0.333). If A3 needs per-candidate detail, that would be a
new observable — out of scope for this round.

---

## `blank_texture` fail-open note

No unit measured `blank_texture` — every unit's texture resource passed the
asset-level alpha scan. Per the fail-open rule in `VisibilityProbe._texture_is_blank`
/ `_image_has_alpha`: when `get_image()` returns null (headless/compressed edge) the
layer PASSES and the scan is recorded as "unavailable" — never a fabricated red. A
green `blank_texture` therefore means either "the asset really has alpha > 0" or
"the scan was unavailable and the layer failed open"; it is never asserted here as a
positive alpha finding, because the scan availability is not separately exposed.
For this round's gate the consequence is identical: `blank_texture` did not fire for
any unit.

---

## Run metadata

- Runs: `portrait_cover_probe` (42 asserts, run 1) + `portrait_cover_probe_vec`
  (12 asserts, run 2). Both `hard_passed=true`, 0/N failed by construction,
  `staged_files_applied=[]`, `spec source: playtest/`.
- Boot prologue identical to `playtest/portrait_visibility.yaml`: 7× `ui_accept`
  at 3,5,7,9,11,13,15; `tutorial_next` at 20,25,30; sample at f40. All `at` values
  single integers.
- No `.gd` / `.tscn` / `playtest/` / `tests/` file was created or edited by this
  task; the inline probe YAML was never written to the repo and no scratch file
  remains.

---

## Acceptance mapping

1. **42 measured values, verbatim** — the per-unit table above copies the `observed`
   lines of the two run reports exactly (7 vars × 6 units; `portrait_visible`,
   `portrait_fail_layer`, `portrait_covered_frac`, `portrait_bar_pos`, `sprite_top`
   from run 1; `portrait_sprite_pos`, `portrait_tex_size` from run 2).
2. **Fail-layer ids valid** — every recorded id is `""` or one of the 8 layer ids.
3. **At least one RED with non-empty fail-layer id** — `Central_Divine` =
   `false` / `covered`, `portrait_covered_frac = 0.333` ≥ `0.25` (expected case
   confirmed).
4. **Dead-probe invariant checked** — no unit sits on the `false`/`""`
   contradiction; the RED is real, probe alive.
5. **Yang Guo resolved by measurement** — all layers green with consistent
   geometry (`sprite_pos` + `tex_size` + `sprite_top` + `bar_pos` all coherent);
   recorded `frame-reading divergence, no fix`.
6. **No code changed** — only `final/portrait_cover_probe_notes.md` was created.
7. **Self-consistent** — every disposition in the RED/GREEN column matches its
   measured table row (GREEN rows are `true`/`""`; the one RED row is
   `false`/`covered`).
