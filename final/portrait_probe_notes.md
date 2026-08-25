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
