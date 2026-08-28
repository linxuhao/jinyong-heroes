## MapScreen — segment 6: the 6-node travel map.
## Focus cycles the adjacency list of the current node (move_right/up next,
## move_left/down previous, wrapping); ui_accept travels ONLY when the focused
## node is actually adjacent (MapData.is_adjacent — adjacency-validated, not
## just distance). Reaching the end node 昆仑 routes to ENDING.
extends Control

## Mainline for auto-select when focus sits on the current node (design §8.7).
const MAINLINE: Array[String] = ["wuming_valley", "luoyang", "wudang", "xiangyang", "kunlun"]

## Surface: the node the player is currently at.
var current_node_id: String = "wuming_valley"

## Surface: the node currently focused (adjacent to current_node_id).
var focus_id: String = "wuming_valley"

## Surface: true after the end node routed to ENDING.
var ended: bool = false

## Node-entry content phase (design/20_content.md §8): "TRAVEL" is the existing
## focus/travel flow; "EVENT" while a modal node-entry event is up. A node whose
## event slot is not "active" never enters EVENT — byte-identical TRAVEL behavior.
var phase: String = "TRAVEL"

## Surface: id of the active node-entry event ("" when none is up).
var event_id: String = ""

## Surface: which event option the ▶ marks (0 = option_a, 1 = option_b).
var event_focus: int = 0

## Surface: battle_id of the node-entry battle this arrival started ("" when the
## node has no live battle slot). Written before the state change, so a reader
## that catches the frame still sees which encounter was entered.
var entry_battle_id: String = ""

## Surface: declared-but-unimplemented entry-content slot types at the current
## node (the honesty observable — gaps are assertable, not just documented).
var entry_declared_gap_types: Array[String] = []

## Profile mirrors (differential playtest asserts — before/after, never literals).
var silver: int = 0
var attr_bone: int = 10
var attr_inner: int = 10
var attr_agility: int = 10
var attr_wisdom: int = 10
var attr_fortune: int = 10

## Surface: effect "type"s of the last resolved node-event option, in order.
var last_effect_types: Array[String] = []

## Surface: session count of resolved node-entry events (ladder 0 -> 1, ...).
var events_resolved_count: int = 0


