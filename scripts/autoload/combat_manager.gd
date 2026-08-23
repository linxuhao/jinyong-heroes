## CombatManager (autoload)
##
## Turn-based combat manager singleton. Owns the sequential turn engine
## (round snapshot with a stable initiative sort, one turn per unit per round,
## round-based cooldown/DoT/status ticking at the unit's own turn start), the
## two-stage damage pipeline (attack side round(base x buffs x fa_hui_du),
## defense side round(output x (1 - DR_total))), the per-unit status table,
## passives (regen, DR tags, counter/reflect, fatal guard, below-40% heal),
## hazard zones, boolean-gate pause, and death handling.
##
## Consumed by Player / Enemy scripts (end_current_turn, is_player_turn,
## execute_action) and by the HUD (current_round / phase / active_unit_name /
## turn_order). Calls into GridManager (occupancy, movement, AoE) and
## GameManager (enemy tracking, win/lose).
##
## The RTWP action queue / timer-driven AI path is REMOVED: turn order is
## driven by 身法 (initiative), the player's turn is event-driven (Space ends
## it), and enemy AI is invoked exactly once per enemy turn.
##
## ---------------------------------------------------------------------------
## Round-frame budget (why TWEEN_TIMEOUT_SEC is 0.25 s)
##
## A full enemy round awaits one tween per move step plus one per action,
## plus the two opening skill tweens (East Heretic 碧海潮生, Central Divine
## 先天一炁): round 1 ≈ 14-16 awaited tweens. At 60 fps with the old 0.6 s
## watchdog that is ≈ 14-16 x 36 ≈ 500-580 frames per round IF tween.finished
## never fires (watchdog expiry on every await) — which is exactly the
## observed failure (a full enemy round not done by frame 500 in
## each_unit_acts_once_per_round_initiative_order) and the terminal run
## (round 5 ≈ frame 3000, i.e. ~600 frames/round). With the 0.25 s cap the
## worst case is ≈ 16 x 15 ≈ 240 frames and the normal case (tweens finish at
## their natural 0.15 s) is ≈ 150 frames — both comfortably inside the
## harness's 500-frame windows.
##
## Diagnostic conclusion (for fix_playtest_scenario_assertions /
## fix_terminal_victory): read debug_await_total / debug_await_timeouts /
## debug_await_frames from the surface after a round. If debug_await_timeouts
## == 0, tweens finish normally and 0.25 s is pure safety margin; if > 0,
## tween.finished does not fire in the harness environment and the cap is what
## bounds each round — no further engine change is required for frame-window
## sizing (gameplay state is applied synchronously before every tween, so
## cutting a visual animation short never desyncs the simulation).
extends Node

