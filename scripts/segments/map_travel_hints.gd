## MapTravelHints — C1 node-type hint + C3 ending-travel gate for the map screen.
##
## Self-driving poller (the proven MoveHintLabel pattern): it resolves its host
## MapScreen node fresh EVERY frame via get_parent(), never stores the ref, and
## reads ONLY the host's public vars (current_node_id / focus_id / phase / ended)
## plus MapData's public static accessors. It never writes host state and never
## calls map.gd private methods — so it cannot corrupt travel. If a future round
## renames those public vars the sibling degrades to "no hint, no gate" (null
## guards), which is the documented, accepted coupling trade-off (locked map.gd
## cannot declare these surface observables, so they live HERE, on the sibling —
## recorded in the delivery notes as the surface-key resolution deviation).
##
## C1 (node-type hint): each frame, classify the focused neighbor (is_end_node ->
## 此去即结局; active_battle_id -> 战斗; active_facility_id -> 门派设施;
## active_event_id -> 事件) and render one line 「<node name> — <type>」 into
## TravelHintLabel. This is a consequence line (what this road gives), NOT a
## second operation hint — the existing footer HintLabel is untouched.
##
## C3 (ending gate): when the current node has an end-node neighbor (昆仑) in
## TRAVEL, a shield covers that visible TravelButton so the first press opens a
## confirm dialog ("此去即结局：…") instead of traveling. 确认启程 hides the dialog
## and re-dispatches the covered button's public `pressed` signal exactly once
## (no map.gd private call); 返回 closes it with zero delta. The shield REARMS
## every frame it is still armed — cancel never leaves a press-travels-directly
## path. The gate is INERT for every non-end neighbor (the shaolin-event /
## huashan-battle / facility verbatim legs never see it).
##
## KEYBOARD PATH — best-effort-DEFERRED, intentionally NOT implemented as a
## block (VERDICT_B, measured 2026-09-03): child-before-parent input ordering is
## true, but child-blocks-parent is FALSE — `set_input_as_handled()` from the
## child does not suppress the parent's `_unhandled_input` in the same dispatch.
## A keyboard confirm-open would therefore ALSO let map.gd's `_travel()` run the
## same frame, popping this dialog over the ending scene (a broken state). So the
## sibling consumes NO keyboard input at all this round; the ending gate is
## CLICK-ONLY (mouse shield + confirm panel). This C3 deviation is flagged in the
## delivery notes for 90_decisions / 40_ux_backlog to record honestly (the four
## keyboard kunlun legs remain ungated this round).
extends Control

const MapDataRef = preload("res://scripts/data/map_data.gd")

# ---------------------------------------------------------------------------
# Observable surface vars (playtest contract — names are verbatim; declared on
# the SIBLING, because locked map.gd cannot add them to MapScreen)
# ---------------------------------------------------------------------------

## The C1 node-type consequence line for the focused neighbor ("" when none).
var travel_hint_text: String = ""

## True while the confirm dialog is open (the interaction surface).
var travel_gate_visible: bool = false

## True while the shield is armed over an end-node travel button.
var travel_gate_armed: bool = false

## Index of the neighbor the gate is covering (-1 when disarmed).
var gate_button_index: int = -1

# ---------------------------------------------------------------------------
# Node references (resolved each frame — never stored across frames)
# ---------------------------------------------------------------------------

var _hint_label: Label = null
var _shield: Control = null
var _panel: Control = null
var _panel_body: Label = null
var _confirm_button: Button = null
var _back_button: Button = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = get_node_or_null("TravelHintLabel") as Label
	_shield = get_node_or_null("TravelGateShield") as Control
	_panel = get_node_or_null("TravelGatePanel") as Control
	_panel_body = get_node_or_null("TravelGatePanel/TravelGateDim/TravelGateBodyLabel") as Label
	_confirm_button = get_node_or_null("TravelGatePanel/TravelGateDim/TravelGateConfirmButton") as Button
	_back_button = get_node_or_null("TravelGatePanel/TravelGateDim/TravelGateBackButton") as Button
	if _shield != null:
		_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shield.visible = false
		_shield.gui_input.connect(_on_shield_gui_input)
	if _panel != null:
		_panel.visible = false
	if _confirm_button != null:
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)


## Resolve the host MapScreen fresh every frame; null when absent/dead.
func _host() -> Control:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent):
		return null
	if parent.get("current_node_id") == null:
		return null
	return parent as Control


func _process(_delta: float) -> void:
	_render_hint()
	_update_gate()


# ---------------------------------------------------------------------------
# C1 — node-type hint
# ---------------------------------------------------------------------------

func _render_hint() -> void:
	var host: Control = _host()
	if host == null or _hint_label == null:
		travel_hint_text = ""
		_hint_label.text = "" if _hint_label != null else ""
		_hint_label.visible = false if _hint_label != null else false
		return
	var target: String = _focused_neighbor(host)
	var line: String = _compose_hint(target)
	travel_hint_text = line
	_hint_label.text = line
	_hint_label.visible = line != ""


## The neighbor currently focused, "" when focus sits on the current node
## (map_hint_single's focus grammar: focus_id == current_node_id => no target).
func _focused_neighbor(host: Control) -> String:
	var focus: Variant = host.get("focus_id")
	var current: Variant = host.get("current_node_id")
	if typeof(focus) != TYPE_STRING or typeof(current) != TYPE_STRING:
		return ""
	if focus == "" or focus == current:
		return ""
	if not MapDataRef.is_adjacent(current as String, focus as String):
		return ""
	return focus as String


