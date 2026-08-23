## CreationScreen — segment 3: 30-point character creation.
## Three phases: ATTRS (5 attrs, tiered pricing, clamps 10..20) -> TRAITS
## (13 trait/flaw toggles) -> CONFIRM. Leftover points are allowed. Confirm
## calls SaveManager.new_profile(attrs, trait_ids) exactly once, then routes to
## SECT_SELECTION.
extends Control

const START_POINTS: int = 30
const ATTR_MIN: int = 10
const ATTR_MAX: int = 20

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

var _traits: Array = []


func _ready() -> void:
	_traits = TraitData.all()
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
				GameManager.enter_segment("SECT_SELECTION")
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
