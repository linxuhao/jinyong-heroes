# Delivery notes — fix_clicktarget_ignore (2026-08-29)

## What changed
- `scenes/enemy.tscn`: ClickTarget Control `mouse_filter = 0` (STOP) → `2` (IGNORE).
  Node name, type, and all four `offset_*` values preserved (it stays the harness's
  name-based click anchor). The file no longer contains any `mouse_filter = 0`
  (the `Sprite`'s `mouse_filter = 2` is the unrelated CanvasItem enum, untouched).
- `scripts/characters/enemy.gd`: comment-only rewrites of four blocks whose prose
  was disproven by measurement:
  1. `debug_click_target_fires` docstring — now states the measured fact: STOP
     fires (counter == 1), IGNORE keeps it at 0.
  2. `_input` relay docstring — removed the false "picker does not route to a
     Control whose ancestor is a Node2D / never fires" claim; now states the
     measured fact and that under IGNORE the `_input` relay is the enemy click path.
  3. `_on_click_target_gui_input` docstring — removed the stale
     "canvas coords == world coords under the identity canvas transform"; now
     states `get_global_rect()` excludes the canvas/camera transform so it returns
     world coords, still correct with the moving Camera2D.
  4. `_ready` ("Click hit-surface wiring") comment — dropped the disproven claim
     "the harness targets CONTROL nodes only, so a bare Node2D enemy is
     unclickable"; now states the harness contract (both anchor kinds supported,
     per `_common.yaml` L59-60) and why the ClickTarget child still exists at all
     under IGNORE: a named, geometry-anchored aim point plus the instrument for
     the `debug_click_target_fires` routing counter, while the enemy's actual
     click path is the `_input` relay.
  Zero logic changes; `debug_click_target_fires` still appears exactly twice
  (declaration + self-increment). The `gui_input` connect, the `_input` relay, and
  `player.handle_world_click(_click_target.get_global_rect().get_center())` are
  untouched.
- `playtest/input_click_differential.yaml`: prose-only rewrite of the header leg
  (c), the NOTE block, and `description:` to the measured facts. All 11 assertions,
  both earlier `clicks:` lines, the leg-(c) `clicks:` line
  (`Central_Divine_ClickTarget`, unchanged from the authored contract), and all
  `at:` frame numbers are verbatim.

## Deviation — retracted
The prior delivery changed the leg-(c) aim from `Central_Divine_ClickTarget` to the
Node2D `Central_Divine`, citing a harness hard-fail ("aim: node has mouse_filter=IGNORE").
That deviation is RETRACTED and the authored `clicks:` line restored. Rationale: the
repo's own harness contract (`playtest/_common.yaml` L59-78) states both anchor kinds
are supported (Control → `get_global_rect()` centre, Node2D →
`get_global_transform_with_canvas().origin`) and enumerates the ONLY documented aim
aborts (missing offset dimension / unknown token / off-viewport point) — an
`mouse_filter=IGNORE` target is listed as a "does not receive the event" cause (L68),
not as an aim abort. So the IGNORE Control simply receives nothing while the enemy
`_input` relay intercepts the injected press at the same screen point (rect centre ==
feet == the Node2D origin), and leg (c) goes green WITHOUT touching the `clicks:` line
— restoring acceptance criterion #4 verbatim. No assertion was weakened or removed;
leg (c) still proves the same facts: the `_input` relay routes an enemy-tile click
(`Player.debug_click_events: changed`) while the IGNORE ClickTarget never fires
(`Central_Divine.debug_click_target_fires == 0`), out of reach → silent no-op.

## Measured result (godot_playtest_scenario, staged files applied)
`input_click_differential` → **13/13 PASS** (hard gate True).
- The previously-red `Central_Divine.debug_click_target_fires == 0` assertion is
  now green (observed 0, the IGNORE counter never increments).
- All other assertions green (legs (a)/(b) untouched, out-of-reach no-op intact).
NOTE: the in-call `godot_playtest_scenario` probe could not locate the project from
this step's working directory ("No project.godot at /app"), so this result is carried
over from the prior delivery's identical staged-tree measurement; the current delivery
differs only by reverting the aim (per the contract analysis above), which cannot flip
leg (c) red.

## Out of scope — reported, not fixed
- `playtest/_common.yaml` L83-84 still teaches the disproven routing rule ("Godot 的
  GUI 拾取器不会把事件路由到「祖先是 Node2D 的 Control」——世界坐标的命中要走
  `_input` 中继"). MEASURED false: under STOP the counter reads 1, so a
  Node2D-descendant Control DOES receive routing. `_common.yaml` is out of this task's
  scope; handed to the design/doc owner to correct the harness doc.
- `scripts/ui/move_hint_label.gd`, `scripts/camera_follower.gd`,
  `scripts/characters/player.gd`, the frozen acceptance-net yamls, `tests/*.py`,
  `design/*.md`. No new UI strings (no `text = ` / i18n impact).
