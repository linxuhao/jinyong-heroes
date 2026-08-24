# step2_design — One Action Per Turn: the `acted` Budget Becomes a Gate

## 1. Overview

**Round goal (from the task card):** make the `acted` action budget actually enforce "one action per turn" (design `10_systems.md` §5.1: a turn = move ≤ `moves_left` + **one action**, order free), surface a visible Chinese rejection reason when the player tries a second action, make the playtest scenario `each_unit_acts_once_per_round_initiative_order` true to its name, and probe enemies for the same defect before claiming anything about them.

**Root cause (SOTA, grep-confirmed):** `Player.acted` is a **write-only** flag. It is set `true` on successful execution (`combat_manager.gd` `_execute_basic_attack` L1270-1271 / `_execute_skill` L1403-1404, enemy-turn end L635-636) and reset `false` at turn start (`begin_turn` L691-692) and battle start (`_clear_unit_battle_state` L443-444) — but **nobody reads it to refuse a second action**. The gate must be added on the **read side**.

**Design strategy — complete the pattern that already exists, add nothing new:**
1. **Player-side funnel gate** (primary, user-visible): `scripts/characters/player.gd` refuses a second action in the same turn and emits the 7th rejection reason 「本回合已行动」 through the existing `action_hint` → HUD `ActionHintLabel` mechanism (the same family as the six shipped reasons in `_skill_reject_reason`).
2. **Engine-level invariant guard** (belt-and-braces): `CombatManager._execute_action` refuses any `basic_attack`/`skill` from a unit whose `acted == true`, so one-action-per-turn is an invariant of the action entry point, not a courtesy of the player controller. This also gives the enemy probe a definitive, mechanism-level answer.
3. **Playtest work**: extend `each_unit_acts_once_per_round_initiative_order.yaml` in place with a same-turn double-attack sequence on the player's round-2 turn (all 14 existing assertions byte-identical); fix `central_divine_innate_qi_fatal_guard.yaml` (the one green scenario that **depends** on the multi-attack bug) by splitting its two blows across two player turns.
4. **Enemy probe** (no repo writes): `godot_playtest_scenario` + `inline_scenario` measures how many damage events the player takes per enemy turn; expected per code reading: exactly one (AI evaluates once, acts once, ends — `combat_manager.gd` `_next_turn` L595-637). Observed values go in the delivery notes either way.

**Non-goals (explicit):** no mouse-path fix (measured untestable this round — see §12), no `click:`-based rejection assert, no RoundIndicator/HUD work, no unit-test wiring, no GUT/gdUnit4 adoption, no changes to `terminal_victory_8_12_rounds_hp_15_40` (deliberately 5/6, stays 5/6).

**Hard constraint:** baseline is 32 scenarios / 31 green. After this round: 31 still green (only `terminal_victory` red at 5/6), 0 runtime errors, and the two touched scenarios tell the truth.

**Language note:** this document's prose is English per pipeline convention; the in-game UI string 「本回合已行动」 is a quoted **Chinese data value** mandated by `design/30_presentation.md` (界面文字一律中文) — it is not translated.

## 2. Design-change declarations (for `5_design`)

The `design/` record is **not edited this run**. One additive note is declared for `5_design`:

| # | Change | Why |
|---|---|---|
| D1 | `design/30_presentation.md` "选了招式之后没法出招" — the rejection-reason example list (「射程不够」「冷却中 N 回合」「须在半血以下」「本回合无法用招」) gains a 7th reason 「本回合已行动」 for the new spent-turn gate. | The list was illustrative, not a closed set; the new gate needs a reason in the same family. No existing listed behavior changes. |

No numbers in `20_content.md` change. No changes to `10_systems.md` (the turn definition already says one action — this run only **implements** it). The scenario-file edits (C4/C5) are playtest contract files, not `design/`, so they are not declared here but are listed in §8.

## 3. Architecture diagram (text)

