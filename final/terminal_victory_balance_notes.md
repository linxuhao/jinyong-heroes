# Balance notes — fix_terminal_victory_balance (tutorial win at 15–40% HP)

Round: **jinyong-balance**, 2026-08-26. Closes the only sanctioned balance-deferral
scenario `playtest/terminal_victory_8_12_rounds_hp_15_40` (5/6 red at `Player.health`
`observed=783`, outside the 15–40% window). This is the design-sanctioned exception
to the "no value changes" round rule (`design/00_roadmap.md`: this scenario is a
"number is the contract" scenario, allowed to change with balance work).

## 1. Problem

- Scenario is the difficulty-spec contract: victory in 8–12 rounds with the player at
  **15%–40%** of `max_health` (`design/10_systems.md §5.3`). Assert
  `health >= max_health * 0.15 and health <= max_health * 0.40`, with `max_health ==
  1000` since the 2026-08-24 balance change.
- Baseline (pre-fix, measured): final `Player.health` **783/1000 (78.3%)** at win —
  the tutorial was far too easy (player wins too healthy).
- The HP window must NOT be widened; the encounter must be tuned.

## 2. Knobs (survival side only — never the player's damage output)

- `max_health` (1000) and the player's ×1.4 skill base damages are **NOT knobs**; the
  fight must stay winnable inside 12 rounds.
- Two survival knobs in `scripts/autoload/combat_manager.gd` (the task card's mention
  of `battlefield.gd` is corrected here — the knobs live in `combat_manager.gd`; the
  five masters' `attack_damage` in `battlefield.gd` is the secondary/second-choice knob
  and was **not** needed this round):
  1. 神雕之力 per-round regen literal (`begin_turn`, ~L727):
     `apply_heal(unit, 0)  # round(0 * 1.3)` — doc base **0** (code stores the
     ×1.3-cooked engine value; base 0 → literal 0).
  2. 神雕之力 melee damage reduction literal (`_damage_reduction`, ~L1786):
     `dr += 0.1  # −10% melee DR` (flat defense-side fraction — never × the fhd
     multiplier, per `10_systems.md §4.3`).

## 3. Tuning path (one number per full-suite probe; measured)

| Step | Change | Measured final `Player.health` | In window? |
|---|---|---|---|
| 0 | baseline (regen 26, DR 0.5) | 783 | no (78.3%) |
| 1 | regen 20 → **0** (base) | 549 | no (54.9%) |
| 2 | + melee DR 0.5 → **0.1** | **349** | **yes (34.9%)** |

`current_round` stays in [8, 12] and `current_state == "WON"` throughout (the player's
damage output is unchanged, so enemy-kill speed — and thus fight length — is unchanged;
only survival moved). 349 sits comfortably in the middle of the [150, 400] window with
margin against both bounds.

## 4. Gate results (measured this task)

- `playtest/terminal_victory_8_12_rounds_hp_15_40` → **PASS 6/6** (health 349,
  round ∈ [8,12], `WON`, `turns_taken` changed).
- `spine_to_ending` → **32/32 fully green**.
- At-risk regression sample (all green): `two_phase_skill_unlock_and_hp_gate` 21/21,
  `battle_end_turn_attack_buttons` 20/20, `each_unit_acts_once_per_round_initiative_order`
  25/25, `player_death_ends_battle` 27/27, `health_bar_numbers` 5/5,
  `round_one_snapshot_and_turn_order` 14/14, `fahui_du_multiplies_damage` 10/10,
  `dot_resolves_at_victim_turn_start` 9/9.
- The injection scenarios (`two_phase_skill_unlock_and_hp_gate`, `health_bar_numbers`,
  `round_one_snapshot_and_turn_order`, `battle_end_turn_attack_buttons`) use
  `debug_damage_player`, which drives the player to 40% via `apply_damage(...,
  ignore_dr=true)` — so they are unaffected by the DR/regen change; measured green.
- `playtest/*.yaml` and `tests/*` are **untouched** (no assert edited, no threshold
  loosened).

## 5. Doc sync (same batch as the code — no drift)

`design/20_content.md` §1 updated to the shipped numbers in the same edit:
- 气血 **500 → 1000** (code has been 1000 since 2026-08-24; the doc had never caught up).
- 神雕之力 per-round regen base **20 → 0** (code literal = round(0 × 1.3) = 0).
- 近战减伤 **−50% → −10%** (code `dr += 0.1`).
- The L36–42 「为什么减免挂在近战上」 rationale block rewritten to the new values and
  the new tuning story (survival surplus trimmed rather than enemy damage raised into a
  death spiral).

`design/99_changelog.md` — appended one `jinyong-balance` row with the final numbers and
the measured tuning path (783 → 549 → 349).

## 6. Non-goals honored

- No `max_health` change (stays 1000), no player-damage change (×1.4 skill bases
  byte-identical), no five-masters stat change.
- No playtest assert file or unit test modified.
- One number per full-suite probe; every red is attributable to the last change (none
  observed after step 2).
