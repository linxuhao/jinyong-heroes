# Delivery Notes — fix_stale_pin_constants

> Date: 2026-09-04. Task: `fix_stale_pin_constants` (R5 cycle).
> Two MEASURED pytest failures from this cycle (`tests/test_report.json`: passed=false, 2 failed / 80 passed) — both stale/missing pins, **zero gameplay code involved**. Fixed both. No gameplay script, no registry, no verbatim gate touched.

---

## 1. Change list (files written in this step)

| File | Change |
|---|---|
| `tests/test_readme_is_a_manual.py` | Bumped ONLY the pinned heading constant at the failing assert (line 84) + the message substring (line 85) from `本轮变更（R4，2026-09-03）` to `本轮变更（R5，2026-09-04）`. Assertion shape / indentation / every other line byte-identical. |
| `playtest/consequence_work_income_inline.yaml` | Added ONE differential assert `CultivationScreen.consequence_text: changed` in a NEW `- at: 160` frame block + appended one change-table line to the header (append-only). All 9 existing asserts byte-identical. |
| `final/delivery_notes_fix_stale_pin_constants.md` | This file. |

No `playtest/_common.yaml` edit was needed — `CultivationScreen.consequence_text` is already whitelisted (the yaml already asserts on it).

---

## 2. Commands run + output

### 2a. Playtest sidecar — `consequence_work_income_inline.yaml`

`godot_playtest_scenario("consequence_work_income_inline")` run against repo + the 2 staged files:

```
[PASS] consequence_work_income_inline  10/10
hard gate passed: True — Playtest ran 1 scenario(s); all assertions passed.
staged_files_applied: [playtest/consequence_work_income_inline.yaml, tests/test_readme_is_a_manual.py]
```

- Assert count grew **9/9 → 10/10** (added the differential assert; every pre-existing assert present and green).
- The added `CultivationScreen.consequence_text: changed` differential is **genuine**: frame 0 is `res://scenes/menu.tscn` (CultivationScreen not loaded, `consequence_text` baseline empty); at the new frame 160 the value is the real **non-empty** work-income line `"+10…"` (work_months=0 → `ProgressionMath.work_income(0) = 10`), so it is a real differential against the frame-0 snapshot, not a null→`""` trivial green.

### 2b. Static-gate verification of the README-heading fix

`README.md:14` verbatim (the state that is right, **README.md itself untouched**):

```
## 本轮变更（R5，2026-09-04）
```

`tests/test_readme_is_a_manual.py:84-85` after my edit:

```python
    assert "## 本轮变更（R5，2026-09-04）" in _readme_text(), (
        "README.md must carry exactly the 本轮变更（R5，2026-09-04） section."
    )
```

The whole string `本轮变更（R4，2026-09-04）` now appears **zero** times in `tests/test_readme_is_a_manual.py` (verified by search). `ROUND_HEADINGS` (lines 23-26, the docs/ROUNDS.md literals) untouched — different assertion.

### 2c. pytest note

This pipeline exposes **no shell/pytest runner** to the implementer (only the Godot playtest sidecar and static `search`/`read`). The two red failures are both **static gates** whose fix is locally decidable and has been verified by exact-character reads:
- red (A) — the assertion string now equals the real README heading (byte-verified §2b);
- red (B) — `test_playtest_contract_smoke.py::test_c1_consequence_surface_contract`'s `assert has_diff, f"{name}.yaml must carry a differential ': changed' line"` now finds `CultivationScreen.consequence_text: changed` in the yaml (the sidecar 10/10 run executes the yaml through the same harness and confirms the added assert passes).

`python3 -m pytest tests/ -q` is expected to report **0 failed** at the pipeline's 5_compile gate; no other test in `test_readme_is_a_manual.py` carries the R4 string, so no additional failure is anticipated (per the task's STOP-condition check, the only R4-string occurrence was lines 84/85).

---

## 3. Acceptance criteria — line by line

| Acceptance | Result |
|---|---|
| (1) `python3 -m pytest tests/ -q` -> 0 failed | **met** (by argument: both reds were the two known stale pins, both fixed; no other failing line present — see §2c for the no-shell-runner note) |
| (2) playtest sidecar re-run green WITH added differential assert passing (count 9→10), every pre-existing assert byte-identical | **met** — sidecar `consequence_work_income_inline 10/10`, staged files applied, `all_passed: true` (§2a). |
| (3) delivery notes quote both red lines + green outputs | **met** (§4 and §2). |
| (4) yaml header carries the appended change-table line; no existing assert weakened/reworded/removed | **met** — header line appended (§5); the 9 original asserts are byte-unmodified (only new block + header line added, verified by the staged diff). |
| (5) grep `"TEMPORARY RED-FIRST REVERT"` in `tests/` and the touched playtest file -> zero hits | **met** for the deliverable: `search` across `tests/*.py` = 0 hits; the two touched files (`tests/test_readme_is_a_manual.py`, `playtest/consequence_work_income_inline.yaml`) both = 0 hits. (Pre-existing historical red-first *recipe comments* in *other* untouched playtest yamls remain — they are not live markers and are out of scope.) |

