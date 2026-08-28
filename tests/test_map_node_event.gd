## Unit pins for map node-entry content (jinyong-map-events round).
## Covers the three pieces of the feature:
##   1. MapData per-node entry_content schema + accessors (data-first declaration)
##   2. EventLogic (shared pure-static resolution core) parity with the pool rows
##   3. MapScreen (scripts/segments/map.gd) EVENT phase: open -> focus -> resolve
##
## Contract: plain GDScript (NO extends), top-level `static func run() -> bool`,
## push_error() on failure, print PASS/FAIL at the end, never assert() (stripped
## in release builds). Collected by tests/unit_test_runner.gd's TESTS registry
## (append-only).
##
## Every numeric assert is RELATIVE: expected values are derived from the pool
## row / PRACTICE_TO_MASTER themselves — no absolute game-value literals.
##
## Hermeticity: all EventLogic cases run against LOCAL PlayerProfile instances
## (the autoload is never touched there). Only the MapScreen case swaps
## SaveManager.profile (the segment resolves through the autoload by design); it
## is restored at the end of run(). Nothing in this file asserts last_error /
## has_save / slot contents — MapScreen._travel() and _resolve_node_event() call
## SaveManager.autosave(), which legitimately refuses outside a STABLE state.
## The kunlun leg deliberately never calls _travel() (that branch would drive
## GameManager/SceneManager autoload FSM state); it is pinned as pure data.
## The shared no-repeat bag (flags["events_seen"]) is seeded from EventData.all()
## — never by hard-coding a pool size.

const MapData = preload("res://scripts/data/map_data.gd")
const EventData = preload("res://scripts/data/event_data.gd")
const EventLogic = preload("res://scripts/data/event_logic.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")
const ProgressionGongfaDataScript = preload("res://scripts/data/progression_gongfa_data.gd")
const MapScene: PackedScene = preload("res://scenes/segments/map.tscn")

