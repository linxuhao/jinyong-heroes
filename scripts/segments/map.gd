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

## Surface: id of the active facility while in FACILITY phase ("" otherwise).
## The facility is entered ONLY by the explicit use_facility key in TRAVEL —
## never on arrival (that is the definitional event-vs-facility split).
var facility_id: String = ""

## Surface: session count of facility uses (ladder 0 -> 1 -> 2 ...; persists across
## visits because MapScreen stays loaded). Bounded only by the silver cost this round.
var facility_use_count: int = 0

## Surface: effect "type"s of the last facility use, in order (mirrors last_effect_types).
var last_facility_effect_types: Array[String] = []

## Render-only (NOT a surface var): true when the last use was refused for lack of
## silver — the FACILITY panel appends 银两不足 when set.
var _facility_refused: bool = false

## Debug injection: the granted silver = this multiple × the max facility silver cost
## (a RELATIVE expression, enough for at least two uses; deliberately NOT a tuned number).
const DEBUG_SILVER_GRANT_MULT := 4


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
	if phase == "FACILITY":
		# The facility modal: ui_accept USES (not travels); the directional leave
		# keys mirror the EVENT grammar. Direction keys here must NEVER leak into
		# travel — this branch returns regardless, so _cycle_focus/_travel are
		# unreachable while a facility is open.
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_use_facility()
		elif event.is_action_pressed("move_down") or event.is_action_pressed("move_left"):
			get_viewport().set_input_as_handled()
			_leave_facility()
		return
	if event.is_action_pressed("use_facility") and MapData.active_facility_id(current_node_id) != "":
		# The opt-in door: the player actively chooses to enter the node's facility.
		# ui_accept still travels (separate key, never a conflict).
		get_viewport().set_input_as_handled()
		_enter_facility()
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


## Enter the FACILITY phase for the current node (opt-in, from the use_facility key
## in TRAVEL). Does NOT auto-use — the player still must press ui_accept to actually
## use the facility, keeping "arrival/entry never uses" true.
func _enter_facility() -> void:
	facility_id = MapData.active_facility_id(current_node_id)
	phase = "FACILITY"
	_facility_refused = false
	_sync_surface()
	_render()


## Use the active facility: pay its silver cost (if affordable) and apply its effects
## through the SAME pure-static EventLogic path events use — zero new economy. The
## player STAYS in FACILITY, so they can use it again immediately or leave.
func _use_facility() -> void:
	var fdef = FacilityData.def(facility_id)
	if fdef == null:
		return
	var cost: int = FacilityData.silver_cost(fdef)
	if SaveManager.profile.silver < cost:
		# Refusal: no effect application, no count increment, no silver/attr change.
		_facility_refused = true
		_sync_surface()
		_render()
		return
	var opt = EventData.EventOption.new()
	opt.effects = fdef.effects.duplicate(true)
	EventLogic.apply_option_effects(SaveManager.profile, opt)
	last_facility_effect_types = []
	for eff in fdef.effects:
		last_facility_effect_types.append(eff.get("type", "none") as String)
	facility_use_count += 1
	_facility_refused = false
	SaveManager.autosave()
	_sync_surface()
	_render()


## Leave the FACILITY phase back to TRAVEL. The use count persists across visits.
func _leave_facility() -> void:
	facility_id = ""
	phase = "TRAVEL"
	_facility_refused = false
	_sync_surface()
	_render()


## Max silver cost across the facility pool; 0 when empty. Used only by the debug
## injection to express the grant RELATIVE to the cost (never a tuned literal).
func _max_facility_silver_cost() -> int:
	var max_cost: int = 0
	for fdef in FacilityData.all():
		var c: int = FacilityData.silver_cost(fdef)
		if c > max_cost:
			max_cost = c
	return max_cost


## Debug-only silver injection, routed THROUGH the normal pipeline (the same
## EventLogic.apply_option_effects path every event/card/facility silver effect takes —
## roadmap rule 2: injection must not bypass the code the player actually exercises).
## Never a bare profile.silver assignment.
func _debug_grant_silver() -> void:
	var opt = EventData.EventOption.new()
	opt.effects = [{"type": "silver", "value": DEBUG_SILVER_GRANT_MULT * _max_facility_silver_cost(), "target": ""}]
	EventLogic.apply_option_effects(SaveManager.profile, opt)
	_sync_surface()
	_render()


