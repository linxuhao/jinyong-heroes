## Integration tests for the encounter battle (scripts/battlefield.gd encounter
## mode + scripts/data/encounter_data.gd + scripts/data/battle_setup.gd).
##
## Run manually from the repo root:
##   godot --headless -s tests/test_encounter.gd
## (run_tests.sh drives this file with its own -s invocation; it is NOT
## collected by unit_test_runner.gd because the battlefield needs the full
## SceneTree + autoloads and a live GridManager.)
##
## Mirrors tests/test_cultivation.gd's harness: extends SceneTree, autoloads
## fetched from the root (deferred so the tree is fully up), synchronous
## assertions, quit codes. Scenarios:
##   (a) battlefield._ready() on the encounter path (return_state == CULTIVATION)
##       wires the BattleSetup hero + one Sparring_Partner at (7,4) with 60 HP,
##       tutorial_battle == false and the tutorial never started;
##   (b) GameManager.start_encounter() CULTIVATION -> BATTLE (with a live
##       encounter battlefield so the round engine has real units); a second
##       call from BATTLE is a no-op;
##   (c) GameManager.request_retry() from LOST routes to CULTIVATION and clears
##       every battle ref;
##   (d) EncounterData.sparring_partner() shape — stats / arts / fhd == 1.3
##       through the real cascade;
##   (e) BattleSetup.build_character(profile) — traits propagation + equip cap
##       2 / 3 (ambidextrous) + grade-A-first sort.
extends SceneTree

const BATTLEFIELD_SCENE = preload("res://scenes/battlefield.tscn")
const EncounterData = preload("res://scripts/data/encounter_data.gd")
const BattleSetup = preload("res://scripts/data/battle_setup.gd")
const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")

var _sm = null   # SaveManager autoload node
var _gm = null   # GameManager autoload node


func _initialize() -> void:
	# Defer so the root tree (and every autoload) is fully up before touching it.
	call_deferred("_run")


func _run() -> void:
	_sm = root.get_node_or_null("SaveManager")
	_gm = root.get_node_or_null("GameManager")
	if _sm == null or _gm == null:
		push_error("test_encounter: SaveManager/GameManager autoloads not found (run with -s from the repo root)")
		quit(1)
		return
	# Hermetic start: clear save files left by an earlier interrupted run.
	_sm.delete_slot(1)
	_sm.delete_slot(2)
	_sm.delete_slot(3)
	var ok := _test_all()
	# Restore the autoloads to their canonical boot state for later checks.
	CombatManager.reset_battle()
	_gm.clear_battle()
	_gm.current_state = "TUTORIAL"
	_gm.set_battle_return_state("TUTORIAL")
	if ok:
		print("PASS test_encounter")
	else:
		print("FAIL test_encounter")
	quit(0 if ok else 1)


func _test_all() -> bool:
	var ok := true
	ok = _test_encounter_field_ready(ok)
	ok = _test_start_encounter_transition(ok)
	ok = _test_request_retry_routes_to_cultivation(ok)
	ok = _test_sparring_partner_shape(ok)
	ok = _test_battle_setup_traits_and_equip(ok)
	return ok


# --- (a) encounter battlefield._ready() wiring --------------------------------