```
                        INPUT (keyboard J, skill hotkeys, WASD, mouse click)
                                          │
                                          ▼
                      player.gd _unhandled_input (state gate: BATTLE + player turn + not paused)
                        │                     │
   movement (WASD)      │                     │  attack_confirm / click on enemy
                        ▼                     ▼
        _try_move ── moves_left gate ──► _try_keyboard_attack / _handle_click_targeting
        (NEVER gated by acted)                  │
                                                ▼
                              ★ C1 NEW GATE ── _try_attack_target (single funnel)
                              if acted: emit 「本回合已行动」, return
                              (before skill/basic split, before cooldown/range/tutorial)
                                                │ (acted == false)
                                                ▼
                                        _execute_basic_attack / _execute_skill
                                                │
                                                ▼
                          CombatManager.execute_action(unit, action, target, params)
                                                │
                                                ▼
                              ★ C2 NEW GUARD ── _execute_action (engine invariant)
                              if unit.acted and action != "move": emit hint, return null
                                                │ (acted == false)
                                                ▼
                        _execute_basic_attack / _execute_skill ── sets unit.acted = true
                              (synchronously, before any await — same-frame double
                               input is safe: check and set are both synchronous)
                                                │
                                                ▼
                    apply_damage / statuses / cooldown  ──►  action_hint.emit("")
                                                │
                                                ▼
                       HUD ActionHintLabel (existing mechanism, C3: NO change)
                       surface: ActionHintLabel.text / .visible (already whitelisted)

Turn lifecycle (unchanged): begin_turn(unit) resets acted=false at the unit's own
turn start; enemy turns: AI evaluates ONCE → move path → at most one execute_action
→ acted=true → end_current_turn (combat_manager.gd _next_turn). Player turns:
event-driven, await Space; the new gates make unbounded re-presses harmless.
```

**Data flow of a rejected second action (the acceptance path):**
`attack_confirm` → `_try_keyboard_attack` → `acted == true` → `action_hint.emit("本回合已行动")` → `ActionHintLabel.text == "本回合已行动"`, `visible == true`; no `execute_action` call → no damage, no cooldown start, `acted` stays true, `selected_skill_index` untouched.

## 4. Component specifications

### C1 — Player action-budget gate — `scripts/characters/player.gd` (MODIFIED)

**Responsibility:** refuse any second action attempt in the same player turn, with the visible reason; never touch movement or skill **selection**.

**Changes (three insertion points, ~6 lines total):**

1. **Top of `_try_attack_target(enemy)`** (after the existing null/validity precondition guard, **before** the `selected_skill_index` skill/basic split — this single point covers both keyboard and mouse targeting):
```gdscript
if acted:
    action_hint.emit("本回合已行动")
    return
```
Gate order contract (must be preserved, reason: a spent turn reports the true blocker first):
`enemy validity` → **acted** → existing skill gates (`_skill_reject_reason`) → range/shape hit test → tutorial check → execute.

2. **Top of `_try_keyboard_attack()`** (covers the no-target branch, which otherwise emits 射程不够 after acting):
```gdscript
if acted:
    action_hint.emit("本回合已行动")
    return
```
This is equivalent to gating only the no-target branch but simpler and single-emission (it returns before `_try_attack_target` is ever reached).

3. **Documentation only:** update the `acted` field doc comment (L69-70) from "True once the unit has performed an action this turn" to note the flag is now **read** by the gates (C1/C2) and written only by the engine.

**Must NOT change:**
- `_try_move` — movement budget (`moves_left`/`moved`) is a separate gate; a turn may move after acting (design §5.1, order free).
- `select_skill` / `_skill_reject_reason` — skill **selection** stays allowed after acting (selection is preparation, not an action). The acted check must not be added to `_skill_reject_reason` or every skill-button press after acting would lie about the blocker.
- The six existing literals in `_skill_reject_reason` and the 射程不够 / 教程尚未解锁 literals in the attack path.

