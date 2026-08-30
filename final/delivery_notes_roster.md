# Delivery notes — roster_panel_red_first (measured red-first evidence)

**Task:** `roster_panel_red_first` — measure the roster-panel item nail's red-before-green
from a REAL `godot_playtest_scenario` sidecar run using the TEMPORARY RED-FIRST REVERT
protocol, record the four measured values, restore the tree byte-identical.
**Date:** 2026-08-30. **Depends on:** `roster_panel_contract` (landed: both scenario files,
`scripts/ui/roster_panel.gd`, the surface blocks and `scenario_order`/`ROUND_SCENARIOS`
two-place sync).

## Deliverables in this task

1. `playtest/roster_panel_item_nail.yaml` — RED-FIRST EVIDENCE placeholder block replaced
   with the four MEASURED values + method note. Timeline (f30–f150), `name:`,
   `description:`, `scene:` byte-untouched.
2. `final/delivery_notes_roster.md` — this note.
3. `scripts/ui/roster_panel.gd` — temporarily reverted to a no-op `open()`, then restored
   byte-identical (zero `TEMPORARY RED-FIRST REVERT` markers left anywhere in `scripts/`).

## 1. RED-FIRST protocol (TEMPORARY RED-FIRST REVERT + direct sidecar)

**Verbatim revert (mark `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`)** in
`scripts/ui/roster_panel.gd`, `open()` (the whole 8-line body neutralized; the
`RosterOpenButton` still exists and its `pressed` signal still delivers into the no-op):
```
func open() -> void:
    # TEMPORARY RED-FIRST REVERT — DO NOT COMMIT
    # is_open = true
    # var overlay: Control = _overlay_node()
    # if overlay != null:
    #     overlay.visible = true
    # var ob: Button = _open_button_node()
    # if ob != null:
    #     ob.visible = false
    # refresh()
    pass
```
`close()`, `refresh()`, `_wire_buttons()`, `_on_open_pressed()` untouched.

**Repro:** apply the revert, run
`godot_playtest_scenario(scenario="roster_panel_item_nail")` directly (NOT through the
5_compile gate), record the four values VERBATIM; restore the revert byte-identically,
re-run.

**MEASURED values (2026-08-30, `godot_playtest_scenario` sidecar run with the revert
applied):**
- failing_frame: **f70**
- first_failing_assert: **`RosterPanel.is_open: is_open == true`**
- exact_error (the report's two lines for that first failure, character-for-character):
  ```
  FAIL f70 RosterPanel.is_open: is_open == true
       observed=false
  ```
- green_asserts_before_red: **8** (f30 ×4 + f50 ×4; strictly before the first failing
  assert — the f70 block's first assert is the failure, so no f70 assert counts).

The run reported `ok: 32, total: 36` for the whole reverted run (it continues past the
first failure and counts later asserts too: f110 `silver: changed` and f130 `is_open ==
true` / `青锋剑` also red on the reverted tree). Those post-f70 failures are NOT part of the
red-before-green count, which is 8 by the strict "strictly before the first failing assert"
rule. The reverted run also produced two `push_error` entries
`aim: node is not visible in tree: RosterCloseButton` from the f80 / f140 `RosterCloseButton`
clicks — the close button is invisible because the panel never opens under the revert; these
occur after the f70 first-red and likewise do not affect the 8.

[Cross-checked against the timeline, read-only — not the source of truth] With `open()` a
no-op, the f60 open click leaves `is_open == false`, so the first failing assert was
expected at f70 = `RosterPanel.is_open: is_open == true`, with 8 green before red
(f30 ×4 + f50 ×4). The run matched this exactly; the run's values are the recorded ones.

## 2. Observed self-run pass counts (BOTH scenarios, restored tree)

The sidecar was run directly on the restored tree. **The baseline is NOT green** — both new
scenarios carry genuine defects that belong to the `roster_panel_contract` task and are
OUTSIDE this measurement task's scope (this task is forbidden from modifying the scenario
timeline, and the defects are in the contract scenarios / the save path, not in the revert
target).

- `roster_panel_item_nail`: **35/36** — single failure at **f110**
  `MapScreen.silver: silver changed since frame 0`. Root cause (verified in data, not
  predicted): a FRESH direct boot has `profile.silver == 0` (`player_profile.gd:21`), and
  merchant `option_a` = `silver -20` (`event_data.gd:35`) which `apply_option_effects`
  clamps to `maxi(0 - 20, 0) = 0` (`event_logic.gd:42`) — so silver never changes and the
  `changed` differential can never pass on this boot. The 青锋剑 item grant is independent
  of the silver clamp and does append `eq_sword_3`, but because the run stops at the f110
  first failure, the f130 `青锋剑` assertion is not reached on the current tree. Fix
  (contract task's job, requires a timeline/flow change this task must not make): give the
  player positive silver before the merchant grant (e.g. a `debug_grant_silver` action or a
  travel-path silver source) so `silver: changed` is meaningful.
- `roster_panel_cultivation_open_close`: **15/16** — failure at **f110**
  `CultivationScreen.month: month changed since frame 0` PLUS 6 runtime errors
  `Invalid access to property or key 'economy' / 'equipment' / 'growth' on a base object of
  type 'Dictionary'` at `save_manager.gd:382` and `:365`. The `month: changed` failure is
  the scenario's own documented limitation (`debug_step_month` is gated on
  `GameManager.current_state == "CULTIVATION"` at `cultivation.gd:694-696`, which a direct
  scene boot does not set; the scenario comment says the fallback is "one real month played
  by clicks", which was not implemented). The `save_manager.gd` runtime errors are a
  separate pre-existing deck-initialization issue surfaced by the direct-boot month
  advance. Both are contract-task concerns, not this measurement task's.

## 3. Restore confirmation (byte-identity)

The revert was restored with the exact reverse edit, re-reading `scripts/ui/roster_panel.gd`
to confirm `open()` is back to its 8 original body lines, and a search of `scripts/**/*.gd`
for `TEMPORARY RED-FIRST REVERT` returns **zero hits**. Post-restore re-run of BOTH
scenarios reproduces the baseline exactly (`roster_panel_item_nail` 35/36 f110; `roster_panel_cultivation_open_close` 15/16 + runtime errors + f110), confirming the restored tree
behaves identically to the pre-revert baseline.

## 4. Untouched

- `playtest/spine_to_ending.yaml` — not modified.
- Frozen artifacts (`tests/test_playtest_contract_smoke.py::_bad_timeline_at_values`,
  `tests/test_facility_copy_location.py`, `scripts/data/card_data.gd::display_name_of`) — not
  modified.
- `playtest/roster_panel_item_nail.yaml` timeline (f30–f150) — not modified.
- The 5_compile gate — not invoked/modified.

## 5. README "71 scenarios" count fix — docs task's responsibility

This task produces only the measured scenario evidence. Updating the README's stale
"71 scenarios" counts (and `design/99_changelog.md` row :126 verification) is the **docs
task's** job, not this card's. The measured evidence this task contributes is: the
red-first four values above, and the observed (non-green) baseline counts above — the
final README scenario total must be reconciled by the docs task once the contract-task
scenario defects (Section 2) are resolved and the official gate reports a green count.
