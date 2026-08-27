# Technical Architecture — Jinyong Tactics: Mouse & Info Interaction Defect Fixes

Round: interaction-defects (2026-08-27). This is a **per-run** design (`design/README.md`):
it describes the change program for this round. The durable `design/` archive is edited
only by `5_design` after final verification passes — the **Design changes** section below is
what `5_design` will land surgically. Everything is in English; in-game UI copy stays Chinese.

## 1. Overview

Fix three **measured** player-reported interaction defects (A: floating health bar swallows
right-click undo on a unit's own tile; B: portrait is drawn a full tile above its grid cell
and clicking the drawn portrait does not target the unit; C: innate-trait descriptions show
only on click, not on hover) plus three small polish fixes (delivery-notes heading, duplicate
map hint, half-width comma). No new content, no plot/event/map data, no engine/asset-pipeline
change. Godot 4 built-ins only.

The three defects share one rendering fact the SOTA (step1_sota.md) measured: a 96×128
portrait on a 64 px tile, anchored at the feet, hangs ~one tile above its grid cell; the top
row is inverted by `GridManager.clamp_sprite_offset` (art pushed DOWN over its own tile).
All three Defect-B candidate arbitration rules were already implemented and measured on
instrumented copies (§3.B2). This design picks one, justifies it, and pins it.

## 2. Architecture / data flow

```
Left-click (board space)
  -> InputEventMouseButton -> Godot input pipeline
     enemy.gd::_input  (runs BEFORE GUI)  -- own-tile relay: if click_grid == grid_pos,
                                            set_input_as_handled + player.handle_world_click
     GUI phase          -- STOP Controls under the pointer swallow the event here
                            (Defect A: Bar was STOP -> ate feet right-click)
     player.gd::_unhandled_input (mouse branch) -> _handle_click_targeting
                                            -> handle_world_click(world_pos)
                                                  [Defect B hit resolver lives here]

Right-click (board space)
  -> ... -> player.gd::_unhandled_input (mouse branch) -> handle_world_right_click
       undo if undo_available, else reject ("已出手,无法退回")

Hover (creation screen)
  -> Button.mouse_entered / mouse_exited -> trait_hover_index -> _render() -> TraitDescLabel

Per-frame draw order (scenes/battlefield.tscn, siblings, no z_index):
  SummitBackdrop -> Grid -> GridLines -> RangeHighlight -> MoveRangeHighlight
  -> Characters (unit art paints OVER highlights) -> [NEW] TileMarkers (paints OVER art,
     so the ground marker is visible even for top-row units whose clamped art covers their feet)
```

## 3. Design changes (declared for the `design/` archive)

`5_design` lands these after verification. Each is doc-first: the rationale is written into
`design/` (`10_systems.md` / `30_presentation.md` / `90_decisions.md` / `40_ux_backlog.md`)
and one row appended to `99_changelog.md`. Chinese UI strings are quoted verbatim.

### 3.A Defect A — the floating health bar's STOP-filter hole

**Change (code):** set `Bar.mouse_filter = 2` (MOUSE_FILTER_IGNORE) in
`scenes/ui/health_bar.tscn`, and re-assert it every frame in `scripts/ui/health_bar.gd`
next to the two existing per-update assertions (`hp_label.mouse_filter = 2` ~L352,
`cap.mouse_filter = 2` ~L368) AND in the per-frame `follow_character()` so it cannot
regress between updates. Comment (English, matching the brief): *"no descendant of a
floating HUD control may be STOP — a click-eating child defeats the click-through root."*
This fix is already **measured effective** on the requester's instrumented copy (the same
feet-tile right-click changed from "_unhandled_input reached 0 times, no retreat" to
"reached 1 time, retreat executed, grid back to (7,5)"; the click-eating Control list became
empty) — implement directly, do not re-verify.

**Audit (measured, not by comment):**
- HealthBar subtree: root `HealthBar` (mouse_filter=2 ✓), `Bar` (now 2 ✓), `EmptyCap` (2 ✓),
  `HpLabel` (2 ✓), `NameLabel` (Label — Godot default IGNORE; **set `mouse_filter = 2`
  explicitly in the tscn for defensiveness and consistency with its siblings**, then audit
  confirms). Record each node's measured filter in `design/30_presentation.md`.
