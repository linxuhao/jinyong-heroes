## Unit tests for scripts/autoload/game_manager.gd — the six-segment FSM
## completion (task game_manager_fsm): state string constants, enter_segment
## validation, request_continue routing via battle_return_state, and
## restart_game.
##
## Run manually from the repo root:
##   godot --headless -s tests/test_game_manager_fsm.gd
##
## Mirrors tests/test_save_manager.gd: extends SceneTree, autoloads from
## project.godot ARE loaded in -s mode and are fetched from the root (deferred,
## so the tree is fully up). The FSM logic is node-free — the test drives
## current_state / battle_return_state directly and never calls the DEBUG paths
## (they touch scene nodes / CombatManager). end_battle IS exercised for its
## overlay-text path (pure node creation, headless-safe; see
## _test_end_overlay_text). current_state and battle_return_state are restored
## to TUTORIAL at the end so later checks are not polluted.
extends SceneTree

const GameManagerScript = preload("res://scripts/autoload/game_manager.gd")
const SaveManagerScript = preload("res://scripts/autoload/save_manager.gd")
const CardDataScript = preload("res://scripts/data/card_data.gd")
const TraitDataScript = preload("res://scripts/data/trait_data.gd")

var _gm = null   # GameManager autoload node
var _sm = null   # SaveManager autoload node

## Ordered log across ALL tracked signals — proves per-signal counts AND their
## relative order: "state:<STATE>" / "continue" / "retry" / "restart".
var _events: Array[String] = []
## state_changed emissions only (target states, in order).
var _state_log: Array[String] = []


func _initialize() -> void:
	# Defer so the root tree (and every autoload) is fully up before touching it.
	call_deferred("_run")
	# Structural guarantee (design/30_presentation.md 「那个 120 秒不退出的测试,死在哪」):
	# quit() must be reachable on EVERY path. A hard runtime error aborts _run
	# before its trailing quit(), leaving the SceneTree to idle until the sidecar
	# timeout (rc=124). The watchdog outlives the whole run, so termination is
	# unconditional — this suite can never hang the gate again.
	call_deferred("_arm_watchdog")


## Fails the run with exit code 2 if _run() never reaches its own quit() —
## the historical rc=124 mode. Fires well inside the sidecar's 180 s per-script
## timeout, so the gate gets a hard failure instead of a hang.
func _arm_watchdog() -> void:
	var watchdog := Timer.new()
	watchdog.name = "Watchdog"
	watchdog.wait_time = 150.0
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		push_error("test_game_manager_fsm: watchdog fired — _run() never reached quit()")
		quit(2))
	root.add_child(watchdog)
	watchdog.start()


func _run() -> void:
	_gm = root.get_node_or_null("GameManager")
	_sm = root.get_node_or_null("SaveManager")
	if _gm == null or _sm == null:
		push_error("test_game_manager_fsm: GameManager/SaveManager autoloads not found (run with -s from the repo root)")
		quit(1)
		return
	# The 2026-08-23 hang: in -s mode an autoload NODE can exist while its SCRIPT
	# is not attached, so `_gm.state_changed` on the bare node hard-errors and
	# skips the trailing quit(). Guard the real failure mode: script attachment,
	# not mere presence. If a script is missing, attach it manually (both scripts
	# are preloaded at the top of the file); the FSM logic is node-free, so a
	# scripted instance drives identically to the autoload. With the scripts
	# attached (the normal -s mode), this is a no-op.
	if _gm.get_script() == null:
		_gm.set_script(GameManagerScript)
	if _sm.get_script() == null:
		_sm.set_script(SaveManagerScript)
	_gm.state_changed.connect(_on_state_changed)
	_gm.continue_requested.connect(_on_continue)
	_gm.retry_requested.connect(_on_retry)
	_gm.restart_requested.connect(_on_restart)
	_gm.battle_started.connect(_on_battle_started)
	var ok := _test_all()
	# Restore the autoload to its canonical boot state for later checks.
	_gm.current_state = GameManagerScript.STATE_TUTORIAL
	_gm.battle_return_state = GameManagerScript.STATE_TUTORIAL
	if ok:
		print("PASS test_game_manager_fsm")
	else:
		print("FAIL test_game_manager_fsm")
	quit(0 if ok else 1)