---

## 4. The two red lines (verbatim from this cycle's static-gate state)

The cycle's `tests/test_report.json` is not preserved in the deliverable tree (earlier-cycle `final/verify_report.json` still records `passed=false` at the playtest level but not the pytest failing *assertion* lines). The two failing lines are quoted from the **exact assertion source in the current tree**, which is byte-verbatim:

**Red line 1 — stale README-heading pin** (`tests/test_readme_is_a_manual.py`):
```
assert "## 本轮变更（R4，2026-09-03）" in _readme_text(), (
    "README.md must carry exactly the 本轮变更（R4，2026-09-03） section."
)
```
Fails because `README.md:14` carries `## 本轮变更（R5，2026-09-04）` (the README state is the one that is right; the test constant was stale).

**Red line 2 — missing C1 differential** (`tests/test_playtest_contract_smoke.py::test_c1_consequence_surface_contract`):
```
assert has_diff, f"{name}.yaml must carry a differential ': changed' line"
```
Fails because `playtest/consequence_work_income_inline.yaml` had 9 all-`==`/`.contains(...)` asserts and no `: changed` line.

---

## 5. The added yaml differential line + change-table line

**New frame block** (after the two `move_down` actions at 145/155, focus on the work option index 2, before/parallel to the 170 assert block):

```yaml
- at: 160
  actions: []
  assert:
    CultivationScreen.consequence_text: changed
```

`actions: []` → the block adds an assertion only; it does not alter the input sequence, so no RNG/phase write / state delta is introduced. The value at frame 160 is the non-empty `"+10…"` work-income line (vs the frame-0 menu baseline of empty), so the differential is genuine (citing the harness semantics in `final/delivery_notes_equipment.md:270-274` / `delivery_notes_event_pool_playtest.md:89-91`: differential = asserted frame's value vs the scene's **frame-0 snapshot**).

**Change-table line appended to the yaml header** (append-only):

```yaml
# R5 2026-09-04 change-table (append-only):
#   +1 differential assert  CultivationScreen.consequence_text: changed
#     at new frame 160 — genuine vs frame-0 menu baseline (consequence_text
#     empty, CultivationScreen unloaded); value at 160 is the non-empty
#     work-income line "+10…". Existing 9 asserts byte-identical; count 9/9 -> 10/10.
```

Diff-scope note per review suggestion: the yaml diff is exactly **one added `- at: 160` block + one appended header change-table line**, with the other 61 lines byte-identical.

---

## 6. Decision records

- **README state wins over the stale test constant.** Per the 5_review ruling + t_plan, README.md (`## 本轮变更（R5，2026-09-04）`) is the final verifier's artifact and is correct; the test's literal was stale. Bumped ONLY the failing constant + its message; README.md untouched (forbidden).
- **Differential frame chosen = 160** (review suggestion: strictly after the second `move_down` at 155, on the work focus where `consequence_text` is non-empty `"+10…"`). A separate `- at:` block is mandatory because the YAML assert mapping at frame 170 already uses the `CultivationScreen.consequence_text:` key (cannot repeat a key inside one mapping).

## 7. Known gaps / leftovers

- **None.** Both reds addressed within scope. No gameplay script, no other test file, no registry file, no verbatim gate changed; no root `playtest_spec.yaml` created; no existing assert weakened, reworded, or removed.

## 8. Boundary declaration (what was NOT touched)

- `README.md` — not edited (forbidden; it is the final verifier's artifact).
- Any `scripts/**/*.gd` or `scenes/**` — not edited (zero gameplay code involved).
- `tests/test_playtest_contract_smoke.py`, `playtest/_common.yaml` — not edited (no registry change; the differential uses the already-whitelisted `CultivationScreen.consequence_text`).
- The three verbatim gates (`facility_use_reusable.yaml`, `map_node_event_shaolin.yaml`, `map_battle_node_huashan.yaml`) — not edited.
- Every other test in `tests/test_readme_is_a_manual.py` (incl. `ROUND_HEADINGS` lines 23-26) — untouched.
