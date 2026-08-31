## Unit tests for equipment-in-battle (scripts/data/battle_setup.gd with gear).
## Covers: legacy equality (empty-equipped = pre-round output), direction matrix
## (each slot feeds exactly its own stat), reversibility (equip→unequip = legacy),
## build_character mirrors cd.gear_*, tutorial-shape CharacterData unaffected.
##
## Style: top-level static func run() -> bool; push_error on failure; print
## PASS/FAIL at the end. Mirrors tests/test_battle_setup.gd's skeleton.

const BattleSetup = preload("res://scripts/data/battle_setup.gd")
const CharacterData = preload("res://scripts/data/character_data.gd")
const EquipmentData = preload("res://scripts/data/equipment_data.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")


static func run() -> bool:
	var ok := true
	ok = _test_legacy_equality(ok)
	ok = _test_legacy_equality_null_equipped(ok)
	ok = _test_direction_weapon_attack_only(ok)
	ok = _test_direction_armor_health_only(ok)
	ok = _test_direction_boots_initiative_only(ok)
	ok = _test_direction_boots_move_at_high_tier(ok)
	ok = _test_direction_boots_low_tier_no_move(ok)
	ok = _test_reversibility(ok)
	ok = _test_build_character_gear_mirrors(ok)
	ok = _test_build_character_gear_empty(ok)
	ok = _test_tutorial_characterdata_gear_defaults(ok)
	if ok:
		print("PASS test_battle_setup_equipment")
	else:
		print("FAIL test_battle_setup_equipment")
	return ok


# --- criterion 1: legacy equality (empty equipped = pre-round formula) --------

static func _test_legacy_equality(ok: bool) -> bool:
	# Multiple attr tuples covering different ranges.
	var tuples: Array[Array] = [
		[10, 10, 10, 10, 10],
		[20, 12, 40, 15, 10],
		[35, 25, 88, 20, 15],
	]
	for t in tuples:
		var p = _profile({"bone": t[0], "inner": t[1], "agility": t[2], "wisdom": t[3], "fortune": t[4]})
		var s: Dictionary = BattleSetup.derive_stats(p)
		var bone: int = t[0]
		var inner: int = t[1]
		var agility: int = t[2]
		ok = _expect(ok, int(s.max_health) == bone * 5,
			"legacy: max_health = %d*5 = %d, got %d" % [bone, bone * 5, int(s.max_health)])
		ok = _expect(ok, int(s.energy) == inner * 2,
			"legacy: energy = %d*2 = %d, got %d" % [inner, inner * 2, int(s.energy)])
		ok = _expect(ok, int(s.move_range) == 2 + int(floor(float(agility) / 20.0)),
			"legacy: move_range = 2 + floor(%d/20) = %d, got %d" % [agility, 2 + int(floor(float(agility) / 20.0)), int(s.move_range)])
		ok = _expect(ok, int(s.initiative) == agility,
			"legacy: initiative = %d, got %d" % [agility, int(s.initiative)])
		ok = _expect(ok, int(s.attack_damage) == 10 + bone,
			"legacy: attack_damage = 10+%d = %d, got %d" % [bone, 10 + bone, int(s.attack_damage)])
	return ok


# --- criterion 2: null equipped (duck-typed profile without equipped property) --

static func _test_legacy_equality_null_equipped(ok: bool) -> bool:
	# A duck-typed object that does NOT have an "equipped" property.
	# Object.get("equipped") on it returns null -> {} -> all zeros -> legacy output.
	var duck = _MiniProfile.new(20, 12, 40)
	var s: Dictionary = BattleSetup.derive_stats(duck)
	ok = _expect(ok, int(s.max_health) == 100, "duck null-equipped: max_health = 100, got %d" % int(s.max_health))
	ok = _expect(ok, int(s.energy) == 24, "duck null-equipped: energy = 24, got %d" % int(s.energy))
	ok = _expect(ok, int(s.move_range) == 4, "duck null-equipped: move_range = 4, got %d" % int(s.move_range))
	ok = _expect(ok, int(s.initiative) == 40, "duck null-equipped: initiative = 40, got %d" % int(s.initiative))
	ok = _expect(ok, int(s.attack_damage) == 30, "duck null-equipped: attack_damage = 30, got %d" % int(s.attack_damage))
	return ok


# --- criterion 3: direction matrix — weapon feeds attack ONLY ------------------

