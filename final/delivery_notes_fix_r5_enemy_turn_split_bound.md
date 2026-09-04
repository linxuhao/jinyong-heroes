# Delivery notes — fix_r5_enemy_turn_split_bound

## 1. 改动清单
- `scripts/autoload/combat_manager.gd` — one statement insertion (option a, attribution-in-code):
  at the enemy-turn start stamp site (immediately after `_enemy_turn_start_msec = Time.get_ticks_msec()`, **before** the `if not _enemy_round_active:` block and the pause-gate / `_evaluate_ai` chain), the two buckets are zeroed:
  ```gdscript
  debug_enemy_move_msec = 0
  debug_enemy_attack_msec = 0
  ```
  plus a 4-line comment explaining why (skip-segment leak) and why `debug_enemy_other_msec` is deliberately NOT reset (it is always recomputed as `max(turn − move − attack, 0)` at the publish site, so resetting it would falsely imply it is a carried value).
- No other file touched. `playtest/enemy_turn_wall_clock.yaml` is byte-identical (option b not needed).

## 2. 跑过的命令与原样输出
Implementer has no shell; the harness probe tool was used (it stages the working tree onto the repo):

- `godot_playtest_scenario("enemy_turn_wall_clock")` →
  `[PASS] enemy_turn_wall_clock  14/14` (staged file applied: `scripts/autoload/combat_manager.gd`) — hard gate passed.
- `godot_playtest_scenario("enemy_action_feedback,camera_transform_follows_unit")` →
  `[PASS] enemy_action_feedback  9/9`, `[PASS] camera_transform_follows_unit  13/13` — hard gate passed.

## 3. acceptance 对照
1. **enemy_turn_wall_clock 14/14 green, bounds byte-identical** — met. Probe: 14/14. The yaml was not edited; round ≤ 10000 / turn ≤ 2000 / index ≥ 5 separation bounds byte-unchanged.
2. **enemy_action_feedback & camera_transform_follows_unit re-run green** — met (9/9, 13/13, counts pasted above).
3. **Chosen option documented with measured residual & named source** — met, see §4. Chosen: (a) attribution-in-code. The measured red (13/14, observed 657) is transcribed from the task card's already-measured red run in this cycle's playtest_summary.md — not re-measured locally; the root cause was confirmed by source read (see §4), and the fix turned the failing assert green (14/14 probe).
4. **Print formats byte-unchanged** — met. (I have no shell; the grep excerpt is provided as source-read evidence:)
   - `"enemy_turn %s %d"` → 1 hit (publish site, unchanged).
   - `"enemy_round %d"` → 2 hits (round-start site and round-publish site), both unchanged.
   - `"enemy_turn_split %s move=%d attack=%d other=%d"` → 1 hit, unchanged.
5. **Diff confined to pacing/print bucket-attribution sites; `_evaluate_ai` and damage lines byte-identical** — met. The only edit is the two zero-assignments at the turn-start instrumentation site (card 0b's region). `_evaluate_ai` body and all damage/stat lines untouched.
6. **Notes quote measured red + green run** — met (§4 / §2).

## 4. 归因分析（measured red → mechanism）
Measured red (transcribed from the task card / this cycle's playtest_summary.md, not re-measured): `enemy_turn_wall_clock 13/14`; failing line-84 split-sanity assert
`debug_enemy_move_msec >= 0 and debug_enemy_attack_msec >= 0 and debug_enemy_other_msec >= 0 and debug_enemy_move_msec + debug_enemy_attack_msec + debug_enemy_other_msec <= debug_enemy_turn_msec` with observed **657** (sum exceeded turn_msec).

Mechanism (static read of the await chain):
- `debug_enemy_move_msec` is assigned only inside `if not move_path.is_empty()` (turn-region move segment).
- `debug_enemy_attack_msec` is assigned only inside `if action != "" and action != "wait"`.
- Neither is reset per turn. When one enemy turn skips a segment, that bucket carries the previous enemy's residual across turns, so `move + attack` can exceed this turn's `turn_msec`; the publish site then clamps `other = max(turn − move − attack, 0)` to 0 and the identity assert fails.
- A single unattributed await (pause-gate timer / tween-safe overhead) cannot cause this: such awaits are absorbed by `other` and would make sum < turn, never > turn. Only the cross-turn leak explains sum > turn.

After the fix, the move and attack intervals are both proper subsets of the turn interval and mutually disjoint; `other = turn − move − attack ≥ 0` holds by construction, so `move + attack + other == turn_msec` exactly. The never-hang watchdog is untouched.

## 5. Known gaps 与遗留
- None in scope. The full 26-scenario gate re-run belongs to 5_compile; the three probed scenarios are green with counts pasted in §2.

## 6. 边界声明
- Not touched: the six locked files; `_evaluate_ai`; damage/stats/cooldowns; AI decisions; turn order; the two print format strings; the never-hang watchdog; the wall-clock bounds; `playtest/enemy_turn_wall_clock.yaml`; `playtest/_common.yaml` (no new surface names); no new public vars in combat_manager.gd; no root `playtest_spec.yaml` created.
- RNG lifelines: the fix adds zero RNG operations (pure counter zeroing), so `save_load_roundtrip` / `event_travel_effects` behavior is unchanged (combat_manager.gd was touched but the change is measurement-only).