const SkillData = preload("res://scripts/data/skill_data.gd")
const TraitEffects = preload("res://scripts/data/trait_effects.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a new round begins. Passes the round number.
signal round_started(current_round: int)

## Emitted when a unit's turn begins. Passes the unit node.
signal turn_started(unit: Node)

## Emitted when a unit's turn ends. Passes the unit node.
signal turn_ended(unit: Node)

## Emitted when the engine phase changes.
signal phase_changed(phase: String)

## Emitted when the game is paused.
signal paused()

## Emitted when the game is unpaused.
signal unpaused()

## Emitted after an action is executed. Passes the unit and action name.
signal action_executed(unit: Node, action: String)

## Emitted when damage is applied to a target. Passes the target node,
## the amount of damage dealt, and whether the damage was lethal.
signal damage_dealt(target: Node, amount: int, is_lethal: bool)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const PAUSE_DEBOUNCE_MS: int = 100

## Maximum time (seconds) to wait for an action tween's `finished` signal
## before giving up. Killed tweens (e.g. a tween bound to a node that was
## queue_free'd on death) never emit `finished`, which would otherwise hang
## the turn loop forever. The longest natural action tween is 0.15 s (move /
## jump / knockback) and the damage flash is 0.1 s, so 0.25 s is that plus a
## small margin. This cap bounds a full enemy round to ≈ 240 frames worst
## case (round-frame budget arithmetic in the header above).
const TWEEN_TIMEOUT_SEC: float = 0.25

## Fallback fa_hui_du when no GongfaData resource is available (tutorial arts
## keep their flat 1.3 via the staged-values short-circuit).
const DEFAULT_FA_HUI_DU: float = 1.3

# ---------------------------------------------------------------------------
# Public state (assertable surface)
# ---------------------------------------------------------------------------

## The current round number (starts at 1 when the battle begins).
var current_round: int = 0

## Engine phase: "IDLE" (pre-battle), "PLAYER_TURN", "ENEMY_TURN", "ROUND_END".
var phase: String = "IDLE"

## Name of the unit whose turn is active ("" while idle).
var active_unit_name: String = ""

## Initiative order snapshot for the current round (unit names, first to act).
var turn_order: Array[String] = []

## Names of units in the order their turns ended (observable log).
var turn_log: Array[String] = []

## Name of the unit that ended the previous turn.
var last_turn_actor: String = ""

## Whether the game is currently paused (boolean gate; no Engine.time_scale).
var is_paused: bool = false

## Active hazard zones (桃花迷阵). Maps Vector2i -> {rounds: int, owner: Node}.
var hazard_zones: Dictionary = {}

## Additive diagnostic counters (surface-observable, NEVER reset — they prove
## where a round's frames go; downstream spec tasks may assert on them):
##   debug_await_total:    number of _await_tween_safe() awaits so far.
##   debug_await_timeouts: of those, how many exited via watchdog expiry with
##                         tween.finished never firing (done[0] == false).
##   debug_await_frames:   total process_frame iterations consumed by awaits.
## If debug_await_timeouts == 0 after a round, tweens finish normally and
## TWEEN_TIMEOUT_SEC is pure safety margin; if > 0, tween.finished does not
## fire in the harness environment and the cap is what bounds the round.
var debug_await_total: int = 0
var debug_await_timeouts: int = 0
var debug_await_frames: int = 0

## Round-frame diagnostic: the process frame at which _begin_round most
## recently ran (set right after the re-entry guard). Lets downstream spec
## tasks re-time key presses against measured round boundaries.
var debug_round_frame: int = 0

## Observable: how many times a round began with NO unit able to act. Must
## stay 0 in a healthy battle; any non-zero value means the battle was
## started with nothing registered and cannot advance.
var empty_round_stalls: int = 0

## 蛤蟆反震 reflect diagnostic: cumulative count of times the reflect
## triggered on a melee attacker (incremented exactly once per trigger, just
## before the untyped 16-damage apply). Lets the balance tasks verify the
## reflect-side hit-count assumption directly from the surface.
var debug_reflect_hits: int = 0

## Whether the active battle is the fixed tutorial. True = the tutorial's
## skill-bar gates apply (two-phase palm unlock, phase lock); false = an
## encounter/free battle with no tutorial restrictions. Set by battlefield.gd
## when the tutorial content is built; reset to false in reset_battle().
var tutorial_battle: bool = false

## 杀 lifesteal diagnostic: cumulative HP healed by the sha_po_lang trait
## (mirror debug_await_* — NEVER reset; the per-round budget resets are
## internal to _sha_round_healed).
var debug_sha_heal_total: int = 0

## 铁布衫 diagnostic: cumulative fatal-guard procs by the iron_shirt trait
## (NEVER reset; once-per-battle tracking is internal to _iron_shirt_used).
var debug_iron_shirt_procs: int = 0

## 狼 diagnostic: the last attack-side multiplier applied by the sha_po_lang
## trait (1.0 when no trait). Reset to 1.0 on every attack-side computation
## (basic attack / skill damage) and in reset_battle().
var debug_lang_attack_mult: float = 1.0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Timestamp (ms) of the last pause toggle, for debounce.
var _last_pause_toggle: int = 0

## Unit nodes in the current round's initiative order (parallel to turn_order).
var _turn_order_units: Array = []

## The unit whose turn is active.
var _active_unit: Node = null

## Set by end_current_turn() so the awaited player-turn branch can resume.
var _player_turn_done: bool = false

## 弹指神通 counter flags, keyed by unit instance id, reset at each round start.
var _finger_dart_used: Dictionary = {}

## 先天罡气 fatal-guard-used flags, keyed by unit instance id (once per battle).
var _innate_qi_used: Dictionary = {}

## 一阳续命 below-40% one-time heal flags, keyed by unit instance id.
var _one_yang_used: Dictionary = {}

## 杀 per-round lifesteal budget consumed, keyed by unit instance id, reset at
## each round start (mirrors _finger_dart_used).
var _sha_round_healed: Dictionary = {}

## 铁布衫 fatal-guard-used flags, keyed by unit instance id (once per battle).
var _iron_shirt_used: Dictionary = {}

# ---------------------------------------------------------------------------
# Wiring
# ---------------------------------------------------------------------------

## Idempotently connect to the battle-start signal. The round loop is a
## long-running coroutine kicked off exactly once from here.
func _ready() -> void:
	if not GameManager.battle_started.is_connected(_on_battle_started):
		GameManager.battle_started.connect(_on_battle_started)


## Begin the turn-based battle: round 1 snapshot and the first turn.
func _on_battle_started() -> void:
	if phase != "IDLE":
		return
	current_round = 1
	_begin_round()

# ---------------------------------------------------------------------------
# Public API — Pause / unpause (boolean gate only, NO Engine.time_scale)
# ---------------------------------------------------------------------------

## Returns whether the game is currently paused.
func get_is_paused() -> bool:
	return is_paused


## Pause the game (boolean gate). Emits paused. No-op if already paused.
func pause() -> void:
	if is_paused:
		return
	is_paused = true
	paused.emit()


## Unpause the game. Emits unpaused. No-op if not paused.
func unpause() -> void:
	if not is_paused:
		return
	is_paused = false
	unpaused.emit()


## Toggle pause/unpause with a 100ms debounce to prevent flickering from
## rapid key presses.
func toggle_pause() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_pause_toggle < PAUSE_DEBOUNCE_MS:
		return
	_last_pause_toggle = now
	if is_paused:
		unpause()
	else:
		pause()


## Returns true while the player's turn is active.
func is_player_turn() -> bool:
	return phase == "PLAYER_TURN"

# ---------------------------------------------------------------------------
# Public API — Battle reset + DEBUG hooks (combat_cleanup)
# ---------------------------------------------------------------------------

## Reset every per-battle engine state so the battlefield can be torn down and
## re-entered cleanly (tutorial retry / restart / future encounter battles).
## Does NOT free or touch scene-tree nodes — the caller (SceneManager) owns the
## actual scene swap. Resets the round snapshot, phase, observables, hazard
## zones, and each live unit's battle state (statuses / cooldowns / shield /
## turn flags) so a re-entered battle starts from a clean slate.
func reset_battle() -> void:
	current_round = 0
	phase = "IDLE"
	active_unit_name = ""
	turn_order = []
	turn_log = []
	last_turn_actor = ""
	_turn_order_units = []
	_active_unit = null
	_player_turn_done = false
	_finger_dart_used = {}
	_innate_qi_used = {}
	_one_yang_used = {}
	_sha_round_healed = {}
	_iron_shirt_used = {}
	tutorial_battle = false
	debug_lang_attack_mult = 1.0
	hazard_zones = {}
	for raw in GameManager.get_enemies_alive():
		if raw == null or not is_instance_valid(raw):
			continue
		_clear_unit_battle_state(raw as Node)
	var player: Node = GameManager.get_player()
	if player != null and is_instance_valid(player):
		_clear_unit_battle_state(player)


## DEBUG hook (unbound harness action, consumed by GameManager._process):
## defeat every living enemy THROUGH THE NORMAL damage/death pipeline
## (apply_damage -> _handle_death -> unregister_enemy -> end_battle(true)) so
## the WON path is identical to a real victory. The loop re-reads
## enemies_alive after every hit: 先天罡气's fatal guard can survive the first
## lethal blow at 1 HP, and the next pass finishes the survivor exactly like a
## real kill. No-op when no battle is running.
func debug_wipe_enemies() -> void:
	if not _battle_active():
		return
	while not GameManager.get_enemies_alive().is_empty() \
			and GameManager.get_state() not in ["WON", "LOST"]:
		var raw = GameManager.get_enemies_alive()[0]
		if raw == null or not is_instance_valid(raw):
			GameManager.enemies_alive.erase(raw)
			continue
		var foe: Node = raw
		if "health" in foe and int(foe.health) > 0:
			# Lethal, DR-ignoring nuke at current HP through the real pipeline.
			apply_damage(foe, int(foe.health), GameManager.get_player(), false, true)
		else:
			GameManager.unregister_enemy(foe)


## DEBUG hook (unbound harness action): kill the player THROUGH THE NORMAL
## damage/death pipeline (apply_damage -> _handle_death -> end_battle(false)).
## No-op when no battle is running.
func debug_kill_player() -> void:
	if not _battle_active():
		return
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if "health" in player and int(player.health) > 0:
		apply_damage(player, int(player.health), null, false, true)


## True while a battle is actually running: the player exists, the engine is
## past IDLE, and the battle is not already decided.
func _battle_active() -> bool:
	if GameManager.get_state() in ["WON", "LOST"]:
		return false
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return false
	return phase != "IDLE"


## Reset one unit's per-battle state (statuses, cooldowns, shield, turn flags).
## Check-then-cast: validate the node before any typed access (freed-object
## safe); every property is guarded with an `in` existence test.
func _clear_unit_battle_state(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if "statuses" in unit and unit.statuses != null:
		unit.statuses.clear()
	if "status_names" in unit and unit.status_names != null:
		unit.status_names.clear()
	if "skill_cooldowns" in unit and unit.skill_cooldowns != null:
		var cooldowns: Array = unit.skill_cooldowns
		for i in range(cooldowns.size()):
			cooldowns[i] = 0
	if "shield" in unit:
		unit.shield = 0
	if "moved" in unit:
		unit.moved = false
	if "acted" in unit:
		unit.acted = false
	if "turns_taken" in unit:
		unit.turns_taken = 0
	if "selected_skill_index" in unit:
		unit.selected_skill_index = -1

# ---------------------------------------------------------------------------
# Turn engine — round loop
# ---------------------------------------------------------------------------

## Snapshot the initiative order for a new round and start the first turn.
## Alive units = the player + living enemies. Order = effective initiative
## DESC (身法, minus 20 while an init_minus_20 status is active), tie-broken
## by registration index ASC (player = 0, then enemy registration order).
##
## The sort is DECORATE-SORT-UNDECORATE with a stable insertion sort: Godot's
## Array.sort_custom is NOT stable, and 碧海潮生's -20 debuff can create ties
## mid-battle, so a strict total order with the unique registration index as
## the secondary key is mandatory for deterministic playtests.
func _begin_round() -> void:
	if phase == "PLAYER_TURN" or phase == "ENEMY_TURN":
		return  # A turn is already in progress — re-entry guard.
	debug_round_frame = Engine.get_process_frames()
	_set_phase("ROUND_END")

	# Reset once-per-round passives.
	_finger_dart_used = {}
	_sha_round_healed = {}

	# --- Build the round-order snapshot (decorate) ---
	var units: Array = [GameManager.get_player()]
	for e in GameManager.get_enemies_alive():
		units.append(e)

	var entries: Array = []
	for i in range(units.size()):
		var u = units[i]
		if u == null or not is_instance_valid(u):
			continue
		if "health" in u and int(u.health) <= 0:
			continue
		entries.append([_effective_initiative(u), i, u])

	# --- Stable insertion sort: effective_init DESC, registration index ASC ---
	for i in range(1, entries.size()):
		var key: Array = entries[i]
		var j: int = i - 1
		while j >= 0 and _round_entry_before(key, entries[j]):
			entries[j + 1] = entries[j]
			j -= 1
		entries[j + 1] = key

	# --- Undecorate into unit list + name snapshot ---
	_turn_order_units = []
	turn_order = []
	for entry in entries:
		_turn_order_units.append(entry[2])
		turn_order.append(_name_of(entry[2]))

	if _turn_order_units.is_empty():
		# Do NOT fall through to _next_turn() here. On an empty order it calls
		# _end_round(), which increments the round and calls _begin_round()
		# again, which lands right back here — three stack frames per round,
		# forever, until "Stack overflow. Check for infinite recursion".
		# Measured on run jinyong-cultivate, 2026-08-23: six such errors,
		# reported at game_manager.gd:108 and combat_manager.gd:541 — neither
		# of which is the recursion, only wherever the stack happened to run
		# out. The cycle has no base case; this is it.
		#
		# A round with nobody in it is a broken battle, not a quiet edge case,
		# so it is made LOUD rather than stalled silently: push_error surfaces
		# in playtest_report.errors, and the counter lets a scenario assert on
		# it directly.
		empty_round_stalls += 1
		push_error("Round %d began with no unit able to act — battle cannot advance." % current_round)
		_set_phase("ROUND_END")
		return

	round_started.emit(current_round)
	_next_turn()


## Compare two decorated round entries: true when `a` sorts before `b`
## (higher effective initiative first; ties broken by earlier registration).
func _round_entry_before(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	return a[1] < b[1]


## Advance to the next unit's turn. Dead units pop; an empty queue ends the
## round. The player's turn is event-driven (awaits Space via
## end_current_turn()); enemy turns run their AI exactly once and execute the
## resulting move path + action with tween-awaited animation.
func _next_turn() -> void:
	if GameManager.get_state() == "WON" or GameManager.get_state() == "LOST":
		return

	# Pop dead heads (units killed earlier this round never act).
	while not _turn_order_units.is_empty():
		# Check-then-cast: a raw Variant read never crashes on a freed object,
		# but `as Node` raises "Trying to cast a freed object" at the cast
		# itself. Validate BEFORE any typed assignment.
		var raw_head = _turn_order_units[0]
		if raw_head == null or not is_instance_valid(raw_head):
			_turn_order_units.pop_front()
			continue
		var head: Node = raw_head  # typed assignment only after validation
		if "health" in head and int(head.health) <= 0:
			_turn_order_units.pop_front()
			continue
		break

	if _turn_order_units.is_empty():
		_end_round()
		return

	# Check-then-cast: the popped head may be a freed object (queue_free() is
	# deferred — a unit killed mid-round is still in the queue). Consume the
	# invalid head and recurse so the next valid head takes the turn.
	var raw_unit = _turn_order_units.pop_front()
	if raw_unit == null or not is_instance_valid(raw_unit):
		_next_turn()
		return
	var unit: Node = raw_unit  # typed assignment only after validation
	_active_unit = unit
	active_unit_name = _name_of(unit)

	var is_player_unit: bool = _is_player(unit)
	_set_phase("PLAYER_TURN" if is_player_unit else "ENEMY_TURN")
	turn_started.emit(unit)

	begin_turn(unit)

	# A unit that dies during its own turn-start ticks (DoT, 先天一炁, ...)
	# records its turn and does not act.
	if GameManager.get_state() == "WON" or GameManager.get_state() == "LOST":
		return
	if "health" in unit and int(unit.health) <= 0:
		end_current_turn()
		return

	if is_player_unit:
		# Event-driven: wait for the player to press Space (end_current_turn).
		_player_turn_done = false
		while not _player_turn_done \
				and GameManager.get_state() not in ["WON", "LOST"]:
			await get_tree().process_frame
		return  # end_current_turn() already continued the loop.

	# --- Enemy turn: AI decides ONCE, then move path + one action. ---
	while is_paused:
		await get_tree().process_frame

	var decision: Dictionary = _evaluate_ai(unit)

	if not decision.is_empty():
		var move_path: Array = decision.get("move_path", [])
		var action: String = decision.get("action", "")
		var target: Node = decision.get("target", null)
		var skill_index: int = decision.get("skill_index", -1)
		var params: Dictionary = decision.get("params", {})

		if target == null or not is_instance_valid(target):
			target = GameManager.get_player()

		# Legacy single-step "move" decision -> normalize to a move path.
		if action == "move":
			if move_path.is_empty() and params.has("to"):
				move_path = [unit.grid_pos, params.to]
			action = ""

		# Surface observability: let the AI declare its FSM state.
		if "fsm_state" in unit:
			var fsm: String = decision.get("fsm_state", "")
			if fsm != "":
				unit.fsm_state = fsm

		if not move_path.is_empty():
			await execute_move_path(unit, move_path)
			if GameManager.get_state() == "WON" or GameManager.get_state() == "LOST":
				return

		if action != "" and action != "wait":
			if params.is_empty() and action == "skill" and skill_index >= 0:
				params = { skill_index = skill_index }
			await execute_action(unit, action, target, params)
			if GameManager.get_state() == "WON" or GameManager.get_state() == "LOST":
				return

	if "acted" in unit:
		unit.acted = true
	end_current_turn()


## End the current round and begin the next one.
func _end_round() -> void:
	_set_phase("ROUND_END")
	current_round += 1
	_begin_round()


## End the active unit's turn: increment turns_taken, log the actor, clear
## one-turn restrictions, emit turn_ended, and advance to the next unit.
## Called by the player (Space) and by the engine after enemy turns.
func end_current_turn() -> void:
	var unit: Node = _active_unit
	if unit == null or not is_instance_valid(unit):
		_player_turn_done = true
		return

	if "turns_taken" in unit:
		unit.turns_taken += 1

	var name: String = _name_of(unit)
	turn_log.append(name)
	last_turn_actor = name

	if unit.has_method("clear_this_turn_restrictions"):
		unit.clear_this_turn_restrictions()
	else:
		# Defensive fallback: consume the "next turn" restriction statuses.
		_remove_status(unit, "move_minus_next_turn")
		_remove_status(unit, "no_techniques_next_turn")
		_remove_status(unit, "no_move_next_turn")

	turn_ended.emit(unit)
	_player_turn_done = true
	_next_turn()

# ---------------------------------------------------------------------------
# Turn-start lifecycle (design 10_systems §5.2) — exact order:
#   1) cooldown decrement    2) DoT/status ticks (incl. hazard zone lifetime)
#   3) constant regen        4) the unit acts
# ---------------------------------------------------------------------------

## Run the unit's turn-start lifecycle. Called by the engine before the unit
## acts (both player and enemy turns).
func begin_turn(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return

	# Reset this turn's budgets.
	if "moved" in unit:
		unit.moved = false
	if "acted" in unit:
		unit.acted = false
	var move_range: int = _move_range_of(unit)
	if "moves_left" in unit:
		unit.moves_left = move_range
	# "Next turn" restrictions apply for this turn.
	if _has_status(unit, "no_move_next_turn"):
		unit.moves_left = 0
	elif _has_status(unit, "move_minus_next_turn"):
		unit.moves_left = max(move_range - 2, 0)

	# (1) Cooldowns decrement by round at the unit's own turn start.
	if "skill_cooldowns" in unit and unit.skill_cooldowns != null:
		for i in range(unit.skill_cooldowns.size()):
			if int(unit.skill_cooldowns[i]) > 0:
				unit.skill_cooldowns[i] = int(unit.skill_cooldowns[i]) - 1
		if unit.has_signal("cooldowns_updated"):
			unit.cooldowns_updated.emit(unit.skill_cooldowns.duplicate())

	# (2) DoT / status ticks.
	_tick_statuses(unit)
	_tick_hazard_zones(unit)

	# (3) Constant regen from the primary internal art's passive.
	var passive: String = _passive_of(unit)
	match passive:
		"shen_diao_power":
			apply_heal(unit, 26)  # round(20 * 1.3)
		"one_yang_renewal":
			apply_heal(unit, 13)  # round(10 * 1.3)

	# (4) The unit acts (driven by the turn engine / player input).


## Tick round-based status durations at the owner's turn start. Poison DoT
## entries deal their stored tick damage (captured at application time) and
## then decrement; shield / init debuff / toad-charge durations decrement and
## expire at 0. "Next turn" restriction statuses are NOT ticked here — they
## persist through the turn and are cleared at its end.
func _tick_statuses(unit: Node) -> void:
	if unit == null or not ("statuses" in unit) or unit.statuses == null:
		return
	var i: int = 0
	while i < unit.statuses.size():
		var st: Dictionary = unit.statuses[i]
		var id: String = st.get("id", "")
		var rounds: int = st.get("rounds", 0)

		if id == "move_minus_next_turn" or id == "no_techniques_next_turn" \
				or id == "no_move_next_turn":
			i += 1
			continue

		if id == "poison" and rounds > 0:
			var tick: int = int(st.get("params", {}).get("tick", 0))
			if tick > 0:
				apply_damage(unit, tick, st.get("params", {}).get("source", null), false)

		rounds -= 1
		st["rounds"] = rounds
		if rounds <= 0:
			if id == "shield" and "shield" in unit:
				unit.shield = 0
			unit.statuses.remove_at(i)
			continue
		i += 1
	_refresh_status_names(unit)


## Decrement hazard-zone lifetimes at the caster's turn start; zones that hit
## 0 are removed.
func _tick_hazard_zones(unit: Node) -> void:
	var tiles_to_remove: Array[Vector2i] = []
	for tile in hazard_zones.keys():
		var zone: Dictionary = hazard_zones[tile]
		if zone.get("owner", null) == unit:
			zone["rounds"] = int(zone.get("rounds", 0)) - 1
			if zone["rounds"] <= 0:
				tiles_to_remove.append(tile)
	for tile in tiles_to_remove:
		hazard_zones.erase(tile)

# ---------------------------------------------------------------------------
# Public API — Damage / Heal / Shield / DoT / Status / Knockback
# ---------------------------------------------------------------------------

## Apply damage to a target through the two-stage pipeline:
##   attack side (already computed by the caller): round(base x buffs x fhd)
##   defense side (here): round(output x (1 - DR_total))
## DR tags: 丐帮铁骨 -15% all damage; 神雕之力 -50% melee (Chebyshev <= 1).
## ignore_damage_reduction (一阳指) skips all DR tags.
## Order: DR -> shield absorb -> HP -> 先天罡气 fatal guard (before death) ->
## death handling -> 一阳续命 below-40% heal -> counter/reflect (owner alive).
func apply_damage(target: Node, amount: int, source: Node = null,
		is_melee: bool = false, ignore_dr: bool = false) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not ("health" in target and "max_health" in target):
		return
	if amount <= 0:
		return

	# --- Defense side: damage reduction ---
	var actual: int = amount
	if not ignore_dr:
		var dr: float = _damage_reduction(target, is_melee)
		actual = int(round(amount * (1.0 - dr)))
	if actual < 0:
		actual = 0

	# --- Shield absorb ---
	var shield_amount: int = int(target.shield) if "shield" in target else 0
	if shield_amount > 0:
		var absorbed: int = min(shield_amount, actual)
		target.shield = shield_amount - absorbed
		actual -= absorbed
		if int(target.shield) <= 0:
			_remove_status(target, "shield")

	# --- HP ---
	var hp_before: int = int(target.health)
	target.health = max(hp_before - actual, 0)
	var is_lethal: bool = int(target.health) <= 0
	# The actual HP-reducing amount (before the fatal guards clamp to 1) — the
	# 杀 lifesteal basis.
	var loss: int = hp_before - int(target.health)

	# --- 先天罡气 fatal guard BEFORE death handling (DoT ticks included) ---
	if is_lethal and _passive_of(target) == "innate_qi" \
			and not bool(_innate_qi_used.get(target.get_instance_id(), false)):
		target.health = 1
		is_lethal = false
		_innate_qi_used[target.get_instance_id()] = true
		_clear_negative_statuses(target)

	# --- 铁布衫 fatal guard (mirror 先天罡气; once per battle) ---
	# Checked after 先天罡气: if the innate-qi guard already cleared the lethal
	# hit, the iron-shirt guard must not also fire (first setter wins).
	if is_lethal and _traits_of(target).has("iron_shirt") \
			and not bool(_iron_shirt_used.get(target.get_instance_id(), false)):
		target.health = 1
		is_lethal = false
		_iron_shirt_used[target.get_instance_id()] = true
		debug_iron_shirt_procs += 1
		_clear_negative_statuses(target)

	damage_dealt.emit(target, amount, is_lethal)
	if target.has_signal("health_changed"):
		target.health_changed.emit(target.health, target.max_health)

	# --- 一阳续命: one-time +78 when surviving a hit below 40% HP ---
	if not is_lethal and int(target.health) > 0 \
			and _passive_of(target) == "one_yang_renewal" \
			and not bool(_one_yang_used.get(target.get_instance_id(), false)):
		var ratio: float = float(target.health) / float(target.max_health)
		if ratio < 0.4:
			_one_yang_used[target.get_instance_id()] = true
			apply_heal(target, 78)  # round(60 * 1.3)

	# --- 杀 lifesteal: heal round(20% of the actual loss), capped at 15% of the
	# owner's max HP per round (per-round budget keyed by the source's instance
	# id, reset at round start). Fires after HP deduction and the fatal guards
	# but before death handling — a lethal blow still heals (target death never
	# cancels it). No lifesteal on self-damage (source == target) or on
	# guard-clamped losses (loss == 0).
	if source != null and is_instance_valid(source) and source != target \
			and loss > 0 and _traits_of(source).has("sha_po_lang"):
		var src_id: int = source.get_instance_id()
		var heal: int = TraitEffects.sha_heal_amount(loss,
			int(source.max_health), int(_sha_round_healed.get(src_id, 0)))
		if heal > 0:
			apply_heal(source, heal)
			_sha_round_healed[src_id] = int(_sha_round_healed.get(src_id, 0)) + heal
			debug_sha_heal_total += heal

	if is_lethal:
		_handle_death(target)
		return

	# --- Counter / reflect (passive owner survived the triggering damage) ---
	_trigger_counter_reflect(target, source, is_melee)


## 弹指神通 counter (13, once per round, attacker within 3 tiles) and
## 蛤蟆反震 reflect (16, melee attacker) — both untyped (skip DR tags),
## triggered after the triggering damage fully resolves, only while the
## passive owner is still alive.
func _trigger_counter_reflect(target: Node, source: Node, is_melee: bool) -> void:
	if source == null or not is_instance_valid(source):
		return
	if source == target:
		return
	if not ("health" in source) or int(source.health) <= 0:
		return
	match _passive_of(target):
		"finger_dart":
			if bool(_finger_dart_used.get(target.get_instance_id(), false)):
				return
			if _distance_between(target, source) <= 3:
				_finger_dart_used[target.get_instance_id()] = true
				apply_damage(source, 13, target, false, true)  # round(10*1.3)
		"toad_reflect":
			if is_melee:
				debug_reflect_hits += 1  # 蛤蟆反震 triggered on a melee attacker
				apply_damage(source, 16, target, false, true)  # round(12*1.3)


## Apply a fully-cooked heal amount (the caller already applied the fa_hui_du
## multiplier). Clamps health to max_health. Emits health_changed.
func apply_heal(target: Node, amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not ("health" in target and "max_health" in target):
		return
	if amount <= 0:
		return
	target.health = min(int(target.health) + amount, int(target.max_health))
	if target.has_signal("health_changed"):
		target.health_changed.emit(target.health, target.max_health)


## Grant a shield absorbing `amount` (already cooked) for `rounds` rounds.
## Overwrites any existing shield pool and refreshes its duration.
func apply_shield(target: Node, amount: int, rounds: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if amount <= 0 or rounds <= 0:
		return
	if "shield" in target:
		target.shield = amount
	_ensure_statuses(target)
	for st in target.statuses:
		if st.get("id", "") == "shield":
			st["rounds"] = rounds
			st["params"] = { amount = amount }
			_refresh_status_names(target)
			return
	target.statuses.append({
		id = "shield", kind = "positive", rounds = rounds, params = { amount = amount },
	})
	_refresh_status_names(target)


## Apply a damage-over-time effect. The tick value round(base_tick x fhd) is
## captured AT APPLICATION TIME and stored in the poison status; each tick
## deals that stored value at the victim's turn start. Multiple DoTs stack.
func apply_dot(target: Node, base_tick: int, rounds: int,
		fa_hui_du: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if base_tick <= 0 or rounds <= 0:
		return
	_ensure_statuses(target)
	var tick: int = int(round(base_tick * fa_hui_du))
	target.statuses.append({
		id = "poison", kind = "negative", rounds = rounds,
		params = { tick = tick, source = null },
	})
	_refresh_status_names(target)


## Apply a status effect to a unit. Poison delegates to apply_dot (the tick
## is cooked with the given fa_hui_du); round-valued statuses decrement at the
## owner's turn start.
func apply_status(target: Node, status_id: String,
		params: Dictionary = {}) -> void:
	if target == null or not is_instance_valid(target):
		return
	_ensure_statuses(target)
	if status_id == "poison":
		apply_dot(target, int(params.get("tick", 0)),
			int(params.get("rounds", 1)), DEFAULT_FA_HUI_DU)
		return

	var entry: Dictionary = {
		id = status_id, kind = "positive", rounds = 1, params = params,
	}
	match status_id:
		"init_minus_20":
			entry.kind = "negative"
			entry.rounds = 2
		"move_minus_next_turn":
			entry.kind = "negative"
		"no_techniques_next_turn":
			entry.kind = "negative"
		"no_move_next_turn":
			entry.kind = "negative"
		"toad_charge":
			# Buff for the next round's first technique: survives to that
			# turn's start (2 -> 1) and through it; consumed on use or at
			# that turn's end.
			entry.rounds = 2
	target.statuses.append(entry)
	_refresh_status_names(target)


## Apply knockback to a target. Moves the target `tiles` tiles in the given
## cardinal direction. Clamped to bounds. If the destination tile is occupied,
## stops one tile before (at the last non-occupied tile along the path).
func apply_knockback(target: Node, direction: Vector2i, tiles: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if tiles <= 0 or direction == Vector2i.ZERO:
		return
	if not ("grid_pos" in target):
		return

	var current_pos: Vector2i = target.grid_pos
	var final_pos: Vector2i = current_pos

	# Walk tile by tile to respect occupancy and bounds.
	for i in range(tiles):
		var next_pos: Vector2i = final_pos + direction

		# Stop if out of bounds.
		if not GridManager.is_in_bounds(next_pos) or not GridManager.is_walkable(next_pos):
			break

		# Stop if the tile is occupied (by someone other than self).
		if GridManager.is_occupied(next_pos) and next_pos != current_pos:
			break

		final_pos = next_pos

	# Only move if the position actually changed.
	if final_pos == current_pos:
		return

	# Free the current tile and reserve the new one.
	GridManager.free_tile(current_pos)
	if not GridManager.reserve_tile(final_pos, target):
		# Re-reserve origin if destination reservation fails (shouldn't happen
		# since we already checked, but guard anyway).
		GridManager.reserve_tile(current_pos, target)
		return

	# Update the target's grid_pos.
	target.grid_pos = final_pos

	# Animate the movement with a tween so we can await it.
	if target is Node2D:
		var tween: Tween = create_tween()
		tween.bind_node(target)
		tween.tween_property(target, "position",
			GridManager.grid_to_world(final_pos), 0.15)


## Remove all kind == "negative" statuses from a unit (先天罡气 guard).
func _clear_negative_statuses(target: Node) -> void:
	if target == null or not ("statuses" in target) or target.statuses == null:
		return
	var i: int = 0
	while i < target.statuses.size():
		if target.statuses[i].get("kind", "") == "negative":
			target.statuses.remove_at(i)
		else:
			i += 1
	_refresh_status_names(target)


## Remove every positive status (shield, toad_charge, ...) — 先天一炁 dispel.
func _dispel_buffs(target: Node) -> void:
	if target == null or not ("statuses" in target) or target.statuses == null:
		return
	var i: int = 0
	while i < target.statuses.size():
		var st: Dictionary = target.statuses[i]
		if st.get("kind", "") == "positive":
			if st.get("id", "") == "shield" and "shield" in target:
				target.shield = 0
			target.statuses.remove_at(i)
		else:
			i += 1
	_refresh_status_names(target)


## Remove all entries with the given status id.
func _remove_status(target: Node, status_id: String) -> void:
	if target == null or not ("statuses" in target) or target.statuses == null:
		return
	var i: int = 0
	while i < target.statuses.size():
		if target.statuses[i].get("id", "") == status_id:
			target.statuses.remove_at(i)
		else:
			i += 1
	_refresh_status_names(target)


## Make sure a unit carries a statuses array (contract: present during battle).
func _ensure_statuses(target: Node) -> void:
	if target == null:
		return
	# A typed array cannot be constructed by calling it — `Array[Dictionary]()`
	# is a parse error ("Cannot call on an expression"), and because this file is
	# an autoload it took every script that references CombatManager down with
	# it: one syntax error, twelve reported failures, zero rendered frames.
	# Declare the type on a local and assign that instead.
	if not ("statuses" in target):
		var fresh: Array[Dictionary] = []
		target.set("statuses", fresh)
	if target.statuses == null:
		var reset: Array[Dictionary] = []
		target.set("statuses", reset)


## Keep the observable status_names array in sync with the statuses table.
func _refresh_status_names(unit: Node) -> void:
	if unit == null or not ("status_names" in unit):
		return
	var names: Array[String] = []
	if "statuses" in unit and unit.statuses != null:
		for st in unit.statuses:
			names.append(str(st.get("id", "")))
	unit.status_names = names

# ---------------------------------------------------------------------------
# (Seconds-based DoT ticking REMOVED — round-based DoTs resolve at the
# victim's turn start inside begin_turn() / _tick_statuses().)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Public API — Action execution
# ---------------------------------------------------------------------------

## Execute a move path tile by tile (tween-awaited). Each step consumes 1
## movement point and applies the 桃花迷阵 zone penalty on entry (-2 to the
## remaining move budget, clamped at 0; the caster's own zones are ignored).
func execute_move_path(unit: Node, path: Array) -> void:
	if unit == null or not is_instance_valid(unit) or path.is_empty():
		return

	var moved_any: bool = false
	for i in range(1, path.size()):
		if GameManager.get_state() == "WON" or GameManager.get_state() == "LOST":
			return
		var to_pos: Vector2i = path[i] as Vector2i
		if not ("grid_pos" in unit) or to_pos == unit.grid_pos:
			continue
		if not GridManager.is_in_bounds(to_pos) or not GridManager.is_walkable(to_pos):
			continue
		if GridManager.is_occupied(to_pos):
			continue
		if "moves_left" in unit and int(unit.moves_left) <= 0:
			return
		if "moves_left" in unit:
			unit.moves_left = int(unit.moves_left) - 1
		var tween: Tween = _execute_move(unit, { to = to_pos })
		if tween != null:
			await _await_tween_safe(tween)
		moved_any = true
		# 桃花迷阵: entering a zone tile slows the mover (except the caster).
		if hazard_zones.has(to_pos) \
				and hazard_zones[to_pos].get("owner", null) != unit \
				and "moves_left" in unit:
			unit.moves_left = max(int(unit.moves_left) - 2, 0)
	if moved_any and "moved" in unit:
		unit.moved = true


## Execute one action ("basic_attack" | "skill") and await its animation.
## Only successful executions set cooldown / acted (handled inside the
## executors); invalid executions are silent no-ops.
func execute_action(unit: Node, action: String, target: Node,
		params: Dictionary) -> void:
	var tween: Tween = _execute_action(unit, action, target, params)
	if tween != null and is_instance_valid(tween):
		await _await_tween_safe(tween)


## Execute a single action. Returns a Tween if one was created (so the caller
## can await it), or null if no tween was needed.
##
## Supported actions:
##   "move"          — params.to (Vector2i): move unit to target grid position
##   "basic_attack"  — target (Node): apply basic attack damage
##   "skill"         — params.skill_index (int): use skill at that index
func _execute_action(unit: Node, action: String, target: Node,
		params: Dictionary) -> Tween:
	var tween: Tween = null

	match action:
		"move":
			tween = _execute_move(unit, params)
		"basic_attack":
			tween = _execute_basic_attack(unit, target)
		"skill":
			tween = _execute_skill(unit, target, params)
		_:
			push_warning("CombatManager: unknown action '%s'" % action)

	action_executed.emit(unit, action)
	return tween


## Execute a move action. Manages occupancy directly (free old tile, reserve
## new tile) and creates a tween for smooth movement.
## Returns the tween, or null if the move was invalid.
func _execute_move(unit: Node, params: Dictionary) -> Tween:
	if not ("to" in params):
		return null

	var from_pos: Vector2i
	if "grid_pos" in unit:
		from_pos = unit.grid_pos
	else:
		return null

	var to_pos: Vector2i = params.to as Vector2i

	# Validate destination.
	if not GridManager.is_in_bounds(to_pos):
		return null
	if not GridManager.is_walkable(to_pos):
		return null
	if GridManager.is_occupied(to_pos) and to_pos != from_pos:
		return null

	# Free origin, reserve destination.
	GridManager.free_tile(from_pos)
	if not GridManager.reserve_tile(to_pos, unit):
		# Re-reserve origin if reservation fails.
		GridManager.reserve_tile(from_pos, unit)
		return null

	# Move SFX — AI path; fires only when the destination was reserved.
	# Regression gate (fix_cascade_script_loads): AudioManager autoload parses,
	# so this call site resolves at compile time.
	AudioManager.play_move()

	# Update unit's grid_pos.
	unit.grid_pos = to_pos

	# Animate movement.
	if unit is Node2D:
		var move_tween: Tween = create_tween()
		move_tween.bind_node(unit)
		move_tween.tween_property(unit, "position",
			GridManager.grid_to_world(to_pos), 0.15)
		unit.is_moving = true
		move_tween.finished.connect(func():
			if is_instance_valid(unit):
				unit.is_moving = false
		, CONNECT_ONE_SHOT)
		return move_tween

	return null


## Execute a basic attack: attack-side round(base x primary-internal-art fhd),
## then the two-stage pipeline. Sets acted on success. Returns a flash tween.
func _execute_basic_attack(unit: Node, target: Node) -> Tween:
	if target == null or not is_instance_valid(target):
		return null
	if not ("health" in target):
		return null

	# Hit SFX — one play per valid basic attack. Deliberately NOT in
	# apply_damage(), which also fires per DoT tick and would spam.
	AudioManager.play_hit()

	# Base damage from the attacker's character_data; cook with the primary
	# internal art's fa_hui_du (design 10_systems §4.0).
	var base: int = 10  # default fallback
	if "character_data" in unit and unit.character_data != null:
		base = int(unit.character_data.attack_damage)
	# 狼 attack side: ×(1 + 0.08 × living enemies) AFTER fhd, BEFORE the
	# attack-side round(). Damage only — heals/shields/DoT never take it.
	debug_lang_attack_mult = 1.0
	var lang_mult: float = 1.0
	if _traits_of(unit).has("sha_po_lang"):
		lang_mult = TraitEffects.lang_attack_mult(_living_enemies_of(unit))
		debug_lang_attack_mult = lang_mult
	var output: int = int(round(base * _internal_fhd(unit) * lang_mult))

	apply_damage(target, output, unit, _is_melee_attack(unit, null))

	if "acted" in unit:
		unit.acted = true
	return _damage_flash(target)


## Execute a skill: gate checks (cooldown, technique seal, HP gate), jump
## displacement, then damage / DoT / status / knockback / heal / shield per
## the SkillData. Starts the cooldown and sets acted ONLY on successful
## execution. Returns a tween for effects, or null (not consumed).
func _execute_skill(unit: Node, target: Node, params: Dictionary) -> Tween:
	var skill_index: int = params.get("skill_index", -1)
	if skill_index < 0:
		return null

	var skills_arr = unit.skills if "skills" in unit else null
	if skills_arr == null or skill_index >= skills_arr.size():
		return null

	var skill = skills_arr[skill_index]
	if skill == null:
		return null

	# --- Execution gates (failure -> skill NOT consumed) ---
	if "skill_cooldowns" in unit and skill_index < unit.skill_cooldowns.size():
		if int(unit.skill_cooldowns[skill_index]) > 0:
			return null
	if _has_status(unit, "no_techniques_next_turn"):
		return null
	if skill.hp_gate_below_ratio > 0.0:
		var hp_ratio: float = float(unit.health) / float(unit.max_health) \
			if int(unit.max_health) > 0 else 1.0
		if hp_ratio >= skill.hp_gate_below_ratio:
			return null

	# --- Jump displacement (landing tile becomes the AoE origin) ---
	var origin: Vector2i = unit.grid_pos if "grid_pos" in unit else Vector2i.ZERO
	var jump_tween: Tween = null
	if skill.jump_tiles > 0:
		var landing: Vector2i = _compute_jump_landing(unit, int(skill.jump_tiles))
		if landing == unit.grid_pos:
			return null  # No valid landing — skill NOT consumed.
		origin = landing
		jump_tween = _displace_unit(unit, landing)

	# Hit SFX — one play per valid skill execution, before damage is applied.
	AudioManager.play_hit()

	var fhd: float = _external_fhd_for_skill(unit, skill)
	var buffs: float = _consume_toad_charge(unit)  # 蛤蟆蹲 x1.5 (damage only)
	# 狼 attack side: ×(1 + 0.08 × living enemies) AFTER fhd/buffs, BEFORE the
	# attack-side round(). Damage only — heals/shields/DoT ticks never take it.
	debug_lang_attack_mult = 1.0
	var lang_mult: float = 1.0
	if _traits_of(unit).has("sha_po_lang"):
		lang_mult = TraitEffects.lang_attack_mult(_living_enemies_of(unit))
		debug_lang_attack_mult = lang_mult
	var damage: int = 0
	if skill.damage > 0:
		damage = int(round(float(skill.damage) * buffs * fhd * lang_mult))

	# --- Resolve hit targets ---
	var hit_units: Array[Node] = []
	if skill.aoe_shape == "global":
		hit_units = _hostile_units_of(unit)
	elif skill.aoe_shape == "single":
		if skill.target_friendly:
			if target != null and is_instance_valid(target):
				hit_units = [target]
			else:
				hit_units = [unit]
		elif target != null and is_instance_valid(target):
			hit_units = [target]
	else:
		var aoe_origin: Vector2i = origin
		if skill.aoe_origin == "target" and target != null and "grid_pos" in target:
			aoe_origin = target.grid_pos
		var direction: Vector2i = Vector2i.ZERO
		if skill.aoe_shape == "line":
			direction = _line_direction(aoe_origin, target)
		if skill.target_friendly:
			var foe: Node = _first_hostile_unit_of(unit)
			hit_units = GridManager.get_units_in_aoe(aoe_origin, skill.aoe_shape,
				skill.aoe_size, direction, foe)
		else:
			hit_units = GridManager.get_units_in_aoe(aoe_origin, skill.aoe_shape,
				skill.aoe_size, direction, unit)

	# --- Self-buffs / zones (always target the caster) ---
	match skill.status_applied:
		"toad_charge":
			apply_status(unit, "toad_charge")
		"hazard_zone":
			_place_hazard_zone(unit, skill)
	if skill.shield_amount > 0:
		apply_shield(unit,
			int(round(float(skill.shield_amount) * _internal_fhd(unit))),
			int(skill.shield_rounds))

	# --- Per-hit effects: damage, DoT, status, knockback ---
	for h in hit_units:
		if h == null or not is_instance_valid(h):
			continue
		if damage > 0:
			apply_damage(h, damage, unit, _is_melee_attack(unit, skill),
				bool(skill.ignore_damage_reduction))
		if skill.dot_damage > 0 and skill.dot_rounds > 0:
			apply_dot(h, int(skill.dot_damage), int(skill.dot_rounds), fhd)
		var status_id: String = skill.status_applied
		if status_id == "dispel_hostile_buffs":
			_dispel_buffs(h)
		elif status_id != "" and status_id != "poison" \
				and status_id != "toad_charge" and status_id != "hazard_zone":
			apply_status(h, status_id)
		if skill.knockback > 0 and "grid_pos" in h:
			_apply_knockback_from(h, unit, int(skill.knockback))

	# --- Heal ---
	if skill.heal_amount > 0:
		var heal_targets: Array[Node] = []
		if skill.target_friendly:
			heal_targets = hit_units
			if heal_targets.is_empty() and target != null and is_instance_valid(target):
				heal_targets = [target]
		else:
			heal_targets = [unit]
		for h in heal_targets:
			apply_heal(h, int(round(float(skill.heal_amount) * fhd)))

	# --- Start cooldown (only on successful execution) ---
	if "skill_cooldowns" in unit and skill_index < unit.skill_cooldowns.size():
		unit.skill_cooldowns[skill_index] = int(skill.cooldown)
	if unit.has_signal("cooldowns_updated"):
		unit.cooldowns_updated.emit(unit.skill_cooldowns.duplicate())
	if "acted" in unit:
		unit.acted = true

	# Return the primary tween (jump displacement if any, else damage flash).
	if jump_tween != null:
		return jump_tween
	if target != null and is_instance_valid(target):
		return _damage_flash(target)
	return _damage_flash(unit)


## Place a 桃花迷阵 hazard zone: every tile in the square AoE around the
## caster becomes a zone for 3 rounds (its own lifetime, decremented at the
## caster's turn start).
func _place_hazard_zone(unit: Node, skill) -> void:
	var center: Vector2i = unit.grid_pos if "grid_pos" in unit else Vector2i.ZERO
	var tiles: Array[Vector2i] = GridManager.get_tiles_in_aoe(center,
		"square", max(int(skill.aoe_size), 1))
	for tile in tiles:
		hazard_zones[tile] = { rounds = 3, owner = unit }


## Jump displacement: up to `tiles` tiles along the A* path toward the nearest
## hostile unit, landing on the furthest walkable, unoccupied tile. Returns
## the landing tile (== start when no valid landing exists).
func _compute_jump_landing(unit: Node, tiles: int) -> Vector2i:
	var start: Vector2i = unit.grid_pos if "grid_pos" in unit else Vector2i.ZERO
	var foe: Node = _nearest_hostile_unit(unit)
	if foe == null or not is_instance_valid(foe) or not ("grid_pos" in foe):
		return start
	var path: Array[Vector2i] = GridManager.find_path(start, foe.grid_pos)
	var landing: Vector2i = start
	for i in range(1, min(path.size(), tiles + 1)):
		var tile: Vector2i = path[i]
		if not GridManager.is_in_bounds(tile) or not GridManager.is_walkable(tile):
			break
		if GridManager.is_occupied(tile) and tile != start:
			break
		landing = tile
	return landing


## Teleport a unit to a tile (occupancy + position). Returns the tween, or
## null if the displacement was invalid.
func _displace_unit(unit: Node, to_pos: Vector2i) -> Tween:
	var from_pos: Vector2i = unit.grid_pos if "grid_pos" in unit else Vector2i.ZERO
	if from_pos == to_pos:
		return null
	GridManager.free_tile(from_pos)
	if not GridManager.reserve_tile(to_pos, unit):
		GridManager.reserve_tile(from_pos, unit)
		return null
	unit.grid_pos = to_pos
	if unit is Node2D:
		var tween: Tween = create_tween()
		tween.bind_node(unit)
		tween.tween_property(unit, "position", GridManager.grid_to_world(to_pos), 0.15)
		return tween
	return null


## Knockback direction away from `unit`, applied via apply_knockback.
func _apply_knockback_from(target: Node, unit: Node, tiles: int) -> void:
	if target == null or not ("grid_pos" in target):
		return
	if unit == null or not ("grid_pos" in unit):
		return
	var unit_pos: Vector2i = unit.grid_pos
	var target_pos: Vector2i = target.grid_pos
	var kb_dir: Vector2i = Vector2i(sign(target_pos.x - unit_pos.x),
		sign(target_pos.y - unit_pos.y))
	if abs(target_pos.x - unit_pos.x) >= abs(target_pos.y - unit_pos.y):
		kb_dir.y = 0
	else:
		kb_dir.x = 0
	apply_knockback(target, kb_dir, tiles)

# ---------------------------------------------------------------------------
# Internal — Helpers
# ---------------------------------------------------------------------------

## Await a tween's `finished` signal, but never hang: if the tween is null,
## freed, or killed before finishing (e.g. its bound node was queue_free'd),
## give up after TWEEN_TIMEOUT_SEC and return. The `done` flag is a 1-element
## Array because GDScript lambdas capture local variables BY VALUE — assigning
## a bare local inside the lambda never propagates back to this scope, while
## mutating a shared Array element does.
func _await_tween_safe(tween: Tween) -> void:
	if tween == null:
		return

	debug_await_total += 1
	var done: Array = [false]
	tween.finished.connect(func(): done[0] = true, CONNECT_ONE_SHOT)
	var timer := get_tree().create_timer(TWEEN_TIMEOUT_SEC, true)
	while not done[0] and timer.time_left > 0.0:
		debug_await_frames += 1
		await get_tree().process_frame
	if not done[0]:
		debug_await_timeouts += 1


## Handle death of a character node.
## Distinguishes between player death and enemy death.
func _handle_death(target: Node) -> void:
	if not is_instance_valid(target):
		return

	# Determine if this is the player or an enemy.
	var is_player: bool = false
	if target.has_method("is_player") or target.name == "Player" \
			or target.name == "YangGuo":
		is_player = true

	if is_player:
		GameManager.end_battle(false)
	else:
		# Free the grid tile.
		if "grid_pos" in target:
			GridManager.free_tile(target.grid_pos)

		# Unregister from GameManager.
		GameManager.unregister_enemy(target)

		# Remove from scene tree.
		target.queue_free()


## Create a damage flash effect on a target Node2D.
## Modulates Sprite2D children overbright for 0.1s, then restores the
## original modulate. Returns the tween so the caller can await it.
func _damage_flash(target: Node) -> Tween:
	# Safe: `target` is validated with is_instance_valid before any use, and
	# the child lookups below use get_node_or_null, which re-resolves the path
	# each call and returns null for freed nodes — never a freed-object cast.
	if target == null or not is_instance_valid(target):
		return null
	if not target is Node2D:
		return null

	# Find a Sprite2D child (or use the target itself if it's a Sprite2D).
	var poly: Node2D = null
	if target is Sprite2D:
		poly = target
	else:
		poly = target.get_node_or_null("Sprite") as Sprite2D
		if poly == null:
			poly = target.get_child(0) as Sprite2D

	if poly == null:
		return null

	var original_modulate: Color = poly.modulate
	poly.modulate = Color(2, 2, 2)

	var flash_tween: Tween = create_tween()
	# Bind to CombatManager (never freed) so the tween survives target death.
	# The modulate-restore callback already guards with is_instance_valid(poly).
	flash_tween.bind_node(self)
	flash_tween.tween_callback(func():
		if is_instance_valid(poly):
			poly.modulate = original_modulate
	).set_delay(0.1)

	return flash_tween


## Call an AI controller's evaluate() exactly once per enemy turn. Supports
## both the new single-argument contract (evaluate(enemy) -> {move_path,
## action, target, skill_index, params}) and the legacy three-argument one
## (evaluate(enemy, player, delta)).
func _evaluate_ai(unit: Node) -> Dictionary:
	var ai = unit.ai_controller if "ai_controller" in unit else null
	if ai == null or not ai.has_method("evaluate"):
		return {}
	var n_args: int = -1
	for m in ai.get_method_list():
		if m.has("name") and m.name == "evaluate":
			n_args = int(m.args.size())
			break
	var result: Variant = {}
	if n_args >= 3:
		result = ai.evaluate(unit, GameManager.get_player(), 0.0)
	else:
		result = ai.evaluate(unit)
	if result is Dictionary:
		return result
	return {}

# ---------------------------------------------------------------------------
# Stat / data helpers
# ---------------------------------------------------------------------------

## Display name of a unit (character_name, falling back to the node name).
func _name_of(unit: Node) -> String:
	if unit == null:
		return ""
	if "character_data" in unit and unit.character_data != null \
			and "character_name" in unit.character_data \
			and unit.character_data.character_name != "":
		return str(unit.character_data.character_name)
	return str(unit.name)


## True when the unit is the player character.
func _is_player(unit: Node) -> bool:
	var p: Node = GameManager.get_player()
	if p == null:
		return unit.name == "Player" or unit.name == "YangGuo"
	return unit.get_instance_id() == p.get_instance_id()


## The unit's trait ids (combat hook lookups). Priority: the node's own
## `traits` property when the node declares it, else the battle CharacterData's
## `traits` (the current carrier — BattleSetup.build_character copies
## profile.traits onto it), else []. Always returns a fresh Array[String].
func _traits_of(unit: Node) -> Array[String]:
	var result: Array[String] = []
	if unit == null or not is_instance_valid(unit):
		return result
	if "traits" in unit:
		var node_traits = unit.traits
		if node_traits is Array:
			for t in node_traits:
				result.append(str(t))
		return result
	if "character_data" in unit and unit.character_data != null \
			and "traits" in unit.character_data:
		var cd_traits = unit.character_data.traits
		if cd_traits is Array:
			for t in cd_traits:
				result.append(str(t))
	return result


## Number of living enemies of the given unit at resolve time (狼 scaling):
## the player counts the registered living enemies; an enemy counts the living
## hostile units (the player). Dead-but-not-yet-unregistered units are skipped.
func _living_enemies_of(unit: Node) -> int:
	var foes: Array[Node] = _hostile_units_of(unit)
	var count: int = 0
	for foe in foes:
		if foe != null and is_instance_valid(foe) \
				and (not ("health" in foe) or int(foe.health) > 0):
			count += 1
	return count


func _initiative_of(unit: Node) -> int:
	if unit == null:
		return 0
	if "initiative" in unit:
		return int(unit.initiative)
	if "character_data" in unit and unit.character_data != null \
			and "initiative" in unit.character_data:
		return int(unit.character_data.initiative)
	return 0


## Effective initiative for round snapshots: 身法 minus 20 while an
## init_minus_20 status is active (碧海潮生).
func _effective_initiative(unit: Node) -> int:
	var eff: int = _initiative_of(unit)
	if _has_status(unit, "init_minus_20"):
		eff -= 20
	return eff


func _move_range_of(unit: Node) -> int:
	if unit == null:
		return 1
	if "character_data" in unit and unit.character_data != null \
			and "move_range" in unit.character_data:
		return int(unit.character_data.move_range)
	return 1


## The unit's primary internal art passive id (shen_diao_power, finger_dart,
## toad_reflect, one_yang_renewal, beggar_iron_bone, innate_qi).
func _passive_of(unit: Node) -> String:
	if unit == null:
		return ""
	if "passive_id" in unit:
		return str(unit.passive_id)
	if "character_data" in unit and unit.character_data != null \
			and "passive_id" in unit.character_data:
		return str(unit.character_data.passive_id)
	return ""


## True when the unit carries the given status with at least 1 round left.
func _has_status(unit: Node, status_id: String) -> bool:
	if unit == null or not ("statuses" in unit) or unit.statuses == null:
		return false
	for st in unit.statuses:
		if st.get("id", "") == status_id and st.get("rounds", 0) >= 1:
			return true
	return false


## fa_hui_du of the unit's primary internal art (basic attacks / passives).
func _internal_fhd(unit: Node) -> float:
	var fhd: float = DEFAULT_FA_HUI_DU
	if unit != null and "character_data" in unit and unit.character_data != null:
		var arts = unit.character_data.internal_arts
		if arts != null and arts.size() > 0 and arts[0] != null:
			fhd = get_fa_hui_du(arts[0], unit.character_data)
	return fhd


## fa_hui_du of the external art that produced `skill`.
func _external_fhd_for_skill(unit: Node, skill) -> float:
	var fhd: float = DEFAULT_FA_HUI_DU
	if unit != null and "character_data" in unit and unit.character_data != null:
		var arts = unit.character_data.external_arts
		if arts != null:
			for art in arts:
				if art != null and "techniques" in art and art.techniques != null:
					if skill in art.techniques:
						return get_fa_hui_du(art, unit.character_data)
	return fhd


## Delegate to the GongfaData fa_hui_du cascade. `unit` is the acting unit's
## CharacterData (never the battle Node): it carries the staged_values /
## internal_arts / external_arts / attribute fields the cascade reads. Falls
## back to DEFAULT_FA_HUI_DU when the gongfa has no cascade method.
func get_fa_hui_du(gongfa, unit) -> float:
	if gongfa != null and gongfa.has_method("get_fa_hui_du"):
		return float(gongfa.get_fa_hui_du(unit))
	return DEFAULT_FA_HUI_DU


## Defense-side damage reduction: 丐帮铁骨 -15% all damage; 神雕之力 -50%
## melee (weapon-class classification via _is_melee_attack); 狼 (sha_po_lang)
## +5% DR per living enemy of the target (raw add — percentages never take
## the fhd multiplier). ignore_damage_reduction skips the whole term.
func _damage_reduction(target: Node, is_melee: bool) -> float:
	var dr: float = 0.0
	match _passive_of(target):
		"beggar_iron_bone":
			dr += 0.15
		"shen_diao_power":
			if is_melee:
				dr += 0.5  # −50% melee DR (flat; percentages never take the fhd multiplier)
	# 狼 defense side.
	if _traits_of(target).has("sha_po_lang"):
		dr += TraitEffects.lang_dr(_living_enemies_of(target))
	return dr


## 蛤蟆蹲 charge: returns 1.5 and consumes the status when the unit has an
## active charge (next round's first technique), else 1.0.
func _consume_toad_charge(unit: Node) -> float:
	if unit == null or not ("statuses" in unit) or unit.statuses == null:
		return 1.0
	for st in unit.statuses:
		if st.get("id", "") == "toad_charge" and st.get("rounds", 0) >= 1:
			unit.statuses.erase(st)
			_refresh_status_names(unit)
			return 1.5
	return 1.0


## Melee weapon classes (design/10_systems.md §2.2): 刀/剑/长兵/拳掌/轻功/横练
## are melee; 指/暗器/奇门毒/乐器 are ranged. The classification is decided by
## the external art's weapon class (外功门类) — NOT by shape, reach, or damage.
const MELEE_SCHOOLS: Array[String] = [
	"sword", "blade", "polearm", "palm", "qinggong", "hardening",
]


## True when the given GongfaData.school value is a melee weapon class.
func _school_is_melee(school: String) -> bool:
	return MELEE_SCHOOLS.has(school)


## Melee/ranged classification — the single place weapon-class semantics live.
## Drives BOTH the Shen Diao -50% melee DR (enemy -> player) and the West
## Poison 蛤蟆反震 reflect (player -> West Poison). Pure function of state:
## zero RNG, never reads grid_pos or distance.
##   skill_or_basic == null       -> basic attack: classify by the unit's
##                                    PRIMARY external art (external_arts[0],
##                                    主修外功).
##   skill_or_basic (SkillData)   -> classify by the declaring external art's
##                                    weapon class (found via
##                                    `skill in art.techniques`, the same
##                                    lookup as _external_fhd_for_skill).
## Missing/invalid data degrades conservatively to ranged (false); "internal"
## arts never declare techniques, so they can never be a skill source.
func _is_melee_attack(unit: Node, skill_or_basic) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not ("character_data" in unit) or unit.character_data == null:
		return false
	var arts = unit.character_data.external_arts
	if arts == null or arts.is_empty():
		return false
	if skill_or_basic == null:
		# Basic attack: classify by the primary external art (主修外功).
		if arts[0] != null:
			return _school_is_melee(str(arts[0].school))
		return false
	# Skill: find the declaring external art; "internal" arts never declare
	# techniques, so a not-found lookup conservatively returns ranged.
	for art in arts:
		if art != null and "techniques" in art and art.techniques != null:
			if skill_or_basic in art.techniques:
				return _school_is_melee(str(art.school))
	return false


func _distance_between(a: Node, b: Node) -> int:
	if a == null or b == null:
		return 999999
	if not ("grid_pos" in a and "grid_pos" in b):
		return 999999
	return _chebyshev(a.grid_pos, b.grid_pos)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


## All units hostile to the given unit (player vs enemies_alive, else player).
func _hostile_units_of(unit: Node) -> Array[Node]:
	var result: Array[Node] = []
	if _is_player(unit):
		for e in GameManager.get_enemies_alive():
			if is_instance_valid(e):
				result.append(e)
	else:
		var p: Node = GameManager.get_player()
		if p != null and is_instance_valid(p):
			result.append(p)
	return result


func _first_hostile_unit_of(unit: Node) -> Node:
	var foes: Array[Node] = _hostile_units_of(unit)
	if foes.is_empty():
		return null
	return foes[0]


func _nearest_hostile_unit(unit: Node) -> Node:
	var foes: Array[Node] = _hostile_units_of(unit)
	var best: Node = null
	var best_dist: int = 999999
	if unit == null or not ("grid_pos" in unit):
		return null
	for foe in foes:
		if foe == null or not is_instance_valid(foe) or not ("grid_pos" in foe):
			continue
		var d: int = _chebyshev(unit.grid_pos, foe.grid_pos)
		if d < best_dist:
			best_dist = d
			best = foe
	return best


## Cardinal direction from origin toward the target (for line AoEs).
func _line_direction(origin: Vector2i, target: Node) -> Vector2i:
	if target == null or not is_instance_valid(target) or not ("grid_pos" in target):
		return Vector2i.ZERO
	var t: Vector2i = target.grid_pos
	if abs(t.x - origin.x) >= abs(t.y - origin.y):
		return Vector2i(sign(t.x - origin.x), 0)
	return Vector2i(0, sign(t.y - origin.y))


## Set the engine phase and emit phase_changed on change.
func _set_phase(p: String) -> void:
	if phase != p:
		phase = p
		phase_changed.emit(p)
