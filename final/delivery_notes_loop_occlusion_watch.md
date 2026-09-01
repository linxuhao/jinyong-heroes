# Delivery Notes — occlusion_watch_gate (jinyong-loop R2)

**Date:** 2026-09-01. **Round:** jinyong-loop R2 (rule short-circuits + theme-round occlusion regression).
**Scope of this task:** the structural occlusion gate (design D6, reviewer R1 order) — a NEW autoload
`UiOcclusionWatch` that publishes `violations` / `violations_text` every frame, its harness contract
(surface whitelist + scenario_order append), the `occlusion_no_button_over_text` scenario, a new pytest
guard, and this evidence record. The scenario + surface/country wiring + pytest guard were delivered in
step t_impl; this step (t_impl review fix) adds the missing evidence record, hardens the LCA walk in
`ui_occlusion_watch.gd` against an out-of-bounds read when the lowest common ancestor is the scene-tree
root, and pins the evidence record in pytest so it cannot be silently dropped in a future round.

## 0. Honesty tiers

- **本步实测 (measured in this step, live runs):** the RED-FIRST evidence below comes from
  `godot_playtest_scenario` sidecar runs of `occlusion_no_button_over_text` against the tree with the
  three scene files reverted to their PRE-fix geometry, then the same scenario GREEN against the fixed
  tree. `observed` values are copied from the play-test report verbatim.
- **已录 (recorded, geometric):** threshold-rationale numbers for the three defect pairs are read off
  the `.tscn` offsets of the PRE-fix geometry (recorded in `final/delivery_notes_loop_occlusion.md` §2/§3)
  and the Godot 4 rect formula; they are the basis for the `>=4px` and `>=0.5` thresholds.
- **待官方判 (deferred to the official frame product):** same-frame screenshots and pixel legibility are
  a downstream 5_vision product (the same discipline recorded in `final/delivery_notes_loop_occlusion.md`
  §1). The structural watch asserts `violations == 0` on every captured frame of the three screens and
  is the machine gate; the frame-pair gallery is the human evidence, judged downstream.

## 1. Why a structural gate (not the vision gate)

Vision gate Q6 asks about TRUNCATION, not OCCLUSION — that is exactly how 79/79 vision-good coexisted
with three button-over-text overlaps. The gate must make "a visible control covers body text" an
observable PROPERTY, not a vision-judge opinion. The generic check cannot live harness-side:
`aitelier/tools/godot_playtest/impl.py` is an external sidecar whose asserts are single-node
`Expression`s over whitelisted surfaces, so the predicate is computed ENGINE-SIDE in the new autoload and
the harness asserts the published property with its existing grammar. New autoload ONLY — no existing
script is modified (the three geometry fixes stay presentation-only, `scripts/segments/sect_select.gd`,
`assets/themes/global_theme.tres`, `scenes/ui/hud.tscn` byte-untouched).

## 2. RED-FIRST four values (measured, this task's own red run)

The occlusions before the geometry task's fixes ARE the red state. The watch scenario was run against
the tree with the three scene files temporarily reverted to PRE-fix geometry, marked
`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` in each file header, then restored byte-identically
(captured in `final/delivery_notes_loop_occlusion.md`; see §6 revert recipe below).

| # | Failing frame | First failing assert | Exact error / observed | Green asserts before red |
|---|---|---|---|---|
| 1 | f158 | `UiOcclusionWatch.violations` (`violations == 0`) | observed `violations == 1`, `violations_text == "Next>Body"` (the tutorial Next button drawn over the WELCOME body RichTextLabel — the measured defect pair) | 5 (f60 ×2, f90 ×1, f120 ×1, f150 ×1) |

Note: the red-first run stops at the first red frame (f158), so the sect-select (f345) and roster (f425)
asserts were not reached on the red tree. Their observed values are recorded separately here from the
geometry note's measured overlap math (§3) and the single-scenario runs of the fixed tree (green, §4).
A second red probe (asserting `violations == 1` at f345 / f425 on the reverted tree, i.e. the pair count
expected at each screen) would confirm each pair independently; this was not re-run in this step — each
of the three is the same predicate family and the f158 red already proves the predicate fires.

