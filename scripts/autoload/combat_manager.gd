## CombatManager (autoload)
##
## Real-Time-with-Pause (RTWP) combat manager singleton. Owns pause/unpause
## state, the action queue (FIFO serialized via tweens), damage/heal/DoT/
## knockback application, and death handling.
##
## Consumed by Player and Enemy scripts that call request_action(). Calls into
## GridManager (occupancy, movement) and GameManager (enemy tracking, win/lose).
extends Node

const SkillData = preload("res://scripts/data/skill_data.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the game is paused (Engine.time_scale set to 0).
signal paused()

## Emitted when the game is unpaused (Engine.time_scale set to 1.0).
signal unpaused()

## Emitted after an action is executed. Passes the unit and action name.
signal action_executed(unit: Node, action: String)

## Emitted when damage is applied to a target. Passes the target node,
## the amount of damage dealt, and whether the damage was lethal.
signal damage_dealt(target: Node, amount: int, is_lethal: bool)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const QUEUE_CAPACITY: int = 10
const PAUSE_DEBOUNCE_MS: int = 100

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Whether the game is currently paused.
var is_paused: bool = false

## FIFO action queue. Each entry: {unit: Node, action: String, target: Node,
## params: Dictionary}
var action_queue: Array[Dictionary] = []

## Whether an action is currently being processed (tween animation playing).
var _processing_action: bool = false

## The unit currently being processed (for is_unit_busy checks).
var _current_action_unit: Node = null

## Active damage-over-time effects.
## Each entry: {target: Node, damage_per_tick: int, ticks_remaining: int,
##              tick_interval: float, time_since_last_tick: float}
var active_dots: Array[Dictionary] = []

## Timestamp (ms) of the last pause toggle, for debounce.
var _last_pause_toggle: int = 0

# ---------------------------------------------------------------------------
# Public API — Pause / unpause
# ---------------------------------------------------------------------------

## Returns whether the game is currently paused.
func get_is_paused() -> bool:
	return is_paused


## Pause the game. Sets Engine.time_scale to 0, emitting paused signal.
## No-op if already paused.
func pause() -> void:
	if is_paused:
		return

	is_paused = true
	Engine.time_scale = 0.0
	paused.emit()


## Unpause the game. Sets Engine.time_scale to 1.0, emitting unpaused signal.
## Then drains the action queue. No-op if not paused.
func unpause() -> void:
	if not is_paused:
		return

	is_paused = false
	Engine.time_scale = 1.0
	unpaused.emit()
	_drain_action_queue()


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

# ---------------------------------------------------------------------------
# Public API — Action queue
# ---------------------------------------------------------------------------

## Request an action to be executed. Enqueues the action in the FIFO queue.
## If the queue is full (>= QUEUE_CAPACITY), returns false without enqueuing.
## If not paused and no action is currently processing, immediately drains
## the queue. Returns true on successful enqueue.
func request_action(unit: Node, action: String, target: Node,
		params: Dictionary = {}) -> bool:
	if action_queue.size() >= QUEUE_CAPACITY:
		return false

	action_queue.append({
		unit = unit,
		action = action,
		target = target,
		params = params,
	})

	# Start draining if not paused and not already processing.
	if not is_paused and not _processing_action:
		_drain_action_queue()

	return true


## Returns true if the given unit is "busy" — either currently being processed
## by an action, has a pending action in the queue, or is currently moving.
func is_unit_busy(unit: Node) -> bool:
	# Check if currently being processed.
	if _current_action_unit != null and _current_action_unit == unit:
		return true

	# Check for pending actions in the queue.
	for entry in action_queue:
		if entry.unit == unit:
			return true

	# Check if the unit's own is_moving flag is set.
	if unit.has_method("get_is_moving") or ("is_moving" in unit and unit.is_moving):
		return true

	# Fallback: check for any property that signals busy state.
	if "is_moving" in unit:
		return unit.is_moving

	return false

# ---------------------------------------------------------------------------
# Public API — Damage / Heal / DoT / Knockback
# ---------------------------------------------------------------------------

## Apply damage to a target. Clamps health to >= 0. Emits damage_dealt.
## If the target's health reaches 0, handles death:
##   - Player death: calls GameManager.end_battle(false).
##   - Enemy death: calls GameManager.unregister_enemy(target),
##     GridManager.free_tile(target.grid_pos), then queue_free.
func apply_damage(target: Node, amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return

	# Ensure the target has a health property.
	if not ("health" in target and "max_health" in target):
		return

	var old_health: int = target.health
	target.health = max(target.health - amount, 0)
	var is_lethal: bool = target.health <= 0

	damage_dealt.emit(target, amount, is_lethal)

	# Emit health_changed signal if the target exposes it.
	if target.has_signal("health_changed"):
		target.health_changed.emit(target.health, target.max_health)

	# Handle death.
	if is_lethal:
		_handle_death(target)


## Apply a damage-over-time effect to a target. Calculates number of ticks
## from duration / tick_interval and appends to active_dots.
func apply_dot(target: Node, damage_per_tick: int, duration: float,
		tick_interval: float = 1.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	if damage_per_tick <= 0 or duration <= 0 or tick_interval <= 0:
		return

	var ticks: int = int(duration / tick_interval)
	if ticks <= 0:
		ticks = 1

	active_dots.append({
		target = target,
		damage_per_tick = damage_per_tick,
		ticks_remaining = ticks,
		tick_interval = tick_interval,
		time_since_last_tick = 0.0,
	})


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
		if not GridManager.is_in_bounds(next_pos):
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


## Apply healing to a target. Clamps health to max_health. Emits health_changed.
func apply_heal(target: Node, amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not ("health" in target and "max_health" in target):
		return

	var old_health: int = target.health
	target.health = min(target.health + amount, target.max_health)

	if target.has_signal("health_changed"):
		target.health_changed.emit(target.health, target.max_health)

# ---------------------------------------------------------------------------
# Process — DoT tick
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# No DoT ticking while paused.
	if is_paused:
		return

	_tick_dots(delta)


## Tick all active damage-over-time effects.
func _tick_dots(delta: float) -> void:
	var i: int = 0
	while i < active_dots.size():
		var dot: Dictionary = active_dots[i]

		# Skip if the target is no longer valid.
		if dot.target == null or not is_instance_valid(dot.target):
			active_dots.remove_at(i)
			continue

		dot.time_since_last_tick += delta

		if dot.time_since_last_tick >= dot.tick_interval:
			# Apply one tick of damage.
			dot.time_since_last_tick -= dot.tick_interval
			apply_damage(dot.target, dot.damage_per_tick)
			dot.ticks_remaining -= 1

		# Remove expired DoTs.
		if dot.ticks_remaining <= 0:
			active_dots.remove_at(i)
		else:
			i += 1

# ---------------------------------------------------------------------------
# Internal — Action execution
# ---------------------------------------------------------------------------

## Drain the action queue FIFO. Each action is executed with an await on its
## tween before the next action begins, ensuring serialised execution.
func _drain_action_queue() -> void:
	if _processing_action:
		return
	if action_queue.is_empty():
		return

	_processing_action = true

	while not action_queue.is_empty():
		var entry: Dictionary = action_queue.pop_front()
		_current_action_unit = entry.unit as Node

		# Skip if the unit is no longer valid.
		if entry.unit == null or not is_instance_valid(entry.unit):
			_current_action_unit = null
			continue

		# Execute the action and capture the tween (if any) for awaiting.
		var tween: Tween = _execute_action(
			entry.unit,
			entry.action,
			entry.target,
			entry.params
		)

		# Await the tween's completion before processing the next action.
		if tween != null and is_instance_valid(tween):
			await tween.finished

		# After the action completes, if the unit is an enemy, trigger its AI
		# to re-evaluate (reset its decision timer).
		if entry.unit != null and is_instance_valid(entry.unit):
			if entry.unit.has_method("reset_ai_timer"):
				entry.unit.reset_ai_timer()

	_current_action_unit = null
	_processing_action = false


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
	if GridManager.is_occupied(to_pos) and to_pos != from_pos:
		return null

	# Free origin, reserve destination.
	GridManager.free_tile(from_pos)
	if not GridManager.reserve_tile(to_pos, unit):
		# Re-reserve origin if reservation fails.
		GridManager.reserve_tile(from_pos, unit)
		return null

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


## Execute a basic attack. Applies damage and plays a damage flash effect.
## Returns a tween for the flash effect, or null.
func _execute_basic_attack(unit: Node, target: Node) -> Tween:
	if target == null or not is_instance_valid(target):
		return null

	# Determine damage from the attacker's character_data.
	var damage: int = 10  # default fallback
	if "character_data" in unit and unit.character_data != null:
		damage = unit.character_data.attack_damage

	apply_damage(target, damage)

	# Damage flash — modulate the target's Polygon2D white, then back.
	return _damage_flash(target)


## Execute a skill action. Looks up the skill by skill_index in the unit's
## skills array. Applies damage, AoE, knockback, DoT, and/or heal as defined
## by the SkillData resource. Starts the cooldown for the skill.
## Returns a tween for effects, or null.
func _execute_skill(unit: Node, target: Node, params: Dictionary) -> Tween:
	if target == null or not is_instance_valid(target):
		return null

	var skill_index: int = params.get("skill_index", -1)
	if skill_index < 0:
		return null

	# Get the skill data from the unit's skills array.
	var skills_arr = unit.skills if "skills" in unit else null
	if skills_arr == null or skill_index >= skills_arr.size():
		return null

	var skill = skills_arr[skill_index]
	if skill == null:
		return null

	# --- Primary target damage ---
	if skill.damage > 0:
		apply_damage(target, skill.damage)

	# --- AoE damage ---
	if skill.aoe_shape != "single" and skill.aoe_size > 0:
		var origin: Vector2i = Vector2i.ZERO
		if "grid_pos" in unit:
			origin = unit.grid_pos

		# Determine direction for line AoE.
		var direction: Vector2i = Vector2i.ZERO
		if skill.aoe_shape == "line":
			direction = params.get("direction", Vector2i.ZERO)
			if direction == Vector2i.ZERO:
				# Auto-detect direction toward target.
				if "grid_pos" in target:
					var t_pos: Vector2i = target.grid_pos
					if t_pos.x > origin.x:
						direction = Vector2i(1, 0)
					elif t_pos.x < origin.x:
						direction = Vector2i(-1, 0)
					elif t_pos.y > origin.y:
						direction = Vector2i(0, 1)
					elif t_pos.y < origin.y:
						direction = Vector2i(0, -1)

		var aoe_targets: Array[Node] = GridManager.get_units_in_aoe(
			origin, skill.aoe_shape, skill.aoe_size, direction
		)

		# Apply AoE damage to all targets except the primary (already hit).
		for aoe_target in aoe_targets:
			if aoe_target != target:
				apply_damage(aoe_target, skill.damage)

	# --- Knockback ---
	if skill.knockback > 0 and "grid_pos" in target:
		# Calculate knockback direction away from the attacker.
		var unit_pos: Vector2i = unit.grid_pos if "grid_pos" in unit else Vector2i.ZERO
		var target_pos: Vector2i = target.grid_pos
		var kb_dir: Vector2i = Vector2i(
			sign(target_pos.x - unit_pos.x),
			sign(target_pos.y - unit_pos.y)
		)
		# Prefer cardinal direction (pick axis with larger delta).
		if abs(target_pos.x - unit_pos.x) >= abs(target_pos.y - unit_pos.y):
			kb_dir.y = 0
		else:
			kb_dir.x = 0

		apply_knockback(target, kb_dir, skill.knockback)

	# --- DoT ---
	if skill.dot_damage > 0 and skill.dot_duration > 0:
		apply_dot(target, skill.dot_damage, skill.dot_duration)

	# --- Heal ---
	if skill.heal_amount > 0:
		apply_heal(target, skill.heal_amount)
		# Also heal the caster if the skill has self-heal flag.
		var heal_self: bool = params.get("heal_self", false)
		if heal_self and unit != target:
			apply_heal(unit, skill.heal_amount)

	# --- Start cooldown ---
	if "skill_cooldowns" in unit and skill_index < unit.skill_cooldowns.size():
		unit.skill_cooldowns[skill_index] = skill.cooldown

	# Damage flash on primary target.
	return _damage_flash(target)

# ---------------------------------------------------------------------------
# Internal — Helpers
# ---------------------------------------------------------------------------

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
## Modulates Polygon2D children white for 0.1s, then back to normal.
## Returns the tween so the caller can await it.
func _damage_flash(target: Node) -> Tween:
	if target == null or not is_instance_valid(target):
		return null
	if not target is Node2D:
		return null

	# Find a Polygon2D child (or use the target itself if it's a Polygon2D).
	var poly: Node2D = null
	if target is Polygon2D:
		poly = target
	else:
		poly = target.get_node_or_null("Sprite") as Polygon2D
		if poly == null:
			poly = target.get_child(0) as Polygon2D

	if poly == null:
		return null

	var original_modulate: Color = poly.modulate
	poly.modulate = Color.WHITE

	var flash_tween: Tween = create_tween()
	flash_tween.bind_node(target)
	flash_tween.tween_callback(func():
		if is_instance_valid(poly):
			poly.modulate = original_modulate
	).set_delay(0.1)

	return flash_tween
