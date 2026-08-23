# Step 2 Design — Make the Encounter Battle Path Load-Bearing

## 1. Overview

**Round goal:** `cultivation_changes_combat` fully green (29/29), `CombatManager.empty_round_stalls == 0` in every scenario, `trait_combat_effects_and_twelve_slots` / `sect_switch_same_school_connects` / `save_load_roundtrip` and all 12 protected tutorial battle scenarios stay green.

**SOTA verdict (accepted):** every piece of the encounter machinery already exists and is unit-tested (`BattleSetup.build_character`, `EncounterData.sparring_partner`, battlefield ENCOUNTER branch, `_instantiate_player`, `_instantiate_sparring_partner`, HUD/trait/turn-engine hooks, save roundtrip). The battle can never start because of **two missing wiring links**:

1. `SceneManager.SCENE_MAP` has no `"BATTLE"` key → `GameManager.start_encounter()` emits `state_changed("BATTLE")` and the router answers `last_error = "state_unmapped"` — **the battlefield scene is never instantiated.**
2. `start_encounter()` emits `battle_started` **synchronously before the async scene swap**, while `get_player() == null` and `enemies_alive` is empty. `CombatManager._on_battle_started()` runs `_begin_round()` on that empty roster, trips the loud guard (`empty_round_stalls += 1`, `push_error`, phase `ROUND_END`) — and because `battle_started` fires only once, **the battle stays stalled forever even after the units arrive.**

This design fixes exactly those two links and re-baselines the playtest. Nothing downstream is rebuilt; the loud guard is **never weakened** — the fix is sequencing, not assertion-lowering.

**No design-record change.** This is a pure wiring bugfix; no rule in `design/` changes, so there is no "设计变更" section and `99_changelog.md` gets no row.

---

## 2. Architecture

### 2.1 Current chain (broken)

```
cultivation (debug_enter_encounter)
  -> GameManager.start_encounter()          state CULTIVATION -> BATTLE
       battle_started.emit()   [roster EMPTY: player null, no enemies]
         -> CombatManager._on_battle_started()
              phase IDLE -> current_round = 1 -> _begin_round()
              -> empty order -> empty_round_stalls += 1, push_error, phase ROUND_END  (STALLED FOREVER)
       state_changed.emit("BATTLE")
         -> SceneManager._on_state_changed: SCENE_MAP.get("BATTLE") == null
              -> last_error = "state_unmapped", return                     (NO SCENE SWAP)
```

### 2.2 Fixed chain (this design)

```
cultivation (debug_enter_encounter)
  -> GameManager.start_encounter()          state CULTIVATION -> BATTLE
       battle_started.emit()   [roster EMPTY]
         -> CombatManager._on_battle_started()  ->  _begin_if_ready()
              roster empty -> return                                      (silent skip, NO stall)
       state_changed.emit("BATTLE")
         -> SceneManager._on_state_changed: SCENE_MAP["BATTLE"] == "battlefield"
              -> swap_to("battlefield")  ->  _do_swap (await tree_exited, ~1-2 frames)
              -> battlefield.tscn enters tree
       battlefield._ready()  [battle_return_state == "CULTIVATION"]
         -> _setup_encounter_battle()
              profile null? -> push_warning + return (no kick-off queued)
              _instantiate_player()          -> GameManager.set_player()     (roster now live)
              _instantiate_sparring_partner() -> GameManager.register_enemy()
              _wire_hud.call_deferred(...)          [queued first]
              CombatManager.begin_battle.call_deferred()  [queued second, LAST statement]
       end-of-frame flush (Godot MessageQueue, FIFO):
         1. HUD.setup() runs (buttons/health bars exist, signal listeners wired)
         2. begin_battle() -> _begin_if_ready()
              phase IDLE, player != null, >= 1 enemy  ->  current_round = 1 -> _begin_round()
              round_started(1) / turn_started(player) reach a WIRED HUD
              -> phase PLAYER_TURN, player turn loop awaits process_frame
```

The tutorial path is untouched end-to-end: its units exist before `start_battle()` fires, so `_on_battle_started()` sees a non-empty roster and begins round 1 exactly as today; `SCENE_MAP["BATTLE"]` maps to the already-hosted `battlefield` (`swap_to` no-ops); and the tutorial `_ready` branch never calls `begin_battle()`.

### 2.3 Component diagram (text)