## Spawn the battlefield on the encounter path (return_state == "CULTIVATION")
## with a live profile and assert the full wiring: the player is the BattleSetup
## hero (traits wired from the profile), exactly one sparring partner stands at
## (7,4) with 60/60 HP, tutorial_battle == false, and the tutorial never started.
func _test_encounter_field_ready(ok: bool) -> bool:
	var node: Node = _spawn_encounter_battlefield()
	var player: Node = _gm.get_player()
	ok = _expect(ok, player != null, "encounter: GameManager has a player")
	ok = _expect(ok, player != null and player.character_data != null
		and str(player.character_data.character_name) == "ProgressionHero",
		"encounter: player is the BattleSetup hero")
	ok = _expect(ok, not CombatManager.tutorial_battle,
		"encounter: CombatManager.tutorial_battle == false")
	var spar: Node = node.get_node_or_null("Characters/Sparring_Partner")
	ok = _expect(ok, spar != null,
		"encounter: node named Sparring_Partner exists under Characters")
	ok = _expect(ok, spar != null and spar.grid_pos == Vector2i(7, 4),
		"encounter: sparring partner at grid_pos (7,4)")
	ok = _expect(ok, spar != null and int(spar.health) == 60 and int(spar.max_health) == 60,
		"encounter: sparring partner health 60/60")
	ok = _expect(ok, not TutorialManager.is_active,
		"encounter: tutorial never started (is_active == false)")
	var enemies: Array[Node] = _gm.get_enemies_alive()
	ok = _expect(ok, enemies.size() == 1, "encounter: exactly one enemy registered")
	ok = _expect(ok, not enemies.is_empty() and enemies[0] == spar,
		"encounter: the registered enemy is the sparring partner")
	ok = _expect(ok, player != null and "traits" in player and player.traits.has("sha_po_lang"),
		"encounter: profile trait sha_po_lang wired onto the player node")
	_teardown(node)
	return ok


# --- (b) start_encounter transition -------------------------------------------

## start_encounter from CULTIVATION -> BATTLE with battle_return_state ==
## CULTIVATION; a second call from BATTLE is a no-op.
func _test_start_encounter_transition(ok: bool) -> bool:
	var node: Node = _spawn_encounter_battlefield()
	_gm.start_encounter()
	ok = _expect(ok, _gm.current_state == "BATTLE",
		"start_encounter: CULTIVATION -> BATTLE")
	ok = _expect(ok, _gm.get_battle_return_state() == "CULTIVATION",
		"start_encounter: battle_return_state == CULTIVATION")
	_gm.start_encounter()   # second call from BATTLE: no-op
	ok = _expect(ok, _gm.current_state == "BATTLE",
		"start_encounter: second call from BATTLE is a no-op")
	ok = _expect(ok, _gm.get_battle_return_state() == "CULTIVATION",
		"start_encounter: no-op leaves battle_return_state == CULTIVATION")
	_teardown(node)
	return ok


# --- (c) request_retry routing --------------------------------------------------

## request_retry from LOST with battle_return_state == CULTIVATION routes back
## to CULTIVATION and clears every battle ref (player + enemy registry).
func _test_request_retry_routes_to_cultivation(ok: bool) -> bool:
	var node: Node = _spawn_encounter_battlefield()
	ok = _expect(ok, _gm.get_player() != null and _gm.get_enemies_alive().size() == 1,
		"retry precondition: player + one enemy registered")
	_gm.current_state = "LOST"
	_gm.request_retry()
	ok = _expect(ok, _gm.current_state == "CULTIVATION",
		"request_retry: LOST with battle_return_state CULTIVATION -> CULTIVATION")
	ok = _expect(ok, _gm.get_player() == null,
		"request_retry: clear_battle nulled the player ref")
	ok = _expect(ok, _gm.get_enemies_alive().is_empty(),
		"request_retry: clear_battle emptied the enemy registry")
	_teardown(node)
	return ok


# --- (d) sparring_partner shape ------------------------------------------------

## EncounterData.sparring_partner(): fixed stats, one internal + three external
## mastered D 阳 arts, no skills, ai_class AIControllerSparring, and every art
## computes fhd == 1.3 through the real cascade.
func _test_sparring_partner_shape(ok: bool) -> bool:
	var cd = EncounterData.sparring_partner()
	ok = _expect(ok, str(cd.character_name) == "Sparring Partner",
		"sparring: character_name == Sparring Partner")
	ok = _expect(ok, int(cd.max_health) == 60, "sparring: max_health 60")
	ok = _expect(ok, int(cd.attack_damage) == 12, "sparring: attack_damage 12")
	ok = _expect(ok, int(cd.move_range) == 2, "sparring: move_range 2")
	ok = _expect(ok, int(cd.initiative) == 3, "sparring: initiative 3")
	ok = _expect(ok, int(cd.attack_range) == 1, "sparring: attack_range 1")
	ok = _expect(ok, int(cd.team) == 1, "sparring: team 1")
	ok = _expect(ok, str(cd.ai_class) == "AIControllerSparring",
		"sparring: ai_class == AIControllerSparring")
	ok = _expect(ok, cd.skills.is_empty(), "sparring: skills empty")
	ok = _expect(ok, cd.internal_arts.size() == 1 and cd.external_arts.size() == 3,
		"sparring: 1 internal + 3 external arts")
	var arts: Array = cd.internal_arts + cd.external_arts
	for art in arts:
		ok = _expect(ok, str(art.grade) == "D", "sparring: art grade D")
		ok = _expect(ok, str(art.attribute) == "yang", "sparring: art attribute yang")
		ok = _expect(ok, bool(art.mastered), "sparring: art mastered")
		ok = _expect(ok, art.techniques.is_empty(), "sparring: art has no techniques")
		ok = _expect(ok, absf(GongfaData.get_fa_hui_du(art, cd) - 1.3) < 0.0001,
			"sparring: art fhd == 1.3 via the real cascade")
	ok = _expect(ok, EncounterData.sparring_partner_tile() == Vector2i(7, 4),
		"sparring: partner tile (7,4)")
	return ok


