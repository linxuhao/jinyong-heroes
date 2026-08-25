# Portrait Visibility — Probe Notes (UX-01 A1, observed-not-assumed discipline)

**Task:** `visibility_probe_and_observables` (A1) — build the six-layer on-frame
portrait-visibility predicate (`scripts/ui/visibility_probe.gd`, class
`VisibilityProbe`), publish it as two observable surface vars on all six battle
units, and run a probe to record the **pre-fix** baseline with **measured** (not
derived) values.

**The only code written by this task:** `scripts/ui/visibility_probe.gd` (NEW) +
two additive var declarations and a two-line `_process()` addition each in
`scripts/characters/player.gd` and `scripts/characters/enemy.gd`. No fix was
made — `_refresh_sprite_clamp` / `clamp_sprite_offset` / `grid_manager.gd`
belong to the A2 task and are untouched. No `playtest/`, `tests/`, or
`design/` file was modified.

---

## ⚠️ Run status: probe execution BLOCKED — godot-builder outage

**The probe run could NOT be executed in this step.** The godot-builder service
(`http://godot-builder:8080`) returned `HTTP 500: Internal Server Error` on
**every** `godot_playtest_scenario` attempt, including a minimal
`use_staged=false` connectivity probe that asserts nothing about the new code.
Nine consecutive failed attempts, in order:

1. full 18-assert `portrait_visibility_probe` (inline) — 500
2. full 18-assert `portrait_visibility_probe` (inline) — 500
3. trivial `connectivity_probe` (Player.health contradiction, default staged) — 500
4. full 18-assert probe — 500
5. full 18-assert probe — 500
6. full 18-assert probe — 500
7. trivial `connectivity_probe` with `use_staged=false` — 500
8. full 18-assert probe — 500
9. full 18-assert probe — 500

Because even a scenario that reads nothing about `VisibilityProbe` fails, this
is a service-level outage, **not** a defect in the staged code. The play-test
gate was "skipped — scene NOT smoke-tested".

**Consequence:** the `observed` column below is **PENDING**, not measured. Per
the A/B discipline, classification must come from a live headless run — a
derived value (even a confident one) is exactly the class of "guess" this probe
exists to eliminate (the health-bar round's 2.75x authored-vs-runtime gap is
the recorded precedent). **No A/B classification is asserted here. The A2 fix
task must not start from these notes' derived values; it must re-run the probe
below the moment the builder is reachable and classify from the printed
`observed` values.**

---

## Probe method

One inline run (`portrait_visibility_probe`) booting `res://scenes/main.tscn`
through the proven battle prologue (copied from `ui_geometry_readability` /
`click_move_*`):

| Frame | Action | Phase | Asserts (all always-false diagnostics) |
|---|---|---|---|
| f3..f15 | 7× `ui_accept` | boot | — |
| f20/f25/f30 | 3× `tutorial_next` | tutorial | — |
| f40 | — | battle turn 1 | 18 contradiction asserts (below) |

Every assert is an **always-false contradiction** whose only purpose is to force
the harness to print the var's `observed` value:

- bool: `portrait_visible and not portrait_visible`
- String: `portrait_fail_layer == "" and portrait_fail_layer != ""`
- float: `sprite_top >= 0.0 and sprite_top < 0.0`

The inline YAML (passed as CLI text, **never staged, never written to the
repo** — the only repo file of this task is this notes file):

```yaml
name: portrait_visibility_probe
timeline:
- {at: 3..15, actions: [ui_accept]}
- {at: 20/25/30, actions: [tutorial_next]}
- at: 40
  assert:
    Player.portrait_visible: portrait_visible and not portrait_visible
    Player.portrait_fail_layer: portrait_fail_layer == "" and portrait_fail_layer != ""
    Player.sprite_top: sprite_top >= 0.0 and sprite_top < 0.0
    East_Heretic.portrait_visible: portrait_visible and not portrait_visible
    East_Heretic.portrait_fail_layer: portrait_fail_layer == "" and portrait_fail_layer != ""
    East_Heretic.sprite_top: sprite_top >= 0.0 and sprite_top < 0.0
    West_Poison.portrait_visible: portrait_visible and not portrait_visible
    West_Poison.portrait_fail_layer: portrait_fail_layer == "" and portrait_fail_layer != ""
    West_Poison.sprite_top: sprite_top >= 0.0 and sprite_top < 0.0
    South_Emperor.portrait_visible: portrait_visible and not portrait_visible
    South_Emperor.portrait_fail_layer: portrait_fail_layer == "" and portrait_fail_layer != ""
    South_Emperor.sprite_top: sprite_top >= 0.0 and sprite_top < 0.0
    North_Beggar.portrait_visible: portrait_visible and not portrait_visible
    North_Beggar.portrait_fail_layer: portrait_fail_layer == "" and portrait_fail_layer != ""
    North_Beggar.sprite_top: sprite_top >= 0.0 and sprite_top < 0.0
    Central_Divine.portrait_visible: portrait_visible and not portrait_visible
    Central_Divine.portrait_fail_layer: portrait_fail_layer == "" and portrait_fail_layer != ""
    Central_Divine.sprite_top: sprite_top >= 0.0 and sprite_top < 0.0
```