- Enemy `ClickTarget` (`scenes/enemy.tscn`, mouse_filter=0 STOP, child of the Enemy Node2D):
  the brief demands a **measurement** of whether `gui_input` ever fires. Instrument a debug
  counter on `ClickTarget.gui_input` fires vs `Player.debug_click_events` while clicking the
  ClickTarget rect, run it through the harness, and **record the measured verdict in
  `design/30_presentation.md`** (input section) and a probe note in `final/`. The node
  **must survive** — it is a harness click anchor used by `click_move_commit_lock.yaml`
  (`<EnemyNodeName>_ClickTarget`, renamed per-enemy in `enemy.gd::_ready`). Conclusion shape:
  "ClickTarget.gui_input measured N fires vs M debug_click_events → [dead: the Node2D
  ancestor means the GUI picker does not route to it, and `enemy._input` pre-handles own-tile
  left-clicks in `_input` before the GUI phase]; node kept as harness anchor; mouse_filter
  decision = [recorded]." The real click path stays `enemy.gd::_input` (the relay) for
  own-tile and `player.handle_world_click` for everything else.

**Play-test pin (NEW):** `click_move_undo_right_feet.yaml` — right-click exactly at
`Player +0,0` (the feet tile) **while a move is undoable** (moved, not yet acted) and assert
the retreat succeeds (grid back to turn-start, `moves_left` refunded, `moved == false`,
`undo_available == false`). A "before" leg must prove `undo_available == true` so the bug is
actually exercised (the existing `click_move_undo_right.yaml` clicks `Player +64,0` and stays
**byte-untouched** — it stayed green under the bug because +64,0 is outside the Bar's dead
zone; the new scenario clicks the feet, inside the dead zone).

### 3.B1 Defect B (visual) — nameplate to the portrait top + a ground marker

**Nameplate reposition.** `health_bar.gd::follow_character()` currently anchors at the feet
(`screen_pos += Vector2(-34, -32)`). Reposition to the **portrait top**: the widget bottom
sits `4 px` above `sprite_top`. Both Player and Enemy publish `sprite_top` (world/canvas
space; the canvas transform is identity in the battlefield). Compute the screen-space top
edge and set `screen_pos = Vector2(char_x_screen - 34, sprite_top_screen - 4.0 - size.y)`,
then apply the existing x/y viewport clamp. This moves the nameplate OFF the legs and onto
the head, so "the bar reads as belonging to the portrait".

**Retain the `STRIP_BOTTOM + 2 = 94` clamp** (do not change it — see 3.B2 / SOTA §3.4: the
clamp is the fix for UX-01b, pinned today by `portrait_visibility.yaml`; a rendered no-clamp
variant put top-row heads under the HUD strip). Document the **measured top-row landing** in
`design/30_presentation.md`: for Central_Divine `sprite_top == 92`; the bar *wants* top
`92 - 4 - 24 = 64` (inside the strip) and is clamped to `top == 94`, so it spans **y 94–118**
over the **hair/forehead band** `[92, 132]` of the 128-px portrait; the **face starts
≈ `sprite_top + 40 = 132`**, so the clamped bar does **not** cover the face. For mid-board
units the bar sits strictly above `sprite_top` (no clamp bite).

**Ground marker (NEW node).** Add `scripts/ui/tile_markers.gd` — a `Node2D` whose `_process`
calls `queue_redraw()` and whose `_draw()` iterates `GameManager.get_player()` +
`get_enemies_alive()`, painting a flattened low-alpha ellipse with a thin gold outline at
`GridManager.grid_to_world(unit.grid_pos)` for each living unit. Mount it in
`scenes/battlefield.tscn` as a `TileMarkers` node placed **after** `Characters` (so it draws
ON TOP of unit art — measured necessary: a per-unit `_draw()` runs BEFORE the child Sprite2D
and was invisible for the top row, where clamped art covers the feet). This route is
**measured working for all six units including top-row Central_Divine and West_Poison**
(SOTA §3.3). It is **click-inert by construction** (Node2D `_draw` has no GUI involvement,
cannot swallow clicks). Honest top-row visual fact to record in `design/30_presentation.md`:
for top-row units the marker draws on top of their own robe ("ellipse on the robe") — the
truthful statement "he stands here" while the art hangs elsewhere; low alpha + thin outline
keeps it presentable.

