## Probe B fixture (child): records _unhandled_input firing and then CONSUMES
## the event via get_viewport().set_input_as_handled() (the Godot 4 Control
## idiom — NOT self.set_input_as_handled(), which does not exist on Control and
## was the prior parse error).
## Owned by tests/test_battle_menu_route_probe.gd — not a gameplay script.
extends Control

var child_ran: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		child_ran = true
		# Append to the parent's shared order log (Arrays are reference types).
		var log = get_parent().get("order_log")
		log.append("child")
		# Consume: this is what gates whether the parent handler still runs.
		get_viewport().set_input_as_handled()
