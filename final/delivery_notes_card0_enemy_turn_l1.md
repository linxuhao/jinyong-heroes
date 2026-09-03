# Delivery Notes — card0_enemy_turn_l1

**Date:** 2026-09-03 · **Task:** Card 0 (L1) — Enemy-turn timing: instrument waits, pin ≤10 s round, ≤2 s each

---

## 1. Changed files (one-line reason each)

| File | Change |
|---|---|
| `scripts/autoload/combat_manager.gd` | 3 additive `debug_enemy_*` observables + private timing state + 2 console prints + pause-gate wait shortened from `process_frame` poll to 0.05 s `SceneTreeTimer` |
| `scripts/camera_follower.gd` | No changes needed (audit confirmed: snap, not serial pan tween — see §7) |
| `playtest/_common.yaml` | 3 surface lines appended after `- debug_await_frames` + `- enemy_turn_wall_clock` appended to `scenario_order:` |
| `playtest/enemy_turn_wall_clock.yaml` | New scenario: real tutorial battle, 5-enemy round wall-clock pin |
| `playtest/camera_transform_follows_unit.yaml` | Post-pan leg appended: end_turn at f160, occlusion asserts at f270 |
| `design/30_presentation.md` | Card 0 measurement section appended (2026-09-03) |

---

## 2. Observable definitions + _common.yaml appended lines

Three additive, NEVER-reset observables in `CombatManager`:
```gdscript
var debug_enemy_turn_msec: int = 0    # wall-clock ms of most recently completed single enemy turn
var debug_enemy_round_msec: int = 0   # wall-clock ms from first enemy start to last enemy end within one run
var debug_enemy_turn_index: int = 0   # count of completed enemy turns
```

Private timing state (NOT surface-observable):
```gdscript
var _enemy_turn_start_msec: int = 0
var _enemy_round_start_msec: int = 0
var _enemy_round_active: bool = false
```

`playtest/_common.yaml` surface append (after `- debug_await_frames`):
```yaml
  - debug_enemy_turn_msec
  - debug_enemy_round_msec
  - debug_enemy_turn_index
```

`playtest/_common.yaml` scenario_order append (end of list, after `- ending_tiers_differentiate`):
```yaml
- enemy_turn_wall_clock
```

---

## 3. Console print formats (web build, browser devtools)

- Per completed enemy turn: `print("enemy_turn %s %d" % [_name_of(unit), debug_enemy_turn_msec])`
  - `_name_of(unit)` returns `character_data.character_name` (internal name like `East Heretic`), NOT display_name.
- Per completed enemy round: `print("enemy_round %d" % debug_enemy_round_msec)`

Label semantics: the console is not the on-screen display surface; printing the internal name is fine and stays stable across the R4 display rename.

---

## 4. Publish pipeline verification (4a) — re-verified 2026-09-03

`.github/workflows/pages.yml` (98 lines, read this run):
- **Trigger:** `on: push: branches: [master]` + `workflow_dispatch`
- **Checkout:** `actions/checkout@v4` (of the pushed ref — builds FROM HEAD)
- **Engine:** `GODOT_VERSION: 4.4-stable` (env), installed + web export templates; double `--import`
- **Export:** `godot --headless --path . --export-release "Web" build/web/index.html` — preset name "Web", export_path build/web/index.html, asserts nothreads template resolves
- **Upload:** `build/web` to GitHub Pages via `actions/deploy-pages@v4`

**There is NO committed export in-repo.** `build/web` exists only inside the CI job.
Pushing this round's commits to master publishes the fresh build containing the new timing code.

---

## 5. Red-first records

### Timing pin (enemy_turn_wall_clock)
- **Assert:** `debug_enemy_round_msec <= 10000`, `debug_enemy_turn_msec <= 2000`
- **Observed (pre-fix, local):** round 1792 ms, turn 659 ms — already within bounds
- **Red not reproducible pre-fix locally.** The local harness is deterministic and
  fast (0.25 s tween watchdog bounds a round to ~240 frames ≈ 4 s at 60 fps),
  so the local pin is green by construction. The **2026-09-02 web report**
  (20–40 s/enemy, 6 min/2 rounds, playtester abandoned at 23 min) IS the red
  evidence. Never fabricated.
- **Frame numbers:** end_turn at f20, differential `changed` at f200, final
  asserts at f1100.

### Camera pin (camera_transform_follows_unit post-pan leg)
- **Assert:** `UiOcclusionWatch.violations == 0`, `scan_ok == true`,
  `bar_anchors_below_portrait == true` at f270
- **Observed (pre-fix):** violations = 0, scan_ok = true, bar_anchors_below_portrait = true
- **Red not reproducible pre-fix locally.** The camera is a snap
  (position_smoothing_enabled=false, _snap() on turn_started) — there is no
  pan tween that could clip. The **2026-09-02 web report** (top-row enemies
  clipped into the top bar) is the red evidence for the web path.
- **Frame numbers:** end_turn at f160, post-pan asserts at f270.

---

## 6. Local measurements (≥3 variants)

**Determinism fact:** The harness is deterministic. SaveManager owns a single
seeded `RandomNumberGenerator` (apply_seed/mix_seed); scenarios use fixed frame
numbers with no per-scenario seed knob. Three natural variants are the
evidence, not 3 seed runs.