**Re-baseline (strengthen, never weaken).** Moving the nameplate up re-baselines
position-sensitive observables (`portrait_bar_pos`, `HUD.hpbar_strip_overlap`,
`HUD.hint_nameplate_overlap`, `HUD.nameplate_pairwise_overlap`). Re-baseline each with a
documented justification in `design/`. The strip clamp still guarantees no bar enters
`0..92`, so `hpbar_strip_overlap` semantics are preserved. Note: after Defect A the bar is
`mouse_filter=IGNORE`, so `VisibilityProbe` no longer counts it as a `covered` host — moving
it is strictly safer for `portrait_visibility.yaml` (the bar no longer covers portrait ink
for the probe's purposes). The documented "hover gap 32 − 24 = 8" pin in
`final/health_bar_probe_notes.md` updates to the new `sprite_top − 4` anchor.

### 3.B2 Defect B (hit) — the portrait-rect hit priority rule

**Measured facts (already run; do not re-derive).** SOTA §3:
- §3.1 "grid → drawn-portrait rect → else click-move" — **BROKEN**: `click_move_undo_right`
  10→6, `click_move_commit_lock` 9→1, `move_target_affordance` 18→11. Cause: Central_Divine
  at (7,1) has clamped art at y∈[92,220], x∈[432,528], covering tile (7,2); the three
  scenarios click-move from (7,5) straight up through (480,160) → resolved as "attack
  Central_Divine" (out of range → silent fail) instead of "walk there".
- §3.2 "move-range highlight arbitrates" — **7/7 green** (click_move_to_tile,
  click_move_undo_right, click_move_commit_lock, click_targeting_fixed,
  move_target_affordance, health_bar_numbers, portrait_visibility) BUT **incomplete**: a
  click on a reachable empty tile wins over the rect even when the rect is a *reachable*
  enemy's body, so attacking the enemy you can actually reach by clicking its portrait still
  fails.
- §3.3 ground marker — rendered; per-unit `_draw` invisible in the top row; the
  after-`Characters` overlay is visible for all six (used in 3.B1).

**Chosen rule (closes the §3.2 gap, keeps the 7 green).** Resolve a left-click at world point
`P` in `player.gd::handle_world_click` in this order:

1. `T = GridManager.world_to_grid(P)`. If a living enemy occupies `T` (`enemy.grid_pos == T`)
   → `_try_attack_target(enemy)`; return. *(the feet/own tile — existing behavior)*
2. Find living enemies whose **live clamped portrait rect** contains `P` **AND** that enemy
   is in the player's current **attack reach** (basic range 1, or the selected skill's
   range/shape, from the player's `grid_pos`). If any → `_try_attack_target(nearest by
   grid_pos)`; return. ***NEW — closes the reachable-body gap.***
3. Else if `T` is a reachable empty tile in the move-range highlight → `_try_move_to(T)`;
   return. *(highlight arbitrates — this is what kept §3.2 7/7 green)*
4. Else find a living enemy whose portrait rect contains `P` → `_try_attack_target(nearest)`;
   return. *(out-of-reach body → select/no-op, the §3.2 residual behavior)*
5. Else if `T == grid_pos` → silent no-op (own tile); else `_try_move_to(T)`. *(click-move)*

**Why this is safe for the 7.** The 7 scenarios' click-moves happen from (7,5) on the
player's first turn; **no enemy is in attack reach** there (all five Greats are ≥4 tiles
away; basic range 1, and no skill is selected during the click-move legs, so even range-3
skills do not reach). Therefore step 2 never intercepts a click the 7 expect to be a move —
behavior is identical to the measured-7/7-green §3.2 rule for those scenarios. Step 2 only
changes behavior for clicks inside an **in-reach** enemy's rect, which the 7 do not perform
as moves (`click_targeting_fixed` wants an attack there, which step 2 delivers).

**Why it closes the gap.** An adjacent/reachable enemy's portrait body hangs over a
reachable empty tile; under §3.2 step 3 (move) won and the enemy was not attacked. Under the
chosen rule, step 2 fires first (rect + in-reach) → attack → damage + `acted=true`. This is
the user's actual complaint ("照着立绘攻击打不到人").

**Priority rule recorded in `design/`** (`30_presentation.md` input section +
`90_decisions.md`): "a click inside a reachable enemy's drawn portrait rect attacks that
enemy; a click on a reachable empty tile that an out-of-reach enemy's rect merely crosses
still moves." The rejected §3.1 rule ("portrait rect before click-move") is recorded as
**out of scope** in `90_decisions.md` with the measured 10→6 / 9→1 / 18→11 numbers.

**Live clamped rect observable.** The repo publishes `portrait_sprite_pos`
(=Sprite2D.global_position = the feet/node position — **not** the ink center, since
`clamp_sprite_offset` moves the texture via `sprite.offset`, not the node) and `sprite_top`
(the clamped ink TOP edge). To get the clamped ink rect cleanly, add a new observable
`portrait_ink_rect: Rect2` on `enemy.gd` (and `player.gd` for symmetry), computed in
`_process` as `Rect2(Vector2(_sprite.global_position.x + _sprite.offset.x - tex_size.x/2,
sprite_top), tex_size)` — top-left = feet.x + clamped offset.x − half-width, top = sprite_top.
The hit resolver reads `enemy.portrait_ink_rect.has_point(P)`. Tiebreak among overlapping
rects (96 wide > 64 tile ⇒ 32 px overlap): nearest `grid_pos` (feet) to `P`.

**`attack_reach_covers` predicate.** Extract a pure static
`attack_reach_covers(player_grid, enemy_grid, selected_skill_index, skills) -> bool` that
both `_try_attack_target` and the click resolver consult (basic range 1 if no skill selected,
else the selected skill's range/shape). Pure → unit-testable headlessly; the play-test legs
stay readable. It checks **reach only**, not cooldown/HP/acted (those gates still run inside
`_try_attack_target`, so a gated click is a no-op exactly as today).

### 3.C Defect C — hover-preview trait descriptions

**Change (`scripts/segments/creation.gd`):** add `var trait_hover_index: int = -1` (the
isolated preview channel). In `_wire_mouse_widgets()`, beside the existing
`pressed.connect(_on_trait_toggle_pressed.bind(i))` for each `TraitToggle{i}`, also connect
`mouse_entered` → `_on_trait_toggle_hover_entered(i)` and `mouse_exited` →
`_on_trait_toggle_hover_exited()`. In `_render()`:
- at the top, `if phase != "TRAITS": trait_hover_index = -1` (a hidden button does not
  reliably emit `mouse_exited` while the pointer sits on its old rect);
- `TraitDescLabel.text = _traits[idx].description` where
  `idx = trait_hover_index if trait_hover_index >= 0 else trait_index`.

`trait_hover_index` influences **only** the desc text. It must **never** write `trait_index`,
never trigger `_toggle_trait`, and never affect the focus `modulate` (those stay driven
solely by `trait_index`). `_on_trait_toggle_hover_entered(i)` sets `trait_hover_index = i`
and calls `_render()`; `_on_trait_toggle_hover_exited()` sets it to `-1` and calls
`_render()` (desc reverts to `trait_index`'s entry). Surface the wiring as a
`hover_connected` snapshot (per-toggle `mouse_entered`/`mouse_exited` connection count > 0)
beside the existing `pressed_connected`.

**Harness.** Drive the new scenario with the `hovers:` motion-only syntax (no button token —
a `left`/`right`/`middle` token after a hover entry is a hard failure; a same-frame hover is
pushed before any click, matching a real mouse). **Add `hovers:` documentation to the
`playtest/_common.yaml` header comment** (it currently documents only `clicks:`). Caveat to
record: the syntax exists only in the rebuilt sidecar — an "unknown key" error means a stale
image, not a bad scenario. (A single `clicks:` also fires `mouse_entered` via
motion-before-press, which is why `hovers:` was introduced as a separate, click-free path.)

### 3.S Small fixes (folded into the docs card)

- **Heading.** `final/delivery_notes.md`: the mislabeled section heading
  `# Delivery notes — jinyong-nodes(主线事件) (2026-08-29)` →
  `# Delivery notes — jinyong-mainline(主线事件) (2026-08-27)`. That section was written by
  the jinyong-mainline round on 2026-08-27; `jinyong-nodes` is a different round and
  08-29 is a future date. Surgical edit; the rest of the section is untouched.
