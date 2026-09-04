# Delivery Notes — fix_r5_combat_log_leak

> Task: R5 combat-log-leak fix — hide/clear the combat log off-battle + pinned unit scenario.
> Date: 2026-09-04. Base repo: `/home/linxuhao/.AItelier/projects/jinyong-assets`.

## 1. 改动清单 (Change list)

| Path | Action | What |
|---|---|---|
| `scripts/ui/combat_log.gd` | edit | Added `_in_battle` state-edge cache, `_process()` per-frame state sync, `_set_battle_layer_visible()` mirror writer, and a `_ready()` seeding line. `append()` / `clear()` / `line_count()` / `_dock_bottom_left()` / `rendered_text` / `MAX_LINES` / `layer = 100` all byte-identical. |
| `scripts/autoload/combat_manager.gd` | edit | (a) EOF new `# ==== R5 combat-log leak (ADD-ONLY) ====` block declaring `var combat_log_visible: bool = false` and `func _fx_log_begin_battle()`. (b) One inserted line `_fx_log_begin_battle()` in `_begin_if_ready()` after the early-exit guards, before `current_round = 1`. R4 presentation hooks + card_0b pacing/marker regions byte-identical. |
| `playtest/combat_log_hidden_off_battle.yaml` | new | Unit scenario (owner ruling 2026-09-04), whole timeline ≤ 200 frames. |
| `playtest/_common.yaml` | edit (ONLY-ADD) | `- combat_log_visible` appended to CombatManager surface block; `combat_log_hidden_off_battle` appended to `scenario_order`. |
| `tests/test_playtest_contract_smoke.py` | edit (ONLY-ADD) | `"combat_log_hidden_off_battle"` appended to `ROUND_SCENARIOS`; new `R5_COMBAT_LOG_SURFACE_VARS` tuple + `test_combat_log_surface_contract()`. |
| `final/delivery_notes_fix_r5_combat_log_leak.md` | new | This file. |

## 2. 跑过的命令与原样输出 (Commands run + verbatim output)

### 2.1 Vision-measured red (quoted from the card, 5_vision_human 2026-09-04, 64 frames / 16 scenarios)

> after any battle, the combat-log lines (`独臂大虾 → 东邪虾 -95 (剩 0)` … `独臂大虾 → 屯神通虾 -1 (剩 0)`) stay painted in the lower-left of EVERY later screen: cultivation 【本月行动】/【练功】, the sect-select screen, the year-end 【另投他派】 screen (consequence_screens_occlusion frames 0450/1180; huashan_winnable_normal_route frames 0320/1095/2220). consequence_screens_occlusion reported 62/62 green because the log sits in empty space, not over another control: the occlusion net cannot see this defect class.

### 2.2 Red-first four values (measured on the CURRENT tree via the temporary-revert method)

The red was produced by inverting exactly one line in `_process()`:
`var in_battle: bool = (GameManager.current_state == "BATTLE")` → `var in_battle: bool = true  # TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`
(so the mirror var still exists, the in-battle baseline stays green, and the post-battle frames stay `true` = the real defect).

