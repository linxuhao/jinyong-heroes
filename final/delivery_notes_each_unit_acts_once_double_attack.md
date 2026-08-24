# Delivery notes — each_unit_acts_once_double_attack_scenario

Task: extend `playtest/each_unit_acts_once_per_round_initiative_order.yaml` so the
scenario name ("each unit acts once per round") is backed by an actual BUDGET
assertion — a same-turn second `attack_confirm` must be rejected with
「本回合已行动」 — not just turn-order asserts. Depends on the sibling tasks
`player_acted_gate` (player.gd `acted` gate at `_try_attack_target` L494 and
`_try_keyboard_attack` L537) and `engine_acted_guard` (combat_manager.gd L1178),
both already delivered in the repo.

## What was changed

**One file, appended entries only:** `playtest/each_unit_acts_once_per_round_initiative_order.yaml`.
The 14 pre-existing assertions (2 at f30 + 12 at f1200) and the entire pre-f1200
timeline (7× ui_accept f3–f15, end_turn f20) are byte-identical — the edit
anchored on the f1200 block's final two lines and appended after them. `name:`
and `description:` unchanged. No other file touched (no `_common.yaml`, no
GDScript, no other scenario — `central_divine_innate_qi_fatal_guard.yaml` is a
sibling task's scope and was left untouched).

## Probe (先取值,再动手) — observed values

Run via `godot_playtest_scenario` inline_scenario (real boot, byte-equivalent
copy of the scenario header + 7× ui_accept + end_turn f20), sampled at f1200
(always-false diagnostics to force `observed` out of the report):

| Unit | grid_pos @ f1200 | health @ f1200 | max_health |
|---|---|---|---|
| Player | (5, 5) | 836 | 1000 |
| East Heretic | (4, 2) | 95 | 95 |
| West Poison | (8, 2) | 115 | 115 |
| South Emperor | (5, 7) | 100 | 100 |
| North Beggar | (9, 7) | 120 | 120 |
| Central Divine | (7, 4) | 130 | 130 |

- `CombatManager.current_round == 2`, `phase == "PLAYER_TURN"`,
  `active_unit_name == "Yang Guo"`, `turn_log.size() == 11`,
  `Player.turns_taken == 1`, `Player.acted == false` (round-2 turn start reset),
  `Player.moves_left == 4`, `Player.status_names == ["init_minus_20"]`.
- **No enemy is within Chebyshev 1 of (5,5)** — nearest are South Emperor
  (5,7) and Central Divine (7,4), both at Chebyshev 2. **Move steps required.**
- Move plan: `move_down` once → player (5,6); South Emperor (5,7) is then the
  UNIQUE enemy at Chebyshev 1 (CD (7,4) is dist 2 from (5,6)), so
  `_pick_nearest_enemy_in_range(1)` deterministically picks South Emperor
  (registration order irrelevant — strictly nearest). South Emperor has **no
  damage reduction** (only North Beggar has 丐帮铁骨 −15%; SE's passive
  先天调息 is a turn-action self-heal, not a passive DR).
- First blow: basic attack = `attack_damage 30 × fa_hui_du 1.3 = 39`
  (tutorial: no traits, no buffs). SE 100 → 61 → **`<N>` = 61**
  (`round(100.0 * 61 / float(100)) == 61`). Empirically confirmed by the probe
  run (the assert itself passed).
- Rejection: second `attack_confirm` hits the `acted` gate → `action_hint`
  → `ActionHintLabel.visible == true`, `text == "本回合已行动"`; SE health
  stays 61 (nothing consumed). Empirically confirmed by the probe run.
- Round 3: after `end_turn`, `init_minus_20` (2 rounds) expires → Yang Guo
  first. Observed at f1610: `current_round == 3`,
  `active_unit_name == "Yang Guo"`, `Player.turns_taken == 2`,
  `empty_round_stalls == 0`, `Player.grid_pos == (5, 6)` (no post-hit
  displacement on SE's counter-free hit).

## Finalized appended timeline

```
- at: 1210  move_down                     (player (5,5) -> (5,6); 30-frame gap
                                           to the attack covers the 0.15s tween)
- at: 1240  attack_confirm                (A — FIRST action of round-2 turn)
- at: 1280  assert (A+40):                Player.acted == true;
                                           ActionHintLabel.text == "";
                                           South_Emperor.health % == 61 (landed)
- at: 1300  attack_confirm                (B = A+60 >= A+55 — SECOND attempt)
- at: 1340  assert (B+40):                Player.acted == true;
                                           ActionHintLabel.visible == true;
                                           ActionHintLabel.text == "本回合已行动";
                                           South_Emperor.health % == 61 (UNCHANGED)
- at: 1400  end_turn                      (C = B+100 >= B+55)
- at: 1610  assert (C+210):               current_round == 3;
                                           active_unit_name == "Yang Guo";
                                           Player.turns_taken == 2;
                                           empty_round_stalls == 0
```

Frames strictly ascending; every action→assert gap ≥ 40; the two
`attack_confirm`s are 60 apart (≥ 55); last assert 1610 ≤ 2999. Keyboard
`attack_confirm` only — **no `click:` entries anywhere** (the battle mouse path
is untestable this round: measured inert 0/2 with no error; never assert mouse
behavior with 'no runtime errors' alone — none shipped here). Health asserts use
integer percentage of max_health per roadmap rule 1, so balance drift cannot
break the math. The "health unchanged after rejection" proof is re-asserting the
same `<N>` = 61 on the post-rejection frame (harness has no `unchanged`
keyword — verified).

## Suite verification (godot_playtest_scenario probes)

- **each_unit_acts_once_per_round_initiative_order: 25/25 PASS** (14 → 25
  asserts; the 11 appended asserts all green; `hard_passed: true`, no runtime
  errors, frame cap respected).
- **skill_rejection_reason_texts: 3/3 PASS** — unaffected.
- **round_one_snapshot_and_turn_order: 14/14, enemy_acts_only_after_player_ends_turn:
  9/9, cooldowns_decrement_by_round: 6/6, two_phase_skill_unlock_and_hp_gate:
  21/21, fahui_du_multiplies_damage: 10/10, dot_resolves_at_victim_turn_start:
  9/9, player_death_ends_battle: 27/27 — all PASS.**
- **terminal_victory_8_12_rounds_hp_15_40: 5/6** — the deliberate baseline
  (f2999 `Player.health >= 150 and <= 400` observed 783); unchanged, stays 5/6.
- **central_divine_innate_qi_fatal_guard: 4/4 currently green** in this repo
  state — its same-turn double attack is now nominally gate-rejected, but its
  `changed` asserts still pass because the harness comparator evaluates against
  the f140 sample (CD 71 → 32 after the round-2 blow = "changed" both times).
  Its proper two-turn split is the **sibling task's scope** (C5 in
  step2_design) and was deliberately left untouched per the task card.

The full 32-scenario gate runs at 5_compile; every probe here reported
`hard_passed: true` (clean run, no runtime errors, no timeout). This task's
change is a single YAML file — each scenario runs in its own fresh process, so
no other scenario's result can shift from this edit.

## Contract compliance

- Byte-identity: 14 existing asserts + pre-f1200 timeline unchanged (edit
  anchored on the last two f1200 lines, content preserved verbatim).
- Assert count 14 → 25 (≥ 24 required).
- Surface/actions: only whitelisted keys (`Player.acted`, `ActionHintLabel.text`
  /`.visible`, `South_Emperor.health`/`max_health`, `CombatManager.current_round`
  /`active_unit_name`/`empty_round_stalls`, `Player.turns_taken`) and whitelisted
  actions (`move_down`, `attack_confirm`, `end_turn`). Zero `_common.yaml`
  changes.
- Frame rules: ascending; gaps ≥ 40 (action→assert); attacks 60 apart; cap 2999.
- Target South Emperor — no damage reduction; `<N>` = 61 self-consistent with
  the probe run.
