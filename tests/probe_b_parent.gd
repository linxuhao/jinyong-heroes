## Probe B fixture (parent): records the order in which _unhandled_input fires
## for a parent Control vs. its child Control when ui_accept is fed.
## Owned by tests/test_battle_menu_route_probe.gd — not a gameplay script.
extends Control

var order_log: Array[String] = []
var parent_ran: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		parent_ran = true
		order_log.append("parent")