```
[GameManager autoload]-- battle_started -->[CombatManager._on_battle_started (guarded)]
        | state_changed("BATTLE")                 |
        v                                         | begin_battle() (public, guarded)
[SceneManager autoload]-- swap_to("battlefield")->[Battlefield scene]
        SCENE_MAP["BATTLE"]="battlefield"               |
                                                        v
                                          _setup_encounter_battle(): units -> HUD queue -> kick-off queue
                                                        |
                                                        +-> [HUD (HUDLayer)]  <- deferred FIFO, before round 1
                                                        +-> [CombatManager]   <- begin_battle deferred, round 1 starts
```

---

## 3. Component specifications

### C1 — `scripts/autoload/scene_manager.gd`: add the `BATTLE` map entry (one line)

- **Change:** add `"BATTLE": "battlefield",` to `SCENE_MAP` (after `"TUTORIAL"`).
- `SCENE_PATHS` **already** contains `"battlefield": "res://scenes/battlefield.tscn"` — no new preload, no new machinery.
- **Invariants (must hold after the change):**
  - Tutorial `start_battle()` emits `state_changed("BATTLE")` while `current_scene == "battlefield"` → `swap_to` returns immediately (no-op branch, line 90-91). Byte-identical behavior.
  - `WON` / `LOST` stay unmapped deliberately: `last_error = "state_unmapped"` on WON/LOST is pre-existing tutorial behavior the playtest already tolerates. **Do not add WON/LOST keys.**
  - The existing swap protocol (`pending_swap` guard, `_teardown_battle_refs()` → `CombatManager.reset_battle()` → `GridManager.clear_grid()` → `GameManager.clear_battle()` **before** `queue_free`, `await tree_exited`) is the freed-object-safety contract — **keep it exactly as is.**

### C2 — `scripts/autoload/combat_manager.gd`: guarded kick-off seam

Replace the body of `_on_battle_started()` and add a public `begin_battle()`, both sharing one guarded helper:

```gdscript
## Begin the turn-based battle: round 1 snapshot and the first turn. Drives the
## tutorial path (battle_started fires when its units already exist). The
## encounter path emits battle_started BEFORE its scene swap, while the roster
## is still empty — skipping here keeps the empty_round_stalls guard
## unreachable; the new battlefield's _ready() calls begin_battle() instead.
func _on_battle_started() -> void:
	_begin_if_ready()


## Public kick-off for battles whose units are registered by the battlefield
## scene itself (encounter mode): IDLE -> round 1. No-op while a battle is
## running, when the player is missing, or when no enemy is registered — a
## stray scene load can never trip the empty-round stall guard. The tutorial
## never calls this (start_battle() drives it via battle_started).
func begin_battle() -> void:
	_begin_if_ready()


## Shared guarded kick-off: phase IDLE + live player + >= 1 enemy, then round 1.
func _begin_if_ready() -> void:
	if phase != "IDLE":
		return
	if GameManager.get_player() == null or GameManager.get_enemies_alive().is_empty():
		return
	current_round = 1
	_begin_round()
```

