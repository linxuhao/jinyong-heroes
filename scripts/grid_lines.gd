## GridLines — Static grid-cell overlay
##
## Draws the 15x11 board's cell-boundary lines above the floor tiles and the
## SummitBackdrop painting so the board grid is clearly visible (design
## 30_presentation.md 可读性硬要求 item 1: 棋盘格子必须可见).
##
## Pure presentation: no logic, no _process. The overlay is static, so the
## single automatic first draw when the node enters the scene tree suffices —
## no queue_redraw() needed. `visible` semantics are the only interface
## (read by the playtest surface observable Battlefield.grid_lines_visible).
extends Node2D

# ---------------------------------------------------------------------------
# Constants (mirror battlefield.gd / GridManager values)
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 15
const GRID_HEIGHT: int = 11

## Semi-transparent dark ink for the interior cell boundaries.
const LINE_COLOR: Color = Color(0.1, 0.1, 0.12, 0.35)
## Slightly stronger ink for the outer border ring so the board edge reads.
const BORDER_COLOR: Color = Color(0.1, 0.1, 0.12, 0.6)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var board_w: float = GRID_WIDTH * TILE_SIZE
	var board_h: float = GRID_HEIGHT * TILE_SIZE

	# Interior vertical lines (14) — one per cell boundary between columns.
	for x in range(1, GRID_WIDTH):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, board_h), LINE_COLOR, 1.0)

	# Interior horizontal lines (10) — one per cell boundary between rows.
	for y in range(1, GRID_HEIGHT):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(board_w, y * TILE_SIZE), LINE_COLOR, 1.0)

	# Outer border ring (unfilled outline, 2 px) so the board edge reads.
	draw_rect(Rect2(0, 0, board_w, board_h), BORDER_COLOR, false, 2.0)
