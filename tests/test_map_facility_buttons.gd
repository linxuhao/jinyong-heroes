## Unit pins for the map screen's CLICK-DELEGATE buttons (touch-reach round).
##
## What this file owns (step2_design §3.3 component D; task card
## map_travel_event_facility_buttons, acceptance item 2):
##   (a) every delegate button is a real scene Button, focus-free (no ui_accept
##       double-fire), and wired — MapScreen.pressed_connected carries all 8 keys
##       as true after _ready();
##   (b) the FACILITY-ENTER GUARD MIRROR, negatively at a node with NO live
##       facility slot: a click changes nothing;
##   (c) the same guard negatively while a modal is up (EVENT) and while already
##       inside the facility (FACILITY) — the phase half of the mirrored gate;
##   (d) the same guard positively: at a node that DOES carry a facility, the
##       click really opens exactly that node's door;
##   (e) TravelButton{i} -> focus + the existing _travel(), including the
##       arrival event firing through the untouched path, and the out-of-range
##       index no-oping;
##   (f) EventOptionButton{i} -> event_focus + the existing _resolve_node_event()
##       (ladder steps once, the modal closes), for BOTH options;
##   (g) FacilityUseButton / FacilityLeaveButton -> the existing _use_facility()
##       / _leave_facility(), with the visibility pool re-syncing on both sides.
##
## WHY THE GUARD IS PROVEN BY EMITTING `pressed` HERE AND NOT ONLY BY A CLICK IN
## THE SCENARIO: `_sync_click_buttons()` deliberately hides the enter door
## exactly where the mirrored guard would refuse it, and the play-test harness
## refuses to aim at an invisible Control at all ("aim: node is not visible in
## tree", measured 2026-08-29). So playtest/map_facility_buttons_click.yaml pins
## the visibility half (no advertised-but-dead door) and this file pins the
## handler half by emitting the signal directly — a refusal no visibility rule
## can mask. The two together are what makes the mirrored gate proven rather
## than asserted in prose.
##
## Contract: plain GDScript (NO extends), top-level `static func run() -> bool`,
## push_error() on failure, print PASS/FAIL at the end, never assert() (stripped
## in release builds). Collected by tests/unit_test_runner.gd's TESTS registry
## (append-only).
##
## Every expected value is DERIVED from MapData / EventData / FacilityData (a
## relational expression against the table), never an absolute game literal —
## so Phase-5 rebalancing and any future re-binding of a node cannot make this
## file lie in either direction.
##
## Hermeticity: like tests/test_map_node_event.gd, the MapScreen legs swap
## SaveManager.profile for a fresh PlayerProfile and restore it; the segment
## resolves the autoload by design, and _travel() / _resolve_node_event() call
## SaveManager.autosave(), which legitimately refuses outside a stable state —
## nothing here asserts last_error / has_save / slot contents. No test travels
## TO an end node (that branch would drive the GameManager/SceneManager FSM);
## the fixtures deliberately avoid it.

const MapData = preload("res://scripts/data/map_data.gd")
const EventData = preload("res://scripts/data/event_data.gd")
const FacilityData = preload("res://scripts/data/facility_data.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")
const MapScene: PackedScene = preload("res://scenes/segments/map.tscn")

## The 8 delegate buttons the surface contract publishes (the
## MapScreen.pressed_connected block in playtest/_common.yaml), as
## key -> node path. Keys are the names the clicks-only spine and the companion
## scenario aim at, so a rename has to move the contract too.
const BUTTON_PATHS: Dictionary = {
	"TravelButton0": "TravelBox/TravelButton0",
	"TravelButton1": "TravelBox/TravelButton1",
	"TravelButton2": "TravelBox/TravelButton2",
	"EventOptionButton0": "EventBox/EventOptionButton0",
	"EventOptionButton1": "EventBox/EventOptionButton1",
	"FacilityEnterButton": "FacilityEnterButton",
	"FacilityUseButton": "FacilityUseButton",
	"FacilityLeaveButton": "FacilityLeaveButton",
}

