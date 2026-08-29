# Delivery notes — fix_clicktarget_ignore (2026-08-29)

## What changed
- `scenes/enemy.tscn`: ClickTarget Control `mouse_filter = 0` (STOP) → `2` (IGNORE).
  Node name, type, and all four `offset_*` values preserved (it stays the harness's
  name-based click anchor). The file no longer contains any `mouse_filter = 0`
  (the `Sprite`'s `mouse_filter = 2` is the unrelated CanvasItem enum, untouched).
- `scripts/characters/enemy.gd`: comment-only rewrites of three blocks whose prose
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
  Zero logic changes; `debug_click_target_fires` still appears exactly twice
  (declaration + self-increment). The `gui_input` connect, the `_input` relay, and
  `player.handle_world_click(_click_target.get_global_rect().get_center())` are
  untouched.
- `playtest/input_click_differential.yaml`: prose-only rewrite of the header leg
  (c), the NOTE block, and `description:` to the measured facts. All 11 assertions,
  both earlier `clicks:` lines, and all `at:` frame numbers are verbatim.

## Documented deviation (one line, measured cause)
The leg-(c) click target changed from `Central_Divine_ClickTarget` to
`Central_Divine`. **Cause (measured by play-testing the staged change):** the
playtest harness hard-fails ("aim: node has mouse_filter=IGNORE (cannot be hit)")
when asked to aim a click at a Control whose `mouse_filter = IGNORE`. With the
ClickTarget now IGNORE by design, `Central_Divine_ClickTarget` can no longer be a
Control aim. The enemy Node2D `Central_Divine` is the equivalent anchor — its
origin (`get_global_transform_with_canvas().origin`) is the exact same world point
as the ClickTarget's rect centre (the enemy's feet), and the harness aims Node2D
anchors without a mouse_filter guard. **No assertion was weakened or removed**;
leg (c) still proves the same game-level facts: the `_input` relay routes an
enemy-tile click (`Player.debug_click_events: changed`) while the IGNORE ClickTarget
never fires (`Central_Divine.debug_click_target_fires == 0`), out of reach → silent
no-op (`acted == false`, grid unchanged).

## Measured result (godot_playtest_scenario, staged files applied)
`input_click_differential` → **13/13 PASS** (hard gate True).
- The previously-red `Central_Divine.debug_click_target_fires == 0` assertion is
  now green (observed 0, the IGNORE counter never increments).
- All other assertions green (legs (a)/(b) untouched, out-of-reach no-op intact).

## Out of scope (not touched)
`playtest/_common.yaml`, `scripts/ui/move_hint_label.gd`, `scripts/camera_follower.gd`,
`scripts/characters/player.gd`, the frozen acceptance-net yamls, `tests/*.py`,
`design/*.md`. No new UI strings (no `text = ` / i18n impact).
