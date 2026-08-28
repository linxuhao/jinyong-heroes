# Technical Architecture - Jinyong Tactics: Mouse & Info Interaction Defect Fixes

Round: interaction-defects (2026-08-28). **Revision 3** - restructured per the round
owner's feedback of 2026-08-28 07:00 UTC: the #1 defect (real-build left-click
dead) is already characterized, located, fixed and live, so this design schedules
**contract coverage, not characterization cards**; the `InputProbeOverlay` temporary
is already deleted (verify-only). Revision 2's shape - the two-layer net, "a skip is
never green", the honest web/touch boundary - is retained per the same feedback.
This is a **per-run** design (`design/README.md`); the durable `design/` archive is
edited only by `5_design` after final verification passes - the **Design changes**
section below is what `5_design` will land surgically. Everything is in English;
in-game UI copy stays Chinese.

## 1. Overview

This round fixes **measured** player-reported interaction defects. In priority order
after the re-scope:

- **P0: the real-input defect is FIXED and live; this round makes the contract able
  to see that class of defect.** Players reported left-click movement completely
  broken in the real web, desktop-native and touch builds while the headless
  play-test suite was 57/57 green. Root cause, measured by the owner with a real X11
  window + xdotool: `scenes/menu.tscn`'s `SegmentHost` was missing
  `mouse_filter = 2` - a full-rect Control, Godot default STOP, parked over the
  board for the whole game (menu.tscn is `run/main_scene`; SceneManager only swaps
  segments inside it), swallowing every press that did not land on a Button. The
  Revision-2 decision tree's `raw > 0, handled == 0` branch fired; `under` named it.
  Fix `42637b7` is live and player-confirmed on web + desktop. **No characterization
  cards are scheduled** - what remains of P0 is the two-layer coverage net (3.P0):
  Layer 1 permanent differential observables + Layer 2 the windowed X11 input gate,
  whose prototype and four pitfalls the owner already ran.
- **P0b: touch has no undo.** Touch support is landed (commit 0473447) but phones have
  no right-click, so 「右键退回」 is unreachable on touch. This round adds a
  finger-reachable undo control (3.T).
- **Defect B** (portrait drawn a full tile above its grid cell; nameplate on the legs;
  clicking the drawn portrait does not target the unit) and **Defect C** (trait
  descriptions show only on click, not on hover) - both still to do, per the Step-1
  SOTA conclusions (§3 of step1_sota.md).
- **Small fixes:** delivery-notes heading round/date, one map hint (not two identical
  lines), full-width comma in the MAP EVENT branch.

**Already landed outside the pipeline - verify only, do not re-implement, do not
conflict with:**

| Item | Commit | State |
|---|---|---|
| Defect A fix: `Bar.mouse_filter = 2` in `scenes/ui/health_bar.tscn` + per-frame re-assert in `scripts/ui/health_bar.gd::update_health` (comment: a floating HUD control must have no STOP descendant) | `7d2daf7` | Red->green A/B verified on the owner's tree (3/7 red before, 7/7 after; full suite no regression). `playtest/click_move_undo_feet.yaml` (right-click at `Player +0,0`, the feet) is landed and two-place synced |
| Touch support: `player.gd` click branch + `enemy.gd` relay accept `InputEventScreenTouch`; `_handle_click_targeting(event: InputEvent)` | `0473447` | Landed; touch undo gap remains (3.T) |
| `config/name` -> 「华山论剑」 | `393a35e` | Landed; recorded in delivery notes only |
| P0 fix: `menu.tscn` `SegmentHost` gains `mouse_filter = 2` | `42637b7` | Real-X11 A/B measured: before `player_grid=(7,5) raw=3 handled=0 EATER SegmentHost(filter=0)`; after `player_grid=(7,4) raw=3 handled=1 EATERS none`. Player-confirmed working on web + desktop |
| Two pytest guards in `tests/test_playtest_contract_smoke.py` | `42637b7` | 19 passed. `test_every_full_rect_host_is_click_through` scans every `.tscn` under `scenes/` and reddens any `SegmentHost` block without `mouse_filter = 2` (would have caught both occurrences); `test_the_contract_boot_scene_is_recorded_against_the_games_own` forces the contract-boot-vs-game-boot divergence to stay documented in the `_common.yaml` header (which now carries it, with the defect story) |
| `InputProbeOverlay` deleted (script + `hud.tscn` node stanza + ext_resource line) | `1989be6` | Landed; 3.O is now a confirm-clean pass, NOT a re-implementation |

**Why a 57/57-green suite could not see it (both recorded in `90_decisions.md`,
3.P0):** (1) the contract's default `scene:` is `res://scenes/main.tscn` while the
game's `run/main_scene` is `res://scenes/menu.tscn` - every scenario graded the
fixed twin; (2) `clicks:` injects via `Input.parse_input_event()`, which never
reaches the GUI phase where a STOP control eats the event.

## 2. Architecture / data flow

```
Real pointer (player's hand)
  browser JS bridge / X11 window / touch panel      <-- the layer parse_input_event()
                                                       BYPASSES: the X11 leg is now
                                                       covered by the windowed gate
                                                       (3.P0 layer 2); the browser
                                                       bridge stays manual-only
  -> OS event -> Window (content-scale transform) -> engine input pipeline
     player.gd::_input   (raw counters: debug_input_events / debug_right_input_events;
                          census: debug_gui_eater = predicted GUI eater at that point)
     enemy.gd::_input    (own-tile relay, runs BEFORE GUI; set_input_as_handled)
     GUI phase           (STOP Controls under the pointer swallow the event here)
     player.gd::_unhandled_input -> _handle_click_targeting -> handle_world_click(world)
                                       [Defect B hit resolver lives here - position-
                                        based, so mouse and touch share it]
     player.gd::_unhandled_input -> handle_world_right_click(world)  (undo)
                                    + [NEW] UndoButton.pressed -> same undo entry (3.T)

Headless play-test (regression contract, unchanged pipeline)
  godot_harness clicks:/hovers: -> Input.parse_input_event -> SAME engine pipeline
  -> differential asserts (raw vs handled counters) pin the post-engine chain

[NEW] Windowed X11 input gate (sidecar /x11_input_smoke; owner-prototyped 2026-08-28)
  copy repo to a writable /tmp path -> godot --headless --import (TWICE) ->
  Xvfb display -> godot WINDOWED (not --headless), real menu.tscn boot ->
  xdotool mousemove + click (driver targets buttons BY NAME from the live report,
  never coordinates) -> real window layer -> engine pipeline -> InputGate report
  JSON -> harness asserts raw counters advanced AND game state changed  (3.P0 L2)

Hover (creation screen)
  Button.mouse_entered / mouse_exited -> trait_hover_index -> _render() -> TraitDescLabel

Per-frame draw order (scenes/battlefield.tscn, siblings, no z_index):
  SummitBackdrop -> Grid -> GridLines -> RangeHighlight -> MoveRangeHighlight
  -> Characters (unit art paints OVER highlights) -> [NEW] TileMarkers (paints OVER art,
     so the ground marker is visible even for top-row units whose clamped art covers
     their own feet)
```

Input pipeline order fact (why the differential works): `Node._input` runs for every
node **before** the GUI phase; `_unhandled_input` runs after it. So
`raw > 0 and handled == 0` uniquely identifies "a STOP Control ate it in the GUI
phase" (the Defect A signature), while `raw == 0` means the event never entered the
engine at all - exactly the class the headless harness cannot produce and only the
X11 gate / live `?debug=1` readings can see.

## 3. Design changes (declared for the `design/` archive)

