## Unit pins for the sect-facility data pool (jinyong-facility round).
##
## Covers FacilityData (scripts/data/facility_data.gd):
##   1. schema (TABLE size, def()/for_node() resolution + inert nulls, the
##      closed {silver, attr, practice, none} effect domain)
##   2. silver_cost() self-consistency (a facility has a price; the stated price
##      == abs(sum of that row's NEGATIVE silver effects)). There is deliberately
##      NO requirement that the two rows share a price — pricing is a phase-5
##      numerical lever, not a schema fact.
##   3. EventLogic parity: every row's effects, applied through the SAME
##      pure-static path events use (EventLogic.apply_option_effects on a LOCAL
##      PlayerProfile), deduct silver with the >= 0 clamp and land the attr
##      floor-aware.
##   4. cross-file BINDING-CONSISTENCY (the binding is stored twice — the
##      FacilityDef.node field AND the node's facility slot — so both directions
##      are pinned; a drifted pair must redden here).
##
## Contract: plain GDScript (NO extends), top-level `static func run() -> bool`,
## push_error() on failure, print PASS/FAIL at the end, never assert(). Collected
## by tests/unit_test_runner.gd's TESTS registry (append-only).
##
## Every numeric assert is RELATIVE: expected values derive from the pool row
## itself (cost, target, effect types) — no absolute game-value literals, and no
## assumption that the two rows share a price.

const FacilityDataScript = preload("res://scripts/data/facility_data.gd")
const MapDataScript = preload("res://scripts/data/map_data.gd")
const EventDataScript = preload("res://scripts/data/event_data.gd")
const EventLogicScript = preload("res://scripts/data/event_logic.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")

