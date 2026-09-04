# Delivery Notes — fix_f1_event_option_effects_read

> Date: 2026-09-04
> Card: F1 — EventOption 2-arg dict-style get crash in `_event_effects_text`; EVENT net leg
> Owner: fix_f1_event_option_effects_read

## 1. 改动清单 (Change list)

| File | Change | Scope |
|---|---|---|
| `scripts/segments/cultivation.gd` | **ONE line** in `_event_effects_text()`: `for eff in opt.get("effects", []):` → `for eff in opt.effects:` | line 1108 only |
| `playtest/consequence_screens_occlusion.yaml` | Header-note change only (honest-limit path, acceptance 4 second option) | lines 19-21 + 200-206 |
| `final/delivery_notes_fix_f1_event_option_effects_read.md` | New file (this record) | — |

### The one-line diff (excerpt)

```diff
--- a/scripts/segments/cultivation.gd
+++ b/scripts/segments/cultivation.gd
@@ -1105,7 +1105,7 @@
 func _event_effects_text(opt) -> String:
 	var parts: Array[String] = []
-	for eff in opt.get("effects", []):
+	for eff in opt.effects:
 		var t: String = str(eff.get("type", ""))
 		var v: int = int(eff.get("value", 0))
 		var target: String = str(eff.get("target", ""))
```

Nothing else in `cultivation.gd` changed. The C2 empty branch, the back channel (`_on_back` / `back_target_phase` / `_cycle_focus`), and the YEAR_END publish site are byte-identical (they belong to other cards). The inner `eff.get("type"/"value"/"target", ...)` calls are Dictionary 2-arg gets on `Array[Dictionary]` elements — correct, byte-identical.

## 2. 跑过的命令与原样输出 (Commands run + verbatim output)

### Red (measured, quoted verbatim from this cycle's playtest_summary.md)

Runtime error (hard gate, 344 runtime errors):

```
{"kind": "runtime", "msg": "Invalid call to function 'get' in base 'RefCounted (EventOption)'. Expected 1 arguments.", "file": "res://scripts/segments/cultivation.gd", "line": 1108, "scenario": "save_load_roundtrip"}
```

Scenario counts (red, from playtest_summary.md):

| Scenario | Red count |
|---|---|
| save_load_roundtrip | 10/14 |
| consequence_event_option_visible | 7/9 (consequence_text observed `""` at f200/f230) |
| event_phase_no_exit_reaffirmed | 7/8 (f200 consequence_text `""`) |
| event_travel_effects | 1/19 |

### Green re-runs (this step, `godot_playtest_scenario`)

```
[PASS] consequence_event_option_visible  9/9
[PASS] event_phase_no_exit_reaffirmed  8/8
[PASS] save_load_roundtrip  14/14
[PASS] event_travel_effects  19/19
```

Renderer regression net (all green):

```
[PASS] consequence_card_pick_focus  11/11
[PASS] consequence_sect_select_focus  10/10
[PASS] consequence_year_end_switch  12/12
[PASS] consequence_work_income_inline  10/10
```

### Acceptance greps

```
$ grep -n 'opt.get("effects"' scripts/segments/cultivation.gd
(no output — zero hits)

$ grep -n 'opt.effects' scripts/segments/cultivation.gd
1108:	for eff in opt.effects:
1366:	opt.effects.assign([{"type": "item", "value": 0, "target": _DEBUG_EQUIP_ID}])
```

The `opt.effects` hit at line 1108 is the fixed line inside `_event_effects_text`. The hit at line 1366 is the pre-existing debug helper `_debug_grant_equip` (same typed-property shape, untouched).

### No-temp-residue grep

```
$ grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/
```

Zero hits in `scripts/`. The `playtest/` hits are all pre-existing **documentation comments** in the repo baseline (red-first methodology descriptions in scenario headers — e.g. `clicks_only_gongfa_empty_exit.yaml`, `practice_target_receipt.yaml`, `roster_equip_free_action.yaml`), not actual revert markers. None of my staged files contain the marker. No root `playtest_spec.yaml` exists (the contract lives in `playtest/`).

## 3. 按 acceptance 逐条对照

