## Unit tests for scripts/data/equipment_data.gd (EquipmentData).
## Contract: top-level static func run() -> bool; push_error on failure;
## never relies on assert() (stripped in release). Collected by
## tests/unit_test_runner.gd.
##
## Covers the full static API: slot_of / tier_of / bonuses_for / sum_bonuses,
## the direction matrix, monotonicity in tier, and hostile-value handling.
## NOTE: all locals are explicitly typed — never use `:=` on a Dictionary/
## Array literal with heterogeneous values (GDScript cannot infer such a type).

static func run() -> bool:
	var ok := true
	ok = _test_slot_of(ok)
	ok = _test_tier_of(ok)
	ok = _test_bonuses_for_direction(ok)
	ok = _test_monotonicity(ok)
	ok = _test_sum_bonuses(ok)
	if ok:
		print("PASS test_equipment_data")
	else:
		print("FAIL test_equipment_data")
	return ok


# --- slot_of ------------------------------------------------------------------

static func _test_slot_of(ok: bool) -> bool:
	# all 12 equipment cards -> their slot
	for i in range(1, 5):
		ok = _expect(ok, EquipmentData.slot_of("eq_sword_%d" % i) == "weapon", "slot_of sword %d" % i)
		ok = _expect(ok, EquipmentData.slot_of("eq_armor_%d" % i) == "armor", "slot_of armor %d" % i)
		ok = _expect(ok, EquipmentData.slot_of("eq_boots_%d" % i) == "boots", "slot_of boots %d" % i)
	# non-equipment / malformed ids -> ""
	ok = _expect(ok, EquipmentData.slot_of("") == "", "slot_of empty string")
	ok = _expect(ok, EquipmentData.slot_of("eq_axe_1") == "", "slot_of unknown prefix")
	ok = _expect(ok, EquipmentData.slot_of("eq_sword") == "", "slot_of missing tier suffix")
	ok = _expect(ok, EquipmentData.slot_of("qingfeng_sword") == "", "slot_of unrelated id")
	return ok


# --- tier_of ------------------------------------------------------------------

static func _test_tier_of(ok: bool) -> bool:
	for i in range(1, 5):
		ok = _expect(ok, EquipmentData.tier_of("eq_sword_%d" % i) == i, "tier_of %d" % i)
	# out of range / malformed -> 0 (silent, never push_error)
	ok = _expect(ok, EquipmentData.tier_of("eq_sword_9") == 0, "tier_of 9 -> 0")
	ok = _expect(ok, EquipmentData.tier_of("eq_sword_0") == 0, "tier_of 0 -> 0")
	ok = _expect(ok, EquipmentData.tier_of("eq_sword_x") == 0, "tier_of x -> 0")
	ok = _expect(ok, EquipmentData.tier_of("") == 0, "tier_of empty -> 0")
	ok = _expect(ok, EquipmentData.tier_of("eq_sword") == 0, "tier_of no suffix -> 0")
	ok = _expect(ok, EquipmentData.tier_of("eq_sword_5") == 0, "tier_of 5 -> 0")
	return ok


# --- bonuses_for direction matrix ---------------------------------------------

static func _test_bonuses_for_direction(ok: bool) -> bool:
	# weapon feeds attack ONLY
	var sw: Dictionary = EquipmentData.bonuses_for("eq_sword_3")
	ok = _expect(ok, int(sw.get("attack", 0)) == EquipmentData.ATTACK_PER_TIER * 3, "sword attack")
	ok = _expect(ok, int(sw.get("health", 0)) == 0, "sword no health")
	ok = _expect(ok, int(sw.get("initiative", 0)) == 0, "sword no initiative")
	ok = _expect(ok, int(sw.get("move", 0)) == 0, "sword no move")
	# armor feeds health ONLY
	var ar: Dictionary = EquipmentData.bonuses_for("eq_armor_2")
	ok = _expect(ok, int(ar.get("health", 0)) == EquipmentData.HEALTH_PER_TIER * 2, "armor health")
	ok = _expect(ok, int(ar.get("attack", 0)) == 0, "armor no attack")
	ok = _expect(ok, int(ar.get("initiative", 0)) == 0, "armor no initiative")
	ok = _expect(ok, int(ar.get("move", 0)) == 0, "armor no move")
	# boots feed initiative ONLY (+ move at high tier)
	var bt2: Dictionary = EquipmentData.bonuses_for("eq_boots_2")
	ok = _expect(ok, int(bt2.get("initiative", 0)) == EquipmentData.INITIATIVE_PER_TIER * 2, "boots initiative")
	ok = _expect(ok, int(bt2.get("attack", 0)) == 0, "boots no attack")
	ok = _expect(ok, int(bt2.get("health", 0)) == 0, "boots no health")
	ok = _expect(ok, int(bt2.get("move", 0)) == 0, "boots t2 no move")
	var bt3: Dictionary = EquipmentData.bonuses_for("eq_boots_3")
	ok = _expect(ok, int(bt3.get("move", 0)) == EquipmentData.MOVE_BONUS, "boots t3 move")
	ok = _expect(ok, int(bt3.get("initiative", 0)) == EquipmentData.INITIATIVE_PER_TIER * 3, "boots t3 initiative")
	var bt4: Dictionary = EquipmentData.bonuses_for("eq_boots_4")
	ok = _expect(ok, int(bt4.get("move", 0)) == EquipmentData.MOVE_BONUS, "boots t4 move")
	# empty/unknown id -> all zeros
	var empty: Dictionary = EquipmentData.bonuses_for("")
	ok = _expect(ok, int(empty.get("attack", 0)) == 0 and int(empty.get("health", 0)) == 0 \
		and int(empty.get("initiative", 0)) == 0 and int(empty.get("move", 0)) == 0, "empty id all zero")
	var unknown: Dictionary = EquipmentData.bonuses_for("eq_axe_3")
	ok = _expect(ok, int(unknown.get("attack", 0)) == 0 and int(unknown.get("health", 0)) == 0 \
		and int(unknown.get("initiative", 0)) == 0 and int(unknown.get("move", 0)) == 0, "unknown id all zero")
	return ok