Expected successful-run shape: `hard_passed=true`, 18 failing contradiction
asserts each printing its var's `observed`, `staged_files_applied` = exactly
`scripts/ui/visibility_probe.gd`, `scripts/characters/player.gd`,
`scripts/characters/enemy.gd`.

---

## Observed values (measured) — PENDING, run blocked by builder outage

| Surface var | A/B | f40 observed | portrait_fail_layer |
|---|---|---|---|
| `Player.portrait_visible` | **PENDING** | (not run) | (not run) |
| `Central_Divine.portrait_visible` | **PENDING** | (not run) | (not run) |
| `East_Heretic.portrait_visible` | **PENDING** | (not run) | (not run) |
| `West_Poison.portrait_visible` | **PENDING** | (not run) | (not run) |
| `South_Emperor.portrait_visible` | **PENDING** | (not run) | (not run) |
| `North_Beggar.portrait_visible` | **PENDING** | (not run) | (not run) |
| `Player.sprite_top` / `Central_Divine.sprite_top` (B-class guards) | **PENDING** | (not run) | — |

There are **no measured values** to record because the run could not execute.
This table must be filled from the printed `observed` of the probe above; every
`portrait_visible == false` unit must then also have its `portrait_fail_layer`
recorded (one of the six ids: `hidden_in_tree` / `null_texture` / `zero_rect` /
`off_viewport` / `clipped` / `occluded`).

---

## Derived vs observed

**The entire "derived" column below is UNMEASURED** — it combines the human
frame-reading that opened UX-01 with a code reading, and the probe has the
authority to overturn it (twice-precedented in this project). It is recorded so
that when the probe does run, any divergence is explicit.

| Fact | Derived (UNMEASURED: human frame reading + code reading) | Observed | Match |
|---|---|---|---|
| `Player.portrait_visible` | false (human: no portrait ink for 杨过) | (not run) | ? |
| `Central_Divine.portrait_visible` | false (human: no portrait ink for 王重阳) | (not run) | ? |
| `East_Heretic.portrait_visible` | true (renders) | (not run) | ? |
| `West_Poison.portrait_visible` | true (renders) | (not run) | ? |
| `South_Emperor.portrait_visible` | true (renders) | (not run) | ? |
| `North_Beggar.portrait_visible` | true (renders) | (not run) | ? |
| `Player.sprite_top` / `Central_Divine.sprite_top` | >= 0 (clamp keeps texture on board) | (not run) | ? |

**Code-reading note (why measurement matters):** `GridManager.clamp_sprite_offset`
(`scripts/autoload/grid_manager.gd` line 140) clamps the sprite origin so the
whole texture rect stays inside the board rect `[0, GRID_WIDTH*TILE_SIZE] ×
[0, GRID_HEIGHT*TILE_SIZE]` — which, at scale 1 with no camera offset, IS the
960x704 viewport rect. If that clamp is working, every portrait is on-frame and
layer 4 (`off_viewport`) cannot fail; the human "two units don't render"
reading could then be an artifact of how the frame was read, and UX-01 could
measure all-six-visible. That is exactly why this probe exists and why the
derived reading is not trusted. The `_refresh_sprite_clamp` / `clamp_sprite_offset`
suspicion from `step2_design.md` remains a **suspicion, not a conclusion** until
the probe prints a failing layer id for an actual invisible unit.

**Divergence handling to apply when the run lands (task card rules):**

1. Any unit expected invisible that measures `true` (or expected visible that
   measures `false`) → record the discrepancy here with the measured value.
