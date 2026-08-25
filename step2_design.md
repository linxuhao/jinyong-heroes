# Technical Architecture Design — Round: Click-Driven Battle Movement

Project: Huashan Sword Tournament (Godot 4 grid tactics). Round goal (from `design/99_changelog.md` rows 2026-08-25 and the SOTA report):

1. **Click-driven battle movement** — left-click an empty tile walks there; right-click undoes the whole turn's movement back to the turn-start tile; a successful action (attack/skill) commits the movement (no more undo). Arrow keys stay as a shortcut, no longer the primary interaction.
2. **Focus-mode fix** — battle HUD buttons must never hold keyboard focus, so GUI focus navigation stops swallowing arrow keys (the reported "sometimes can't move" defect).
3. **Creation screen: one primary interaction** — the `▶` keyboard-cursor text model is removed; the button set is the single visible surface; keyboard input degrades to pure shortcuts (behavior pinned by 11/11 + 19/19 scenarios).
4. **Click-aware movement-range highlight** — `MoveRangeHighlight` expresses the "trying" state: where right-click returns to (turn-start tile), whether undo is available, and reacts to click-driven movement.

All design is grounded in verified repo reads: `scripts/characters/player.gd`, `scripts/autoload/combat_manager.gd` (`begin_turn` at line 684), `scripts/autoload/grid_manager.gd` (`world_to_grid`/`move_unit`/`is_walkable`/`is_occupied`), `scripts/ui/move_range_highlight.gd`, `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, `scenes/ui/skill_button.tscn`, `scripts/segments/creation.gd`, `scenes/segments/creation.tscn`, `playtest/_common.yaml` (surface whitelist + `clicks:` spec), `playtest/click_targeting_fixed.yaml`, `playtest/movement_range_highlight.yaml`, `tests/test_playtest_contract_smoke.py`.

---

## 1. Overview

The battle already has one proven mouse path: `player._unhandled_input` (left button) → `_handle_click_targeting(event)` → `handle_world_click(world_pos)` → `GridManager.world_to_grid` → living-enemy match → `_try_attack_target`. The enemy `_input` relay converges on the same public `handle_world_click`. This round extends that single convergence point rather than creating a second mouse architecture:

- `handle_world_click` gains a **fallback branch**: no enemy on the clicked tile → click-move to that tile (enemy-first resolution preserves `click_targeting_fixed`, clicking one's own tile is a no-op).
- A **sibling right-button branch** in `_unhandled_input` implements undo; the harness drives it with the `clicks:` `right` token (real `InputEventMouseButton` events — no DEBUG action, no test-only path).
- Movement **reuses `_try_move` byte-for-byte** as the single mutation path: a new pure path planner (`GridManager.plan_movement`) resolves the clicked tile into a cardinal step list under the exact `_try_move` cost model (walkable + unoccupied landing, 身轻如燕 swallow-lightness slide at cost 2), and a step queue executes it one `_try_move` call per step.
- The turn-start snapshot (`turn_start_grid` / `turn_start_moves_left` / `turn_start_moved`) is written by `CombatManager.begin_turn` — the engine already owns the turn-start lifecycle and budget reset, so the snapshot lives there, next to the `moved`/`acted` resets.

### 1.1 State machine: 试走 (trial) → 反悔 (undo) → 出手即锁定 (commit)

| State | Entry | Exit |
|---|---|---|
| **trial** | turn start (`begin_turn` snapshot) or after any move | undo, or commit |
| **undo** | right-click while not committed | restores snapshot: `grid_pos = turn_start_grid`, `moves_left = turn_start_moves_left`, `moved = turn_start_moved` (animated via `GridManager.move_unit`) |
| **commit** | `acted` becomes true (engine sets it only on successful execution) or turn ends | undo permanently refused this turn |

**Two rules, decided here and recorded for downstream:**

- **Commit blocks UNDO, not movement.** `design/10_systems.md` §5.1 "移动与动作的先后不限" (move and act in any order) is a pinned rule, and `playtest/movement_range_highlight.yaml` explicitly pins `MoveRangeHighlight.visible == true` AFTER acting with `moves_left > 0` (the node's own comment forbids `acted` from entering the hide condition). Click-move after acting therefore stays allowed; only the undo affordance dies at commit. Reason: changing the order-unrestricted rule would break the pinned scenario and contradict the design doc — commit semantics are new, the movement rule is not.
- **Commit condition is exactly `acted == true`** (player's own turn). The engine resets `acted = false` in `begin_turn`, so "acted became true since turn start" is simply `acted == true` while it is the player's turn. End-turn commits implicitly: after `end_current_turn` it is no longer the player's turn and the input gate already blocks all battle input.

---

## 2. Architecture Diagram (text)

```
                    Viewport input pipeline (_input → GUI focus nav → shortcut → _unhandled_input)
                                                          │
        ┌─────────────────────────────────────────────────┼───────────────────────────────┐
        │ LEFT click (empty tile / enemy)                 │ RIGHT click                    │ enemy hit-surface relay
        v                                                  v                                v
