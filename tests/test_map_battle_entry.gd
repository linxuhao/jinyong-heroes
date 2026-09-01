## Integration tests for the map-battle entry (scripts/battlefield.gd
## _setup_map_battle + _instantiate_map_enemies) — jinyong-huashan round.
##
## Run manually from the repo root:
##   godot --headless -s tests/test_map_battle_entry.gd
## (the sidecar auto-discovers extends-SceneTree scripts; run_tests.sh needs no
## registration — same as tests/test_encounter.gd).
##
## Mirrors tests/test_encounter.gd's harness: extends SceneTree, autoloads
## fetched from root in a deferred _run, synchronous assertions, quit codes.
## Legs:
##   (1) REAL SceneManager swap: shell under root → enter MAP →
##       start_map_battle("huashan_duel") → the real _do_swap (map freed,
##       _teardown_battle_refs → clear_battle MID-SWAP) → battlefield._ready
##       reads the id → profile hero + five-greats roster + round 1. The id
##       SURVIVING the mid-swap clear_battle is the load-bearing pin (red under
##       a clear_battle()-owned lifecycle, green under write-at-entry).
##   (2) write-at-entry: a hand-planted map_battle_id is cleared by the
##       start_battle() (TUTORIAL) and start_encounter() (CULTIVATION) paths.
##   (3) clear-at-route: request_continue / request_retry clear the id.
##   (4) guard: a null profile aborts _setup_map_battle without crashing and
##       registers no units.
extends SceneTree

const BATTLEFIELD_SCENE = preload("res://scenes/battlefield.tscn")

var _sm = null   # SaveManager autoload node
var _gm = null   # GameManager autoload node


func _initialize() -> void:
	# Defer so the root tree (and every autoload) is fully up before touching it.
	call_deferred("_run")


func _run() -> void:
	_sm = root.get_node_or_null("SaveManager")
	_gm = root.get_node_or_null("GameManager")
	if _sm == null or _gm == null:
		push_error("test_map_battle_entry: SaveManager/GameManager autoloads not found (run with -s from the repo root)")
		quit(1)
		return
	# Hermetic start: clear save files left by an earlier interrupted run.
	_sm.delete_slot(1)
	_sm.delete_slot(2)
	_sm.delete_slot(3)
	var ok := true
	# Legs 2-4 first: they deliberately run while NO shell exists, so the
	# state_changed swaps they trigger fail harmlessly (host_missing) instead of
	# hosting real tutorial/map scenes.
	ok = _test_write_at_entry(ok)
	ok = _test_clear_at_route(ok)
	ok = _test_null_profile_guard(ok)
	# Leg 1 last: it builds the shell and drives the real swap.
	ok = await _test_real_swap(ok)
	# Restore the autoloads to their canonical boot state for later checks.
	CombatManager.reset_battle()
	_gm.clear_battle()
	_gm.current_state = "TUTORIAL"
	_gm.set_battle_return_state("TUTORIAL")
	_gm.set_map_battle_id("")
	if ok:
		print("PASS test_map_battle_entry")
	else:
		print("FAIL test_map_battle_entry")
	quit(0 if ok else 1)


# --- (2) write-at-entry discipline ---------------------------------------------

## A hand-planted map_battle_id must be cleared by every other battlefield
## entry route: start_battle() (TUTORIAL) and start_encounter() (CULTIVATION)
## each write "" at entry — no stale window even from a planted value.
func _test_write_at_entry(ok: bool) -> bool:
	_sm.new_profile({}, ["sha_po_lang"])
	_gm.clear_battle()
	CombatManager.reset_battle()
	# Tutorial path: hard-gated on TUTORIAL.
	_gm.current_state = "TUTORIAL"
	_gm.set_map_battle_id("huashan_duel")
	_gm.start_battle()
	ok = _expect(ok, _gm.get_map_battle_id() == "",
		"write-at-entry: start_battle() clears a planted map_battle_id")
	# Encounter path: hard-gated on CULTIVATION.
	_gm.current_state = "CULTIVATION"
	_gm.set_map_battle_id("huashan_duel")
	_gm.start_encounter()
	ok = _expect(ok, _gm.get_map_battle_id() == "",
		"write-at-entry: start_encounter() clears a planted map_battle_id")
	CombatManager.reset_battle()
	_gm.clear_battle()
	return ok


