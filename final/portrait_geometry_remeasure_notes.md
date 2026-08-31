# Portrait Geometry Re-Measure Notes — M1 (wuxia-shrimp-portraits, 2026-08-31)

**Task:** `portrait_geometry_remeasure` — re-run the three pinned portrait-geometry nails
against the six NEW shrimp PNGs via the playtest harness (`godot_playtest_scenario`) and
record the **observed** values. **ZERO repo-file changes** — no `playtest/*.yaml` was
edited, staged, or created; `scripts/` and the camera/coord layer were not touched. The
only write this task makes is this notes file.

**Instrument:** the repo's own playtest harness. Frozen scenarios were run by name
unmodified; the six-unit visibility values and the exact f40/f820 `ink_world_dx/dy` were
captured with the probe-contradiction technique — inline YAML passed as the `scenario=`
parameter, **never staged into `playtest/`** (a staged inline file would be executed by the
loader and could redden the whole gate if forgotten).

**Run status: MEASURED (all green).** All three nails green on the new art; no red line, no
threshold change, no yaml/script/PNG edit. The geometry swap did not break the pinned
layout.

---

## 0. Precondition — surface whitelist verified (append-only, NOT edited)

Before the M1c probe, `playtest/_common.yaml` was read and every target observable
confirmed on its unit's whitelist block:

- All six units (Player, East_Heretic, West_Poison, South_Emperor, North_Beggar,
  Central_Divine): `portrait_visible`, `portrait_fail_layer`, `portrait_covered_frac`,
  `portrait_sprite_pos`, `portrait_tex_size`, `portrait_bar_pos`, `portrait_ink_rect`,
  `ink_world_dx`, `ink_world_dy`, `camera_offset_y` — present on every unit block.
- `sprite_top` — present on **Player** (L255), **East_Heretic** (L289), **Central_Divine**
  (L378) **only**; absent on West_Poison / South_Emperor / North_Beggar. `sprite_top` was
  therefore captured on the first three and **skipped** on the other three (the whitelist was
  NOT edited).
- All camera observables (`follow_target_is_active`, `active_unit_screen_y`,
  `active_unit_world_y`, `viewport_half_y`, `camera_position`, `camera_y_lo`, `camera_y_hi`)
  present under the `Camera` block.

No whitelist name was missing; no stop-and-report condition was triggered.

---

## 1. M1a — `portrait_grid_alignment` (frozen, run UNMODIFIED)

Run by name via `godot_playtest_scenario(scenario="portrait_grid_alignment")`. The frozen
scenario was not edited.

- **Pass count: 30/30** (`ok=30, total=30`), `hard_passed: true`.
- **24 ink lines green** — 12 at f40 (all six units × `abs(ink_world_dx)<=1.0` +
  `abs(ink_world_dy)<=1.0`) + 12 at f820 (same 12 re-asserted at the walk-arrival frame).
  **No ink line reddened** (the frozen yaml prints `observed` only on a red line; green
  gave none, so the exact observed dx/dy below come from the M1c probe-contradiction — see
  §3).
- **6 route/timing pins green** — f135 `Player.grid_pos == (8,2)` + `moves_left == 0`;
  f750 `active_unit_name == "Yang Guo"` + `Player.grid_pos == (6,2)`; f820
  `Player.grid_pos == (6,1)` + `moves_left == 3`.
- Walk-leg route confirmed intact: the round-2 arrival landed at the row-1 tile `(6,1)` as
  the frozen yaml's derivation predicts (West Poison's knockback moved the player `(8,2) ->
  (6,2)` during round-1 enemy turns, then `+0,-64` from `(6,2)` resolves to `(6,1)`).
- **No red-for-the-wrong-reason condition** — the five enemies' `grid_pos` needed no
  report because no leg missed its tile.

---

## 2. M1c observed `ink_world_dx` / `ink_world_dy` (from probe-contradiction, never staged)

