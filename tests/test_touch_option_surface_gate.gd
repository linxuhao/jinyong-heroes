## Property-based touch-coverage gate (coverage_gate task, step2_design §6).
##
## Run manually from the repo root:
##   godot --headless -s tests/test_touch_option_surface_gate.gd
## (the /script gate auto-discovers every tests/*.gd that `extends SceneTree` —
## run_tests.sh has NO per-file invocation list on purpose, so it is NOT edited
## here, and this file is NOT added to unit_test_runner.gd's TESTS registry:
## that runner collects `static func run() -> bool` files, and a quit()-based
## SceneTree test added there would kill the runner mid-loop.)
##
## THE PROPERTY (game-level, never engine geometry — no offset/position/size/
## z-order/mouse_filter, no absolute balance numbers):
##   Every player-choice phase the machine itself reaches — unless it is EXEMPT
##   (no input can change it) — must have had its clickable-control constructor
##   leave >=1 VISIBLE and WIRED (pressed_connected true) control, AND must show
##   no ▶ cursor marker in the rendered body text (cursor_markers_visible ==
##   false, the machine-checkable proof the duplicated keyboard-cursor text list
##   is gone — cultivation.gd / map.gd / sect_select.gd single-surface work).
##
## DISCOVERY: phases are not enumerated in a hard-coded phase-name array. Each
## walk drives the machine through its OWN handlers (_on_accept / _on_option_
## pressed / _cycle_focus / _on_travel_pressed / _on_event_option_pressed /
## _on_facility_enter_pressed / ...) and reads the landing node.phase to decide
## the phase under inspection. The `match phase:` dispatch arms ARE the
## adjacency table; the walks are explicit because several choice phases
## consume the monthly action and are therefore visited one per simulated month
## (exactly as manual play reaches them), with a <250-drive guard.
##
## SCOPE (from step2_design §6): battle (HUD buttons + endgame overlay), creation
## (single-surface), menu / settings / tutorial / ending (stable button pools)
## are ALL OUTSIDE the three traversed machines and are covered by their own
## playtest scenarios; this gate covers only the segments whose option pools are
## (re)built per render/state (cultivation, map, sect_select).
##
## The walk is fully synchronous (no awaits): hermetic fresh profile + seeded
## RNG before any draw, GameManager.current_state forced, each segment scene
## instantiated and added to the root so _ready() runs. Segments call
## SaveManager.autosave(), which legitimately refuses outside a stable state —
## nothing here asserts has_save / slot contents (the hermetic pattern of
## tests/test_map_facility_buttons.gd / tests/test_cultivation.gd).
## The map walk deliberately avoids end nodes (kunlun -> ENDING) and the battle
## node (huashan); the cultivation walk never drives an action at (year 3,
## month 12), which would route to MAP.
extends SceneTree

const CULTIVATION_SCENE = preload("res://scenes/segments/cultivation.tscn")
const MAP_SCENE = preload("res://scenes/segments/map.tscn")
const SECT_SCENE = preload("res://scenes/segments/sect_select.tscn")
const MapData = preload("res://scripts/data/map_data.gd")

## The map segment's delegate-button pool (scene node paths; the same 8 the
## playtest surface contract publishes). Only a path whose button is VISIBLE and
## whose pressed_connected[name] == true counts as a wired, offered control.
const MAP_BUTTON_PATHS: Array = [
	"TravelBox/TravelButton0", "TravelBox/TravelButton1", "TravelBox/TravelButton2",
	"EventBox/EventOptionButton0", "EventBox/EventOptionButton1",
	"FacilityEnterButton", "FacilityUseButton", "FacilityLeaveButton",
]

## EXEMPT table — a state is exempt iff NO input can change it (pure display /
## auto-advance only). Empty for all three machines today: every reachable phase
## is a player-choice state, so the table documents the RULE and gives a future
## pure-display / auto-advance phase a place to justify itself instead of
## silently weakening the gate. A newly discovered non-exempt phase producing 0
## controls FAILS with the self-explaining message in _check_choice_state.
const EXEMPT: Dictionary = {}

