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

## 1. Mouse path is NOT verified this round

The reviewer **WITHDREW the both-legs requirement** after a measured inert
`click:` probe (SOTA commits a694e81 / 4696887): a real `click:` on the enemy
tile — with the player walked into adjacency and `skill_1` selected — produced
**0/2 with NO error anywhere** (`Central_Divine.health` full, `Player.acted ==
false`). The player's battle mouse path does not use the clicked node:
`_handle_click_targeting()` (player.gd) reads `get_global_mouse_position()` — a
viewport-cached pointer that synthesized events cannot update (mechanism
inferred, harness limitation recorded in commit 4696887). The same timeline with
keyboard `attack_confirm` is green, so the preconditions were fine — the
inertness is in the click itself.

Consequently the acceptance assertion exercises the **keyboard `attack_confirm`
path ONLY**, and **this round claims NO mouse-path verification**: the mouse
attack leg is untestable with the current harness and its behavior is neither
asserted nor claimed. Do not read anything in this round's results as evidence
about the mouse path.

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

## 4. No `click:`-verified behavior

**This round ships NO `click:`-verified behavior of any kind, and no
mouse-interaction scenario asserting only 'no runtime errors' was shipped.**
The harness click defect measured this round (0/2, zero errors) is **silent**:
a mouse scenario asserting only 'no runtime errors' would pass vacuously against
it — the exact failure shape this repo keeps falling into — so neither a
`click:`-based rejection assert nor such a vacuous mouse scenario appears
anywhere in this round's contract. The rejection is proven through the keyboard
`attack_confirm` path only; the mouse attack leg is recorded as an unverified
debt (fix direction for a downstream round: make `_handle_click_targeting()`
use the `InputEventMouseButton` coordinates it already receives instead of
re-querying `get_global_mouse_position()`).

## Contract compliance

- All four required statements present and distinct: (1) mouse path NOT
  verified — commits a694e81/4696887, 0/2 no-error probe,
  `get_global_mouse_position()`, keyboard `attack_confirm` only; (2) enemy
  probe values cited from `final/enemy_probe_notes.md` — ≤1 damage event per
  enemy turn across 10 turns (7/3), `acted` turn-end-true → own-turn-start
  reset, `turns_taken` +1 per round (all five == 2 at f1200), caller-enforced
  mechanism + engine-guard invariant; (3) 31/32 green with
  `terminal_victory_8_12_rounds_hp_15_40` deliberately 5/6, 0 runtime errors,
  assert counts each_unit_acts_once 14 → 25 and central_divine 4 → 4 with the
  re-timed second-blow assert; (4) explicit no-`click:`-verified-behavior
  sentence.
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

**`clicks:` harness diagnostics (the enemy-click leg):**
- `clicks: [SkillButton1]` at f85 → `Player.selected_skill_index` observed **0** — the
  harness delivers a real click at a Control's rect center (button `pressed` fired).
- `clicks: [Central_Divine]` at f100 (enemy at grid (7,1), node at (480,96)) → **completely
  inert**: `Player.acted` stayed false, `ActionHintLabel.text` stayed `""` (so
  `_try_attack_target` never ran with a matched enemy — no rejection hint either),
  `Central_Divine.health` stayed 130. No runtime error (run hard-passed).
- `clicks: [HealthBar]` → hard runtime error revealing the mechanism:
  `"click: node has mouse_filter=IGNORE (cannot be hit): HealthBar"` — the harness targets
  **Control nodes via `get_global_rect()` + `mouse_filter`**; it cannot compute a click
  point on the enemy's grid tile for a bare `Node2D` (the enemy node is `Node2D` with a
  `Sprite2D` child; its sprite visual centre sits off the tile, so no tile-based click is
  produced and nothing reaches `_handle_click_targeting`).

**Status: scenario authored as the target contract; fix correct but unproven-by-harness.**
The `clicks:` node-targeting capability is **Control-only** in the harness as it exists
today (README debt #2: "the harness has no coordinate input"; this task's probe extends
that: Control clicks work, Node2D clicks do not). The enemy-click leg of
`click_targeting_fixed.yaml` therefore cannot be driven green by the harness, so this task
claims **NO harness-verified mouse-path attack**: the click-to-attack proof awaits either a
coordinate-capable `clicks:` key or a Control hit-surface on enemies (out of scope —
task contract allows code edits only in `scripts/characters/player.gd`). What IS verified:
the fix compiles/parses clean, the keyboard path on the identical timeline proves the
preconditions (39 damage), and the `Player.acted: changed` differential + the
`health == max_health - 39` numeric asserts remain the contract for when the harness can
hit the tile. The 32 existing scenario files and `playtest/_common.yaml` are untouched
(byte-identical); `click_targeting_fixed.yaml` is the only added scenario file.

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