# --- monotonicity in tier ------------------------------------------------------

static func _test_monotonicity(ok: bool) -> bool:
	# every tier step is the same delta for the slot's stat (additive linear),
	# so "better sword -> better stat" is monotone by construction.
	var prev_attack := -1
	var prev_health := -1
	var prev_initiative := -1
	for t in range(1, 5):
		var sw: Dictionary = EquipmentData.bonuses_for("eq_sword_%d" % t)
		var ar: Dictionary = EquipmentData.bonuses_for("eq_armor_%d" % t)
		var bt: Dictionary = EquipmentData.bonuses_for("eq_boots_%d" % t)
		var a: int = int(sw.get("attack", 0))
		var h: int = int(ar.get("health", 0))
		var i: int = int(bt.get("initiative", 0))
		ok = _expect(ok, a > prev_attack, "attack monotone tier %d" % t)
		ok = _expect(ok, h > prev_health, "health monotone tier %d" % t)
		ok = _expect(ok, i > prev_initiative, "initiative monotone tier %d" % t)
		prev_attack = a
		prev_health = h
		prev_initiative = i
	# move is a step function: 0 for t<3, MOVE_BONUS for t>=3
	ok = _expect(ok, EquipmentData.bonuses_for("eq_boots_1").get("move", 0) == 0, "move gate t1")
	ok = _expect(ok, EquipmentData.bonuses_for("eq_boots_2").get("move", 0) == 0, "move gate t2")
	ok = _expect(ok, EquipmentData.bonuses_for("eq_boots_3").get("move", 0) == EquipmentData.MOVE_BONUS, "move gate t3")
	ok = _expect(ok, EquipmentData.bonuses_for("eq_boots_4").get("move", 0) == EquipmentData.MOVE_BONUS, "move gate t4")
	return ok


# --- sum_bonuses ---------------------------------------------------------------

static func _test_sum_bonuses(ok: bool) -> bool:
	var empty_equip: Dictionary = {}
	ok = _expect(ok, EquipmentData.sum_bonuses(empty_equip) == {"attack": 0, "health": 0, "initiative": 0, "move": 0}, "sum_bonuses({}) all zero")
	ok = _expect(ok, EquipmentData.sum_bonuses(null) == {"attack": 0, "health": 0, "initiative": 0, "move": 0}, "sum_bonuses(null) all zero")
	ok = _expect(ok, EquipmentData.sum_bonuses("not a dict") == {"attack": 0, "health": 0, "initiative": 0, "move": 0}, "sum_bonuses(non-dict) all zero")
	# equipped sword + armor + boots sum independently
	var mixed: Dictionary = {
		"weapon": "eq_sword_3",
		"armor": "eq_armor_2",
		"boots": "eq_boots_4",
	}
	var sum: Dictionary = EquipmentData.sum_bonuses(mixed)
	ok = _expect(ok, int(sum.get("attack", 0)) == EquipmentData.ATTACK_PER_TIER * 3, "sum attack")
	ok = _expect(ok, int(sum.get("health", 0)) == EquipmentData.HEALTH_PER_TIER * 2, "sum health")
	ok = _expect(ok, int(sum.get("initiative", 0)) == EquipmentData.INITIATIVE_PER_TIER * 4, "sum initiative")
	ok = _expect(ok, int(sum.get("move", 0)) == EquipmentData.MOVE_BONUS, "sum move (boots t4)")
	# hostile slot values (int instead of String) are treated as empty
	var hostile: Dictionary = {
		"weapon": "eq_sword_1",
		"armor": 5,
		"boots": null,
	}
	var hsum: Dictionary = EquipmentData.sum_bonuses(hostile)
	ok = _expect(ok, int(hsum.get("attack", 0)) == EquipmentData.ATTACK_PER_TIER, "hostile sum attack (sword kept)")
	ok = _expect(ok, int(hsum.get("health", 0)) == 0, "hostile armor int -> 0")
	ok = _expect(ok, int(hsum.get("initiative", 0)) == 0, "hostile boots null -> 0")
	return ok


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_equipment_data: " + msg)
	return false