var _sm = null   # SaveManager autoload node
var _gm = null   # GameManager autoload node


func _initialize() -> void:
	# Defer so the root tree (and every autoload) is fully up before touching it.
	call_deferred("_run")


func _run() -> void:
	_sm = root.get_node_or_null("SaveManager")
	_gm = root.get_node_or_null("GameManager")
	if _sm == null or _gm == null:
		push_error("test_touch_option_surface_gate: SaveManager/GameManager autoloads not found (run with -s from the repo root)")
		quit(1)
		return
	# Hermetic start: clear save files left by an earlier interrupted run.
	_sm.delete_slot(1)
	_sm.delete_slot(2)
	_sm.delete_slot(3)
	var ok := true
	ok = _cultivation_walk()
	ok = _test_gongfa_empty_exit(ok)
	ok = _map_walk()
	ok = _sect_walk()
	_gm.current_state = "TUTORIAL"   # leave the autoload clean for later runs
	if ok:
		print("PASS test_touch_option_surface_gate")
	else:
		print("FAIL test_touch_option_surface_gate")
	quit(0 if ok else 1)


func _is_exempt(machine: String, phase: String) -> bool:
	var m: Variant = EXEMPT.get(machine, {})
	return m is Dictionary and (m as Dictionary).has(phase)


## Check the property for one observed machine / phase. Returns `ok` unchanged
## on success, false on failure. The 0-control failure message is the exact
## self-explaining string the gate contract pins (<name> = observed phase).
func _check_choice_state(ok: bool, machine: String, phase: String, visible_wired: int, cursor: bool) -> bool:
	if _is_exempt(machine, phase):
		return ok
	if visible_wired < 1:
		push_error("new phase %s produced 0 tappable controls — give it a clickable exit or add it to EXEMPT with a documented reason; do not weaken this gate" % phase)
		return false
	if cursor:
		push_error("test_touch_option_surface_gate: %s/%s still rendered a ▶ cursor marker (duplicated text list)" % [machine, phase])
		return false
	return ok


# ---------------------------------------------------------------------------
# Cultivation — traverse CARD_PICK / ACTION_PICK / GONGFA_PICK / ATTR_PICK /
# EVENT / YEAR_END / SECT_SWITCH / YEAR_AUGMENT through the machine's own
# handlers. Several choice phases consume the monthly action, so each is
# visited in its own simulated month, exactly as manual play reaches them.
# ---------------------------------------------------------------------------

func _cultivation_walk() -> bool:
	var ok := true
	var drives := 0
	# Sub-walk A: year 1 month 1 -> CARD_PICK, ACTION_PICK, GONGFA_PICK
	# (practice advances a month), ATTR_PICK, EVENT (each one month apart).
	var node: Node = _cult_setup("shaolin", 54321, 1, 1)
	drives += 1
	ok = _cult_check(node, ok)                            # CARD_PICK
	node._on_option_pressed(0)                            # pick card -> ACTION_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_option_pressed(0)                            # 练功 -> GONGFA_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_accept()                                     # practice -> next month CARD_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_option_pressed(0)                            # card -> ACTION_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_option_pressed(1)                            # 修习 -> ATTR_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_accept()                                     # cultivate -> next month CARD_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_option_pressed(0)                            # card -> ACTION_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_option_pressed(3)                            # 游历 -> EVENT
	drives += 1
	ok = _cult_check(node, ok)
	node._on_accept()                                     # resolve event -> next month CARD_PICK
	drives += 1
	ok = _cult_check(node, ok)
	_teardown(node)
	# Sub-walk B: year 2 month 1 -> YEAR_AUGMENT -> CARD_PICK.
	node = _cult_setup("shaolin", 111, 2, 1)
	drives += 1
	ok = _cult_check(node, ok)                            # YEAR_AUGMENT
	node._on_option_pressed(0)                            # yearly card -> CARD_PICK
	drives += 1
	ok = _cult_check(node, ok)
	_teardown(node)
	# Sub-walk C: year 2 month 12 -> YEAR_END -> SECT_SWITCH (never (3,12) -> MAP).
	node = _cult_setup("shaolin", 222, 2, 12)
	drives += 1
	ok = _cult_check(node, ok)                            # CARD_PICK
	node._on_option_pressed(0)                            # card -> ACTION_PICK
	drives += 1
	ok = _cult_check(node, ok)
	node._on_option_pressed(2)                            # 做工 -> month 12 -> YEAR_END
	drives += 1
	ok = _cult_check(node, ok)
	node._cycle_focus(1)                                  # year-end focus -> 另投他派
	node._on_accept()                                     # -> SECT_SWITCH
	drives += 1
	ok = _cult_check(node, ok)
	_teardown(node)
	ok = _expect(ok, drives < 250, "cultivation walk stayed under the 250-drive guard (drove %d)" % drives)
	return ok