func _ready() -> void:
	# Save-integrity fallback: a hand-edited or legacy save may carry an empty /
	# unknown map_node — never strand the player on a node with no neighbors.
	current_node_id = SaveManager.profile.map_node
	if current_node_id == "" or MapData.node_def(current_node_id).is_empty():
		current_node_id = MapData.start_node()
		SaveManager.profile.map_node = current_node_id
	focus_id = current_node_id
	_sync_surface()
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if ended:
		return
	if phase == "EVENT":
		if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
			get_viewport().set_input_as_handled()
			event_focus = 0
			_render()
		elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
			get_viewport().set_input_as_handled()
			event_focus = 1
			_render()
		elif event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_resolve_node_event()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_travel()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_cycle_focus(1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_cycle_focus(-1)


func _cycle_focus(dir: int) -> void:
	var nbrs: Array[String] = MapData.neighbors(current_node_id)
	if nbrs.is_empty():
		return
	if focus_id == current_node_id:
		# Focus sits on the current node: forward (+1) auto-selects the mainline
		# successor so move_right advances the story (falling back to the first
		# neighbor when the successor is not adjacent); backward (-1) wraps to
		# the LAST neighbor. Both directions stay inside the adjacency list.
		var mi: int = MAINLINE.find(current_node_id)
		if dir > 0 and mi >= 0 and mi < MAINLINE.size() - 1 and MapData.is_adjacent(current_node_id, MAINLINE[mi + 1]):
			focus_id = MAINLINE[mi + 1]
		elif dir > 0:
			focus_id = nbrs[0]
		else:
			focus_id = nbrs[nbrs.size() - 1]
		_render()
		return
	var idx: int = nbrs.find(focus_id)
	if idx == -1:
		focus_id = nbrs[0]
	else:
		focus_id = nbrs[(idx + dir + nbrs.size()) % nbrs.size()]
	_render()


func _travel() -> void:
	if focus_id == current_node_id:
		return
	if not MapData.is_adjacent(current_node_id, focus_id):
		return
	current_node_id = focus_id
	SaveManager.profile.map_node = current_node_id
	SaveManager.autosave()
	_sync_surface()
	if MapData.is_end_node(current_node_id):
		ended = true
		if not SceneManager.pending_swap:
			GameManager.enter_segment("ENDING")
			return
	_maybe_start_entry_event()
	if phase != "EVENT":
		_maybe_start_entry_battle()
	_render()


## Start the node-entry event for the current node, if its event slot is active.
## Fires ONLY on arrival by travel (called from _travel) — never on boot/load, so
## a save→load at an active node does not re-trigger (save_load_roundtrip stays
## green). End-node routing already ran first, so node content never blocks the
## ending.
func _maybe_start_entry_event() -> void:
	var eid: String = MapData.active_event_id(current_node_id)
	if eid == "":
		return
	phase = "EVENT"
	event_id = eid
	event_focus = 0
	_sync_surface()
	_render()


## Start the node-entry battle for the current node, if its battle slot is live.
##
## Fires ONLY on arrival by travel, and ONLY when no node-entry event opened
## first. A node carrying both an active event and an active battle would need a
## precedence rule; there is no such node today (华山, the only live battle slot,
## has no event), so this guard states that invariant rather than choosing a
## winner. If one is ever authored, the rule belongs in the design file first.
##
## End-node routing has already run in _travel() by the time this is called, so
## a battle can no more block the ending than an event can.
func _maybe_start_entry_battle() -> void:
	var bid: String = MapData.active_battle_id(current_node_id)
	if bid == "":
		return
	entry_battle_id = bid
	_sync_surface()
	GameManager.start_map_battle()


## Resolve the modal node-event: pick the option by event_focus, apply its effects
## through the shared EventLogic path, and return to TRAVEL. Deterministic binding
## channel — does NOT read/write flags["events_seen"] (bag independence).
func _resolve_node_event() -> void:
	var def = EventData.def(event_id)
	if def == null:
		phase = "TRAVEL"
		event_id = ""
		_render()
		return
	var opt = def.option_a if event_focus == 0 else def.option_b
	last_effect_types = []
	for eff in opt.effects:
		last_effect_types.append(eff.get("type", "none") as String)
	EventLogic.apply_option_effects(SaveManager.profile, opt)
	events_resolved_count += 1
	event_id = ""
	phase = "TRAVEL"
	SaveManager.autosave()
	_sync_surface()
	_render()


## Mirror the profile + node content state into the playtest surface observables.
func _sync_surface() -> void:
	silver = SaveManager.profile.silver
	attr_bone = SaveManager.profile.get_attr("bone")
	attr_inner = SaveManager.profile.get_attr("inner")
	attr_agility = SaveManager.profile.get_attr("agility")
	attr_wisdom = SaveManager.profile.get_attr("wisdom")
	attr_fortune = SaveManager.profile.get_attr("fortune")
	entry_declared_gap_types = MapData.declared_gap_types(current_node_id)


## Single-operation-hint invariant: the bottom travel hint is the map's own
## promise ("左右/上下选择相邻去处，回车启程") and must NOT survive into a modal event panel
## that asks for 上下选择. The event panel's own prompt is the only hint that may
## show while phase == "EVENT"; the travel hint is restored whenever phase is
## anything else (TRAVEL today, and any future phase) so it can never silently
## re-promise travel while the player is not in the travel flow. hint.text is the
## static scene text and is never touched here — visibility toggling is the whole
## fix.
func _apply_hint_visibility() -> void:
	var hint: Label = get_node_or_null("HintLabel") as Label
	if hint == null:
		return
	hint.visible = phase != "EVENT"


func _render() -> void:
	_apply_hint_visibility()
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
		return
	if phase == "EVENT":
		var def = EventData.def(event_id)
		if def == null:
			body.text = ""
			return
		var ea = "▶ %s" % def.option_a.label if event_focus == 0 else "  %s" % def.option_a.label
		var eb = "▶ %s" % def.option_b.label if event_focus == 1 else "  %s" % def.option_b.label
		body.text = "【%s】\n\n%s\n\n%s\n%s\n\n上下选择，回车定夺" % [def.title, def.text, ea, eb]
		return
	var text: String = "【江湖行路】\n\n"
	for node in MapData.node_ids():
		var name: String = MapData.node_def(node).get("display_name", node)
		if node == current_node_id:
			text += "▶ %s（此处）\n" % name
		elif node == focus_id:
			text += "  %s（可前往）\n" % name
		else:
			text += "  %s\n" % name
	# The operation hint lives in ONE place: the footer HintLabel, whose
	# visibility _apply_hint_visibility() already drives per phase. It used to be
	# printed here as well, so the TRAVEL screen showed the identical sentence
	# twice — the panel line and the footer, both reading
	# 「左右/上下选择相邻去处，回车启程」. Unifying the two texts (2026-08-27) made
	# them byte-identical and turned a near-duplicate into an exact one; the
	# single-hint invariant this file documents above wants one, not two.
	text += "\n当前：%s" % MapData.node_def(current_node_id).get("display_name", current_node_id)
	body.text = text
