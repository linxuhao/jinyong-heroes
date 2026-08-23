## RoundIndicator — Top-center HUD widget showing the current round, the
## active actor, and the initiative order snapshot for the current round.
## All rendered text is Chinese (design §2.1 display layer); identity names
## (CombatManager.active_unit_name / turn_order) stay English. Refreshed
## every frame by hud.gd.
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

## Full ActiveLine string for the current frame, e.g.
## "行动: 杨过 · 移动 4 · 行动 ✓". Written by update_display every frame
## (outside the label-null guard) so the playtest surface stays live even if
## the ActiveLabel node is missing. "✓" = U+2713; "·" = U+00B7.
var active_text: String = ""

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _round_label: Label = $RoundLabel
@onready var _active_label: Label = $ActiveLabel
@onready var _order_label: Label = $OrderLabel

## Compact initiative-order tokens for the OrderLabel (display only). The
## `order_names` observable keeps the full canonical names — playtest asserts
## depend on them. Unknown names pass through unchanged.
const _ORDER_TOKENS := {
	"Yang Guo": "杨过",
	"East Heretic": "黄药师",
	"Central Divine": "王重阳",
	"South Emperor": "段智兴",
	"North Beggar": "洪七公",
	"West Poison": "欧阳锋",
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Map a canonical character name to its compact order token; unknown names
## are returned unchanged (fallback names like "Player"/"Enemy" unaffected).
func _token_for(name: String) -> String:
	return _ORDER_TOKENS.get(name, name)

## Build the ActiveLabel text from CombatManager.active_unit_name + the
## player's moves_left/acted. Null-safe pre-battle fallback "行动: <actor>"
## only. "✓" (U+2713) is mandated verbatim by the task card; "·" (U+00B7) is
## Latin-1 and covered by the default font.
func _active_text(actor: String) -> String:
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return "行动: %s" % actor
	# Defensive guards (task contract): a player node that lacks moves_left /
	# acted (e.g. a non-player scene) falls back to "Move 0 / End" instead of
	# throwing on property access. `in` on an Object tests property existence.
	var moves_left: int = int(player.moves_left) if "moves_left" in player else 0
	var acted: bool = bool(player.acted) if "acted" in player else true
	return "行动: %s · 移动 %d · %s" % [
		actor,
		moves_left,
		("行动 ✓" if not acted else "结束"),
	]

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Refresh the indicator from the turn engine. Writes the observable state
## and the three child labels ("回合 %d", "行动: %s", "顺序: %s").
## Defensively resolves child labels via get_node_or_null (health_bar.gd
## pattern) so the method is call-order independent.
func update_display(round_num: int, actor: String, order: Array[String]) -> void:
	current_round = round_num
	# Display layer: both the active_actor observable and the actor slot in
	# the active line map through _ORDER_TOKENS (fallback: identity) so the
	# whole active line is CJK-consistent (行动: 杨过 · 移动 4 · 行动 ✓).
	active_actor = _token_for(actor)
	order_names = order.duplicate()

	# Observable ActiveLine string — written unconditionally (outside the
	# label-null guard below) so the surface stays live even if the ActiveLabel
	# node is missing from the scene.
	active_text = _active_text(active_actor)

	var round_label: Label = _round_label
	if round_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		round_label = get_node_or_null("RoundLabel") as Label
		if round_label != null:
			_round_label = round_label
	if round_label != null:
		round_label.text = "回合 %d" % round_num

	var active_label: Label = _active_label
	if active_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		active_label = get_node_or_null("ActiveLabel") as Label
		if active_label != null:
			_active_label = active_label
	if active_label != null:
		active_label.text = active_text

	var order_label: Label = _order_label
	if order_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		order_label = get_node_or_null("OrderLabel") as Label
		if order_label != null:
			_order_label = order_label
	if order_label != null:
		# Compact token format (no clip/ellipsis) so the order line fits its
		# box and stays clear of the PauseButton. order_names keeps the full
		# canonical names above — tokenization is display-only.
		order_label.text = "顺序: %s" % " > ".join(order.map(_token_for))