2. Narrow UX-01 scope to ONLY units that measure `portrait_visible == false`.
   Do NOT fix a unit the probe says is already visible.
3. If ALL six measure `true` → UX-01 is **NOT CONFIRMED**: mark
   `design/40_ux_backlog.md` UX-01 `WONTFIX(实测六个单位均可见,人工读帧误判)`
   and skip the A2 fix task entirely. Do NOT fabricate a defect.

---

## Caveats / run notes

- **This step's run did not happen** (builder outage, 9/9 HTTP 500). The probe
  YAML above is the verbatim instrument, ready to execute unchanged the moment
  `godot-builder:8080` is reachable. The A2 task's first act is to run it and
  fill the "Observed values" table from the printed `observed` numbers.
- The staged-code parse risk that failed the previous attempt of this task
  (`Transform2D.xform` — a Godot 3 API, absent in 4.x) has been corrected:
  `leaf_rect()` now transforms the four local corners with the Godot 4 `*`
  operator (`xf * point`) and takes the AABB. No other parse-error class is
  known to remain in the three staged files; a headless import parse of
  `scripts/ui/visibility_probe.gd` was not available to re-confirm this step
  because the same builder outage blocked it.
- `staged_files_applied` expected exactly the three script files; the probe
  YAML is inline-only (per the SOTA rule: inline probes are CLI text, never
  written to the repo).
- f40 six-unit-alive assumption: the tutorial battle opens with all six units
  present (`click_targeting_fixed` has clicked `Central_Divine_ClickTarget` in
  the same tutorial battle), so no unit is dead at f40.
- No A/B class is claimed in this file because classification is defined as
  measured-only. Treat every derived cell above as unverified.

---

## A2 classification (task `ux01_fix_and_portrait_scenario`, appended by implementer)

**Fix set: EMPTY.**