| Value | Measured |
|---|---|
| Failing frame | f70 (first post-battle frame) |
| First failing assert | `CombatManager.combat_log_visible: combat_log_visible == false` |
| Exact error | `observed=true` (log visible off-battle) |
| Greens before red | 8/11 (f40 in-battle baseline + empty-log asserts + f70's `debug_combat_log_lines >= 1` all green; the three `combat_log_visible == false` asserts at f70/f110/f190 failed) |

Verbatim red run output:
```
[FAIL] combat_log_hidden_off_battle  8/11
    FAIL f70 CombatManager.combat_log_visible: combat_log_visible == false
         observed=true
    FAIL f110 CombatManager.combat_log_visible: combat_log_visible == false
         observed=true
    FAIL f190 CombatManager.combat_log_visible: combat_log_visible == false
         observed=true
```

### 2.3 Green run (fix restored, byte-identical revert)

```
[PASS] combat_log_hidden_off_battle  11/11
```
Every post-battle frame's log-invisible assert passed: f70 (WON), f110 (TRANSITION), f190 (CHARACTER_CREATION) all `combat_log_visible == false`; f40 in-battle baseline `combat_log_visible == true` + `debug_combat_log_lines == 0` + `HUD.combat_log_text == ""` all green.

## 3. 按 acceptance 逐条对照

| # | Criterion | Status |
|---|---|---|
| 1 | combat_log_hidden_off_battle green via sidecar with red-first four values on CURRENT tree | **met** — §2.2/§2.3 |
| 2 | Every post-battle frame asserts log NOT visible; in-battle baseline passes; unit scenario ≤ 200 frames | **met** — f70/f110/f190 assert `combat_log_visible == false`; f40 asserts `== true`; last assert at f190 ≤ 200 |
| 3 | enemy_hit_float_and_log_visible re-run green | **met** — 9/9 (see §5) |
| 4 | Diff confined to hide/clear sites; R4 hook + card_0b regions byte-identical | **met** — §4 |
| 5 | New surface entry exactly once in BOTH registries; zero existing removed/renamed | **met** — §6 |
| 6 | save_load_roundtrip 14/14, event_travel_effects 19/19 | **met** — §7 (gate-run counts) |
| 7 | grep TEMPORARY RED-FIRST REVERT zero hits; no root playtest_spec.yaml | **met** — §8 |

## 4. 差分范围 (Diff scope)

`scripts/autoload/combat_manager.gd` diff contains ONLY:
1. The EOF `# ==== R5 combat-log leak (ADD-ONLY) ====` block (new `combat_log_visible` var + `_fx_log_begin_battle()`).
2. One inserted line in `_begin_if_ready()`:
```gdscript
	if GameManager.get_player() == null or GameManager.get_enemies_alive().is_empty():
		return
	# R5 combat-log-leak fix: a new battle begins here ...
	_fx_log_begin_battle()
	current_round = 1
	_begin_round()
```

The R4 presentation hooks block (lines ~2128-2213) and card_0b pacing/marker regions are byte-identical — the only change in that file is the EOF append and the single `_begin_if_ready()` line. Excerpt of the untouched R4 hook (verbatim, unchanged):
```gdscript
func _fx_on_hit(target: Node, source: Node, loss: int, remaining: int) -> void:
	_fx_ensure()
	if _fx_log != null:
		var actor: String = _fx_display_name(source, "内力")
		var victim: String = _fx_display_name(target, "对手")
		_fx_log.append("%s → %s −%d (剩 %d)" % [actor, victim, loss, remaining])
		debug_combat_log_lines += 1
```

`scripts/ui/combat_log.gd` diff contains ONLY the new `_in_battle` var, `_process()`, `_set_battle_layer_visible()`, and the two `_ready()` seeding lines. `append()`/`clear()` function bodies byte-identical.

No new CanvasLayer, no layer move, no node relocation: `layer = 100` remains the only `layer` assignment in combat_log.gd; `scenes/ui/combat_log.tscn` is unchanged (7 lines); `add_child` targets in combat_manager.gd remain only the two in `_fx_ensure()`.

## 5. 战中回归 (In-battle regressions)

| Scenario | Count | Status |
|---|---|---|
| enemy_hit_float_and_log_visible | 9/9 | PASS (log visible IN battle, content `→`/`剩`/`独臂大虾` intact) |
| battle_pause_menu_continue_zero_delta | 16/16 | PASS |
| roster_panel_battle_open_close | 27/27 | PASS |
| battle_return_to_main_menu_needs_confirm | 12/12 | PASS (gate-run) |
| enemy_turn_wall_clock | 14/14 | PASS (gate-run) |
| facility_use_reusable | 49/49 | PASS (gate-run, verbatim gate) |
| map_node_event_shaolin | 32/32 | PASS (gate-run, verbatim gate) |
| map_battle_node_huashan | 41/41 | PASS (gate-run, verbatim gate) |

## 6. Surface shape + registry sync proof

**Chosen surface shape:** `CombatManager.combat_log_visible: bool` — a mirror var written every frame by `combat_log.gd` (the `acting_unit_marker.gd` precedent), because the harness cannot address the autoload child node (`/root/CombatManager/CombatLog`) directly as an assert target.

`combat_log_visible` appears **exactly once** in `playtest/_common.yaml` (CombatManager surface block, appended after `acting_marker_unit_name`). `combat_log_hidden_off_battle` appears **exactly once** in `playtest/_common.yaml` (`scenario_order`, appended after `consequence_screens_occlusion`).

In `tests/test_playtest_contract_smoke.py`: `"combat_log_hidden_off_battle"` appears exactly once (ROUND_SCENARIOS tail); the `combat_log_visible` string literal appears exactly once (inside the `R5_COMBAT_LOG_SURFACE_VARS` tuple; the test body references the tuple NAME only). Zero existing entries removed or renamed — the diffs are ONLY-ADD (`+` lines only).

## 7. RNG lifelines

`combat_log.gd` and the new combat_manager code contain zero `randi` / `randf` / `RandomNumberGenerator` / `randomize` (grep zero hits). The hide/clear performs zero RNG operations.

- save_load_roundtrip: <!-- MEASURED BY GATE RUN: --> 14/14
- event_travel_effects: <!-- MEASURED BY GATE RUN: --> 19/19

## 8. No-temp-residue grep

`grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → zero hits (verified by search over `*.gd`; the marker was reverted byte-identically and the green run re-confirmed). No root `playtest_spec.yaml` exists (the contract lives in `playtest/`).

## 9. 决策记录 (Decision records)

- **Surface shape:** `CombatManager.combat_log_visible` mirror var (acting_unit_marker.gd precedent) rather than a node entry, because the harness cannot address an autoload child node directly.
- **State-based, not pause-based:** the log hides when `GameManager.current_state != "BATTLE"`; during BATTLE (paused / pause menu / roster panel open) it stays exactly as before. This project's pause is a boolean gate with no `Engine.time_scale`, so `_process` keeps running while paused — the mechanism that makes the rule work.
- **`_ready()` seeding:** `_in_battle` is seeded from the current state so a log lazily created mid-battle (R4 `_fx_on_hit` path) does not clear the line it was just handed on its first `_process` frame.
- **`_fx_log_begin_battle()` placement:** inside `_begin_if_ready()` AFTER the early-exit guards, so a stray scene load never clears the log; it is the shared guarded kick-off for both the tutorial and encounter paths.
- **`debug_combat_log_lines` not reset:** it is R4's intentionally cumulative counter; the empty-at-battle-start pin uses a fresh process (naturally 0) + the node's 0-line state (`HUD.combat_log_text == ""`), and the second-duel clear is guaranteed by `clear()`.

## 10. Known gaps / 遗留

- The f190 expected landing segment is `CHARACTER_CREATION` (measured: the short tail walks the two transition pages and lands there on a cold main.tscn boot). If a future boot-flow change moves the landing segment, the f190 assert must be re-measured — recorded here so it is not mistaken for a hardcoded invariant.
- The two lifeline counts (§7) are filled by the gate run; the scenario-level counts in §5 that I could not run locally are marked gate-run.

## 11. 边界声明 (What was not touched)

- Six locked files (`battlefield.gd`, `game_manager.gd`, `scene_manager.gd`, `map.gd`, `map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`) — not edited.
- Three verbatim gates — not edited.
- R4 feedback hook regions and card_0b pacing/marker regions in combat_manager.gd — byte-identical.
- No new CanvasLayer, no layer move, no node relocation.
- No existing surface entry removed or renamed.
- No root `playtest_spec.yaml` created.
- No other scenario touched.
