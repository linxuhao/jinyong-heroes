# Gate Run Notes — jinyong-loop R2 (full gate-run record)

**Date:** 2026-09-01
**Task:** `gate_sync_and_full_run` — consolidated verification of the round.

## Consolidated run status

- **Hard gate passed flag:** `pending host gate run` — the single 84-scenario
  consolidated harness run is a host-gated `5_compile` artifact; this step has no
  shell. Every per-scenario PASS count below is attributed to the five fix tasks' own
  measured `godot_playtest_scenario` sidecar runs (copied verbatim from their notes),
  never presented as the consolidated 84/84 single-run verdict.
- **Runtime errors:** zero across every listed measured run (each fix note records its
  sidecar runs hard-gate passed with zero runtime errors).
- **GDScript unit suite / pytest guards:** the official verdict (`test_report.json`) is a
  `5_test` artifact — `pending host gate run`. **A read-audit of the pytest contract smoke
  suite surfaces one conflict (see `final/delivery_notes_loop.md` §7):**
  `test_softlock_nail_contract` asserts `"debug_fast_forward" not in ftext` over the whole
  softlock scenario file, but that file's header comments legitimately quote the literal
  string. The guard reddens on the scenario it was written to protect unless one of the two
  candidate resolutions in §7 is ratified by the driver. Not edited here (red line).

## Per-scenario measured PASS counts (source = the fix notes' sidecar runs)

| Scenario | PASS | Source note |
|---|---|---|
| `softlock_empty_practice_month_advances` (new) | 15/15 | delivery_notes_loop_softlock.md §5 |
| `gongfa_pick_empty_keyboard_return` (re-pointed) | 15/15 | delivery_notes_loop_softlock.md §5 |
| `clicks_only_gongfa_empty_exit` (re-pointed) | 18/18 | delivery_notes_loop_softlock.md §5 |
| `facility_use_cap_exhausted_zero_delta` (new) | 33/33 | delivery_notes_loop_facility.md §5 |
| `facility_use_reusable` (gate a) | 49/49 | delivery_notes_loop_facility.md §5 |
| `map_facility_buttons_click` | 38/38 | delivery_notes_loop_facility.md §5 |
| `spine_to_ending` | 42/42 | delivery_notes_loop_facility.md & resettle.md §5 |
| `save_load_roundtrip` | 14/14 | delivery_notes_loop_facility.md & resettle.md §5 |
| `map_node_event_revisit_no_resettle` (new) | 33/33 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_shaolin` (gate b) | 32/32 | delivery_notes_loop_resettle.md §5 |
| `map_battle_node_huashan` (gate b) | 41/41 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_mainline_east` | 23/23 | delivery_notes_loop_resettle.md §5 |
| `map_node_event_mainline_return` | 20/20 | delivery_notes_loop_resettle.md §5 |
| `event_travel_effects` | 19/19 | delivery_notes_loop_resettle.md §5 |
| `occlusion_no_button_over_text` (new) | GREEN f158/f345/f425 (`violations == 0`) | delivery_notes_loop_occlusion_watch.md §4 |

## Spine proofs & pinned gates of note

- **`spine_to_ending` 42/42** — the full keyboard spine (menu → creation → tutorial →
  cultivation 36 months → map → ending) still runs end-to-end; the soft-lock fix does
  not disturb it.
- **`clicks_only_storyline`** — not measured in this round's fix notes (count carried
  from the theme round's 47/47 as historical context); the consolidated run will
  re-confirm it. Not attributed as a measured number this round.
- **`cultivation_month_cycle_and_deck_bookkeeping` (17/17)** and
  **`cultivation_changes_combat` (30/30)** — touched by cultivation.gd; the fix notes
  measured `event_travel_effects` 19/19 and `save_load_roundtrip` 14/14 (the RNG-op-order
  lifelines) as the regression proxies; these two are listed for the consolidated run.
- **`equipment_in_battle_diff` (47/47)** and **`event_pool_new_event_resolved` (15/15)**
  — existing gates unaffected by this round; re-confirmed by the consolidated run.
- **`theme_focus_marker_cultivation` (14/14)** — the theme-round focus marker; the
  soft-lock fix does not touch the `:582-646` stylebox-swap portion, so this stays green
  (consolidated run confirms).

## Pending / not-executed lines

- **Single consolidated 84-scenario run (79 existing + 5 new) PASS flag:**
  `pending host gate run`.
- **Official pytest + GDScript unit suite `test_report.json`:** `pending host gate run`
  (this step ran no pytest subprocess).
- **Theme-round `git log` merge check:** `not executed + reason: no shell in this step`
  (in-tree `ThemeManager.option_style` consumption confirms the merge; see
  `delivery_notes_loop.md` §5).
- **Official frame product (before/after pixel verdicts):** deferred to the downstream
  `5_vision` product; the structural watch asserts `violations == 0` and is the machine
  gate in the interim.

## Zero-error claim

Every listed measured run is recorded by its fix note as hard-gate passed with zero
runtime errors. No runtime error was observed in any listed sidecar run.
