## Probe for tasks/probe_locked_routes — locked-route + structure probes A/B/D/E.
##
## Probe C (grep hit lists) is done with the `search` tool, not at runtime, so it
## is NOT exercised here; its verdicts are recorded in
## final/delivery_notes_probe_locked_routes.md.
##
## Run standalone (NOT collected by unit_test_runner.gd, which only runs
## `static func run()` files — this is the SceneTree style, mirroring
## tests/test_game_manager_fsm.gd):
##   godot --headless --path . -s res://tests/test_battle_menu_route_probe.gd
##
## Read-only probe: it drives the LOCKED game_manager.gd/scene_manager.gd ONLY
## through their public API, and never edits a locked file. It restores
## GameManager.current_state to TUTORIAL at the end.

extends SceneTree

const GameManagerScript = preload("res://scripts/autoload/game_manager.gd")

var _gm = null   # GameManager autoload node


## Probe B fixture — parent Control. Records its _unhandled_input firing into a
## shared order_log so we can measure the ordering vs. the child handler.
class ProbeBParent extends Control:
	var order_log: Array[String] = []
	var parent_ran: bool = false

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			parent_ran = true
			order_log.append("parent")


## Probe B fixture — child Control. Records its own firing (through the parent's
## shared order_log, since Arrays are reference types) and then CONSUMES the
## event via get_viewport().set_input_as_handled() — the Godot 4 Control idiom.
## (self.set_input_as_handled() does NOT exist on Control; calling it is a
## parse error, which is what the prior retry caught.)
class ProbeBChild extends Control:
	var child_ran: bool = false

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			child_ran = true
			var log = get_parent().get("order_log")
			log.append("child")
			get_viewport().set_input_as_handled()

## Probe result verdicts, published for the delivery notes (also printed).
var verdict_a: String = "NEITHER"
var verdict_b_child_before_parent: bool = false
var verdict_b_child_blocks_parent: bool = false
var _probe_b_log: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_arm_watchdog")


func _arm_watchdog() -> void:
	var watchdog := Timer.new()
	watchdog.name = "ProbeWatchdog"
	watchdog.wait_time = 150.0
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		push_error("test_battle_menu_route_probe: watchdog fired — _run() never reached quit()")
		quit(2))
	root.add_child(watchdog)
	watchdog.start()


func _run() -> void:
	_gm = root.get_node_or_null("GameManager")
	if _gm == null:
		push_error("test_battle_menu_route_probe: GameManager autoload not found (run with -s from the repo root)")
		quit(1)
		return
	if _gm.get_script() == null:
		_gm.set_script(GameManagerScript)
	var ok := true
	ok = _probe_a() and ok
	var b_ok: bool = await _probe_b()
	ok = b_ok and ok
	# Restore canonical boot state so later checks are not polluted.
	_gm.current_state = GameManagerScript.STATE_TUTORIAL
	print("VERDICT_A=%s" % verdict_a)
	print("VERDICT_B_CHILD_BEFORE_PARENT=%s" % str(verdict_b_child_before_parent))
	print("VERDICT_B_CHILD_BLOCKS_PARENT=%s" % str(verdict_b_child_blocks_parent))
	if ok:
		print("PASS test_battle_menu_route_probe")
	else:
		print("FAIL test_battle_menu_route_probe")
	quit(0 if ok else 1)


# --- PROBE A: BATTLE -> MENU public route --------------------------------------

func _probe_a() -> bool:
	var ok := true
	# Reach a BATTLE state headlessly (node-free, like test_game_manager_fsm: the
	# FSM logic does not require an actual battlefield scene to be instantiated;
	# we set current_state directly).
	_gm.current_state = GameManagerScript.STATE_BATTLE
	ok = _expect(ok, _gm.current_state == "BATTLE", "booted into BATTLE state")

	# (b) enter_segment("MENU") from BATTLE — expected false, state unchanged
	# (MENU is not in SEGMENT_STATES and BATTLE has no segment successor row).
	var seg_ret: bool = _gm.enter_segment("MENU")
	ok = _expect(ok, seg_ret == false, "enter_segment('MENU') from BATTLE returns false")
	ok = _expect(ok, _gm.current_state == "BATTLE", "current_state still BATTLE after rejected enter_segment")

	# (c) restart_game() from BATTLE — routes to fresh TUTORIAL.
	_gm.restart_game()
	ok = _expect(ok, _gm.current_state == "TUTORIAL", "restart_game() from BATTLE lands TUTORIAL")

	# (d) Other public route: enter_menu() — no guard, any state -> MENU.
	_gm.current_state = GameManagerScript.STATE_BATTLE
	_gm.enter_menu()
	ok = _expect(ok, _gm.current_state == "MENU", "enter_menu() from BATTLE lands MENU")

	# VERDICT: enter_menu() is the sanctioned public BATTLE->MENU route.
	verdict_a = "enter_menu"
	if _gm.current_state != "MENU":
		verdict_a = "NEITHER"
	return ok


# --- PROBE B: _unhandled_input ordering child vs parent -----------------------

func _probe_b() -> bool:
	var ok := true
	_probe_b_log.clear()

	var parent := ProbeBParent.new()
	parent.name = "ProbeBParent"

	var child := ProbeBChild.new()
	child.name = "ProbeBChild"

	parent.add_child(child)
	root.add_child(parent)

	# Feed ui_accept as a synthesized InputEventAction. In Godot 4 a Control
	# consumes input by calling get_viewport().set_input_as_handled() — NOT
	# self.set_input_as_handled(). The probe scripts use the viewport call.
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	# Flush the queued event through one frame so _unhandled_input runs.
	await process_frame
	await process_frame

	var parent_ran: bool = parent.parent_ran
	var child_ran: bool = child.child_ran
	_probe_b_log = parent.order_log
	print("probe_b order_log: %s" % str(_probe_b_log))
	print("probe_b parent_ran=%s child_ran=%s" % [str(parent_ran), str(child_ran)])

	ok = _expect(ok, child_ran and parent_ran, "both handlers received ui_accept")
	# Measure whether the child handler ran before the parent handler.
	if _probe_b_log.size() == 2:
		verdict_b_child_before_parent = (_probe_b_log[0] == "child")
		verdict_b_child_blocks_parent = not (parent_ran and _probe_b_log.has("parent"))
	else:
		# child consumed the event -> parent never appended: child-before-parent true,
		# and child blocked parent if only child is present.
		verdict_b_child_before_parent = (_probe_b_log.size() == 1 and _probe_b_log[0] == "child")
		verdict_b_child_blocks_parent = (not parent_ran)
	print("probe_b verdict child_before_parent=%s child_blocks_parent=%s"
		% [str(verdict_b_child_before_parent), str(verdict_b_child_blocks_parent)])

	parent.queue_free()
	return ok


func _expect(ok_so_far: bool, cond: bool, msg: String) -> bool:
	if cond:
		print("  ok  %s" % msg)
	else:
		push_error("test_battle_menu_route_probe: %s" % msg)
		print("  FAIL %s" % msg)
	return ok_so_far and cond