# --- (3) clear-at-route ----------------------------------------------------------

## From WON/LOST with battle_return_state == MAP, request_continue() and
## request_retry() each clear the map battle id (the battle is over either way).
func _test_clear_at_route(ok: bool) -> bool:
	_sm.new_profile({}, ["sha_po_lang"])
	_gm.clear_battle()
	CombatManager.reset_battle()
	_gm.set_battle_return_state("MAP")
	_gm.current_state = "WON"
	_gm.set_map_battle_id("huashan_duel")
	_gm.request_continue()
	ok = _expect(ok, _gm.current_state == "MAP",
		"clear-at-route: request_continue routes WON to MAP")
	ok = _expect(ok, _gm.get_map_battle_id() == "",
		"clear-at-route: request_continue clears map_battle_id")
	_gm.set_battle_return_state("MAP")
	_gm.current_state = "LOST"
	_gm.set_map_battle_id("huashan_duel")
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "MAP",
		"clear-at-route: request_retry routes LOST to MAP")
	ok = _expect(ok, _gm.get_map_battle_id() == "",
		"clear-at-route: request_retry clears map_battle_id")
	return ok


# --- (4) null-profile guard --------------------------------------------------------

## A null profile aborts _setup_map_battle (via the _ready map branch, since a
## null profile IS the stray-load case) with a push_warning: no crash, no
## player, no enemies, and the tutorial fallthrough never runs.
func _test_null_profile_guard(ok: bool) -> bool:
	_sm.profile = null
	_gm.clear_battle()
	CombatManager.reset_battle()
	_gm.set_map_battle_id("huashan_duel")
	var inst: Node = BATTLEFIELD_SCENE.instantiate()
	root.add_child(inst)   # _ready: map branch taken, guard aborts inside
	ok = _expect(ok, _gm.get_player() == null,
		"guard: null profile registers no player")
	ok = _expect(ok, _gm.get_enemies_alive().is_empty(),
		"guard: null profile registers no enemies")
	ok = _expect(ok, CombatManager.current_round == 0,
		"guard: null profile never kicks round 1")
	if inst.get_parent() != null:
		inst.get_parent().remove_child(inst)
	inst.free()
	CombatManager.reset_battle()
	_gm.clear_battle()
	_gm.set_map_battle_id("")
	GridManager.clear_grid()
	return ok


# --- (1) the real-swap load-bearing leg ---------------------------------------------