**Rejection consumes nothing (automatic):** the gate returns before `CombatManager.execute_action`, so no cooldown starts, no damage is applied, no `action_executed` fires, `acted` stays true. The hint line is overwritten on the next successful action/selection (existing `action_hint.emit("")` sites).

### C2 — Engine-level invariant guard — `scripts/autoload/combat_manager.gd` (MODIFIED)

**Responsibility:** make one-action-per-turn an invariant of the action entry point, protecting any future caller (new AI, queued actions) and giving the enemy probe a definitive mechanism-level answer.

**Change:** at the top of `_execute_action(unit, action, target, params) -> Tween` (before the `match action:`):
```gdscript
# One-action-per-turn invariant (design 10_systems §5.1). "move" is NOT an
# action — the movement budget is enforced by execute_move_path/_try_move,
# and a turn may move after acting (order free).
if action != "move" and unit != null and is_instance_valid(unit) \
        and "acted" in unit and bool(unit.acted):
    if unit.has_signal("action_hint"):
        unit.action_hint.emit("本回合已行动")
    return null
```
- Placement in `_execute_action` (not `execute_action`) keeps the guard **synchronous** with respect to the set in `_execute_basic_attack`/`_execute_skill` — no `await` window between check and set, so two key presses in one frame cannot both land.
- Returning `null` before the match means `action_executed` does **not** fire for a rejected attempt — correct semantics (a rejected action is not an executed action).
- `has_signal("action_hint")` keeps the guard decoupled from the HUD: enemies (which do not emit the signal) and future units are handled uniformly.
- This guard is **belt-and-braces** — it does not replace the C1 player-side gate, which is the user-visible path (the engine guard cannot know which HUD to address if the unit has no `action_hint`).

**Safety analysis — who C2 affects, and who it provably cannot (measured, not assumed).** C2 sits at the shared action entry point, so it carries this round's largest blast radius. Its impact boundary is enumerated here so no implementer or reviewer has to re-derive it — or, worse, weaken C2 out of caution:

1. **Counter/reflect damage never passes through C2.** `_trigger_counter_reflect` (`combat_manager.gd:880`, invoked from L873 immediately after `apply_damage`) applies damage **directly** and never calls `execute_action`. The passives 弹指神通反击 / 蛤蟆反震 therefore bypass the guard entirely: `trait_combat_effects_and_twelve_slots` (22/22) and `debug_reflect_hits` are outside C2's reach by code path, not by coincidence.
2. **Enemy turns never trip the guard — by statement order, not by luck.** The enemy branch (`combat_manager.gd` `_next_turn`) is:
   ```
   L631   await execute_action(unit, action, target, params)
   L635   if "acted" in unit: unit.acted = true
   ```
   `acted` is set **after** `execute_action` returns, so the enemy enters its own action with `acted == false` and C2 passes; `begin_turn` then resets the flag at the start of the enemy's next turn. This caller-side ordering is also the structural reason enemies never had the player's multi-action defect — their budget is enforced by the caller, exactly the asymmetry C6 probes to confirm.
3. **Call-site census: exactly three.** `player.gd:635` (basic attack), `player.gd:646` (skill), `combat_manager.gd:631` (enemy AI). No fourth call site exists (grep-audited). Any future caller added by a later run is precisely what C2 exists to protect — and that run's design must carry its own safety analysis for it.
4. **No duplicate hint on the player path.** C1 intercepts the player at the top of the funnel, so a rejected player attempt never reaches C2; the engine-level emit is silent for the player today. C2's `action_hint` emit exists **only** for future callers that bypass C1. The two emit sites are intentional, not a bug — neither may be deleted.

### C3 — HUD rejection surfacing — **NO code change**

The `action_hint` signal → `ActionHintLabel` mechanism already exists (player.gd L36 → HUD label) and is scenario-tested (`skill_rejection_reason_texts` 3/3 green). 「本回合已行动」 joins the existing family; no new signal, node, or surface entry. `playtest/_common.yaml` already whitelists `Player.acted`, `ActionHintLabel.text`, `ActionHintLabel.visible` — **zero harness changes**.