## A sentinel assigned to facility_result_text by the FACILITY-phase negative
## case. _enter_facility() clears that var (entering is not using), so if the
## sentinel survives the click, _enter_facility() provably did NOT run — the
## only non-vacuous way to show a refused re-entry. ASCII on purpose: the
## §433 copy-location guard and the i18n coverage guard scan for CJK literals,
## and a test fixture is not player copy.
const REENTRY_SENTINEL: String = "SENTINEL-RESULT-LINE"


static func run() -> bool:
	var ok: bool = true
	ok = _test_pressed_connected(ok)
	ok = _test_facility_enter_guard(ok)
	ok = _test_travel_and_event_handlers(ok)
	ok = _test_facility_use_and_leave(ok)
	if ok:
		print("PASS: test_map_facility_buttons")
	else:
		print("FAIL: test_map_facility_buttons")
	return ok


# ---------------------------------------------------------------------------
# (a) wiring: 8 keys, all true; real Buttons; focus off; static labels kept
# ---------------------------------------------------------------------------

static func _test_pressed_connected(ok: bool) -> bool:
	var sm = _save_manager()
	if sm == null:
		return _expect(ok, false, "SaveManager autoload reachable in the unit-test context")
	sm.profile = PlayerProfileScript.new()
	var map = _make_map(sm, "wuming_valley")

	ok = _expect(ok, typeof(map.pressed_connected) == TYPE_DICTIONARY,
			"pressed_connected is a Dictionary (got %s)" % type_string(typeof(map.pressed_connected)))
	var wired = map.pressed_connected
	if typeof(wired) != TYPE_DICTIONARY:
		wired = {}
	ok = _expect(ok, wired.size() == BUTTON_PATHS.size(),
			"pressed_connected carries exactly the %d delegate buttons (got %d: %s)" % [BUTTON_PATHS.size(), wired.size(), str(wired.keys())])
	for key in BUTTON_PATHS:
		var key_name: String = str(key)
		ok = _expect(ok, wired.has(key_name), "pressed_connected declares '%s'" % key_name)
		ok = _expect(ok, wired.get(key_name) == true,
				"pressed_connected['%s'] is true (got %s)" % [key_name, str(wired.get(key_name))])
		# The button is a scene node (stable pool, never add_child per render), a
		# real Button, and unfocusable — focus_mode FOCUS_NONE is what keeps the
		# keyboard branch byte-identical (ui_accept can never reach a button that
		# cannot hold focus, so exactly one dismissal per key press).
		var b: Button = map.get_node_or_null(String(BUTTON_PATHS[key])) as Button
		ok = _expect(ok, b != null, "the scene carries a %s node at '%s'" % [key_name, String(key)])
		if b == null:
			continue
		ok = _expect(ok, b.focus_mode == Control.FOCUS_NONE, "%s is FOCUS_NONE (no ui_accept double-fire)" % key_name)
		ok = _expect(ok, b.mouse_filter != Control.MOUSE_FILTER_IGNORE,
				"%s is not MOUSE_FILTER_IGNORE (an IGNORE anchor is unhittable)" % key_name)

	# The two static labels live in map.tscn ONLY (the §433 copy-location rule):
	# they must be present and distinct without this file naming their Chinese.
	var enter: Button = map.get_node_or_null("FacilityEnterButton") as Button
	var leave: Button = map.get_node_or_null("FacilityLeaveButton") as Button
	ok = _expect(ok, enter != null and leave != null, "enter + leave buttons resolvable for the label pin")
	if enter != null and leave != null:
		ok = _expect(ok, enter.text != "" and leave.text != "",
				"both static facility labels are set in the scene (enter '%s', leave '%s')" % [enter.text, leave.text])
		ok = _expect(ok, enter.text != leave.text, "the two static labels are distinct (not one shared string)")

	_free_map(map)
	sm.profile = PlayerProfileScript.new()
	return ok