- **One map hint.** The MAP segment currently prints the same operation hint twice
  (the `map.gd::_render()` TRAVEL panel trailing line at ~L221 AND the footer `HintLabel`).
  **Keep the footer `HintLabel`, remove the panel trailing hint line** (`\n\n左右/上下选择相邻去处，回车启程`
  suffix → leave `当前：%s`). Justification (in `design/` + `99_changelog.md`): the footer is
  the map's persistent operation hint, is already asserted (`HintLabel.text`), and already
  carries the EVENT-hide logic (`_apply_hint_visibility`, `phase != "EVENT"`); removing the
  panel line is the smallest blast radius and one screen keeps one hint. The related
  assertion (`map_node_event_mainline_return.yaml` `HintLabel.text ==` the string) stays
  green and unchanged — verified by grep that **no** playtest yaml pins the panel `BodyLabel`
  hint text (the `MapScreen` surface does not even expose `BodyLabel.text`), so removing the
  panel line is assertion-safe. Record in `99_changelog.md` why the jinyong-mainline
  "byte-identical" unification is now changed to "one screen, one hint".
- **Full-width comma.** `map.gd` EVENT branch (~L210): `上下选择,回车定夺` (ASCII `,`
  U+002C) → `上下选择，回车定夺` (full-width `，` U+FF0C), matching the TRAVEL hint's
  full-width comma. Grep-verified: this is the only half-width punctuation in the MAP
  segment, and no yaml pins the EVENT body verbatim → assertion-safe. Scan the rest of the
  MAP segment for any other half-width punctuation.

