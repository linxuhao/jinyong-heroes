# Grid Rows Audit Notes — `grid_manager_board_rect_and_rows`

Date: 2026-08-28
Task: add `GridManager.board_rect()`; delete `MIN_LEGAL_ROW` constant and the
rows-0..2 unenterable branch in `is_walkable`. Clamp deletion is a SIBLING task.

## Residual sweep — `MIN_LEGAL_ROW`

`search "MIN_LEGAL_ROW"` across `scripts/`, `scenes/`, `playtest/`, `tests/` is
**zero hits** after this edit. Allowed hits remain only in historical prose
(`design/`, `step2_design.md`, this `final/` note).

- `scripts/autoload/grid_manager.gd` — the doc block + `const MIN_LEGAL_ROW`
  (L32-45) deleted; the rows-0..2 branch in `is_walkable` (L156-163) deleted.
- One live residual was found and cleared in this task: a `MIN_LEGAL_ROW`
  reference in a prose comment above the enemy spawn dict in
  `scripts/battlefield.gd` (L786 of the pre-edit file). The comment claimed a
  rows-0..2 unenterable rule that this task deleted, so it was a dangling
  dead-symbol reference. It has been rewritten (this task) to name no deleted
  constant and no minimum legal row; the `positions` dict values are frozen and
  handed to the spawn-restore sibling task. After that rewrite, the sweep is
  **zero hits** in `scripts/` + `scenes/` + `playtest/` + `tests/`.

## `is_walkable` new semantics (one line)

Walkable == in bounds AND not on the border ring (x/y at 0 or `GRID_*-1`);
legal rows are now `1..GRID_HEIGHT-2` (today 1..9), legal columns `1..GRID_WIDTH-2`.

## `board_rect()` today-substitution

`board_rect() = Rect2(Vector2.ZERO, Vector2(GRID_WIDTH*TILE_SIZE, GRID_HEIGHT*TILE_SIZE))`
- `size == Vector2(960, 704)` (15*64, 11*64)
- `end  == Vector2(960, 704)` (position + size)

Body references only the symbols `GRID_WIDTH` / `GRID_HEIGHT` / `TILE_SIZE` —
**no** `960 / 704 / 480 / 352` literal anywhere (cross-checked). This is the flat
evidence for the acceptance criteria 2/3.

## Walkthrough of `is_walkable` after deletion (no engine)

- `is_walkable((7,1))` — in bounds; x=7 not 0/14; y=1 not 0/10 → **true**
- `is_walkable((3,2))` — in bounds; not border → **true**
- `is_walkable((11,2))` — in bounds; not border → **true**
- `is_walkable((7,0))` — y==0 border → **false**
- `is_walkable((7,10))` — y==10 == GRID_HEIGHT-1 border → **false**
- `is_walkable((0,5))` — x==0 border → **false**
- `is_walkable((14,5))` — x==14 == GRID_WIDTH-1 border → **false**
- `is_walkable((7,11))` — out of bounds → **false**

## Clamp untouched (this task)

`clamp_sprite_offset` (grid_manager.gd) and `BOARD_TOP_MARGIN_Y` remain and
still reference each other (`clamp_sprite_offset` L182 uses `BOARD_TOP_MARGIN_Y`).
`player.gd` / `enemy.gd` `_refresh_sprite_clamp` not touched. `PORTRAIT_TEX_Y`,
occupancy, A*, `plan_movement`, AoE all untouched. The only diff in
`grid_manager.gd` is: added `board_rect()`, deleted the two MIN_LEGAL_ROW blocks.

## Risks — disposition

1. **Spawn-point coupling (highest).** Deleting `MIN_LEGAL_ROW` makes rows 1-2
   legal, but `scripts/battlefield.gd` L793-799 still spawns enemies at the
   clamp-era downward-shifted positions: East Heretic (3,4), West Poison (11,4),
   South Emperor (3,8), North Beggar (11,8), Central Divine (7,3). The brief
   restores Central Divine (7,1) / East Heretic (3,2) / West Poison (11,2) — that
   is a SIBLING task's edit, NOT this one. Intermediate state is legal but the
   formation is still the down-shifted version. Restoration derivation for the
   sibling: row-1 unit feet_y = `GRID_ORIGIN.y + TILE_SIZE*1` = 32+64 = 96; its
   unclamped ink top = 96 - 128 = -32 — the same numbers as `ink_world_dy`
   124 -> 0 in that task. **Owner: spawn-restore sibling task; this task does
   not touch the spawn dict.** This task DID rewrite the explanatory comment
   above the dict (it was a dangling `MIN_LEGAL_ROW` reference), but left the
   dict `positions` values themselves untouched.
2. **Dependent-yaml upper-bound asserts (report-only).** `playtest/movement_range_highlight.yaml`
   frame 85 asserts `Player.moves_left == 1` (3x move_up) and
   `MoveRangeHighlight.tile_count: changed`; `playtest/click_portrait_body_targets_enemy.yaml`
   (7,5)->(7,2) climb depends on whether row 2 is a legal landing. Rule: **do not
   edit yamls, do not loosen thresholds.** If any turns red under ONLY this
   task's change, report it here with the exact number + cause + whether the
   spawn-restore task turns it back green. No red is expected from this task in
   isolation (row 1-2 becoming legal only opens MORE tiles; it does not shrink an
   existing move range or move a click target).
3. **AStar static geometry.** `setup_grid()` disables points purely via
   `is_walkable`; deleting the branch auto-enables rows 1-2 points — no extra
   edit, no new hardcoded row numbers. `reserve_tile` / `free_tile` untouched
   (occupancy never toggles the graph; L205-208 contract preserved).

## Type / float notes

`GRID_ORIGIN` is `Vector2(32,32)` (float components); `GRID_WIDTH*TILE_SIZE` is
int, promoted through `Vector2(...)` to float. `Rect2` is all-float semantics.
Any future float comparison uses `is_equal_approx` / abs-diff <= 1, never `==`.

## i18n

No new/changed UI strings; `tests/test_i18n_coverage.py` unaffected.
