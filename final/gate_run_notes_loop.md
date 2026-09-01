# Gate Run Notes — jinyong-loop R2 (repaired-tree gate-run record)

**Date:** 2026-09-01
**Task:** `fix_loop_round_gate_rerun` — consolidated re-verification of the round on the
repaired tree, run LAST after the three fix tasks landed
(`fix_occlusion_watch_crashproof`, `fix_purchase_nail_scene_boot`,
`fix_nail_contract_guards`). This record supersedes (i) the pre-fix round's
pending-host record that previously occupied this file, and (ii) the CRASHED
`5_compile` run (44,660 runtime errors, `passed: False`) — the latter is marked
SUPERSEDED in `final/delivery_notes_loop.md` (R2-fix section); NO number from it
is presented as this round's verdict.

## Consolidated run status

- **Hard gate passed flag:** `pending host gate run (5_compile)` — the single
  84-scenario consolidated harness run is a host-gated `5_compile` artifact; this
  step has no shell. The `step:5_compile` product in context is still the CRASHED
  run (SUPERSEDED) — no number from it is spliced in. Every per-scenario PASS
  count below is attributed to the fix tasks' own measured
  `godot_playtest_scenario` sidecar runs (copied verbatim from their notes), never
  presented as the consolidated 84/84 single-run verdict.
- **Runtime errors:** zero across every listed measured run (each fix note records
  its sidecar runs hard-gate passed with zero runtime errors). The 44,660-error
  crash (the `canvas_layer`-on-Control access in `ui_occlusion_watch.gd`) is fixed
  in-tree (null-guarded nearest-CanvasLayer-ancestor walk; read-audit shows only
  guarded typed accesses); the consolidated run's runtime-error count is
  `pending host gate run (5_compile)`.
- **pytest contract smoke + GDScript unit suites:** the official verdict
  (`test_report.json`) is a `5_test` artifact — `pending host gate run (5_test)`.
  **Read-audit confirms the guard-conflict the pre-fix record flagged is RESOLVED
  (ruling APPLIED, see `final/delivery_notes_loop.md` §(c)):**
  `test_softlock_nail_contract`'s whole-file `"debug_fast_forward" not in ftext`
  ban was re-scoped to the TIMELINE's actions (parsed via `yaml.safe_load`) — the
  scenario's documentation prose legitimately quotes the literal, and the timeline
  executes zero `debug_fast_forward` actions. The three index guards
  (`test_facility_use_cap_nail_contract`,
  `test_map_node_event_revisit_no_resettle_nail_contract`,
  `test_occlusion_watch_surface_contract`) were repaired from an unsatisfiable
  absolute-index equality to the relative-order sync comparison
  `[n for n in order_names if n in ROUND_SCENARIOS] == ROUND_SCENARIOS`.
  `test_occlusion_watch_surface_contract`'s pin is extended over
  `violations / violations_text / scan_ok / scan_failed_frames`. Read-verifiable
  static count: 56 tests in `tests/test_playtest_contract_smoke.py`; the four
  repaired guards + the extended occlusion pin are present (verified by read). The
  official 56/56 PASS is `pending host gate run (5_test)` — not claimed as measured.

## Per-scenario measured PASS counts (source = the fix notes' sidecar runs)

