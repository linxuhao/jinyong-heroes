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
**Fix landing (task `fix_roster_item_nail_silver`, 2026-08-31):** `roster_panel_item_nail`
was re-run **36/36 PASS** on the restored tree via `godot_playtest_scenario` sidecar (the
authoritative self-run for this scenario's fix). The f110 `MapScreen.silver: changed` red
is resolved by funding silver before the merchant event: one `at: 35` frame `actions:
[debug_grant_silver]` (whitelisted action, consumed in `map.gd::_process` → `_debug_grant_silver()`
→ `EventLogic.apply_option_effects`, never a bare profile write) grants **32** = 4 × the max
facility silver cost; merchant `option_a` then applies −20 and `maxi(32−20,0) = 12 ≠ 0`,
so the frame-0 baseline `0` → `12` satisfies `changed`. All blocks from f40 onward are
byte-identical; the RED-FIRST EVIDENCE block (f70 / `RosterPanel.is_open: is_open == true`
/ exact two lines / red-before-green **8**) and the §1 measured four values are untouched
(no re-measure — this scenario's red-first was already done). Note: under the historical
revert condition (open() a no-op) f110 would now be green regardless, but the stored 8
counts only asserts strictly before the f70 failure, so §1's block stays accurate.
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

## 6. Visually-verifiable walkthrough (docs task addition, 2026-08-30)

The following walks exactly the nail path pinned by `playtest/roster_panel_item_nail.yaml`
(a real event/card grant, then a click-through of the panel):

1. Boot the game into the **MAP** segment (`map.tscn`), standing at 无名谷.
2. Tap the **角色** button (top-right of the canvas) — the roster panel opens as a centered
   box. 人物 section shows the five attributes (根骨 / 内力 / 身法 / 悟性 / 福缘), 银两,
   先天特质, the current year/month and 门派; 功法 lists every learned gongfa one by one
   with grade, 练度 and a 大成 marker; 物品 resolves each inventory id via
   `CardData.display_name_of` to a readable Chinese name.
3. Close the panel (tap **关闭** or outside it) — back to the same MAP state, nothing consumed.
4. Travel to 洛阳, resolve the merchant `EVENT` with **option A** (a real
   `EventLogic.apply_option_effects` grant → `eq_sword_3` **青锋剑**, silver −20).
5. Tap **角色** again — the 物品 section now shows **青锋剑** (the drawn item's Chinese name
   is finally visible instead of a dead id).
6. Tap **关闭** and continue playing; phase / year-month / counts are unchanged and no
   keyboard was used at any point.

This is the exact correspondence-nail path the playtest asserts (`RosterBodyLabel.text`
contains `青锋剑` after the grant, `cursor_markers_visible == false` on the panel and on the
host, and the open/close never consumes a turn/action or autosaves).

## 7. `design/99_changelog.md` row :126 verification (docs task conclusion)

**Verified, not rewritten.** Row :126 (`touch_single_surface(修红实测收口)`, 2026-08-30)
already holds the four measured values **verbatim**: failing frame **f140** / first failing
assert **`CultOptionButton0.visible: visible == true`** / exact error
**`aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`** / red-before-green
**9**. Per the append-only archive rule (old rows stay verbatim; corrections are new rows),
and because this correction row already exists, **no third `touch_single_surface` correction
row was appended** — the brief's 「改成实测值」 for that historical predicted row is
overridden by the already-landed correction. The only changelog addition this round is the
single new `roster_panel` row for jinyong-roster's own design change, referencing the
measured red-first values in §1 above.

## 8. README scenario-count correction (docs task; measured, not hardcoded)

**Counting method:** the number of list items under `scenario_order:` in
`playtest/_common.yaml` — a registry count (counted 2026-08-30, not gated). Counted value:
**75** entries (73 prior + 2 roster scenarios: `roster_panel_item_nail`,
`roster_panel_cultivation_open_close`), matching the lines 1029–1103 list. This measured
value, **75**, was written into README at **exactly two** present-tense structural lines:
- `README.md:402` — "75 scenarios, including the keyboard spine …"
- `README.md:554` — "`playtest/` — 75 headless playtest scenarios …"

No other occurrence of "71" was touched: the historical PASS counts (`:501` / `:507` / `:520`
"71/71 scenarios PASS") and the unrelated `good_answers 71` counts (`:85` / `:433` / `:509`)
and the "(72 yaml files)" parenthetical at `:554` remain byte-identical. This is the
anti-global-replace rule applied — only the two current, structural scenario-count lines
changed (plain prose, not under the append-only archive rule).

## 9. `roster_panel_cultivation_open_close` month-progression fix (2026-08-31)

**Task:** `fix_roster_cultivation_month_progression` — replace the `debug_step_month`
frame with a clicks-only month advance, fixing the f110 `CultivationScreen.month: changed`
red (measured 15/16) and re-baselining frames. The `save_manager.gd` deck-boot runtime
errors (6, lines `:365`/`:382`) were already handled by `fix_save_manager_deck_boot_guard`
(this task runs after it).

- **Root cause (measured, not predicted):** `debug_step_month` is consumed in
  `cultivation.gd::_process` but early-returns unless `GameManager.current_state ==
  "CULTIVATION"`; a direct scene boot of `cultivation.tscn` leaves `GameManager.current_state`
  at the autoload default (STATE_TUTORIAL), so the token never advanced a month — observed
  `month: changed` actual `{'baseline': 1, 'current': 1}` at f110. The scenario's own
  documented clicks-only fallback was never implemented.
- **Fix:** replaced the f80 `actions: [debug_step_month]` frame with the real month path
  driven by clicks (phase-gated, not state-gated — works under a direct boot): f80 clicks
  `CultOptionButton0` (card pick, CARD_PICK → ACTION_PICK), f90 clicks `CultOptionButton2`
  (做工/work, ACTION_PICK index 2 → `_after_action` advances month 1→2 back to CARD_PICK).
  The post-advance assert (f100: `phase == "CARD_PICK"` + `month: changed`) is kept; the
  re-open/close block shifted f110→f140. All other assertions (three section headers,
  `cursor_markers_visible == false`, gongfa_count, is_open, boot `month == 1`) and the
  RED-FIRST EVIDENCE placeholder block were kept verbatim.
- **Observed self-run (authoritative, `godot_playtest_scenario` sidecar on the staged tree):
  `roster_panel_cultivation_open_close` **16/16 PASS**, hard gate `passed: True`,
  **ZERO runtime errors**.**
- Not modified: `playtest/spine_to_ending.yaml`, frozen artifacts,
  `playtest/_common.yaml`, `ROUND_SCENARIOS`, other scenarios.

## 10. `roster_panel_cultivation_open_close` red-first measurement (2026-08-31)

**Task:** `measure_roster_cultivation_red_first` — measure the red-before-green for
`roster_panel_cultivation_open_close.yaml` from a REAL run (TEMPORARY RED-FIRST REVERT
protocol) and overwrite the placeholder block.

- **Baseline (un-reverted tree):** `godot_playtest_scenario(scenario="roster_panel_cultivation_open_close")`
  → **16/16 PASS**, hard gate `passed: True`, **zero** runtime errors.
- **Revert applied:** `open()` body neutralized to a no-op (`pass`), each line commented
  with `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`. `RosterOpenButton` still exists;
  its `pressed` signal still delivers into the no-op.
- **Measured four values (VERBATIM from the run's report):**
  - fail frame: **50**
  - first assertion: **`RosterPanel.is_open: is_open == true`**
  - exact error: **`observed=false`**
  - red-before-green: **4** (the four boot asserts at f30: visible / phase / month / RosterOpenButton.visible)
- **Run summary (reverted):** 14/16, two FAILs (f50 `RosterPanel.is_open`, f120 `RosterPanel.is_open`),
  two runtime `push_error`s (`aim: node is not visible in tree: RosterCloseButton` — expected: the
  close button stays hidden when `open()` is a no-op).
- **Restore:** `scripts/ui/roster_panel.gd` restored byte-identical; re-run confirmed **16/16 PASS**,
  hard gate `passed: True`, zero runtime errors.
- **Overwrite:** placeholder block at lines 32–38 of `playtest/roster_panel_cultivation_open_close.yaml`
  replaced with the measured four values + method note. `name:`/`description:`/`scene:`/timeline
  bytes untouched.
- Not modified: `playtest/spine_to_ending.yaml`, frozen artifacts, the already-measured
  `roster_panel_item_nail.yaml` RED-FIRST block.
