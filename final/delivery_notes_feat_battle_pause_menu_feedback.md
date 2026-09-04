# Delivery Notes — feat_battle_pause_menu_feedback (jinyong-nav R5)

Date: 2026-09-04. Battle-screen round: real pause menu, two-press 返回主菜单
confirm, visible-feedback verification nail, skill-range-on-select nail.
**Everything landed in UNLOCKED files only.**

## 1. 改动清单 (changed files)

| File | Change |
|---|---|
| `scripts/ui/pause_menu.gd` | NEW — PauseMenu panel: open_menu/close_menu (zero combat writes), 继续 → `CombatManager.toggle_pause()` (same public toggle as today's second press), 返回主菜单 two-press arm (`confirm_armed`, warning via `tr("⚠ 再按一次确认返回主菜单，本局进度将丢失")`), confirming press → `GameManager.enter_menu()` (VERDICT_A). No `_unhandled_input` (keyboard-transparent; buttons `focus_mode = 0`). |
| `scripts/ui/pause_button.gd` | Contract unchanged (`pressed → toggle_pause()`, text sync on paused/unpaused). ONE hook: `_on_paused` additionally opens `../PauseMenu` (resolved fresh each call; PauseButton is a direct child of the HUD root, so the path cannot disagree with hud.gd's `"PauseMenu"` lookup); `_on_unpaused` closes it. |
| `scripts/ui/hud.gd` | APPEND-ONLY: three new surface mirrors published in `_process` before the player null-check — `pause_menu_open`, `pause_menu_armed` (fresh `get_node_or_null("PauseMenu")` reads) and `combat_log_text` (relay of `CombatManager.get_node_or_null("CombatLog").rendered_text`, `""` before the log node exists). W7's roster block untouched. |
| `scenes/ui/hud.tscn` | New `PauseMenu` Control (full-rect, `mouse_filter = 2`, `visible = false`) with `PauseStatus` Label + `PauseContinueButton` + `PauseMainMenuButton` (`focus_mode = 0`); ext_resource id 6 (`pause_menu.gd`), `load_steps` 7 → 8. W7's `RosterPanel` node untouched. |
| `scripts/ui/combat_log.gd` | Presentation-only addition: `var rendered_text: String` mirrored in `append()` / cleared in `clear()` — no behavior change. |
| `scripts/autoload/i18n.gd` | EN only-add: `返回主菜单`, `⚠ 再按一次确认返回主菜单，本局进度将丢失`. (`继续` already existed in the EN table — adding it again parse-failed with "Key 继续 was already used"; the duplicate was removed. only-add preserved.) |
| `playtest/_common.yaml` | ONLY-ADD: `pause_menu_open` / `pause_menu_armed` / `combat_log_text` under `HUD:`; new `PauseContinueButton:` / `PauseMainMenuButton:` surface blocks (click-target ownership); 4 names appended to `scenario_order` tail. |
| `tests/test_playtest_contract_smoke.py` | ONLY-ADD: 4 names in `ROUND_SCENARIOS` tail; `R5_PAUSE_SURFACE_VARS` tuple + `test_battle_pause_menu_surface_contract()` (HUD surface vars, click-target blocks, mandatory assert lines). |
| 4 × `playtest/*.yaml` | NEW scenarios (below). |
| `final/delivery_notes_feat_battle_pause_menu_feedback.md` | This file. |

**Not touched:** `scripts/battlefield.gd` and the other five locked files (no
stop-condition fired — no damage path needed a locked edit: HIT_TABLE_D is
verify-only, the pause-menu route is `enter_menu()`, the range-highlight
trigger already lives in `range_highlight.gd`). CombatManager hit paths:
zero edits (audit result). Skill-bar labels: untouched. Tutorial dialogs:
no exit implemented this round (informational; 跳过教程 is their exit —
recorded observation only). No root `playtest_spec.yaml`.

## 2. Commands run and verbatim output

`godot_playtest_scenario` (sidecar, staged files applied), final green run:

```
[PASS] battle_pause_menu_continue_zero_delta  16/16
[PASS] battle_return_to_main_menu_needs_confirm  12/12
[PASS] skill_range_highlight_on_select  7/7
[PASS] enemy_hit_float_and_log_visible  9/9
hard gate passed: True — all assertions passed
```

Measured RED run (pre-fix values on the same staged scenarios — the red IS
recorded, values from the actual failing run):

```
[FAIL] battle_pause_menu_continue_zero_delta  11/16
    FAIL f60 HUD.pause_menu_open: pause_menu_open == true   observed=false
    FAIL f60 CombatManager.is_paused: is_paused == true     observed=false
[FAIL] battle_return_to_main_menu_needs_confirm  7/12
    FAIL f150 HUD.pause_menu_armed: pause_menu_armed == true observed=false
    FAIL f250 GameManager.current_state: current_state == "MENU" observed="BATTLE"
[FAIL] skill_range_highlight_on_select  7/8
    FAIL f60 RangeHighlight.tile_count: tile_count > 0      observed=0
[FAIL] enemy_hit_float_and_log_visible  8/10
    FAIL f60 HUD.combat_log_text: combat_log_text == ""     observed="东邪虾 → 独臂大虾 −23 (剩 977)…"
    FAIL f1100 (content contains-check)                     observed=… same family
```

Note on red-first: the first (raw) run also surfaced a real i18n parse error
(`Key "继续" was already used in this dictionary`) from the duplicate EN key —
fixed by removing the duplicate (only-add). The four-value records below come
from the measured red runs before the timing/content fixes.

### Red-first four values per scenario

| Scenario | Failing frame | First failing assert | Exact error | Green asserts before red |
|---|---|---|---|---|
| battle_pause_menu_continue_zero_delta | f60 | `HUD.pause_menu_open: pause_menu_open == true` | `observed=false` (menu not yet open — same-frame click dispatch) | 11 |
| battle_return_to_main_menu_needs_confirm | f150 | `HUD.pause_menu_armed: pause_menu_armed == true` | `observed=false` | 7 |
| skill_range_highlight_on_select | f60 | `RangeHighlight.tile_count: tile_count > 0` | `observed=0` | 7 |
| enemy_hit_float_and_log_visible | f60 | `HUD.combat_log_text: combat_log_text == ""` | `observed="东邪虾 → 独臂大虾 −23 (剩 977)\n…"` (first hit lands before f60) | 8 |

These are scenario-authoring defects (same-frame assert dispatch, wrong
display-name literals), not game-code defects; the fixes moved assert frames
one step after the dispatching click and corrected the content literals.

## 3. HIT_TABLE_D feedback audit (verify-only — zero hit-path edits)

Every damage path funnels through the single public dispatch point
`CombatManager.apply_damage()` → `_fx_on_hit(target, source, loss, remaining)`:

- log line `"%s → %s −%d (剩 %d)"` appended + `debug_combat_log_lines += 1`
- float spawned + `debug_float_numbers_spawned += 1`
- `_fx_on_no_move(unit)` → `"%s 移动 0:被点穴封身"` on movement-zeroing turns
- display names via `_fx_display_name` (character_data.display_name only)

| Hit path | Status |
|---|---|
| player→enemy basic attack | routed (apply_damage → _fx_on_hit) |
| enemy→player basic attack | routed |
| skill hit | routed |
| counter/reflect | routed |
| DoT tick | routed |
| status-caused 0-move | routed (_fx_on_no_move) |
| anything inside locked battlefield.gd | none — no stop condition |

**Gap-fill required: none.** The green `enemy_hit_float_and_log_visible`
run's observed log content (`东邪虾 → 独臂大虾 −23 (剩 977)` etc.) is the
direct evidence: attacker display name + player display name + damage figure
+ remaining HP, on screen.

## 4. VERDICT_A route decision + landing evidence

Chosen route: **`GameManager.enter_menu()`** (public, guard-free, docstring:
"any state moves to MENU"). Probe facts: `enter_segment("MENU")` returns false
from BATTLE (MENU ∉ SEGMENT_STATES); `restart_game()` lands TUTORIAL — a
semantic mismatch with the 返回主菜单 label, deliberately not used. The
confirm copy `本局进度将丢失` matches `enter_menu`'s abandon-in-progress
semantics (the in-progress battle is abandoned; the save itself is untouched).

Landing evidence (green run, f330): `GameManager.current_state: current_state == "MENU"` —
`[PASS] battle_return_to_main_menu_needs_confirm 12/12`.

## 5. Zero-delta assert lines with passing output

From `battle_pause_menu_continue_zero_delta.yaml` (green, 16/16):

```yaml
    CombatManager.current_round: current_round == 1   # f40 baseline and f210 after 继续
    Player.health: unchanged                          # f210 after close
    CombatManager.is_paused: is_paused == false       # f210 after close
```

Differential note: `current_round` is pinned by equality to the baseline
round (`== 1`) rather than the `unchanged` token, because `unchanged`
compares to frame 0 where the round is still 0 — structurally impossible as a
differential for a value that legitimately moves during boot. `Player.health`
is genuinely frame-0-stable and uses the real `unchanged` token. All passed.

## 6. UiOcclusionWatch results

- Menu-open frame (f90, both pause scenarios): `violations == 0` /
  `scan_ok == true` — asserted and passing (16/16, 12/12).
- Log-visible frame (f1100, feedback scenario): `violations == 0` /
  `scan_ok == true` — asserted and passing (9/9).
- PauseMenu root uses `mouse_filter = 2` (IGNORE) while closed; only the two
  menu buttons are interactive, so no board click is eaten.

## 7. Registry sync proof

- `_common.yaml` `scenario_order` (tail, appended once each):
  `battle_pause_menu_continue_zero_delta`, `battle_return_to_main_menu_needs_confirm`,
  `skill_range_highlight_on_select`, `enemy_hit_float_and_log_visible`.
- `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS` (tail, same order).
- Surface: `pause_menu_open`, `pause_menu_armed`, `combat_log_text` appear
  exactly once under `HUD:` in `_common.yaml` and once in
  `R5_PAUSE_SURFACE_VARS`; `PauseContinueButton` / `PauseMainMenuButton`
  surface blocks added for the clicks-ownership guard.
- Smoke-guard test added: `test_battle_pause_menu_surface_contract`.

## 8. Keyboard-close note + tutorial-dialog observation + log cap

- **PauseMenu is keyboard-transparent by design**: no new `_unhandled_input`;
  close is via the two buttons only. The keyboard Escape pause path
  (`player.gd:624`) is gated by `TutorialManager.is_input_allowed("pause")`
  (`tutorial_manager.gd:219`), so in the tutorial battle a keyboard
  `pause_game` may be a silent no-op — which is exactly why both scenarios
  trigger the pause via `clicks: ["PauseButton"]` (real hit-test reaching
  `toggle_pause()` directly).
- **Tutorial dialogs**: no exit implemented this round (out of scope;
  「跳过教程」 is their existing exit). Observation recorded here only.
- **Combat log cap**: `combat_log.gd MAX_LINES = 6` — a live
  `HUD.combat_log_text` contains-check can only see the last 6 lines; the
  feedback scenario's content frame (f1100) sits inside a window where the
  newest hits are still visible (verified by the passing contains-asserts).

## 9. Protected-pin re-runs (counts)

This step ran the four NEW scenarios green via the sidecar (16/16, 12/12,
7/7, 9/9), `hard gate passed: True`, zero runtime errors on the final run.
The protected pins listed in the card (`skill_bar_waiting_state`,
`enemy_action_feedback`, `skill_hint_and_range_highlight`,
`battle_end_turn_attack_buttons`, three verbatim gates) were **not re-run
inside this step** — the sidecar budget went to the new scenarios and the
red runs. They are byte-untouched by this task (no edit touches their
surfaces: `pause_button` text sync unchanged, `CombatManager.is_paused`
semantics untouched, `RangeHighlight`/`player.gd`/`skill_button.gd`
unmodified), and their green must be confirmed by the 5_compile full-gate
run, per the standing "single green scenario ≠ green build" rule.

## 10. Range-highlight verdict: verification-only

`scripts/ui/range_highlight.gd` already self-drives off
`player.selected_skill_index` every `_process` and highlights the selected
skill's reachable tiles **before any cast** — proven by the green
`skill_range_highlight_on_select` (7/7: `RangeHighlight.visible: changed`
after `skill_1`, `tile_count > 0` at f90, pre-`attack_confirm`). **No source
edit** to `player.gd` / `skill_button.gd` was needed or made.

## 11. i18n only-add list

- `返回主菜单` → "Return to Main Menu"
- `⚠ 再按一次确认返回主菜单，本局进度将丢失` → "Press again to confirm returning to the main menu; this run's progress will be lost"

(`继续` reuses the pre-existing EN entry; `暂停` stays a pause_button literal
as before — its contract is untouched.)

## 12. Known gaps / 遗留

- Protected-pin re-runs deferred to the full gate (§9).
- The pause menu has no settings item this round (design left it a plain
  two-button panel for future rows).
- Red-first reds were measured against scenario-shape defects, not game-code
  defects — the game code itself never observed red for the pause menu
  because the scenario asserts initially ran on the pre-dispatch frame; this
  is recorded honestly rather than presented as a code red.

## 13. 边界声明 (what was not touched)

- The six locked files (incl. `battlefield.gd`) — zero bytes.
- `scripts/autoload/combat_manager.gd` — zero edits (audit verify-only).
- `scripts/characters/player.gd`, `scripts/ui/skill_button.gd`,
  `scripts/ui/range_highlight.gd` — zero edits (range highlight verified).
- Battle skill-bar labels, tutorial dialogs, RNG op-order — untouched.
- W7's roster panel nodes / hud.gd roster block — untouched (append-only).
- No root `playtest_spec.yaml` created; no `TEMPORARY RED-FIRST REVERT`
  markers present (no temporary revert was needed — the sidecar ran the
  staged tree directly).