player._unhandled_input ──_handle_click_targeting   player._unhandled_input ──right branch  enemy.gd._input
        │                                                  │                                │
        └──────────────────────┐                           └──── handle_world_right_click ──┘
                               v                                                     │
                    handle_world_click (single convergence point)                    │
                               │                                                     │
        world→grid: GridManager.world_to_grid(event-canvas-space position)           │
                               │                                                     │
              ┌────────────────┴────────────────────┐                                │
              │ living enemy at tile? YES           │ NO: click_grid == grid_pos? no-op
              v                                      v                                │
   _try_attack_target (UNCHANGED, all gates)   _try_move_to(click_grid)               │
                                                      │                               │
                              GridManager.plan_movement(from, budget, slide_ok)       │
                              (pure BFS — EXACT _try_move cost model, returns steps)  │
                                                      │                               │
                                              step queue ──> _try_move(dir) ×N        │
                                              (single mutation path, budget/occupancy │
                                               re-validated per step; tween per step)  │
                                                      │                               v
                                     _on_move_completed pops next step    committed (acted)?
                                     ────────────────────────────────── NO ──> GridManager.move_unit
                                     Player.undo_available (recomputed                 (self, grid_pos, turn_start_grid)
                                       per frame in _process)                          + budget/moved refund
                                                      │                        YES ──> hint 「已出手,无法退回」, no state change
                                                      v
                                  MoveRangeHighlight (polls player each frame):
                                  reachable BFS (unchanged hide rules) + start_tile marker
                                  + undo_available mirror (drawn/observable)

Engine side:
CombatManager.begin_turn(unit) ──> budget reset (unchanged) ──> snapshot block:
        unit.turn_start_grid = unit.grid_pos
        unit.turn_start_moves_left = unit.moves_left   # AFTER next-turn restrictions
        unit.turn_start_moved = unit.moved             # (guarded: fields exist only on Player)

Focus fix (static, per-scene):
hud.tscn: PauseButton / EndTurnButton / AttackButton  += focus_mode = 0
skill_button.tscn: root SkillButton (⇒ all SkillButton1..12 instances) += focus_mode = 0
⇒ no battle Control can ever hold focus ⇒ ui_* focus navigation never consumes arrows ⇒
  move_up/down/left/right reach _unhandled_input deterministically (the "intermittent" defect dies)
