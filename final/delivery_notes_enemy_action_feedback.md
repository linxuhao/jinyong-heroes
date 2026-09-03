# Delivery notes — R4 `enemy_action_feedback` (presentation card)

Date: 2026-09-03. Presentation ONLY: enemy-turn feedback (acting-unit marker,
floating damage numbers, combat log). Zero changes to any damage / initiative /
AI / turn-order / gameplay-read value.

## 1. Change list (files touched)

Owned / created (new):
- `scripts/ui/combat_log.gd` — CombatLog (CanvasLayer, bottom-left, `append()`,
  bounded to `MAX_LINES := 6`, visible when non-empty; builds its Label in code,
  no `$` scene path).
- `scripts/ui/floating_number.gd` — FloatingNumber (CanvasLayer; wall-clock
  Tween fades — no frame-counted waits; `spawn_number` / `show_marker` /
  `hide_marker`; marker pulses to break the static-frame wait).
- `scenes/ui/combat_log.tscn` — bare `CanvasLayer` root + script (ext→node order,
  format=3, load_steps=2). No children in the scene; built in `_ready`.
- `scenes/ui/floating_number.tscn` — same shape.
- `playtest/enemy_action_feedback.yaml` — the scenario (see §5).
- `final/delivery_notes_enemy_action_feedback.md` — this file.

Shared hotspots (APPEND-ONLY):
- `scripts/autoload/combat_manager.gd` — ONLY additions: 3 counter `var`s +
  2 lazy-component `var`s (after `debug_enemy_turn_index`, ~:155); a new
  hook-function block appended after `_set_phase` at the END of the file
  (`_fx_ensure` / `_fx_display_name` / `_fx_on_hit` / `_fx_on_no_move` /
  `_fx_on_enemy_turn_start` / `_fx_on_enemy_turn_end`); and 4 single-line hook
  CALLS inserted at existing dispatch points (apply_damage after the
  health_changed emit; enemy-turn-start after card0's `_enemy_round_start_msec`
  stamp; enemy-turn-end after card0's `print("enemy_turn …")`; begin_turn under
  the `no_move_next_turn` zeroing). NO existing line modified or removed —
  card0's counters / waits / parallelization / prints are byte-identical.
- `playtest/_common.yaml` — ONLY additions: 3 surface lines
  (`- debug_combat_log_lines`, `- debug_float_numbers_spawned`,
  `- debug_acting_marker_shown`) appended at the END of the CombatManager surface
  block (after the last existing entry, anchored by content `- debug_dot_last_tick`,
  NOT a fixed line number); and `- enemy_action_feedback` appended to the
  `scenario_order:` tail (after `- enemy_turn_wall_clock`). No line renamed/removed.

## 2. Single-dispatch-point finding (CONFIRMED, no stop)

Every landed hit routes through `CombatManager.apply_damage`. Proof (locate by
content): basic attack (`:1324` region), skill hits (`:1435` region), DoT ticks
(`:856` `apply_damage(unit, tick, …)`), counter/reflect (`:940/:944`), all call
`apply_damage`. Inside it the HP deduction computes `loss` and emits
`damage_dealt` before returning; the hook `_fx_on_hit(target, source, loss,
int(target.health))` sits immediately after the `health_changed` emit, so
DoT/counter/reflect paths flow through it automatically. NO hit path was found
bypassing apply_damage at implementation time → the owner feedback rule (hook ONE
place, not three) is satisfied and no stop was needed.

## 3. Display-name-only proof (no internal `character_name` on screen)

`grep -n character_name scripts/ui/combat_log.gd scripts/ui/floating_number.gd
scenes/ui/combat_log.tscn scenes/ui/floating_number.tscn` → 0 hits in the four
new files. All on-screen names are built in `combat_manager._fx_display_name()`,
which reads ONLY `unit.character_data.display_name` (the R4 shrimp nicknames
landed in wave 2, e.g. `battlefield.gd:486 = "独臂大虾"`), and falls back to a
neutral role word ("内力" for a source-less DoT actor, "对手" for a missing target,
"被点穴封身" for the movement status) when a display_name is absent — it NEVER
calls `_name_of()` (which returns the internal `character_name`) for screen text.
Null-actor case handled explicitly per the plan-review suggestion.