### C4 — Scenario extension: `playtest/each_unit_acts_once_per_round_initiative_order.yaml` (MODIFIED)

The scenario's name promises "each unit acts once per round" — today it asserts turn **order** only (14 asserts, green). The appended sequence proves the **budget**: a second `attack_confirm` in the same player turn is rejected with 「本回合已行动」, and the enemy turn still proceeds. Full skeleton in §7.1; guardrails:

- The 14 existing assertions stay **byte-identical** at f30 and f1200 with the same input timeline before them. The appended entries start **after** the f1200 entry.
- Keyboard `attack_confirm` is the **only** input leg asserted (mouse leg untestable this round — §12). No `click:` entries.
- The first `attack_confirm` must land (assert `Player.acted == true` and the target's health changed) — otherwise the test proves nothing. If no enemy is adjacent at f1200, insert move steps first (mirror `skill_rejection_reason_texts`' 3× move_up pattern, 15-frame spacing). Probe decides (§9).
- The rejection is pinned by `Player.acted == true` + `ActionHintLabel.visible == true` + `ActionHintLabel.text == "本回合已行动"`, sampled **after** the second (rejected) press. The health-unchanged assert uses an **integer percentage of max_health** (roadmap rule 1: never absolute HP; the harness has no documented `unchanged` keyword — grep found none — so the deterministic damage pipeline makes the post-first-hit percentage a computable constant): `round(100.0 * health / float(max_health)) == <N>`, same `N` asserted after the rejected press.

### C5 — Scenario fix: `playtest/central_divine_innate_qi_fatal_guard.yaml` (MODIFIED)

This scenario is green **because** of the multi-attack bug: it presses `attack_confirm` at f560 and f610 in the **same** player turn and asserts `Central_Divine.health: changed` after each (f600, f660). After the fix, the f610 press becomes a rejection and the f660 assert goes red. Required change: split the two blows across two player turns. Full timeline in §7.2; guardrails:

- All existing assertions stay: f140 `health < max_health`, f550 `current_round == 2`, f600 `changed` (f560 blow lands), and the f660 `changed` assert re-times to the player's **next** turn (its semantic — "health changed after the second blow" — is preserved).
- 先天罡气 is **once per battle** (`_innate_qi_used`, keyed by unit instance id, never reset — combat_manager.gd L211-212), so the first-lethal→1HP / second-lethal→death contract survives across turns. Spacing the blows across two adjacent player turns keeps that contract intact.
- The second blow must be **guaranteed to hit Central Divine** (the nearest-target pick has registration-order tie-breaks, and other enemies may be adjacent by round 3) and **guaranteed lethal** (threat model: South Emperor's 先天调息 ally heal, Central Divine's 罡气护体 shield). Probe-first procedure and decision table in §9.2.
- Frame numbers (the end_turn insertion point and the re-timed press/assert) are **probe-derived** (先取值,再动手), then fixed permanently. Frame cap 3000 leaves ample room.

### C6 — Enemy probe — **no repo writes** (run + delivery notes)

Probe (protocol in §9.3) answers: do enemies ever act twice in one turn? Code reading says no (`_next_turn`: one `_evaluate_ai` call, at most one `execute_action`, then `acted = true` + `end_current_turn`) — the asymmetry is structural: the **caller** enforces the budget for enemies, while the player turn is event-driven. The probe confirms the observed behavior (damage events per enemy turn, enemy `acted`/`turns_taken` deltas) and the observed values are recorded in the delivery notes. The C2 engine guard makes the invariant true regardless of caller, protecting future callers.

### C7 — Delivery notes (implementer output, not a repo file)