## The closed effect-type domain (documented in facility_data.gd / event_data.gd).
const CLOSED_DOMAIN: Array[String] = ["silver", "attr", "practice", "none"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_schema(ok)
	ok = _test_silver_cost(ok)
	ok = _test_event_logic_parity(ok)
	ok = _test_binding_consistency(ok)
	if ok:
		print("PASS: test_facility_data")
	else:
		print("FAIL: test_facility_data")
	return ok


# ---------------------------------------------------------------------------
# 1. FacilityData schema
# ---------------------------------------------------------------------------

static func _test_schema(ok: bool) -> bool:
	# (a) exactly two rows this round (少林 + 武当).
	ok = _expect(ok, FacilityDataScript.TABLE.size() == 2,
			"FacilityData.TABLE has exactly 2 rows (got %d)" % FacilityDataScript.TABLE.size())

	# (b) def() resolves the two real ids and is inert (null) on an unknown id.
	ok = _expect(ok, FacilityDataScript.def("shaolin_wooden_men") != null,
			"def('shaolin_wooden_men') resolves")
	ok = _expect(ok, FacilityDataScript.def("wudang_meditation") != null,
			"def('wudang_meditation') resolves")
	ok = _expect(ok, FacilityDataScript.def("nope") == null,
			"def(unknown id) -> null (never crashes)")

	# (c) for_node() resolves the bound node and is null elsewhere.
	var fs = FacilityDataScript.for_node("shaolin")
	ok = _expect(ok, fs != null and fs.id == "shaolin_wooden_men",
			"for_node('shaolin') -> shaolin_wooden_men (got %s)" % (fs.id if fs != null else "<null>"))
	var fw = FacilityDataScript.for_node("wudang")
	ok = _expect(ok, fw != null and fw.id == "wudang_meditation",
			"for_node('wudang') -> wudang_meditation (got %s)" % (fw.id if fw != null else "<null>"))
	ok = _expect(ok, FacilityDataScript.for_node("luoyang") == null,
			"for_node('luoyang') -> null (no facility declared there)")
	ok = _expect(ok, FacilityDataScript.for_node("nope") == null,
			"for_node(unknown) -> null (never crashes)")

	# (d) every effect of every row uses ONLY the closed domain.
	for fdef in FacilityDataScript.all():
		ok = _expect(ok, not fdef.effects.is_empty(),
				"%s carries at least one effect" % fdef.id)
		for eff in fdef.effects:
			var t: String = String(eff.get("type", ""))
			ok = _expect(ok, CLOSED_DOMAIN.has(t),
					"%s effect type '%s' is in the closed domain %s" % [fdef.id, t, str(CLOSED_DOMAIN)])
	return ok


# ---------------------------------------------------------------------------
# 2. silver_cost() self-consistency (per row, no cross-row price equality)
# ---------------------------------------------------------------------------

static func _test_silver_cost(ok: bool) -> bool:
	for fdef in FacilityDataScript.all():
		# Expected price derived from THIS row's own negative silver effects —
		# the very definition silver_cost() implements, restated independently.
		var neg_sum: int = 0
		for eff in fdef.effects:
			if eff.get("type", "") == "silver" and int(eff.get("value", 0)) < 0:
				neg_sum += int(eff.get("value", 0))
		var expected: int = absi(neg_sum)
		var cost: int = FacilityDataScript.silver_cost(fdef)
		ok = _expect(ok, cost > 0, "%s has a price (silver_cost > 0, got %d)" % [fdef.id, cost])
		ok = _expect(ok, cost == expected,
				"%s: silver_cost == abs(sum of its negative silver effects) (got %d, expected %d)" % [fdef.id, cost, expected])
	# (NOTE: no assert that the two rows share a price — pricing is phase-5.)
	# Null input must be inert, never crash.
	ok = _expect(ok, FacilityDataScript.silver_cost(null) == 0, "silver_cost(null) -> 0 (never crashes)")
	return ok


# ---------------------------------------------------------------------------
# 3. EventLogic parity — every row lands through the shared pure-static path
# ---------------------------------------------------------------------------

static func _test_event_logic_parity(ok: bool) -> bool:
	for fdef in FacilityDataScript.all():
		var cost: int = FacilityDataScript.silver_cost(fdef)
		var silver_delta: int = _silver_value(fdef)
		var attr_eff: Dictionary = _find_attr_eff(fdef)
		var attr_target: String = String(attr_eff.get("target", ""))
		var attr_value: int = int(attr_eff.get("value", 0))

		# --- affordable: silver lands its exact (negative) delta, clamped >= 0 ---
		var p = PlayerProfileScript.new()
		p.silver = cost + 1
		var sil_before: int = p.silver
		var attr_before: int = p.get_attr(attr_target) if attr_target != "" else 0
		var opt = EventDataScript.EventOption.new()
		opt.effects.assign(fdef.effects.duplicate(true))
		EventLogicScript.apply_option_effects(p, opt)
		ok = _expect(ok, p.silver == maxi(sil_before + silver_delta, 0),
				"%s silver delta applied (before %d, delta %d, got %d)" % [fdef.id, sil_before, silver_delta, p.silver])
		ok = _expect(ok, p.silver < sil_before,
				"%s's funded use really reduced silver (before %d, got %d)" % [fdef.id, sil_before, p.silver])
		ok = _expect(ok, p.silver >= 0, "%s silver never goes negative" % fdef.id)
		if attr_target != "":
			var expected_attr: int = maxi(attr_before + attr_value, PlayerProfileScript.ATTR_FLOOR)
			ok = _expect(ok, p.get_attr(attr_target) == expected_attr,
					"%s attr '%s' lands floor-aware (before %d, value %d, got %d)" % [fdef.id, attr_target, attr_before, attr_value, p.get_attr(attr_target)])

		# --- unaffordable: the silver branch CLAMPS at 0 (never negative) ---
		# (apply_option_effects is the raw effect path — it has no affordability
		#  gate; map.gd's _use_facility owns the gate. Here we pin only that the
		#  silver branch itself can never drive silver below 0.)
		var p2 = PlayerProfileScript.new()
		p2.silver = maxi(cost - 1, 0)
		var opt2 = EventDataScript.EventOption.new()
		opt2.effects.assign(fdef.effects.duplicate(true))
		EventLogicScript.apply_option_effects(p2, opt2)
		ok = _expect(ok, p2.silver >= 0,
				"%s: a cost the profile cannot pay clamps silver at 0 (never negative, got %d)" % [fdef.id, p2.silver])
	return ok


# ---------------------------------------------------------------------------
# 4. Cross-file binding consistency (both directions)
# ---------------------------------------------------------------------------

static func _test_binding_consistency(ok: bool) -> bool:
	# (a) FacilityData -> MapData: for each TABLE row, the node it names must
	#     actually resolve back to that row's id through the single resolution
	#     point active_facility_id().
	for row in FacilityDataScript.TABLE:
		var rid: String = String(row.get("id", ""))
		var rnode: String = String(row.get("node", ""))
		ok = _expect(ok, MapDataScript.active_facility_id(rnode) == rid,
				"TABLE row '%s' binds node '%s' whose active_facility_id resolves back to it (got '%s')" % [rid, rnode, MapDataScript.active_facility_id(rnode)])

	# (b) MapData -> FacilityData: for every map node with an ACTIVE facility
	#     slot, the stored facility_id must resolve to a real def whose own .node
	#     points back at that node. A half-flipped / drifted pair reddens here.
	for nid in MapDataScript.node_ids():
		var ec: Dictionary = MapDataScript.entry_content(nid)
		var slot: Variant = ec.get("facility", {})
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		if (slot as Dictionary).get("status", "") != "active":
			continue
		var fid: String = String((slot as Dictionary).get("facility_id", ""))
		ok = _expect(ok, fid != "", "%s has an active facility slot with a non-empty facility_id" % nid)
		var fdef = FacilityDataScript.def(fid)
		ok = _expect(ok, fdef != null, "%s facility_id '%s' resolves in FacilityData" % [nid, fid])
		if fdef != null:
			ok = _expect(ok, fdef.node == nid,
					"%s facility_id '%s' binds back to this node (def.node == '%s')" % [nid, fid, fdef.node])
	return ok


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

## Sum of the silver values carried by a facility def's effects.
static func _silver_value(fdef) -> int:
	var total: int = 0
	for eff in fdef.effects:
		if eff.get("type", "") == "silver":
			total += int(eff.get("value", 0))
	return total


## The first "attr" effect Dictionary on a facility def ({} when none).
static func _find_attr_eff(fdef) -> Dictionary:
	for eff in fdef.effects:
		if eff.get("type", "") == "attr":
			return eff
	return {}


static func _expect(ok_so_far: bool, cond: bool, what: String) -> bool:
	if not cond:
		push_error("test_facility_data: " + what)
	return ok_so_far and cond