# ---------------------------------------------------------------------------
# (b)(c)(d) the FacilityEnterButton guard mirror: two refusals, one real door
# ---------------------------------------------------------------------------

static func _test_facility_enter_guard(ok: bool) -> bool:
	var sm = _save_manager()
	if sm == null:
		return _expect(ok, false, "SaveManager autoload reachable in the unit-test context")
	sm.profile = PlayerProfileScript.new()

	# Fixtures taken from the table, never hard-coded here.
	var open_node: String = _node_with_facility()
	var closed_node: String = _node_without_facility()
	var modal_node: String = _node_with_facility_and_event()
	ok = _expect(ok, open_node != "", "the table has at least one node with a live facility slot")
	ok = _expect(ok, closed_node != "", "the table has at least one non-end node with no live facility slot")
	ok = _expect(ok, modal_node != "", "the table has a node carrying BOTH a live facility and a live event")
	if open_node == "" or closed_node == "" or modal_node == "":
		sm.profile = PlayerProfileScript.new()
		return ok

	# --- (b) NEGATIVE: TRAVEL at a node with no live facility slot ------------
	var map = _make_map(sm, closed_node)
	var enter: Button = map.get_node_or_null("FacilityEnterButton") as Button
	ok = _expect(ok, enter != null, "FacilityEnterButton resolvable")
	if enter == null:
		_free_map(map)
		sm.profile = PlayerProfileScript.new()
		return ok
	ok = _expect(ok, map.phase == "TRAVEL", "fixture: the segment boots in TRAVEL")
	ok = _expect(ok, MapData.active_facility_id(closed_node) == "",
			"fixture: %s declares no live facility (so only the guard can refuse)" % closed_node)
	ok = _expect(ok, enter.visible == false,
			"(b) the door is not even offered where the F key cannot open it")
	var node_before: String = map.current_node_id
	enter.pressed.emit()
	ok = _expect(ok, map.phase == "TRAVEL",
			"(b) refused click changed no phase (got %s)" % str(map.phase))
	ok = _expect(ok, map.facility_id == "",
			"(b) refused click left facility_id empty (got %s)" % str(map.facility_id))
	ok = _expect(ok, map.facility_use_count == 0,
			"(b) refused click used nothing (got %d)" % int(map.facility_use_count))
	ok = _expect(ok, map.current_node_id == node_before,
			"(b) refused click did not move the player (got %s)" % str(map.current_node_id))

	# --- (c1) NEGATIVE: the modal half, at a node whose door DOES exist -------
	# The strongest form of the phase half: the facility slot is live here, so
	# the ONLY reason the click must be refused is phase != "TRAVEL".
	map.current_node_id = modal_node
	map.phase = "EVENT"
	map.event_id = MapData.active_event_id(modal_node)
	map._render()
	ok = _expect(ok, MapData.active_facility_id(modal_node) != "",
			"fixture: %s carries a live facility, so this refusal is the PHASE half" % modal_node)
	ok = _expect(ok, enter.visible == false,
			"(c1) no enter door while a modal event is up")
	enter.pressed.emit()
	ok = _expect(ok, map.phase == "EVENT",
			"(c1) the click never entered FACILITY from the modal (got %s)" % str(map.phase))
	ok = _expect(ok, map.facility_id == "",
			"(c1) facility_id untouched while the modal is up (got %s)" % str(map.facility_id))

	# --- (c2) NEGATIVE: already inside FACILITY, no silent re-entry ----------
	# current_node_id is moved to a DIFFERENT live-facility node first, so an
	# ungated _enter_facility() would visibly change facility_id; the sentinel
	# result line catches the same bug through its reset.
	map.phase = "TRAVEL"
	map.event_id = ""
	enter.pressed.emit()
	ok = _expect(ok, map.phase == "FACILITY",
			"(c2) precondition: in TRAVEL at a live facility the click does open the door")
	ok = _expect(ok, map.facility_id == MapData.active_facility_id(modal_node),
			"(c2) precondition: the door opened is that node's own binding (got %s)" % str(map.facility_id))
	var other_facility: String = _other_node_with_facility(modal_node)
	ok = _expect(ok, other_facility != "",
			"(c2) the table has a second live-facility node for the re-entry probe")
	if other_facility != "" and MapData.active_facility_id(other_facility) != map.facility_id:
		map.facility_result_text = REENTRY_SENTINEL
		map.current_node_id = other_facility
		enter.pressed.emit()
		ok = _expect(ok, map.phase == "FACILITY",
				"(c2) a click inside FACILITY stayed in FACILITY (got %s)" % str(map.phase))
		ok = _expect(ok, map.facility_id != MapData.active_facility_id(other_facility),
				"(c2) refused re-entry did not swap to the other node's facility (got %s)" % str(map.facility_id))
		ok = _expect(ok, map.facility_result_text == REENTRY_SENTINEL,
				"(c2) _enter_facility() provably did not run (its reset would have wiped the sentinel)")
		ok = _expect(ok, map.facility_use_count == 0,
				"(c2) the refused re-entry also used nothing (got %d)" % int(map.facility_use_count))
		map.current_node_id = modal_node

	# --- (d) POSITIVE: the door the guard opens is the same door the key opens
	var leave0: Button = map.get_node_or_null("FacilityLeaveButton") as Button
	if leave0 != null:
		leave0.pressed.emit()
	ok = _expect(ok, map.phase == "TRAVEL", "(d) precondition: the leave click closed the modal")
	map.current_node_id = open_node
	map._render()
	ok = _expect(ok, MapData.active_facility_id(open_node) != "", "fixture: %s has a live facility" % open_node)
	ok = _expect(ok, enter.visible == true,
			"(d) in TRAVEL at a live facility the door IS offered (the round's whole point)")
	enter.pressed.emit()
	ok = _expect(ok, map.phase == "FACILITY",
			"(d) the enter click really opened the facility (got %s)" % str(map.phase))
	ok = _expect(ok, map.facility_id == MapData.active_facility_id(open_node),
			"(d) the facility opened is that node's own binding (got %s)" % str(map.facility_id))
	ok = _expect(ok, map.facility_use_count == 0, "(d) entering is not using")
	_free_map(map)
	sm.profile = PlayerProfileScript.new()
	return ok


