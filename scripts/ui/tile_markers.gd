## TileMarkers — ground marker overlay for every living unit
##
## Pure-presentation overlay that paints one flattened, low-alpha gold ellipse
## (with a thin gold outline) on the tile each living unit currently occupies,
## so the board keeps a readable "he stands here / click here" ground reference
## even after the health-bar/nameplate moves up to the portrait top (Defect B).
##
## Self-driving: polls GameManager.get_player() + GameManager.get_enemies_alive()
## every frame (never stores the refs), hides when there is no battle / no
## player, and recomputes the cached centre array + observables in _process
## (NOT in _draw) so the playtest surface is gradeable headless even on a frame
## where the renderer never ran.
##
## Click-inert by construction: this is a plain Node2D whose only output is
## _draw() ink — no Control, no mouse_filter, no gui_input anywhere in the
## subtree, so it can never swallow a board click (the Defect A failure mode).
##
## Measured draw-order facts (do not re-derive):
##  * A per-unit _draw() on the character itself runs BEFORE that unit's child
##    Sprite2D, so a feet marker drawn there is invisible for top-row units
##    whose clamped art is pushed down over their own feet. Hence this overlay
##    is mounted AFTER `Characters` in scenes/battlefield.tscn — the measured
##    route where all six markers (incl. top-row Central_Divine / West_Poison)
##    are visible.
##  * Honest top-row caveat: for top-row units the marker draws ON TOP of their
##    own robe ("ellipse on the robe") — the truthful statement "he stands
##    here" while the art hangs elsewhere. Low alpha + thin outline is what
##    keeps that presentable.
##  * We deliberately do NOT use `sprite.show_behind_parent = true`: that field
##    is read by scripts/ui/visibility_probe.gd as part of its draw-order
##    comparison, and flipping it would re-baseline portrait_visibility.yaml.
##
## The node dies with the battlefield scene on a swap — no manual teardown.
extends Node2D

# ---------------------------------------------------------------------------
# Constants (same literal the other overlays declare)
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64

## Ellipse semi-axis along x (< TILE_SIZE/2 so adjacent units' markers never
## merge into one blob — the 32px art overlap is accepted, marker overlap is not).
const MARKER_RX: float = 26.0

## Flattened vertical semi-axis -> reads as a ground mark, not an upright plate.
const MARKER_RY: float = 9.0

## Ring tessellation count (closed ellipse outline).
const MARKER_SEGMENTS: int = 24

## Marker centre pushed 2 px below the tile centre so it sits at the feet.
const MARKER_OFFSET_Y: float = 2.0

## Low-alpha gold fill. Alpha <= 0.20 keeps the 35%-alpha grid lines readable
## underneath (design readability hard rule #1 — same band that caps MOVE_FILL).
const MARKER_FILL: Color = Color(0.96, 0.82, 0.35, 0.16)
const MARKER_EDGE: Color = Color(0.97, 0.84, 0.40, 0.70)
const MARKER_EDGE_WIDTH: float = 1.0

# ---------------------------------------------------------------------------
# Observables (playtest surface contract)
# ---------------------------------------------------------------------------

## Number of living units with a drawn marker (0 when hidden). The ONLY writer
## is _process (via _collect_units / _hide) — never _draw.
var tile_marker_count: int = 0

## == (tile_marker_count > 0). Same writer rule as tile_marker_count.
var tile_marker_visible: bool = false

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Cached ellipse centres (world == screen px) for the current frame's living
## units, ordered player-first. Written only by _process; consumed only by _draw.
var _centres: Array[Vector2] = []

# ---------------------------------------------------------------------------
# Per-frame update
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Hide whenever there is no battle or no player. Poll every frame and never
	# store refs, so a mid-battle teardown / scene swap cannot leave stale data.
	if GameManager.get_state() != GameManager.STATE_BATTLE:
		_hide()
		return
	if not is_instance_valid(GameManager.get_player()):
		_hide()
		return

	var units: Array = _collect_units()
	_centres.clear()
	tile_marker_count = 0
	for unit in units:
		var grid_pos: Vector2i = unit.grid_pos
		# Bounds-guard BEFORE grid_to_world: skip the (-1,-1) sentinel and any
		# out-of-bounds tile so neither the count nor a drawn ring is polluted.
		if grid_pos.x < 0 or not GridManager.is_in_bounds(grid_pos):
			continue
		var centre: Vector2 = GridManager.grid_to_world(grid_pos)
		centre.y += MARKER_OFFSET_Y
		_centres.append(centre)
		tile_marker_count += 1

	tile_marker_visible = tile_marker_count > 0
	visible = tile_marker_visible
	queue_redraw()


## Hide the overlay and zero the observables. The ONLY writer of the zero state.
func _hide() -> void:
	visible = false
	tile_marker_count = 0
	tile_marker_visible = false
	_centres.clear()


## Collect the living units to mark, player-first: [player, enemies_alive...].
## GameManager.get_enemies_alive() already excludes the dead, so no extra
## health re-filter is needed beyond a defensive is_instance_valid guard — we
## never ADD a unit the arrays already exclude.
func _collect_units() -> Array:
	var units: Array = []
	var player = GameManager.get_player()
	if is_instance_valid(player):
		units.append(player)
	for enemy in GameManager.get_enemies_alive():
		if is_instance_valid(enemy):
			units.append(enemy)
	return units

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Render ONLY from the cached centres — this is a pure consumer of the
	# per-frame _process computation, never a writer of the observables.
	for centre in _centres:
		var ring: PackedVector2Array = _ring(centre)
		draw_colored_polygon(ring, MARKER_FILL)
		draw_polyline(ring, MARKER_EDGE, MARKER_EDGE_WIDTH, true)


## Build the closed ellipse ring centred at `centre` (first point repeated as
## the last so draw_polyline closes the outline).
func _ring(centre: Vector2) -> PackedVector2Array:
	var ring: PackedVector2Array = PackedVector2Array()
	var n: int = MARKER_SEGMENTS
	for i in range(n + 1):
		var a: float = TAU * float(i) / float(n)
		ring.append(centre + Vector2(cos(a) * MARKER_RX, sin(a) * MARKER_RY))
	return ring