## Drives the REAL SceneManager swap (not a direct add_child): shell → MAP
## segment → start_map_battle("huashan_duel") → _do_swap frees the map, runs
## _teardown_battle_refs (clear_battle MID-SWAP), instantiates the battlefield,
## whose _ready reads the surviving id and fields the profile hero + the
## five-greats roster, then the deferred begin_battle brings round 1 up.
## Deliberately NOT asserted here (environment, not behavior): HUD wiring and
## the specific phase value (a low-initiative hero acts last; enemy-turn pacing
## is frame-dependent in -s) — both are pinned end-to-end by the playtest gate.
func _test_real_swap(ok: bool) -> bool:
	_build_shell()
	# Seed a profile the way the encounter harness does, but with bone 30 so the
	# hero (max_health = bone*5 = 150) survives the five greats' round-1 globals
	# (measured floor 62) for the length of this assertion window — a test
	# fixture value, not a balance number.
	_sm.new_profile({}, ["sha_po_lang"])
	_sm.profile.attrs["bone"] = 30
	_sm.profile.cultivation["sect_id"] = "wudang"
	_sm.profile.add_gongfa("wudang_taiji_d", "D")
	_sm.profile.main_external_id = "wudang_taiji_d"
	CombatManager.reset_battle()
	# Enter the MAP segment through the validated edge (direct assignment emits
	# nothing; enter_segment hosts the real map scene via the real swap).
	_gm.current_state = "CULTIVATION"
	ok = _expect(ok, _gm.enter_segment("MAP"), "real-swap: enter_segment(MAP) accepted")
	await process_frame
	ok = _expect(ok, SceneManager.current_scene == "map",
		"real-swap: MAP segment hosted before the battle")
	# THE REAL ENTRY.
	_gm.start_map_battle("huashan_duel")
	for i in range(4):
		await process_frame
	ok = _expect(ok, SceneManager.current_scene == "battlefield",
		"real-swap: current_scene == battlefield")
	ok = _expect(ok, SceneManager.pending_swap == false,
		"real-swap: pending_swap settled")
	ok = _expect(ok, _gm.get_map_battle_id() == "huashan_duel",
		"real-swap: map_battle_id SURVIVED the mid-swap clear_battle")
	var bf: Node = root.get_node_or_null("Main/SceneHost/Battlefield")
	ok = _expect(ok, bf != null, "real-swap: Main/SceneHost/Battlefield is hosted")
	var player: Node = _gm.get_player()
	ok = _expect(ok, player != null, "real-swap: GameManager has a player")
	ok = _expect(ok, player != null and player.character_data != null
		and str(player.character_data.character_name) == "ProgressionHero",
		"real-swap: the player is the profile-built ProgressionHero (NOT Yang Guo)")
	ok = _expect(ok, not CombatManager.tutorial_battle,
		"real-swap: CombatManager.tutorial_battle == false")
	ok = _expect(ok, CombatManager.current_round == 1,
		"real-swap: current_round == 1")
	ok = _expect(ok, CombatManager.phase != "IDLE",
		"real-swap: the engine left IDLE")
	var turn_order: Array = CombatManager.turn_order
	ok = _expect(ok, turn_order.size() == 6,
		"real-swap: turn_order.size() == 6 (observed %d)" % turn_order.size())
	for expected_name in ["ProgressionHero", "East Heretic", "West Poison", "South Emperor", "North Beggar", "Central Divine"]:
		ok = _expect(ok, turn_order.has(expected_name),
			"real-swap: turn_order contains \"%s\"" % expected_name)
	ok = _expect(ok, _gm.get_enemies_alive().size() == 5,
		"real-swap: 5 enemies registered")
	# Teardown: free the shell and everything the swaps hosted.
	CombatManager.reset_battle()
	_gm.clear_battle()
	_gm.set_map_battle_id("")
	GridManager.clear_grid()
	var shell: Node = root.get_node_or_null("Main")
	if shell != null:
		root.remove_child(shell)
		shell.free()
	SceneManager.current_scene = "none"
	SceneManager._current_node = null
	return ok


## Minimal shell mirroring scenes/main.tscn's hosting nodes: Main + SceneHost
## (Node2D) + SegmentLayer/SegmentHost (full-rect Control). The _do_swap HUD
## lookup (/root/Main/HUDLayer) is null-guarded, so its absence is safe; without
## this shell the boot-default swap_to("battlefield") already failed
## (host_missing) before _run, so no tutorial battlefield was auto-hosted.
func _build_shell() -> void:
	if root.get_node_or_null("Main") != null:
		return
	var main := Node.new()
	main.name = "Main"
	var scene_host := Node2D.new()
	scene_host.name = "SceneHost"
	main.add_child(scene_host)
	var segment_layer := CanvasLayer.new()
	segment_layer.name = "SegmentLayer"
	var segment_host := Control.new()
	segment_host.name = "SegmentHost"
	segment_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	segment_layer.add_child(segment_host)
	main.add_child(segment_layer)
	root.add_child(main)


func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_map_battle_entry: " + msg)
	return false