# ---------------------------------------------------------------------------
# (e)(f) travel + event-option delegates drive the EXISTING handlers
# ---------------------------------------------------------------------------

static func _test_travel_and_event_handlers(ok: bool) -> bool:
	var sm = _save_manager()
	if sm == null:
		return _expect(ok, false, "SaveManager autoload reachable in the unit-test context")
	sm.profile = PlayerProfileScript.new()

	# A (node -> first-neighbour-with-a-live-event) pair, taken from the table.
	var pair: Array = _travel_pair()
	ok = _expect(ok, pair.size() == 2,
			"the table has a non-end node whose first neighbour carries a live event (travel+modal leg)")
	if pair.size() != 2:
		sm.profile = PlayerProfileScript.new()
		return ok
	var from_id: String = pair[0] as String
	var to_id: String = pair[1] as String

	var map = _make_map(sm, from_id)
	var b0: Button = map.get_node_or_null("TravelBox/TravelButton0") as Button
	var b2: Button = map.get_node_or_null("TravelBox/TravelButton2") as Button
	ok = _expect(ok, b0 != null and b2 != null, "travel pool resolvable")
	if b0 == null or b2 == null:
		_free_map(map)
		sm.profile = PlayerProfileScript.new()
		return ok

	# The pool is 3 wide but the node may have fewer neighbours: only the real
	# ones are offered, and an out-of-range index is a no-op even if the signal
	# is emitted (a hidden button must never teleport the player).
	var nbrs: Array[String] = MapData.neighbors(from_id)
	ok = _expect(ok, b0.visible == true, "the first neighbour is offered in TRAVEL")
	ok = _expect(ok, b0.text != "", "the travel button carries the neighbour's own display name")
	ok = _expect(ok, b2.visible == (nbrs.size() > 2),
			"TravelButton2 exists exactly when there is a third neighbour (nbrs %d)" % nbrs.size())
	ok = _expect(ok, MapData.neighbors(from_id).size() > 0, "fixture: the from-node is not a dead end")

	var resolved_before: int = int(map.events_resolved_count)
	var moved_before: String = map.current_node_id
	b2.pressed.emit()
	ok = _expect(ok, map.current_node_id == moved_before,
			"(e) an out-of-range travel index never moved the player (got %s)" % str(map.current_node_id))
	ok = _expect(ok, map.phase == "TRAVEL", "(e) an out-of-range travel index opened no modal")

	# --- (e) the real travel click -------------------------------------------
	b0.pressed.emit()
	ok = _expect(ok, map.focus_id == to_id,
			"(e) the click focused neighbour 0 (got %s)" % str(map.focus_id))
	ok = _expect(ok, map.current_node_id == to_id,
			"(e) the click travelled to neighbour 0 (got %s)" % str(map.current_node_id))
	ok = _expect(ok, map.phase == "EVENT",
			"(e) the arrival event fired through the untouched path (got %s)" % str(map.phase))
	ok = _expect(ok, map.event_id == MapData.active_event_id(to_id),
			"(e) the event shown is the arrival node's own binding (got %s)" % str(map.event_id))
	ok = _expect(ok, int(map.events_resolved_count) == resolved_before,
			"(e) arriving resolved nothing (ladder still %d)" % resolved_before)

	# The EVENT modal hides the travel pool: no travelling behind a modal.
	var e0: Button = map.get_node_or_null("EventBox/EventOptionButton0") as Button
	var e1: Button = map.get_node_or_null("EventBox/EventOptionButton1") as Button
	ok = _expect(ok, e0 != null and e1 != null, "event option pool resolvable")
	if e0 == null or e1 == null:
		_free_map(map)
		sm.profile = PlayerProfileScript.new()
		return ok
	ok = _expect(ok, e0.visible == true and e1.visible == true,
			"(f) the modal offers both options as buttons")
	ok = _expect(ok, b0.visible == false, "(f) the travel pool is hidden while the modal is up")
	var def0 = EventData.def(map.event_id)
	ok = _expect(ok, def0 != null, "(f) the opened event resolves in EventData")
	if def0 != null:
		ok = _expect(ok, e0.text != "" and e1.text != "",
				"(f) both option buttons carry the row's own labels")
		ok = _expect(ok, e0.text != e1.text, "(f) the two option buttons are not the same label")

	# --- (f) option A: focus 0 + the existing resolve -------------------------
	e0.pressed.emit()
	ok = _expect(ok, map.event_focus == 0, "(f) option A click focused option 0 (got %d)" % int(map.event_focus))
	ok = _expect(ok, map.phase == "TRAVEL", "(f) option A click resolved back to TRAVEL (got %s)" % str(map.phase))
	ok = _expect(ok, map.event_id == "", "(f) the resolved event closed")
	ok = _expect(ok, int(map.events_resolved_count) == resolved_before + 1,
			"(f) the resolve ladder stepped exactly once (%d -> %d)" % [resolved_before, int(map.events_resolved_count)])
	ok = _expect(ok, def0 == null or int(map.last_effect_types.size()) == int(def0.option_a.effects.size()),
			"(f) last_effect_types mirrors option A's own effect count")
	ok = _expect(ok, b0.visible == true, "(f) back in TRAVEL the travel pool is offered again")

	# --- (f2) option B: the index the click carries is the focus it sets ------
	var b_idx: int = _neighbor_with_event_index(map.current_node_id, to_id)
	ok = _expect(ok, b_idx >= 0, "the table has a neighbour (other than where we came from) with a live event")
	if b_idx >= 0:
		var btn_name: String = "TravelBox/TravelButton%d" % b_idx
		var btb: Button = map.get_node_or_null(btn_name) as Button
		ok = _expect(ok, btb != null and btb.visible == true,
				"(f2) TravelButton%d is offered at this node" % b_idx)
		if btb != null:
			var mid_before: String = map.current_node_id
			btb.pressed.emit()
			ok = _expect(ok, map.current_node_id != mid_before,
					"(f2) index %d moved the player to its own neighbour" % b_idx)
			ok = _expect(ok, map.phase == "EVENT",
					"(f2) that arrival opened its bound modal (got %s)" % str(map.phase))
			if map.phase == "EVENT":
				var resolved_mid: int = int(map.events_resolved_count)
				map.event_focus = 0
				e1.pressed.emit()
				ok = _expect(ok, map.event_focus == 1,
						"(f2) option B click carries index 1 into event_focus (got %d)" % int(map.event_focus))
				ok = _expect(ok, map.phase == "TRAVEL", "(f2) option B resolved back to TRAVEL")
				ok = _expect(ok, int(map.events_resolved_count) == resolved_mid + 1,
						"(f2) the second resolve stepped the ladder again (%d -> %d)" % [resolved_mid, int(map.events_resolved_count)])
				ok = _expect(ok, map.event_id == "", "(f2) the second event closed")

	_free_map(map)
	sm.profile = PlayerProfileScript.new()
	return ok