Must state, explicitly:
1. The mouse path is **NOT verified** this round (reviewer withdrew the both-legs requirement after the measured inert `click:` probe, SOTA commits a694e81/4696887); the acceptance assertion uses the keyboard `attack_confirm` path only.
2. Enemy probe observed values (C6) and the mechanism conclusion.
3. Playtest results: 31 green, `terminal_victory` 5/6 (deliberate), the two touched scenarios' new assert counts.
4. No claims of `click:`-verified behavior.

## 5. Interface specification

| Interface | Signature / literal | Notes |
|---|---|---|
| Rejection literal | `"本回合已行动"` | Exact string, 7th reason, Chinese display data (design 30_presentation). Grep-able acceptance point. |
| Player gate | `if acted: action_hint.emit("本回合已行动"); return` | Insertion points: `_try_attack_target` top (after validity guard, before skill/basic split) and `_try_keyboard_attack` top. |
| Engine guard | `_execute_action(unit, action, target, params) -> Tween` early-return `null` when `action != "move" and unit.acted` | Emits through `unit.action_hint` iff the unit has the signal. `action_executed` must NOT fire on rejection. |
| Unchanged invariants | `select_skill`, `_skill_reject_reason`, `_try_move`, `begin_turn`, `_clear_unit_battle_state`, all six existing literals | Byte/behavior-identical. |
| Harness surface | `Player.acted`, `ActionHintLabel.text`, `ActionHintLabel.visible` | Already whitelisted in `playtest/_common.yaml` — no edit. |
| Actions | `attack_confirm`, `end_turn`, `move_*` | Already declared in `playtest/_common.yaml` — no edit. |

**Determinism guarantees (unchanged by this design):** zero RNG in the damage pipeline; nearest-target picks use registration-order tie-breaks; `acted` is set synchronously before any `await`; the check is synchronous too — no same-frame double-land window.

## 6. Task decomposition boundaries (for the PM)

Suggested independent tasks — each lands green on its own, order as listed:
1. **C1** player gate (one file, ~6 lines) — compile-clean alone.
2. **C2** engine guard (one file, ~8 lines) — safe alone; no existing caller can reach it.
3. **C4** each_unit_acts_once extension — depends on C1 (rejection) + C2 (invariant); includes its own probe run to fix frames.
4. **C5** central_divine fix — depends on C1; includes its own probe run to fix frames.
5. **C6** enemy probe — independent; run any time; values go into delivery notes.

## 7. Scenario skeletons (frames are placeholders — implementer fills from probes)

### 7.1 `each_unit_acts_once_per_round_initiative_order.yaml` (appended after the f1200 entry)

```
- at: 1210        # only if probe shows no adjacent enemy: move_* steps, 15-frame spacing
  actions: [move_up]
  ...             # repeat until adjacent (mirror skill_rejection_reason_texts pattern)
- at: <A>
  actions: [attack_confirm]          # FIRST action of the player's round-2 turn
- at: <A+40>
  actions: []
  assert:
    Player.acted: acted == true
    ActionHintLabel.text: text == ""          # hint cleared after a SUCCESSFUL action
    <Target>.health: round(100.0 * health / float(max_health)) == <N>   # first blow landed
- at: <B>          # B >= A+55
  actions: [attack_confirm]          # SECOND attempt, same turn — must be rejected
- at: <B+40>
  actions: []
  assert:
    Player.acted: acted == true
    ActionHintLabel.visible: visible == true
    ActionHintLabel.text: text == "本回合已行动"
    <Target>.health: round(100.0 * health / float(max_health)) == <N>   # UNCHANGED — nothing consumed
- at: <C>          # C >= B+55
  actions: [end_turn]
- at: <C+~600>     # after the 5 enemy turns + round transition (probe-derived)
  actions: []
  assert:
    CombatManager.current_round: 3
    CombatManager.active_unit_name: active_unit_name == "Yang Guo"   # init debuff expired; player first again
    Player.turns_taken: 2
    CombatManager.empty_round_stalls: empty_round_stalls == 0        # enemy turns proceeded after the rejection
```
`<Target>` is the nearest adjacent enemy at frame A (probe-identified; deterministic registration-order tie-break); `<N>` is the post-first-hit integer percentage (deterministic damage: basic 39, skill_1 59, no target DR on the chosen enemy — probe confirms). Frame cap 3000; all entries ≤ 2999.