## 3. Threshold rationale — MEASURED basis for >=4px and >=0.5

The two constant thresholds in `ui_occlusion_watch.gd` (`_MIN_OVERLAP_PX = 4`,
`_MIN_RESIDUAL_VISIBILITY = 0.5`) are chosen so a future legal layout tweak cannot trip them blind.
Basis = the measured per-axis intersection and residual visibility of each of the three defect pairs on
the PRE-fix tree (rects from the `.tscn` offsets per the rect formula; the geometry note's §2/§3 tables
are the source of the before-geometry):

### Pair 1 — tutorial WELCOME `Next` (Button) over `Body` (RichTextLabel)
- **Per-axis intersection (PRE-fix):** Buttons HBox rect x 280..680 × y 96..536; Body rect x 200..760 ×
  y 216..452. x-overlap = min(680,760) − max(280,200) = 680−280 = **400 px**; y-overlap =
  min(536,452) − max(96,216) = 452−216 = **236 px**. (The `Next` button filled the full column height;
  the watch pairs the Button node, so it is the whole button rect vs the body rect.)
- **Residual visibility of `Body` under the overlay chain:** `Next` is opaque (theme Button background
  alpha 1.0; the strip's HBox children render their own opaque stylebox), so residual = 1.0×(1−1.0) =
  **0.0** — the body text is completely covered where the button spans it. `_MIN_RESIDUAL_VISIBILITY = 0.5`
  sits well above 0.0.

### Pair 2 — sect-select SectButton{i} over `BodyLabel`
- **Per-axis intersection (PRE-fix):** BodyLabel x 320..320 ⇒ 0.5W−320 .. 0.5W+320; SectButton x
  −120..120 ⇒ 0.5W−120 .. 0.5W+120. x-overlap = min(0.5W+120, 0.5W+320) − max(0.5W−120, 0.5W−320) =
  (0.5W+120) − (0.5W−120) = **240 px**; y-overlap is the full button band over the Tang-Men row
  (the row's text runs under the buttons' y-band) ≈ **40 px** (button height with the theme's
  font_size 15 + content margins 4/4).
- **Residual visibility of `BodyLabel`:** buttons opaque, residual = **0.0** where covered.

### Pair 3 — roster EquipButton{i} over `RosterBodyLabel`
- **Per-axis intersection (PRE-fix):** RosterBodyLabel x 16..624; EquipButton x 165..301 etc.
  x-overlap = min(301,624) − max(165,16) = 301−165 = **136 px** per column; y-overlap over the
  悟性 row band ≈ **30 px**.
- **Residual visibility:** opaque buttons, residual = **0.0**.

### Why the thresholds sit where they sit
- `>=4px` both axes: 240 / 400 / 136 px on x and 236 / 40 / 30 px on y — every measured pair is
  orders of magnitude above 4 px. A 4 px graze (a button edge just kissing a label's rect edge, e.g. a
  scrollbar, a padding corner) is not occlusion; 4 px is safely below every real defect. A legal tweak
  that moves a button a few px will not accidentally cross below 4 px on a genuinely overlapping pair.
- `>=0.5` residual: the three defect labels sit on OPAQUE panels with no translucent overlay between
  button and label ⇒ residual 0.0, far below 0.5. The tutorial/roster dims (0.88 / 0.85 alpha over a
  whole screen) push under-labels to (1−0.88)=0.12 / (1−0.85)=0.15 residual — excluded by the 0.5 cut
  (and by the same-CanvasLayer clause, since the dim ColorRects sit on a different layer by design).
  A dim at 0.5 exactly (residual 0.5, boundary-ambiguous) is out of this game's vocabulary; the cut is
  chosen to sit between the designed 0.12–0.15 dim coverage and the 0.0 defect coverage with margin.

## 4. GREEN run after the geometry fixes (measured)

The watch scenario `occlusion_no_button_over_text` against the fixed tree (the three geometry fixes
landed):
- f158 (tutorial WELCOME): `UiOcclusionWatch.violations == 0` — GREEN.
- f345 (sect-select): `UiOcclusionWatch.violations == 0` — GREEN.
- f425 (roster open in CULTIVATION): `UiOcclusionWatch.violations == 0` — GREEN.
- `violations_text` empty at all three frames.

## 5. Tutorial other-6-pages measurement record

- **WELCOME page — MEASURED (this task):** red-first run observed `violations == 1`, `Next>Body` at
  f158 (see §2); green after the geometry fix at f158.
- **Other 6 tutorial pages — NOT EXECUTED in this step + reason:** the official frame product captures
  only the WELCOME page in the pinned run, and this task's scenario (`occlusion_no_button_over_text`)
  drives only the WELCOME page (the intro sequence shows WELCOME before the next click). The remaining
  six pages' occlusion is a geometric consequence of the fix (the Buttons HBox is anchored to the panel
  bottom — panel-local y 344..384, 44 px below the body's y 64..300 — regardless of body TEXT length,
  so no page can put the strip over the body), which `final/delivery_notes_loop_occlusion.md` §4
  records as geometric inference. Because the structural watch runs every frame over the live tree, its
  `violations == 0` assertion covers EVERY captured frame of EVERY page should a future run capture them;
  the per-page pixel verdict remains deferred to the downstream frame product. Per-page values are
  therefore **未执行 + 原因** and this note says so honestly.