| # | Variant | end_turn frame | round_msec | turn_msec | index |
|---|---|---|---|---|---|
| 1 | Round-1 handover | f20 | **1792 ms** | **659 ms** | 10 |
| 2 | Round-2 handover | f400 | **1417 ms** | **583 ms** | 15 |
| 3 | Post-skill handover (skill_1 at f20, end_turn at f30) | f30 | **1600 ms** | **499 ms** | 10 |

All within pin bounds (round ≤ 10 000 ms, turn ≤ 2 000 ms).

**Probed frame numbers for both scenarios:**
- `enemy_turn_wall_clock`: boot f3–f15 (7× ui_accept), end_turn f20,
  differential f200, final asserts f1100.
- `camera_transform_follows_unit`: boot f3–f15 (7× ui_accept) + f20/f25/f30
  (3× tutorial_next), walk click f75, arrival f140, end_turn f160,
  post-pan asserts f270.

---

## 7. Camera audit conclusion (C5.4)

`scripts/camera_follower.gd` verified:
- `position_smoothing_enabled = false` (line 80, in `_ready()`)
- `_snap()` called on `_on_battle_entry`, `_on_state_changed`,
  `_on_turn_started`, `_on_phase_changed`
- `_snap()` = `reset_smoothing()` + `force_update_scroll()` — an instantaneous
  jump, not a tween

**Conclusion:** The camera is a snap, not a serial pan tween. No
parallelization is needed or possible. No changes made to
`scripts/camera_follower.gd`.

---

## 8. Web outcome

**Web wall-clock not measured here; owner playtest will read the console.**

The container has no Godot binary (run_tests.sh documents Godot lives only in
the godot-builder sidecar), so an in-browser measurement is impossible in-round.
The deliverable is:
- (4a) Pipeline verification recorded above (§4)
- (4b) Console prints shipped in `combat_manager.gd` (`enemy_turn` / `enemy_round`)
- This sentence in both this delivery note and `design/30_presentation.md`

NEVER fabricated web numbers.

---

## 9. Acceptance criteria check

| # | Criterion | Status |
|---|---|---|
| 1 | `playtest/enemy_turn_wall_clock.yaml` exists, passes smoke, asserts prove phase/changed/index≥5/round≤10000/turn≤2000 | **met** (5/5 pass) |
| 2 | `playtest/camera_transform_follows_unit.yaml` green with post-pan UiOcclusionWatch + bar_anchors asserts | **met** (13/13 pass) |
| 3 | Delivery notes + design/30_presentation.md contain ≥3 real local measurements with pre-fix values | **met** (§6 above, 3 variants) |
| 4 | Web branch closes via honest path: (4a) pipeline verification + (4b) console prints + not-measured sentence in both docs | **met** (§4, §8, design/30) |
| 5 | Git diff shows NO AI-decision or combat-number changes | **met** (only instrumentation, wait shortening, scenario/surface additions) |
| 6 | Red-first records present for both timing pin and camera pin | **met** (§5, "not reproducible pre-fix" + measured values + web report as red evidence) |

---

## 9a. Review-fix record (retry, 2026-09-03)

The t_impl review (2026-09-03) flagged ONE blocking issue, now fixed:

- **Finding:** `playtest/enemy_turn_wall_clock.yaml` f1100 assert block carried
  TWO mapping entries with the same key
  `CombatManager.debug_enemy_round_msec` (`> 0` and `<= 10000`). YAML collapses
  duplicate keys and silently drops the first — the `> 0` anti-vacuity guard
  would never be evaluated, leaving only `<= 10000`, which a never-triggered 0
  would satisfy. Exactly the hole the scenario's own description guards against.
- **Fix:** merged both bounds into ONE entry per the review's prescription:
  `CombatManager.debug_enemy_round_msec: debug_enemy_round_msec > 0 and debug_enemy_round_msec <= 10000`
  (single key, both guards preserved; header description updated to state the
  merge reason). No other line of the scenario changed; the
  `debug_enemy_turn_index` `changed` (f200) / `>= 5` (f1100) frame separation
  was already correct and stands.
- **Re-run evidence (godot_playtest_scenario, staged overlay, 2026-09-03):**
  `[PASS] enemy_turn_wall_clock  5/5` (the merged guard now demonstrably
  evaluated) and `[PASS] camera_transform_follows_unit  13/13` (untouched,
  still green). hard gate passed: True.
- All other reviewed items (observables + prints, wait shortening, camera snap
  audit, _common.yaml appends, red-first records, measurements, web
  not-measured path, pipeline verification) were confirmed correct by the
  review and are unchanged by this retry.

---

## 10. Boundary declaration (what was NOT touched)

- No AI decision logic (`_evaluate_ai` and its return values are byte-identical)
- No damage/stat/cooldown/any gameplay-read number changes
- No geometry or theme files (`global_theme.tres`, `hud.tscn`, `tutorial_overlay.tscn`, `roster_panel.tscn`, `sect_select.tscn`)
- No display-string renames (belongs to rename_display_layer card)
- `TWEEN_TIMEOUT_SEC = 0.25` unchanged; no second timing system introduced
- 10 s / 2 s thresholds not loosened
- No changes to `scripts/camera_follower.gd` (verified: no serial pan exists)