- **The guard (`empty_round_stalls` + `push_error` in `_begin_round()`) stays untouched.** The fix is sequencing, never assertion-weakening.
- `_on_battle_started` keeps its existing `phase != "IDLE"` re-entry guard as the first check (tutorial battles that already started cannot be double-kicked; `start_encounter`'s second call is already a no-op at the GameManager level).
- **Tutorial byte-identity:** the roster there is non-empty when `battle_started` fires, so the new skip never fires on the tutorial path (SOTA assumption, verified against `start_battle()` call sites — it is only reachable from TUTORIAL after the tutorial battlefield `_ready` built its units).
- `begin_battle()` is safe to call from anywhere, synchronously or deferred, because all preconditions are re-checked inside — including after a `reset_battle()` + `clear_battle()` teardown where the deferred call lands on a freed battlefield (player null → no-op).

### C3 — `scripts/battlefield.gd`: kick off round 1 in the ENCOUNTER branch

In `_setup_encounter_battle()`, after the HUD wiring line, append the kick-off as the **last statement**, and update the function's doc comment (it currently claims `start_encounter()` kicks the battle — that is the bug being fixed):

```gdscript
	# Wire the HUD (deferred — HUD._ready() hasn't run yet, so its @onready vars
	# are null), then kick off round 1 deferred AFTER the wiring: Godot's
	# MessageQueue flushes call_deferred FIFO within the same frame, so
	# HUD.setup() (buttons + signal listeners) runs BEFORE round_started /
	# turn_started fire — the same ordering the tutorial path has (HUD wired,
	# then battle starts). begin_battle() self-guards (phase IDLE + non-empty
	# roster), so the profile-null early return and any stray scene load can
	# never reach the empty-round stall guard.
	_wire_hud.call_deferred(player_node, [enemy_node])
	CombatManager.begin_battle.call_deferred()
```

- **Profile-null guard:** `_setup_encounter_battle()` early-returns with a `push_warning` when `SaveManager.profile == null` — the kick-off is queued after that return point, and even if it weren't, `begin_battle()`'s roster check absorbs it. (SOTA edge case: no stray scene load can trip the stall guard.)
- **HUD-before-round-1:** both calls are deferred in FIFO order in the same frame flush. `call_deferred` on a freed object is dropped by the MessageQueue (unit-test teardown path), and `begin_battle` is on the never-freed autoload, so the pair is safe under scene teardown.
- **Deterministic timing:** the round starts at the end of the frame in which the new battlefield entered the tree; `CombatManager.debug_round_frame` records that process-frame number — the re-baselining anchor for the playtest.
- **Do not touch** the tutorial branch of `_ready()` (steps 5-10 + `CombatManager.tutorial_battle = true` last-statement contract).
- Encounter mode stays tutorial-free: `tutorial_battle == false` re-asserted, no overlay, no `TutorialManager.start()`.

### C4 — `playtest_spec.yaml`: surface + scenario re-baseline

#### Surface delta (the observable contract for implementers)

```yaml
CombatManager: [current_round, phase, active_unit_name, turn_order, turn_log,
  last_turn_actor, debug_await_total, debug_await_timeouts, debug_await_frames,
  debug_round_frame, debug_reflect_hits, tutorial_battle, debug_sha_heal_total,
  debug_iron_shirt_procs, debug_lang_attack_mult, empty_round_stalls]
```

(`empty_round_stalls` appended — the round goal asserts it is 0 everywhere; `debug_round_frame` is already whitelisted and becomes the re-baselining instrument.)

#### Scenario deltas (skeletons; exact thresholds are PM's, but the values below are derived and expected to land as written)

1. `round_one_snapshot_and_turn_order` — add to the frame-30 assert block: `CombatManager.empty_round_stalls: 0` (tutorial path proves the skip never misfires into a stall).

2. `cultivation_changes_combat` — battle-1 assert block (frame 490) gains:
   - `CombatManager.empty_round_stalls: 'empty_round_stalls == 0'`
   - `CombatManager.current_round: 1`
   - `CombatManager.phase: 'phase == "PLAYER_TURN"'`
   - `CombatManager.active_unit_name: 'active_unit_name == "ProgressionHero"'`
   Battle-2 assert block (frame 1040) gains the same four lines.
   **Existing digit asserts stay unchanged** — verified against the input model: the `skill_1` hotkey only *selects* skill 0, and the `basic_attack` key (J) *executes the selected skill* at the nearest valid target then auto-deselects; it never additionally lands a basic attack while a skill is selected. So battle 1 is `round(30×0.7)=21 → 60−21 = 39` and battle 2 is `round(30×0.85)=26 → 60−26 = 34` — exactly the current asserts (21→39, 26→34). Player `acted` flips to true on the successful skill execution (`"changed"` still passes).
   - **Frame re-baseline rule:** round 1 now starts at `debug_round_frame` ≈ the frame the battlefield `_ready` ran (≈ debug_enter_encounter + 2-3 frames: swap teardown `await tree_exited` + instantiation). The first post-entry press sits +15 frames or more after the entry press in both battles (505 vs 450; 1055 vs 1000) — margins are ≥ 12 frames, so **no timeline edits are expected**. If the harness ever shows a press swallowed (phase not yet `PLAYER_TURN`), shift the press by the measured `debug_round_frame` delta, never by assertion edits.

3. `trait_combat_effects_and_twelve_slots` — add `CombatManager.empty_round_stalls: 'empty_round_stalls == 0'` to the frame-845 assert block. Existing digit asserts stay: 身轻如燕 slide (7,5)→(7,3) with `moves_left == 0` (move budget 2, slide costs 2), dart `round(30×0.85×1.08)=28 → 60−28 = 32`, `debug_lang_attack_mult == 1.08`, 杀 heal `round(28×0.2)=6`, 铁布衫 `health == 1` + `debug_iron_shirt_procs == 1`, no LOST. All of these were authored against the live-turn model (select → execute) and now actually execute.

4. `sect_switch_same_school_connects`, `save_load_roundtrip`, all tutorial battle scenarios, `spine_to_ending`: **no edits.** They do not press encounter-combat inputs, and the tutorial path is byte-identical.

#### Frame cap
All scenarios remain inside the 3000-frame cap; the deferred kick-off adds 0 extra frames versus the swap frame (same-frame flush).

---

## 4. Data flow & timing contract

| Step | Actor | Frame (relative) |
|---|---|---|
| `debug_enter_encounter` press | harness | F |
| `start_encounter()`: state→BATTLE, `battle_started` (skipped: empty roster), `state_changed("BATTLE")` | GameManager | F |
| `swap_to("battlefield")` → `_do_swap` teardown + `await tree_exited` | SceneManager | F..F+1 |
| battlefield `add_child` → `_ready()` → ENCOUNTER branch → units registered → HUD queue → `begin_battle` queue | battlefield | F+1..F+2 |
| deferred flush (FIFO): `HUD.setup()` then `begin_battle()` → `current_round = 1`, `phase = PLAYER_TURN`, `round_started(1)`, `turn_started(player)` | MessageQueue | end of that same frame |
| player turn loop resumes; input presses land | CombatManager / Player | every later frame |

**Interface contract:**

- `CombatManager.begin_battle() -> void` — public, idempotent, guarded; callable sync or deferred; the only new cross-component seam.
- `CombatManager._on_battle_started()` — now skips empty rosters; unchanged signature/signal wiring (`GameManager.battle_started`).
- `SceneManager.SCENE_MAP` — `"BATTLE" -> "battlefield"`; router logic untouched.
- `battlefield._setup_encounter_battle()` — queues HUD wiring then `begin_battle` (both deferred); no other caller changes.
- Playtest surface: `empty_round_stalls` must exist on `CombatManager` (it already does as a public var — only the spec whitelist changes).
- Node/signal names, `class_name`s, and method signatures in the existing surface (`Player`, `Sparring_Partner`, `SkillButton1..12`, `CultivationScreen`, …) remain **verbatim** — they are the harness contract.

---

## 5. Edge cases → design decisions (traceability to the SOTA report)

| SOTA edge case | Where this design answers it |
|---|---|
| Round-start ordering (the killer race) | C2 + C3: round 1 begins only via the guarded seam after both units are registered; the pre-swap `battle_started` is skipped when the roster is empty. |
| `SCENE_MAP` gap | C1: one-line map entry; `swap_to` no-ops when already hosted (tutorial); WON/LOST stay unmapped. |
| Second encounter in one session | `request_continue`/`request_retry` already `clear_battle()` for segment routing (verified in `game_manager.gd`), so `set_player` first-call-wins cannot swallow a rebuilt player; teardown order unchanged. |
| Profile-null guard | `_setup_encounter_battle` early-return + `begin_battle()`'s own roster guard — double protection. |
| Deterministic frame timing | Deferred FIFO flush at the end of the battlefield's `_ready` frame; `debug_round_frame` is the measurement anchor; press margins ≥ 12 frames. |
| RNG/deck sensitivity | No RNG touched; yearly draws still consume `SaveManager.rng` only; scenario seed unchanged. |
| Damage digit determinism | No damage code touched; expected digits (21→39, 26→34, 28→32, heal 6, ×1.08) are derived, not tuned. |
| HUD/tutorial flags in ENCOUNTER mode | `tutorial_battle == false` asserted; HUD wiring flushed **before** `begin_battle()` so buttons and listeners exist when round 1 starts. |
| Vision gate Q3 on battle scenes | Expected to resolve as a side effect of a live round loop (real cooldown/state changes); no button-visual code special-cased. |
| Non-goal battles untouched | `each_unit_acts_once_per_round_initiative_order`, `dot_resolves_at_victim_turn_start`, `terminal_victory_8_12_rounds` untouched — no tutorial content numbers or AI behavior change; no assertion edits there. |

---

## 6. Verification plan

### 6.1 Unit level (`run_tests.sh`, unchanged script)
- `godot --headless -s res://tests/test_encounter.gd` — must stay green. Analysis: test (a) asserts wiring only (no phase assert), so the deferred kick-off does not break it; the queued `begin_battle` fires after teardown's `reset_battle()` + `clear_battle()` and self-guards to a no-op. Test (b) `start_encounter` now proceeds through `_on_battle_started` with a non-empty roster (units spawned) — signal-order asserts unaffected.
- **Additive test (recommended, small):** in `test_encounter.gd`, a `_test_encounter_battle_live` case — spawn the battlefield, `await get_tree().process_frame` once (deferred flush completes), then assert `CombatManager.phase == "PLAYER_TURN"`, `CombatManager.current_round == 1`, `CombatManager.empty_round_stalls == 0`, and `CombatManager.active_unit_name == "ProgressionHero"`. This is the unit-level regression pin for the exact bug this round fixes.
- `test_game_manager_fsm.gd` — asserts signal order only (`battle_started` then `state:BATTLE`); unaffected by the CombatManager-side skip.
- `test_battle_setup.gd`, `test_gongfa_cascade.gd`, `test_trait_effects.gd`, `test_save_manager.gd`, `test_cultivation.gd`, `test_skill_button_states.gd` — untouched, must stay green (no files they read change behavior).

### 6.2 Integration level (`playtest_spec.yaml`)
- `cultivation_changes_combat` fully green (29/29 including the new `empty_round_stalls == 0` + round-1 liveness asserts).
- `trait_combat_effects_and_twelve_slots`, `sect_switch_same_school_connects`, `save_load_roundtrip`, `spine_to_ending` green.
- The 12 protected tutorial battle scenarios byte-identical (the only additive is the optional `empty_round_stalls: 0` assert in `round_one_snapshot_and_turn_order`).

### 6.3 Vision gate Q3
Battle-scene screenshots should now show real state transitions across frames (cooldown/selection changes) once the encounter round loop is live; no visual-code changes are designed.

### 6.4 Rollback
No irreversible operations, no data migration, no asset rewrites. Rollback = revert `scene_manager.gd` / `combat_manager.gd` / `battlefield.gd` / `playtest_spec.yaml`. (The "backup → execute → verify → delete old" migration constraint does not apply: nothing is deleted or rewritten in place; all edits are additive to source files under git.)

---

## 7. Task decomposition (for PM)

| Task | File(s) | Acceptance |
|---|---|---|
| T1: BATTLE map entry | `./scripts/autoload/scene_manager.gd` | `SCENE_MAP` contains `"BATTLE": "battlefield"`; tutorial swap no-op preserved; WON/LOST unmapped |
| T2: guarded kick-off seam | `./scripts/autoload/combat_manager.gd` | `begin_battle()` + `_begin_if_ready()` as specced; `_on_battle_started` skips empty roster; stall guard untouched; `test_encounter` green |
| T3: encounter kick-off | `./scripts/battlefield.gd` | deferred HUD-wiring + deferred `begin_battle()` queued in FIFO order, last statements of `_setup_encounter_battle()`; doc comment corrected; profile-null early return preserved |
| T4: playtest re-baseline | `./playtest_spec.yaml` | surface gains `empty_round_stalls`; new liveness asserts in the two encounter scenarios + optional tutorial assert; all four encounter scenarios green, tutorial scenarios byte-identical |
| T5: additive unit pin (optional but recommended) | `./tests/test_encounter.gd` | `_test_encounter_battle_live` proves phase/round/stall values after one deferred flush |

Dependency order: T1/T2 are independent; T3 depends on T2; T4 depends on T1-T3; T5 after T2.

---

## 8. Tech stack & extension considerations

- **Stack:** Godot 4.4 + GDScript only; no new dependencies, no addons, no assets (per SOTA). Linters: `.gd` is excluded from `linter_manifest.json` (handled by the host `gdscript_check` gate); `basic` covers `.json/.yaml/.md/.tscn/.tres`.
- **Extensions left open (not built now):** more encounter battles are rows in `EncounterData`/`BattleSetup` — `begin_battle()` is content-agnostic; any future mode whose units are registered by its scene can reuse the same guarded seam, and any signal-driven mode keeps `battle_started`. No new abstraction layers are introduced — the two-line guard and one map entry are the entire new surface.
- **Deliberately not done:** no WON/LOST scene keys, no `empty_round_stalls` guard changes, no tutorial content/AI changes, no visual special-casing.

## 9. Playtest contract summary (for PM)

`scene`: `res://scenes/main.tscn` (unchanged). `actions`: unchanged (all 25 actions already declared, incl. `debug_enter_encounter`, `skill_9..12`). `surface`: one-line delta to `CombatManager` (add `empty_round_stalls`). Scenarios: two additive assert blocks + one optional tutorial assert, with the frame re-baseline rule from §3/C4. Frame cap 3000 unchanged.