## Pure classifier: is_end_node -> 此去即结局; active battle -> 战斗;
## active facility -> 门派设施; active event -> 事件; unknown/empty -> "".
## Order mirrors design/20_content.md slot precedence (end routing precedes
## entry content; battle precedes facility/event, matching huashan = 战斗).
func _classify_node(id: String) -> String:
	if id == "" or MapDataRef.node_def(id).is_empty():
		return ""
	if MapDataRef.is_end_node(id):
		return tr("此去即结局")
	if MapDataRef.active_battle_id(id) != "":
		return tr("战斗")
	if MapDataRef.active_facility_id(id) != "":
		return tr("门派设施")
	if MapDataRef.active_event_id(id) != "":
		return tr("事件")
	return ""


func _compose_hint(node_id: String) -> String:
	if node_id == "":
		return ""
	var type_word: String = _classify_node(node_id)
	if type_word == "":
		return ""
	var name: String = str(MapDataRef.node_def(node_id).get("display_name", node_id))
	return tr("%s — %s") % [tr(name), type_word]


# ---------------------------------------------------------------------------
# C3 — ending-travel confirmation gate
# ---------------------------------------------------------------------------

## The gate state machine. armed := host in TRAVEL, not ended, and some neighbor
## i with is_end_node(neighbors(current_node_id)[i]) == true whose TravelButton{i}
## is visible. While armed the shield covers that button (STOP) unless the dialog
## is open (the dialog is then the interaction surface). Disarmed otherwise.
func _update_gate() -> void:
	var host: Control = _host()
	if host == null:
		_disarm()
		_close_panel()
		return
	if str(host.get("phase")) != "TRAVEL" or bool(host.get("ended")):
		_disarm()
		_close_panel()
		return
	var idx: int = _end_neighbor_button_index(host)
	if idx < 0:
		_disarm()
		_close_panel()
		return
	_arm(idx)
	if _panel != null and _panel.visible:
		# Dialog open: the dialog is the surface; shield paused.
		travel_gate_visible = true
		if _shield != null:
			_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		travel_gate_visible = false


## Index of the visible end-node travel button, or -1 when there is none. map.gd
## hides pool buttons whose neighbor index is out of range; a shield may never
## silently cover dead geometry, so visible == true is required.
func _end_neighbor_button_index(host: Control) -> int:
	var nbrs: Array = MapDataRef.neighbors(str(host.get("current_node_id")))
	for i in range(nbrs.size()):
		var nid: String = str(nbrs[i])
		if not MapDataRef.is_end_node(nid):
			continue
		var btn: Button = host.get_node_or_null("TravelBox/TravelButton%d" % i) as Button
		if btn == null or not btn.visible:
			continue
		return i
	return -1


func _arm(idx: int) -> void:
	gate_button_index = idx
	travel_gate_armed = true
	if _shield == null:
		return
	_shield.visible = true
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	# Match the covered button's GLOBAL rect exactly (shield is a child of the
	# same MapScreen root, so global == its own rect in the same space).
	var host: Control = _host()
	if host == null:
		return
	var btn: Button = host.get_node_or_null("TravelBox/TravelButton%d" % idx) as Button
	if btn == null:
		return
	var r: Rect2 = btn.get_global_rect()
	_shield.global_position = r.position
	_shield.size = r.size


func _disarm() -> void:
	gate_button_index = -1
	travel_gate_armed = false
	travel_gate_visible = false
	if _shield != null:
		_shield.visible = false
		_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_panel() -> void:
	if _panel == null:
		return
	var host: Control = _host()
	var nid: String = ""
	if host != null and gate_button_index >= 0:
		var nbrs: Array = MapDataRef.neighbors(str(host.get("current_node_id")))
		if gate_button_index < nbrs.size():
			nid = str(nbrs[gate_button_index])
	var name: String = str(MapDataRef.node_def(nid).get("display_name", nid))
	if _panel_body != null:
		_panel_body.text = tr("此去即结局：踏上%s后，江湖故事将落幕。") % tr(name)
	_panel.visible = true
	travel_gate_visible = true
	if _confirm_button != null:
		_confirm_button.grab_focus()


func _close_panel() -> void:
	if _panel != null:
		_panel.visible = false
	travel_gate_visible = false


## Mouse shield input. A click on the shield is the FIRST press on the end-node
## travel button — swallow it and open the confirm dialog; map.gd's
## _on_travel_pressed is never reached.
func _on_shield_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_panel()
		get_viewport().set_input_as_handled()


func _on_confirm_pressed() -> void:
	_close_panel()
	# Single documented re-dispatch of the covered button's PUBLIC signal; this
	# invokes map.gd's own _on_travel_pressed(i) exactly as a real click would.
	# Never a map.gd private-method call. The state machine REARMS the shield on
	# the next frame, so a second press is gated again.
	var host: Control = _host()
	if host != null and gate_button_index >= 0:
		var btn: Button = host.get_node_or_null("TravelBox/TravelButton%d" % gate_button_index) as Button
		if btn != null:
			btn.pressed.emit()


func _on_back_pressed() -> void:
	# Cancel: hide the dialog, zero state delta. The shield REARMS next frame —
	# a press after cancel must be gated again, never travel straight to the end.
	_close_panel()
