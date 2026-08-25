## MoveHintLabel — state-following move-target affordance hint (UX-02).
##
## Self-driving poller (the proven MoveRangeHighlight pattern): resolves
## GameManager.get_player() fresh every frame, never stores the ref, recomputes
## its state / Chinese copy / position entirely from engine-owned fields
## (moves_left / undo_available / acted / grid_pos), and hides itself when the
## context is not a live, player-turned, tutorial battle with movement budget.
##
## Pure read-only observer: it never writes game state and never eats input
## (mouse_filter = IGNORE), so it cannot collide with click-move, right-click
## undo, or targeting. The affordance copy follows the move state machine in the
## SAME transition that locks the move — the hint must never promise an undo
## that no longer exists (the deleted "右键确认" mistake must not reappear):
##   idle       「左键点格移动 · 右键退回」
##   undo_ready 「右键退回起点 · 出手即确认」
##   committed  「已出手 · 移动已确认」
##
## The label lives in the HUD layer-10 / scale-1 space the floating HealthBars
## use, so GridManager.grid_to_world(...) pixels and the Label's global_position
## are the same coordinate space — no Node2D<->Control conversion.
extends Label

# ---------------------------------------------------------------------------
# Observable surface vars (playtest contract — names are verbatim)
# ---------------------------------------------------------------------------

## "hidden" | "idle" | "undo_ready" | "committed".
var state: String = "hidden"

## Player tile the hint is docked to; (-1,-1) while hidden.
var tile: Vector2i = Vector2i(-1, -1)

## Final clamped label center in viewport space.
var center: Vector2 = Vector2.ZERO

## Label rect fully inside the 960x704 viewport.
var in_viewport: bool = false

## 1px-inset overlap vs the player's floating HealthBar (debug extra, never the
## A-class contract; stays false when the bar node cannot be resolved).
var bar_overlap: bool = false

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Fallback label size while the Label has not laid out yet (the first frame
## reads size == Vector2(0,0) before the text settles).
const FALLBACK_SIZE: Vector2 = Vector2(200, 20)

## Below-the-feet docking offset: the name + health bar float ABOVE the sprite,
## so this slot is empty and the hint adds no occlusion.
const FEET_OFFSET: Vector2 = Vector2(0, 44)

func _ready() -> void:
	# Hard requirement: the hint must never eat the click-move / right-click
	# undo / targeting events. Label is not focusable by default, so focus_mode
	# needs no explicit change (that discipline applies to clickable Controls).
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		_hide()
		return
	if GameManager.get_state() != GameManager.STATE_BATTLE:
		_hide()
		return
	if not CombatManager.is_player_turn():
		_hide()
		return
	if player.moves_left <= 0:
		_hide()
		return
	# Tutorial-only affordance: the move-target box lives in the tutorial battle.
	# Defensive read of the autoload bool (a plain property, not a constant).
	if not CombatManager.get("tutorial_battle"):
		_hide()
		return

	# State machine — pure function of engine-owned fields, first match wins.
	# `acted` (engine-written on a successful action) commits the move and locks
	# undo; `undo_available` (recomputed per frame by the player) means moved but
	# not yet committed.
	if player.acted:
		state = "committed"
		text = "已出手 · 移动已确认"
	elif player.undo_available:
		state = "undo_ready"
		text = "右键退回起点 · 出手即确认"
	else:
		state = "idle"
		text = "左键点格移动 · 右键退回"

	visible = true

	# Position: below the player's feet, above the tile edge, same scale-1
	# world space as grid_to_world.
	var world_pos: Vector2 = GridManager.grid_to_world(player.grid_pos)
	center = world_pos + FEET_OFFSET

	# Clamp into the viewport so the hint never drifts off-frame. Use the
	# fallback while the Label's own size is still (0,0) pre-layout.
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var label_size: Vector2 = size if size.length() > 0.0 else FALLBACK_SIZE
	var half: Vector2 = label_size / 2.0
	center.x = clamp(center.x, vp_rect.position.x + half.x,
		vp_rect.position.x + vp_rect.size.x - half.x)
	center.y = clamp(center.y, vp_rect.position.y + half.y,
		vp_rect.position.y + vp_rect.size.y - half.y)

	global_position = center - size / 2.0

	in_viewport = vp_rect.encloses(Rect2(global_position, size))
	tile = player.grid_pos

	# Debug extra: the per-unit floating bar lives in HUD/HealthBarContainer with
	# a composition-varying node path, so the lookup is defensive — if it cannot
	# be resolved the hint stays non-overlapping (the bar floats ABOVE the sprite
	# while this label sits below the feet, so overlap is false on every shown
	# frame by construction).
	var health_bar = get_node_or_null("HealthBar")
	if health_bar != null and is_instance_valid(health_bar):
		var bar_rect: Rect2 = Rect2(health_bar.global_position, health_bar.size)
		bar_overlap = Rect2(global_position, size).intersects(bar_rect, false)
	else:
		bar_overlap = false

## Hide the hint and reset the contract observables. Sole writer of
## visible = false; the only place state returns to "hidden".
func _hide() -> void:
	state = "hidden"
	visible = false
	text = ""