# --- (e) BattleSetup.build_character -------------------------------------------

## BattleSetup.build_character: traits copied from the profile (duplicated, not
## aliased); equip cap 2 without ambidextrous / 3 with; grade-A external always
## equipped first.
func _test_battle_setup_traits_and_equip(ok: bool) -> bool:
	var p = PlayerProfileScript.new()
	p.add_trait("sha_po_lang")
	p.add_trait("iron_shirt")
	p.add_gongfa("shaolin_yijin_d", "D")     # internal
	p.add_gongfa("shaolin_luohan_d", "D")    # external palm
	p.add_gongfa("shaolin_luohan_c", "C")    # external palm
	p.add_gongfa("a_sword", "A")             # external A (grade-first)
	var cd = BattleSetup.build_character(p)
	ok = _expect(ok, cd.traits == p.traits, "build: traits copied from profile")
	ok = _expect(ok, cd.traits.has("sha_po_lang") and cd.traits.has("iron_shirt"),
		"build: both traits present on CharacterData")
	ok = _expect(ok, cd.external_arts.size() == 2, "build: cap 2 without ambidextrous")
	ok = _expect(ok, str(cd.external_arts[0].grade) == "A",
		"build: grade-A art equipped first")
	# Duplicate copy, not aliasing: a later profile mutation cannot leak in.
	p.add_trait("swallow_lightness")
	ok = _expect(ok, cd.traits.size() == 2, "build: traits duplicated (mutation isolated)")
	p.add_trait("ambidextrous")
	var cd3 = BattleSetup.build_character(p)
	ok = _expect(ok, cd3.external_arts.size() == 3, "build: cap 3 with ambidextrous")
	ok = _expect(ok, str(cd3.external_arts[0].grade) == "A",
		"build: grade-A still first with 3 equipped")
	return ok


# --- helpers --------------------------------------------------------------------

## Fresh encounter context: new profile (traits incl. sha_po_lang so the traits
## wire is observable), one wudang sword art (so BattleSetup has gongfa + a main
## external school), state CULTIVATION, battle_return_state reset to TUTORIAL
## (start_encounter must override it), then the battlefield scene instantiated
## and added to the root so _ready() runs the encounter branch.
func _spawn_encounter_battlefield() -> Node:
	_sm.new_profile({}, ["sha_po_lang"])
	_sm.profile.cultivation["sect_id"] = "wudang"
	_sm.profile.add_gongfa("wudang_taiji_d", "D")
	_sm.profile.main_external_id = "wudang_taiji_d"
	_gm.clear_battle()
	CombatManager.reset_battle()
	_gm.current_state = "CULTIVATION"
	_gm.set_battle_return_state("TUTORIAL")
	var inst: Node = BATTLEFIELD_SCENE.instantiate()
	root.add_child(inst)
	return inst


func _teardown(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	CombatManager.reset_battle()
	_gm.clear_battle()
	GridManager.clear_grid()


func _expect(ok: bool, cond: bool, msg: String) -> bool:
	if cond:
		return ok
	push_error("test_encounter: " + msg)
	return false
