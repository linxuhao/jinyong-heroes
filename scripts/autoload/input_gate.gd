## InputGate (autoload) — design C-I3 / task T3.
##
## Server-side real-input gate. Normally INERT: when the environment variable
## AITELIER_INPUT_GATE_REPORT is unset/empty, _ready() returns immediately (no
## files opened, no signals connected, nothing written) and _process() exits on
## the first `if not _enabled: return`. When it IS set (to an absolute path) the
## gate:
##   1. self-drives to the battle state under test by internal calls only (no
##      button-name walk, no synthesized mouse events — navigation is not the
##      layer under test),
##   2. publishes ready:true exactly when that state is really reached,
##   3. writes a nine-key JSON report to the env path every 0.25 s,
##   4. quits deterministically after a timeout (rc=124 impossible by
##      construction — the test_game_manager_fsm lesson).
##
## The LANDED sidecar (/x11_input_smoke, outside this repo's boundary) reads the
## report file only after process exit; this autoload is the in-repo half it
## talks to. A missing key reads as zero sidecar-side; richer debug keys may be
## published ALONGSIDE the nine (the sidecar ignores unknown keys).
##
## The sidecar activates via OS.get_environment — NOT CLI user args: an autoload
## keyed on OS.get_cmdline_user_args() never switches on in the windowed run.
extends Node

const ENV_REPORT: String = "AITELIER_INPUT_GATE_REPORT"
const ENV_TIMEOUT: String = "AITELIER_INPUT_GATE_TIMEOUT"
const REPORT_INTERVAL: float = 0.25
const DEFAULT_TIMEOUT: float = 20.0

## Gate mode on/off. False unless the env report path is non-empty at _ready.
var _enabled: bool = false

## Absolute path of the report JSON (the env value).
var _report_path: String = ""

## Timeout in ms (default DEFAULT_TIMEOUT seconds).
var _timeout_ms: int = int(DEFAULT_TIMEOUT * 1000.0)

## Monotonic start tick for the timeout.
var _start_ms: int = 0

## Report-write accumulator (seconds).
var _acc: float = 0.0

## Process ticks since gate activation (published as a debug key).
var _ticks: int = 0

## Self-drive phase (published as a debug key). 0 boot, 1 tutorial dismiss,
## 2 wait-for-battle, 3 done.
var _phase: int = 0


func _ready() -> void:
	var path: String = OS.get_environment(ENV_REPORT)
	if path.strip_edges().is_empty():
		return  # gate off: nothing opened, nothing connected, nothing written.
	_report_path = path
	_enabled = true
	var t: String = OS.get_environment(ENV_TIMEOUT)
	if not t.is_empty():
		var v: float = float(t)
		if v > 0.0:
			_timeout_ms = int(v * 1000.0)
	_start_ms = Time.get_ticks_msec()
	_phase = 0


## True when the gate is active (env report path was set at _ready).
func gate_enabled() -> bool:
	return _enabled


func _process(delta: float) -> void:
	if not _enabled:
		return
	_ticks += 1
	# Deterministic timeout quit: rc=124 impossible by construction.
	if Time.get_ticks_msec() - _start_ms > _timeout_ms:
		get_tree().quit()
		return
	drive_to_battle()
	_acc += delta
	if _acc >= REPORT_INTERVAL:
		_acc = 0.0
		write_report(build_report())


## Self-drive, re-tried every tick until state_under_test() is true. Never
## restart-loops: restart_game() is called only from a non-battle state (leaving
## MENU/a segment for a fresh TUTORIAL battle through the real entry point); once
## we are in TUTORIAL/BATTLE the drive only dismisses the tutorial overlay and
## waits, so a genuine red (a STOP Control parked over the aim point in BATTLE)
## is reported as ready:false + the real eater and ends at the timeout — it is
## never papered over by looping the restart.
func drive_to_battle() -> void:
	if state_under_test():
		_phase = 3
		return
	var st: String = GameManager.get_state()
	if st != GameManager.STATE_TUTORIAL and st != GameManager.STATE_BATTLE:
		# Leave MENU / a segment for a fresh tutorial battle. restart_game()
		# emits state_changed("TUTORIAL") -> SceneManager swaps in a fresh
		# battlefield; its _ready defers TutorialManager.start().
		_phase = 0
		GameManager.restart_game()
		return
	# In TUTORIAL: dismiss the tutorial overlay through its real API. skip()
	# hides the overlay and calls GameManager.start_battle() (TUTORIAL -> BATTLE).
	# If the tutorial has not started yet (battlefield swap still settling), wait
	# and re-try next tick.
	if st == GameManager.STATE_TUTORIAL:
		_phase = 1
		if TutorialManager.is_active:
			TutorialManager.skip()


## True only when the state under test is really reached: BATTLE + a live player
## + nothing covers the aim point. Never true unconditionally.
func state_under_test() -> bool:
	if GameManager.get_state() != GameManager.STATE_BATTLE:
		return false
	var player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return false
	if InputCensus.top_eater(get_tree().root, aim_world_point()) != "":
		return false
	return true


## Where xdotool should aim (viewport px): the player's tile centre. Node2D world
## px == viewport px under the identity canvas transform (960x704 window at (0,0)).
func aim_world_point() -> Vector2:
	var player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	return GridManager.grid_to_world(player.grid_pos)


## Exactly the nine contract keys, plus debug extras alongside (sidecar ignores
## unknown keys; a missing key reads as zero).
func build_report() -> Dictionary:
	var player = GameManager.get_player()
	var world: Vector2 = aim_world_point()
	var grid: Array = []
	var moves_left: int = -1
	var raw_left: int = 0
	var handled_left: int = 0
	var raw_right: int = 0
	var handled_right: int = 0
	var eater: String = ""
	var player_path: String = ""
	if player != null and is_instance_valid(player):
		grid = [int(player.grid_pos.x), int(player.grid_pos.y)]
		moves_left = int(player.moves_left)
		raw_left = int(player.debug_input_events)
		handled_left = int(player.debug_click_events)
		raw_right = int(player.debug_right_input_events)
		handled_right = int(player.debug_undo_events)
		eater = String(player.debug_gui_eater)
		player_path = String(player.get_path())
	# When no press has been observed yet, report the live predicted eater at the
	# aim point so the sidecar can see a pre-existing hole before it clicks.
	if eater.is_empty():
		eater = InputCensus.top_eater(get_tree().root, world)
	return {
		"ready": state_under_test(),
		"player_world": [float(world.x), float(world.y)],
		"grid": grid,
		"moves_left": moves_left,
		"raw_left": raw_left,
		"handled_left": handled_left,
		"raw_right": raw_right,
		"handled_right": handled_right,
		"eater": eater,
		# Debug extras (sidecar ignores unknown keys):
		"state": GameManager.get_state(),
		"player_path": player_path,
		"ticks": _ticks,
		"drive_phase": _phase,
	}


## Tolerant write: create the parent directory if needed; a null/failed FileAccess
## logs one push_warning and returns so the next tick retries — never a crash.
func write_report(dict: Dictionary) -> void:
	var parent: String = _report_path.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(parent)
	var f: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
	if f == null:
		push_warning("InputGate: cannot write report to %s (open_error %s)" % [
			_report_path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(dict))
	f.flush()
	f.close()
