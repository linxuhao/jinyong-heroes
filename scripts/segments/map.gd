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


func _ready() -> void:
	# Save-integrity fallback: a hand-edited or legacy save may carry an empty /
	# unknown map_node — never strand the player on a node with no neighbors.
	current_node_id = SaveManager.profile.map_node
	if current_node_id == "" or MapData.node_def(current_node_id).is_empty():
		current_node_id = MapData.start_node()
		SaveManager.profile.map_node = current_node_id
	focus_id = current_node_id
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if ended:
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
	_render()
	if MapData.is_end_node(current_node_id):
		ended = true
		if not SceneManager.pending_swap:
			GameManager.enter_segment("ENDING")
			return


func _render() -> void:
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
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
	text += "\n当前：%s\n\n左右/上下选择相邻去处，回车启程" % MapData.node_def(current_node_id).get("display_name", current_node_id)
	body.text = text
