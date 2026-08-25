# Technical Architecture Design - Portrait Visibility Observability (UX-01) + Move-Target Affordance (UX-02)

Round: **jinyong-affordance**. Baseline HEAD `5bf8fb8`: playtest 44 scenarios / 43 green
(only `terminal_victory_8_12_rounds_hp_15_40` deliberately red), pytest 7 passed, vision
gate 6/6. This round adds **no new mechanics**. It adds two things the design archive
demands and the gates could not express:

1. **UX-01** - 王重阳 (`Central_Divine`) and 杨过 (`Player`) render **no portrait ink** on
   the battle frame (name + health bar only; the other four Greats render fine). Today
   nothing can *prove* that from a test: `visible` flags and `sprite_top` are green while
   the pixels are absent. We need a **layered on-frame visibility predicate** that turns
   "the portrait is visible on the rendered frame" into a decidable, assertable fact -
   **probed per unit first (查明 before 修), never assumed**.
2. **UX-02** - right-click undo works (44-scenario gate proves it) but the move-target box
   has **zero affordance**: the player is never told 左键移动 / 右键退回 / 出手即确认.
   We need a **state-following hint** whose copy tracks the move state machine (pending ->
   undo-available -> committed), in Chinese, mouse-transparent, additive.

Per `step1_sota.md`, everything is built from engine-native APIs
(`is_visible_in_tree`, `get_global_rect`, `Rect2.intersection`, `get_visible_rect`,
ancestor `clip_contents` scan, draw-order comparison) plus the repo's proven probe /
playtest / append-only-contract idioms. **No new libraries, no node renames, no
reparents, no gameplay-logic changes.**

---

## 1. Overview

Two defect classes, one shared observability layer:

| Goal | Defect | Fix idiom | Red-before-fix proof |
|---|---|---|---|
| UX-01 | Two units' portraits never render; cause **suspected** (`_refresh_sprite_clamp` / `clamp_sprite_offset`), **not concluded** | Probe matrix per unit -> targeted fix -> layered `portrait_visible` predicate | `Player.portrait_visible == false` and `Central_Divine.portrait_visible == false` **observed** at baseline (A-class); the other four units observed `true` (B-class guards) |
| UX-02 | Move-target box has no affordance; right-click undo is an invisible feature | New self-driving `MoveHintLabel` polling existing move-state fields | Scenario `move_target_affordance` fails at baseline (node absent -> surface target unresolved = hard red); post-fix asserts the hint's **text/state in both states** (pending vs committed) |

**Probe-first is a hard ordering**: the UX-01 fix task may not start until the probe task
has written `final/portrait_probe_notes.md` with per-unit observed values (runtime-measured,
never derived from `.tscn` - the health-bar round found a 2.75x authored-vs-runtime gap).
王重阳 and 杨过 are probed **independently and never merged** - they may fail for
different reasons (different parents, different textures, different clamps).

---

## 2. Architecture Diagram (text)

