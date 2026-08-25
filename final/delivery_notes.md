# Delivery notes — jinyong-events (visibility predicate UX-01a/01b + events 4→16 + no-repeat bag proof)

Round: **jinyong-events**, 2026-08-25. This file is the round's closing record and
changes **docs only** — the three files named in the task card
(`final/delivery_notes.md` new, `design/99_changelog.md` appended,
`design/40_ux_backlog.md` updated). The round's code was landed by sibling tasks
(predicate extension + observables, the clamp-margin visibility fix, the 16-row
event table, the cultivation observables, the scenario and contract wiring); no
`scripts/`, `scenes/`, `playtest/`, `tests/`, `design/30_presentation.md` or
`README.md` file is touched here.

## 1. Round summary

Three goals, per `step2_design.md`:

1. **UX-01a / UX-01b — make the portrait-visibility predicate genuinely decide
   "ink is on the 960×704 frame".** `VisibilityProbe` extended from six to
   **eight** layers: `blank_texture` (asset-level alpha scan, after
   `null_texture`) and `covered` (partial occlusion by a later-drawn opaque host,
   after `occluded`), plus `covered_fraction()` and the **3-number probe**
   (`portrait_sprite_pos` + `portrait_tex_size` + `portrait_bar_pos`) published
   per frame on all six units. Measured pre-fix (f40, native 960×704): **exactly
   one RED** — `Central_Divine` (王重阳), fail layer `covered`,
   `portrait_covered_frac = 0.333333333333333`; `Player` (杨过) measured **GREEN**
   with internally consistent 3-number geometry → the earlier "nothing drawn at
   that spot" reading was a frame-reading divergence, **no fix** (no-guess rule:
   no measured failing layer id for `Player`).
2. **Events 4 → 16.** `EventData.TABLE` grew from 4 near-isomorphic rows to
   **16** rows — pure data, only the 5 implemented effect types
   (`silver`/`attr`/`item`/`practice`/`none`), only real item ids
   (`eq_sword_2`/`eq_armor_2`/`eq_boots_2` new), two real trade-off options per
   row, Chinese Jin Yong flavor from `design/20_content.md`.
3. **No-repeat bag proof.** `_draw_event()`'s exclusion + pool-reset was already
   implemented; this round made it observable
   (`CultivationScreen.events_seen_count`) and proved it with the new
   `event_travel_effects` scenario (count ladder 0 → 1 → 2 → 3, `event_id != ""`
   throughout, no specific drawn id asserted — RNG-dependent by design).

Scenarios: **46 → 47** (new `event_travel_effects.yaml`, registered at the **end**
of `scenario_order` in `playtest/_common.yaml`).

## 2. A/B classification table

### A-class (defect-proof — red before fix, from a measured artifact)

| Observable | A/B | Pre-fix (measured, verbatim) | Evidence |
|---|---|---|---|
| `Central_Divine.portrait_visible` | **A** | **`false`** @f40 | `final/portrait_cover_probe_notes.md` |
| `Central_Divine.portrait_fail_layer` | **A** | **`"covered"`** @f40 (non-empty fail-layer id) | `final/portrait_cover_probe_notes.md` |
| `Central_Divine.portrait_covered_frac` | **A** | **`0.333333333333333`** @f40 (≥ 0.25 threshold, ≥ 64 px² floor) | `final/portrait_cover_probe_notes.md` |
| `EventData.all_defs.size()` | **A** | **4** at baseline (4-row pool) → now **`>= 16`** | `tests/test_event_data.gd` (`all_defs.size() >= 16`), `scripts/data/event_data.gd` |
| `CultivationScreen.events_seen_count` | **A** | **absent** (no observable before this round) → ladder `0 → 1 → 2 → 3` after 3 resolved 游历 proves k distinct draws | `playtest/event_travel_effects.yaml` |
| `Player` 3-number probe (UX-01a) | — | measured **GREEN**: `true` / `""` / `0.104166666666667` / `[480,352]`+`[96,128]`+`[446,320]` — **no A-class red materialized** | `final/portrait_cover_probe_notes.md` → disposition `frame-reading divergence, no fix` |

### B-class (regression guard — green before and after)

| Observable | A/B | Value |
|---|---|---|
| `East_Heretic` / `West_Poison` / `South_Emperor` / `North_Beggar` `.portrait_visible` / `.portrait_fail_layer` | **B** | `true` / `""` @f40 (all four) |
| those four units `.portrait_covered_frac` | **B** | `0.166666666666667` (< 0.25) @f40 |
| all six units `.portrait_tex_size` | **B** | `[96.0, 128.0]` (> 0) @f40 |
| existing 45 green scenarios (baseline) | **B** | stay green; `terminal_victory_8_12_rounds_hp_15_40` stays the single deliberate red |
| `sprite_top >= 0.0` asserts | **B** | hold post-fix (92 px clamp margin keeps them true) |