The frozen yaml does not print dx/dy on green. The exact observed values at both legs were
forced out with inline always-false assertions (see §4/§5 for the probes). All **0.0** — the
texture-rect-derived alignment reads perfect stand-on-tile for every unit at both legs.

### f40 (battle turn 1, all six units at spawn) — observed `ink_world_dx` / `ink_world_dy`

| unit | ink_world_dx (observed) | ink_world_dy (observed) |
|---|---|---|
| Player | 0.0 | 0.0 |
| East_Heretic | 0.0 | 0.0 |
| Central_Divine | 0.0 | 0.0 |
| West_Poison | 0.0 | 0.0 |
| South_Emperor | 0.0 | 0.0 |
| North_Beggar | 0.0 | 0.0 |

### f820 (walk-arrival frame — Player on the row-1 tile `(6,1)`, `moves_left == 3`) — observed `ink_world_dx` / `ink_world_dy`

| unit | ink_world_dx (observed) | ink_world_dy (observed) |
|---|---|---|
| Player | 0.0 | 0.0 |
| East_Heretic | 0.0 | 0.0 |
| Central_Divine | 0.0 | 0.0 |
| West_Poison | 0.0 | 0.0 |
| South_Emperor | 0.0 | 0.0 |
| North_Beggar | 0.0 | 0.0 |

**Interpretation:** all 12 f40 dx/dy and all 12 f820 dx/dy read **0.0** → `abs(x)<=1.0`
green trivially. Every portrait's ink centre x equals its unit's world x and its ink bottom
y equals the unit's feet y, at spawn and at the row-1 arrival. The new shrimp PNGs stand on
their own tiles exactly as the old human figures did — the alignment nail's claim holds.

---

## 3. M1c six-unit eight-layer visibility (f40) — observed values

Forced out with inline always-false contradictions over the whitelisted observables. No
unit's probe was dead (`portrait_visible == false` WITH `portrait_fail_layer == ""` — the
dead-probe invariant — was **not** seen; every unit reports visible with empty fail_layer,
which is a genuine reading).

| unit | portrait_visible (bool) | portrait_fail_layer | portrait_covered_frac | portrait_tex_size | portrait_ink_rect (position, size) | ink_world_dx | ink_world_dy | sprite_top |
|---|---|---|---|---|---|---|---|---|
| Player | true | "" | 0.0 | [96.0, 128.0] | P:(432.0, 224.0) S:(96.0, 128.0) | 0.0 | 0.0 | 224.0 |
| East_Heretic | true | "" | 0.0 | [96.0, 128.0] | P:(176.0, 32.0) S:(96.0, 128.0) | 0.0 | 0.0 | 32.0 |
| Central_Divine | true | "" | 0.0 | [96.0, 128.0] | P:(432.0, -32.0) S:(96.0, 128.0) | 0.0 | 0.0 | -32.0 |
| West_Poison | true | "" | 0.0 | [96.0, 128.0] | P:(688.0, 32.0) S:(96.0, 128.0) | 0.0 | 0.0 | *(not whitelisted)* |
| South_Emperor | true | "" | 0.0 | [96.0, 128.0] | P:(176.0, 416.0) S:(96.0, 128.0) | 0.0 | 0.0 | *(not whitelisted)* |
| North_Beggar | true | "" | 0.0 | [96.0, 128.0] | P:(688.0, 416.0) S:(96.0, 128.0) | 0.0 | 0.0 | *(not whitelisted)* |

**Notes on the observed values:**
- `portrait_fail_layer` is the empty-string `""` for all six → **no portait fails any of the
  eight VisibilityProbe layers** (`hidden_in_tree` / `null_texture` / `blank_texture` /
  `zero_rect` / `off_viewport` / `clipped` / `occluded` / `covered`). It is not `"blank_texture"`
  (the layer ids) and not one of the 8 ids — the `""` value means the portrait is fully visible.
- `portrait_covered_frac = 0.0` for all six → no portrait is partly covered by an occluder;
  the health-bar/clip region does not overlap any of the new portraits.