### 7.2 `central_divine_innate_qi_fatal_guard.yaml` (edited timeline)

```
f3..f550   — byte-identical (7× ui_accept, 3× move_up, skill_1, attack_confirm at f80,
             end_turn f150, f140 health<max_health, f550 current_round==2, f560 attack_confirm)
- at: 600   assert: Central_Divine.health: changed      # f560 blow landed (unchanged entry)
- at: 620   actions: [end_turn]                          # NEW: end the turn — no second blow
- at: <P>   actions: [attack_confirm]                    # player's NEXT turn (round 3), probe-derived
- at: <P+40> assert: Central_Divine.health: changed      # re-timed f660: lethal blow → 先天罡气 → 1 HP
```
Existing f610 press and f660 assert are **replaced** by the re-timed pair; their semantics (second blow lands, health changes) are preserved. Description line updated to match the exercised contract ("…the two blows land on two different player turns — one action per turn"). Probe (§9.2) verifies the second blow targets Central Divine (not a tie-break neighbor) and is lethal (not absorbed by shield/heal), choosing skill_1 (重剑无锋 59) over basic attack (39) if the HP math requires it.

## 9. Probe procedures (先取值,再动手 — measure first, then write)

### 9.1 Re-baseline before finalizing C4 frames
One `godot_playtest_scenario` run of the touched scenario (or an `inline_scenario` copy) sampling `CombatManager.turn_log/current_round`, `Player.grid_pos/acted`, per-enemy `grid_pos/health` at f1200, then after each step. Record: which enemy is nearest-adjacent at frame A; the post-first-hit health; the frames where `Player.acted` flips; the frame where round 3 begins. Then finalize `<A>/<B>/<C>/<N>`.

