## InputProbeOverlay — an on-screen answer to "where did that click go?".
##
## OFF unless the page URL carries ?debug=1, so the public build never shows it.
## It exists because the desktop build and the web build disagree and only the
## web build is broken: on the deployed page a menu button highlights on hover
## while a segment button, hovered at its visible centre, does not — and the
## battlefield ignores clicks entirely. Every hypothesis that could be checked
## from the source (a Control covering the board, the Camera2D, the segment
## CanvasLayer, the tutorial overlay, input gating) has been checked and cleared
## by a whole-tree census run in the desktop build, which is clean. What is left
## is the coordinate the WEB build actually delivers, and nothing on disk can
## tell us that.
##
## Reports, every frame:
##   vp     the viewport rect the game thinks it has
##   win    the real window size
##   last   the last press position as the game received it
##   grid   the tile that position resolves to
##   under  the topmost click-eating Control at that position, if any
extends Label

var _last_pos: Vector2 = Vector2(-1, -1)
var _last_kind: String = "-"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _debug_requested()
	set_process(visible)
	set_process_input(visible)


static func _debug_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	var q = JavaScriptBridge.eval("window.location.search", true)
	return q != null and str(q).contains("debug=1")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_last_pos = event.position
		_last_kind = "mouse%d" % event.button_index
	elif event is InputEventScreenTouch and event.pressed:
		_last_pos = event.position
		_last_kind = "touch"


func _process(_delta: float) -> void:
	var vp: Rect2 = get_viewport().get_visible_rect()
	var win: Vector2i = DisplayServer.window_get_size()
	var grid_txt: String = "-"
	if _last_pos.x >= 0.0:
		grid_txt = str(GridManager.world_to_grid(_last_pos))
	var under: String = "-"
	if _last_pos.x >= 0.0:
		var best: Control = null
		var stack: Array = [get_tree().root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is Control:
				var ctl := n as Control
				if ctl != self and ctl.is_visible_in_tree() \
						and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE \
						and ctl.get_global_rect().has_point(_last_pos):
					best = ctl
		if best != null:
			under = str(best.name)
	# The two numbers that settle it: raw = presses that reached the player node
	# at all, handled = presses that got as far as handle_world_click. raw>0 with
	# handled==0 means something ate it in the GUI phase; both 0 means it never
	# reached the node.
	var raw: String = "-"
	var handled: String = "-"
	var pl = GameManager.get_player()
	if pl != null and is_instance_valid(pl):
		if "debug_input_events" in pl:
			raw = str(pl.debug_input_events)
		if "debug_click_events" in pl:
			handled = str(pl.debug_click_events)
	text = "vp %dx%d  win %dx%d\nlast %s %s -> grid %s\nunder %s\nraw %s  handled %s" % [
		int(vp.size.x), int(vp.size.y), win.x, win.y,
		_last_kind, str(_last_pos), grid_txt, under, raw, handled]