## Check the property for the cult screen's CURRENT phase (discovered by reading
## node.phase after the last handler drive — never from a hard-coded phase list).
func _cult_check(node: Node, ok: bool) -> bool:
	return _check_choice_state(ok, "cultivation", String(node.phase), _cult_visible_wired(node), bool(node.cursor_markers_visible))


## Count of OptionsBox children that are visible Button controls and WIRED
## (pressed_connected[name] == true). The box is rebuilt every render, so this
## reflects exactly what the constructor left behind for the current phase.
func _cult_visible_wired(node: Node) -> int:
	var box: Node = node.get_node_or_null("OptionsBox")
	if box == null:
		return 0
	var pc: Dictionary = node.pressed_connected if node.pressed_connected is Dictionary else {}
	var n: int = 0
	for child in box.get_children():
		if child is Button:
			var b: Button = child as Button
			if b.visible and bool(pc.get(str(b.name), false)):
				n += 1
	return n


## Fresh deterministic cultivation scenario: new profile, shaolin sect, year /
## month on the profile, RNG seeded before any draw, state forced to CULTIVATION,
## scene instantiated and added to the root so _ready() runs.
func _cult_setup(sect_id: String, seed_value: int, year: int, month: int) -> Node:
	_sm.new_profile({}, [])
	_sm.profile.cultivation["sect_id"] = sect_id
	_sm.profile.cultivation["year"] = year
	_sm.profile.cultivation["month"] = month
	_sm.apply_seed(seed_value)
	_gm.current_state = "CULTIVATION"
	var inst: Node = CULTIVATION_SCENE.instantiate()
	root.add_child(inst)
	return inst