```
                    ┌──────────────────────────────────────────────┐
                    │ NEW  scripts/ui/visibility_probe.gd          │
                    │ class_name VisibilityProbe (static, no node) │
                    │  leaf_rect(node) -> Rect2                    │
                    │  first_fail_layer(unit_root) -> String       │
                    │    "" | "hidden_in_tree" | "null_texture"    │
                    │    | "zero_rect" | "off_viewport"            │
                    │    | "clipped" | "occluded"                  │
                    │  portrait_visible(unit_root) -> bool         │
                    └──────────────┬───────────────────────────────┘
                                   │ called (cheap, per frame)
        ┌──────────────────────────┴───────────────────────────┐
        │ player.gd / enemy.gd  (ADDITIVE, ~6 lines each)      │
        │  _process(): after _refresh_sprite_clamp():          │
        │    portrait_fail_layer = VisibilityProbe             │
        │        .first_fail_layer(self)                       │
        │    portrait_visible = portrait_fail_layer == ""      │
        └──────────────────────────┬───────────────────────────┘
                                   │ surface (append-only)
    playtest/_common.yaml  Player.{portrait_visible, portrait_fail_layer}
                          East_Heretic / West_Poison / South_Emperor /
                          North_Beggar / Central_Divine .{same two}
                          NEW NODE MoveHintLabel.{state, text, visible,
                          tile, center, in_viewport, bar_overlap}

    ┌────────────────────────────────────────────────────────────┐
    │ NEW  scripts/ui/move_hint_label.gd + MoveHintLabel (Label) │
    │ in scenes/ui/hud.tscn - self-driving poller (the proven    │
    │ MoveRangeHighlight pattern): polls GameManager.get_player(),│
    │ CombatManager.is_player_turn(), player.moves_left /        │
    │ undo_available / acted / grid_pos EVERY FRAME, never       │
    │ stores the ref; recomputes text + position. mouse_filter=2 │
    │ (IGNORE - it must never eat the click-move events).        │
    │   state: "hidden" | "idle" | "undo_ready" | "committed"    │
    │   idle:      「左键点格移动 · 右键退回」                      │
    │   undo_ready:「右键退回起点 · 出手即确认」                    │
    │   committed: 「已出手 · 移动已确认」                          │
    │   position: player tile world center + (0, +44), clamped   │
    │   into the viewport, in the same layer-10 / scale-1 space  │
    │   the HealthBars live in (no Node2D<->Control conversion)  │
    └────────────────────────────────────────────────────────────┘

    GATES (append-only / new files):
      playtest/portrait_visibility.yaml      NEW scenario (A-class UX-01)
      playtest/move_target_affordance.yaml   NEW scenario (A-class UX-02)
      _common.yaml scenario_order            += both (append at end)
      tests/test_playtest_contract_smoke.py  ROUND_SCENARIOS += both (same order)
                                            + ONE additive test function
      44 scenarios -> 46 scenarios; terminal_victory stays the only allowed red
```

Data flow is one-directional: game state (engine-owned fields `grid_pos`, `moves_left`,
`acted`, `undo_available`, `turn_start_grid`) -> read-only observers
(`VisibilityProbe`, `MoveHintLabel`) -> surface vars -> yaml asserts. **Observers never
write game state.**

---

## 3. Component List

### 3.1 `scripts/ui/visibility_probe.gd` - NEW layered visibility predicate

**Responsibility:** answer "does this unit's portrait put ink on the rendered frame" as a
decidable fact, reusing one implementation for probes, red-before-fix assertions, and
future rounds. Pure static functions; no node, no state, no scene change.

**Interface (exact names - PM/PM thresholds and implementers match verbatim):**

```gdscript
class_name VisibilityProbe

## Global rect of the node that actually draws the ink. Sprite2D uses
## position + offset +/- texture half-size under the node's global transform;
## Control uses get_global_rect(). Containers are NOT leaves - callers must
## pass the ink node (the unit's "Sprite" child), which this helper resolves
## from the unit root.
static func leaf_rect(unit_root: Node2D) -> Rect2

## First failing layer, "" when fully visible on-frame. Layer order is the
## cheap-to-expensive order from step1_sota.md:
##  1 "hidden_in_tree"  leaf.visible == false OR not is_visible_in_tree()
##  2 "null_texture"    Sprite2D.texture == null OR texture size == 0
##  3 "zero_rect"       leaf rect has zero area, scale == Vector2.ZERO,
##                       or combined modulate alpha < 0.01 (self x ancestors)
##  4 "off_viewport"    leaf rect intersection with
##                       get_viewport().get_visible_rect() is empty
##                       (intersection must be NON-empty - touching edges
##                       does not count)
##  5 "clipped"         an ancestor Control with clip_contents == true does
##                       not enclose the leaf rect
##  6 "occluded"        a later-drawn / higher-z Control whose rect fully
##                       covers the leaf rect AND mouse_filter != IGNORE
##                       (the repo's opaque-host convention)
static func first_fail_layer(unit_root: Node2D) -> String

## Convenience: first_fail_layer(unit_root) == "".
static func portrait_visible(unit_root: Node2D) -> bool
```

**Layer-6 simplification (declared):** full occlusion via `gui_get_hovered_control()` is
mouse-dependent and therefore out of scope for a pure visibility test; the check is the
SOTA's draw-order comparison (tree order + `z_index` / `show_behind_parent` +
`CanvasLayer`) restricted to intersecting `Control`s. In the battle scene the only
candidates are the TopStrip and the tutorial overlay, both already
`mouse_filter`-declared - so the predicate stays cheap and deterministic.