func _on_state_changed(state: String) -> void:
	_state_log.append(state)
	_events.append("state:" + state)


func _on_continue() -> void:
	_events.append("continue")


func _on_retry() -> void:
	_events.append("retry")


func _on_restart() -> void:
	_events.append("restart")


func _on_battle_started() -> void:
	_events.append("battle_started")


func _test_all() -> bool:
	var ok := true
	ok = _test_state_constants(ok)
	ok = _test_enter_segment_legal(ok)
	ok = _test_enter_segment_illegal(ok)
	ok = _test_request_continue_routing(ok)
	ok = _test_request_continue_noop(ok)
	ok = _test_request_retry_unchanged(ok)
	ok = _test_restart_game(ok)
	ok = _test_end_overlay_text(ok)
	ok = _test_start_encounter(ok)
	ok = _test_request_retry_encounter_routing(ok)
	ok = _test_request_continue_clears_battle(ok)
	ok = _test_debug_enter_encounter(ok)
	return ok


# --- state string constants ------------------------------------------------------

func _test_state_constants(ok: bool) -> bool:
	ok = _expect(ok, GameManagerScript.STATE_TUTORIAL == "TUTORIAL", "STATE_TUTORIAL == 'TUTORIAL'")
	ok = _expect(ok, GameManagerScript.STATE_BATTLE == "BATTLE", "STATE_BATTLE == 'BATTLE'")
	ok = _expect(ok, GameManagerScript.STATE_WON == "WON", "STATE_WON == 'WON'")
	ok = _expect(ok, GameManagerScript.STATE_LOST == "LOST", "STATE_LOST == 'LOST'")
	ok = _expect(ok, GameManagerScript.STATE_TRANSITION == "TRANSITION", "STATE_TRANSITION == 'TRANSITION'")
	ok = _expect(ok, GameManagerScript.STATE_CHARACTER_CREATION == "CHARACTER_CREATION", "STATE_CHARACTER_CREATION == 'CHARACTER_CREATION'")
	ok = _expect(ok, GameManagerScript.STATE_SECT_SELECTION == "SECT_SELECTION", "STATE_SECT_SELECTION == 'SECT_SELECTION'")
	ok = _expect(ok, GameManagerScript.STATE_CULTIVATION == "CULTIVATION", "STATE_CULTIVATION == 'CULTIVATION'")
	ok = _expect(ok, GameManagerScript.STATE_MAP == "MAP", "STATE_MAP == 'MAP'")
	ok = _expect(ok, GameManagerScript.STATE_ENDING == "ENDING", "STATE_ENDING == 'ENDING'")
	ok = _expect(ok, GameManagerScript.SEGMENT_STATES.size() == 6, "SEGMENT_STATES has exactly 6 entries")
	for s in GameManagerScript.SEGMENT_STATES:
		ok = _expect(ok, GameManagerScript.SEGMENT_PREDECESSORS.has(s),
			"SEGMENT_PREDECESSORS has a row for every segment state: " + s)
	ok = _expect(ok, not GameManagerScript.SEGMENT_STATES.has("TUTORIAL"), "TUTORIAL not in SEGMENT_STATES")
	ok = _expect(ok, not GameManagerScript.SEGMENT_STATES.has("BATTLE"), "BATTLE not in SEGMENT_STATES")
	ok = _expect(ok, not GameManagerScript.SEGMENT_STATES.has("WON"), "WON not in SEGMENT_STATES")
	ok = _expect(ok, not GameManagerScript.SEGMENT_STATES.has("LOST"), "LOST not in SEGMENT_STATES")
	return ok


# --- criterion 1: legal enter_segment transitions (design §4 table) -------------

func _test_enter_segment_legal(ok: bool) -> bool:
	var table := [
		["WON", "TRANSITION"],
		["TRANSITION", "CHARACTER_CREATION"],
		["CHARACTER_CREATION", "SECT_SELECTION"],
		["SECT_SELECTION", "CULTIVATION"],
		["CULTIVATION", "MAP"],
		["MAP", "ENDING"],
	]
	for row in table:
		_reset_signals()
		var from: String = row[0]
		var to: String = row[1]
		_gm.current_state = from
		ok = _expect(ok, _gm.enter_segment(to), "enter_segment(" + to + ") from " + from + " returns true")
		ok = _expect(ok, _gm.current_state == to, "current_state == " + to + " after legal transition")
		ok = _expect(ok, _state_log == [to], "state_changed fired exactly once with " + to)
		ok = _expect(ok, _events == ["state:" + to], "no other signals on a legal enter_segment")
	return ok