## The GONGFA_PICK empty-list dead-end regression (the reported touch dead-end
## this round removes): with NO unmastered technique, the phase must offer the
## single tappable exit — and CLICKING it (emitting the button's own pressed
## signal, the real click path) must ACTUALLY transition phase GONGFA_PICK ->
## ACTION_PICK. A merely-present button does not satisfy this; the phase diff does.
func _test_gongfa_empty_exit(ok: bool) -> bool:
	_sm.new_profile({}, [])
	_sm.profile.cultivation["sect_id"] = "shaolin"
	_sm.profile.cultivation["year"] = 1
	_sm.profile.cultivation["month"] = 1
	_sm.apply_seed(7)
	_gm.current_state = "CULTIVATION"
	var node: Node = CULTIVATION_SCENE.instantiate()
	root.add_child(node)   # _ready granted the sect's year-1 arts, phase CARD_PICK
	# Master EVERY granted art directly on the profile (the sanctioned debug
	# route — the review suggestion that avoids coupling the gate to practice UI).
	for entry in _sm.profile.gongfa:
		var gid: String = str(entry.get("id", ""))
		if gid != "":
			_sm.profile.master_gongfa_of(gid)
	node._sync_surface()
	# Navigate via the machine's own handlers: CARD_PICK -> ACTION_PICK -> GONGFA_PICK.
	ok = _expect(ok, node.phase == "CARD_PICK", "fixture: fresh month 1 stages CARD_PICK (got %s)" % str(node.phase))
	node._on_option_pressed(0)
	ok = _expect(ok, node.phase == "ACTION_PICK", "card pick -> ACTION_PICK (got %s)" % str(node.phase))
	node._on_option_pressed(0)   # 练功
	ok = _expect(ok, node.phase == "GONGFA_PICK", "action index 0 -> GONGFA_PICK (got %s)" % str(node.phase))
	# Exactly ONE tappable exit: wired + visible.
	var box: Node = node.get_node_or_null("OptionsBox")
	ok = _expect(ok, box != null, "OptionsBox is present")
	var child_count: int = box.get_child_count() if box != null else -1
	ok = _expect(ok, child_count == 1, "GONGFA_PICK with no unmastered -> exactly ONE tappable exit (got %d)" % child_count)
	var exit_btn: Button = box.get_child(0) as Button if box != null and child_count == 1 else null
	ok = _expect(ok, exit_btn != null, "the single child is a Button")
	if exit_btn != null:
		ok = _expect(ok, exit_btn.name == "CultOptionButton0", "the exit is CultOptionButton0 (got %s)" % str(exit_btn.name))
		ok = _expect(ok, exit_btn.visible, "the exit button is visible")
		ok = _expect(ok, exit_btn.text != "", "the exit button carries a label")
	ok = _expect(ok, bool(node.pressed_connected.get("CultOptionButton0", false)), "CultOptionButton0 is wired (pressed_connected true)")
	ok = _expect(ok, node.cursor_markers_visible == false, "no ▶ cursor marker at GONGFA_PICK-empty")
	# The click REALLY transitions phase: emit the button's own pressed signal
	# (the pointer path) and assert the phase diff, not button-existence.
	if exit_btn != null:
		exit_btn.pressed.emit()
	ok = _expect(ok, node.phase == "ACTION_PICK", "clicking the exit really transitions GONGFA_PICK -> ACTION_PICK (got %s)" % str(node.phase))
	_teardown(node)
	return ok


# ---------------------------------------------------------------------------
# Map — traverse TRAVEL / EVENT / FACILITY through the machine's own handlers,
# following the safe facility path wuming_valley -> luoyang -> wudang (never the
# end node kunlun, never the battle node huashan). Each travel button index is
# computed from MapData.neighbors(current).find(target) — never hard-coded.
# ---------------------------------------------------------------------------

func _map_walk() -> bool:
	var ok := true
	_sm.new_profile({}, [])
	_sm.profile.map_node = MapData.start_node()   # wuming_valley
	_gm.current_state = "MAP"
	var map: Node = MAP_SCENE.instantiate()
	root.add_child(map)   # _ready wires the pool + renders; boots TRAVEL
	ok = _map_check(map, ok)                            # TRAVEL at wuming_valley
	# Leg 1: wuming_valley -> luoyang (arrival opens the merchant EVENT).
	var leg1: int = _travel_index(map, "luoyang")
	ok = _expect(ok, leg1 >= 0, "map: luoyang is adjacent from wuming_valley")
	if leg1 >= 0:
		map._on_travel_pressed(leg1)
	ok = _expect(ok, map.phase == "EVENT", "arrival at luoyang opened its EVENT (got %s)" % str(map.phase))
	ok = _expect(ok, _visible_wired(map, MAP_EVENT_KEYS) >= 2, "EVENT offers >=2 wired EventOptionButton")
	ok = _map_check(map, ok)
	map._on_event_option_pressed(0)                    # resolve -> TRAVEL at luoyang
	ok = _expect(ok, map.phase == "TRAVEL", "resolved luoyang EVENT -> TRAVEL (got %s)" % str(map.phase))
	ok = _map_check(map, ok)
	# Leg 2: luoyang -> wudang (facility live; arrival opens its own EVENT).
	var leg2: int = _travel_index(map, "wudang")
	ok = _expect(ok, leg2 >= 0, "map: wudang is adjacent from luoyang")
	if leg2 >= 0:
		map._on_travel_pressed(leg2)
	ok = _expect(ok, map.phase == "EVENT", "arrival at wudang opened its EVENT (got %s)" % str(map.phase))
	ok = _expect(ok, _visible_wired(map, MAP_EVENT_KEYS) >= 2, "EVENT at wudang offers >=2 wired EventOptionButton")
	ok = _map_check(map, ok)
	map._on_event_option_pressed(0)                    # resolve -> TRAVEL at wudang
	ok = _expect(ok, map.phase == "TRAVEL", "resolved wudang EVENT -> TRAVEL (got %s)" % str(map.phase))
	ok = _map_check(map, ok)
	# Facility is live at wudang: the enter click (GATED to TRAVEL + live slot)
	# opens FACILITY; use + leave are the two buttons that make it 100% tappable.
	ok = _expect(ok, MapData.active_facility_id(str(map.current_node_id)) != "", "wudang carries a live facility")
	map._on_facility_enter_pressed()
	ok = _expect(ok, map.phase == "FACILITY", "the enter click opened FACILITY (got %s)" % str(map.phase))
	ok = _expect(ok, _visible_wired(map, MAP_FACILITY_KEYS) >= 2, "FACILITY offers >=2 wired buttons (use + leave)")
	ok = _map_check(map, ok)
	# Fund through the sanctioned debug injection, then use (stays inside).
	map._debug_grant_silver()
	map._on_facility_use_pressed()
	ok = _expect(ok, map.phase == "FACILITY", "a facility use keeps the player inside (got %s)" % str(map.phase))
	ok = _map_check(map, ok)
	# Leave: the touch exit back to TRAVEL.
	map._on_facility_leave_pressed()
	ok = _expect(ok, map.phase == "TRAVEL", "the leave click returned to TRAVEL (got %s)" % str(map.phase))
	ok = _map_check(map, ok)
	_teardown(map)
	return ok