## 3. Gate results

**Honest state at write time (2026-08-25): the four gate-report artifacts
(`compile_report.json` / `playtest_report.json` / `playtest_summary.md` /
`vision_report.json` / `test_report.json`) are NOT on disk.** The pipeline's gate
steps (5_compile / 5_test / 5_vision) run after this task stage. Per the repo's
no-fabrication rule every gate count below is marked **UNVERIFIED** with its target
stated; no count is invented. (`final/verify_report.json` on disk is the **prior**
round's stale report — it records the old `Canvas`-parse issue and `unit_tests: not
available at this step` — it is NOT evidence for this round.)

| Gate | Target | Status at write time |
|---|---|---|
| Compile (`/compile`) | 0 errors across the whole repo | **UNVERIFIED** — no `compile_report.json` on disk |
| Playtest (`/playtest`) | 47 scenarios, **46 green, 1 deliberate red** (`terminal_victory_8_12_rounds_hp_15_40`), incl. new `event_travel_effects` | **UNVERIFIED** — no `playtest_report.json` / `playtest_summary.md` on disk |
| Vision (`/vision`) | 6/6 questions pass on native 960×704 frames | **UNVERIFIED** — no `vision_report.json` on disk |
| Unit tests (`/test`) | pytest pass (incl. `test_event_content_surface_contract`); GDScript suite pass (12 existing + new cultivation tests) | **UNVERIFIED** — no `test_report.json` on disk; see §5 |

On-disk (non-gate) facts verified directly this round: `playtest/event_travel_effects.yaml`
exists with `name:` = basename, single-integer `at:` values, and the count-ladder
asserts; it is registered at the **end** of `scenario_order` in `playtest/_common.yaml`
(46 → 47 scenario files on disk); `CultivationScreen.events_seen_count` and the six
units' four new portrait vars are all declared in `_common.yaml` `surface`.

## 4. Probe evidence (measured, verbatim)

Measured at **f40** (battle turn 1), native 960×704 frame, two inline probe runs
(`portrait_cover_probe` + `portrait_cover_probe_vec`); values copied verbatim from
`final/portrait_cover_probe_notes.md` — none computed or derived.

| Unit | `portrait_visible` | `portrait_fail_layer` | `portrait_covered_frac` | `portrait_sprite_pos` | `portrait_tex_size` | `portrait_bar_pos` | `sprite_top` |
|---|---|---|---|---|---|---|---|
| `Player` | `true` | `""` | `0.104166666666667` | `[480.0, 352.0]` | `[96.0, 128.0]` | `[446.0, 320.0]` | `224.0` |
| `East_Heretic` | `true` | `""` | `0.166666666666667` | `[224.0, 160.0]` | `[96.0, 128.0]` | `[190.0, 128.0]` | `32.0` |
| `West_Poison` | `true` | `""` | `0.166666666666667` | `[736.0, 160.0]` | `[96.0, 128.0]` | `[702.0, 128.0]` | `32.0` |
| `South_Emperor` | `true` | `""` | `0.166666666666667` | `[224.0, 544.0]` | `[96.0, 128.0]` | `[190.0, 512.0]` | `416.0` |
| `North_Beggar` | `true` | `""` | `0.166666666666667` | `[736.0, 544.0]` | `[96.0, 128.0]` | `[702.0, 512.0]` | `416.0` |
| `Central_Divine` | **`false`** | **`covered`** | **`0.333333333333333`** | `[480.0, 96.0]` | `[96.0, 128.0]` | `[446.0, 94.0]` | `0.0` |

Dispositions (from the probe notes):

- **`Central_Divine` — RED (`covered`).** `sprite_top == 0.0` puts the texture top
  at the board top (y = 0); the opaque children of the 0..92 top strip partially
  hide it; `portrait_covered_frac = 0.333333333333333` is the max single coverer,
  above the `COVERED_AREA_FRAC = 0.25` threshold and the 64 px² absolute floor. The
  old `occluded` layer (full enclosure only) could never fire here — this is the
  partial-occlusion hole closing. Fix locus per `step2_design.md` §3.3:
  `GridManager.clamp_sprite_offset` top margin `BOARD_TOP_MARGIN_Y = 92` so top-row
  ink starts below the strip.
- **`Player` (杨过) — GREEN, `frame-reading divergence, no fix`.** All eight layers
  pass; the 3-number geometry is internally consistent: sprite top y = 224, texture
  96 × 128 → ink spans x ∈ [432, 528], y ∈ [224, 352], mid-board and fully inside the
  960×704 viewport, well below the strip; bar at (446, 320) floats just above the
  portrait's upper edge. The earlier human reading ("scenery at that spot, no ink")
  was a frame-reading artifact. No blank texture, no wrong-target clamp, no
  off-viewport → per the no-guess rule **no gameplay fix is warranted for `Player`**.
- **Dead-probe invariant:** no unit sits on the `false` + `fail_layer == ""`
  contradiction; the only `false` unit (`Central_Divine`) carries the non-empty id
  `covered` → probe class ALIVE, the RED is a genuine measured defect.
- **Discrimination:** the four flanker units measure `0.166666666666667` (1/6,
  sub-threshold, GREEN) while `Central_Divine` measures `0.333` (1/3, above) — the
  0.25 threshold separates "merely overlapped by a HUD corner" from "meaningfully
  hidden by the top strip".

## 5. Effects-land determination (UNPROVEN clause)

The 48 effect cases exist **as actual GDScript unit tests**:
`tests/test_cultivation.gd` (`extends SceneTree`, the shape `run_tests.sh`'s
`/script` gate auto-discovers) holds `_test_event_effects_fresh` (16 defs × 2
options = 32 fresh cases) and `_test_event_effects_adversary` (16 cases), and
`tests/test_event_data.gd` pins `all_defs.size() >= 16` plus `_test_effect_targets`
(target schema for every row: `attr.target` in the five keys, `item.target` in the
12 real equipment ids, `type` in the five effect types, non-empty labels).

However, **no on-disk test-report artifact lists `test_cultivation` as discovered
AND passed at delivery-write time**: there is no `test_report.json` on disk, and the
only JSON report present (`final/verify_report.json`) is the **prior** round's stale
report, which explicitly records `unit_tests: "not available at this step (no
test_report.json on disk)"`. Per the reviewer-mandated UNPROVEN clause, the
effects-land claim is recorded as **UNPROVEN** — the unit tests exist and are wired,
but their execution and pass are not gate-evidenced on disk at this delivery. The
issue is left open until `5_test` produces a report listing `test_cultivation` as
discovered and passed. The delivery notes make **no claim** about effect-application
outcomes beyond the on-disk existence and wiring of those unit tests.