```

---

## 3. Component List

### 3.1 `scripts/characters/player.gd` — click-move + undo controller

**Responsibility:** resolve world clicks into movement and undo on the player unit, without forking the movement rules.

**New state (playtest-surface observables):**
```gdscript
var turn_start_grid: Vector2i = Vector2i(-1, -1)   # engine-written at begin_turn; init in setup()
var turn_start_moves_left: int = 0                  # AFTER next-turn restrictions
var turn_start_moved: bool = false
var undo_available: bool = false                    # recomputed EVERY frame in _process()
var _pending_move_steps: Array[Vector2i] = []       # private step queue
```

`undo_available` is recomputed every frame (same pattern as `_refresh_sprite_clamp`), **never** event-written:
```gdscript
undo_available = (not acted) and (grid_pos != turn_start_grid or moves_left != turn_start_moves_left)
```
Per-frame recompute is the robust choice: `acted` is written externally by the engine on successful execution, and this formula can never go stale no matter who writes what.

**Interface changes:**

- `func _try_move(direction: Vector2i) -> bool` — signature changes `-> void` to `-> bool` (true = step accepted and tween scheduled). **All existing gates, cost bookkeeping and side effects byte-identical** — only the return value is new; existing callers (`_unhandled_input` movement arms) legally ignore it in GDScript, so the 37 keyboard-driven scenarios are untouched.
- `func _try_move_to(target_grid: Vector2i) -> void` — new, private. Gates: `TutorialManager.is_input_allowed("move")` (else `action_hint.emit("教程尚未解锁")` — same literal the skill path uses), `moves_left > 0`, `target != grid_pos`, `GridManager.is_walkable(target)` (silent — clicking the border ring is not a meaningful rejection). Then `GridManager.plan_movement(grid_pos, moves_left, traits.has("swallow_lightness"))`; unreachable → `action_hint.emit("走不到那里")` and return. One step → plain `_try_move(step)`. Multiple → fill `_pending_move_steps`, pop-front the first and `_try_move` it.
- `func _on_move_completed() -> void` — modified: if `_pending_move_steps` is non-empty, pop the next direction, `_try_move` it, and **return early if it succeeded** (next completion callback is already scheduled); on a failed step clear the queue. Otherwise fall through to the existing `is_moving = false` + grid-centre snap. This eliminates the stuck-`is_moving` deadlock if a planned step ever fails mid-queue.
- `func handle_world_click(world_pos: Vector2) -> void` — modified, one append after the enemy-match loop (the loop and its `break` are untouched):
  ```gdscript
  if click_grid == grid_pos:
      return                       # click on own tile: no-op
  _try_move_to(click_grid)
  ```
  Enemy-first resolution is preserved: `click_targeting_fixed` (2/2 green) keeps its exact evidence chain. The enemy relay path can never reach the move branch (it only fires on enemy hit-surfaces, which always match an enemy).
- `func handle_world_right_click(world_pos: Vector2) -> void` — new, **public** (mirrors the `handle_world_click` relay shape). Same 4-condition gate (state == BATTLE, `is_player_turn()`, not paused, not `is_moving`). Then: `if acted: action_hint.emit("已出手,无法退回"); return`. If already at turn start with full budget (`grid_pos == turn_start_grid and moves_left == turn_start_moves_left`): silent no-op (benign — nothing to undo). Otherwise restore: `moved = turn_start_moved`, `moves_left = turn_start_moves_left`, `is_moving = true`, `GridManager.move_unit(self, grid_pos, turn_start_grid)`, `grid_pos = turn_start_grid`, and schedule `_on_move_completed` after `MOVE_DURATION` (same tween pattern as `_try_move` — animated, not an instant snap; `move_unit` keeps occupancy consistent).
- `_unhandled_input` — one new sibling branch (placed after the left-click branch):
  ```gdscript
  elif event is InputEventMouseButton \
          and event.button_index == MOUSE_BUTTON_RIGHT \
          and event.pressed:
      handle_world_right_click(get_canvas_transform().affine_inverse() * event.position)
      get_viewport().set_input_as_handled()
  ```
- `setup()` — initialise `turn_start_grid = grid_pos`, `turn_start_moves_left = moves_left`, `turn_start_moved = false` so the fields are sane before the first `begin_turn`.

**New Chinese hint literals (grep-able acceptance points, consistent with the existing 7 reason texts):** `走不到那里` (unreachable tile), `已出手,无法退回` (undo refused after commit), `教程尚未解锁` (reused for tutorial-blocked click-move).

### 3.2 `scripts/autoload/combat_manager.gd` — turn-start snapshot (engine side)

**Responsibility:** own the snapshot in the same lifecycle that already owns budget reset. **No other engine behavior changes.**

In `begin_turn(unit)` (line ~684), immediately after the existing budget-reset block (AFTER the `no_move_next_turn` / `move_minus_next_turn` restriction application so the snapshot records the effective budget), append:
```gdscript
if unit.is_player() and "turn_start_grid" in unit:
    unit.turn_start_grid = unit.grid_pos
    unit.turn_start_moves_left = unit.moves_left
    unit.turn_start_moved = unit.moved
