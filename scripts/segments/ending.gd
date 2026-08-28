## EndingScreen — final segment: tiered ending text.
## tier = MapData.ending_tier(sum of the 5 attrs); ui_accept restarts the whole
## game (GameManager.restart_game -> fresh profile + fresh tutorial battle).
extends Control

## Surface: ending tier (1..3, MapData.ENDING_TIERS).
var tier: int = 0

## Surface: true after restart routed onward.
var done: bool = false


func _ready() -> void:
	var total: int = 0
	for key in PlayerProfile.ATTR_KEYS:
		total += SaveManager.profile.get_attr(key)
	tier = MapData.ending_tier(total)
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
		get_viewport().set_input_as_handled()
		done = true
		if not SceneManager.pending_swap:
			GameManager.restart_game()


func _render() -> void:
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
		return
	var def: Dictionary = MapData.ending_def(tier)
	var title: String = def.get("title", "") if not def.is_empty() else ""
	var text_lines: String = def.get("text", "") if not def.is_empty() else ""
	body.text = tr("【结局 · %s】\n\n%s\n\n按回车重新开始") % [tr(title), tr(text_lines)]