## 4. Component list (paths relative to repo root)

| ID | File | Change |
|---|---|---|
| C-A1 | `scenes/ui/health_bar.tscn` | `Bar` add `mouse_filter = 2`; `NameLabel` add `mouse_filter = 2` (defensive) |
| C-A2 | `scripts/ui/health_bar.gd` | re-assert `Bar.mouse_filter = 2` in `update_health` (next to L352/L368) AND per-frame in `follow_character`; reposition nameplate to `sprite_top − 4 − size.y`; audit NameLabel |
| C-A3 | `scenes/enemy.tscn` | ClickTarget audit (measured; node kept). Decision on `mouse_filter` recorded from measurement |
| C-B1 | `scripts/ui/tile_markers.gd` (NEW) | Node2D ground-marker overlay (ellipse + outline at `grid_to_world`, all living units) |
| C-B2 | `scenes/battlefield.tscn` | add `TileMarkers` node AFTER `Characters` |
| C-B3 | `scripts/characters/enemy.gd` | publish `portrait_ink_rect` (clamped ink rect) in `_process` |
| C-B4 | `scripts/characters/player.gd` | publish `portrait_ink_rect` (symmetry); implement the §3.B2 hit priority in `handle_world_click` + pure `attack_reach_covers` |
| C-C1 | `scripts/segments/creation.gd` | `trait_hover_index`; wire `mouse_entered`/`mouse_exited` on `TraitToggle{0..12}`; `_render` prefers hover index for `TraitDescLabel` only |
| C-S1 | `final/delivery_notes.md` | heading fix (§3.S) |
| C-S2 | `scripts/segments/map.gd` | remove panel trailing hint line; EVENT comma → full-width; audit MAP segment punctuation |
| C-P1 | `playtest/click_move_undo_right_feet.yaml` (NEW) | Defect A feet-undo pin |
| C-P2 | `playtest/click_portrait_body_targets_enemy.yaml` (NEW) | Defect B body-click damages/acts |
| C-P3 | `playtest/health_bar_above_portrait.yaml` (NEW) | bar bottom above sprite_top, incl. top-row face-band; ground-marker observable |
| C-P4 | `playtest/trait_hover_preview.yaml` (NEW) | Defect C hover preview, trait_index untouched |
| C-P5 | `playtest/_common.yaml` | surface whitelist additions; `hovers:` header doc; `scenario_order` append (C-P1..4) |
| C-P6 | `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` two-place sync (C-P1..4) + surface-contract pins |
| C-U1 | `tests/test_click_priority.gd` (NEW) | pure `attack_reach_covers` + resolve-order truth table (headless) |
| C-U2 | `tests/test_trait_hover_preview.gd` (NEW) | hover index never mutates trait_index / never toggles (headless) |
| C-D1 | `design/` docs (landed by 5_design) | 3.A audit results, 3.B1 landing/top-row, 3.B2 priority rule + rejected §3.1, 3.C hover, 3.S; `99_changelog.md` rows |

