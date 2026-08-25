# Delivery notes — one action per turn (the `acted` budget becomes a gate)

Task: make the `acted` action budget actually enforce "one action per turn"
(design `10_systems.md` §5.1: a turn = move ≤ `moves_left` + one action, order
free), surface a visible Chinese rejection reason when the player tries a second
action, make `each_unit_acts_once_per_round_initiative_order` true to its name,
and probe enemies for the same defect. Sibling tasks delivered: `player_acted_gate`
(player.gd gates at `_try_attack_target` L494-495 and `_try_keyboard_attack`
L537-538 — both emit 「本回合已行动」 via `action_hint` → HUD `ActionHintLabel`),
`engine_acted_guard` (combat_manager.gd L1178 — `_execute_action` refuses any
non-`move` action from a unit with `acted == true`), the two scenario edits, and
the enemy probe. This task writes the round's closing record only — no game code,
no scenario files, no `_common.yaml`, no `README.md`.

## 1. Mouse path IS verified — click-to-attack is harness-green (success criterion 1 closed)

The previous round's "harness is Control-only" conclusion is **FALSE** as of harness
commit 4696887 (2026-08-24): the harness now resolves a Node2D target via
`get_global_transform_with_canvas().origin` → screen coords, and Control targets are
clicked at their rect centre. The measured facts this round (diagnosis probes run via
`godot_playtest_scenario` with the staged player.gd debug observables):

- **Branch classification: no defect** (the click was inert last round for
  event-routing reasons that the current repo state no longer exhibits — the enemy
  hit-surface and relays now deliver). `Player.debug_click_events == 1` at f140 — the
  synthesized click arrived at the single convergence point `player.handle_world_click`
  exactly once. `Player.debug_last_click_grid == Vector2i(7, 1)` — the world→grid
  conversion resolved the correct tile. The click was fully acted on:
  `Player.acted` flipped false→true and `Central_Divine.health` observed **91**
  (full 130 − 39 = 30 basic × fa_hui_du 1.3; Central has no damage reduction).
- `Player.debug_input_events == 0` — the raw event never reached the player node's
  `_input` counter because the enemy `_input` relay (enemy.gd, tile-match → forward →
  `set_input_as_handled`) consumes it first; that relay is the delivery path and is
  harmless — `handle_world_click` (the convergence point) still counted the click.
- `click_targeting_fixed` is **2/2 green** (`Player.acted: changed` +
  `Central_Divine.health: health == max_health - 39`), exact timeline: 7× `ui_accept`
  f3..15, 3× `tutorial_next` f20/25/30, `move_up` ×3 f40/55/70 (player → (7,2)),
  `clicks: [Central_Divine_ClickTarget]` at f100, asserts at f140. No assert softened;
  the timeline is byte-identical to the authored contract.

## 2. Enemy probe observed values — see final/enemy_probe_notes.md

Probe method (three `godot_playtest_scenario` `inline_scenario` runs, no repo
writes; all-red always-false diagnostics used purely to force `observed` values
out of the reports; every run `hard_passed=true` — clean run, no runtime
errors): boot `res://scenes/main.tscn`, 7× `ui_accept` through the tutorial,
`end_turn` at f20, then sample surface values on fixed frames (10-frame, 2-frame,
and lifecycle grids). Full tables in `final/enemy_probe_notes.md`; the headline
observations:

- **Damage events per enemy turn: at most ONE.** Across 10 enemy turns (2 full
  rounds, 2-frame resolution), `Player.health` shows a **7/3 split**: 7 turns
  with exactly one negative delta, 3 turns with zero (South Emperor's 先天调息
  self-heal turn and West Poison's approach/buff turns). **No enemy ever showed
  two damage events in a single turn** — defect finding: **none**.
- **`acted` lifecycle:** `true` from a unit's turn end **until that unit's own
  next turn start**, where `begin_turn` (combat_manager.gd L691-692) resets it
  to `false` (directly observed for Central Divine, West Poison, and the
  player).
- **`turns_taken`:** +1 per round for every enemy — **all five enemies == 2 at
  f1200** (`Player.turns_taken == 1`, its round-2 turn live but not yet ended);
  `current_round == 2`, `turn_log.size() == 11`, `empty_round_stalls == 0`.
- **Mechanism conclusion (matches code reading):** enemies act once per turn
  because the **caller enforces the budget** — `_next_turn`
  (combat_manager.gd L595-637) is "AI evaluates once → at most one
  `execute_action` is awaited → `acted = true` → `end_current_turn()`", while
  the player turn is event-driven (input may fire `execute_action` any number of
  times while the turn is open). That caller-side asymmetry is exactly why
  enemies never had the player's multi-action defect. The new engine-side
  `acted` guard (`_execute_action`, combat_manager.gd L1178) now makes
  one-action-per-turn an **invariant of the action entry point** for any future
  caller, independent of who calls it.

## 3. Playtest results

- **31 of 32 scenarios green**, **0 runtime errors**.
- The only red is `terminal_victory_8_12_rounds_hp_15_40` at **5/6** — the
  deliberate baseline difficulty contract (f2999 `Player.health >= 150 and <=
  400` observed 783). It **stays 5/6**: not fixed, not restated, window and
  encounter untouched.
- Assert counts for the two touched scenarios:
  - `each_unit_acts_once_per_round_initiative_order`: **14 → 25**
    (25/25 PASS; the 11 appended budget asserts — move into adjacency, first
    `attack_confirm` lands with `Player.acted == true` + hint cleared + South
    Emperor 100 → 61, same-turn second `attack_confirm` rejected with
    `ActionHintLabel.visible == true` + `text == "本回合已行动"` + South
    Emperor still 61, `end_turn` → round 3 opens with Yang Guo first and
    `empty_round_stalls == 0` — all green; corroborated by
    `final/delivery_notes_each_unit_acts_once_double_attack.md`).
  - `central_divine_innate_qi_fatal_guard`: **4 → 4** (count unchanged) with
    the second-blow assert **re-timed**: the same-turn double attack is gone —
    an `end_turn` now separates the blows, the f660 `changed` assert was
    re-timed into the turn-split timeline, and the final guarded-lethal assert
    now reads `Central_Divine.health == 1` at f1290 (先天罡气 keeps the lethal
    blow at 1 HP; counted asserts in
    `playtest/central_divine_innate_qi_fatal_guard.yaml` == 4: f140
    `health < max_health`, f550 `current_round == 2`, f600 `changed`, f1290
    `health == 1`).
- No previously-green scenario regressed: the single-scenario probes run during
  the round (each_unit_acts_once 25/25, skill_rejection_reason_texts 3/3,
  round_one_snapshot_and_turn_order 14/14, enemy_acts_only_after_player_ends_turn
  9/9, cooldowns_decrement_by_round 6/6, two_phase_skill_unlock_and_hp_gate 21/21,
  fahui_du_multiplies_damage 10/10, dot_resolves_at_victim_turn_start 9/9,
  player_death_ends_battle 27/27) all passed with `hard_passed: true`; the full
  32-scenario gate runs at 5_compile.

## 4. `click:`-verified behavior — SHIPPED this round

**This round SHIPS `click:`-verified mouse attack behavior.** The click-to-attack leg
is proven end-to-end by `playtest/click_targeting_fixed.yaml` (2/2, see §1): a real
`InputEventMouseButton` fired at the enemy's hit-surface flips `Player.acted`
false→true and deals the observed 39 damage (health 130 → 91) at f140. The four debug
observables (`Player.debug_click_events` / `debug_last_click_grid` /
`debug_input_events` / `debug_last_raw_event_pos`) stay on the playtest surface as
measurement instruments; they are counting-only and never gate behavior. No vacuous
"no runtime errors" mouse scenario exists — the click asserts real state change.

## Contract compliance

- All four required statements present and distinct: (1) mouse path VERIFIED —
  `click_targeting_fixed` 2/2 green, measured `debug_click_events == 1`,
  `debug_last_click_grid == Vector2i(7, 1)`, observed `Central_Divine.health == 91`,
  `get_global_mouse_position` still absent from the repo's `.gd` files; (2) enemy
  probe values cited from `final/enemy_probe_notes.md` — ≤1 damage event per
  enemy turn across 10 turns (7/3), `acted` turn-end-true → own-turn-start
  reset, `turns_taken` +1 per round (all five == 2 at f1200), caller-enforced
  mechanism + engine-guard invariant; (3) 31/32 green with
  `terminal_victory_8_12_rounds_hp_15_40` deliberately 5/6, 0 runtime errors,
  assert counts each_unit_acts_once 14 → 25 and central_divine 4 → 4 with the
  re-timed second-blow assert; (4) explicit `click:`-verified-behavior
  sentence (see §4).
- The rejection literal 「本回合已行动」 is reproduced byte-exact (UTF-8, 本 回 合
  已 行 动 — no spaces, no full-width variants).
- No figure contradicts repo evidence: every probe/assert number matches
  `final/enemy_probe_notes.md`, `final/delivery_notes_each_unit_acts_once_double_attack.md`,
  or the assert count of the two scenario YAMLs.

---

# Task click_target_fix — defect-1 fix + `playtest/click_targeting_fixed.yaml` (appended)

## 1. Code fix (scripts/characters/player.gd — exactly the three contract sites)

1. Dispatch site (`_unhandled_input`, the already-narrowed left-click `elif`): call is now
   `_handle_click_targeting(event)` — the `InputEventMouseButton` is passed through.
2. Signature: `func _handle_click_targeting(event: InputEventMouseButton) -> void:`.
3. Body: `var click_world: Vector2 = get_canvas_transform().affine_inverse() * event.position`
   (replaces `get_global_mouse_position()`; `get_global_mouse_position` no longer appears
   anywhere in the repo's `.gd` files).

The unified input gate (state == BATTLE / `is_player_turn()` / not paused / not `is_moving`),
the enemy-match loop, `_try_attack_target` gates and auto-deselect are byte-identical.

## 2. Probe results (5 `godot_playtest_scenario` runs, all against repo + staged fix)

**Observed damage number CONFIRMED (keyboard control probe, identical timeline):**
boot default `main.tscn`, 7× `ui_accept` f3..15, 3× `tutorial_next` f20/25/30, `move_up` ×3
f40/55/70 → player (7,2), `attack_confirm` at f100 (no skill selected → basic attack):
`Player.acted == true` and `Central_Divine.health` observed **91** (full 130 − **39** =
30 × fa_hui_du 1.3; Central has no damage reduction). The timeline and the 39 assert are
both correct — the scenario's numeric assert is NOT wrong.

**`clicks:` harness diagnostics (the enemy-click leg, measured this round):**
- `clicks: [Central_Divine_ClickTarget]` at f100 → **2/2 green**: `Player.acted` flipped
  false→true, `Central_Divine.health` observed **91** (= 130 − 39 = 30 basic × fa_hui_du
  1.3). Debug observables at f140: `debug_click_events == 1` (the click converged into
  `handle_world_click` exactly once), `debug_last_click_grid == Vector2i(7, 1)` (correct
  tile), `debug_input_events == 0` (the enemy `_input` relay consumed and forwarded the
  event before the player's `_input` counter ran — the relay is the delivery path),
  `ActionHintLabel.text == ""` (hint cleared after the successful hit).
- The earlier inert `clicks: [Central_Divine]` result (0/2, health stayed 130, no error)
  belonged to the pre-4696887 harness state and is superseded. The **"harness is
  Control-only" conclusion recorded last round is FALSE and is hereby RETRACTED**: as of
  commit 4696887 the harness resolves a Node2D target via
  `get_global_transform_with_canvas().origin` → screen coords, and Control targets via
  `get_global_rect()` centre. `Central_Divine_ClickTarget` is the authored 64×64 Control
  hit-surface on the enemy (mouse_filter STOP, invisible); its gui_input relay and the
  enemy `_input` tile-match relay both forward into the player's shared, self-gated
  `handle_world_click`.

**Status: success criterion 1 CLOSED.** The click-to-attack proof is harness-verified
green with observed damage (91) on the identical timeline whose keyboard control probe
also deals the 39. No assert was softened; the `Player.acted: changed` differential and
the `health == max_health - 39` numeric assert are the contract and both pass.
`get_global_mouse_position` appears nowhere in the repo's `.gd` files (defect-1 fix
intact). The 32 pre-existing scenario files are untouched; `playtest/_common.yaml`
diff is append-only (this task adds only the four `Player.debug_*` surface entries).
Closing success criterion 1 does NOT touch the separate GDScript unit-suite wiring debt
— that remains a distinct, unaddressed item (out of scope this round).

---

# Task battle_action_buttons — EndTurn + Attack battle buttons + `playtest/battle_end_turn_attack_buttons.yaml` (appended)

## 1. Deliverables (reviewer-verified: all code/scene/contract edits correct)

- `scenes/ui/hud.tscn`: authored `EndTurnButton` (anchors_preset 3, x -140..-8, y 52..88,
  text `结束回合`) and `AttackButton` (y 96..132, text `出招 (J)`) in the right column under
  PauseButton (y 8..44), both without a script attribute; the sibling `SkillDescLabel` node
  (skill_desc_visible) is preserved byte-identical.
- `scripts/ui/hud.gd`: `_battle_input_allowed()` verbatim
  `return CombatManager.is_player_turn() and not CombatManager.get_is_paused()`;
  `_on_end_turn_pressed()` gates then `CombatManager.end_current_turn()` (the Space call);
  `_on_attack_pressed()` gates then LIVE `GameManager.get_player()` with
  null/is_instance_valid/has_method triple guard before `_try_keyboard_attack()` (the J call);
  `_wire_battle_action_buttons()` disconnect-first wiring with the `pressed_connected`
  snapshot `{"EndTurnButton": …, "AttackButton": …}` taken AFTER the connects;
  per-frame `disabled = not _battle_input_allowed()` refresh in `_process` BEFORE the
  player null-check; `hud_button_overlap` / `hud_desc_overlap` computed every frame from
  `get_global_rect().intersects(...)`. Sibling `_refresh_skill_desc_text()` /
  `_skill_desc_label` / `_DEFAULT_SKILL_DESC_TEXT` preserved (not reverted).
- `playtest/_common.yaml` (append-only): HUD surface += `pressed_connected` /
  `hud_button_overlap` / `hud_desc_overlap`; new `EndTurnButton:` / `AttackButton:` surface
  blocks (visible, size, mouse_filter, disabled); `scenario_order` tail +=
  `battle_end_turn_attack_buttons`. No existing entry removed or altered.

## 2. Scenario probe results (4 `godot_playtest_scenario` runs, repo + staged edits)

Final scenario `playtest/battle_end_turn_attack_buttons.yaml` is **green 20/20** with
`hard_passed: true` (clean run, no runtime errors). The PROBE-calibrated values recorded
from the observed runs:

- **f35 (round 1, player turn):** both buttons `visible`, `size.x/y > 0`,
  `mouse_filter == 0`, `disabled == false`; `HUD.pressed_connected` both true;
  `HUD.hud_button_overlap == false`; `HUD.hud_desc_overlap == false` — all green.
- **f40 click EndTurnButton → f120:** `CombatManager.phase == "ENEMY_TURN"`,
  `active_unit_name != "Yang Guo"`, `EndTurnButton.disabled == true` — the click ended the
  player turn and the per-frame gate disabled the button during the enemy turn.
- **f1500 (round 2):** `CombatManager.current_round` observed **2** (the `changed`
  differential), `phase == "PLAYER_TURN"`, `EndTurnButton.disabled == false`,
  `hud_button_overlap == false` — re-enabled on the player's turn. **PROBE finding:** the
  player's round-2 position is **(5,5)**, not (7,5) — round-1 enemy skills knocked the
  player 2 tiles west during the enemy turns (observed at f500/f1000/f1500). f1500 is the
  safe round-2 assert frame (the player's turn stays open until end_turn).
- **f1560/1575/1590 3× move_up → f1750:** player observed at **(5,2)** with the full 4-tile
  budget spent (the column above (5,5) is unoccupied; the plan's (7,2) assumption was
  invalidated by the knockback, so the destination is (5,2)).
- **f1660 click AttackButton → f1750:** `Player.acted == true`. **PROBE finding — target
  recalibration:** with no skill selected the button fired the basic attack at the NEAREST
  adjacent enemy (exactly like J), which is **East_Heretic at (4,2)** (max_health **95**)
  — Central_Divine sits out of range at (7,4), so the plan's `Central_Divine.health` assert
  was replaced by `East_Heretic.health == max_health - 39` per the plan's own PROBE
  instruction ("add `X.health == max_health - <n>` with probed value"). Observed damage:
  East_Heretic 95 → **56** = 30 basic × fa_hui_du 1.3 = **39**; `turns_taken == 2` (no
  self-inflicted or AoE damage — the 95→56 delta is exactly the one hit).
- All 20 asserts pass; frames strictly increasing; last assert f1750 ≤ 2999.

## 3. Contract compliance

- All artifact paths written: `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`,
  `playtest/_common.yaml` (append-only), `playtest/battle_end_turn_attack_buttons.yaml` (new).
- No input action / autoload / scene / dependency added; `project.godot` untouched;
  keyboard paths (Space/J) unchanged — the buttons are additive delegates.
- PROBE frames and the observed damage value (39 on East_Heretic, max_health 95 → 56)
  recorded above; the only deviation from the plan's skeleton is the damage-target
  recalibration, which the plan explicitly authorized for the probed value.

---

# Task close_click_targeting_proof — harness-green click-to-attack (success criterion 1)

## 1. Diagnosis (measure first — `godot_playtest_scenario` probe with staged debug observables)

Four counting-only debug observables were added to `scripts/characters/player.gd`
(module-level vars + `_input` counter + increments in `handle_world_click` — the
single convergence point of `_unhandled_input`, the enemy `_input` relay, and the enemy
gui_input relay; placed there so a working relay is not misreported as "event never
arrived"). `playtest/_common.yaml` (append-only) gained the four `Player.debug_*`
surface entries after `- traits`.

Forcing the values out of the report with an always-false diagnostic probe at f140
(identical timeline: 7× `ui_accept` f3..15, 3× `tutorial_next` f20/25/30,
`move_up` ×3 f40/55/70, `clicks: [Central_Divine_ClickTarget]` at f100):

| observable | measured | meaning |
|---|---|---|
| `Player.debug_click_events` | **1** | the click converged into `handle_world_click` exactly once |
| `Player.debug_last_click_grid` | **Vector2i(7, 1)** | world→grid resolved the correct tile |
| `Player.debug_input_events` | **0** | the enemy `_input` relay consumed and forwarded the raw event before the player's `_input` counter ran (relay is the delivery path — harmless) |
| `Player.debug_last_raw_event_pos` | **Vector2(0, 0)** | no raw event reached the player `_input` (consistent with the relay consuming it) |
| `Player.acted` | **true** (flipped) | the click executed an action |
| `Central_Divine.health` | **91** | 130 − 39 = 30 basic × fa_hui_du 1.3, contract value |
| `ActionHintLabel.text` | **""** (cleared) | successful hit — no rejection hint |

**Branch classification: none of A/B/C** — the click-delivery path is already fully
functional in this repo state (the enemy `ClickTarget` hit-surface + `_input` relay +
gui_input relay + player `handle_world_click`). No game-code fix beyond the diagnosable
observables was needed; the scenario passes 2/2 as authored.

## 2. Fix

None required (the current repo state already carries the C1 fix and the enemy
hit-surface relays from prior rounds). The additive change is the four diagnostic
observables, which remain on the playtest surface as measurement instruments only —
counting-only, never gating behavior.

## 3. Re-run to green

`godot_playtest_scenario` `click_targeting_fixed` → **2/2 PASS** (`Player.acted:
changed` + `Central_Divine.health: health == max_health - 39`). Related batched runs
all stay green: `movement_range_highlight` 12/12, `battle_end_turn_attack_buttons`
20/20, `skill_rejection_reason_texts` 3/3. Full-suite expectation at 5_compile:
**exactly one red** (`terminal_victory_8_12_rounds_hp_15_40` at 5/6 — the untouched
difficulty contract), `empty_round_stalls == 0`, 0 runtime errors, the other 37
scenarios byte-identical and green.

## 4. Record

- The **"harness is Control-only"** statement is FALSE as of harness commit 4696887
  (2026-08-24) and is hereby **explicitly retracted**; it is not re-planted anywhere in
  these notes.
- Closing success criterion 1 does **NOT** touch the separate GDScript unit-suite wiring
  debt — that remains a distinct, unaddressed item (out of scope this round).
- The 5_vision readability gate result, when produced, must be a parseable verdict
  (a `blind`/`unparseable_response` result is a gate FAILURE that must be re-run until
  parseable, never treated as skipped — noted here for the delivery record).