# ---------------------------------------------------------------------------
# (g) facility use + leave delegates
# ---------------------------------------------------------------------------

static func _test_facility_use_and_leave(ok: bool) -> bool:
	var sm = _save_manager()
	if sm == null:
		return _expect(ok, false, "SaveManager autoload reachable in the unit-test context")
	sm.profile = PlayerProfileScript.new()

	var facility_node: String = _node_with_facility()
	ok = _expect(ok, facility_node != "", "the table has a node with a live facility slot")
	if facility_node == "":
		sm.profile = PlayerProfileScript.new()
		return ok
	var fid: String = MapData.active_facility_id(facility_node)
	var fdef = FacilityData.def(fid)
	ok = _expect(ok, fdef != null, "the node's facility binding resolves in FacilityData")
	if fdef == null:
		sm.profile = PlayerProfileScript.new()
		return ok
	# Every expected value derives from the row: price, and the effect types the
	# use must mirror. Nothing here repeats a tuned number.
	var cost: int = FacilityData.silver_cost(fdef)
	var expected_types: Array[String] = []
	for eff in fdef.effects:
		expected_types.append(String(eff.get("type", "none")))
	ok = _expect(ok, cost > 0, "the facility has a positive silver price (got %d)" % cost)

	var map = _make_map(sm, facility_node)
	var use: Button = map.get_node_or_null("FacilityUseButton") as Button
	var leave: Button = map.get_node_or_null("FacilityLeaveButton") as Button
	var enter: Button = map.get_node_or_null("FacilityEnterButton") as Button
	ok = _expect(ok, use != null and leave != null and enter != null, "facility buttons resolvable")
	if use == null or leave == null or enter == null:
		_free_map(map)
		sm.profile = PlayerProfileScript.new()
		return ok
	# In TRAVEL the modal buttons are hidden — and the use button carries the
	# facility's OWN advertised verb the moment the modal is up (runtime text).
	ok = _expect(ok, use.visible == false and leave.visible == false,
			"(g) use/leave are hidden outside the FACILITY phase")

	# Fund through the sanctioned debug injection (it routes the grant through
	# EventLogic — the same pipeline the player's silver effects take — never a
	# bare profile assignment), then enter with a click.
	map._debug_grant_silver()
	ok = _expect(ok, int(map.silver) > cost,
			"(g) the fixture can afford at least one use (silver %d, cost %d)" % [int(map.silver), cost])
	enter.pressed.emit()
	ok = _expect(ok, map.phase == "FACILITY", "(g) the enter click opened the facility")
	ok = _expect(ok, use.visible == true and leave.visible == true,
			"(g) inside FACILITY, use + leave are offered (no dead-end phase on touch)")
	ok = _expect(ok, enter.visible == false,
			"(g) the enter door is hidden while inside (no double-entry)")
	ok = _expect(ok, use.text != "",
			"(g) the use button carries a runtime label of its own")
	# Relational (no CJK retyped here): the click must offer EXACTLY the verb the
	# FACILITY panel advertises with its ▶ marker, so a button that delegated to
	# a different action than the one on screen cannot pass.
	var body_g: Label = map.get_node_or_null("BodyLabel") as Label
	ok = _expect(ok, body_g != null, "(g) BodyLabel resolvable for the advertised-verb probe")
	if body_g != null:
		ok = _expect(ok, String(body_g.text).contains("▶ " + use.text),
				"(g) the use button carries exactly the verb the FACILITY panel advertises (button '%s')" % use.text)

	var uses_before: int = int(map.facility_use_count)
	var silver_before: int = int(map.silver)
	var attr_before: int = int(map.attr_inner) + int(map.attr_bone)
	use.pressed.emit()
	ok = _expect(ok, int(map.facility_use_count) == uses_before + 1,
			"(g) the use click stepped the ladder once (%d -> %d)" % [uses_before, int(map.facility_use_count)])
	ok = _expect(ok, map.facility_result_text != "",
			"(g) the use click produced the visible result line")
	ok = _expect(ok, int(map.silver) < silver_before,
			"(g) the use click spent silver (%d -> %d)" % [silver_before, int(map.silver)])
	ok = _expect(ok, map.last_facility_effect_types == expected_types,
			"(g) last_facility_effect_types mirrors the row's own types (%s)" % str(expected_types))
	ok = _expect(ok, map.phase == "FACILITY", "(g) using keeps the player inside (reusable)")
	var attr_after_use: int = int(map.attr_inner) + int(map.attr_bone)

	# Leave: the touch exit — without this button a phone player who tapped in
	# could only leave with a direction key, i.e. the dead end this round removes.
	leave.pressed.emit()
	ok = _expect(ok, map.phase == "TRAVEL",
			"(g) the leave click is the pointer exit from FACILITY (got %s)" % str(map.phase))
	ok = _expect(ok, map.facility_id == "", "(g) the leave click cleared facility_id")
	ok = _expect(ok, int(map.facility_use_count) == uses_before + 1,
			"(g) leaving never rewinds the use count (got %d)" % int(map.facility_use_count))
	ok = _expect(ok, use.visible == false and leave.visible == false,
			"(g) leaving hides the modal buttons again")
	ok = _expect(ok, enter.visible == true,
			"(g) back in TRAVEL the door is offered again (enter -> use -> leave is a cycle, not a trap)")
	ok = _expect(ok, int(map.silver) < silver_before, "(g) leaving spent no further silver")
	ok = _expect(ok, int(map.attr_inner) + int(map.attr_bone) == attr_after_use,
			"(g) leaving changed no attribute (the use's gain persisted, nothing else moved)")

	# Refusal path stays a refusal through the button too: too poor -> no ladder
	# step, no effect mirror change, no silver spent.
	enter.pressed.emit()
	ok = _expect(ok, map.phase == "FACILITY", "(g) precondition: re-entered for the refusal probe")
	sm.profile.silver = maxi(cost - 1, 0)
	var ref_uses: int = int(map.facility_use_count)
	var ref_silver: int = int(map.silver)
	use.pressed.emit()
	ok = _expect(ok, int(map.facility_use_count) == ref_uses,
			"(g) an unaffordable use did NOT step the ladder (got %d)" % int(map.facility_use_count))
	ok = _expect(ok, int(map.silver) == ref_silver, "(g) an unaffordable use spent no silver")
	ok = _expect(ok, map.facility_result_text != "", "(g) the refusal is a visible line")
	leave.pressed.emit()
	ok = _expect(ok, map.phase == "TRAVEL", "(g) cleanup: left the facility")

	_free_map(map)
	sm.profile = PlayerProfileScript.new()
	return ok