## 5. Observable contract (exact surface names to whitelist in `playtest/_common.yaml`)

- `Enemy.*` / `Player.*`: add `portrait_ink_rect` (Rect2) — beside the existing
  `portrait_sprite_pos` / `portrait_tex_size` / `sprite_top`.
- `CreationScreen`: add `trait_hover_index` (int) and `hover_connected` (Dictionary,
  per-toggle `mouse_entered`/`mouse_exited` counts > 0).
- `HealthBar`: add `bar_top` (float) and `bar_bottom` (float) — derived in `follow_character`
  from the live `global_position.y` + `size.y`, so the "bar bottom above sprite_top" pin
  reads live geometry; `bar_anchors_sprite_top` (bool) true when the unclamped desired bottom
  == `sprite_top − 4`.
- `Battlefield` (or a `TileMarkers` surface): add `tile_marker_count` (int, living units
  with a drawn marker) and `tile_marker_visible` (bool). The marker node exposes these via
  the same `get_*` duck-typed surface the harness reads.

Numeric pins are relative where possible (`bar_bottom <= sprite_top + 40` for the top-row
face-band case; `bar_bottom < sprite_top` for mid-board; `trait_hover_index == 5`,
`trait_index == 0`). The map hint string is a **text contract** (one absolute), consistent
with the jinyong-nodes precedent.

## 6. Playtest scenario skeletons (architect-owned; PM finalizes frames/thresholds)

All direct-boot where the screen allows; `name == basename`; single-integer `at:`; a
comparison operator (or `changed`) on every dotted assert line; frame cap 3000 (last ≤ 2999).

**C-P1 `click_move_undo_right_feet.yaml`** — `scene: res://scenes/main.tscn`. Boots the
tutorial battle (7× `ui_accept` + `tutorial_next` prefix, mirroring `click_move_undo_right`).
Legs: (a) assert round-1 baseline `grid_pos == (7,5)`, `moves_left == 4`, `undo_available
== false`; (b) walk up N tiles (e.g. `Player +0,-128`) → assert `undo_available == true`,
`moved == true`, `grid_pos: changed` (the "before" leg proving the bug is exercised); (c)
right-click `Player +0,0` (the **feet** of the moved position) → assert retreat:
`grid_pos == (7,5)`, `moves_left == 4`, `moved == false`, `undo_available == false`. The
existing `click_move_undo_right.yaml` (clicks `Player +64,0`) is **not modified**.

**C-P2 `click_portrait_body_targets_enemy.yaml`** — `scene: res://scenes/main.tscn`. Move
the player adjacent to a Great (e.g. to (7,4) so an enemy is in basic reach), then click the
enemy's **portrait body center** (the drawn rect, NOT the feet tile) — computed from the live
`portrait_ink_rect` center, which for a mid-board enemy is ~one tile above the feet. Assert
`enemy.health: changed` (or `< before`) and `Player.acted == true`. The clicked point is a
reachable empty tile (the body hangs over it) — under the old code this moved; under the new
rule it attacks. Include a negative control: a body click on an **out-of-reach** enemy
selects (`debug_click_unit == <name>`) but does **not** damage (`health` unchanged, `acted
== false`).

**C-P3 `health_bar_above_portrait.yaml`** — `scene: res://scenes/main.tscn`. For a mid-board
unit assert `HealthBar.bar_bottom < sprite_top` (bar strictly above the portrait). For
**Central_Divine** (top-row, clamped) assert `HealthBar.bar_top == 94` (clamped) AND
`HealthBar.bar_bottom <= sprite_top + 40` (the 26 px intrusion stays in the hair/forehead
band, face untouched). Also pin `Battlefield.tile_marker_count == <living units>` and
`tile_marker_visible == true` for both a mid-board and a top-row unit.