```
Guards keep it inert for enemies (which have neither the fields nor need them); `begin_turn` remains a no-op for enemy units apart from the existing lifecycle. `execute_action` is **not** touched — commit is *read* as `acted` by the player, never a second writer.

### 3.3 `scripts/autoload/grid_manager.gd` — pure movement planner

**Responsibility:** one pure function that encodes the `_try_move` cost model, so path resolution and highlight reachability cannot drift apart.

```gdscript
## Pure planner: BFS/SPFA over the grid under the EXACT _try_move cost model.
## from: origin tile. budget: movement points. slide_ok: 身轻如燕 enabled.
## Returns { "dist": {tile: cost}, "steps": {tile: Array[Vector2i] of step directions} }.
## Neighbor step cost 1 (walkable + unoccupied landing); slide-through of an
## occupied tile costs 2 and lands on the walkable unoccupied tile beyond
## (one direction entry encodes the whole 2-tile slide — _try_move executes it
## natively). Landing tiles are never occupied; the origin is seeded at cost 0.
func plan_movement(from: Vector2i, budget: int, slide_ok: bool) -> Dictionary
```
Reuses the existing relaxation pattern (`_relax`-style re-enqueue, needed because mixed 1/2 costs mean a later cheap path can beat an earlier expensive one). Grid is 15×11 with budget ≤ ~6 — performance is a non-issue.

### 3.4 `scripts/ui/move_range_highlight.gd` — "trying" state

**Responsibility:** show where right-click returns to and whether undo is available, on top of the existing reachable-set overlay.

**Changes (additive only — the pinned `movement_range_highlight` scenario asserts `visible` / `tile_count` / `fill_color`, none of which change semantics):**

- New observables: `var start_tile: Vector2i = Vector2i(-1, -1)`, `var undo_available: bool = false`. Polled every frame from `player.turn_start_grid` / `player.undo_available` in `_process` (before the diff early-return), and `start_tile` is added to the cheap-diff key set so the marker redraws when it changes.
- New draw constant `START_EDGE` (a bright amber-green edge, distinct from `MOVE_FILL`/`MOVE_EDGE` and from `RangeHighlight`'s blue/red) and in `_draw()` an edge-only marker rect on `start_tile`.
- **The visibility/hide condition is UNCHANGED.** `acted` must NOT enter the hide condition (documented in the file, pinned by `movement_range_highlight.yaml`, and required by the "commit blocks undo, not movement" rule of §1.1). The commit state is expressed through `undo_available` flipping false — never by hiding the reachable set.
- Optional (guarded) refactor: `_recompute` may switch to `GridManager.plan_movement` (throwing away its private BFS) **only if** `movement_range_highlight` stays byte-green; otherwise keep the private BFS and the planner coexists. Flag any deviation in the delivery notes.

### 3.5 Battle focus-mode sweep — `scenes/ui/hud.tscn`, `scenes/ui/skill_button.tscn`

**Responsibility:** make "no battle Control ever holds focus" a static, per-scene property.

- `./scenes/ui/hud.tscn`: add `focus_mode = 0` to `PauseButton`, `EndTurnButton`, `AttackButton` (the three buttons that currently default to FOCUS_ALL).
- `./scenes/ui/skill_button.tscn`: add `focus_mode = 0` to the root `SkillButton` node — covers all SkillButton1..12 instances in one edit.
- Sweep check (same task): any other `Button` in battle-visible UI (e.g. `scenes/ui/tutorial_overlay.tscn` if it has clickables) gets the same line, per the changelog implementation rule "新增可点控件一律显式设 focus_mode = 0". Do NOT touch creation/menu/settings scenes (already correct, 29 sites).

**Why static per-scene instead of code:** the defect is a scene-authoring property (a Control with default focus mode); fixing it in `.tscn` is diff-visible, matches the 29-site precedent, and the new scenario asserts the result numerically via the `focus_mode` observable.

### 3.6 Creation screen single-UI — `scenes/segments/creation.tscn`, `scripts/segments/creation.gd`

**Responsibility:** collapse the two parallel operation surfaces (keyboard `▶` cursor text model in `BodyLabel` vs `MouseBox` buttons) into one: **buttons are the single visible interaction surface; keyboard remains a working shortcut layer.**

**`./scenes/segments/creation.tscn`:**
- **Remove the `BodyLabel` node** (the `▶` cursor text surface — the "second UI" the user reported). No scenario asserts on it (it is not in the `surface:` whitelist — verified).
- **Add `PointsLabel`** (a `Label`, top area, e.g. centred above `MouseBox`): displays `剩余点数 N`. This carries the points display that used to live inside `BodyLabel`.
- Keep `HintLabel` (new text, below) and **every `MouseBox/...` node name, path and `focus_mode = 0` line byte-identical** (pinned scenarios `creation_traits_back_next_buttons`, `creation_back_to_menu_walk`, `creation_mouse_interaction` depend on node names/paths).

**`./scripts/segments/creation.gd`:**
- `_render()`: delete the `BodyLabel` text-building (all three phases); add `PointsLabel.text = "剩余点数 %d" % points_left`; keep every existing `MouseBox` per-phase visibility/text update as-is.
- **New observable `cursor_markers_visible` — the gate-judged proof that the keyboard-cursor surface is gone.** `var cursor_markers_visible: bool = false`, recomputed at the END of `_render()`: walk every `Label` descendant (e.g. `find_children("*", "Label", true, false)`) and set it true if any label's `text` contains the `▶` marker (U+25B6). Why `▶` is the right signature: the keyboard-cursor model's entire visual language is the `▶` marker in front of the focused attr/trait row — that marker list IS the second, parallel operation surface; the button surface expresses focus through modulate/disabled states and never uses `▶`. So 「no `▶` in any rendered creation text」 ⟺ 「the cursor-list surface is gone」, regardless of which node renders it. A node-absence check (BodyLabel deleted) would miss the cursor model reviving in a different label — this observable goes red in exactly that case, which is why it is asserted `== false` by the playtest gate (scenario 5) instead of being accepted by a `.tscn` diff.
- **Focused-row visual**: in `_render()`, set `modulate` on the focused `AttrRow{i}` (ATTRS) / `TraitToggle{i}` (TRAITS) — focused row `Color(1,1,1,1)`, others `Color(0.72,0.72,0.72,1)`. `attr_index` / `trait_index` thus remain *visible* on the single button surface (they drive which row minus/plus acts on), instead of living in a duplicated text list. No new nodes, no new button names.
- `HintLabel.text` per phase, accurate to the real controls and **without the stale 「右键确认」 promise** (the TRAITS right-click hint promised a handler that never existed — SOTA flags it as a candidate; it dies with the BodyLabel text): ATTRS → `点击 ± 调整属性 · 回车下一步`; TRAITS → `点击切换特质 · 回车进入确认`; CONFIRM → `点击确认踏上江湖 · 回车确认`. (Exact wording is implementer-fine-tunable; the hard requirement is: no right-click promise, no "两个界面".)
- **`_unhandled_input`, `_process` (debug action), `_wire_mouse_widgets` and every handler stay byte-identical** — keyboard keeps working as a pure shortcut with the exact semantics pinned by `creation_budget_clamp_and_traits` (11/11) and `menu_to_creation_to_tutorial_order` (19/19). Arrow keys no longer "move a cursor list" because the cursor list is gone; they move row focus on the button surface.

### 3.7 Playtest contract — `playtest/_common.yaml` + 5 new scenario files + `tests/test_playtest_contract_smoke.py`

**Contract shape statement (for PM & implementer):**
- `scene:` default stays `res://scenes/main.tscn`; the creation scenario overrides with `scene: res://scenes/segments/creation.tscn` (proven direct-boot pattern).
- `actions:` list is **UNCHANGED** — no new input actions, no new DEBUG actions. Right-click is driven exclusively by `clicks:` entries with the `right` token (`"<Node>[ +dx,dy][ left|right|middle]"`), which post real `InputEventMouseButton` events through the real `_unhandled_input` branch.
- `surface:` additions are **append-only, surgical** (never a file rewrite — the previous round's whole-file-rewrite audit is the standing warning):

```yaml
  Player:                    # append to existing block
  - turn_start_grid
  - turn_start_moves_left
  - turn_start_moved
  - undo_available
  MoveRangeHighlight:        # append to existing block
  - start_tile
  - undo_available
  EndTurnButton:             # append
  - focus_mode
  AttackButton:              # append
  - focus_mode
  PauseButton:               # append
  - focus_mode
  SkillButton1:              # append (representative: all 12 share the instanced scene)
  - focus_mode
  PointsLabel:               # new block
  - visible
  - text
  CreationScreen:            # append to existing block
  - cursor_markers_visible
```

**Scenario skeletons** (frames are placeholders for PM calibration; each ≤ 2999; battle preamble = 7× `ui_accept` f3..15 + `tutorial_next` f20/25/30, input live ~f35 — measured shape of the existing battle scenarios; every click needs ~15–30 frames after it before asserting, each walk step ≈ 9 frames (0.15 s tween) — leave 50+ frames after multi-step clicks):

1. `battle_focus_arrow_keys` (focus-mode proof) — main.tscn, battle preamble. Assert the **static contract** `EndTurnButton.focus_mode == 0`, `AttackButton.focus_mode == 0`, `SkillButton1.focus_mode == 0`, `PauseButton.focus_mode == 0`. Then the behavioral differential: `clicks: [AttackButton]` (click focuses a button; its gate-guarded handler emits 「射程不够」 and does NOT end the turn), then `actions: [move_up]`, then assert `Player.grid_pos: changed` (the hard differential rule — arrow still reaches `_unhandled_input` after a button click). Note in the file: the static `focus_mode == 0` asserts are the direct proof of the fix and cannot be vacuous even if the harness synthesizes actions rather than raw keys; the `grid_pos: changed` differential is the end-to-end behavior proof.
2. `click_move_to_tile` (click-move) — main.tscn, battle preamble (player (7,5), moves 4). `clicks: [Player +64,0]` → assert `Player.debug_click_events: changed` (click arrived), `Player.grid_pos == Vector2i(8,5)`, `Player.moves_left == 3`, `Player.moved == true`, `Player.undo_available == true`, `MoveRangeHighlight.start_tile == Vector2i(7,5)`. Then multi-step: `clicks: [Player +0,-192]` (offset is re-anchored to the player's NEW centre → tile (8,2), 3 steps) → assert `Player.grid_pos == Vector2i(8,2)`, `Player.moves_left == 0`. Then no-op control: `clicks: [Player +0,0]` → assert `Player.grid_pos: changed == false`-style differential (grid_pos still (8,2), moves_left still 0 — clicking one's own tile is a no-op; use the `changed` comparator or explicit `==`).
3. `click_move_undo_right` (undo) — main.tscn, preamble. Control probe first: `clicks: [Player +0,0 right]` with nothing moved → assert `Player.grid_pos == Vector2i(7,5)` and `Player.moves_left == 4` (harmless no-op). Then `clicks: [Player +0,-192]` (walk (7,5)→(7,2), budget 1) → assert `grid_pos == Vector2i(7,2)`, `moves_left == 1`, `undo_available == true`. Then `clicks: [Player +0,0 right]` → assert `Player.grid_pos == Vector2i(7,5)`, `Player.moves_left == 4`, `Player.moved == false`, `Player.undo_available == false` (full restore — this is the differential proof that the `right` token truly selects the right button, mirrored by the measured left-vs-right contrast from SOTA).
4. `click_move_commit_lock` (commit) — main.tscn, preamble. `clicks: [Player +0,-192]` → (7,2) adjacent to Central_Divine (7,1), budget 1. Then `clicks: [Central_Divine_ClickTarget]` → basic attack, assert `Player.acted == true`, `Central_Divine.health == max_health - 39` (PROBE number — recalibrate to observed, same convention as `click_targeting_fixed`). Then `clicks: [Player +0,0 right]` → assert `Player.grid_pos == Vector2i(7,2)` (NOT (7,5) — undo refused), `Player.moves_left == 1`, `Player.undo_available == false`.
5. `creation_single_ui` (creation single surface) — `scene: res://scenes/segments/creation.tscn` direct boot. Assert at ~f30: `CreationScreen.visible == true`, `CreationScreen.phase == "ATTRS"`, `PointsLabel.visible == true`, `PointsLabel.text.contains("剩余点数") == true` (the `.contains() … == true` operator rule), `AttrPlus0.visible == true`, `TraitToggle0.visible == false` (phase-scoped single surface), `CreationScreen.pressed_connected.size() > 0` (wiring intact), `CreationScreen.cursor_markers_visible == false` (the runtime proof the keyboard-cursor surface is gone — no `▶` in any rendered label; see §3.6 for why this captures 「two UIs」 and not just 「a node is missing」). Then keyboard-shortcut regression pins: `actions: [move_right]` → assert `CreationScreen.attrs.bone == 11` and `CreationScreen.points_left == 29`; `actions: [move_left]` → back to `10` / `30`. Phase-completeness: after the keyboard pins, press `confirm` (Enter) into TRAITS and re-assert `CreationScreen.cursor_markers_visible == false` and `TraitToggle0.visible == true` — the scan runs at the end of every `_render()`, so each phase's rendered text is covered. Note in the file: this acceptance is judged by the playtest gate, NOT by the `BodyLabel`-removed `.tscn` diff and NOT by the vision gate (whose six fixed questions never ask about UI-surface multiplicity) — a diff is a review aid, not an acceptance gate.

**`tests/test_playtest_contract_smoke.py`:**
- `ROUND_SCENARIOS` becomes the 5 new names **in this exact order**: `battle_focus_arrow_keys`, `click_move_to_tile`, `click_move_undo_right`, `click_move_commit_lock`, `creation_single_ui`.
- Append the same 5 names to `scenario_order:` in `_common.yaml` (same order — the pytest asserts `indices == sorted(indices)`).
- Add `test_click_move_surface_contract()`: assert `Player` block contains `turn_start_grid`, `turn_start_moves_left`, `undo_available`; `MoveRangeHighlight` block contains `start_tile`, `undo_available`; `CreationScreen` block contains `cursor_markers_visible`. Extend the clicks-owner check for the new scenarios: parse each new scenario's `clicks:` items, take the **first whitespace-separated token** as the node name (offset spec strings like `Player +64,0`), strip a trailing `_ClickTarget`, and assert the owner is a whitelisted surface block (`Player`, `Central_Divine`, `AttackButton`). Reuses the existing `_items_under` helper; standard library only.

---

## 4. Interface / Data-Flow Summary (for PM decomposition)

| # | Producer → Consumer | Contract |
|---|---|---|
| 1 | `CombatManager.begin_turn` → `Player` | writes `turn_start_grid` / `turn_start_moves_left` / `turn_start_moved` after budget reset; guarded by `unit.is_player() and "turn_start_grid" in unit` |
| 2 | `player._unhandled_input` / `enemy._input` relay → `handle_world_click(world_pos)` | unchanged signature; new fallback: enemy miss → `_try_move_to(click_grid)` |
| 3 | `_unhandled_input` right branch → `handle_world_right_click(world_pos)` | public, same gate set as `handle_world_click` |
| 4 | `GridManager.plan_movement(from, budget, slide_ok) -> {dist, steps}` | pure; `steps[tile]` = directions, one entry per `_try_move` call (slide = 1 entry) |
| 5 | `_try_move(direction) -> bool` | single mutation path; semantics byte-identical, return value new |
| 6 | `Player` (per-frame `undo_available`) → `MoveRangeHighlight` | polled, plus `turn_start_grid` → `start_tile` |
| 7 | Scenario files → harness | `clicks:` spec strings with `right` token; surface whitelist gate |
| 8 | `_common.yaml` surface → pytest | append-only; new blocks/items above |

---

## 5. Tech Stack

- **Godot 4.4 / GDScript + `.tscn` text scenes** — no new third-party dependencies, no new assets, no new autoloads. Everything is an edit to existing scripts/scenes or a new pure function.
- **Harness features used:** `clicks:` real mouse events (left/right + node-relative offsets) — already shipped and measured (SOTA f31cbc2 / doc 50b9c8f); no new harness work.
- **Python side:** standard-library-only `pytest` contract smoke (`ruff`-linted).
- **Linting:** GDScript via the `gdscript_check`/compile gate (not in the manifest); `ruff` for `.py`; `basic` for `.yaml`/`.json`/`.md` (see `linter_manifest.json`).

## 6. Extensibility Considerations

- `GridManager.plan_movement` is unit-agnostic and budget/slide-aware; future AI movement (enemies currently use the static `find_path` A*) can adopt it without touching the player.
- The snapshot/commit state machine generalises to all units via the `"turn_start_grid" in unit` guard pattern — the engine already writes per-unit turn state.
- `MoveRangeHighlight`'s observables pattern (`start_tile` / `undo_available`) is the template for any future "pending choice" visual (e.g., jump-landing preview) — poll + cheap-diff keys, no signals required.
- The `clicks:` offset addressing needs **zero production per-tile nodes** — scenarios address tiles as offsets from live nodes; production code must NOT grow per-tile click targets this round (SOTA constraint).
- Deliberately NOT built: a separate click-to-move hit-surface Control (measured broken in this codebase — GUI picker never routes to Controls under Node2D ancestors), and no new DEBUG action for undo (the harness's real-mouse `right` token supersedes it; a test-only path is the debt shape this round explicitly avoids).

## 7. Design-Change Declaration (for the 5_design archive step)

**No new design changes are introduced.** This round realises the already-recorded 2026-08-25 decisions in `design/99_changelog.md` rows 66–69 (click-driven movement, trial→undo→commit, focus_mode discipline, creation single-primary-interaction). Two decisions made in THIS document and worth recording downstream:

1. **Commit blocks undo, not movement** — `10_systems.md` §5.1 (order-free move+act) and the `movement_range_highlight` pin stay authoritative.
2. **Creation keyboard input survives as a shortcut layer** acting on the button surface (row focus + ± / toggle / accept), never a second rendered list.

Post-run archive sync candidates for `5_design` (not done here): `30_presentation.md` 输入映射 table (click-primary movement, right-click undo, arrow keys as shortcut), the creation-screen description (single button surface), and a §5.1 note for the trial/undo/commit state machine.

## 8. Safety / Rollback Discipline (irreversible-op rule)

No database, no generated data, no bulk rewrites — but the contract files carry the historical risk, so:

- **`_common.yaml` edits are append-only surgical edits**; the 38 existing scenario files must remain **byte-identical** (the previous round's measured acceptance criterion — `git diff --stat` must touch only `_common.yaml`, the 5 new files, and the pytest file).
- **`creation.tscn` node removal** (BodyLabel) is a text-file edit; verify by direct-boot + `creation_single_ui` + the two pinned creation scenarios (which never referenced BodyLabel). Rollback = git revert of one file.
- **`_try_move` return-type change** is verified by the 37 keyboard-driven scenarios staying green — that is the rollback gate for the single mutation path.
- **Execution order for the gates**: (1) `pytest` contract smoke locally (millisecond gate) before any Godot run; (2) compile gate; (3) playtest gate; (4) vision gate on the battle frames only (its six fixed questions cover battle readability — Q1–Q5 are `applies_to: "battle"`, Q6 is text truncation; none asks about UI-surface multiplicity). The creation single-surface acceptance is the playtest assertion `CreationScreen.cursor_markers_visible == false` in `creation_single_ui`, never a vision question. Fix any red gate in its own task before proceeding.

## 9. Task Decomposition Hints (for PM)

Suggested task sequence with dependencies:
1. **T1 — Player click-move + undo + engine snapshot** (`player.gd`, `combat_manager.gd`, `grid_manager.gd`): planner → `_try_move` bool → step queue → `_try_move_to` → `handle_world_click` fallback → right-click branch + `handle_world_right_click` → `undo_available` per-frame → snapshot block in `begin_turn`. Gate: compile + existing battle scenarios green.
2. **T2 — Focus-mode sweep** (`hud.tscn`, `skill_button.tscn`, tutorial overlay check). Gate: compile + `battle_end_turn_attack_buttons` / `skill_button_visual_states` stay green (focus_mode=0 makes them more robust, not less).
3. **T3 — MoveRangeHighlight trying state** (`move_range_highlight.gd`; optional planner refactor only if `movement_range_highlight` stays byte-green).
4. **T4 — Creation single-UI** (`creation.tscn`, `creation.gd`). Gate: `creation_budget_clamp_and_traits` (11/11), `menu_to_creation_to_tutorial_order` (19/19), `creation_mouse_interaction`, `creation_traits_back_next_buttons`, `creation_back_to_menu_walk` all green.
5. **T5 — Playtest contract**: `_common.yaml` append-only surface + `scenario_order`; author the 5 scenario YAMLs (with PROBE marks where numeric damage is asserted).
6. **T6 — Pytest contract**: `ROUND_SCENARIOS` + `test_click_move_surface_contract` (+ offset-aware clicks-owner parsing). Gate: 4-test pytest green, then full playtest run green with 43 scenario files (38 pre-existing byte-identical + 5 new).