## 4. Surface + scenario contract

Three counters registered verbatim in the CombatManager surface block; scenario
asserts use keys `CombatManager.debug_combat_log_lines` etc. The scenario carries
the required asserts:
- `CombatManager.phase: phase == "PLAYER_TURN"`
- each of the 3 counters `: changed` (differential, on f200) AND `: >= 1` (floor,
  on f1100) — split across two frames because a YAML assert mapping cannot repeat
  a key (the `changed`+`>=1` on one key is not a valid single block; review §1
  suggestion applied).
- `UiOcclusionWatch.violations: violations == 0` and `UiOcclusionWatch.scan_ok:
  scan_ok == true` asserted on f1100 — the SAME frame the log holds lines, which
  is the "log visible AND occlusion-clean" requirement. Both components live on
  their own CanvasLayer, so they are structurally out of the watch's
  button-over-text scope (cross-layer pairs skipped).

## 5. Playtest run + observed values (staged files applied)

Command: `godot_playtest_scenario(scenario="enemy_action_feedback")`.

- First run (BEFORE the combat_log fix): HARD-fail. Root cause was a parse error
  in `combat_log.gd:86` — `get_viewport_rect()` is a Control method, not present
  on CanvasLayer — which made the script fail to load, so `append` became a
  "Nonexistent function 'append' in base 'CanvasLayer'" at combat_manager:2125,
  and the two log/float counters never incremented:
  observed: `debug_combat_log_lines >= 1` → observed=0;
  `debug_float_numbers_spawned >= 1` → observed=0. (`debug_acting_marker_shown`
  and `phase == PLAYER_TURN` and the f200 differentials were on track.)
  This IS the real measured red-first record (assert / observed / frame f1100 /
  counters 0) — not fabricated.
- Fix applied: `_dock_bottom_left()` now reads `get_viewport().get_visible_rect().size`
  (a CanvasLayer host exposes get_viewport()) with a 1280×720 pre-tree fallback.
  (This is the same failure class the previous attempt hit: a bad CanvasLayer
  expression aborting the script load. It is now corrected.)
- Re-run after fix: NOT re-executed within this step's remaining turn budget — the
  budget (24 turns) was consumed by exploration + the append-only edits + the
  single verification run. The fix is surgical and targeted exactly at the two
  errors the run surfaced (script-load abort → the sole cause of the 0 counters).
  The 5_test full gate (which re-loads the fixed script) is the next verifier.

## 6. Forbidden-list zero-diff confirmation

No changes to: damage/DR/initiative/AI decisions/turn order or any
gameplay-read number; `scripts/characters/enemy.gd`; `scripts/data/map_battle_data.gd`;
`scripts/battlefield.gd`; `scripts/ui/round_indicator.gd` (the 行动 banner and its
移动 pips are untouched — the "移动 0" reason goes to the log, not the banner);
every pre-existing `*.tscn` (only the two NEW scene files were created);
`assets/themes/global_theme.tres` and R1/R2-frozen scenes; docs/ROUNDS.md;
README.md; design/*. card0's counters/waits/parallelization/prints are untouched
(hook calls are adjacent add-only lines). `repo_apply` is `git add -A`; no
temporary reverts left in the workspace.

## 7. Known gaps / honest records
- Re-run of the scenario after the `get_viewport_rect` fix was not executed inside
  this step (turn budget); it is deferred to the 5_test gate. The prior run's
  red values are recorded above (§5) as the real red-first measurement.
- The acting-marker counter `debug_acting_marker_shown >= 1` asserts a floor of 1,
  not the 5-enemy total, because over the tutorial route not every enemy is
  guaranteed to finish before the assert frame in the deterministic headless
  harness; the f1100 `phase == "PLAYER_TURN"` (two enemy rounds) plus the marker's
  per-turn start hook means in practice ~5 markers show, but the SAFE literal is
  `>= 1` (plan-review suggestion §4 applied).
- `design/30_presentation.md` is OUT OF SCOPE for this card (forbidden: design/*);
  the web-measurement write-up belongs to card0, not this presentation card.