# --- criterion 2: illegal transitions are no-ops ---------------------------------

func _test_enter_segment_illegal(ok: bool) -> bool:
	# Out-of-order: from TRANSITION, MAP is not the legal successor.
	_reset_signals()
	_gm.current_state = "TRANSITION"
	ok = _expect(ok, not _gm.enter_segment("MAP"), "enter_segment(MAP) from TRANSITION returns false")
	ok = _expect(ok, _gm.current_state == "TRANSITION", "current_state unchanged on illegal transition")
	ok = _expect(ok, _state_log.is_empty(), "no state_changed on illegal transition")
	ok = _expect(ok, _events.is_empty(), "no signals at all on illegal transition")

	# No self-transition.
	_reset_signals()
	_gm.current_state = "TRANSITION"
	ok = _expect(ok, not _gm.enter_segment("TRANSITION"), "enter_segment(TRANSITION) from TRANSITION returns false (self)")
	ok = _expect(ok, _gm.current_state == "TRANSITION", "current_state unchanged on self-transition")

	# Battle states are not enterable via enter_segment.
	_reset_signals()
	_gm.current_state = "MAP"
	for s in ["TUTORIAL", "BATTLE", "WON", "LOST"]:
		ok = _expect(ok, not _gm.enter_segment(s), "enter_segment(" + s + ") returns false (not a segment)")
	ok = _expect(ok, _gm.current_state == "MAP", "current_state unchanged after non-segment attempts")

	# Empty target.
	_reset_signals()
	ok = _expect(ok, not _gm.enter_segment(""), "enter_segment('') returns false")
	ok = _expect(ok, _gm.current_state == "MAP", "current_state unchanged on empty target")
	ok = _expect(ok, _state_log.is_empty(), "no state_changed on empty target")
	return ok


# --- criterion 3: request_continue routes via battle_return_state ---------------

func _test_request_continue_routing(ok: bool) -> bool:
	# Tutorial battle (battle_return_state "TUTORIAL") -> TRANSITION — the
	# byte-identical path the 11 protected scenarios rely on.
	_reset_signals()
	_gm.current_state = "WON"
	_gm.set_battle_return_state("TUTORIAL")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "TRANSITION", "continue from tutorial WON -> TRANSITION")
	ok = _expect(ok, _state_log == ["TRANSITION"], "state_changed(TRANSITION) fired once")
	ok = _expect(ok, _events == ["state:TRANSITION", "continue"], "continue_requested fired after state_changed")

	# Future encounter battle (battle_return_state "CULTIVATION") -> CULTIVATION.
	_reset_signals()
	_gm.current_state = "WON"
	_gm.set_battle_return_state("CULTIVATION")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "CULTIVATION", "continue from encounter WON -> CULTIVATION")
	ok = _expect(ok, _state_log == ["CULTIVATION"], "state_changed(CULTIVATION) fired once (SceneManager routes on it)")

	# Unknown return state -> fall back to TRANSITION.
	_reset_signals()
	_gm.current_state = "WON"
	_gm.set_battle_return_state("BOGUS")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "TRANSITION", "bogus battle_return_state falls back to TRANSITION")
	ok = _expect(ok, _state_log == ["TRANSITION"], "state_changed(TRANSITION) fired on fallback")
	return ok


func _test_request_continue_noop(ok: bool) -> bool:
	_reset_signals()
	_gm.current_state = "TUTORIAL"
	_gm.set_battle_return_state("TUTORIAL")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "TUTORIAL", "continue no-op outside WON")
	ok = _expect(ok, _state_log.is_empty(), "no state_changed on no-op continue")
	ok = _expect(ok, _events.is_empty(), "no signals at all on no-op continue")
	return ok


# --- criterion 5: request_retry behavior unchanged ------------------------------

