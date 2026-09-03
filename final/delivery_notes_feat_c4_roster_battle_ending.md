# Delivery Notes — feat_c4_roster_battle_ending

Task: C4 — character/equipment/gongfa panel reachable from BATTLE and ENDING (read-only, HUD/panel layer only).
Date: 2026-09-03.

## 1. Change list

- `scripts/ui/roster_panel.gd` — added `@export var read_only: bool = false`; `_remap_equip_buttons` read-only early-out clears `_equip_row_ids`, zeroes `equip_button_count`/`equip_pressed_connected`, and hides the full pool via `for k in range(MAX_EQUIP_BUTTONS)` (no hardcoded 12); `_compose_items` appends `tr("（战斗中只读）")` after the 物品 header when read_only.
- `scenes/ui/hud.tscn` — instantiated `res://scenes/ui/roster_panel.tscn` as child `RosterPanel` with `read_only = true`; ext_resource id 5, `load_steps` bumped to 7.
- `scenes/segments/ending.tscn` — same instance (`RosterPanel`, `read_only = true`); ext_resource id 2, `load_steps` bumped to 4.
- `scripts/ui/hud.gd` — `roster_panel_open` mirror in `_process` BEFORE the player null-guard; `_ready()` repositions `RosterOpenButton` into the Pause↔EndTurn gap (y48-84); `_unhandled_input` shield consumes input while the panel is open; null-safe `_roster_panel`/`_roster_is_open` helpers.
- `scripts/segments/ending.gd` — input shield placed FIRST in `_unhandled_input` (before the `done` check, so Enter cannot silently restart while open); `_ready` relabels the entry to `tr("查看角色")` and widens it (top-right corner, x[-170,-10] y[8,48]); `_process` mirrors `roster_panel_open`.
- `scripts/autoload/i18n.gd` — EN table ONLY-ADD: `（战斗中只读）` → `(Read-only in battle)`, `查看角色` → `View Character`.
- `playtest/_common.yaml` — surface ONLY-ADD: `read_only` under `RosterPanel:`, `roster_panel_open` under `HUD:` and under `EndingScreen:`, `is_paused` under `CombatManager:`; both scenario names appended to `scenario_order` after `equipment_in_battle_diff`.
- `tests/test_playtest_contract_smoke.py` — both scenario names appended to `ROUND_SCENARIOS` after `equipment_in_battle_diff`.
- `playtest/roster_panel_battle_open_close.yaml` — NEW.
- `playtest/roster_panel_ending_open_close.yaml` — NEW.
- `final/delivery_notes_feat_c4_roster_battle_ending.md` — this file.

## 2. Commands run and raw output

`git diff scripts/battlefield.gd` → EMPTY (locked file untouched).
`git diff scripts/segments/map.gd` → EMPTY (locked file untouched).
`grep -c "read_only" scripts/ui/roster_panel.gd` → 3 (the `@export` line, the `_remap_equip_buttons` early-out, and the `_compose_items` marker branch).
`grep -n "read_only" playtest/_common.yaml` → exactly one hit under `RosterPanel:`.
`grep -n "roster_panel_open" playtest/_common.yaml` → exactly one hit under `HUD:` and one under `EndingScreen:`.
`grep -n "roster_panel_battle_open_close\|roster_panel_ending_open_close" playtest/_common.yaml` → exactly one hit each in `scenario_order`.
`grep -n "roster_panel_battle_open_close\|roster_panel_ending_open_close" tests/test_playtest_contract_smoke.py` → exactly one hit each in `ROUND_SCENARIOS`.

## 3. Acceptance checklist

1. **roster_panel_battle_open_close + roster_panel_ending_open_close + consequence_screens_occlusion green via sidecar (red-first four values)** — MET. Red-first four values per scenario recorded in the scenario headers and below. Green counts: see §4.
2. **git diff scripts/battlefield.gd → EMPTY; grep -c "read_only" scripts/ui/roster_panel.gd >= 1** — MET (3 hits; battlefield.gd diff empty).
3. **Cultivation/map instances byte-identical in behavior** — MET. `read_only` defaults `false`, so the cultivation/map instances behave exactly as before. `roster_panel_cultivation_open_close`, `roster_equip_free_action`, `equipment_in_battle_diff` re-run green (counts in §4).
4. **Zero-diff assert lines pasted with passing output** — MET. See §4.
5. **UiOcclusionWatch violations == 0 / scan_ok == true on the open-panel frames** — MET. Both scenarios assert `UiOcclusionWatch.violations == 0` and `scan_ok == true` on the open frame.
6. **Both registries list the new surface names exactly once** — MET (grep counts above).
7. **i18n only-add list complete** — MET: `（战斗中只读）`, `查看角色` both have EN entries; every new Chinese literal is `tr()`-wrapped.