static func _test_direction_weapon_attack_only(ok: bool) -> bool:
	var p_empty = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_empty: Dictionary = BattleSetup.derive_stats(p_empty)

	var p_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_eq.equipped = {"weapon": "eq_sword_3", "armor": "", "boots": ""}
	var s_eq: Dictionary = BattleSetup.derive_stats(p_eq)

	var expected_attack_bonus: int = EquipmentData.ATTACK_PER_TIER * 3
	ok = _expect(ok, int(s_eq.attack_damage) == int(s_empty.attack_damage) + expected_attack_bonus,
		"weapon t3: attack_damage +%d, got %d vs %d" % [expected_attack_bonus, int(s_eq.attack_damage), int(s_empty.attack_damage)])
	ok = _expect(ok, int(s_eq.max_health) == int(s_empty.max_health), "weapon: max_health unchanged")
	ok = _expect(ok, int(s_eq.energy) == int(s_empty.energy), "weapon: energy unchanged")
	ok = _expect(ok, int(s_eq.move_range) == int(s_empty.move_range), "weapon: move_range unchanged")
	ok = _expect(ok, int(s_eq.initiative) == int(s_empty.initiative), "weapon: initiative unchanged")
	return ok


# --- criterion 4: direction matrix — armor feeds health ONLY --------------------

static func _test_direction_armor_health_only(ok: bool) -> bool:
	var p_empty = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_empty: Dictionary = BattleSetup.derive_stats(p_empty)

	var p_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_eq.equipped = {"weapon": "", "armor": "eq_armor_2", "boots": ""}
	var s_eq: Dictionary = BattleSetup.derive_stats(p_eq)

	var expected_health_bonus: int = EquipmentData.HEALTH_PER_TIER * 2
	ok = _expect(ok, int(s_eq.max_health) == int(s_empty.max_health) + expected_health_bonus,
		"armor t2: max_health +%d, got %d vs %d" % [expected_health_bonus, int(s_eq.max_health), int(s_empty.max_health)])
	ok = _expect(ok, int(s_eq.attack_damage) == int(s_empty.attack_damage), "armor: attack_damage unchanged")
	ok = _expect(ok, int(s_eq.energy) == int(s_empty.energy), "armor: energy unchanged")
	ok = _expect(ok, int(s_eq.move_range) == int(s_empty.move_range), "armor: move_range unchanged")
	ok = _expect(ok, int(s_eq.initiative) == int(s_empty.initiative), "armor: initiative unchanged")
	return ok


# --- criterion 5: direction matrix — boots feeds initiative ONLY (low tier) ----

static func _test_direction_boots_initiative_only(ok: bool) -> bool:
	var p_empty = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_empty: Dictionary = BattleSetup.derive_stats(p_empty)

	var p_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_eq.equipped = {"weapon": "", "armor": "", "boots": "eq_boots_4"}
	var s_eq: Dictionary = BattleSetup.derive_stats(p_eq)

	var expected_init_bonus: int = EquipmentData.INITIATIVE_PER_TIER * 4
	ok = _expect(ok, int(s_eq.initiative) == int(s_empty.initiative) + expected_init_bonus,
		"boots t4: initiative +%d, got %d vs %d" % [expected_init_bonus, int(s_eq.initiative), int(s_empty.initiative)])
	ok = _expect(ok, int(s_eq.attack_damage) == int(s_empty.attack_damage), "boots: attack_damage unchanged")
	ok = _expect(ok, int(s_eq.max_health) == int(s_empty.max_health), "boots: max_health unchanged")
	ok = _expect(ok, int(s_eq.energy) == int(s_empty.energy), "boots: energy unchanged")
	return ok


# --- criterion 6: boots high tier adds move bonus --------------------------------

static func _test_direction_boots_move_at_high_tier(ok: bool) -> bool:
	var p_empty = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_empty: Dictionary = BattleSetup.derive_stats(p_empty)

	var p_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_eq.equipped = {"weapon": "", "armor": "", "boots": "eq_boots_4"}
	var s_eq: Dictionary = BattleSetup.derive_stats(p_eq)

	ok = _expect(ok, int(s_eq.move_range) == int(s_empty.move_range) + EquipmentData.MOVE_BONUS,
		"boots t4: move_range +%d (t>=threshold), got %d vs %d" % [EquipmentData.MOVE_BONUS, int(s_eq.move_range), int(s_empty.move_range)])
	return ok


# --- criterion 7: boots low tier does NOT add move bonus -------------------------

static func _test_direction_boots_low_tier_no_move(ok: bool) -> bool:
	var p_empty = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_empty: Dictionary = BattleSetup.derive_stats(p_empty)

	var p_eq = _profile({"bone": 20, "inner": 12, "agility": 40})
	p_eq.equipped = {"weapon": "", "armor": "", "boots": "eq_boots_1"}
	var s_eq: Dictionary = BattleSetup.derive_stats(p_eq)

	ok = _expect(ok, int(s_eq.move_range) == int(s_empty.move_range),
		"boots t1: move_range unchanged (t < threshold), got %d vs %d" % [int(s_eq.move_range), int(s_empty.move_range)])
	var expected_init_bonus: int = EquipmentData.INITIATIVE_PER_TIER * 1
	ok = _expect(ok, int(s_eq.initiative) == int(s_empty.initiative) + expected_init_bonus,
		"boots t1: initiative +%d" % expected_init_bonus)
	return ok


