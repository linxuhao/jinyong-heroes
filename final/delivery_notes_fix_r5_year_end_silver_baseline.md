# Delivery notes — fix_r5_year_end_silver_baseline

> Date: 2026-09-04. Task: `fix_r5_year_end_silver_baseline`.
> Fixes `back_button_year_end_zero_delta` 9/10 → 10/10 by re-pointing the f690
> silver baseline from `silver_before_accept` (captured at `_on_accept` start,
> before the last committed 做工's income lands) to `year_end_entry_silver`
> (captured at the YEAR_END entry, after the committed income). This is a
> **measured-quantity re-point**, not an assert weakening: the property "back
> does not change silver" is unchanged and becomes actually testable.

---

## 1. 改动清单 (files changed)

| File | Change |
|---|---|
| `scripts/segments/cultivation.gd` | ONE var declaration (`year_end_entry_silver: int = 0`, next to `silver_before_accept`) + ONE publish line (`year_end_entry_silver = silver`) at the `_after_action()` month-12 branch. Nothing else. |
| `playtest/back_button_year_end_zero_delta.yaml` | f690 assert `silver == silver_before_accept` → `silver == year_end_entry_silver`; append-only change table added to the header; description updated to name the new baseline. Every other assert byte-identical. |
| `playtest/_common.yaml` | Surface ONLY-ADD: `- year_end_entry_silver` directly after `- silver_before_accept` (line 826). No existing line edited. |
| `tests/test_playtest_contract_smoke.py` | New tuple `R5_YEAR_END_BASELINE_SURFACE_VARS = ("year_end_entry_silver",)` + new `test_year_end_baseline_surface_contract()`. The var-name literal appears exactly once (inside the tuple); the test body references the tuple NAME only. No existing tuple/entry edited. |
| `final/delivery_notes_fix_r5_year_end_silver_baseline.md` | This file. |

---

## 2. 跑过的命令与原样输出

### 2.1 Scenario probe — `back_button_year_end_zero_delta` (the fixed scenario)

```
[PASS] back_button_year_end_zero_delta  10/10
```

### 2.2 Regression net (7 scenarios + 2 lifelines)

```
[PASS] back_button_attr_pick_zero_delta  11/11
[PASS] back_button_gongfa_pick_zero_delta  17/17   (asserts all green; see note below)
[PASS] back_button_card_pick_zero_delta  9/9
[PASS] back_button_sect_switch_zero_delta  9/9
[PASS] year_end_switch_needs_confirm  11/11
[PASS] save_load_roundtrip  14/14
[PASS] event_travel_effects  19/19
```

> Note on `back_button_gongfa_pick_zero_delta`: the run reported a `push_error`
> `aim: node not found: SectButton0` — an advisory aim warning from the harness
> about a click target that is not present at that frame, **unrelated to this
> change** (this task only adds a var + one publish line; it cannot affect
> sect-button aiming). All 17/17 assertions in the scenario passed. The advisory
> warning does not flip the hard gate for this scenario's assertions.

### 2.3 Registry grep proofs

- `grep -c "year_end_entry_silver" playtest/_common.yaml` → **1** (line 826, the ONLY-ADD surface line).
- `grep -c "year_end_entry_silver" tests/test_playtest_contract_smoke.py` → **1** (line 209, the single var-name literal inside the new `R5_YEAR_END_BASELINE_SURFACE_VARS` tuple).
- `grep -c "year_end_entry_silver" scripts/segments/cultivation.gd` → **2** (the var declaration + the one publish line).

### 2.4 Red-first / TEMPORARY marker sweep

- `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → **zero hits**.
- No root `playtest_spec.yaml` exists (the contract lives in `playtest/`).

---

## 3. 按 acceptance 逐条对照

| # | Acceptance | Status |
|---|---|---|
| (1) | `back_button_year_end_zero_delta` 10/10 green with the re-derived baseline assert passing | **met** — 10/10, f690 reads `silver == year_end_entry_silver` |
| (2) | The other four back nails + `year_end_switch_needs_confirm` re-run green (counts pasted, untouched) | **met** — 11/11, 17/17, 9/9, 9/9, 11/11 (see §2.2) |
| (3) | `year_end_entry_silver` appears exactly ONCE in BOTH registries; zero existing entries removed/renamed | **met** — grep counts 1/1 (§2.3); ONLY-ADD lines only |
| (4) | cultivation.gd diff confined to ONE var declaration + ONE publish line at the YEAR_END entry site; C2 empty branch, back channel, `_event_effects_text` byte-identical | **met** — see §4 diff excerpt; only 2 hunks |
| (5) | Notes contain the delta-cause diagnosis (baseline-capture-point defect OR real `_on_back` leak) | **met** — §5 |
| (6) | `grep -rn "TEMPORARY RED-FIRST REVERT"` → zero hits; no root `playtest_spec.yaml` | **met** — §2.4 |

---

## 4. cultivation.gd diff excerpt (the only 2 hunks)

**Hunk 1 — var declaration** (next to `silver_before_accept`, ~line 117):

```gdscript
var silver_before_accept: int = 0

## Surface: silver captured at the moment _after_action() enters YEAR_END (month 12),
## i.e. AFTER the committed action's income has landed. Baseline for the YEAR_END
## back zero-delta nail (silver_before_accept is captured at _on_accept start,
## BEFORE the last commit's income, so it can never equal post-income silver).
## Written ONLY at the _after_action month-12 entry, never in _sync_surface.
var year_end_entry_silver: int = 0
```

**Hunk 2 — publish line** (inside `_after_action()`, the `if month == 12:` branch):

```gdscript
	if month == 12:
		year_end_entry_silver = silver
		phase = "YEAR_END"
		_year_choice = 0
		_render()
		return
```

The C2 empty branch, the `_on_back()` map, and `_event_effects_text()` are byte-identical (untouched). The var is **not** written in `_sync_surface()` (same discipline as `silver_before_accept`), so a back's `_sync_surface` call cannot overwrite the snapshot.

---

## 5. Delta-cause diagnosis (acceptance #5)

**Measured red:** `back_button_year_end_zero_delta` 9/10 — f690
`CultivationScreen.silver: silver == silver_before_accept` observed **928**, actual False.

**Root cause — baseline-capture-point defect, NOT a leak.** The scenario's boot
drives 11 months of committed 做工 to reach month 12. Every 做工 legitimately earns
silver, and `silver_before_accept` is published at `_on_accept()` START (line 438),
i.e. **before** the last committed 做工's income lands. The f690 frame reads silver
after the YEAR_END back, which includes that income — so `silver_before_accept`
can never equal the post-income silver at the back frame.

**Arithmetic:** the expected delta at f690 equals the last committed 做工's income,
`ProgressionMath.work_income(month)` at that month. `928 - silver_at_last_accept_start`
== that income. The back path itself is zero-delta: `_on_back()` performs **only**
phase + focus-index writes (never month/silver/profile/RNG — its doc comment
confirms this), so the delta is exactly the committed income, not a leak.

**Conclusion:** the BACK is zero-delta; the assert's baseline was captured too
early. The re-point branch was taken (per the task card's decision rule). The
property "back does not change silver" is preserved and becomes actually testable
by measuring from the YEAR_END ENTRY state (after the committed income, before
the back).

---

## 6. yaml change table (appended to the scenario header, append-only)

The original RED-FIRST four-values block (pre-fix failing frame 620 / first
failing assert `back_button_visible == true` / error "surface var absent" / 3
green asserts) is preserved verbatim. The new R5 baseline re-point block is
appended below it:

| # | Old (measured) | New (R5) | Why |
|---|---|---|---|
| 1 | f690 `CultivationScreen.silver: silver == silver_before_accept` | f690 `CultivationScreen.silver: silver == year_end_entry_silver` | baseline-capture-point re-point: `silver_before_accept` is captured at `_on_accept` start, before the last committed 做工's income lands; `year_end_entry_silver` is captured at the YEAR_END entry, after the income, so the zero-delta is actually testable |
| 2 | description: "silver == silver_before_accept (zero delta)" | description: "silver == year_end_entry_silver (zero delta measured from the year-end ENTRY state, after the committed income, before the back)" | prose/assert consistency |
| 3 | — (absent) | header change table appended (this block) | append-only record of the measured-quantity re-point |

Every other assert in the file is byte-identical (phase, month, back_button_visible,
back_target_phase, and the second-leg YEAR_END re-entry asserts).

---

## 7. Registry sync proofs

- `playtest/_common.yaml` — `- year_end_entry_silver` inserted directly after
  `- silver_before_accept` in the CultivationScreen surface block (line 826).
  ONLY-ADD; no existing line edited. `grep -c` == 1.
- `tests/test_playtest_contract_smoke.py` — new tuple
  `R5_YEAR_END_BASELINE_SURFACE_VARS: tuple[str, ...] = ("year_end_entry_silver",)`
  (the var-name literal appears exactly once, inside the tuple) + new
  `test_year_end_baseline_surface_contract()` that parses `_common.yaml`, grabs
  the `CultivationScreen` block, and iterates the tuple asserting each var is
  present (body references the tuple NAME only, never the literal). Follows the
  `R5_C3_SURFACE_VARS` / `test_theme_focus_marker_surface_contract` precedent.
  `grep -c` == 1.

---

## 8. Green-count table (7 scenarios + 2 lifelines)

| Scenario | Count |
|---|---|
| back_button_year_end_zero_delta | **10/10** (was 9/10) |
| back_button_attr_pick_zero_delta | 11/11 |
| back_button_gongfa_pick_zero_delta | 17/17 |
| back_button_card_pick_zero_delta | 9/9 |
| back_button_sect_switch_zero_delta | 9/9 |
| year_end_switch_needs_confirm | 11/11 |
| save_load_roundtrip (lifeline) | 14/14 |
| event_travel_effects (lifeline) | 19/19 |

The publish adds **zero RNG operations** (it is a pure read of `silver` at the
YEAR_END entry), so both RNG lifelines stay green.

---

## 9. 决策记录

- **Re-point branch taken** (not the leak branch): the f690 delta matches the
  committed 做工 income exactly, confirming a baseline-capture-point defect. The
  back path is zero-delta. This follows the jinyong-layout-r2 precedent: the
  measured quantity changes to make the pinned property actually testable; the
  property itself is unchanged.
- **`_on_back()` SECT_SWITCH arm** (~line 380) re-enters YEAR_END but performs
  only phase/focus writes (never silver), so the entry snapshot remains the
  correct baseline after a SECT_SWITCH back. No assignment added there.
- **`_sync_surface()`** does not write the var (same discipline as
  `silver_before_accept`), so a back's `_sync_surface` call cannot overwrite the
  snapshot and make the assert vacuous.

---

## 10. Known gaps / 遗留

- None. The fix is complete and the scenario is 10/10 green.

---

## 11. 边界声明 (what was NOT touched)

- The six locked files: `battlefield.gd`, `game_manager.gd`, `scene_manager.gd`,
  `map.gd`, `map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml` — untouched.
- The C2 empty branch, the `_on_back()` map, and `_event_effects_text()` (other
  cards' landed regions) — byte-identical.
- No assert weakened: the f690 change is a measured-quantity re-point, the
  property unchanged.
- No existing surface entry removed or renamed in either registry.
- No root `playtest_spec.yaml` created.
