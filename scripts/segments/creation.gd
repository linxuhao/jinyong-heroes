## CreationScreen — segment 3: 30-point character creation.
## Three phases: ATTRS (5 attrs, tiered pricing, clamps 10..20) -> TRAITS
## (13 trait/flaw toggles) -> CONFIRM. Leftover points are allowed. Confirm
## calls SaveManager.new_profile(attrs, trait_ids) exactly once, then routes via
## GameManager.finish_creation(): MENU entry -> TUTORIAL (new flow); legacy
## TRANSITION entry (boot default) -> enter_segment("SECT_SELECTION"), byte-identical.
extends Control

const START_POINTS: int = 30
const ATTR_MIN: int = 10
const ATTR_MAX: int = 20

## Chinese descriptions per attribute, keyed by PlayerProfile.ATTR_KEYS.
## Formulas verbatim from design/40_progression.md §7.1, meanings from
## design/10_systems.md §1 — never paraphrased (numbers are the contract).
const _ATTR_DESCS: Dictionary = {
	"bone": "气血 = 根骨 × 5",
	"inner": "内力值 = 内力 × 2",
	"agility": "移动力 = 2 + 身法 ÷ 20(向下取整);先攻 = 身法",
	"wisdom": "决定学功法的速度(修习查表)",
	"fortune": "影响事件与奇遇(游历事件可重掷)",
}

## Surface: "ATTRS" | "TRAITS" | "CONFIRM".
var phase: String = "ATTRS"

## Surface: remaining creation points (never negative).
var points_left: int = START_POINTS

## Surface: focused attr row index (0..4, PlayerProfile.ATTR_KEYS order).
var attr_index: int = 0

## Surface: the five attrs (PlayerProfile.ATTR_KEYS -> int).
var attrs: Dictionary = {"bone": 10, "inner": 10, "agility": 10, "wisdom": 10, "fortune": 10}

var trait_index: int = 0

## Surface: chosen trait/flaw ids.
var trait_ids: Array[String] = []

## Surface: true after confirm routed onward.
var confirmed: bool = false

## Surface: pressed_connected[widget_name] is true when that mouse widget's
## pressed signal is wired to its bound handler. The ONLY observable proof of
## the middle of the mouse chain — debug_click_creation_widget calls the handler
## directly and deliberately bypasses the signal link. Snapshot AFTER all
## connects in _ready (before connect() the connection list is empty).
var pressed_connected: Dictionary = {}

var _traits: Array = []


func _ready() -> void:
	_traits = TraitData.all()
	_wire_mouse_widgets()
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if confirmed:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_accept()
	elif event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_cycle_attr_or_trait(-1)
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		_cycle_attr_or_trait(1)
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_on_move_left()
	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_on_move_right()


func _process(_delta: float) -> void:
	# Harness-only DEBUG action (defined by project.godot [input]; an absent
	# action just returns false from is_action_just_pressed — never crashes).
	# debug_click_creation_widget drives the SAME _on_attr_plus_pressed the
	# AttrPlus buttons call, proving the handler without coordinate input.
	# Guarded to the ATTRS phase so a stray press cannot advance TRAITS/CONFIRM.
	if Input.is_action_just_pressed("debug_click_creation_widget"):
		if not confirmed and phase == "ATTRS":
			_on_attr_plus_pressed(attr_index)