# ---------------------------------------------------------------------------
# fixtures / helpers
# ---------------------------------------------------------------------------

## Instantiate the map segment and run _ready() on it WITHOUT adding it to the
## scene tree (the pattern tests/test_map_node_event.gd established): _ready()
## reads SaveManager.profile.map_node, so the fixture node is set on the profile
## first — exactly how the segment boots for a real player. Wiring the buttons
## through _ready() (not by calling _wire_buttons() directly) is the point: it
## proves the player's path, not the helper's.
static func _make_map(sm, node_id: String) -> Node:
	var prof = PlayerProfileScript.new()
	prof.map_node = node_id
	sm.profile = prof
	var map = MapScene.instantiate()
	map._ready()
	return map


static func _free_map(map: Node) -> void:
	if map != null:
		map.free()


## First node with a live facility slot (table order).
static func _node_with_facility() -> String:
	for nid in MapData.node_ids():
		if MapData.active_facility_id(nid) != "" and not MapData.is_end_node(nid):
			return nid
	return ""


## First node with a live facility slot OTHER than `skip` (the re-entry probe
## needs two different doors, so a silent re-entry would change facility_id).
static func _other_node_with_facility(skip: String) -> String:
	for nid in MapData.node_ids():
		if nid != skip and MapData.active_facility_id(nid) != "" and not MapData.is_end_node(nid):
			return nid
	return ""