Reason: the "Observed values (measured)" table above is still **PENDING** — the
probe run was blocked by the godot-builder outage (9/9 HTTP 500, recorded in the
run-status section) and no `observed` value for any of the six units'
`portrait_visible` / `portrait_fail_layer` ever landed. Per the task-card rules
("fix ONLY units measured `portrait_visible == false`; do NOT fabricate a defect;
a fix PR without probe evidence is rejected"), no speculative gameplay fix may be
written: there is no measured invisible unit, so no code point is justified.

**Decision recorded:**

- `scripts/autoload/grid_manager.gd`, `scripts/characters/player.gd`,
  `scripts/characters/enemy.gd` — **no change** (empty diff vs baseline).
  `_refresh_sprite_clamp` / `clamp_sprite_offset` are untouched (task-card rule:
  never touch the clamp without a measured `off_viewport`).
- B-class guards (units that would measure visible) are not asserted from derived
  values — they remain to be confirmed by the live run of `portrait_visibility.yaml`.

**Re-measurement instrument:** `playtest/portrait_visibility.yaml` (this round's new
scenario) asserts all six units' `portrait_visible == true` at f40. Its first green
run is the measured confirmation that UX-01 was a frame-reading artifact
(all-six-visible); its first red run prints the real `observed` fail_layer for the
genuinely broken unit(s), which then feeds a targeted per-layer fix (task-card §2
table) in a later round. Either way this decision stays re-openable from measured
data — probe-first discipline, not a conclusion.

(`design/40_ux_backlog.md` WONTFIX/CLOSED marking is deferred to the 5_design step
per P2 §7 — implementers do not edit `design/`.)

---

# Post-fix re-probe (task `fix_final_regression`, appended)

## 1. Pre-fix contradiction recap (dead probe, NOT "all invisible")

The 5_compile run that opened the final regression printed **all six**
`portrait_visible == false` while every `portrait_fail_layer` stayed `""` — the
forbidden `false/""` combination (consistency invariant row 3 below). It also
logged, thousands of times:

- `Parse Error: Could not find type "Canvas" in the current scope.`
  (`scripts/ui/visibility_probe.gd:183`)
- `Invalid call. Nonexistent function 'first_fail_layer' in base 'GDScript'.`
  (`scripts/characters/player.gd:346`, `scripts/characters/enemy.gd:240`)
- `Compile Error: Failed to compile depended scripts.` (player.gd / enemy.gd)

`first_fail_layer` never ran, so `portrait_visible` sat at its declared `false`
default. That baseline "all six invisible" reading is a **dead-probe artifact**,
not measured evidence of invisibility. It also aborted `player.gd._process()`
*before* the `undo_available` recompute, which is why the protected click-move
scenarios showed `undo_available == false` (9/10) in that same run.

## 2. Compile-fix static verification (read-backed facts)

- `scripts/ui/visibility_probe.gd` — **no `Canvas` type anywhere** (the parse
  error is gone). Layer-6 occlusion / draw-order helpers reference only
  `CanvasLayer`, `CanvasItem`, `Control`, `Sprite2D`; `_canvas_layer()` (line 182)
  walks the ancestor chain with `node is CanvasLayer` (the exact line that used
  to say `Canvas`), `_effective_z()` (line 192) and `_tree_index()` (line 204)
  are the other layer-6 primitives.
- `scripts/characters/player.gd` `_process()` (line 346):
  `portrait_fail_layer = VisibilityProbe.first_fail_layer(self)`, then line 347:
  `portrait_visible = portrait_fail_layer == ""` — placed **before** the
  `undo_available` recompute (line 353), so the probe and the undo logic both run.
- `scripts/characters/enemy.gd` `_process()` (line 240–241): the same two lines
  immediately after `_refresh_sprite_clamp()`.

## 3. Consistency invariant (dead-probe rule)

| `portrait_visible` | `portrait_fail_layer` | verdict |
|---|---|---|
| true | "" | probe alive, all six visible → UX-01 `WONTFIX(实测六个单位均可见,人工读帧误判)` |
| false | non-empty id | probe alive, real defect → UX-01 `CLOSED(jinyong-affordance)`; the id is the real cause |
| false | "" | CONTRADICTION — probe still dead; do NOT proceed |

The pre-fix baseline sat on **row 3**. Whether the post-fix re-probe lands on
row 1 (`true`/`""` → WONTFIX) or row 2 (`false`/non-empty id → CLOSED) is decided
by the 5_compile gate run of this round — the observed cells below are filled from
that run, never from assumption.

## 4. Observed values — FILLED BY THE 5_COMPILE GATE RUN OF THIS ROUND (not yet measured)

Re-measurement instrument: `playtest/portrait_visibility.yaml` f40 (this round's
new scenario: integer-only `at` values, `name:` == basename, 10 asserts
byte-identical to the committed content), plus the inline contradiction probe
recorded in the "Probe method" section above. **No post-fix runtime report is
in-repo at implementation time** — the implementer has no shell/network and
cannot run the godot-builder sidecar — so the `observed` cells below carry the
task-mandated placeholder and are filled by the 5_compile gate run of this round.

**Expected-evidence mapping** (what the gate run's report means):

- `portrait_visibility.yaml` green (all 10 asserts) ⇒ every unit's
  `portrait_visible == true` and `portrait_fail_layer == ""` at f40 ⇒ the
  `true/""` invariant row 1 ⇒ probe class ALIVE, all six portraits on-frame.
- Any unit's `portrait_visible` red with a non-empty `portrait_fail_layer` ⇒
  invariant row 2 ⇒ that unit is genuinely invisible and the fail-layer id is the
  real cause.
- A `portrait_fail_layer` red while `portrait_visible` is red (observed
  `false`/`""`) ⇒ invariant row 3 ⇒ the probe class is STILL dead and the round
  must not proceed.

| Unit | `portrait_visible` (observed) | `portrait_fail_layer` (observed) |
|---|---|---|
| `Player` | filled by the 5_compile gate run of this round | filled by the 5_compile gate run of this round |
| `East_Heretic` | filled by the 5_compile gate run of this round | filled by the 5_compile gate run of this round |
| `West_Poison` | filled by the 5_compile gate run of this round | filled by the 5_compile gate run of this round |
| `South_Emperor` | filled by the 5_compile gate run of this round | filled by the 5_compile gate run of this round |
| `North_Beggar` | filled by the 5_compile gate run of this round | filled by the 5_compile gate run of this round |
| `Central_Divine` | filled by the 5_compile gate run of this round | filled by the 5_compile gate run of this round |

Do not read these placeholder cells as measurements. The pre-fix "all six false"
reading is recorded as the dead-probe contradiction (section 1), NOT as evidence
of invisibility; only the 5_compile gate run of this round can distinguish
"probe alive, all visible" (`true`/`""`) from "probe still dead" (`false`/`""`).

## 5. UX-01 disposition (conditional — pending the 5_compile gate run)

The disposition is a FUNCTION of the observed row the gate run lands in; it is
**not yet decided** and no measured value is claimed here:

- **If the 5_compile gate run confirms all six units `true`/`""`** (the
  `portrait_visibility.yaml` scenario green) → UX-01 **will be**
  `WONTFIX(实测六个单位均可见,人工读帧误判)`: the original UX-01 report
  ("王重阳 and 杨过 render no portrait ink") was a human frame-reading artifact,
  and the baseline's "all invisible" numbers came from the dead probe class, not
  from any real defect. No gameplay fix is warranted and none was made.
- **If any unit measures `false`/non-empty fail-layer id** → UX-01 **will be**
  `CLOSED(jinyong-affordance)` with that id as the real cause; the targeted
  per-layer fix is deferred to a later round (per the task-card §2 table).
- **If any unit measures `false`/`""`** → probe still dead; do NOT proceed.

This notes file is the evidence record `fix_readme_round_state` Step 3 consumes
when it applies the final WONTFIX/CLOSED marking in `design/40_ux_backlog.md`
(per P2 §7 implementers do not edit `design/`; the marking is applied once the
gate run's measured values land).

## 6. UX-02 clicks-spec correction (rationale kept; PASS claims NOT implementer-run)

`playtest/move_target_affordance.yaml` at wiring time **HARD-failed** on the
spec: the f135 undo click was `Player +0,0 right` — a right-click on the player's
OWN tile, which the protected `click_move_undo_right.yaml` documents as "a benign
no-op". The undo never fires (player stays at (7,2)); the f175 `Player +0,-192`
click then anchors at (7,2) → point `(480.0, -32.0)` **outside the 960×704
viewport** → harness `push_error` → hard gate red. Correction (**clicks spec only
— no assertion value changed; all 18 asserts byte-identical**): f135
`Player +0,0 right` → `Player +64,0 right`, the exact proven undo click from
`click_move_undo_right`, so the undo lands on the tile right of the player.

Whether the corrected spec then passes (18/18) and whether the protected
`click_move_undo_right` / `click_move_to_tile` scenarios return to 10/10 is
decided by the 5_compile gate run of this round — **no run numbers are claimed
by the implementer here** (no godot-builder access). Expected-evidence mapping:
`move_target_affordance.yaml` green ⇒ the state transitions idle → undo_ready →
idle → undo_ready → committed all hold with zero runtime errors; the protected
click-move scenarios green ⇒ the pre-fix 9/10 `undo_available` failures (the same
dead-probe `_process` abort, section 1) are gone.

## 7. Downstream gate mapping (not run by the implementer)

The implementer has no shell/network, so the full 46-scenario playtest hard gate
and the vision gate execute at the pipeline's 5_compile / 5_test / 5_vision
steps. **No gate result is claimed in this file** — what this round's artifacts
contribute:

- `tests/test_playtest_contract_smoke.py` gains the static guard
  `test_timeline_at_values_are_integers`, asserting every timeline `at:` in all 8
  `ROUND_SCENARIOS` files is a single integer at pytest time (stdlib-only regex
  parse — no YAML parser, no network).
- `playtest/portrait_visibility.yaml` and `playtest/move_target_affordance.yaml`
  are syntax-clean: all `at` values single integers, `name:` == basename, all
  asserts byte-identical to the committed content (10 and 18 respectively).
- `playtest/_common.yaml` surface/order wiring (six units × `portrait_visible` /
  `portrait_fail_layer`, the `MoveHintLabel` block, `scenario_order` appending
  both new scenarios) is verified by the static smoke tests.

Expected outcome once the gates run (to be confirmed by the gate runs, NOT
measured here): 46 scenarios total, 45 green — the 43 baseline-green scenarios
(incl. the five protected click-move scenarios) plus `portrait_visibility` and
`move_target_affordance` — with `terminal_victory_8_12_rounds_hp_15_40`
remaining the **only** allowed red (deliberate balance-target red). The vision
gate's Q5 ("health bars recognisable") is expected to pass (good ≥ 22/28) per
`fix_vision_gate_health_bar_q5`, with Q1/Q2/Q6 expected green and Q3/Q4
expected to recover once the dead battle loop from the compile error is gone.