- `portrait_tex_size = [96.0, 128.0]` for all six → every portrait loads the new 96×128 RGBA
  texture (no `null_texture`). This confirms the swapped PNGs are loaded and have dimensions.
- `sprite_top` on the three whitelisted units (Player 224.0, East_Heretic 32.0,
  Central_Divine -32.0) matches each unit's `portrait_ink_rect` top edge (feet world y minus
  128) — the foot-anchored `(0, -tex.y/2)` offset is intact.
- `portrait_ink_rect` positions confirm each unit's feet anchor: e.g. Player's rect top y
  224.0 = feet y - 128, Central_Divine's top y -32.0 = feet y 96 - 128, etc. All consistent
  with the constant offset — nothing shifts a portrait off its tile.

---

## 4. M1c probe instrumentation (transcribed evidence)

### Probe 1 — f40 six-unit (always-false contradiction block, inline, never staged)

`godot_playtest_scenario(inline_scenario=...)`. Boot: `ui_accept`@3,5,7,9,11,13,15;
`tutorial_next`@20,25,30; battle turn 1 settled at f40. f40 block: 45 always-false
contradictions — all six units × 7 observables (`portrait_visible`, `portrait_fail_layer`,
`portrait_covered_frac`, `portrait_tex_size`, `portrait_ink_rect`, `ink_world_dx`,
`ink_world_dy`) + `sprite_top` on Player/East_Heretic/Central_Divine only. Contradiction
forms per type (bool `x and not x`, String `x == "" and x != ""`, float `x >= 0.0 and
x < 0.0`, Vector2/Rect2 `x != x`). Result: `ok=0, total=45` (all intended contradictions
failed, printing the observed values listed in §3), `hard_passed: true` (hard gate counts
errors, not failed in-line assertions — this is the advisory probe path).

### Probe 2 — f820 walk-arrival leg (inline, never staged)

Boot as above; inline replay of the frozen walk: `clicks: [Player +64,-192]`@75,
`end_turn`@150, real pins `Player.grid_pos == (6,2)` + `CombatManager.active_unit_name ==
"Yang Guo"`@750, `clicks: [Player +0,-64]`@760, then f820 real pins `Player.grid_pos ==
(6,1)` + `Player.moves_left == 3` + 12 always-false `ink_world_dx`/`ink_world_dy`
contradictions for all six. Result: `ok=4, total=16` — the four real pins PASSED (grid_pos
(6,2), grid_pos (6,1), moves_left 3, active_unit_name "Yang Guo"); the 12 contradictions
failed as intended, printing the observed dx/dy in §2, `hard_passed: true`.

---

## 5. M1b — `camera_transform_follows_unit` and `spine_to_ending` (frozen, run UNMODIFIED)

Run by name via `godot_playtest_scenario(scenario="camera_transform_follows_unit,spine_to_ending")`.

- **`camera_transform_follows_unit`: 9/9** (`ok=9, total=9`), `hard_passed: true`. Both
  camera-motion-pure-translation invariants on the new art: at f40 (camera at centre) and at
  the f140 arrival (camera pinned to `cam_y_lo`=260), `active_unit_screen_y -
  active_unit_world_y == viewport_half_y - camera_position.y` (92 == 92) and
  `abs((health_bar_screen_y - health_bar_world_y) - camera_offset_y) <= 1.0` hold; plus
  `follow_target_is_active == true` and `camera_position.y in [camera_y_lo, camera_y_hi]`.
- **`spine_to_ending`: 42/42** (`ok=42, total=42`), `hard_passed: true` — the full
  six-segment spine stays fully green, **0 runtime errors**. The portrait swap introduced no
  runtime error anywhere in the boot → creation → cultivation → map → battle → ending spine.

---

## 6. Red-nail findings

**None.** Every pinned check this task re-measures is green on the new shrimp art at the
frozen thresholds:

| nail | re-measured result | observed |
|---|---|---|
| `portrait_grid_alignment` | 30/30 (24 ink lines green) | all 24 dx/dy = 0.0 (f40 + f820) |
| `portrait_visibility` six-unit | all six visible | `portrait_visible=true`, `portrait_fail_layer=""`, `covered_frac=0.0` |
| `camera_transform_follows_unit` | 9/9 | both translation invariants (92==92), follow active, cam within bounds |
| `spine_to_ending` | 42/42 | fully green, 0 runtime errors |

No threshold was loosened, no `playtest/*.yaml` edited, no `scripts/` or
`scripts/camera_follower.gd` / `scripts/coord.gd` touched, no PNG redrawn. The frozen
scenarios and the four guard tests were left byte-identical.

**Why the alignment being green here is still not proof of *pixel* footing** — recorded as a
finding, not a defect: `ink_world_dx/dy` derive from the **texture rect** (`portrait_ink_rect`,
published at `player.gd:469` / `enemy.gd:328`, dx/dy at `player.gd:502-503` / `enemy.gd:355-356`)
and the constant foot-anchor offset `(0, -tex.y/2)` — never from the alpha pixels. So the 0.0
values prove the 96×128 texture is foot-anchored, but would read ≈0.0 even for an image with
transparent bottom padding floating the drawn content. The true footing check is the per-PNG
alpha bounding box (M2) — see §7 — which independently confirms this set has **no** bottom
padding, so here the green is genuinely constructed by the foot anchor aligning with real ink.

---

## 7. Cross-reference to the alpha-bbox footing record (M2)

The pixel-true footing of the same six PNGs was measured separately in
**[`final/portrait_alpha_bbox_notes.md`](portrait_alpha_bbox_notes.md)** (`portrait_alpha_bbox_probe`,
in-engine per-pixel probe, 2026-08-31). Key results this task relies on for the "does the
drawn ink actually stand on the tile" story:

- **`bottom_gap_raw = 0` for all six** — the drawn ink touches the bottom row (y=127) in
  every portrait, so the constant foot-anchor offset places real ink (not a transparent
  margin) on the tile. The texture-rect pin's anticipated blind spot (transparent bottom
  padding floating a portrait) **does not exist in this set**.
- **`h_center_offset_raw` = 0** for east_heretic, south_emperor, central_divine, yang_guo and
  **−0.5** for west_poison, north_beggar (a half-pixel odd-width bbox asymmetry — a finding,
  **not** a geometry defect; invisible at the 96-px texture scale and does not affect the
  pinned dx/dy, which derive from the constant 96-px texture width).
- **Threshold-8 bbox == raw bbox** for all six (no antialiasing fringe inflates an edge);
  opaque counts 4388–7193 at thresh8 (no blank / near-blank / all-transparent decode).

The M1 engine-true dx/dy (all 0.0) and the M2 alpha-bbox (`bottom_gap = 0` for all six)
together confirm: the headline alignment nail green on the new art is **constructed** by the
foot-anchor offset meeting real ink at the bottom of every texture, not a coincidence of the
old human figures' geometry. The swap did not break the pinned layout, and the layout pin was
not merely coincidental.

---

## 8. Hard-condition self-run evidence

Per `configs/addons/game_harness/implementer.md:23`, every scenario this task touches was
self-run via `godot_playtest_scenario` and the observed values are pasted above. Runs:

1. `portrait_grid_alignment`, `camera_transform_follows_unit`, `spine_to_ending` (named,
   frozen) — **30/30, 9/9, 42/42**, `hard_passed: true`.
2. Inline f40 probe (never staged) — 0/45 (all intended contradictions; observed values
   transcribed in §3), `hard_passed: true`.
3. Inline f820 walk-replay probe (never staged) — 4/16 (4 real pins passed, 12 observed
   dx/dy captured), `hard_passed: true`.

**Repo-file change summary:** the only file written this step is this notes file. No
`playtest/*.yaml` was created, staged, edited, or deleted; the four guard tests and all of
`scripts/` are untouched.