# --- criterion 8: reversibility (equip -> differ -> unequip -> equal legacy) -----

static func _test_reversibility(ok: bool) -> bool:
	var p = _profile({"bone": 20, "inner": 12, "agility": 40})
	var s_baseline: Dictionary = BattleSetup.derive_stats(p)

	# Equip all three slots.
	p.equipped = {"weapon": "eq_sword_2", "armor": "eq_armor_3", "boots": "eq_boots_4"}
	var s_equipped: Dictionary = BattleSetup.derive_stats(p)
	ok = _expect(ok, s_equipped != s_baseline, "reversibility: equipped stats differ from baseline")

	# Unequip (restore empty slots).
	p.equipped = {"weapon": "", "armor": "", "boots": ""}
	var s_reverted: Dictionary = BattleSetup.derive_stats(p)
	ok = _expect(ok, s_reverted == s_baseline, "reversibility: after unequip, stats equal baseline again")
	return ok


# --- criterion 9: build_character mirrors cd.gear_* correctly --------------------

static func _test_build_character_gear_mirrors(ok: bool) -> bool:
	var p = _profile({"bone": 20, "inner": 12, "agility": 40})
	p.equipped = {"weapon": "eq_sword_3", "armor": "eq_armor_2", "boots": "eq_boots_4"}
	var cd = BattleSetup.build_character(p)

	var expected: Dictionary = EquipmentData.sum_bonuses(p.equipped)
	ok = _expect(ok, int(cd.gear_attack_bonus) == int(expected.get("attack", 0)),
		"build_character: gear_attack_bonus = %d, got %d" % [int(expected.get("attack", 0)), int(cd.gear_attack_bonus)])
	ok = _expect(ok, int(cd.gear_health_bonus) == int(expected.get("health", 0)),
		"build_character: gear_health_bonus = %d, got %d" % [int(expected.get("health", 0)), int(cd.gear_health_bonus)])
	ok = _expect(ok, int(cd.gear_initiative_bonus) == int(expected.get("initiative", 0)),
		"build_character: gear_initiative_bonus = %d, got %d" % [int(expected.get("initiative", 0)), int(cd.gear_initiative_bonus)])
	ok = _expect(ok, int(cd.gear_move_bonus) == int(expected.get("move", 0)),
		"build_character: gear_move_bonus = %d, got %d" % [int(expected.get("move", 0)), int(cd.gear_move_bonus)])
	return ok


# --- criterion 10: build_character with empty equipped -> all gear 0 -------------

static func _test_build_character_gear_empty(ok: bool) -> bool:
	var p = _profile({"bone": 20, "inner": 12, "agility": 40})
	# Default empty equipped.
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, int(cd.gear_attack_bonus) == 0, "empty equipped: gear_attack_bonus = 0")
	ok = _expect(ok, int(cd.gear_health_bonus) == 0, "empty equipped: gear_health_bonus = 0")
	ok = _expect(ok, int(cd.gear_initiative_bonus) == 0, "empty equipped: gear_initiative_bonus = 0")
	ok = _expect(ok, int(cd.gear_move_bonus) == 0, "empty equipped: gear_move_bonus = 0")
	return ok


# --- criterion 11: tutorial-shape CharacterData (not via build_character) --------

static func _test_tutorial_characterdata_gear_defaults(ok: bool) -> bool:
	var cd = CharacterData.new()
	ok = _expect(ok, int(cd.gear_attack_bonus) == 0, "tutorial CD: gear_attack_bonus = 0")
	ok = _expect(ok, int(cd.gear_health_bonus) == 0, "tutorial CD: gear_health_bonus = 0")
	ok = _expect(ok, int(cd.gear_initiative_bonus) == 0, "tutorial CD: gear_initiative_bonus = 0")
	ok = _expect(ok, int(cd.gear_move_bonus) == 0, "tutorial CD: gear_move_bonus = 0")
	return ok


# --- helpers --------------------------------------------------------------------

## Fresh PlayerProfile with the given int attrs.
static func _profile(attrs: Dictionary):
	var p = PlayerProfileScript.new()
	for key in attrs.keys():
		if attrs[key] is int:
			p.attrs[key] = attrs[key]
	return p


## Minimal profile-like object without an "equipped" property.
## Object.get("equipped") on this returns null, exercising the null-safe path
## in derive_stats. Has all the properties _attr/_attack_range_for need.
class _MiniProfile extends RefCounted:
	var attrs: Dictionary = {}
	var gongfa: Array = []
	var traits: Array[String] = []
	var main_external_id: String = ""

	func _init(b: int, i: int, a: int) -> void:
		attrs = {"bone": b, "inner": i, "agility": a, "wisdom": 10, "fortune": 10}


static func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_battle_setup_equipment: " + msg)
	return false