func _test_request_retry_unchanged(ok: bool) -> bool:
	_reset_signals()
	_gm.current_state = "LOST"
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "TUTORIAL", "retry routes LOST -> TUTORIAL")
	ok = _expect(ok, _state_log == ["TUTORIAL"], "state_changed(TUTORIAL) fired once")
	ok = _expect(ok, _events == ["state:TUTORIAL", "retry"], "retry_requested fired after state_changed")

	_reset_signals()
	_gm.current_state = "CULTIVATION"
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "CULTIVATION", "retry no-op outside LOST")
	ok = _expect(ok, _state_log.is_empty(), "no state_changed on no-op retry")
	ok = _expect(ok, _events.is_empty(), "no signals at all on no-op retry")
	return ok


# --- criterion 4: restart_game returns to a truly-fresh TUTORIAL ----------------

func _test_restart_game(ok: bool) -> bool:
	# Prime a non-default profile and a deterministic pre-restart seed so every
	# reset effect of restart_game is observable.
	_reset_signals()
	_sm.new_profile({"bone": 17}, ["deep_fortune"])
	_sm.apply_seed(42)
	_gm.current_state = "ENDING"
	_gm.set_battle_return_state("CULTIVATION")
	var pre_seed: int = _sm.seed

	_gm.restart_game()

	ok = _expect(ok, _gm.current_state == "TUTORIAL", "restart routes to TUTORIAL")
	ok = _expect(ok, _state_log == ["TUTORIAL"], "state_changed(TUTORIAL) fired exactly once")
	ok = _expect(ok, _events == ["state:TUTORIAL", "restart"], "state_changed BEFORE restart_requested, once each")
	ok = _expect(ok, _gm.get_battle_return_state() == "CULTIVATION", "restart does not touch battle_return_state")
	ok = _expect(ok, _sm.has_save == false, "has_save false after restart")
	ok = _expect(ok, _sm.slot == 0, "slot reset to 0 after restart")
	ok = _expect(ok, _sm.last_error == "", "last_error cleared after restart")
	ok = _expect(ok, _sm.profile.flags["tutorial_done"] == false, "tutorial_done false after restart (fresh tutorial)")
	ok = _expect(ok, _sm.profile.traits.is_empty(), "traits cleared after restart")
	for key in PlayerProfile.ATTR_KEYS:
		ok = _expect(ok, _sm.profile.get_attr(key) == PlayerProfile.ATTR_FLOOR,
			"attr " + key + " reset to floor after restart")
	ok = _expect(ok, _sm.seed != pre_seed, "seed differs from pre-restart seed (reseeded)")
	# Deck counts back to the authoritative initial sizes — derived, never hardcoded.
	ok = _expect(ok, _sm.eco_left == CardDataScript.deck_size("economy"), "eco_left restored to initial deck size")
	ok = _expect(ok, _sm.eq_left == CardDataScript.deck_size("equipment"), "eq_left restored to initial deck size")
	ok = _expect(ok, _sm.growth_left == CardDataScript.deck_size("growth"), "growth_left restored (9 rows — NOT 12)")
	ok = _expect(ok, _sm.pow_left == CardDataScript.deck_size("power"), "pow_left restored to initial deck size")
	ok = _expect(ok, _sm.art_left == CardDataScript.deck_size("artifact"), "art_left restored to initial deck size")
	ok = _expect(ok, _sm.trait_left == TraitDataScript.positive_ids().size(),
		"trait_left restored (dynamic: 8 positives for a fresh profile)")
	return ok


# --- criterion 6: end_overlay_text (Chinese, no ellipsis) -------------------------