**Why a shared helper instead of asserts in yaml:** the same predicate must serve (a) the
probe matrix (print every layer's inputs per unit), (b) the A-class assertions, and (c)
the B-class guards. One implementation, one place to be wrong.

### 3.2 `scripts/characters/player.gd` + `scripts/characters/enemy.gd` - ADDITIVE observables

**Responsibility:** publish the predicate per frame so the harness can read it like any
other surface var.

**Changes (identical shape in both files, no existing line touched):**

- Two new declared vars (documented, playtest surface):
  - `var portrait_visible: bool = false`
  - `var portrait_fail_layer: String = ""`
- In `_process()`, immediately after the existing `_refresh_sprite_clamp()` call (so the
  reading happens after the clamp has settled this frame):
  `portrait_fail_layer = VisibilityProbe.first_fail_layer(self)` and
  `portrait_visible = portrait_fail_layer == ""`.

**Interface:** surface vars `portrait_visible` / `portrait_fail_layer` on `Player`,
`East_Heretic`, `West_Poison`, `South_Emperor`, `North_Beggar`, `Central_Divine`. No
method signatures change; `_refresh_sprite_clamp` and `clamp_sprite_offset` are **not**
modified by this component (any change to them belongs to the 3.3 fix task and must be
justified by probe evidence).

### 3.3 UX-01 fix - `scripts/autoload/grid_manager.gd` / character scripts (GATED ON PROBE)

**Responsibility:** make the two invisible units pass layer 1-6, changing **only what the
probe identified**.

**This component intentionally has no fixed diff.** The brief's rule is
先查明再修，不许猜 ("find out first, no guessing"). The probe (task A1) writes
`final/portrait_probe_notes.md` with, per unit: `visible`, `is_visible_in_tree()`,
`texture` resource path + size, `scale`, `modulate` chain alpha, `offset` before/after
clamp, leaf rect, viewport intersection, failing layer. The fix is then chosen from the
observed failing layer:

| Observed failing layer | Likely fix locus (verify against probe numbers) |
|---|---|
| `null_texture` | `enemy.gd TEXTURE_PATHS` key mismatch for the unit's `character_name`, or player-side texture path - assign the texture, keep the null-safe fallback |
| `off_viewport` / `zero_rect` from a bad offset | `GridManager.clamp_sprite_offset` bounds math or `_refresh_sprite_clamp`'s use of it - correct the math so the clamped rect stays on-board; the current suspicion (offset pushed fully off the board for the top row / center column) is **a suspicion, not a conclusion** |
| `clipped` | remove/relax `clip_contents` on the offending ancestor |
| `occluded` | draw order / `z_index` of a covering host |

**Constraint:** whatever the fix, it must keep the other four units' `portrait_visible`
true (B-class guards) and keep `sprite_top` semantics unchanged (existing surface asserts
read it). Numbers are read at **runtime**, not from `.tscn`.

### 3.4 `scripts/ui/move_hint_label.gd` + `MoveHintLabel` node - NEW (UX-02)

**Responsibility:** a self-evident, state-following affordance for click-move + right-click
undo, whose copy changes **in the same transition** that locks the move - never showing a
promise that no longer holds (the deleted "右键确认" creation-screen mistake must not
reappear).

**Node:** `MoveHintLabel` (type `Label`) added to `scenes/ui/hud.tscn` as a **new sibling
at a path nothing pins** (the TopStrip precedent), in the same layer-10 / scale-1
coordinate space as the floating `HealthBar`s. Properties: `mouse_filter = 2` (IGNORE -
hard requirement, it must never eat the click-move events), font = global theme (CJK),
font size 14, `modulate` with outline/contrast readable over the board, NO `focus_mode`
concern (Label is not focusable; the clickable discipline `focus_mode = 0` applies to
clickables only).

**Driver script (self-driving poller, the proven `MoveRangeHighlight` pattern - polls
every frame, never stores the player ref, hides itself when the battle ends; the node
dies with the scene swap):**

```gdscript
extends Label

# Observables (playtest surface contract)
var state: String = "hidden"      # "hidden" | "idle" | "undo_ready" | "committed"
var tile: Vector2i = Vector2i(-1, -1)
var center: Vector2 = Vector2.ZERO
var in_viewport: bool = false
var bar_overlap: bool = false     # vs the player's HealthBar (1px-inset convention)

func _process(_delta: float) -> void:
    # state = f(existing engine-owned fields only - zero new game state):
    #   hidden   <- no player / not battle / not player's turn / moves_left <= 0
    #   idle     <- player's turn, undo_available == false, acted == false
    #   undo_ready <- undo_available == true (moved, not yet committed)
    #   committed  <- acted == true (undo locked by the commit rule)
    # text:   idle -> "左键点格移动 · 右键退回"
    #         undo_ready -> "右键退回起点 · 出手即确认"
    #         committed  -> "已出手 · 移动已确认"
    # position: grid_to_world(player.grid_pos) + (0, +44)  (below the feet,
    #           above the tile edge), then clamped so the label rect stays
    #           inside the 960x704 viewport; center/in_viewport/bar_overlap
    #           recomputed from the final rect.
```

**Why follow the tile instead of a fixed dock:** the UX complaint is "the move-target box
has no affordance" - the promise must sit **where the action is** (the yellow box /
turn-start marker), not in a corner the eye is not on. The below-the-feet slot is empty
today (name + health bar float **above** the sprite), so the hint adds no occlusion; the
`bar_overlap` observable proves it per frame.