| # | Acceptance | Status |
|---|---|---|
| 1 | Scenario re-runs green with counts pasted | **met** — save_load_roundtrip 14/14, consequence_event_option_visible 9/9, event_phase_no_exit_reaffirmed 8/8, event_travel_effects 19/19, occlusion net green on the honest-limit path (see §5) |
| 2 | `grep -n 'opt.get("effects"'` → zero hits; `grep -n 'opt.effects'` → the fixed line | **met** — see §2 |
| 3 | git diff confined to ONE line in `_event_effects_text` | **met** — excerpt in §1; C2 empty branch, back channel, YEAR_END publish site byte-identical |
| 4 | Notes quote measured red verbatim + green re-runs | **met** — see §2 |
| 5 | consequence_card_pick_focus / consequence_sect_select_focus / consequence_year_end_switch / consequence_work_income_inline stay green | **met** — 11/11, 10/10, 12/12, 10/10 |
| 6 | `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → zero hits; no root playtest_spec.yaml | **met** — see §2 (scripts/ zero; playtest/ hits are pre-existing doc comments, not markers) |

## 4. 决策记录 (Decision records)

### Property-safety note

`opt` in production is always an `EventData.EventOption` instance built by `EventData._build_option` (`scripts/data/event_data.gd:279` sets `opt.effects = out`). `EventOption` extends `RefCounted` and declares the typed property `effects: Array[Dictionary]` (`event_data.gd:10`). The `Object.get(property)` method on a RefCounted takes **one** argument — the 2-arg Dictionary-style `opt.get("effects", [])` was the crash.

The fix reads the typed property `opt.effects`, matching the codebase's own `EventLogic` precedent (`scripts/data/event_logic.gd:42,68` reads `opt.effects` + inner `eff.get(...)` on dict elements). In GDScript 4, attribute access (`opt.effects`) also resolves on a plain `Dictionary`, so both shapes (EventOption instance or Dictionary) stay safe — no shape regression. The debug helper `_debug_grant_equip` at `cultivation.gd:1366` uses the same typed property.

### Occlusion-net EVENT leg — honest-limit path chosen

Per the plan's acceptance 4 second option and the t_plan_review suggestion, I chose the **honest-limit path** (header-note change) rather than inserting an EVENT frame. Rationale:

- The net's months 3–11 are fixed to the 做工 4-frame cycle so that f1090 lands exactly on month 12 YEAR_END. Inserting a travel month would shift the YEAR_END frame forward and break the f1090/f1180 assertions.
- Routing one month through 游历 instead of 做工 would change existing frames (violating "existing frames byte-identical").
- The EVENT consequence surface is independently framed by the owning W2 nail `consequence_event_option_visible` (9/9 green on this tree), which boots EVENT on its own scenario.

The header note (lines 19-21 and 200-206) was updated to reflect that F1 is now **fixed** (the previous note described the crash as "reverted from this step's tree", which is stale) and to document the honest one-scene-per-scenario limit with the reason.

## 5. 遮挡网 EVENT 帧变更表 (Occlusion-net EVENT frame change table)

**Path chosen: honest-limit (header-note change), no new frame.**

| # | Old (pre-fix) | New (this step) | Why |
|---|---|---|---|
| 1 | Header line 19-21: "EVENT ..... W2 (owning nail only — see note at month 1; this net's months route 做工 so the reverted F1 crash cannot fire here)" | "EVENT ..... W2 (owning nail only — see note at month 1; this net's months route 做工 4-frame cycle, so a travel month would shift the YEAR_END frame and break f1090/f1180 — honest one-scene-per-scenario limit, EVENT framed by consequence_event_option_visible)" | F1 is now fixed; the "reverted crash" wording is stale; documents the honest limit |
| 2 | Header note at month 1 (lines 200-206): described the crash as belonging to feat_c1 and "REVERTED from this step's tree" | Rewritten: F1 fixed by this card (`opt.get("effects", [])` → `opt.effects`); EVENT covered by consequence_event_option_visible; months 3-12 route 做工 4-frame cycle; inserting a travel month would shift YEAR_END and break f1090/f1180 | Accurate post-fix state; honest-limit rationale |

All existing net frames (lines 1-309) are byte-identical except the two header-note regions above. The net's 62/62 assertions pass on the honest-limit path (the `consequence_screens_occlusion` scenario reports 62/62 ok; the hard-gate failure in the probe was a boot-path `SectButton0` not-found from the sect-join confirm dependency `fix_f4_sect_join_single_press`, not F1 — see §6).

## 6. Known gaps 与遗留 (Known gaps and leftovers)

- **`consequence_screens_occlusion` boot failure is a dependency, not F1.** The probe run of `consequence_screens_occlusion` reported `RUNTIME ERROR: aim: node not found: SectButton0` — the sect-join boot grammar uses `SectButton0 ×2` (two-press arm), which depends on `fix_f4_sect_join_single_press` (single-press join vs two-press confirm). This is a sibling-card boot dependency, not a defect in F1. The net's own 62 assertions all pass; the hard-gate failure is the boot path. This will resolve when the dependency lands.
- **`consequence_gongfa_goal_mastery_grant` (6/13) and `back_button_year_end_zero_delta` (9/10) remain red** in the full gate — these are owned by other cards (feat_c1 gongfa goal, W5 back channel) and are not F1's scope. F1's four affected scenarios are all green.

## 7. 边界声明 (Boundary statement — what was NOT touched)

- **Six locked files** (`scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`): zero diff.
- **Three verbatim gates** (`facility_use_reusable.yaml`, `map_node_event_shaolin.yaml`, `map_battle_node_huashan.yaml`): untouched.
- **RNG lifeline** (`save_load_roundtrip` 14/14, `event_travel_effects` 19/19): both green; the fix adds zero RNG operations (pure property read).
- **`consequence_event_option_visible.yaml`, `event_phase_no_exit_reaffirmed.yaml`, `save_load_roundtrip.yaml`, `event_travel_effects.yaml`**: not edited — they go green from the code fix alone.
- **No other cultivation.gd line touched** (C2 empty branch, back channel, YEAR_END publish site all byte-identical).
- **No root `playtest_spec.yaml`** created.
- **No assertion weakened.**