`5_design` lands these after verification. Each is doc-first: rationale lands in
`design/` (`10_systems.md` / `30_presentation.md` / `90_decisions.md` /
`40_ux_backlog.md`) and one row in `99_changelog.md`. Chinese UI strings are quoted
verbatim.

### 3.0 Re-scope (recorded in `99_changelog.md` row + `90_decisions.md`)

Two re-scopes, both by the round owner, both cumulative. (1) 2026-08-27 23:48 UTC:
Defect A's fix, touch support and `config/name` landed outside the pipeline, and
real-input coverage was elevated above the original three defects. (2) 2026-08-28
07:00 UTC: the real-input defect itself is also landed (`42637b7`, root cause
`menu.tscn`'s `SegmentHost`) together with two pytest guards, and the
`InputProbeOverlay` temporary is deleted (`1989be6`). This design therefore
schedules **no characterization work** - what remains of P0 is converting the
owner's one-off X11 prototype and `?debug=1` triad into permanent, assertable
contract coverage (Layer 1 + Layer 2). Defect A's audit residue (NameLabel filter,
ClickTarget measurement) stays, because the brief demands those verdicts be
**recorded in design/**, not just fixed.

### 3.A Defect A - landed; residual audit

**Landed (do not redo):** `Bar.mouse_filter = 2` (tscn) + the per-frame re-assert in
`update_health` next to the two existing sibling assertions; scenario
`playtest/click_move_undo_feet.yaml` (clicks `Player +0,0 right` - the feet, inside
the old dead zone - after a one-tile move, asserts the retreat:
`grid_pos == (7,5)`, `moves_left == 4`, `moved == false`, `undo_available == false`).
The existing `click_move_undo_right.yaml` (`Player +64,0`) stays byte-untouched.

**Residual audit (this round, measured not assumed):**
- HealthBar subtree: root `HealthBar` (2 ✓), `Bar` (2 ✓ landed), `EmptyCap` (2 ✓),
  `HpLabel` (2 ✓), `NameLabel` (Label - Godot default IGNORE, but **set
  `mouse_filter = 2` explicitly in `health_bar.tscn`** for defensiveness and
  consistency with its siblings; the 2026-08-25 `SegmentHost` discipline: a default
  that happens to be correct is still a hole). Record the measured per-node filter
  table in `design/30_presentation.md`.
- Enemy `ClickTarget` (`scenes/enemy.tscn`, mouse_filter=0 STOP, child of the Enemy
  Node2D): the brief demands a measurement of whether its `gui_input` ever fires, not
  the comment's claim. **Pin the deadness itself**: add `debug_click_target_fires: int`
  on `enemy.gd` (incremented in the existing `_on_click_target_gui_input`), whitelist
  it, and add a leg to the differential scenario that clicks the
  `Central_Divine_ClickTarget` rect and asserts
  `debug_click_target_fires == 0 and debug_click_events: changed` - the click still
  lands because `enemy._input` pre-handles own-tile presses before the GUI phase.
  Verdict recorded in `30_presentation.md`: "ClickTarget gui_input measured 0 fires
  (dead for routing, cannot eat events); node **kept** - it is the harness click
  anchor `click_move_commit_lock.yaml` resolves by name; authored `mouse_filter`
  left unchanged (zero-diff; it is inert either way)."

### 3.P0 The real input path: making the contract able to see it

**Resolved root cause (measured by the owner, landed in `42637b7` - do not
re-derive):** `scenes/menu.tscn`'s `SegmentHost` was missing `mouse_filter = 2`. The
deployed `?debug=1` triad read `raw > 0, handled == 0` - exactly the Revision-2
decision tree's "STOP Control in the GUI phase" branch - and `under` reported
`EATER SegmentHost(filter=0, /root/Main/SegmentLayer/SegmentHost)`. Real-X11 A/B
around the one-line fix: before `player_grid=(7,5) raw=3 handled=0 EATER
SegmentHost(filter=0)`; after `player_grid=(7,4) raw=3 handled=1 EATERS none`.
Players confirmed web + desktop left-click both work. This is the **second**
full-rect STOP hole of the same node name (the first was `main.tscn`, recorded in
the `_common.yaml` `clicks:` note); the fix landed there, its structural twin never
got the line. The two reasons it dodged a 57/57-green suite are recorded in
`90_decisions.md`: the contract's default `scene:` is `main.tscn` while the game's
`run/main_scene` is `menu.tscn` (all scenarios graded the fixed twin), and `clicks:`
injection via `Input.parse_input_event()` never reaches the GUI phase where a STOP
control eats the event. Two machine guards landed with the fix and pin the class
(§1 table): `test_every_full_rect_host_is_click_through` (every `.tscn` under
`scenes/` must declare `mouse_filter = 2` on every `SegmentHost` block) and
`test_the_contract_boot_scene_is_recorded_against_the_games_own` (the boot-scene
divergence must stay documented in the `_common.yaml` header, which now carries it).

**What remains of P0 this round: the two-layer coverage net.** The defect is fixed;
the *blindness* is only half-fixed - the landed guards are static text scans, so
they cannot see a STOP hole in any other node type, and nothing yet proves on the
server that a real window-layer press survives to a state change. Layer 1 makes the
post-engine chain assertable per-press; Layer 2 is that server-side proof.

**Layer 1 - permanent in-game differential observables (in-repo, always on).**
The repo already has `debug_input_events` (left presses + touches reaching `_input`),
`debug_last_raw_event_pos`, `debug_click_events` (entries into `handle_world_click`),
`debug_last_click_grid` - whitelisted and used (`click_move_to_tile.yaml` f45).
Gaps this round closes in `scripts/characters/player.gd` (additive only - the
existing vars' semantics stay byte-identical, they are documented in the
`_common.yaml` header and pinned by existing scenarios):
- `debug_right_input_events: int` - raw **right**-presses reaching `_input` (a new
  var, not a widening: the undo path currently has no raw counter at all).
- `debug_undo_events: int` - entries into `handle_world_right_click` (increments
  before the gate, mirroring `debug_click_events`).
- `debug_gui_eater: String` - at every press (left/right/touch) observed in `_input`,
  run the census walk and record the topmost visible non-IGNORE Control containing
  the point ("" if none). Port the walk from the deleted overlay's `_process`
  (source of truth = git history, commit a673a42; the file itself was removed in
  `1989be6`) into a
  new static helper `scripts/ui/input_census.gd` (`class_name InputCensus`,
  `static func top_eater(root: Node, pos: Vector2) -> String`) so the permanent
  observable is behavior-identical to the deployed probe. Cost: per-press only (the
  overlay ran it every frame), ~100-node tree - negligible. Semantics: it is the
  *predicted* eater if the event survives to the GUI phase; for enemy-tile clicks
  the `enemy._input` relay pre-handles the press, so a non-empty eater there does
  **not** mean the click failed - which is why the scenario below asserts emptiness
  only at points with no authored Control (feet / empty tiles) and pairs the
  enemy-tile leg with `debug_click_events` instead.
- New scenario `playtest/input_click_differential.yaml` (C-P1): boots the tutorial
  battle, then (a) left-click `Player +0,-64` (empty tile) -> assert
  `debug_input_events: changed`, `debug_click_events: changed`,
  `debug_gui_eater == ""`; (b) right-click `Player +0,0` (feet, the old Bar dead
  zone) -> assert `debug_right_input_events: changed`, `debug_undo_events: changed`,
  `debug_gui_eater == ""` (this is the permanent form of the Defect A probe: a STOP
  control reappearing under the feet reddens here); (c) left-click the
  `Central_Divine_ClickTarget` rect -> assert `debug_click_events: changed` and
  `Enemy.debug_click_target_fires == 0` (the 3.A measurement pin). This turns
  "the event arrived AND was processed" into an assertable quantity in the existing
  headless contract - the class-level regression net for every future STOP-filter
  hole (Defect A family), independent of where the click was aimed. (This scenario
  grades `main.tscn`, the contract default; the `menu.tscn` twin is covered by the
  landed static guard + the Layer-2 real-boot walk - the divergence note and its
  guard are already in the tree.)

**Layer 2 - windowed X11 input gate (sidecar; the server-side "players can click"
proof). Owner-prototyped on 2026-08-28 - the pitfalls below are measured, not
speculative; build on them, do not re-find them.** `Input.parse_input_event()` never
traverses the window layer, so the contract needs one run that does. New sidecar
endpoint `/x11_input_smoke` (AItelier-side harness change, **requires a sidecar
image rebuild** - xdotool must be baked into the Dockerfile; an `apt-get install` at
run time lives in the container's writable layer and evaporates on rebuild):
1. **Copy the project to a container-writable path first** (the owner used `/tmp/rp`):
   the repo mount is read-only inside `aitelier-godot` and `--import` must write
   `res://.godot/` - otherwise `Cannot create file
   res://.godot/editor/filesystem_cache10`.
2. **Run `godot --headless --path <proj> --import` TWICE** before the windowed run -
   once is not enough: fonts/themes fail to load, `preload()` becomes a parse error,
   GameManager never comes up, and the log drowns in ~95000 script errors.
3. Start Xvfb (already present in the sidecar) at 960×704×24; run the game
   **windowed** (not `--headless`): `DISPLAY=<xvfb> godot --path <proj>
   --resolution 960x704 --position 0,0` with user args
   `-- --input-gate-report <abs path>.json --input-gate-timeout-ms 20000`. Window at
   (0,0), 960×704, content scale identity -> screen coordinates == viewport ==
   board coordinates. The windowed run boots the REAL `run/main_scene`
   (`menu.tscn`) - the exact scene the headless contract does not grade.
4. **Drive by name, never by coordinates.** The game-side report publishes, every
   250 ms, all visible Button names + their screen centers alongside the counter
   block; the driver script picks targets by name (preference `*Next*` /
   `Confirm*` / `*Skip*`, then the known menu/creation buttons) and issues
   `xdotool mousemove <x> <y> click 1` (button 3 = right; `xdotool key Return`
   where the flow wants a key, e.g. the tutorial advance). No hardcoded screen
   coordinates anywhere - a layout change cannot rot the script. Owner-measured:
   this exact route walks menu -> creation -> tutorial -> `state=BATTLE` and clicks
   the board. `python-xlib` XTEST stays a documented fallback only, for the case
   where xdotool cannot be baked into the image.
5. Game side: new always-registered autoload `scripts/autoload/input_gate.gd`,
   registered in `project.godot [autoload]` **before `SceneManager`** (project.godot
   states SceneManager must remain the LAST entry - its `_teardown_battle_refs`
   references the other autoloads by name; inserting after it breaks compile
   ordering). Near-zero cost when the user args are absent. In gate mode it (a)
   refreshes the JSON report every 250 ms: `{state, scene, buttons: [{name, x, y}],
   debug_input_events, debug_click_events, debug_right_input_events,
   debug_undo_events, debug_gui_eater, debug_last_raw_event_pos,
   debug_last_click_grid, grid_pos, moves_left, current_round, player_world}`;
   (b) quits after the timeout (deterministic exit, rc=124 impossible by
   construction - the `test_game_manager_fsm` lesson).
6. Harness asserts on the report after process exit: the button walk reached
   `state=BATTLE` (real clicks through the real boot scene); the scripted
   left-click at `player_world + (0,-64)` advanced `debug_input_events` **and**
   `debug_click_events` **and** changed `grid_pos`; the scripted right-click at
   `player_world` advanced `debug_right_input_events` and `debug_undo_events` and
   restored `grid_pos`. A `raw > 0, handled == 0` with a non-empty `debug_gui_eater`
   at a board point reproduces the menu.tscn class of defect on the server - the
   gate goes red naming the eater.
7. **Skip semantics are loud:** if Xvfb/xdotool cannot run, the endpoint returns
   `skipped` with the reason; the pipeline records it in the gate report and
   `final/delivery_notes.md` as an **OPEN coverage gap** - a skip is never green.

**Honest boundary (recorded in `90_decisions.md` + delivery notes):** the X11 gate
covers the desktop window layer end-to-end (OS event -> window -> engine ->
handler -> state change). The **web export's browser->engine bridge cannot be
exercised server-side**; it is covered only by the shared engine-side code path, the
player confirmation already in hand (web + desktop both work after `42637b7`), and a
manual-playtest checklist entry. The touch path
on real hardware is likewise only partially covered (xdotool injects mouse events;
XI2 touch injection is out of scope). The fix itself is landed and player-confirmed;
what this round adds on top of it is **coverage**, so the next hole of this class
goes red on the server instead of living under a green suite.

**Decision tree (keyed on the differential triad; retained as the reading manual for
a future red - the branch that fired this round is marked resolved):**
- `raw == 0` (event never reaches the player node): if `under` names a Control, it is
  a pre-`_input` GUI/STOP eater -> in-repo `mouse_filter` fix + the landed
  SegmentHost guard + the Layer-1 pin; if `under` is empty, the event never entered
  the engine -> window/browser layer -> X11 gate is the server-side net;
  web-specific -> escalate to the round owner (may be export-preset / JS-shell
  side, outside this repo's reach).
- `raw > 0, handled == 0` - **the branch that fired this round (menu.tscn
  `SegmentHost`, resolved in `42637b7`)**: swallowed between receipt and handler ->
  STOP Control in the GUI phase -> `under` names it -> in-repo `mouse_filter` fix.
- `handled > 0`, no state change: coordinate/logic - `debug_last_raw_event_pos` vs
  `debug_last_click_grid` reveal a transform mismatch (e.g. every click resolving to
  one tile) -> fix the conversion in repo.
Whatever branch fires next, the resulting fix is pinned by the landed guards,
Layer 1 (differential) or the X11 gate (delivery layer) so it cannot regress
silently.

### 3.O Confirm the `InputProbeOverlay` is fully deleted (verify-only - landed in `1989be6`)

Commit `1989be6` already removed all three pieces of a673a42: the
`[ext_resource ... id="probe"]` line, the `[node name="InputProbeOverlay"]` stanza,
and the script file `scripts/ui/input_probe_overlay.gd`. A repo-wide search this
round finds **zero** remaining references outside this design doc - the deletion is
clean. **Do NOT re-add anything.** The remaining work is verification and absorption
only: (a) `scenes/ui/hud.tscn` must keep parsing - `[ext_resource]` entries must all
precede `[sub_resource]` entries (the ordering hazard the owner hit once); the
deletion only removed lines so the invariant holds, and the post-deletion `/compile`
runs prove it; (b) the raw/handled/under triad the overlay carried must be absorbed
by the Layer-1 permanent observables (`debug_*` counters + `InputCensus.top_eater`,
3.P0) - that is what makes "the diagnostic capability survives in-repo" true rather
than aspirational. Recorded in `90_decisions.md`: a URL-gated temporary is not how a
repo keeps diagnostics; permanent observables are.

### 3.T Touch-reachable undo control (the landed-touch leftover gap)

Phones have no right-click, so 「右键退回」 is unreachable on touch. Add an
**`UndoButton`** to the battle HUD as an additive delegate of the *same* undo entry
(the `battle_end_turn_attack_buttons.yaml` precedent: buttons delegate, keyboard
stays a shortcut, one source of truth):

- `scenes/ui/hud.tscn`: new `Button` node `UndoButton`, right action column directly
  below `AttackButton` - anchors right (`anchor_left/right = 1.0`), `offset_left =
  -140.0`, `offset_top = 176.0`, `offset_right = -8.0`, `offset_bottom = 212.0`
  (36 px tall like its siblings), `focus_mode = 0` (the 2026-08-25 discipline:
  every new clickable control sets it explicitly), `mouse_filter = 0` (STOP - it is
  an intentional button, unlike the floating bar), `text = "退回"`.
  `SkillDescLabel` shifts down to make room: `offset_top 176 -> 216` (height 180
  unchanged, bottom 396 - still inside the 704 viewport; its surface pin is
  `visible`/`text` only, no position pin, and `hud_desc_overlap` is computed live).
  Placement rationale: the right column already owns turn-scoped action buttons
  (EndTurn / Attack), is clear of the skill bar and the floating elements
  (MoveHintLabel / nameplates), and is thumb-reachable in landscape; a bottom slot
  would collide with the 880 px skill bar, and a slot near the player would collide
  with `MoveHintLabel`.
- `scripts/ui/hud.gd`: `_wire_battle_action_buttons` gains
  `UndoButton.pressed.connect(_on_undo_button_pressed)`; the handler runs the same
  4-condition gate and calls `player.handle_world_right_click(player_world_center)`
  (the shared, self-gated public entry - no synthetic right-click event, no forked
  undo logic; the locked-state rejection 「已出手,无法退回」 stays owned by that
  handler). Per-frame refresh mirrors EndTurn/Attack: `disabled = not
  (gate and player.undo_available)` - so the button also *teaches* that undo exists
  and greys out exactly when right-click would be refused. Extend the
  `pressed_connected` snapshot with `"UndoButton"` and the pairwise overlap
  computation with the new button (`hud_button_overlap`, plus a new
  `undo_desc_overlap` observable, both `== false`).
- `MoveHintLabel` copy is **not** changed: its three state texts are pinned by
  `move_target_affordance.yaml` and re-wording them is out of this round's lever;
  the button's 「退回」 verb matches the hint's promise, which is now backed by a
  visible control on every platform. Residual recorded honestly.
- `design/10_systems.md` §5.1 archive edit: the undo paragraph gains one sentence -
  the retreat is reachable by right-click **and** by the HUD 「退回」 button, same
  semantics, same lock rule.

### 3.B1 Defect B (visual) - nameplate to the portrait top + a ground marker

**Nameplate reposition.** `health_bar.gd::follow_character()` currently anchors at
the feet (`screen_pos += Vector2(-34, -32)`), parking the bar on the shins. Reposition
to the **portrait top**: the widget bottom sits `4 px` above `sprite_top`. Both Player
and Enemy publish `sprite_top` per-frame (world == screen under the identity canvas
transform). Compute `screen_pos = Vector2(char_x - 34, sprite_top - 4.0 - size.y)`,
then apply the existing viewport clamp. The nameplate now reads as belonging to the
portrait.

**Retain the `STRIP_BOTTOM + 2 = 94` clamp** (unchanged - SOTA §3.4: the clamp is the
UX-01b fix, pinned today by `portrait_visibility.yaml`; a rendered no-clamp variant
put top-row heads under the HUD strip). Document the **measured top-row landing** in
`30_presentation.md`: Central_Divine `sprite_top == 92`; the bar *wants* top
`92 - 4 - 24 = 64` (inside the strip) and is clamped to top `94`, spanning
**y 94–118** over the **hair/forehead band** `[92, 132]`; the face of a 128 px
portrait starts ≈ `sprite_top + 40 = 132`, so the clamped bar does **not** cover the
face. Mid-board units sit strictly above `sprite_top` (no clamp bite).

**Ground marker (NEW node).** `scripts/ui/tile_markers.gd` - a `Node2D` whose
`_process` calls `queue_redraw()` and whose `_draw()` iterates
`GameManager.get_player()` + `get_enemies_alive()`, painting a flattened low-alpha
ellipse with a thin gold outline at `GridManager.grid_to_world(unit.grid_pos)` per
living unit. Mount in `scenes/battlefield.tscn` as a `TileMarkers` node **after**
`Characters` (measured necessary: per-unit `_draw()` runs before the child Sprite2D
and was invisible for the top row, where clamped art covers the feet). This route is
**measured working for all six units including top-row Central_Divine and
West_Poison** (SOTA §3.3). Click-inert by construction (Node2D `_draw`, no GUI
involvement). Honest top-row visual fact to record: for top-row units the marker
draws on top of their own robe ("ellipse on the robe") - the truthful statement
"he stands here" while the art hangs elsewhere; low alpha + thin outline keeps it
presentable.

**Re-baseline (strengthen, never weaken).** Moving the nameplate re-baselines
`portrait_bar_pos`, `HUD.hpbar_strip_overlap` (stays false by the clamp - semantics
preserved), `HUD.hint_nameplate_overlap`, `HUD.nameplate_pairwise_overlap`; each
re-baselined with a documented justification in `design/`. After Defect A the bar is
IGNORE, so `VisibilityProbe` no longer counts it as a `covered` host - moving it is
strictly safer for `portrait_visibility.yaml`. The documented "hover gap 32 − 24 = 8"
pin in `final/health_bar_probe_notes.md` updates to the new `sprite_top − 4` anchor.

### 3.B2 Defect B (hit) - the portrait-rect priority rule

**Measured facts (already run; do not re-derive - SOTA §3):**
- §3.1 "grid -> drawn-portrait rect -> else click-move" - **BROKEN**:
  `click_move_undo_right` 10->6, `click_move_commit_lock` 9->1,
  `move_target_affordance` 18->11 (`click_move_to_tile` 10->10 only by accident).
  Cause: Central_Divine at (7,1) has clamped art at y∈[92,220], x∈[432,528] covering
  tile (7,2); three scenarios click-move from (7,5) straight up through (480,160) ->
  resolved as "attack Central_Divine" (out of range -> silent fail) instead of "walk
  there". An empty tile must not become unclickable because a tall unit stands
  behind it. **Rejected - do not re-propose.**
- §3.2 "move-range highlight arbitrates" - **regression-free but incomplete**:
  7/7 green on the acceptance net (`click_move_to_tile`, `click_move_undo_right`,
  `click_move_commit_lock`, `click_targeting_fixed`, `move_target_affordance`,
  `health_bar_numbers`, `portrait_visibility`), but a click on a reachable empty
  tile wins over the rect even when the rect is a *reachable* enemy's body.
- §3.3 ground marker - per-unit `_draw` invisible in the top row;
  after-`Characters` overlay visible for all six (used in 3.B1).

**Chosen rule (closes the §3.2 gap, keeps the 7 green).** Resolve a left-click at
world point `P` in `player.gd::handle_world_click` in this order:

1. `T = GridManager.world_to_grid(P)`. If a living enemy occupies `T`
   (`enemy.grid_pos == T`) -> `_try_attack_target(enemy)`; return. *(feet/own tile -
   existing behavior)*
2. Living enemies whose **live clamped portrait rect** contains `P` **AND** is in the
   player's current **attack reach** (basic range 1, or the selected skill's range,
   from the player's `grid_pos`) -> `_try_attack_target(nearest by grid_pos)`;
   return. ***NEW - closes the reachable-body gap.***
3. Else if `T` is a reachable empty tile in the move-range highlight ->
   `_try_move_to(T)`; return. *(highlight arbitrates - what kept §3.2 7/7 green)*
4. Else a living enemy whose portrait rect contains `P` -> `_try_attack_target(nearest)`;
   return. *(out-of-reach body -> the §3.2 residual behavior)*
5. Else if `T == grid_pos` -> silent no-op (own tile); else `_try_move_to(T)`.

**Why safe for the 7:** their click-moves happen from (7,5) on the player's first
turn; no enemy is in attack reach there (all five Greats ≥ 4 tiles away; basic range
1; no skill selected during the click-move legs). Step 2 therefore never intercepts
a click the 7 expect to be a move - behavior is identical to the measured-green §3.2
rule for those scenarios. Step 2 only changes clicks inside an **in-reach** enemy's
rect, which the 7 do not perform as moves (`click_targeting_fixed` wants an attack
there, which step 2 delivers). **Why it closes the gap:** an adjacent enemy's body
hangs over a reachable empty tile; under §3.2 the move won and the enemy was not
attacked; under this rule step 2 fires first -> attack -> damage + `acted == true` -
the player's actual complaint (「照着立绘攻击打不到人」).

**Priority rule recorded in `design/`** (`30_presentation.md` input section +
`90_decisions.md`): "a click inside a reachable enemy's drawn portrait rect attacks
that enemy; a click on a reachable empty tile that an out-of-reach enemy's rect
merely crosses still moves." The rejected §3.1 rule is recorded as out of scope with
its measured 10->6 / 9->1 / 18->11 numbers.

**Live clamped rect observable.** Add `portrait_ink_rect: Rect2` on `enemy.gd` (and
`player.gd` for symmetry), recomputed per-frame:
`Rect2(Vector2(sprite.global_position.x + sprite.offset.x - tex_size.x/2, sprite_top),
tex_size)`. The resolver reads `enemy.portrait_ink_rect.has_point(P)`. Tiebreak among
overlapping rects (96 px art > 64 px tile ⇒ 32 px overlap): nearest `grid_pos` to `P`.
The resolver is position-based inside `handle_world_click`, so the landed touch
branch and the mouse branch share it unchanged.

**`attack_reach_covers` predicate.** Pure static
`attack_reach_covers(player_grid, enemy_grid, selected_skill_index, skills) -> bool`
consulted by both the resolver and `_try_attack_target` (reach **only** - cooldown /
HP / acted gates stay inside `_try_attack_target`, so a gated click is a no-op exactly
as today). Pure -> headlessly unit-testable; play-test legs stay readable.

### 3.C Defect C - hover-preview trait descriptions

**Change (`scripts/segments/creation.gd`):** add `var trait_hover_index: int = -1`
(the isolated preview channel). In `_wire_mouse_widgets()` (L399, beside the existing
`pressed.connect(_on_trait_toggle_pressed.bind(i))` for each `TraitToggle{i}`,
i ∈ [0, min(_traits.size(), 13))), also connect `mouse_entered` ->
`_on_trait_toggle_hover_entered(i)` and `mouse_exited` ->
`_on_trait_toggle_hover_exited()`. In `_render()`:
- at the top, `if phase != "TRAITS": trait_hover_index = -1` (a hidden button does
  not reliably emit `mouse_exited` while the pointer sits on its old rect);
- `TraitDescLabel.text = _traits[idx].description` (L657-658) where
  `idx = trait_hover_index if trait_hover_index >= 0 else trait_index`.

`trait_hover_index` influences **only** the desc text: never writes `trait_index`,
never triggers `_toggle_trait`, never affects the focus `modulate` (those stay driven
solely by `trait_index`). Hover-entered sets it and calls `_render()`; hover-exited
resets to `-1` and re-renders (desc reverts to `trait_index`'s entry). Surface the
wiring as a `hover_connected` snapshot (per-toggle `mouse_entered`/`mouse_exited`
connection count > 0) beside the existing `pressed_connected`.

**Harness.** Drive the new scenario with the `hovers:` motion-only syntax (no button
token - a `left`/`right`/`middle` token after a hover entry is a hard failure; a
same-frame hover is pushed before any click, matching a real mouse). **Add `hovers:`
documentation to the `playtest/_common.yaml` header comment** (it currently documents
only `clicks:`; the header is the project's input-contract doc). Caveats to record:
the syntax exists only in the rebuilt sidecar - an "unknown key" error means a stale
image, not a bad scenario; and a single `clicks:` also fires `mouse_entered` via
motion-before-press, which is exactly why `hovers:` (motion-only) exists as a
separate, click-free path that can pin hover without toggling.

### 3.S Small fixes (folded into the docs card)

- **Heading.** `final/delivery_notes.md` L166:
  `# Delivery notes - jinyong-nodes(主线事件) (2026-08-29)` ->
  `# Delivery notes - jinyong-mainline(主线事件) (2026-08-27)`. That section was
  written by the jinyong-mainline round on 2026-08-27; `jinyong-nodes` is a different
  round and 08-29 is a future date. Surgical edit; the section's body is untouched.
- **One map hint.** The MAP segment prints the same operation hint twice: the
  `map.gd::_render()` TRAVEL panel trailing line (~L221,
  `\n\n左右/上下选择相邻去处，回车启程` suffix on the panel body) AND the footer
  `HintLabel`. **Keep the footer `HintLabel`, remove the panel trailing hint line**
  (leave `当前：%s`). Justification: the footer is the map's persistent operation
  hint, is already asserted (`map_node_event_mainline_return.yaml` pins
  `HintLabel.text == "左右/上下选择相邻去处，回车启程"`), and already carries the
  EVENT-hide logic (`_apply_hint_visibility`, `phase != "EVENT"` - an allow-list by
  negation that yields for any future phase); removing the panel line is the smallest
  blast radius, and one screen keeps one hint. Grep-verified no yaml pins the panel
  `BodyLabel` hint text (the `MapScreen` surface does not expose `BodyLabel.text`),
  so the removal is assertion-safe; the existing `HintLabel.text` assert stays green
  and unchanged. Record in `99_changelog.md` why the jinyong-mainline
  "byte-identical" unification is now changed to "one screen, one hint" (the
  duplicate was that round's own defect).
- **Full-width comma.** `map.gd` EVENT branch (~L210):
  `上下选择,回车定夺` (ASCII `,` U+002C) -> `上下选择，回车定夺` (full-width `，`
  U+FF0C), matching the TRAVEL hint. Grep-verified the only half-width punctuation in
  the MAP segment; no yaml pins the EVENT body verbatim -> assertion-safe. Scan the
  MAP segment for any other half-width punctuation while there.
- **`config/name`** is already 「华山论剑」 (commit 393a35e) - recorded in delivery
  notes only, no card.

## 4. Component list (paths relative to repo root)

| ID | File | Change |
|---|---|---|
| C-A1 | `scenes/ui/health_bar.tscn` | `NameLabel` add `mouse_filter = 2` (defensive; Bar already landed) |
| C-A2 | `scripts/characters/enemy.gd` | `debug_click_target_fires` counter in `_on_click_target_gui_input` (the 3.A measurement pin) |
| C-I1 | `scripts/characters/player.gd` | add `debug_right_input_events`, `debug_undo_events`, `debug_gui_eater` (+ census call on every press); existing counters untouched |
| C-I2 | `scripts/ui/input_census.gd` (NEW) | static `top_eater(root, pos)` - the overlay's measured walk, ported from git history (a673a42; the file was deleted in `1989be6`) |
| C-I3 | `scripts/autoload/input_gate.gd` (NEW) | gate-mode autoload: JSON report refresh (counters + visible-Button names/centers), auto-quit; registers BEFORE `SceneManager` (must stay last) |
| C-I4 | `project.godot` | `[autoload]` register `InputGate` (GameManager precedent) |
| C-I5 | sidecar `docker/godot/godot_harness.py` + sidecar Dockerfile | NEW `/x11_input_smoke` endpoint: copy-to-writable-path, double `--headless --import`, Xvfb + **xdotool baked into the Dockerfile** (image rebuild required), name-driven button walk. `python-xlib` XTEST fallback only |
| C-T1 | `scenes/ui/hud.tscn` | `UndoButton` node (right column, y176–212); `SkillDescLabel` offset_top 176->216 |
| C-T2 | `scripts/ui/hud.gd` | undo button wiring + per-frame disabled refresh + `pressed_connected["UndoButton"]` + `undo_desc_overlap` observable |
| C-B1 | `scripts/ui/tile_markers.gd` (NEW) | Node2D ground-marker overlay (ellipse + outline at `grid_to_world`, all living units) |
| C-B2 | `scenes/battlefield.tscn` | add `TileMarkers` node AFTER `Characters` |
| C-B3 | `scripts/characters/enemy.gd` | publish `portrait_ink_rect` (clamped ink rect) in `_process` |
| C-B4 | `scripts/characters/player.gd` | publish `portrait_ink_rect` (symmetry); implement the §3.B2 resolver in `handle_world_click` + pure `attack_reach_covers` |
| C-C1 | `scripts/segments/creation.gd` | `trait_hover_index`; wire `mouse_entered`/`mouse_exited` on `TraitToggle{0..12}`; `_render` prefers hover index for `TraitDescLabel` only |
| C-S1 | `final/delivery_notes.md` | heading fix (§3.S) + this round's new section |
| C-S2 | `scripts/segments/map.gd` | remove panel trailing hint line; EVENT comma -> full-width; MAP punctuation audit |
| C-O1 | `scenes/ui/hud.tscn` | VERIFY-ONLY: the overlay is already deleted (`1989be6`); confirm zero references + the scene still parses (ext_resources before sub_resources) |
| C-P1 | `playtest/input_click_differential.yaml` (NEW) | P0 Layer-1 differential pin (left / right / enemy-tile legs) |
| C-P2 | `playtest/undo_button_retreat.yaml` (NEW) | touch undo button: click -> retreat; geometry + wiring pins |
| C-P3 | `playtest/click_portrait_body_targets_enemy.yaml` (NEW) | Defect B body-click damages/acts |
| C-P4 | `playtest/health_bar_above_portrait.yaml` (NEW) | bar bottom above sprite_top incl. top-row face-band; ground-marker pins |
| C-P5 | `playtest/trait_hover_preview.yaml` (NEW) | Defect C hover preview, trait_index untouched |
| C-P6 | `playtest/_common.yaml` | surface whitelist additions; `hovers:` header doc; `scenario_order` append (C-P1..P5) |
| C-P7 | `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` two-place sync (C-P1..P5) + surface-contract pins; the two landed guards (`test_every_full_rect_host_is_click_through`, `test_the_contract_boot_scene_is_recorded_against_the_games_own`) stay green and untouched |
| C-U1 | `tests/test_click_priority.gd` (NEW) | pure `attack_reach_covers` + resolve-order truth table (headless) |
| C-U2 | `tests/test_trait_hover_preview.gd` (NEW) | hover index never mutates trait_index / never toggles (headless) |
| C-D1 | `design/` docs (landed by 5_design) | 3.A audit table + ClickTarget verdict, 3.P0 root-cause record (menu.tscn `SegmentHost`, the two dodge reasons, landed guards) + two-layer coverage + X11-gate pitfalls + honest OPEN web boundary, 3.O deletion verdict, 3.T undo button, 3.B1 landing/top-row, 3.B2 priority rule + rejected §3.1, 3.C hover, 3.S; `99_changelog.md` row |
| C-F1 | `final/delivery_notes.md` (round section) | what changed per item, new assertions, B priority rule, P0 coverage status (honest), manual web/touch playtest checklist |

## 5. Observable contract (exact surface names to whitelist in `playtest/_common.yaml`)

- `Player`: add `debug_right_input_events` (int), `debug_undo_events` (int),
  `debug_gui_eater` (String), `portrait_ink_rect` (Rect2) - beside the existing
  `debug_input_events` / `debug_last_raw_event_pos` / `debug_click_events` /
  `debug_last_click_grid` / `sprite_top` / `portrait_sprite_pos` /
  `portrait_tex_size`.
- `Enemy` (all five blocks): add `debug_click_target_fires` (int, Central_Divine's
  is the one the scenario reads) and `portrait_ink_rect` (Rect2).
- `HUD`: add `undo_desc_overlap` (bool); extend `pressed_connected` with
  `"UndoButton"`; new `UndoButton` node block (`visible`, `size`, `mouse_filter`,
  `disabled`, `focus_mode`, `text`).
- `CreationScreen`: add `trait_hover_index` (int) and `hover_connected` (Dictionary,
  per-toggle `mouse_entered`/`mouse_exited` counts > 0).
- `HealthBar`: add `bar_top` (float) and `bar_bottom` (float), derived in
  `follow_character` from the live `global_position.y` + `size.y`, so the
  "bar bottom above sprite_top" pin reads live geometry; `bar_anchors_sprite_top`
  (bool) true when the unclamped desired bottom == `sprite_top − 4`.
- `Battlefield` (or a `TileMarkers` surface): `tile_marker_count` (int, living units
  with a drawn marker) and `tile_marker_visible` (bool).

Numeric pins are relative/differential wherever possible (counters `: changed`;
`bar_bottom < sprite_top` mid-board, `bar_bottom <= sprite_top + 40` top-row;
`trait_hover_index == 5`, `trait_index == 0`). The map hint string stays a **text
contract** (one absolute), per the jinyong-nodes precedent.

## 6. Playtest scenario skeletons (architect-owned; PM finalizes frames/thresholds)

All direct-boot where the screen allows; `name == basename`; single-integer `at:`;
a comparison operator (or `changed`/`unchanged`) on every dotted assert line; frame
cap 3000 (last ≤ 2999). The two-place sync (`_common.yaml scenario_order` +
`tests/test_playtest_contract_smoke.py ROUND_SCENARIOS`) appends all five in the
same order. The landed `click_move_undo_feet.yaml` is untouched.

**C-P1 `input_click_differential.yaml`** - `scene: res://scenes/main.tscn`, tutorial
boot preamble (7× `ui_accept` + 3× `tutorial_next`, mirroring
`click_move_undo_feet`). Legs: (a) `clicks: Player +0,-64` -> assert
`Player.debug_input_events: changed`, `Player.debug_click_events: changed`,
`Player.debug_gui_eater: gui_eater == ""`; (b) `clicks: Player +0,0 right` ->
`debug_right_input_events: changed`, `debug_undo_events: changed`,
`debug_gui_eater: gui_eater == ""`, and the retreat observables
(`grid_pos` back to start, `moves_left` refunded); (c) `clicks:
Central_Divine_ClickTarget` -> `Player.debug_click_events: changed` AND
`Central_Divine.debug_click_target_fires: debug_click_target_fires == 0` (the
ClickTarget dead-for-routing measurement pin, 3.A).

**C-P2 `undo_button_retreat.yaml`** - `scene: res://scenes/main.tscn`, tutorial boot.
Legs: (a) wiring/geometry at turn start: `UndoButton.visible == true`,
`size.x > 0 and size.y > 0`, `mouse_filter == 0`, `focus_mode == 0`,
`disabled == true` (nothing to undo yet),
`HUD.pressed_connected: pressed_connected["UndoButton"] == true`,
`HUD.hud_button_overlap: hud_button_overlap == false`,
`HUD.undo_desc_overlap: undo_desc_overlap == false`; (b) `clicks: Player +0,-64` ->
`UndoButton.disabled == false` (`undo_available` mirrors into the button); (c)
`clicks: UndoButton` -> assert the retreat: `grid_pos` back to (7,5),
`moves_left == 4`, `moved == false`, `undo_available == false`,
`Player.debug_undo_events: changed` (the button drives the same shared entry);
(d) after the retreat `UndoButton.disabled == true` again.

**C-P3 `click_portrait_body_targets_enemy.yaml`** - `scene: res://scenes/main.tscn`.
Move the player adjacent to a Great (e.g. to (7,4) by `clicks: Player +0,-64`), then
click the enemy's **portrait body center** - `Enemy +0,-64` for an unclamped mid-board
enemy, computed from the live `portrait_ink_rect` (the drawn rect, NOT the feet
tile). Assert `enemy.health: changed` (differential vs a captured before-value, or
`< before`) and `Player.acted == true`. The clicked point is a reachable empty tile
(the body hangs over it) - under the old code this moved; under the new rule step 2
attacks. Include a negative control: a body click on an **out-of-reach** enemy
(e.g. North_Beggar) -> `Player.debug_last_click_grid` reflects the point but
`enemy.health: unchanged`, `Player.acted == false`, `Player.grid_pos: unchanged`
(step 4 selects/no-op, no silent move).

**C-P4 `health_bar_above_portrait.yaml`** - `scene: res://scenes/main.tscn`. For a
mid-board unit (Player at (7,5)): `HealthBar.bar_bottom: bar_bottom < sprite_top`
(bar strictly above the portrait). For **Central_Divine** (top-row, clamped):
`HealthBar.bar_top: bar_top == 94` (clamped) AND
`HealthBar.bar_bottom: bar_bottom <= sprite_top + 40` (the 26 px intrusion stays in
the hair/forehead band, face untouched). Also
`Battlefield.tile_marker_count: tile_marker_count == 6` and
`tile_marker_visible == true` (all living units, including the top row).

**C-P5 `trait_hover_preview.yaml`** - `scene: res://scenes/segments/creation.tscn`,
walk to TRAVEL-less TRAITS phase (button clicks per the creation scenarios). Then
`hovers: TraitToggle5` -> assert `CreationScreen.trait_hover_index == 5`,
`TraitDescLabel.text` contains trait-5's keyword, `CreationScreen.trait_index == 0`
(unchanged), `CreationScreen.hover_connected: hover_connected["TraitToggle5"] == true`.
Then `hovers: TraitNextButton` (pointer leaves the toggle) ->
`CreationScreen.trait_hover_index: trait_hover_index == -1`, `TraitDescLabel.text`
reverts to trait-`trait_index`'s text, `trait_index` still 0, no toggle fired
(`CreationScreen.trait_ids: unchanged`). If the sidecar rejects `hovers:` as
"unknown key", that is a stale image - escalate; do not convert to a `clicks:`
(a click would toggle).

**X11 gate acceptance (not a YAML - the sidecar endpoint's own contract, C-I5):**
setup = copy to a writable path, `--headless --import` twice, Xvfb 960×704×24,
windowed run of the real `menu.tscn` boot; script = [name-driven button walk
menu -> creation -> tutorial -> `state=BATTLE` (driver picks `*Next*` / `Confirm*` /
`*Skip*` from the live Button report, never coordinates), motion to
`player_world + (0,-64)` + click 1, wait, motion to `player_world` + click 3];
report must show the walk reached BATTLE, `debug_input_events` +1,
`debug_click_events` +1, `grid_pos` changed by the left click, then
`debug_right_input_events` +1, `debug_undo_events` +1 and `grid_pos` restored by the
right click, and `debug_gui_eater == ""` at both board points. A skipped run (no
Xvfb/xdotool) is recorded as an OPEN coverage gap, never green. The sidecar's own
unit tests cover the endpoint (the `hovers:` precedent: harness changes ship with
sidecar tests + image rebuild).

## 7. GDScript unit pins (headless `run() -> bool`, registered in `unit_test_runner.gd`)

- `tests/test_click_priority.gd` - truth table for the §3.B2 resolver (pure static
  over grid/reach/rects): own-tile occupied -> attack; reachable-empty-highlighted
  with an out-of-reach rect crossing -> move; reachable-empty-highlighted with an
  in-reach rect containing the point -> attack (the gap-closing case); out-of-reach
  body, non-highlighted -> select; own empty non-highlighted -> no-op. Plus
  `attack_reach_covers` for basic range 1 and a representative skill range.
- `tests/test_trait_hover_preview.gd` - `trait_hover_index` previews the desc, never
  writes `trait_index`, never calls `_toggle_trait` (trait_ids unchanged), `modulate`
  driven only by `trait_index`; `phase != "TRAITS"` resets hover to -1.

## 8. Edge cases -> how this design answers each

- **P0: the headless harness cannot produce the GUI-phase failure.** Correct - and
  the class is now pinned three independent ways: the landed static guard (every
  `SegmentHost` in every `.tscn` declares `mouse_filter = 2`), Layer 1 (per-press
  differential asserts: `raw` vs `handled` vs `debug_gui_eater`), and Layer 2 (the
  windowed X11 run through the REAL `menu.tscn` boot). The web bridge is honestly
  out of server reach and stays covered by the player confirmation + a manual
  checklist. The fix is landed; coverage is this round's deliverable.
- **P0: the X11 gate's four measured pitfalls.** Read-only repo mount (copy to a
  writable `/tmp` path first), the double `--headless --import`, autoload ordering
  (`InputGate` before `SceneManager`), and xdotool living in the Dockerfile rather
  than the container's writable layer. All four are in 3.P0 Layer 2 verbatim;
  re-hitting any of them is a process failure, not bad luck.
- **P0: counters must not change meaning.** `debug_input_events` /
  `debug_click_events` keep their documented semantics (header comment +
  `click_move_to_tile.yaml` f45 pin); right-path coverage is **new** vars, and the
  census runs per-press, not per-frame.
- **P0: debug_gui_eater can be non-empty at authored controls.** At an enemy tile
  the `ClickTarget` is the predicted eater, yet the click works (the `enemy._input`
  relay pre-handles before the GUI phase). C-P1 therefore asserts emptiness only at
  Control-free points (feet/empty tile) and pairs the enemy-tile leg with
  `debug_click_events` + the `debug_click_target_fires == 0` pin.
- **Overlay removal.** Already landed (`1989be6`); ext_resources still precede
  sub_resources in `hud.tscn` (removal never reorders lines). The one remaining
  hazard is re-adding the overlay instead of relying on the Layer-1 observables -
  3.O forbids it explicitly.
- **Touch undo moves HUD geometry.** UndoButton sits in the existing right action
  column (clear of the skill bar, MoveHintLabel, nameplates); `SkillDescLabel` shifts
  40 px down (no position pin exists; `hud_desc_overlap` is computed live); new
  pairwise overlaps are asserted false in C-P2. `focus_mode = 0` and `mouse_filter
  = 0` are explicit per the two 2026-08-25 disciplines.
- **A: filter re-assert survives re-entry/headless.** Landed code already follows
  the guarded pattern; NameLabel gains an explicit tscn value; ClickTarget measured,
  node kept (harness anchor).
- **A: ClickTarget verify-by-measurement.** `debug_click_target_fires` + the C-P1
  leg = the measurement, pinned (not a comment); verdict recorded in
  `30_presentation.md`; node kept for `click_move_commit_lock.yaml`.
- **B: `bar_bottom < sprite_top` is impossible for top-row under the retained
  clamp.** Central_Divine `sprite_top == 92`; bar clamped to 94–118. The strict
  assertion holds for mid-board; for the top row the design pins the **documented
  landing** (`bar_top == 94` AND `bar_bottom <= sprite_top + 40`, face untouched).
  The brief's "including top-row Central_Divine" is satisfied by that top-row pin.
- **B: hit-test uses the live clamped rect, not the naive feet−128.**
  `portrait_ink_rect` is recomputed per-frame from the clamped offset +
  `sprite_top`, so top-row and edge units get the correct rect. The clamp is static,
  shared (player + enemy) and **unchanged**.
- **B: 96 vs 64 ⇒ overlap + every portrait covers the tile above; the rule must be
  visible and never make a reachable empty tile unclickable.** Step 2 only fires for
  in-reach enemies (the §3.1 regression was out-of-reach Central_Divine's rect over
  (7,2), which step 2 skips). The ground marker (3.B1) makes "where to click"
  visible. The 7-scenario acceptance net is named in 3.B2 and must stay green.
- **B: body-center test must pin the reachable case (the actual complaint).** This
  design closes the §3.2 gap, so C-P3 clicks a **reachable** enemy's body, with an
  out-of-reach negative control.
- **B: ground marker click-inert AND on top where it matters.** Node2D `_draw` (no
  GUI); mounted after `Characters` (measured visible for all six incl. top row).
- **B: moving the nameplate re-baselines yamls.** `portrait_bar_pos`,
  `hpbar_strip_overlap` (false by the retained clamp), `hint_nameplate_overlap`,
  `nameplate_pairwise_overlap` re-baselined with justification; the bar is IGNORE so
  it no longer counts as a `covered` host for `portrait_visibility`.
- **C: hover must not leak into the keyboard path.** `trait_hover_index` is
  display-only, reset to -1 on `mouse_exited` and whenever `phase != "TRAITS"`;
  `modulate`/`pressed` driven solely by `trait_index`. Assertable via the rebuilt
  `hovers:` syntax (C-P5).
- **Small fixes:** remove panel line (footer kept, already asserted, EVENT-hide
  intact); EVENT comma -> full-width (grep-verified no yaml pins it); heading
  surgical edit at L166.

## 9. Safety / rollback

No irreversible operations. All edits are additive or surgical single-line /
scene-stanza changes; `.tscn` and `.gd` are text and diff-revertible. The clamp, art
size, TILE_SIZE, BOARD_TOP_MARGIN_Y, and STRIP_BOTTOM+2 are **untouched** (frozen
constants). The new `TileMarkers` node, `InputCensus`, `InputGate` autoload,
`UndoButton`, and the five new scenarios are additive (drop-in). The overlay
deletion is already landed (`1989be6`, revertible from git); C-O1 is verify-only.
`click_move_undo_right.yaml` and
`click_move_undo_feet.yaml` are **not modified**. The sidecar `/x11_input_smoke`
endpoint is additive to the sidecar (image rebuild, same channel as `hovers:`); if
it cannot run, it reports `skipped` loudly - the existing gates are unaffected. If
the §3.B2 rule reddens a scenario in the 7-scenario net, **do not weaken the
scenario** - escalate to design (the rule's acceptance net is those 7; a red there
means the in-reach gate intercepted a move the scenario expected, resolved by
narrowing the gate, not deleting an assertion). The
`tests/fixtures/playplay_assert_superset.json` "only-add-never-remove" machine pin
still guards the previously-edited yamls; the five new scenarios are appended, not
inserted into protected files.

## 10. Task decomposition (for PM) - priority order per the re-scope

| ID | Task | Files | Depends on |
|---|---|---|---|
| T1 | P0 Layer 1: right/undo counters + `debug_gui_eater` + `InputCensus` port | C-I1, C-I2 | - |
| T2 | P0: ClickTarget measurement pin + NameLabel filter + audit table (design record) | C-A1, C-A2, C-D1(partial) | T1 |
| T3 | P0: `InputGate` autoload + report writer + registration (BEFORE `SceneManager`) | C-I3, C-I4 | - |
| T4 | P0: sidecar `/x11_input_smoke` endpoint - copy-to-writable-path, double `--import`, Xvfb + xdotool (Dockerfile), name-driven driver + sidecar tests + image rebuild | C-I5 (sidecar) | T3 |
| T5 | P0: `input_click_differential.yaml` scenario + surface/order sync | C-P1, C-P6(partial), C-P7(partial) | T1, T2 |
| T6 | Touch undo: `UndoButton` + wiring + geometry observables + scenario | C-T1, C-T2, C-P2 | - |
| T7 | Defect B visual: nameplate -> sprite_top (retain clamp) + top-row landing doc | C-B1(partial), C-D1(partial) | - |
| T8 | Defect B visual: ground marker `TileMarkers` (after Characters) | C-B1, C-B2 | - |
| T9 | Defect B hit: `portrait_ink_rect` observables (enemy + player) | C-B3, C-B4(partial) | - |
| T10 | Defect B hit: §3.B2 resolver + `attack_reach_covers` | C-B4, C-U1 | T9 |
| T11 | Defect C: `trait_hover_index` + hover wiring + `_render` preference | C-C1, C-U2 | - |
| T12 | Small fixes: heading, one map hint, full-width comma | C-S1, C-S2 | - |
| T13 | Remaining scenarios (C-P3..P5) + full surface whitelist + `hovers:` header doc + `scenario_order` | C-P3..P6 | T7–T11 |
| T14 | pytest two-place sync + surface-contract pins | C-P7 | T13 |
| T15 | Unit pins (click priority, hover preview) registered in the suite | C-U1, C-U2 | T10, T11 |
| T16 | Record the resolved root cause + the two dodge reasons + the landed-guard inventory in `design/` (evidence already in hand, §1 table; **no characterization cards**) | C-D1 (partial) | T1 |
| T17 | Verify the `InputProbeOverlay` deletion is clean (zero references; `hud.tscn` parses; the triad is absorbed by Layer 1) | C-O1 | T1 |
| T18 | Design-archive declarations (5_design lands after verification) | C-D1 | T1–T17 |
| T19 | `final/delivery_notes.md` round section: per-item changes, new assertions, B priority rule, P0 coverage status (honest OPEN boundary), manual web/touch checklist | C-F1 | T1–T18 |

## 11. Technology stack

Godot 4 built-ins only (no external packages in the repo):
`Control.mouse_filter`, the `_input` -> GUI -> `_unhandled_input` order,
`Button.mouse_entered`/`mouse_exited`, `Node2D._draw`, `Rect2.has_point`,
`GridManager.world_to_grid` / `grid_to_world` / `clamp_sprite_offset`,
`OS.get_cmdline_user_args()`. GDScript for logic; `.tscn` is hand-editable text.
Sidecar-side tooling (not repo dependencies): Xvfb (already present) + **xdotool
baked into the sidecar Dockerfile** (the owner's measured driver route; an
`apt-get install` at run time lives in the writable layer and is lost on rebuild),
with `python-xlib` XTEST as fallback only. Tests: headless GDScript `extends SceneTree` unit pins +
the `playtest/` YAML contract + `tests/test_playtest_contract_smoke.py` pytest. All
gates run through the `godot-builder` sidecar (`/compile`, `/playtest`, `/vision`,
`/script`, and the NEW `/x11_input_smoke`).

## 12. Linter manifest

`linter_manifest.json` keeps `.py: ruff`, `.md/.json/.yaml: basic` (this round adds
`.gd`/`.tscn` files - excluded from the manifest by design, the `gdscript_check` gate
parses them per-file via `godot --check-only`, host-controlled; the sidecar
`godot_harness.py` changes are `.py` -> `ruff`). See the separate
`linter_manifest.json`.