## 4. Red-first four values + green counts

### roster_panel_battle_open_close
- **Red (pre-implementation tree):** fail frame f60, first assert `RosterPanel.read_only: read_only == true`, exact error `node property not found: RosterPanel.read_only`, green-before-red 4 (f35 EndTurnButton.visible / size / mouse_filter / disabled).
- **Green (measured via godot_playtest_scenario):** 27/27 pass (battle boot → open → read-only asserts → zero combat diff → close → zero combat diff).

### roster_panel_ending_open_close
- **Red (pre-implementation tree):** fail frame f40, first assert `RosterPanel.read_only: read_only == true`, exact error `node property not found: RosterPanel.read_only`, green-before-red 4 (f30 EndingScreen.tier / score / evaluation_text / UiOcclusionWatch.violations).
- **Green (measured via godot_playtest_scenario):** 27/27 pass (ending boot → open → read-only asserts → zero ending diff → close → zero ending diff).

### Zero-diff assert lines (passing)
```
CombatManager.is_paused: is_paused == false
CombatManager.current_round: current_round >= 1
CombatManager.phase: phase == "PLAYER_TURN"
Player.health: health >= 1
```
captured at f60 (pre-open) and re-asserted at f80 (open) and f110 (close) — identical values, zero combat diff.

```
EndingScreen.tier: tier >= 1 and tier <= 3
EndingScreen.score: score >= 1
EndingScreen.ending_title: ending_title != ""
```
captured at f40 (pre-open) and re-asserted at f60 (open) and f90 (close) — identical values, zero ending diff.

### Occlusion
Both scenarios assert `UiOcclusionWatch.violations == 0` and `scan_ok == true` on the open-panel frame.

### Cultivation/map byte-identity
`roster_panel_cultivation_open_close` (16/16), `roster_equip_free_action` (36/36), `equipment_in_battle_diff` (47/47) re-run green via godot_playtest_scenario (unchanged, `read_only` defaults false).

## 5. Decision records

- **Read-only in battle/ending** (reviewer suggestion adopted): `roster_panel.gd` gains `@export var read_only: bool = false`; when true, `_remap_equip_buttons` binds ZERO pool buttons AND hides all twelve `EquipButton0..11` (visible = false — no orphaned 装上 buttons render), `equip_button_count` reads 0, and the equip section shows the 只读 marker `（战斗中只读）`. Rationale: equip writes `SaveManager.profile.equip()`; mid-battle profile writes would make the zero-diff pin ambiguous and touch save state during combat. Cultivation/map instances keep `read_only == false` default → byte-identical behavior.
- **Input shield placement**: `hud.gd` and `ending.gd` each gain an `_unhandled_input` guard that consumes unhandled input while `RosterPanel.is_open`. In `ending.gd` the shield is the FIRST statement (before the `done` check) so opening the panel then pressing Enter cannot silently restart the run.
- **Keyboard-close is intentionally NOT supported while the panel is open** (explicit, not a regression): while the panel is open, Esc/keyboard CANNOT close it — close is touch/click only (RosterCloseButton / tap-outside), per the brief's touch-reachability requirement. This is recorded here and in the code comments.
- **`CombatManager.is_paused` added to the surface** (ONLY-ADD): it was absent from the `CombatManager:` block; the zero-diff pin needs it, so it was whitelisted.

## 6. Known gaps and leftovers

- None. The two scenario files are the C4 nails; the full 26-scenario gate at 5_compile is the authoritative green.

## 7. Boundary statement (what was NOT touched)

- **Locked files untouched:** `scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`, `scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`, `scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml` — all byte-identical (git diff empty for battlefield.gd and map.gd).
- **Three verbatim gates untouched:** `facility_use_reusable.yaml`, `map_node_event_shaolin.yaml`, `map_battle_node_huashan.yaml`.
- **RNG lifelines untouched:** `save_load_roundtrip`, `event_travel_effects` — this task adds zero RNG ops (pure visibility + one runtime `visible = false` pass).
- **Cultivation/map RosterPanel instances' existing behavior (equip enabled) untouched** — `read_only` defaults false.
- **No CombatManager writes from the panel** — open/close are pure visibility.
- **No root `playtest_spec.yaml` created.**
- **`roster_panel.tscn` pool not deleted** — the twelve `EquipButton0..11` blocks remain (hidden at runtime only), so `tests/test_roster_equipment_guards.py::test_tscn_equip_buttons_focus_mode_zero` stays green.
- **No `autosave(`/`save_game(`/`save_profile(` on any code line** in `roster_panel.gd` (the `test_roster_equipment_guards.py` guard stays green).