**Why keep the label visible in `committed` (with swapped text) rather than hiding:** the
archive rule is the copy must **follow state**; swapping text is strictly more assertable
than toggling visibility (a `visible` flip and a `text` swap can both be pinned, but the
swap also proves the *promise* changed, not just that something disappeared).

### 3.5 `playtest/_common.yaml` - surface + order (append-only)

- `surface:` appends `portrait_visible`, `portrait_fail_layer` under `Player`,
  `East_Heretic`, `West_Poison`, `South_Emiror` -> **`South_Emiror` is a typo in this
  design doc only - use the existing key `South_Emperor`**, `North_Beggar`,
  `Central_Divine` (existing blocks, append at the end of each list; no line reordered).
- `surface:` adds a NEW top-level block `MoveHintLabel: [state, text, visible, tile,
  center, in_viewport, bar_overlap]` (the harness resolves nodes by bare name, like
  `TopStrip` / `ActionHintLabel`).
- `scenario_order:` appends `portrait_visibility` then `move_target_affordance` (both at
  the end, matching `ROUND_SCENARIOS`).

### 3.6 `playtest/portrait_visibility.yaml` - NEW scenario (A-class UX-01)

Boot shape copies the proven `ui_geometry_readability` / `click_move_*` prologue
(7x `ui_accept` f3..f15 -> 3x `tutorial_next` f20/f25/f30 -> assert f40; every assert
value carries a comparison operator - the repo's `== true` discipline):

```yaml
name: portrait_visibility
timeline:
- {at: 3..15, actions: [ui_accept]}          # 7 presses (proven boot)
- {at: 20/25/30, actions: [tutorial_next]}   # skip tutorial cards
- at: 40
  assert:
    Player.portrait_visible: portrait_visible == true            # A-class
    Player.portrait_fail_layer: portrait_fail_layer == ""         # A-class
    Central_Divine.portrait_visible: portrait_visible == true     # A-class
    Central_Divine.portrait_fail_layer: portrait_fail_layer == "" # A-class
    East_Heretic.portrait_visible: portrait_visible == true       # B-class guard
    West_Poison.portrait_visible: portrait_visible == true        # B-class guard
    South_Emperor.portrait_visible: portrait_visible == true      # B-class guard
    North_Beggar.portrait_visible: portrait_visible == true       # B-class guard
    Player.sprite_top: sprite_top >= 0.0                          # B-class (on-board)
    Central_Divine.sprite_top: sprite_top >= 0.0                  # B-class (on-board)
```

At baseline the four A-class lines are **red by construction** (observed, per the probe
notes) and the B-class lines green - exactly the SOTA A/B split: A proves the defect, B
guards the four healthy units against regression by the fix.

### 3.7 `playtest/move_target_affordance.yaml` - NEW scenario (A-class UX-02)

Frames reuse the click-move scenarios' proven timings (`click_move_undo_right`: move
f70->settled f130, undo f135->f170). Real mouse events only (`clicks:`), no DEBUG
stand-ins:

