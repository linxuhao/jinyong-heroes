## TransitionScreen — segment 2: tutorial win -> creation/next segment.
## Two full-screen Chinese text pages; ui_accept advances; the last page routes
## onward via GameManager.enter_segment, branching on GameManager.creation_done:
## true (creation already done from the menu) -> SECT_SELECTION, skipping the
## second creation; false (legacy boot flow) -> CHARACTER_CREATION.
extends Control

const PAGES: Array[String] = [
	"华山之巅，云海翻涌。\n你赢了论剑，也赢得了一段属于自己的江湖路。\n\n江湖很大，故事才刚刚开始。",
	"接下来的路，由你自己选择。\n\n先为自己定下根基吧。",
]

## Surface: pages shown so far (0..2).
var lines_shown: int = 0

## Surface: true after the last page routed onward.
var done: bool = false


func _ready() -> void:
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	lines_shown += 1
	if lines_shown >= PAGES.size():
		done = true
		if not SceneManager.pending_swap:
			GameManager.enter_segment("SECT_SELECTION" if GameManager.creation_done else "CHARACTER_CREATION")
	else:
		_render()


func _render() -> void:
	var label: Label = get_node_or_null("PageLabel") as Label
	if label != null:
		label.text = PAGES[mini(lines_shown, PAGES.size() - 1)]
