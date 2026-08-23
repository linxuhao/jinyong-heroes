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
## "行动: 杨过 · 移动 4 ···· · 行动 ✓" (move budget = digit + "·" pips).
## Written by update_display every frame (outside the label-null guard) so the
## playtest surface stays live even if the ActiveLabel node is missing.
## "✓" = U+2713; "·" = U+00B7.
var active_text: String = ""

## Highlight state of the ActiveLabel panel: "player" (bright panel, player's
## turn), "enemy" (dim panel) or "idle" (default theme, no player / pre-battle).
## Observable surface for Q4 — a turn/action-state change is visually distinct.
var highlight_state: String = ""

## Move-budget pips for the current frame, e.g. "····" for 4 moves left.
## "·".repeat(0) == "" — a zero-move frame renders no pips (never an error).
var move_pips: String = ""

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _round_label: Label = $RoundLabel
@onready var _active_label: Label = $ActiveLabel
@onready var _order_label: Label = $OrderLabel

## Cached StyleBoxFlat panels for the ActiveLabel turn highlight — built once
## in _ready, never per-frame (this is a hot _process path).
var _player_box: StyleBoxFlat
var _enemy_box: StyleBoxFlat

## Player-turn highlight colors (cached — Color is a value type, so local
## copies can be darkened for the "结束" state without touching these).
var _player_font_color: Color = Color(0.12, 0.09, 0.00, 1.0)
var _enemy_font_color: Color = Color(0.90, 0.90, 0.90, 1.0)

## Whether the active actor had already acted when _active_text last ran —
## darkens the highlight font so 行动 ✓ vs 结束 differ beyond the text itself.
var _last_acted: bool = false

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
# Init
# ---------------------------------------------------------------------------

## Build the two cached StyleBoxFlat panels once. Content margins inset the
## text inside the panel (desired here — unlike the health-bar track, which
## deliberately uses expand margins). Never allocate per frame.
func _ready() -> void:
	_player_box = StyleBoxFlat.new()
	_player_box.bg_color = Color(0.92, 0.75, 0.20, 1.0)
	_player_box.set_corner_radius_all(4)
	_player_box.set_content_margin_all(6.0)
	_enemy_box = StyleBoxFlat.new()
	_enemy_box.bg_color = Color(0.22, 0.22, 0.24, 1.0)
	_enemy_box.set_corner_radius_all(4)
	_enemy_box.set_content_margin_all(6.0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Map a canonical character name to its compact order token; unknown names
## are returned unchanged (fallback names like "Player"/"Enemy" unaffected).
func _token_for(name: String) -> String:
	return _ORDER_TOKENS.get(name, name)

## Build the ActiveLabel text from CombatManager.active_unit_name + the
## player's moves_left/acted. Null-safe pre-battle fallback "行动: <actor>"
## only. Format keeps the protected contract — contains "移动", ends with
## "行动 ✓" (U+2713); the move budget renders as a digit + "·" pips
## (move_pips = "·".repeat(moves_left)) so it visibly changes with each move.
func _active_text(actor: String) -> String:
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		move_pips = ""
		_last_acted = true
		return "行动: %s" % actor
	# Defensive guards (task contract): a player node that lacks moves_left /
	# acted (e.g. a non-player scene) falls back to "Move 0 / End" instead of
	# throwing on property access. `in` on an Object tests property existence.
	var moves_left: int = int(player.moves_left) if "moves_left" in player else 0
	var acted: bool = bool(player.acted) if "acted" in player else true
	_last_acted = acted
	move_pips = "·".repeat(moves_left)
	return "行动: %s · 移动 %d %s · %s" % [
		actor,
		moves_left,
		move_pips,
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
		# canonical names above — tokenization is display-only. The "·" (U+00B7)
		# separator is much narrower than the old ASCII arrow — all six names
		# fit at font 10.
		order_label.text = "顺序: %s" % "·".join(order.map(_token_for))

	_apply_turn_highlight()


## Apply the active-actor turn highlight to the ActiveLabel: bright panel for
## the player's turn, dim panel for enemy turns, default theme when no player
## exists (pre-battle: "idle"). Darkens the font color when the actor has
## already acted (结束) so the 行动 ✓ / 结束 state change is visually distinct
## beyond the text itself. Uses the two cached StyleBoxFlat instances — no
## per-frame allocation.
func _apply_turn_highlight() -> void:
	var active_label: Label = _active_label
	if active_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		active_label = get_node_or_null("ActiveLabel") as Label
		if active_label != null:
			_active_label = active_label
	var player: Node = GameManager.get_player()
	if active_label == null or player == null or not is_instance_valid(player) \
			or _player_box == null or _enemy_box == null:
		highlight_state = "idle"
		return
	# Guarded call — is_player_turn() may be absent in some code paths; fall
	# back to the dim (enemy) panel rather than throwing.
	var is_player: bool = CombatManager.has_method("is_player_turn") \
		and CombatManager.is_player_turn()
	var box: StyleBoxFlat = _player_box if is_player else _enemy_box
	var font_color: Color = _player_font_color if is_player else _enemy_font_color
	if _last_acted:
		# "结束" state — darken so the acted state reads differently from 行动 ✓.
		font_color = Color(
			font_color.r * 0.7, font_color.g * 0.7, font_color.b * 0.7,
			font_color.a)
	active_label.add_theme_stylebox_override("normal", box)
	active_label.add_theme_color_override("font_color", font_color)
	highlight_state = "player" if is_player else "enemy"