**C-P4 `trait_hover_preview.yaml`** — `scene: res://scenes/segments/creation.tscn`. Walk to
TRAITS phase. `hovers: TraitToggle5` → assert `CreationScreen.trait_hover_index == 5`,
`TraitDescLabel.text` contains trait-5's keyword, `CreationScreen.trait_index == 0`
(unchanged), `CreationScreen.hover_connected["TraitToggle5"] == true`. Then `hovers:
TraitNextButton` (pointer leaves the toggle) → `trait_hover_index == -1`, `TraitDescLabel`
reverts to trait-`trait_index`'s text, `trait_index` still 0, no toggle fired
(`trait_ids` unchanged). If the sidecar rejects `hovers:` as "unknown key", that is a stale
image — escalate, do not convert to a `clicks:` (a click would toggle).

## 7. GDScript unit pins (headless `run() -> bool`, registered in `unit_test_runner.gd`)

- `tests/test_click_priority.gd` — truth table for the §3.B2 resolver (pure static over
  grid/reach/rects): own-tile occupied → attack; reachable-empty-highlighted with an
  out-of-reach rect crossing → move; reachable-empty-highlighted with an in-reach rect
  containing the point → attack (the gap-closing case); out-of-reach body, non-highlighted
  → select; own empty non-highlighted → no-op. Plus `attack_reach_covers` for basic range 1
  and a representative skill range.
- `tests/test_trait_hover_preview.gd` — `trait_hover_index` previews the desc, never writes
  `trait_index`, never calls `_toggle_trait` (trait_ids unchanged), `modulate` driven only by
  `trait_index`; `phase != "TRAITS"` resets hover to -1.

## 8. Edge cases → how this design answers each

- **A: filter re-assert must survive scene re-entry/headless.** The new `Bar.mouse_filter
  = 2` write follows the existing guarded `get_node_or_null` pattern and is asserted both in
  `update_health` and the per-frame `follow_character`. NameLabel gets an explicit tscn
  value + audit. ClickTarget measured, node kept.
- **A: new test must click feet while undo is available.** C-P1's "before" leg pins
  `undo_available == true`; the existing `click_move_undo_right.yaml` (+64,0) is untouched.
- **A: ClickTarget verify-by-measurement.** Instrumented probe (gui_input fires vs
  debug_click_events); verdict recorded in `design/30_presentation.md`; node kept (harness
  anchor).
- **B: `bar_bottom < sprite_top` is impossible for top-row under the retained clamp.**
  Central_Divine `sprite_top == 92`; bar clamped to 94–118. The strict assertion holds for
  mid-board; for the top row the design pins the **documented landing** (`bar_top == 94` AND
  `bar_bottom <= sprite_top + 40`, face ≥ sprite_top+40 untouched). The brief's "including
  top-row Central_Divine" is satisfied by this top-row-specific pin.
- **B: hit-test uses the live clamped rect, not the naive feet−128.** `portrait_ink_rect`
  is recomputed every frame from the clamped `sprite.offset` (+ `sprite_top`), so top-row and
  edge units get the correct rect. The clamp is **static and shared** (player + enemy) and
  is **not changed** (3.B2/SOTA §3.4).
- **B: 96 vs 64 ⇒ overlap + every portrait covers the tile above; rule must be visible.**
  The chosen rule never makes a reachable empty tile unclickable (step 2 only fires for
  in-reach enemies; the §3.1 regression was out-of-reach Central_Divine's rect over (7,2),
  which step 2 skips). The ground marker (3.B1) makes "where to click" visible.
- **B: body-center test must not be a valid move destination OR the gap is closed.** This
  design **closes the gap** (step 2), so C-P2 clicks a **reachable** enemy's body (the
  user's actual complaint), not the easy out-of-reach case.
- **B: ground marker click-inert AND on top where it matters.** Node2D `_draw` (no GUI);
  mounted after `Characters` (measured visible for all six incl. top row).
- **B: moving the nameplate re-baselines yamls.** `portrait_bar_pos`,
  `hpbar_strip_overlap`, `hint_nameplate_overlap`, `nameplate_pairwise_overlap` re-baselined
  with justification; the bar is now IGNORE so it no longer counts as a `covered` host for
  `portrait_visibility` (strictly safer).