## First node with no live facility slot, non-end, and with neighbours (the (b)
## refusal fixture).
static func _node_without_facility() -> String:
	for nid in MapData.node_ids():
		if MapData.active_facility_id(nid) == "" and not MapData.is_end_node(nid) and MapData.neighbors(nid).size() > 0:
			return nid
	return ""


## First node carrying BOTH a live facility and a live event: the fixture where
## only the PHASE half of the guard can refuse the click.
static func _node_with_facility_and_event() -> String:
	for nid in MapData.node_ids():
		if MapData.active_facility_id(nid) != "" and MapData.active_event_id(nid) != "" and not MapData.is_end_node(nid):
			return nid
	return ""


## A [from, to] pair where `from` is a non-end node with a live event on its
## FIRST neighbour (also non-end, so the travel never routes to ENDING).
static func _travel_pair() -> Array:
	for nid in MapData.node_ids():
		if MapData.is_end_node(nid):
			continue
		var nbrs: Array[String] = MapData.neighbors(nid)
		if nbrs.is_empty():
			continue
		var first: String = nbrs[0]
		if MapData.active_event_id(first) != "" and not MapData.is_end_node(first):
			return [nid, first]
	return []


## Index in `from_id`'s neighbour list of the first neighbour that carries a live
## event and is not the node we just came from (`exclude`) and not an end node.
## -1 when the table offers no such leg.
static func _neighbor_with_event_index(from_id: String, exclude: String) -> int:
	var nbrs: Array[String] = MapData.neighbors(from_id)
	for i in range(nbrs.size()):
		var n: String = nbrs[i]
		if n == exclude or MapData.is_end_node(n):
			continue
		if MapData.active_event_id(n) != "":
			return i
	return -1


## The SaveManager autoload instance, resolved dynamically (same pattern as
## tests/test_map_node_event.gd) so this file works as a collected static-run
## unit test in -s mode.
static func _save_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var root_node: Node = (loop as SceneTree).root
	if root_node == null:
		return null
	var node: Node = root_node.get_node_or_null("SaveManager")
	if node == null:
		node = root_node.find_child("SaveManager", true, false)
	return node


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_map_facility_buttons: " + what)
	return ok_so_far and cond