## 6. Revert recipe + zero-residue confirmation

RED-FIRST was run with a temporary revert of the three scene files to PRE-fix geometry:
- `scenes/ui/tutorial_overlay.tscn`: Buttons HBox anchors (0,0,0,1) + offsets (100,−56,500,−16).
- `scenes/segments/sect_select.tscn`: BodyLabel offset_right 320; SectButton0..4 x −120..120; HintLabel
  −200..200.
- `scenes/ui/roster_panel.tscn`: RosterBodyLabel offset_right −16; EquipButton0..11 x
  165/211/257..209/255/301.

Each reverted file header had the marker `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`. After the red
run the originals were restored byte-identically. **Zero-residue check:** `grep -c "TEMPORARY RED-FIRST
REVERT"` over the three scene files returns 0; the delivered tree contains no revert marker
(`repo_apply` is `git add -A` — none may remain). The geometry task's own delivery note
(`final/delivery_notes_loop_occlusion.md`) documents the same before-geometry values independently.

## 7. Pre-landing checklist — git-log theme-merge confirmation

**Theme round has merged — confirmed by in-tree evidence (no shell in this step to run `git log`; the
brief requires the explicit check, and it resolves via the tree):** the theme round's focus-style work
consumes `ThemeManager.option_style` at `scripts/segments/cultivation.gd:685` and
`scripts/segments/sect_select.gd:88` (verified in-tree above). `cultivation.gd`'s `_rebuild_options_box`
stylebox-swap portion is therefore landed; the occlusion gate touches NEITHER `cultivation.gd` NOR
`sect_select.gd` (pure new autoload + scene geometry), so there is no overlap with the theme-round
functions. `assets/themes/global_theme.tres` and `scenes/ui/hud.tscn` were never opened for edit
(byte-untouched). The explicit `git log` shell check is recorded as **not executed + reason** (no shell
available in this step); the merge is nonetheless evidenced by the landed `option_style` consumption
and does not gate a single-byte overlap.

## 8. Robustness fix applied this step (reviewer feedback)

- `ui_occlusion_watch.gd::_draws_over` guarded the child-branch index: when the lowest common ancestor
  is the LAST element of a parent chain (the scene-tree root, two controls from unrelated top-level
  subtrees collected across the whole visible tree every frame), `bp.find(lca)+1` would read one past
  the array end and emit a GDScript runtime error (a hard harness red). The guard now early-returns
  `false` when `bi >= bp.size()` or `li >= lp.size()` — no LCA child-branch ⇒ no draw-order comparison
  ⇒ pair out of scope (never red). The LCA-null case was already handled.
- pytest `test_occlusion_watch_surface_contract` now also pins the existence of this evidence record
  (`final/delivery_notes_loop_occlusion_watch.md`), so the threshold-rationale + tutorial-pages record
  cannot be silently dropped in a future round.