```yaml
name: move_target_affordance
timeline:
- {at: 3..15, actions: [ui_accept]}            # 7 presses
- {at: 20/25/30, actions: [tutorial_next]}
- at: 45                                        # turn start, nothing moved
  assert:
    MoveHintLabel.state: state == "idle"
    MoveHintLabel.text: text.contains("左键") == true
    MoveHintLabel.visible: visible == true
    MoveHintLabel.in_viewport: in_viewport == true
- at: 70
  clicks: [Player +0,-192]                     # walk 3 tiles up to (7,2)
- at: 130
  assert:
    Player.grid_pos: grid_pos == Vector2i(7, 2)
    MoveHintLabel.state: state == "undo_ready"
    MoveHintLabel.text: text.contains("右键") == true
    MoveHintLabel.bar_overlap: bar_overlap == false
    MoveHintLabel.in_viewport: in_viewport == true
- at: 135
  clicks: [Player +0,0 right]                  # undo -> back to (7,5)
- at: 170
  assert:
    Player.grid_pos: grid_pos == Vector2i(7, 5)
    MoveHintLabel.state: state == "idle"       # promise follows state back
- at: 175
  clicks: [Central_Divine_ClickTarget]         # click-attack from (7,2)... see note
- at: 230
  assert:
    Player.acted: acted == true
    Player.undo_available: undo_available == false
    MoveHintLabel.state: state == "committed"
    MoveHintLabel.text: text.contains("已出手") == true
    MoveHintLabel.visible: visible == true
```

**Note for the implementer (re-baseline before finalizing):** the commit arm needs the
player adjacent to a target. Two proven options: (a) walk to (7,2) again then click
`Central_Divine_ClickTarget` (click-to-attack, proven in `click_targeting_fixed`), or
(b) `skill_1` + `attack_confirm` after moving adjacent (keyboard path, proven in
`skill_rejection_reason_texts`). Pick one, probe the frames once, then freeze them - the
asserts above (state/text in **both** the pending and the committed state) are the
contract; the exact frames are placeholders for the probe.

### 3.8 `tests/test_playtest_contract_smoke.py` - additive contract pin

- `ROUND_SCENARIOS` appends `portrait_visibility`, `move_target_affordance` **in the same
  order** as `scenario_order` (the two-place sync rule). Existing entries untouched.
- ONE new test function, e.g. `test_affordance_surface_contract`, asserting statically:
  the six units' surface blocks contain `portrait_visible` / `portrait_fail_layer`;
  `MoveHintLabel` block exists with its seven vars; both new scenario files exist, their
  `name:` equals the basename, and every assert value in them contains a comparison
  operator (guards the "no bare-scalar silent-false" rule for the new files).

### 3.9 Probe + evidence artifacts (task outputs, not gate files)

- `final/portrait_probe_notes.md` (NEW) - the A/B probe table for all six units:
  per-unit layer inputs and observed failing layer **before** the fix, with the A/B class
  column (format copies `final/creation_probe_notes.md`). Probe method: inline scenario
  via `godot_playtest_scenario` (YAML passed as CLI text, never staged), always-false
  contradiction asserts forcing the harness to print `observed` values.
- `final/move_hint_probe_notes.md` (NEW) - pre-fix confirmation that `MoveHintLabel` is
  absent (surface target unresolved -> hard red) and post-fix state/text readings at the
  four states.
- Raw-frame captures at native 960x704 (the 5_compile frames) are the human/vision-gate
  evidence that all **six** portraits now render; no zoomed evidence (hard rule).

### 3.10 Documentation (declared for the `5_design` step - not written by implementers)

See section 7 (Design Changes).

---

## 4. Observable Contract (interface spec - names are verbatim)