const MAP_EVENT_KEYS: Array = ["EventBox/EventOptionButton0", "EventBox/EventOptionButton1"]
const MAP_FACILITY_KEYS: Array = ["FacilityUseButton", "FacilityLeaveButton"]


## Check the property for the map screen's CURRENT phase.
func _map_check(map: Node, ok: bool) -> bool:
	return _check_choice_state(ok, "map", String(map.phase), _visible_wired(map, MAP_BUTTON_PATHS), bool(map.cursor_markers_visible))


## Index in the current node's neighbour list of `target` (-1 if not adjacent).
func _travel_index(map: Node, target: String) -> int:
	return MapData.neighbors(str(map.current_node_id)).find(target)


## Count of the given scene node paths that are VISIBLE Buttons AND WIRED
## (pressed_connected[name] == true).
func _visible_wired(map: Node, paths: Array) -> int:
	var pc: Dictionary = map.pressed_connected if map.pressed_connected is Dictionary else {}
	var n: int = 0
	for p in paths:
		var b: Node = map.get_node_or_null(String(p))
		if b is Button:
			var btn: Button = b as Button
			if btn.visible and bool(pc.get(str(btn.name), false)):
				n += 1
	return n


# ---------------------------------------------------------------------------
# Sect select — a single machine reachable by reading the wired button pool the
# _ready() constructor left behind (5 sects; _pick() is deliberately NOT called
# because it routes to CULTIVATION).
# ---------------------------------------------------------------------------

func _sect_walk() -> bool:
	var ok := true
	_sm.new_profile({}, [])
	_gm.current_state = "SECT_SELECT"
	var node: Node = SECT_SCENE.instantiate()
	root.add_child(node)   # _ready wires + renders
	var pc: Dictionary = node.pressed_connected if node.pressed_connected is Dictionary else {}
	var n: int = 0
	for i in 5:
		var b: Button = node.get_node_or_null("SectButton%d" % i) as Button
		if b != null and b.visible and bool(pc.get("SectButton%d" % i, false)):
			n += 1
	ok = _check_choice_state(ok, "sect_select", "SECT_CHOOSE", n, bool(node.cursor_markers_visible))
	ok = _expect(ok, n == 5, "sect_select offers all 5 wired visible SectButton (got %d)" % n)
	_teardown(node)
	return ok


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _teardown(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_touch_option_surface_gate: " + msg)
	return false