| Scenario | PASS | Source note |
|---|---|---|
| `softlock_empty_practice_month_advances` (new) | 15/15 | delivery_notes_loop_softlock.md §5 |
| `gongfa_pick_empty_keyboard_return` (re-pointed) | 15/15 | delivery_notes_loop_softlock.md §5 |
| `clicks_only_gongfa_empty_exit` (re-pointed) | 18/18 | delivery_notes_loop_softlock.md §5 |
| `facility_use_cap_exhausted_zero_delta` (new) | 33/33 | delivery_notes_loop_facility.md §5 |
| `facility_use_reusable` (gate a, verbatim-protected) | 49/49 | delivery_notes_loop_facility.md §5 |
| `map_facility_buttons_click` | 38/38 | delivery_notes_loop_facility.md §5 |
| `spine_to_ending` | 42/42 | delivery_notes_loop_facility.md & resettle.md §5 |
| `save_load_roundtrip` (RNG-op-order lifeline) | 14/14 | delivery_notes_loop_facility.md & resettle.md §5 |
| `map_node_event_revisit_no_resettle` (new) | 33/33 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_shaolin` (gate b, verbatim-protected) | 32/32 | delivery_notes_loop_resettle.md §5 |
| `map_battle_node_huashan` (gate b, verbatim-protected) | 41/41 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_mainline_east` | 23/23 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_mainline_return` | 20/20 | delivery_notes_loop_resettle.md §5 |
| `event_travel_effects` (RNG-op-order lifeline) | 19/19 | delivery_notes_loop_resettle.md §5 |
| `event_option_refused_no_charge` (new, re-booted) | 11/11 | delivery_notes_loop_purchase.md §3 (8/11 red on corrected code → 11/11 green) |
| `occlusion_no_button_over_text` (new) | GREEN f158/f345/f425 (`violations == 0` + `scan_ok == true`) | delivery_notes_loop_occlusion_watch.md §4 |

## Spine proofs & pinned gates of note

- **Three verbatim-protected gates, by name, required green (byte-untouched):**
  `facility_use_reusable` **49/49** (gate (a) — "leave-and-return still allows
  another use"; the per-month cap of 2 allows both uses in month 36),
  `map_node_event_shaolin` **32/32** (gate (b) — the 1→2→3
  `events_resolved_count` re-fire ladder), `map_battle_node_huashan` **41/41**
  (gate (b) — Leg F `events_resolved_count == 3` after the re-fired `night_rain`).
  No round task's file table lists them; read-audit confirms their pinned lines.
  **If ANY of them reds in the consolidated run: STOP and surface to the driver
  with the failing frame and assert — NEVER edit the protected yaml to force
  green.**
- **RNG-op-order lifelines:** `save_load_roundtrip` **14/14** and
  `event_travel_effects` **19/19** — this round's validation and suppression logic
  add zero RNG draws, so the deterministic-stream lifelines hold; both measured
  green by the fix notes.
- **`spine_to_ending` 42/42** — the full keyboard spine (menu → creation →
  tutorial → cultivation 36 months → map → ending) still runs end-to-end; the
  soft-lock fix does not disturb it.
- **`event_option_refused_no_charge` 11/11** — re-booted from the wrong
  `menu.tscn` boot (0/11 in the CRASHED run, stranded in TUTORIAL at f400) to the
  contract-default `main.tscn`; frames re-baselined, the zero-delta
  `silver == event_open_silver` leg green.
- **Consolidated-run-only attention list (NOT measured in any fix note — do not
  attribute stale numbers; the single consolidated run is the only authority):**
  `clicks_only_storyline`, `cultivation_month_cycle_and_deck_bookkeeping`,
  `cultivation_changes_combat`, `equipment_in_battle_diff`,
  `event_pool_new_event_resolved`.

## Pending / not-executed lines

- **Single consolidated 84-scenario run (79 existing + 5 new) PASS flag +
  runtime-error count:** `pending host gate run (5_compile)` — the `step:5_compile`
  product in context is the CRASHED run (SUPERSEDED); no number from it is used.
- **Official compile `compile_report.json` (99 scripts):** `pending host gate run
  (5_compile)`. Read-verifiable: `scripts/**/*.gd` = **99** (98 pre-round +
  `scripts/autoload/ui_occlusion_watch.gd`); the crash-proofed watch introduces no
  parse error; `UiOcclusionWatch` stays in `[autoload]`, `SceneManager` still LAST.
- **Official pytest + GDScript unit suite `test_report.json`** (56/56 pytest;
  GDScript suite incl. `test_map_node_event.gd` cost-gate block — the zero-mutation
  refusal pins, ~:562-577 — + `test_facility_data.gd` raw effect path; the
  zero-delta refusal behavior is also pinned by the three playtest nails
  `event_option_refused_no_charge`, `facility_use_cap_exhausted_zero_delta`,
  `map_node_event_revisit_no_resettle`): `pending host gate run (5_test)` (this
  step ran no test subprocess; the read-audit above confirms the guards are
  present and repaired).
- **Theme-round `git log` merge check:** `not executed + reason: no shell in this
  step` (in-tree `ThemeManager.option_style` consumption at
  `cultivation.gd`/`sect_select.gd` confirms the merge; see the R2-fix audit in
  `final/delivery_notes_loop.md`).
- **Official frame product (before/after pixel verdicts) + vision Q1–Q6:**
  `blind / endpoint_unreachable` — no vision product is present in this step's
  context; no Q6 count is invented. The seven before/after same-frame occlusion
  pairs (5 sect + tutorial + roster) remain recorded in
  `final/delivery_notes_loop.md`; the structural watch (`violations == 0` +
  `scan_ok == true`) is the machine gate in the interim.

## Zero-error + zero-revert claims (read-backed)

- **Zero runtime errors in every listed sidecar run:** each fix note records its
  runs hard-gate passed with zero runtime errors. The consolidated run's
  runtime-error count is `pending host gate run (5_compile)`; the crash root cause
  is fixed in-tree.
- **Zero `TEMPORARY RED-FIRST REVERT` residue:** `search` for the literal across
  `scripts/**` (and `playtest/**` working code) returns **zero hits** — every fix
  note's temporary revert was restored byte-identically; the marker appears only in
  historical delivery notes / scenario headers that legitimately quote the revert
  recipe. `repo_apply` is `git add -A`, so no residue may remain.