| Surface var | Type | Writer | Meaning |
|---|---|---|---|
| `<Unit>.portrait_visible` | bool | per-frame predicate | all six visibility layers pass for that unit's ink leaf |
| `<Unit>.portrait_fail_layer` | String | per-frame predicate | first failing layer id, "" when visible |
| `MoveHintLabel.state` | String | per-frame poller | "hidden" / "idle" / "undo_ready" / "committed" |
| `MoveHintLabel.text` | String | per-frame poller | the current Chinese hint copy |
| `MoveHintLabel.visible` | bool | poller (sole writer) | label on-frame |
| `MoveHintLabel.tile` | Vector2i | per-frame poller | tile the hint is docked to (player's tile) |
| `MoveHintLabel.center` | Vector2 | per-frame poller | final clamped label center (viewport space) |
| `MoveHintLabel.in_viewport` | bool | per-frame poller | label rect fully inside 960x704 |
| `MoveHintLabel.bar_overlap` | bool | per-frame poller | 1px-inset overlap vs the player's `HealthBar` |

`<Unit>` ∈ {`Player`, `East_Heretic`, `West_Poison`, `South_Emperor`, `North_Beggar`,
`Central_Divine`}. All values assertable with comparison operators only.

---

## 5. Edge Cases (from `step1_sota.md`) and how this design handles them

- **`visible == true` but ancestor hidden / zero-size / off-screen / clipped /
  occluded** - each is its own named layer in `first_fail_layer`; the predicate cannot
  pass while any of them fails, and the *failing layer id* is itself observable, so the
  red assertion says **why**, not just "no".
- **Leaf-rect discipline** - `leaf_rect()` measures the unit's `Sprite` (the ink), never
  the unit root (a slot); containers are never summed.
- **Two invisible units, two causes** - the probe records each unit separately; the
  scenario asserts each unit's own line; nothing merges them.
- **A-class must be red at baseline, measured at runtime** - `portrait_visible` is read
  from a live headless run (probe notes record the observed values), not derived from
  `.tscn`; the health-bar round's authored-vs-runtime 2.75x gap is the recorded reason.
- **Affordance copy must follow state** - the hint's `text`/`state` is a pure function of
  the engine-owned fields; the scenario pins the copy in `idle`, `undo_ready`, **and**
  `committed`, plus the return to `idle` after undo.
- **RMB conflict** - the hint is display-only (`mouse_filter = 2`); it introduces no
  input mapping, so it cannot collide with `click_move` / right-click undo / targeting.
- **Protected geometry** - TopStrip, creation centering, health-bar geometry, and the five
  protected click-move scenarios are untouched: no renames, no reparents, no edits to
  their yamls (the two new scenarios are new files; `_common.yaml` is append-only).
- **No mouse dependence in the visibility test** - layer 6 uses the draw-order/rect
  comparison, never hover APIs.

---

## 6. Technology Stack

- **Godot 4.4 engine APIs only** (per SOTA): `CanvasItem.is_visible_in_tree()`,
  `Control.get_global_rect()`, `Rect2.intersection()/intersects()/encloses()`,
  `Viewport.get_visible_rect()`, ancestor `clip_contents` scan, `z_index` /
  `show_behind_parent` / `CanvasLayer` ordering. Zero new dependencies.
- **Existing harness**: `playtest/` per-scenario yaml + `_common.yaml` contract,
  `godot_playtest_scenario` inline probes, `tests/test_playtest_contract_smoke.py`
  static contract, `run_tests.sh` (sidecar HTTP; unchanged).
- **GDScript for all new code**; no `.gd` entries in `linter_manifest.json` (the
  `gdscript_check` gate parses them host-side).

---

## 7. Design Changes (declared for `5_design` to apply - the implementer does NOT edit `design/`)

1. `design/40_ux_backlog.md`: UX-01 and UX-02 rows change to `CLOSED(jinyong-affordance)`
   with one-line evidence pointers (`final/portrait_probe_notes.md`,
   `playtest/portrait_visibility.yaml`, `playtest/move_target_affordance.yaml`). Closure
   is an explicit action in the fixing commit (backlog rule 2) - it must not be inferred
   from the findings disappearing.
2. `design/30_presentation.md`: add the **layered portrait-visibility predicate** to the
   readability hard-requirements section ("visible == true is necessary but not
   sufficient; on-frame visibility = 6 layers, see `VisibilityProbe`") and a UI-layout
   row for `MoveHintLabel` (below-the-feet, follows the player's tile, Chinese
   state-following copy, `mouse_filter = 2`).
3. `design/99_changelog.md`: one row for the round (probe findings summary + the two
   CLOSED ids).
4. If the UX-01 probe overturns the `_refresh_sprite_clamp` suspicion, the probe notes -
   not this design - are the record of the real cause; `5_design` cites them.

**No conflicts with the archive otherwise.** No numbers from `20_content.md` change; no
system rules from `10_systems.md` change; the hint copy is Chinese per the hard
requirement; no `90_decisions.md` Out-of-scope idea is reintroduced.

---

## 8. Safety, Baseline Protection, Rollback

- **No irreversible operations anywhere.** All edits are additive or property-level; no
  file is deleted, no schema migrated, no data rewritten. The only "replacing" write is
  `step2_design.md` itself (archived automatically).
- **Baseline protection (hard constraints):**
  - The 43 green scenarios stay green; `terminal_victory` stays the **only** allowed red.
  - The five protected click-move scenarios (`click_move_to_tile`, `click_move_undo_right`,
    `click_move_commit_lock`, `click_targeting_fixed`, `movement_range_highlight`) are
    byte-untouched; the new scenario reuses their proven frame timings instead of
    re-baselining them.
  - Pinned node paths unchanged; `MoveHintLabel` is a new sibling at an unpinned path
    (TopStrip precedent); `TopStrip` / creation / health-bar geometry untouched.
  - The UX-01 fix must keep the four healthy units' `portrait_visible` true (B-class
    guards) and `sprite_top` semantics unchanged.
- **Rollback path:** every component is one commit-sized revert (helper file, two var
  additions, one Label + driver, two yaml files, smoke-test function). If the fix
  regresses a protected scenario, revert the fix commit alone - the observables and the
  probe notes remain valid evidence either way.
- **Probe-first gating:** the 3.3 fix task is blocked until
  `final/portrait_probe_notes.md` exists with per-unit observed values. A fix PR without
  probe evidence is rejected at review.

---

## 9. Suggested Task Decomposition (for the PM)

| # | Task | Files | Depends on |
|---|---|---|---|
| A1 | Visibility predicate + per-unit observables + probe run + `final/portrait_probe_notes.md` | `scripts/ui/visibility_probe.gd` (NEW), `player.gd`/`enemy.gd` (additive), probe notes (NEW) | - |
| A2 | UX-01 fix from probe evidence (locus per 3.3 table) + `portrait_visibility.yaml` + surface/order/smoke wiring | `grid_manager.gd` or character scripts (per probe), `playtest/portrait_visibility.yaml` (NEW), `_common.yaml` (append), `test_playtest_contract_smoke.py` (additive) | A1 |
| B1 | `MoveHintLabel` node + driver + `move_target_affordance.yaml` + surface/order/smoke wiring + `final/move_hint_probe_notes.md` | `scenes/ui/hud.tscn` (new sibling), `scripts/ui/move_hint_label.gd` (NEW), `playtest/move_target_affordance.yaml` (NEW), `_common.yaml` (append), `test_playtest_contract_smoke.py` (additive) | - (parallel with A1/A2; the two-place `_common.yaml` sync must be serialized - one task lands its surface append, the other rebases) |
| C1 | Docs + README round-state rewrite (declared changes of section 7 applied only if 5_design defers) | `README.md` | A2, B1 |

Suggested order: A1 -> A2 -> B1 -> C1, with B1 allowed to start after A1 (never in
parallel with A2 on `_common.yaml`).

---

## 10. Out of Scope / Not This Round

- UX-03..UX-08 in the backlog (skill descriptions, lock reasons, HP numbers, creation
  attr effects) - next rounds' candidates, not this round's contract.
- Any change to damage / cooldown / turn-order numbers; any AI change; any art asset
  regeneration (if the probe shows a **missing texture file**, the fix is wiring the
  existing asset, not generating new art).
- Replacing the yellow move-target box visuals themselves (the START_EDGE marker stays
  as-is; the hint label adds the affordance around it).
- Occlusion via hover/GUI mouse queries (mouse-dependent, rejected in SOTA).
- Any new input action or rebind; RMB stays exactly as wired.