## 6. UX disposition

Recorded in `design/40_ux_backlog.md` from the measured evidence
(`final/portrait_cover_probe_notes.md`):

- **UX-01a (Player / 杨过)** — measured disposition: **`frame-reading divergence,
  no fix`**. Measured `portrait_visible == true`, `fail_layer == ""`, all eight
  layers green, 3-number geometry internally consistent; the "nothing drawn at that
  spot" finding was a human frame-reading artifact. Closed from the measurement
  (evidence pointer: `final/portrait_cover_probe_notes.md`).
- **UX-01b (Central_Divine / 王重阳)** — measured pre-fix RED:
  `portrait_visible == false`, `portrait_fail_layer == "covered"`,
  `portrait_covered_frac == 0.333333333333333`, `sprite_top == 0.0`. The
  clamp-margin fix (`BOARD_TOP_MARGIN_Y = 92`) was landed this round. **Not marked
  CLOSED**: backlog rule 2 requires post-fix green to be on-disk evidenced (a
  `playtest_report.json` / `playtest_summary.md`), which is absent at write time —
  the measured disposition is recorded and closure is pending the 5_compile playtest
  gate.

## 7. Evidence chain

| Artifact | Role |
|---|---|
| `final/portrait_cover_probe_notes.md` | measured pre-fix probe table (f40), both inline runs, dispositions, dead-probe invariant, Yang Guo 3-number analysis |
| `playtest/portrait_visibility.yaml` | extended in place: `covered_frac` / `tex_size` / `fail_layer` asserts appended |
| `playtest/event_travel_effects.yaml` | new scenario — no-repeat count ladder 0→1→2→3, `event_id != ""` throughout |
| `playtest/_common.yaml` | surface (`events_seen_count`, four new portrait vars on six units) + `scenario_order` tail registration |
| `tests/test_cultivation.gd` | no-repeat exclusion / pool-reset + 48 effects cases (wired; execution not gate-evidenced → §5 UNPROVEN) |
| `tests/test_event_data.gd` | `all_defs.size() >= 16` + `_test_effect_targets` |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` + `test_event_content_surface_contract` (contract pin) |
| `scripts/ui/visibility_probe.gd`, `scripts/autoload/grid_manager.gd`, `scripts/data/event_data.gd`, `scripts/segments/cultivation.gd`, `scripts/characters/player.gd`, `scripts/characters/enemy.gd` | the round's code (landed by sibling tasks) |
| `design/99_changelog.md` | this round's row appended (2026-08-25) |
| `design/40_ux_backlog.md` | UX-01a / UX-01b updated from measured evidence |

**Gate gap (honest):** no `compile_report.json` / `playtest_report.json` /
`playtest_summary.md` / `vision_report.json` / `test_report.json` exists on disk at
this delivery; all gate counts in §3 are marked UNVERIFIED with targets and are to
be confirmed by the pipeline's 5_compile / 5_test / 5_vision gates. No gate count is
invented.