## WON/LOST overlay text must be Chinese (界面文字一律中文) and never contain
## "..." or U+2026 "…" (repo-wide no-ellipsis rule for UI text) — acceptance 5
## of fix_vision_gate_readability. end_battle's overlay path is pure node
## creation (CanvasLayer + Panel + Label; no scene refs), so it is safe in
## headless -s mode; clear_battle() tears each overlay down afterwards.
func _test_end_overlay_text(ok: bool) -> bool:
	# WON: end_battle(true) writes the 胜利 overlay text.
	_reset_signals()
	_gm.current_state = "BATTLE"
	_gm.end_battle(true)
	ok = _expect(ok, _gm.current_state == "WON", "end_battle(true) -> WON")
	ok = _expect(ok, _gm.end_overlay_text.contains("胜利"), "WON end_overlay_text contains 胜利")
	ok = _expect(ok, not _gm.end_overlay_text.contains("..."), 'WON end_overlay_text has no "..."')
	ok = _expect(ok, not _gm.end_overlay_text.contains("…"), "WON end_overlay_text has no U+2026")
	_gm.clear_battle()

	# LOST: end_battle(false) writes the 战败 overlay text.
	_reset_signals()
	_gm.current_state = "BATTLE"
	_gm.end_battle(false)
	ok = _expect(ok, _gm.current_state == "LOST", "end_battle(false) -> LOST")
	ok = _expect(ok, _gm.end_overlay_text.contains("战败"), "LOST end_overlay_text contains 战败")
	ok = _expect(ok, not _gm.end_overlay_text.contains("..."), 'LOST end_overlay_text has no "..."')
	ok = _expect(ok, not _gm.end_overlay_text.contains("…"), "LOST end_overlay_text has no U+2026")
	_gm.clear_battle()

	# Restore the FSM to a non-WON/LOST state for _run()'s teardown.
	_gm.current_state = GameManagerScript.STATE_TUTORIAL
	return ok


# --- start_encounter: CULTIVATION -> BATTLE with battle_return_state == CULTIVATION ---

func _test_start_encounter(ok: bool) -> bool:
	# CULTIVATION -> BATTLE: battle_return_state set to CULTIVATION, and the
	# signals fire in the same order as start_battle (battle_started first).
	_reset_signals()
	_gm.clear_battle()
	_gm.current_state = "CULTIVATION"
	_gm.set_battle_return_state("TUTORIAL")
	_gm.start_encounter()
	ok = _expect(ok, _gm.current_state == "BATTLE", "start_encounter CULTIVATION -> BATTLE")
	ok = _expect(ok, _gm.get_battle_return_state() == "CULTIVATION",
		"start_encounter sets battle_return_state == CULTIVATION")
	ok = _expect(ok, _state_log == ["BATTLE"], "state_changed(BATTLE) fired exactly once")
	ok = _expect(ok, _events == ["battle_started", "state:BATTLE"],
		"battle_started emitted before state_changed(BATTLE), once each")

	# No-op from every other state: no state change, no signals.
	for s in ["TUTORIAL", "BATTLE", "WON", "LOST", "MAP"]:
		_reset_signals()
		_gm.current_state = s
		_gm.set_battle_return_state("TUTORIAL")
		_gm.start_encounter()
		ok = _expect(ok, _gm.current_state == s, "start_encounter no-op in " + s)
		ok = _expect(ok, _gm.get_battle_return_state() == "TUTORIAL",
			"battle_return_state untouched by start_encounter no-op in " + s)
		ok = _expect(ok, _events.is_empty(), "no signals on start_encounter no-op in " + s)
	return ok


# --- request_retry: segment routing via battle_return_state --------------------

func _test_request_retry_encounter_routing(ok: bool) -> bool:
	# Encounter LOST (battle_return_state == CULTIVATION, a segment) routes back
	# to CULTIVATION instead of the hardcoded TUTORIAL.
	_reset_signals()
	_gm.clear_battle()
	_gm.current_state = "LOST"
	_gm.set_battle_return_state("CULTIVATION")
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "CULTIVATION", "retry from encounter LOST -> CULTIVATION")
	ok = _expect(ok, _state_log == ["CULTIVATION"], "state_changed(CULTIVATION) fired once")
	ok = _expect(ok, _events == ["state:CULTIVATION", "retry"],
		"state_changed(CULTIVATION) before retry_requested, once each")

	# Tutorial LOST (battle_return_state == TUTORIAL, NOT a segment) stays
	# TUTORIAL — the byte-identical path the protected scenarios rely on.
	_reset_signals()
	_gm.current_state = "LOST"
	_gm.set_battle_return_state("TUTORIAL")
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "TUTORIAL", "retry from tutorial LOST -> TUTORIAL (unchanged)")
	ok = _expect(ok, _events == ["state:TUTORIAL", "retry"], "tutorial retry event order unchanged")

	# Non-segment fallback: an unknown return state still routes to TUTORIAL.
	_reset_signals()
	_gm.current_state = "LOST"
	_gm.set_battle_return_state("BOGUS")
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "TUTORIAL", "bogus battle_return_state falls back to TUTORIAL")
	ok = _expect(ok, _events == ["state:TUTORIAL", "retry"], "fallback retry event order unchanged")
	return ok


