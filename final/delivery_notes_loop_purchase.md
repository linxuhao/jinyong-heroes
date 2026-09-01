# Delivery Notes — fix_purchase_nail_scene_boot (jinyong-loop R2, D4)

> Date: 2026-09-01
> Task: fix the purchase nail's wrong boot scene, redo its red-first under the corrected boot.
> Scope: `playtest/event_option_refused_no_charge.yaml` + `final/delivery_notes_loop_purchase.md`.
> `scripts/data/event_logic.gd`: temporary revert measured then restored byte-identically (zero residue).

## 1. The mis-boot root cause (official 5_compile run, 2026-09-01)

`playtest/event_option_refused_no_charge.yaml` measured **0/11** in the official run — the only
scenario in the whole 84-scenario run with genuinely failing assertions. Measured failures:

- at f400 `GameManager.current_state` observed **TUTORIAL** (expected MAP);
- every MapScreen assert failed with `node not found: MapScreen`.

**Root cause:** the file carried a `scene: res://scenes/menu.tscn` override (line 69) while its
timeline was copied verbatim from the facility-cap nail's proven boot (7 tutorial-intro ui_accepts
at f3..f15 → `debug_win_tutorial` at f20 → WON overlay continue → transition accepts → sect pick →
cultivation → `debug_grant_equip` → `debug_fast_forward` → MAP) — a boot authored for the
CONTRACT-DEFAULT `main.tscn`. `facility_use_cap_exhausted_zero_delta.yaml` has NO `scene:` line
(it inherits `scene: res://scenes/main.tscn` from `playtest/_common.yaml`) and its assertions all
passed in the same official run (33/33). Booting `menu.tscn` instead desynchronized the entire
timeline (the ui_accepts walked the menu/creation screens instead of the tutorial intro pages) and
the run stranded in TUTORIAL forever.

## 2. Fix actions applied

1. **Deleted** the `scene: res://scenes/menu.tscn` line — the file now inherits the contract
   default `res://scenes/main.tscn`, exactly like the green facility nail whose boot it mirrors.
   The timeline is byte-identical to that proven boot up to f220; the only insertions are
   `debug_grant_equip` at f260 (between the facility boot's f220 accept and its f280
   `debug_fast_forward`) — kept.
2. **Corrected** the description prose: "Boots menu.tscn" → "Boots the contract-default main.tscn"
   (a copy fix in a non-protected scenario file, not a game-UI copy change).
3. **Filled the red-first block** with MEASURED four values from a real red run under the corrected
   boot (see §3) — no placeholders, no data spliced from the old mis-booted run.
4. **Frames re-baselined** from the measured green run: the corrected main.tscn boot reaches MAP at
   f400 exactly as the facility nail does, so the existing `at:` frames (f400/f440/f470) needed no
   change — verified by the 11/11 green run.
5. **No `debug_grant_silver` funding added** — the measured green run's receipt is the OWNED
   wording (此物已在行囊，无须再购), not 银两不足 (see §4).

## 3. Red-first redo — MEASURED four values (corrected boot)

The official 0/11 red was measured for the WRONG reason (the scene mismatch), not the owned-refusal
revert. With the boot fixed, the documented TEMPORARY RED-FIRST REVERT was applied to
`scripts/data/event_logic.gd` and the CORRECTED scenario was run via the direct
`godot_playtest_scenario` sidecar.

**Revert applied (both functions, marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`):**
- `validate_option()` → `return ""` unconditionally (so map.gd's `_resolve_node_event` REFUSED
  path never fires and the APPLIED path runs);
- `apply_option_effects()` → the old unconditional-charge shape (silver applies regardless with the
  `maxi(..., 0)` clamp, item appends only when absent, no refusal receipt).

**Measured red run (corrected boot, revert applied):** `event_option_refused_no_charge` **8/11**.

| # | Value | Measured |
|---|---|---|
| failing_frame | 470 | first failing assert at f470 |
| first_failing_assert | `MapScreen.last_effect_types` — `last_effect_types.is_empty() == true` | observed `["silver", "item"]` (effects applied, not refused) |
| exact_error/observed | at f470, three asserts red | `last_effect_types.is_empty() == true` → observed `["silver", "item"]`; `silver == event_open_silver` → observed `1810` (event_open_silver `1830` — dipped by exactly 20, the old unconditional charge); `map_status_text != ""` → observed `""` (no refusal receipt) |
| green_asserts_before_red | 8 | f400 `current_state == "MAP"` + `visible == true`; f440 `phase == "EVENT"` + `event_id == "merchant"` + `current_node_id == "luoyang"` + `silver == event_open_silver`; f470 `phase == "TRAVEL"` + `events_resolved_count == 1` |

**Restore:** `event_logic.gd` restored byte-identically; `grep scripts/ "TEMPORARY RED-FIRST
REVERT"` → **zero hits** (verified). Re-run GREEN: **11/11**.

## 4. Owned-vs-silver honesty check

The nail's stated purpose is to pin the OWNED refusal (`EventLogic.validate_option` returns
"owned" because `eq_sword_3` was granted into inventory at f260). `validate_option` checks net
silver capacity FIRST, then item ownership — so if the post-fast-forward balance at the merchant
were < 20, the SILVER reason would fire instead and the nail would pass for the wrong reason.

**Verified on the measured green run:** the receipt is the OWNED wording
`此物已在行囊，无须再购` (probed via an inline scenario asserting an impossible value on
`map_status_text` at f470 — observed the owned wording). The red-run evidence independently
confirms balance ≥ 20: under the revert, silver dipped by exactly 20 from 1830 → 1810, so the
post-fast-forward balance at the merchant was ≥ 20. **No `debug_grant_silver` funding was needed.**

## 5. Blast radius

Re-ran the two co-boot scenarios via the sidecar after the fix — both stay green:

- `facility_use_cap_exhausted_zero_delta` — **33/33** (same boot route, unchanged);
- `map_node_event_revisit_no_resettle` — **33/33**.

This route resolves the merchant event and grants `eq_sword_3` into inventory; no co-running
scenario on this boot asserts NOT owning it (the equipment-round nails assert ownership/equip
state, not absence).

## 6. Red-line self-check

- `playtest/facility_use_reusable.yaml`, `playtest/map_node_event_shaolin.yaml`,
  `playtest/map_battle_node_huashan.yaml` — **byte-untouched** (verbatim-protected trio).
- `scripts/data/event_logic.gd` — landed content byte-identical to the pre-task baseline (the
  validate-then-apply logic is a LANDED, passing repair; the revert was temporary and measured
  only, restored byte-identically, zero residue).
- No balance numbers moved.
- The five landed fixes (soft-lock, facility cap, re-settlement split, all-or-nothing, occlusion)
  are untouched — this task touched only the one broken scenario yaml and its delivery notes.
- Out of scope (not touched here): the `ui_occlusion_watch.gd:58` runtime error that hard-fails
  the whole official run — that is the occlusion-watch subtask's fix surface.