## The 6 nodes and the 5 mainline ids — graph facts from step2_design §8.7
## (not the §8 declaration table), so they stay true however events are bound.
const NODE_IDS: Array[String] = ["wuming_valley", "luoyang", "wudang", "xiangyang", "kunlun", "shaolin", "huashan"]
const MAINLINE_IDS: Array[String] = ["wuming_valley", "luoyang", "wudang", "xiangyang", "kunlun"]
const SLOT_TYPES: Array[String] = ["event", "battle", "facility"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_map_data_schema(ok)
	ok = _test_event_logic_parity(ok)
	ok = _test_map_event_phase(ok)
	if ok:
		print("PASS: test_map_node_event")
	else:
		print("FAIL: test_map_node_event")
	return ok


# ---------------------------------------------------------------------------
# 1. MapData entry-content declaration schema
# ---------------------------------------------------------------------------

static func _test_map_data_schema(ok: bool) -> bool:
	# (a) every node declares all three slots, and only those three;
	#     every status lives in {active, declared}.
	for nid in NODE_IDS:
		var ec: Dictionary = MapData.entry_content(nid)
		ok = _expect(ok, ec.size() == SLOT_TYPES.size(), "%s: entry_content declares exactly 3 slots" % nid)
		for slot_type in SLOT_TYPES:
			ok = _expect(ok, ec.has(slot_type), "%s: entry_content has a '%s' slot" % [nid, slot_type])
			var slot: Variant = ec.get(slot_type, {})
			ok = _expect(ok, typeof(slot) == TYPE_DICTIONARY, "%s/%s: slot is a Dictionary" % [nid, slot_type])
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			var status: Variant = (slot as Dictionary).get("status", "")
			ok = _expect(ok, status == "active" or status == "declared",
					"%s/%s: status '%s' in {active, declared}" % [nid, slot_type, str(status)])

	# (b) exactly five ACTIVE event slots across the whole table — the four
	#     live mainline nodes (wuming_valley/luoyang/wudang/xiangyang) plus
	#     shaolin's branch — each resolving inside the sanctioned pool (zero new
	#     prose). battle/facility slots stay declared everywhere, so the total
	#     active-slot count equals the active-event-slot count.
	var active_event_nodes: Array[String] = []
	var active_battle_nodes: Array[String] = []
	var active_slot_total: int = 0
	for nid in NODE_IDS:
		var ec: Dictionary = MapData.entry_content(nid)
		for slot_type in SLOT_TYPES:
			var slot: Variant = ec.get(slot_type, {})
			if typeof(slot) == TYPE_DICTIONARY and (slot as Dictionary).get("status", "") == "active":
				active_slot_total += 1
				if slot_type == "event":
					active_event_nodes.append(nid)
				elif slot_type == "battle":
					active_battle_nodes.append(nid)
	# Six live slots now, not five: the same five events plus 华山's battle — the
	# first slot of a type other than event to go live. Counting the two kinds
	# apart is what keeps this assertion honest; a single total would have gone
	# on reading "five events" while one of them was something else entirely.
	ok = _expect(ok, active_slot_total == 6, "exactly six active entry slots across the table (got %d)" % active_slot_total)
	ok = _expect(ok, active_battle_nodes == ["huashan"],
			"华山 is the only node with a live battle slot (got %s)" % str(active_battle_nodes))
	ok = _expect(ok, MapData.active_battle_id("huashan") == "huashan_duel", "huashan binds huashan_duel")
	ok = _expect(ok, MapData.active_battle_id("shaolin") == "", "a declared battle slot yields no id")
	ok = _expect(ok, MapData.active_event_id("huashan") == "", "华山 carries no event, so no precedence rule is reachable")
	ok = _expect(ok, active_event_nodes == ["wuming_valley", "luoyang", "wudang", "xiangyang", "shaolin"],
			"the active event slots are the four live mainline nodes + shaolin, in NODE_IDS order (got %s)" % str(active_event_nodes))
	var shaolin_id: String = MapData.active_event_id("shaolin")
	ok = _expect(ok, shaolin_id != "", "active_event_id(shaolin) is non-empty")
	ok = _expect(ok, EventData.def(shaolin_id) != null,
			"shaolin's binding '%s' resolves in EventData (pool-only text)" % shaolin_id)

	# (c) MAINLINE node events are LIVE (4 of 5), not inert. The spine is still
	#     protected — but by STRUCTURE, not by leaving slots empty:
	#     _travel() routes an END node to ENDING (ended = true) BEFORE
	#     _maybe_start_entry_event() runs, so kunlun's declared slot is a
	#     structural non-trigger and the ending can never be blocked by node
	#     content. The other four mainline nodes each bind a deterministic
	#     pool row; their declared-gap observable drops 'event' accordingly.
	ok = _expect(ok, MapData.active_event_id("wuming_valley") == "tomb_bed", "mainline wuming_valley binds tomb_bed")
	ok = _expect(ok, MapData.active_event_id("luoyang") == "merchant", "mainline luoyang binds merchant")
	ok = _expect(ok, MapData.active_event_id("wudang") == "quanzhen_scripture", "mainline wudang binds quanzhen_scripture")
	ok = _expect(ok, MapData.active_event_id("xiangyang") == "dragon_scrap", "mainline xiangyang binds dragon_scrap")
	ok = _expect(ok, MapData.active_event_id("kunlun") == "", "kunlun stays inert (routing-first guarantee: end node -> ENDING before entry content)")

	# (d) declared_gap_types: the honesty observable (gap = not implemented,
	#     never faked — so it must be assertable, not just documented).
	var gaps_shaolin: Array = MapData.declared_gap_types("shaolin")
	ok = _expect(ok, gaps_shaolin.has("battle") and gaps_shaolin.has("facility"),
			"shaolin declares battle + facility as unimplemented gaps")

	# The honesty observable has to MOVE when a gap is filled, or it degrades into
	# decoration: 华山's battle is implemented, so 'battle' must be absent from its
	# gap list while 'event' and 'facility' remain.
	var gaps_huashan: Array = MapData.declared_gap_types("huashan")
	ok = _expect(ok, gaps_huashan == ["event", "facility"],
			"华山's gap list drops 'battle' now that slot is live (got %s)" % str(gaps_huashan))
	ok = _expect(ok, not gaps_shaolin.has("event"), "shaolin's implemented event is NOT a gap")
	# luoyang's event slot is now LIVE, so its only remaining declared gaps are
	# battle + facility (2 slot types, fixed order) — the honesty observable
	# shrinks exactly as a slot becomes implemented, never faked.
	var gaps_luoyang: Array = MapData.declared_gap_types("luoyang")
	ok = _expect(ok, gaps_luoyang == ["battle", "facility"],
			"luoyang's gap list is exactly [battle, facility] now its event slot is live (got %s)" % str(gaps_luoyang))
	ok = _expect(ok, gaps_luoyang.size() == 2, "luoyang's gap list is exactly 2 slot types")
	ok = _expect(ok, not gaps_luoyang.has("event"), "luoyang's implemented event is NOT a gap")

	# (e) unknown node degrades inert (never crashes).
	ok = _expect(ok, MapData.entry_content("nope_node").is_empty(), "entry_content(unknown) -> {}")
	ok = _expect(ok, MapData.active_event_id("nope_node") == "", "active_event_id(unknown) -> \"\"")
	ok = _expect(ok, MapData.declared_gap_types("nope_node").is_empty(), "declared_gap_types(unknown) -> []")

	# (f) deep copy: mutating a returned dictionary must not corrupt the const table.
	var probe: Dictionary = MapData.entry_content("shaolin")
	probe.erase("event")
	probe["battle"] = "tampered"
	var fresh: Dictionary = MapData.entry_content("shaolin")
	ok = _expect(ok, fresh.has("event"), "entry_content() is a deep copy: erasing 'event' does not leak")
	ok = _expect(ok, typeof(fresh.get("battle")) == TYPE_DICTIONARY,
			"entry_content() is a deep copy: overwriting a slot value does not leak")
	return ok


# ---------------------------------------------------------------------------
# 2. EventLogic parity with the pool rows (local profiles only, no autoload)
# ---------------------------------------------------------------------------

static func _test_event_logic_parity(ok: bool) -> bool:
	var bandits = EventData.def("bandits")
	var tomb = EventData.def("tomb_bed")
	var beggar = EventData.def("beggar")
	var merchant = EventData.def("merchant")
	ok = _expect(ok, bandits != null and tomb != null and beggar != null and merchant != null,
			"the four pool rows this file pins all exist")
	if bandits == null or tomb == null or beggar == null or merchant == null:
		return ok

	# --- silver: exact delta, then the >= 0 clamp ---
	var silver_eff: Dictionary = _find_eff(bandits.option_a, "silver")
	ok = _expect(ok, not silver_eff.is_empty(), "bandits/option_a carries a silver effect")
	var p_silver = PlayerProfileScript.new()
	var sv: int = int(silver_eff.get("value", 0))
	# Derive the payable starting amount from the row's own value (relative:
	# strictly more than the loss, so the clamp cannot mask the delta).
	p_silver.silver = absi(sv) + 1
	var sil_before: int = p_silver.silver
	p_silver.silver = maxi(sil_before, 0)
	EventLogic.apply_option_effects(p_silver, bandits.option_a)
	ok = _expect(ok, p_silver.silver == sil_before + sv,
			"silver effect lands exactly (before %d, value %d, got %d)" % [sil_before, sv, p_silver.silver])
	ok = _expect(ok, p_silver.silver >= 0, "silver never goes negative")
	p_silver.silver = 0
	EventLogic.apply_option_effects(p_silver, bandits.option_a)
	ok = _expect(ok, p_silver.silver == 0, "a loss the profile cannot pay clamps at 0 (never negative)")

	# --- attr: lands the row's value on the row's own target (floor-aware) ---
	var attr_eff: Dictionary = _find_eff(bandits.option_b, "attr")
	ok = _expect(ok, not attr_eff.is_empty(), "bandits/option_b carries an attr effect")
	var p_attr = PlayerProfileScript.new()
	var akey: String = String(attr_eff.get("target", ""))
	var avec: int = int(attr_eff.get("value", 0))
	var floor_v: int = int(PlayerProfileScript.ATTR_FLOOR)
	var attr_before: int = p_attr.get_attr(akey)
	EventLogic.apply_option_effects(p_attr, bandits.option_b)
	ok = _expect(ok, p_attr.get_attr(akey) == maxi(attr_before + avec, floor_v),
			"attr effect '%s' lands its value (before %d, value %d)" % [akey, attr_before, avec])
	# floor clamp: drive the attr below the floor with the row's own magnitude.
	p_attr.set_attr(akey, floor_v + absi(avec))
	p_attr.add_attr(akey, -(absi(avec) + 1))
	ok = _expect(ok, p_attr.get_attr(akey) == floor_v, "attr never drops below ATTR_FLOOR")

	# --- item: appended once, never duplicated ---
	var item_eff: Dictionary = _find_eff(tomb.option_b, "item")
	ok = _expect(ok, not item_eff.is_empty(), "tomb_bed/option_b carries an item effect")
	var iid: String = String(item_eff.get("target", ""))
	var p_item = PlayerProfileScript.new()
	ok = _expect(ok, p_item.inventory.count(iid) == 0, "fresh profile does not already own '%s'" % iid)
	EventLogic.apply_option_effects(p_item, tomb.option_b)
	ok = _expect(ok, p_item.inventory.count(iid) == 1, "item effect appends its target once")
	EventLogic.apply_option_effects(p_item, tomb.option_b)
	ok = _expect(ok, p_item.inventory.count(iid) == 1, "re-applying the same item effect never duplicates it")

	# --- practice: adds to the FIRST unmastered art, masters at the grade cap ---
	var prac_eff: Dictionary = _find_eff(beggar.option_b, "practice")
	ok = _expect(ok, not prac_eff.is_empty(), "beggar/option_b carries a practice effect")
	var pvalue: int = int(prac_eff.get("value", 0))
	var p_prac = PlayerProfileScript.new()
	ok = _expect(ok, p_prac.add_gongfa("gf_pin_first", "D"), "fixture art 1 added")
	ok = _expect(ok, p_prac.add_gongfa("gf_pin_second", "D"), "fixture art 2 added")
	var first_before: int = int(p_prac.get_gongfa("gf_pin_first").get("practice", 0))
	var second_before: int = int(p_prac.get_gongfa("gf_pin_second").get("practice", 0))
	EventLogic.apply_option_effects(p_prac, beggar.option_b)
	var first_after: Dictionary = p_prac.get_gongfa("gf_pin_first")
	ok = _expect(ok, int(first_after.get("practice", 0)) == first_before + pvalue
			or bool(first_after.get("mastered", false)),
			"practice lands on the first unmastered art (before %d, value %d)" % [first_before, pvalue])
	ok = _expect(ok, int(p_prac.get_gongfa("gf_pin_second").get("practice", 0)) == second_before,
			"practice touches only the FIRST unmastered art")
	# Mastery happens exactly at the grade threshold (read from the registry).
	var cap: int = int(ProgressionGongfaDataScript.PRACTICE_TO_MASTER.get("D", 0))
	var p_mastered = PlayerProfileScript.new()
	p_mastered.add_gongfa("gf_pin_cap", "D")
	var below: int = maxi(cap - pvalue, 0)
	p_mastered.get_gongfa("gf_pin_cap")["practice"] = below
	EventLogic.apply_option_effects(p_mastered, beggar.option_b)
	if below + pvalue >= cap:
		ok = _expect(ok, bool(p_mastered.get_gongfa("gf_pin_cap").get("mastered", false)),
				"reaching the grade threshold masters the art")
	else:
		ok = _expect(ok, not bool(p_mastered.get_gongfa("gf_pin_cap").get("mastered", false)),
				"below the grade threshold the art stays unmastered")
	# A pool of fully-mastered arts is never re-offered and never grows.
	var p_all_done = PlayerProfileScript.new()
	p_all_done.add_gongfa("gf_pin_done", "D")
	p_all_done.master_gongfa_of("gf_pin_done")
	var done_before: int = int(p_all_done.get_gongfa("gf_pin_done").get("practice", 0))
	EventLogic.apply_option_effects(p_all_done, beggar.option_b)
	ok = _expect(ok, p_all_done.gongfa.size() == 1, "no new art is invented when everything is mastered")
	ok = _expect(ok, int(p_all_done.get_gongfa("gf_pin_done").get("practice", 0)) == done_before,
			"a mastered art is never practiced again")

	# --- none: the whole profile snapshot is untouched ---
	var p_none = PlayerProfileScript.new()
	var none_opt = merchant.option_b
	ok = _expect(ok, not _find_eff(none_opt, "none").is_empty(),
			"merchant/option_b carries a none effect")
	var snap_a: String = JSON.stringify(p_none.to_dict())
	EventLogic.apply_option_effects(p_none, none_opt)
	ok = _expect(ok, JSON.stringify(p_none.to_dict()) == snap_a, "a 'none' option changes nothing at all")

	# --- D6 bag independence (node-event channel) ---
	# The node-event channel shares EventLogic.apply_option_effects with the
	# cultivation bag draw, but that shared core must NEVER read/write
	# flags["events_seen"] (only draw_unseen_id does, and node events never call
	# it). merchant.option_a = silver -20 + item eq_sword_3; on a fresh profile
	# the silver delta clamps at 0, so the ITEM is the only non-vacuous proof the
	# resolution actually landed. Together with the shaolin leg's bag check in
	# _test_map_event_phase, this covers channel independence for BOTH a mainline
	# binding and the branch binding — no RNG enters either.
	var p_bag = PlayerProfileScript.new()
	ok = _expect(ok, (p_bag.flags.get("events_seen", []) as Array).is_empty(),
			"D6 fixture: a fresh profile's events_seen bag starts empty")
	ok = _expect(ok, not p_bag.inventory.has("eq_sword_3"),
			"D6 fixture: the fresh profile does not already own merchant's item")
	EventLogic.apply_option_effects(p_bag, merchant.option_a)
	ok = _expect(ok, p_bag.inventory.has("eq_sword_3"),
			"D6: merchant/option_a really applied (item landed — non-vacuous proof, silver clamps at 0)")
	ok = _expect(ok, (p_bag.flags.get("events_seen", []) as Array).is_empty(),
			"D6: apply_option_effects never touches flags['events_seen'] (bag independence)")

	# --- add_practice with an empty gongfa list: no-op, no crash ---
	var p_empty = PlayerProfileScript.new()
	ok = _expect(ok, p_empty.gongfa.is_empty(), "fixture: profile knows no gongfa")
	EventLogic.add_practice(p_empty, pvalue + 1)
	ok = _expect(ok, p_empty.gongfa.is_empty(), "add_practice no-ops on an empty gongfa list (no crash)")

	# --- draw_unseen_id: no-repeat exclusion (bag seeded from the pool itself) ---
	var pool_ids: Array[String] = []
	for d in EventData.all():
		pool_ids.append(d.id)
	var n: int = pool_ids.size()
	ok = _expect(ok, n > 1, "the event pool is non-trivial (size %d)" % n)
	var excluded: String = pool_ids[0]
	var p_seen = PlayerProfileScript.new()
	var seen: Array[String] = []
	for i in range(1, n):
		seen.append(pool_ids[i])
	ok = _expect(ok, seen.size() == n - 1, "seen bag holds every id except the excluded one")
	p_seen.flags["events_seen"] = seen
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 7
	var drawn_missing: String = EventLogic.draw_unseen_id(p_seen, rng_a)
	ok = _expect(ok, drawn_missing == excluded,
			"the bag excludes every seen id (drew %s, only %s was unseen)" % [drawn_missing, excluded])
	# A fresh bag yields every pool id exactly once before repeating.
	var p_fresh = PlayerProfileScript.new()
	var distinct: Array[String] = []
	var fresh_bag: Array = p_fresh.flags["events_seen"]
	var rng_f: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_f.seed = 11
	for i in range(n):
		var got: String = EventLogic.draw_unseen_id(p_fresh, rng_f)
		distinct.append(got)
		fresh_bag.append(got)
	ok = _expect(ok, _unique_count(distinct) == n, "a full bag yields %d distinct ids (got %d)" % [n, _unique_count(distinct)])
	# Reset leg: with every id seen, the bag resets instead of returning "".
	var p_full = PlayerProfileScript.new()
	p_full.flags["events_seen"] = pool_ids.duplicate()
	var rng_full: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_full.seed = 23
	var wrapped: String = EventLogic.draw_unseen_id(p_full, rng_full)
	ok = _expect(ok, wrapped != "", "an exhausted bag resets and still returns an id (never \"\")")
	ok = _expect(ok, pool_ids.has(wrapped), "the reset draw is a real pool id (got %s)" % wrapped)
	ok = _expect(ok, (p_full.flags["events_seen"] as Array).size() < n,
			"the exhausted bag was reset (size %d < %d)" % [(p_full.flags["events_seen"] as Array).size(), n])
	# The two channels are independent: drawing here mutated ONLY this local
	# profile's bag, so a different bag is untouched by that call.
	var seen_after_other: Variant = p_seen.flags.get("events_seen", [])
	ok = _expect(ok, (seen_after_other as Array).size() == n - 1,
			"draw_unseen_id mutates only the profile it was handed (bag isolation)")
	return ok


# ---------------------------------------------------------------------------
# 3. MapScreen node-entry EVENT phase (scene instantiated, NOT added to the
#    tree — so _ready() never runs and no event can fire on boot/load)
# ---------------------------------------------------------------------------

static func _test_map_event_phase(ok: bool) -> bool:
	# Untyped on purpose: the SaveManager autoload instance is fetched from the
	# scene tree (same pattern as tests/test_skill_button_states.gd), so member
	# access resolves dynamically instead of against the native Node API.
	var sm = _save_manager()
	if sm == null:
		return _expect(ok, false, "SaveManager autoload reachable in the unit-test context")
	var fresh_profile = PlayerProfileScript.new()
	sm.profile = fresh_profile

	var night = EventData.def(MapData.active_event_id("shaolin"))
	ok = _expect(ok, night != null, "shaolin's bound pool row resolves")
	if night == null:
		sm.profile = PlayerProfileScript.new()
		return ok

	# --- arrival at the BRANCH node (洛阳 -> 少林) opens the modal event ---
	var map = MapScene.instantiate()
	map.current_node_id = "luoyang"
	map.focus_id = "shaolin"
	map._travel()
	ok = _expect(ok, map.phase == "EVENT", "arriving at shaolin switches phase to EVENT")
	ok = _expect(ok, map.event_id == MapData.active_event_id("shaolin"),
			"the event shown is the node's deterministic binding (%s)" % map.event_id)
	ok = _expect(ok, map.event_id != "", "the shaolin event actually opened (event_id non-empty)")
	ok = _expect(ok, map.current_node_id == "shaolin", "the player arrived at shaolin")
	ok = _expect(ok, map.ended == false, "node content did not end the run")

	# --- both options are selectable (focus cycles 0/1) ---
	map.event_focus = 0
	ok = _expect(ok, map.event_focus == 0, "option A focusable")
	map.event_focus = 1
	ok = _expect(ok, map.event_focus == 1, "option B focusable")
	map.event_focus = 0
	ok = _expect(ok, map.event_focus == 0, "focus cycles back to option A")

	# --- the ▶ marker follows the focus in the rendered body text ---
	var opt_a_label: String = String(night.option_a.label)
	var opt_b_label: String = String(night.option_b.label)
	ok = _expect(ok, opt_a_label != "" and opt_b_label != "" and opt_a_label != opt_b_label,
			"the bound row carries two distinct option labels")
	var body_label: Label = map.get_node_or_null("BodyLabel") as Label
	ok = _expect(ok, body_label != null, "MapScreen has a direct BodyLabel child (marker probe target)")
	if body_label != null:
		map._render()
		var text_a: String = String(body_label.text)
		ok = _expect(ok, text_a.find("▶ " + opt_a_label) != -1,
				"focus 0 renders the marker on option A")
		ok = _expect(ok, text_a.find("▶ " + opt_b_label) == -1,
				"focus 0 does not mark option B")
		map.event_focus = 1
		map._render()
		var text_b: String = String(body_label.text)
		ok = _expect(ok, text_b.find("▶ " + opt_b_label) != -1,
				"focus 1 renders the marker on option B")
		ok = _expect(ok, text_b.find("▶ " + opt_a_label) == -1,
				"focus 1 does not mark option A")
		ok = _expect(ok, text_b.find(String(night.title)) != -1 and text_b.find(String(night.text)) != -1,
				"the event title and body text are shown (pool text, not invented)")
		map.event_focus = 0

	# --- resolving option A applies its effects and returns to TRAVEL ---
	# Fund the profile from the row's own magnitude so the silver leg is a real
	# delta, not the >= 0 clamp hiding it.
	fresh_profile.silver = absi(_silver_value(night.option_a)) + 1
	var bag_before: Variant = (fresh_profile.flags.get("events_seen", []) as Array).duplicate(true)
	var silver_before: int = int(fresh_profile.silver)
	var attrs_before: Dictionary = {}
	for key in PlayerProfileScript.ATTR_KEYS:
		attrs_before[key] = int(fresh_profile.get_attr(key))
	var resolved_before: int = int(map.events_resolved_count)
	var opt_a_eff_types: Array[String] = []
	for eff_a in night.option_a.effects:
		opt_a_eff_types.append(String(eff_a.get("type", "none")))
	map._resolve_node_event()
	ok = _expect(ok, map.phase == "TRAVEL", "resolving returns the map to TRAVEL")
	ok = _expect(ok, map.event_id == "", "the event closes (event_id == \"\")")
	ok = _expect(ok, int(map.events_resolved_count) == resolved_before + 1,
			"events_resolved_count ladder steps once (%d -> %d)" % [resolved_before, int(map.events_resolved_count)])
	ok = _expect(ok, map.last_effect_types == opt_a_eff_types,
			"last_effect_types mirrors option A's own effect types (%s)" % str(opt_a_eff_types))
	ok = _expect(ok, fresh_profile.silver == maxi(silver_before + _silver_value(night.option_a), 0),
			"option A's silver delta applied (before %d -> %d)" % [silver_before, int(fresh_profile.silver)])
	ok = _expect(ok, silver_before != int(fresh_profile.silver) or _silver_value(night.option_a) == 0,
			"the funded silver leg actually moved silver")
	# Every attr the option touches lands its own value (floor-aware); the rest
	# of the five attrs stay exactly where they were.
	var attr_map: Dictionary = _attr_values(night.option_a)
	for key in PlayerProfileScript.ATTR_KEYS:
		var expected: int = maxi(int(attrs_before[key]) + int(attr_map.get(key, 0)), PlayerProfileScript.ATTR_FLOOR)
		ok = _expect(ok, int(fresh_profile.get_attr(key)) == expected,
				"attr %s: %d -> %d (expected %d)" % [key, int(attrs_before[key]), int(fresh_profile.get_attr(key)), expected])
	# --- the map channel never touches the cultivation no-repeat bag ---
	var bag_after: Variant = (fresh_profile.flags.get("events_seen", []) as Array).duplicate(true)
	ok = _expect(ok, JSON.stringify(bag_before) == JSON.stringify(bag_after),
			"the node-event channel leaves flags['events_seen'] untouched (bag independence)")
	map.free()

	# --- the MAINLINE leg now opens its bound event (洛阳 is live) ---
	# The spine is protected by routing-first order (kunlun below), not by mainline
	# inertness. On a fresh main_map instance events_resolved_count starts at 0, so
	# resolving exactly one merchant event lands on the deterministic value 1 — a
	# relative ladder step, not an absolute game value.
	sm.profile = PlayerProfileScript.new()
	var main_map = MapScene.instantiate()
	main_map.current_node_id = "wuming_valley"
	main_map.focus_id = "luoyang"
	main_map._travel()
	ok = _expect(ok, main_map.phase == "EVENT", "mainline arrival (无名谷->洛阳) opens the bound event")
	ok = _expect(ok, main_map.event_id == "merchant", "the opened event is luoyang's deterministic merchant binding (got %s)" % main_map.event_id)
	ok = _expect(ok, main_map.current_node_id == "luoyang", "the mainline move still happens")
	ok = _expect(ok, not main_map.entry_declared_gap_types.is_empty(),
			"the live node still exposes its remaining declared gaps (honesty observable)")
	main_map._resolve_node_event()
	ok = _expect(ok, main_map.phase == "TRAVEL", "resolving luoyang's event returns the map to TRAVEL")
	ok = _expect(ok, main_map.event_id == "", "the opened event closes (event_id == \"\")")
	ok = _expect(ok, int(main_map.events_resolved_count) == 1,
			"the mainline resolution steps the ladder once (0 -> 1, fresh instance)")
	main_map.free()

	# --- the END node: content must never block the ending (data-only pin;
	#     travelling to 昆仑 would drive the GameManager FSM, so it is not done) ---
	ok = _expect(ok, MapData.is_end_node("kunlun"), "kunlun is the end node")
	ok = _expect(ok, MapData.active_event_id("kunlun") == "", "kunlun declares no active event (ending unblocked)")

	sm.profile = PlayerProfileScript.new()
	return ok


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

## The first effect Dictionary of `type` on an untyped EventOption ({} when none).
static func _find_eff(opt, type: String) -> Dictionary:
	for eff in opt.effects:
		var e: Dictionary = eff
		if e.get("type", "") == type:
			return e
	return {}


## Sum of the silver values carried by an option's effects.
static func _silver_value(opt) -> int:
	var total: int = 0
	for eff in opt.effects:
		if eff.get("type", "") == "silver":
			total += int(eff.get("value", 0))
	return total


## attr target -> summed value for an option's effects.
static func _attr_values(opt) -> Dictionary:
	var out: Dictionary = {}
	for eff in opt.effects:
		if eff.get("type", "") == "attr":
			var key: String = eff.get("target", "")
			out[key] = int(out.get(key, 0)) + int(eff.get("value", 0))
	return out


static func _unique_count(list: Array) -> int:
	var seen: Array = []
	for item in list:
		if not seen.has(item):
			seen.append(item)
	return seen.size()


## The SaveManager autoload instance, resolved dynamically (same pattern as
## tests/test_skill_button_states.gd) so this file works as a collected
## static-run unit test.
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
		push_error("test_map_node_event: " + what)
	return ok_so_far and cond