func _process(_delta: float) -> void:
	if ended:
		return
	if Input.is_action_pressed("debug_grant_silver"):
		_debug_grant_silver()


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
## that asks for 上下选择, nor into the FACILITY panel. The event/facility panel's own
## prompt is the only hint that may show while a modal is up; the travel hint is
## shown ONLY in TRAVEL (phase == "TRAVEL") so it can never silently re-promise
## travel while the player is in the event or facility flow. hint.text is the
## static scene text and is never touched here — visibility toggling is the whole
## fix.
func _apply_hint_visibility() -> void:
	var hint: Label = get_node_or_null("HintLabel") as Label
	if hint == null:
		return
	hint.visible = phase == "TRAVEL"


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
		var ea = "▶ %s" % tr(def.option_a.label) if event_focus == 0 else "  %s" % tr(def.option_a.label)
		var eb = "▶ %s" % tr(def.option_b.label) if event_focus == 1 else "  %s" % tr(def.option_b.label)
		body.text = tr("【%s】\n\n%s\n\n%s\n%s\n\n上下选择，回车定夺") % [tr(def.title), tr(def.text), ea, eb]
		return
	if phase == "FACILITY":
		var fdef = FacilityData.def(facility_id)
		if fdef == null:
			body.text = ""
			return
		var summary: String = _facility_effect_summary(fdef)
		body.text = tr("【%s】\n\n%s\n\n%s\n%s\n\n%s") % [tr(fdef.title), tr(fdef.text), summary, "▶ " + tr(fdef.action_label), tr("回车使用 · 上下离开")]
		if _facility_refused:
			body.text += tr("银两不足")
		return
	var text: String = tr("【江湖行路】\n\n")
	for node in MapData.node_ids():
		var name: String = tr(str(MapData.node_def(node).get("display_name", node)))
		if node == current_node_id:
			text += tr("▶ %s（此处）\n") % name
		elif node == focus_id:
			text += tr("  %s（可前往）\n") % name
		else:
			text += "  %s\n" % name
	# The operation hint lives in ONE place: the footer HintLabel, whose
	# visibility _apply_hint_visibility() already drives per phase. It used to be
	# printed here as well, so the TRAVEL screen showed the identical sentence
	# twice — the panel line and the footer, both reading
	# 「左右/上下选择相邻去处，回车启程」. Unifying the two texts (2026-08-27) made
	# them byte-identical and turned a near-duplicate into an exact one; the
	# single-hint invariant this file documents above wants one, not two.
	text += tr("\n当前：%s") % tr(str(MapData.node_def(current_node_id).get("display_name", current_node_id)))
	# Facility hint: let the player SEE the node has a usable facility and which key
	# enters it. The prose itself lives only in facility_data.gd (the §433 rule).
	var fid: String = MapData.active_facility_id(current_node_id)
	if fid != "":
		var fdef = FacilityData.def(fid)
		if fdef != null:
			text += tr("\n\n门派设施：%s（F 使用）") % tr(fdef.title)
	body.text = text


## Compose the cost/effect summary line for a facility from its effects (e.g.
## "银两 −8 · 根骨 +2"). Only silver-cost and attr-gain effects render; unknown
## attr targets fall back to a plain non-CJK "+N" marker (never reached by the
## current bone/inner-only facility pool).
func _facility_effect_summary(fdef) -> String:
	var parts: Array[String] = []
	for eff in fdef.effects:
		var etype: String = eff.get("type", "none") as String
		var value: int = eff.get("value", 0) as int
		if etype == "silver" and value < 0:
			parts.append(tr("银两 −%d") % absi(value))
		elif etype == "attr":
			var target: String = eff.get("target", "") as String
			if target == "inner":
				parts.append(tr("内力 +%d") % value)
			elif target == "bone":
				parts.append(tr("根骨 +%d") % value)
			else:
				parts.append("+%d" % value)
	return " · ".join(parts)
