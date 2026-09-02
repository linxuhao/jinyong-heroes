# Delivery Notes — fix_c2_practice_target (C2)

**Date:** 2026-09-02
**Card:** C2 (L3) — Practice targets the chosen art: `add_practice` target threading + receipt.

---

## What Was Done

1. **`scripts/data/event_logic.gd`** — `add_practice(profile, amount, target_id := "")` gains the third parameter (default `""`). The `sha_po_lang` `TraitEffects.pojun_practice` transform keeps its exact order (pure arithmetic, zero RNG). New `_resolve_target(profile, target_id) -> String`: returns `target_id` only when it is non-empty AND names an unmastered row (`mastered != true`, non-empty String id); otherwise (empty / unknown id / already mastered) falls back to `_first_unmastered_id(profile)`; returns `""` only when the profile has no unmastered rows at all (no-op, existing behavior). A practice month is never silently dropped. The event-effect call site (`apply_option_effects` "practice" row, ~:79) and the card "practice" path still call `add_practice(profile, value)` with NO target → fallback, byte-identical.

2. **`scripts/segments/cultivation.gd`** — `_apply_action` "practice" branch resolves the target FIRST (`var resolved: String = EventLogic._resolve_target(SaveManager.profile, target)`), threads the RESOLVED gid into `_add_practice(PRACTICE_ACTION_GAIN, resolved)`, and sets `last_practice_target = resolved` (never the raw input). `_add_practice` wrapper gains the pass-through parameter and forwards to `EventLogic.add_practice(SaveManager.profile, amount, target_id)`. `last_yield_text` is built from `ProgressionGongfaData.display_name_of(resolved)` with honest degrade to the raw gid on miss (roster_panel precedent).

3. **Two computed observables** — `last_practice_other_rows_unchanged: bool` and `last_practice_target_increased: bool`, computed from a pre/post snapshot inside `_apply_action` via `_practice_counts_by_id()` / `_other_rows_unchanged()` / `_target_increased()`. Both default `false` ("not yet exercised"); both are `false` when the month no-ops (no unmastered rows). Published via `_sync_surface`; registered in the `playtest/_common.yaml` surface whitelist (lines 793-794).

4. **`tests/test_cultivation.gd`** — three new unit pins wired into `_test_all`:
   - `_test_practice_targeted`: targeted increment (row2 +2, row1 unchanged), the two computed observables via the real `_apply_action` path, receipt display name + no raw ASCII id.
   - `_test_practice_target_fallback`: empty target → first unmastered (row1); unknown id → first unmastered; already-mastered target → first unmastered (row2). Month never dropped.
   - `_test_practice_resolved_gid_invariant`: mastered raw target resolves to the fallback gid; `last_practice_target` holds the RESOLVED gid, never the raw input.
   Existing `_test_practice_mastery` / `_test_add_practice_no_unmastered_noop` remain compile-compatible with the defaulted third param.

5. **`playtest/practice_target_receipt.yaml`** (new) — real-save boot (main.tscn → tutorial → creation → join sect). Month 1 practice picks row 1 (default focus, `CultOptionButton0`); month 2 practice CLICKS row 2 (`CultOptionButton1` = shaolin_luohan_d). Asserts `last_practice_target: changed` (two months target different arts), `last_practice_other_rows_unchanged == true` (zero-diff), `last_practice_target_increased == true`, `last_yield_text: changed` + containing the chosen art's display name (罗汉拳, CJK literal sourced from `display_name_of`), no raw ASCII id, and UiOcclusionWatch clean on every touched frame. Zero balance literals.

6. **Registry two-place sync** — `practice_target_receipt` added to `playtest/_common.yaml` `scenario_order` tail (line 1175) AND `tests/test_playtest_contract_smoke.py` `ROUND_SCENARIOS` (line 92) at the same relative order (name==basename guard).

---

## Measured Red (Red-First Four Values)

**Pre-fix tree** (temporary revert of the threading, marked `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`): the `_apply_action` "practice" branch was reverted to call `_add_practice(PRACTICE_ACTION_GAIN)` with no target and `last_practice_target = target` (raw input). Run via `godot_playtest_scenario` on the new scenario.

| Field | Value |
|---|---|
| Failing frame | **f560** (the month-2 practice assert frame) |
| First failing assertion | `CultivationScreen.last_practice_target` (`last_practice_target: changed`) |
| Exact error / observed | observed `last_practice_target == "shaolin_yijin_d"` on BOTH months — the revert made month 2 add to row 1 while the raw input `"shaolin_luohan_d"` was recorded (the receipt said one thing, the practice landed on another) |
| Green before red | **12** (f260 CULTIVATION 4 + f360 month-1 practice 4 + f460 month-2 GONGFA_PICK 4) |

**Revert recipe** (mark `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`):
- `scripts/segments/cultivation.gd` `_apply_action` "practice" branch: replace `_add_practice(PRACTICE_ACTION_GAIN, resolved)` with `_add_practice(PRACTICE_ACTION_GAIN)` (no target) and `last_practice_target = resolved` with `last_practice_target = target`.

**Restore**: byte-identical restore of the threading; `grep scripts/ for "TEMPORARY RED-FIRST REVERT"` → zero hits (no residue). Re-run GREEN.

---

## Resolved-Gid Double-Call Rationale (Invariant Note)

`cultivation._apply_action` calls `EventLogic._resolve_target(profile, target)` for bookkeeping (to set `last_practice_target` and compute the two observables), and `add_practice` re-resolves internally. Both calls are deterministic and pure (zero RNG, no mutation between the two calls), so they always agree. `add_practice` stays `void`. A future refactor that makes `add_practice` return the resolved gid must keep both call sites consistent.

---

## RNG Lifelines (Re-run After Edit)

- `save_load_roundtrip` — **green** after the EventLogic edit (zero new RNG ops; the `_resolve_target` scan is pure iteration).
- `event_travel_effects` — **green** after the EventLogic edit (zero new RNG ops).

## Regression Suite Confirmation

- `action_yield_differential` — asserts `last_practice_target != ""` and `last_yield_text != ""`; both still hold under the new semantics (resolved gid is non-empty whenever an unmastered row exists).
- `softlock_empty_practice_month_advances` — unaffected (no-op path preserved).
- `clicks_only_storyline` — unaffected (no practice-branch change to the click grammar).
- `save_load_roundtrip` / `event_travel_effects` — green (above).

---

## Hard Rules Compliance

- **Six-file lock:** untouched (battlefield.gd, game_manager.gd, scene_manager.gd, map.gd, map_battle_data.gd, map_battle_node_huashan.yaml).
- **Three verbatim gates:** untouched (facility_use_reusable, map_node_event_shaolin, map_battle_node_huashan).
- **RNG op-order:** zero new RNG ops on old paths — all changes are pure arithmetic / iteration.
- **gongfa row structure** `{id, grade, practice, mastered}` unchanged.
- **Zero `TEMPORARY RED-FIRST REVERT` residue** in `scripts/` (grep clean).

---

## Downstream Consumption

- `fix_c6_yield_receipt` extends `playtest/practice_target_receipt.yaml` (same file, sequenced after this task) with `last_yield_readable` + the receipt render. This task's registry/surface additions and any assertion frames left open are NOT omissions of C2's scope.
- `fix_c8_design_records` records the fallback ruling (empty/unknown/mastered target → first unmastered; a practice month is never silently dropped) in `design/90_decisions.md`.
