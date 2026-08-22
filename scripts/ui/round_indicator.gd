## RoundIndicator — Top-center HUD widget showing the current round, the
## active actor, and the initiative order snapshot for the current round.
## All text is English + digits only. Refreshed every frame by hud.gd.
extends Control

# ---------------------------------------------------------------------------
# State (observable surface)
# ---------------------------------------------------------------------------

## The current round number (0 before the battle starts).
var current_round: int = 0

## Name of the unit whose turn is active ("" while idle).
var active_actor: String = ""

## Initiative order snapshot for the current round (names, first to act).
var order_names: Array[String] = []

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _round_label: Label = $RoundLabel
@onready var _active_label: Label = $ActiveLabel
@onready var _order_label: Label = $OrderLabel

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Refresh the indicator from the turn engine. Writes the observable state
## and the three child labels ("Round %d", "Active: %s", "Order: %s").
## Defensively resolves child labels via get_node_or_null (health_bar.gd
## pattern) so the method is call-order independent.
func update_display(round_num: int, actor: String, order: Array[String]) -> void:
	current_round = round_num
	active_actor = actor
	order_names = order.duplicate()

	var round_label: Label = _round_label
	if round_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		round_label = get_node_or_null("RoundLabel") as Label
		if round_label != null:
			_round_label = round_label
	if round_label != null:
		round_label.text = "Round %d" % round_num

	var active_label: Label = _active_label
	if active_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		active_label = get_node_or_null("ActiveLabel") as Label
		if active_label != null:
			_active_label = active_label
	if active_label != null:
		active_label.text = "Active: %s" % actor

	var order_label: Label = _order_label
	if order_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		order_label = get_node_or_null("OrderLabel") as Label
		if order_label != null:
			_order_label = order_label
	if order_label != null:
		order_label.text = "Order: %s" % ", ".join(order)