- **C: hover must not leak into the keyboard path.** `trait_hover_index` is display-only,
  reset to -1 on `mouse_exited` and whenever `phase != "TRAITS"`; `modulate`/`pressed` driven
  solely by `trait_index`. Assertable via the rebuilt `hovers:` syntax (C-P4).
- **Small fixes:** remove panel line (footer kept, already asserted, EVENT-hide intact);
  EVENT comma → full-width (grep-verified no yaml pins it); heading surgical edit.

## 9. Safety / rollback

No irreversible operations. All edits are additive or surgical single-line/scene-stanza
changes; `.tscn` and `.gd` are text and diff-revertible. The clamp, art size, TILE_SIZE,
BOARD_TOP_MARGIN_Y, and STRIP_BOTTOM+2 are **untouched** (frozen constants). The new
`TileMarkers` node and the four new scenarios are additive (drop-in). `click_move_undo_right.yaml`
is **not modified**. If the §3.B2 rule reddens a scenario in the 7-scenario net, **do not
weaken the scenario** — escalate to design (the rule's acceptance net is those 7; a red there
means the in-reach gate intercepted a move the scenario expected, which must be resolved by
narrowing the gate, not by deleting an assertion). The `tests/fixtures/playtest_assert_superset.json`
"only-add-never-remove" machine pin from jinyong-nodes still guards the two previously-edited
yamls; the four new scenarios are appended, not inserted into protected files.

## 10. Task decomposition (for PM)

| ID | Task | Files | Depends on |
|---|---|---|---|
| T1 | Defect A: Bar STOP fix + per-frame re-assert + NameLabel audit | C-A1, C-A2 | — |
| T2 | ClickTarget measurement + record verdict in design/ | C-A3, C-D1(partial) | T1 |
| T3 | Defect B visual: nameplate → sprite_top (retain clamp) + top-row landing doc | C-A2, C-D1(partial) | T1 |
| T4 | Defect B visual: ground marker `TileMarkers` (node after Characters) | C-B1, C-B2 | — |
| T5 | Defect B hit: `portrait_ink_rect` observable (enemy + player) | C-B3, C-B4(partial) | — |
| T6 | Defect B hit: §3.B2 resolver + `attack_reach_covers` in `handle_world_click` | C-B4, C-U1 | T5 |
| T7 | Defect C: `trait_hover_index` + hover wiring + `_render` preference | C-C1, C-U2 | — |
| T8 | Small fixes: heading, one map hint, full-width comma | C-S1, C-S2 | — |
| T9 | Surface whitelist + `hovers:` header doc + `scenario_order` | C-P5 | T1,T6,T7 |
| T10 | Four new scenarios (C-P1..4) | C-P1..4 | T9 |
| T11 | pytest two-place sync + surface-contract pins | C-P6 | T10 |
| T12 | Unit pins (click priority, hover preview) | C-U1, C-U2 | T6, T7 |
| T13 | Design-archive declarations (5_design lands after verification) | C-D1 | T1–T12 |
| T14 | `final/delivery_notes.md` — what changed, new assertions, B priority rule | (delivery notes) | T1–T13 |

## 11. Technology stack

Godot 4 built-ins only (no external packages): `Control.mouse_filter`, the
`_input`→GUI→`_unhandled_input` order, `Button.mouse_entered`/`mouse_exited`, `Node2D._draw`,
`Rect2.has_point`, `GridManager.world_to_grid` / `grid_to_world` / `clamp_sprite_offset`.
GDScript for logic; `.tscn` is hand-editable text. Tests: headless GDScript `extends
SceneTree` unit pins + the `playtest/` YAML contract + `tests/test_playtest_contract_smoke.py`
pytest. All gates run through the `godot-builder` sidecar (`/compile`, `/playtest`, `/vision`,
`/script`).

## 12. Linter manifest

`linter_manifest.json` keeps `.py: ruff`, `.md/.json/.yaml: basic`. `.gd` and `.tscn` are
**intentionally not in the manifest** — the `gdscript_check` gate parses them per-file via
`godot --check-only` (host-controlled, not via the manifest, so a misspelled backend can never
silently disable the gate). See the separate `linter_manifest.json`.
