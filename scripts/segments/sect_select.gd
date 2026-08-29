## SectSelectScreen — segment 4: pick one of the five sects.
## Pick sets profile.cultivation.sect_id and routes to CULTIVATION (the
## cultivation scene grants the sect's D-grade internal + external arts at
## year 1 month 1; the 孤煞 trait suppresses the internal grant).
extends Control

## Surface: focused sect row index (0..4, ProgressionGongfaData.SECTS order).
var focus_index: int = 0

## Surface: last picked sect id ("" until picked).
var selected_sect_id: String = ""

## Surface: button name -> pressed-signal wired.
var pressed_connected: Dictionary = {}


func _ready() -> void:
	_wire_sect_buttons()
	_render()


func _wire_sect_buttons() -> void:
	for i in 5:
		var btn: Button = get_node_or_null("SectButton%d" % i) as Button
		if btn == null:
			continue
		btn.pressed.connect(_on_sect_pressed.bind(i))
		pressed_connected["SectButton%d" % i] = btn.get_signal_connection_list("pressed").size() > 0


func _on_sect_pressed(i: int) -> void:
	focus_index = i
	_render()
	_pick()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_pick()
	elif event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		focus_index = (focus_index - 1 + 5) % 5
		_render()
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		focus_index = (focus_index + 1) % 5
		_render()


func _pick() -> void:
	if selected_sect_id != "" or SceneManager.pending_swap:
		return
	var ids: Array[String] = ProgressionGongfaData.sect_ids()
	if focus_index < 0 or focus_index >= ids.size():
		return
	selected_sect_id = ids[focus_index]
	SaveManager.profile.cultivation["sect_id"] = selected_sect_id
	GameManager.enter_segment("CULTIVATION")


func _render() -> void:
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
		return
	var text: String = tr("【拜入门派】\n\n")
	var rows: Array = ProgressionGongfaData.SECTS
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var marker: String = "▶" if i == focus_index else " "
		text += tr("%s %s —— 内功 %s（%s） · 外功 %s（%s）\n") % [
			marker, tr(str(row["display_name"])), tr(str(row["internal_base"])), tr(str(row["internal_attribute"])),
			tr(str(row["external_base"])), tr(str(row["external_attribute"])),
		]
	text += tr("\n上下选择，回车拜入")
	body.text = text
	for i in range(rows.size()):
		var btn: Button = get_node_or_null("SectButton%d" % i) as Button
		if btn != null:
			btn.text = tr(str(rows[i]["display_name"]))
