# MoveHintLabel — A/B Probe Notes (observed, not assumed)

**Task:** `move_hint_label_and_affordance_scenario` (B1) — the state-following
move-target affordance hint (UX-02): a new `MoveHintLabel` Label below the
player's feet whose Chinese copy follows the move state machine
(`idle` 左键点格移动 · 右键退回 → `undo_ready` 右键退回起点 · 出手即确认 →
`committed` 已出手 · 移动已确认), plus the `playtest/move_target_affordance.yaml`
scenario that pins the copy in both the pending and the committed states.

## A-class (pre-fix) — the strongest possible red

| Fact | Observed pre-fix | Why it is red |
|---|---|---|
| `MoveHintLabel` node exists in `scenes/ui/hud.tscn` | **absent** — no node named `MoveHintLabel` anywhere in the scene file (grep-verifiable: the node, its script and the `[ext_resource]` are all missing) | The playtest harness resolves surface targets by bare name; a nonexistent node makes every `MoveHintLabel.*` assert a **hard red** ("node not found"), so the A-class proof *cannot* be false at baseline. |
| `MoveHintLabel.state` | — (node absent) | unresolvable target → hard red |
| `MoveHintLabel.text` | — (node absent) | unresolvable target → hard red |

Pre-fix the whole `move_target_affordance.yaml` scenario is red by construction;
post-fix the first green run is the measured confirmation. This is the "surface
target unresolved" A-class the plan calls the strongest kind — it needs no
runtime observation because the node's absence is structural.

## Probe method

The scenario frame timings were **not re-derived**: they reuse the proven
numbers from `playtest/click_move_undo_right.yaml` (walk click f70 → settled
f130; undo click f135 → settled f170) and `playtest/click_move_commit_lock.yaml`
(walk then `Central_Divine_ClickTarget` attack, execute latency 40 frames).
Sequence in the final scenario:

1. boot 7× `ui_accept` (f3..15) → 3× `tutorial_next` (f20/25/30)
2. **f45** — turn start, nothing moved → `state == "idle"`,
   `text.contains("左键")`, `visible == true`, `in_viewport == true`
3. **f70** click `Player +0,-192` → **f130** settled at (7,2) →
   `state == "undo_ready"`, `text.contains("右键")`, `bar_overlap == false`
4. **f135** click `Player +0,0 right` (real right-button undo) → **f170** back
   at (7,5) → `state == "idle"` (promise follows the state back)
5. **f175** click `Player +0,-192` again → **f230** (7,2) → `undo_ready`
6. **f235** click `Central_Divine_ClickTarget` (adjacent at (7,1)) → **f290**
   `Player.acted == true`, `undo_available == false`, `state == "committed"`,
   `text.contains("已出手")`, `visible == true`

## Post-fix expected readings (state → text → visible)

| State | Trigger (engine-owned) | text | visible |
|---|---|---|---|
| `hidden` | no player / not `STATE_BATTLE` / not player turn / `moves_left <= 0` / not tutorial | `""` | false |
| `idle` | player turn, `undo_available == false`, `acted == false` | `左键点格移动 · 右键退回` | true |
| `undo_ready` | `undo_available == true` (moved, not committed) | `右键退回起点 · 出手即确认` | true |
| `committed` | `acted == true` (commit locks the move) | `已出手 · 移动已确认` | true |

The copy follows the state machine in the **same transition** that locks the
move — `committed` swaps the text instead of hiding the label (a text swap also
proves the *promise* changed, not just that something disappeared), and the
`idle` return after undo (f170) pins that the promise follows the state **back**.

## Derived vs observed

| Fact | Derived | Observed |
|---|---|---|
| A-class: node absent pre-fix | structural (grep `MoveHintLabel` in `hud.tscn`) | absent (no node, no ext_resource) |
| `state == "idle"` at f45 | `undo_available`/`acted` both false at turn start | pinned by the f45 assert |
| `state == "undo_ready"` at f130/f230 | `undo_available == true` after walking to (7,2) | pinned by the f130/f230 asserts |
| `state == "committed"` at f290 | `acted == true` after the click-to-attack | pinned by the f290 assert |
| `bar_overlap == false` at f130 | the bar floats ABOVE the sprite, the hint sits BELOW the feet; the per-unit bar's node path is composition-varying so the defensive lookup keeps false | pinned by the f130 assert |

## Caveats / run notes

- The `HealthBar` overlap lookup is **defensive** (`get_node_or_null("HealthBar")`
  on the label — no such child exists, so `bar_overlap` stays `false`). It is a
  debug extra only: `state` / `text` / `visible` are the A-class contract. The
  scenario asserts `bar_overlap == false`, which holds by construction and never
  regresses.
- `CombatManager.tutorial_battle` is asserted by `battlefield.gd` at the end of
  the tutorial branch and stays `true` through the tutorial battle, so the
  tutorial-only guard keeps the hint visible for the whole scenario.
- Encoding: all Chinese copy is UTF-8 (repo convention).
- Input safety: `mouse_filter = 2` (IGNORE), no `gui_input`/`_input` handlers →
  the hint cannot eat click-move / right-click undo / targeting; no new input
  action or rebind — RMB stays exactly as wired.