# --- request_continue: guarded clear_battle on segment routing -----------------

## request_continue now drops every per-battle ref (clear_battle) ONLY when the
## WON routes to a segment state (encounter battles). The tutorial WON path
## (battle_return_state == "TUTORIAL", not a segment) must preserve _player and
## enemies byte-identically.
func _test_request_continue_clears_battle(ok: bool) -> bool:
	# Encounter WON -> CULTIVATION: battle refs are cleared.
	_reset_signals()
	var dummy_enemy: Node = Node.new()
	dummy_enemy.name = "DummyEnemy"
	var dummy_player: Node = Node.new()
	dummy_player.name = "DummyPlayer"
	_gm.clear_battle()
	_gm.register_enemy(dummy_enemy)
	_gm.set_player(dummy_player)
	_gm.current_state = "WON"
	_gm.set_battle_return_state("CULTIVATION")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "CULTIVATION", "continue from encounter WON -> CULTIVATION")
	ok = _expect(ok, _gm.get_player() == null, "clear_battle dropped the player ref on segment routing")
	ok = _expect(ok, _gm.get_enemies_alive().is_empty(), "clear_battle dropped enemies on segment routing")
	dummy_enemy.free()
	dummy_player.free()
	_gm.clear_battle()

	# Tutorial WON -> TRANSITION: battle refs are preserved (byte-identical guard).
	_reset_signals()
	dummy_enemy = Node.new()
	dummy_enemy.name = "DummyEnemy2"
	dummy_player = Node.new()
	dummy_player.name = "DummyPlayer2"
	_gm.clear_battle()
	_gm.register_enemy(dummy_enemy)
	_gm.set_player(dummy_player)
	_gm.current_state = "WON"
	_gm.set_battle_return_state("TUTORIAL")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "TRANSITION", "continue from tutorial WON -> TRANSITION")
	ok = _expect(ok, _gm.get_player() == dummy_player,
		"tutorial WON preserves the player ref (no clear_battle)")
	ok = _expect(ok, _gm.get_enemies_alive().size() == 1,
		"tutorial WON preserves enemies (no clear_battle)")
	dummy_enemy.free()
	dummy_player.free()
	_gm.clear_battle()
	return ok


# --- debug_enter_encounter: unbound DEBUG action in _process ------------------

## Input.is_action_just_pressed is frame-dependent: press -> _process -> release
## must all happen in this one synchronous function (no await, no frame
## boundary), per research_notes.md.
func _test_debug_enter_encounter(ok: bool) -> bool:
	# No-op outside CULTIVATION (TUTORIAL).
	_reset_signals()
	_gm.clear_battle()
	_gm.current_state = "TUTORIAL"
	_gm.set_battle_return_state("TUTORIAL")
	Input.action_press("debug_enter_encounter")
	_gm._process(0.0)
	Input.action_release("debug_enter_encounter")
	ok = _expect(ok, _gm.current_state == "TUTORIAL",
		"debug_enter_encounter no-op outside CULTIVATION")
	ok = _expect(ok, _events.is_empty(), "no signals on no-op debug_enter_encounter")

	# CULTIVATION -> BATTLE via the same _process hook.
	_reset_signals()
	_gm.current_state = "CULTIVATION"
	_gm.set_battle_return_state("TUTORIAL")
	Input.action_press("debug_enter_encounter")
	_gm._process(0.0)
	Input.action_release("debug_enter_encounter")
	ok = _expect(ok, _gm.current_state == "BATTLE", "debug_enter_encounter in CULTIVATION -> BATTLE")
	ok = _expect(ok, _gm.get_battle_return_state() == "CULTIVATION",
		"debug_enter_encounter sets battle_return_state == CULTIVATION")
	ok = _expect(ok, _events == ["battle_started", "state:BATTLE"],
		"debug_enter_encounter fires battle_started then state_changed(BATTLE)")
	return ok


# --- helpers ----------------------------------------------------------------------

func _reset_signals() -> void:
	_events.clear()
	_state_log.clear()


func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_game_manager_fsm: " + msg)
	return false