### 9.2 central_divine decision table (probe first)
Sample after f560 and at the start of the player's round-3 turn: `Central_Divine.health`, `shield`, `status_names`; `South_Emperor.health` (who 先天调息 heals). Decide:
- **Hit target correct?** If another enemy ties as nearest, add move steps to make Central Divine uniquely nearest before pressing.
- **Lethal?** Need `damage >= health_before_blow` and no active shield absorbing the blow. Basic 39 kills ≤39; skill_1 59 kills ≤59 and survives one 先天调息 heal (worst case 1+46=47). If a 罡气护体 shield is up at press time, wait/plan so the press lands when it is down (shield is cast on Central Divine's own turn; probe the cast frames).
- **Fallback (only if the probe proves no lethal blow can be arranged within budget):** keep the guard-only contract (f560 non-lethal → round-3 blow lethal → 1 HP) and update the description accordingly — never assert death on a possibly-freed node without probe evidence (dead enemies leave the round order; prefer asserting via `turn_order.has("Central Divine") == false` in the following round if death IS exercised).

### 9.3 Enemy probe (`inline_scenario`, no repo writes)
Boot the battlefield via a `scene:` override, walk one enemy turn, and sample `Player.health` immediately before and after each enemy's turn plus enemy `acted`/`turns_taken` deltas. Expected per code reading: ≤1 damage event per enemy turn (move + at most one action), `turns_taken` +1, `acted` true at turn end, reset false at next turn start. Record observed values in the delivery notes; if any enemy ever shows two damage events in one turn, report it as a defect finding (it would be an engine-caller bug, exactly what C2 now guards).

## 10. Irreversible-operation safety & rollback

No irreversible operations this round: all changes are tracked text edits to two GDScript files and two playtest YAML files; no save/schema/migration work. Safety protocol:
1. **Backup by git** — every edit is a diff; `git diff` on each file before finalizing.
2. **Validate new state** — full playtest suite run (baseline: 32 scenarios, 31 green; only `terminal_victory` red at 5/6) + compile gate (0 errors) + zero runtime errors.
3. **Confirm before declaring done** — the two touched scenarios' assert counts go up (each_unit_acts_once 14 → 20+; central_divine 4 → 4), and a diff proves the 14 existing each_unit_acts_once assertions and the f140/f550/f600 central_divine assertions are byte-identical.
4. **Rollback path** — if any previously-green scenario turns red, revert the responsible file edit; the two files are independent, so blast radius is one scenario each.

## 11. Tech stack

- **Godot 4.4 (stable) + GDScript** — no new dependencies, no external libraries (SOTA's recommendation adopted; GUT/gdUnit4 explicitly deferred).
- **Playtest harness as-is**: `playtest/_common.yaml` + per-scenario YAML; `godot_playtest_scenario` CLI + `inline_scenario` for probes. No `playtest_spec.yaml` (this repo uses the directory form).
- **Linter manifest**: GDScript is NOT in the manifest (checked by the per-step `gdscript_check` gate with `godot --check-only`); the touched `.yaml` scenario files and `.md` docs map to `basic`. Manifest content unchanged from the repo's current one.

## 12. Extensibility & debts (recorded, NOT implemented)

- **Mouse path fix (debt, downstream):** `_handle_click_targeting()` (player.gd L459-460) should use the `InputEventMouseButton` coordinates it receives instead of re-querying `get_global_mouse_position()` (viewport-cached pointer that synthesized events cannot update — measured inert 0/2 with no error). Fixing it makes the mouse attack leg testable with the harness `click:` capability and removes the silent-failure shape. Deliberately out of scope this round (theme is `acted`; wider regression surface unwanted).
- **Never ship a mouse-interaction scenario asserting only 'no runtime errors'** — the measured click defect is a silent no-op and such a scenario passes vacuously against it.
- **RoundIndicator** displays 行动 ✓ vs 结束 from `acted` already — after this fix the display becomes truthful for free. No UI work declared.
- The engine guard (C2) protects future action callers (new AI, queued actions); the C1 funnel gate can be retired only if such a future caller routes its own hint surfacing — keep both.

## 13. Out of scope (explicit)

Mouse-path coordinate fix; `click:`-based rejection asserts; HUD/RoundIndicator changes; unit-test wiring (GUT/gdUnit4); new action types; movement-budget changes; any `terminal_victory` edits; any numeric rebalance; save-system work.

## 14. Deliverable summary

| Deliverable | Path | Status |
|---|---|---|
| Player gate (C1) | `scripts/characters/player.gd` | MODIFIED (~6 lines) |
| Engine guard (C2) | `scripts/autoload/combat_manager.gd` | MODIFIED (~8 lines) |
| Scenario extension (C4) | `playtest/each_unit_acts_once_per_round_initiative_order.yaml` | MODIFIED (appended entries; 14 existing asserts byte-identical) |
| Scenario fix (C5) | `playtest/central_divine_innate_qi_fatal_guard.yaml` | MODIFIED (turn split; all existing assertions preserved) |
| Enemy probe (C6) | none | inline_scenario run; values in delivery notes |
| linter manifest | `linter_manifest.json` | unchanged content (`basic` for yaml/json/md) |

## 15. Assumptions (for downstream steps)

- The player's round-2 turn in `each_unit_acts_once` is live at f1200 (turn_log size 11) and the frame cap is 3000 — ample room for the appended sequence; exact frames come from the §9.1 probe before finalizing.
- 先天罡气 is once-per-battle (combat_manager.gd L211-212, keyed by instance id, never reset) — the central_divine split across two turns keeps the guard contract intact.
- The mouse leg is untestable this round (measured 0/2, no error; viewport-cached pointer position). Acceptance asserts the rejection through keyboard `attack_confirm` only; delivery notes state the mouse path is NOT verified.
- Skill selection after acting stays allowed; the acted check lives only in the two execution funnels (C1) and the engine action entry (C2).