## Wire every mouse widget's pressed signal to the bound handler — the keyboard
## handlers stay the only logic, the buttons just delegate (single source of
## truth). Code wiring (menu_panel/settings_panel precedent) keeps the
## pressed_connected snapshot adjacent to the connects. Snapshot AFTER all
## connects: before connect() the signal's connection list is empty.
func _wire_mouse_widgets() -> void:
	for i in 5:
		(get_node("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button).pressed.connect(_on_attr_minus_pressed.bind(i))
		(get_node("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button).pressed.connect(_on_attr_plus_pressed.bind(i))
	for i in min(_traits.size(), 13):
		(get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button).pressed.connect(_on_trait_toggle_pressed.bind(i))
	(get_node("MouseBox/ConfirmBox/ConfirmButton") as Button).pressed.connect(_on_accept)
	(get_node("MouseBox/ConfirmBox/BackButton") as Button).pressed.connect(_on_move_left)
	pressed_connected.clear()
	for i in 5:
		pressed_connected["AttrMinus%d" % i] = (get_node("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button).get_signal_connection_list("pressed").size() > 0
		pressed_connected["AttrPlus%d" % i] = (get_node("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button).get_signal_connection_list("pressed").size() > 0
	for i in min(_traits.size(), 13):
		pressed_connected["TraitToggle%d" % i] = (get_node("MouseBox/TraitBox/TraitToggle%d" % i) as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["ConfirmButton"] = (get_node("MouseBox/ConfirmBox/ConfirmButton") as Button).get_signal_connection_list("pressed").size() > 0
	pressed_connected["BackButton"] = (get_node("MouseBox/ConfirmBox/BackButton") as Button).get_signal_connection_list("pressed").size() > 0


## Cost to raise an attr from `v` to `v + 1` (v in 10..19): 1 for 10..14,
## 2 for 15..19 (step2_design §2.2 tiered pricing).
func _step_cost(v: int) -> int:
	return 1 if v < 15 else 2


func _cycle_attr_or_trait(dir: int) -> void:
	match phase:
		"ATTRS":
			attr_index = (attr_index + dir + 5) % 5
		"TRAITS":
			trait_index = (trait_index + dir + _traits.size()) % _traits.size()
		_:
			return
	_render()


func _on_move_left() -> void:
	match phase:
		"ATTRS":
			var key: String = PlayerProfile.ATTR_KEYS[attr_index]
			var v: int = int(attrs[key])
			if v > ATTR_MIN:
				# Going v -> v-1 refunds the cost that was paid for v-1 -> v.
				points_left += _step_cost(v - 1)
				attrs[key] = v - 1
		"TRAITS":
			phase = "ATTRS"
			_render()
			return
		"CONFIRM":
			phase = "TRAITS"
			_render()
			return
	_render()


func _on_move_right() -> void:
	match phase:
		"ATTRS":
			var key: String = PlayerProfile.ATTR_KEYS[attr_index]
			var v: int = int(attrs[key])
			if v < ATTR_MAX:
				var cost: int = _step_cost(v)
				if points_left >= cost:
					points_left -= cost
					attrs[key] = v + 1
		"TRAITS":
			phase = "CONFIRM"
		"CONFIRM":
			return
	_render()


func _on_accept() -> void:
	match phase:
		"ATTRS":
			phase = "TRAITS"
			trait_index = 0
		"TRAITS":
			_toggle_trait(trait_index)
		"CONFIRM":
			if not confirmed and not SceneManager.pending_swap:
				confirmed = true
				SaveManager.new_profile(attrs, trait_ids)
				GameManager.finish_creation()
			return
	_render()


## Toggle a trait/flaw: positive cost spends points; a flaw (negative cost)
## refunds points. Toggling ON is refused when it would drive points negative;
## leftover points are allowed at confirm.
func _toggle_trait(idx: int) -> void:
	if idx < 0 or idx >= _traits.size():
		return
	var def = _traits[idx]
	var id: String = def.id
	var cost: int = def.cost
	if trait_ids.has(id):
		trait_ids.erase(id)
		points_left += cost
	else:
		if points_left - cost < 0:
			return
		trait_ids.append(id)
		points_left -= cost


## Mouse: focus a row without any other side effect — the following minus/plus
## press acts on the clicked row.
func _focus_attr(i: int) -> void:
	attr_index = i


## Mouse AttrMinus{i}: delegate to the same handler keyboard move_left uses.
func _on_attr_minus_pressed(i: int) -> void:
	_focus_attr(i)
	_on_move_left()


## Mouse AttrPlus{i}: delegate to the same handler keyboard move_right uses.
func _on_attr_plus_pressed(i: int) -> void:
	_focus_attr(i)
	_on_move_right()


## Mouse TraitToggle{i}: delegate to the same toggle keyboard ui_accept uses.
func _on_trait_toggle_pressed(i: int) -> void:
	trait_index = i
	_toggle_trait(i)
	_render()


func _render() -> void:
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
		return
	var text: String = ""
	match phase:
		"ATTRS":
			text = "【塑造根骨】剩余点数 %d\n\n" % points_left
			var keys: Array[String] = PlayerProfile.ATTR_KEYS
			for i in range(keys.size()):
				var key: String = keys[i]
				var marker: String = "▶" if i == attr_index else " "
				var cost: String = str(_step_cost(int(attrs[key]))) if int(attrs[key]) < ATTR_MAX else "--"
				text += "%s %s %2d  (提升 +%s点)\n" % [marker, _attr_label(key), int(attrs[key]), cost]
			text += "\n左右调整数值，上下选择属性，回车进入特质"
		"TRAITS":
			text = "【挑选特质】剩余点数 %d\n\n" % points_left
			for i in range(_traits.size()):
				var def = _traits[i]
				var marker: String = "▶" if i == trait_index else " "
				var owned: String = "已选" if trait_ids.has(def.id) else ("+" + str(def.cost) if def.cost > 0 else str(def.cost))
				text += "%s %s  %s  %s\n" % [marker, def.display_name, owned, ("先天" if def.cost > 0 else "缺陷")]
			text += "\n上下选择，回车切换，右键确认"
		"CONFIRM":
			text = "【确认】剩余点数 %d（可保留余点）\n\n" % points_left
			for key in PlayerProfile.ATTR_KEYS:
				text += "%s %2d  " % [_attr_label(key), int(attrs[key])]
			text += "\n\n特质: "
			for id in trait_ids:
				var def = TraitData.get_def(id)
				text += (def.display_name if def != null else id) + " "
			text += "\n\n回车确认，踏上江湖"
	body.text = text
	# Mouse widget surface: per-phase group visibility + row/toggle texts. The
	# keyboard text model above is untouched; the buttons mirror the same state
	# for the mouse path. Every leaf's `visible` mirrors the phase so node-level
	# asserts (TraitToggle0.visible == false in ATTRS) hold, not just the group.
	var attr_box: Control = get_node_or_null("MouseBox/AttrBox") as Control
	var trait_box: Control = get_node_or_null("MouseBox/TraitBox") as Control
	var confirm_box: Control = get_node_or_null("MouseBox/ConfirmBox") as Control
	if attr_box != null:
		attr_box.visible = phase == "ATTRS"
	if trait_box != null:
		trait_box.visible = phase == "TRAITS"
	if confirm_box != null:
		confirm_box.visible = phase == "CONFIRM"
	for i in range(PlayerProfile.ATTR_KEYS.size()):
		var row: Control = get_node_or_null("MouseBox/AttrBox/AttrRow%d" % i) as Control
		if row != null:
			row.visible = phase == "ATTRS"
		var minus: Button = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrMinus%d" % [i, i]) as Button
		if minus != null:
			minus.visible = phase == "ATTRS"
		var plus: Button = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrPlus%d" % [i, i]) as Button
		if plus != null:
			plus.visible = phase == "ATTRS"
		var row_label: Label = get_node_or_null("MouseBox/AttrBox/AttrRow%d/AttrLabel" % i) as Label
		if row_label != null:
			row_label.text = "%s %2d" % [_attr_label(PlayerProfile.ATTR_KEYS[i]), int(attrs[PlayerProfile.ATTR_KEYS[i]])]
	for i in range(min(_traits.size(), 13)):
		var toggle: Button = get_node_or_null("MouseBox/TraitBox/TraitToggle%d" % i) as Button
		if toggle != null:
			toggle.visible = phase == "TRAITS"
			var def = _traits[i]
			var owned: String = "已选" if trait_ids.has(def.id) else ("+" + str(def.cost) if def.cost > 0 else str(def.cost))
			toggle.text = def.display_name + " " + owned
	var confirm_button: Button = get_node_or_null("MouseBox/ConfirmBox/ConfirmButton") as Button
	if confirm_button != null:
		confirm_button.visible = phase == "CONFIRM"
	var back_button: Button = get_node_or_null("MouseBox/ConfirmBox/BackButton") as Button
	if back_button != null:
		back_button.visible = phase == "CONFIRM"
	# Description labels (defects 4/5): each label shows the focused item's
	# Chinese description and is visible only in its own phase. Uses
	# get_node_or_null so a missing node can never crash the render path.
	var attr_desc_label: Label = get_node_or_null("MouseBox/AttrBox/AttrDescLabel") as Label
	if attr_desc_label != null:
		attr_desc_label.visible = phase == "ATTRS"
		if phase == "ATTRS":
			attr_desc_label.text = _attr_desc(PlayerProfile.ATTR_KEYS[attr_index])
	var trait_desc_label: Label = get_node_or_null("MouseBox/TraitBox/TraitDescLabel") as Label
	if trait_desc_label != null:
		trait_desc_label.visible = phase == "TRAITS"
		if phase == "TRAITS" and trait_index >= 0 and trait_index < _traits.size():
			trait_desc_label.text = _traits[trait_index].description


func _attr_label(key: String) -> String:
	match key:
		"bone":
			return "根骨"
		"inner":
			return "内力"
		"agility":
			return "身法"
		"wisdom":
			return "悟性"
		"fortune":
			return "福缘"
	return key


## Chinese description for an attribute key; "" for unknown keys (never throws).
func _attr_desc(key: String) -> String:
	return _ATTR_DESCS.get(key, "")
