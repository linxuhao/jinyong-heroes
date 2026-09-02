# Delivery Notes — fix_c1_grade_vocabulary (C1)

**Date:** 2026-09-02
**Card:** C1 (L2) — Single grade-vocabulary source: Latin-key GRADE_POINTS, prod-key fixtures.

---

## What Was Done

1. **`scripts/data/progression_math.gd`** — `GRADE_POINTS` changed from CJK keys `{"丁":1,"丙":2,"乙":3,"甲":4}` to Latin keys `{"D":1,"C":2,"B":3,"A":4}`. Pure const, zero load-order risk. The SINGLE-SOURCE property is guarded by the key-set-equality nail in the test file.

2. **`tests/test_progression_math.gd`** — Full fixture rewrite:
   - Deleted the hand-written `const GRADE_KEYS: Array[String] = ["丁","丙","乙","甲"]`.
   - Added `static func _grade_keys() -> Array` that returns `ProgressionGongfaData.PRACTICE_TO_MASTER.keys()` (production vocabulary, single source).
   - `_test_grade_points`: asserts key-set mutual inclusion (both directions) + per-key point values (D=1, C=2, B=3, A=4).
   - `_test_mastery_points`: builds one mastered row per production grade, asserts `mastery_points > 0` for each; keeps property pins (unmastered→0, unknown grade→0, missing `mastered` key→0).
   - All `add_gongfa` grade arguments taken from `_grade_keys()` — zero hand-written grade strings.

3. **`tests/test_battle_setup_readiness.gd`** — Consumption sweep: 9 occurrences of CJK grade literals (`"丁"`, `"甲"`) replaced with production Latin keys (`"D"`, `"A"`). Zero logic changes.

4. **`tests/test_ending_logic.gd`** — Consumption sweep: 2 occurrences of CJK grade literals replaced with Latin keys (`"D"`, `"A"`). Assertion message updated from "mastered 丁" to "mastered D".

---

## Measured Red (Unit-Level)

**Pre-fix tree** (CJK GRADE_POINTS + new Latin-key fixtures):

| Field | Value |
|---|---|
| First failing assertion | `_test_grade_points`: `GRADE_POINTS has production key D` |
| Observed | `GRADE_POINTS.has("D") == false` (keys are 丁/丙/乙/甲) |
| Exact error | `test_progression_math: GRADE_POINTS has production key D` |
| Green before red | 0 (the very first assert in `_test_grade_points` fails) |

The red is natural: running the new Latin-key fixtures against the pre-fix CJK dict immediately fails at the key-presence check. No temporary revert was needed — the pre-fix tree IS the CJK tree.

**Post-fix:** all assertions in `_test_grade_points`, `_test_mastery_points`, `_test_mastered_count` pass. The other test functions (`_test_work_income`, `_test_deed_score`, `_test_readiness_power`) are unaffected by the GRADE_POINTS key change and remain green.

---

## Consumer Sweep Result

| File | Status | Notes |
|---|---|---|
| `scripts/data/event_logic.gd:95` | **No change needed** | Uses `PRACTICE_TO_MASTER.get(grade, 4)` — Latin key lookup, correct. |
| `scripts/segments/cultivation.gd:456` | **No change needed** | `add_gongfa(pick, "A")` — Latin key, correct. |
| `scripts/segments/cultivation.gd:566-573` | **No change needed** | Year ladder uses `GRADE_BY_YEAR` (Latin), correct. |
| `scripts/segments/cultivation.gd:967` | **No change needed** | Debug A grant, Latin key, correct. |
| `scripts/data/battle_setup.gd` / `gongfa_data.gd` | **No change needed** | GRADE_RANK uses Latin keys, correct. |
| `tests/test_progression_math.gd` | **Fixed** | Fixture rewrite (this card). |
| `tests/test_battle_setup_readiness.gd` | **Fixed** | 9 CJK literals → Latin (this card). |
| `tests/test_ending_logic.gd` | **Fixed** | 2 CJK literals → Latin (this card). |

**Result: zero stray CJK grade literals remain in the codebase.** All production code was already Latin-key; only the three test files needed updating.

---

## Interface Contract Delivered

`ProgressionMath.GRADE_POINTS: Dictionary` — key set exactly equal (both directions) to `ProgressionGongfaData.PRACTICE_TO_MASTER.keys()` = `{"D","C","B","A"}`, values `{"D":1,"C":2,"B":3,"A":4}`.

`ProgressionMath.mastery_points(profile) -> int` — body unchanged; now returns non-zero for real saves (which store Latin grade keys).

Downstream cards (`fix_c3_ending_tiers`, `fix_c4_huashan_readiness`, `fix_c5_winnable_huashan_route`) can now rely on `mastery_points > 0` for profiles with mastered arts.

---

## Hard Rules Compliance

- **Six-file lock:** untouched (battlefield.gd, game_manager.gd, scene_manager.gd, map.gd, map_battle_data.gd, map_battle_node_huashan.yaml).
- **Three verbatim gates:** untouched (facility_use_reusable, map_node_event_shaolin, map_battle_node_huashan).
- **RNG lifelines:** zero new RNG ops — this card changes only a const dict + test fixtures. `save_load_roundtrip` and `event_travel_effects` unaffected.
- **SINGLE-SOURCE rule:** point values remain a single lookup in `progression_math.gd`; no inline re-derivations elsewhere.
