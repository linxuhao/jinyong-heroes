## Player — Yang Guo character controller (turn-based)
##
## Turn-based controller: per-turn budgets (moves_left / moved / acted),
## round-valued int cooldowns, skill selection via hotkeys 1-12 (two-phase
## unlock is tutorial-only: palm arts 5-8 need round >= 4; Seventeen Forms
## additionally needs HP below 50%), J to execute the selected skill at the
## nearest valid target
## (else an adjacent basic attack), Space to end the turn, Escape to pause,
## and left-click enemy targeting. Actions go through
## CombatManager.execute_action() — the RTWP action queue is removed.
## Lives in battlefield as a child of the Battlefield scene.
extends Node2D

const CharacterData = preload("res://scripts/data/character_data.gd")
const SkillData = preload("res://scripts/data/skill_data.gd")

## Input action for confirming / executing an attack (physical key J, keycode
## 74). This is the INPUT action; the engine action string used by
## CombatManager.execute_action is a separate namespace and stays unchanged.
const ATTACK_ACTION: StringName = &"attack_confirm"

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when health changes. HUD HealthBar listens to this.
signal health_changed(new_health: int, max_health: int)

## Emitted when cooldowns change (engine turn-start decrement, or after a
## skill is used). HUD skill buttons listen to this. Cooldowns are int ROUNDS.
signal cooldowns_updated(cooldowns: Array)

## Emitted whenever a skill selection / attack attempt is rejected, with the
## specific Chinese reason (or "" to clear the hint line: selection success,
## toggle-off, or a successful action). HUD ActionHintLabel listens to this.
signal action_hint(text: String)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Current grid position (tile coordinate).
var grid_pos: Vector2i = Vector2i(-1, -1)

## Current health points.
var health: int = 100

## Maximum health points.
var max_health: int = 100

## The CharacterData resource set by battlefield during setup.
var character_data = null

## Array of SkillData resources (from character_data).
var skills: Array = []

## Per-skill remaining cooldown in ROUNDS (parallel to skills array).
## Ints, initialised to 0 (ready) by setup(). Decremented by the turn engine
## (CombatManager.begin_turn) at the unit's own turn start — never per frame.
var skill_cooldowns: Array[int] = []

## Movement budget remaining this turn (tiles). Reset to move_range (minus
## next-turn restrictions) by the engine at the start of every turn.
var moves_left: int = 0

## True once the unit has moved this turn.
var moved: bool = false

## True once the unit has performed an action this turn. READ by the
## action-budget gates (_try_attack_target / _try_keyboard_attack) and the
## engine guard (engine_acted_guard task); WRITTEN only by the engine
## (CombatManager) on successful execution.
var acted: bool = false

## Number of turns this unit has taken since the battle began.
var turns_taken: int = 0

## Shield pool (absorbed before HP). Managed by CombatManager status ticks.
var shield: int = 0

## Per-unit status table (poison / shield / next-turn restrictions / ...).
## Entries: { id, kind, rounds, params }. Written by CombatManager.
var statuses: Array[Dictionary] = []

## Observable status ids, kept in sync with statuses (surface contract).
var status_names: Array[String] = []

## 内力 energy pool (display only — no technique costs this run).
var energy: int = 0

## 身法 initiative value; drives turn order (88 for Yang Guo).
var initiative: int = 0

## Team id: 0 = player, 1 = Five Greats.
var team: int = 0

## Primary internal art's passive id (engine hooks: shen_diao_power, ...).
var passive_id: String = ""

## Trait ids carried into battle from the profile (playtest surface + trait
## engine hooks: sha_po_lang / iron_shirt / swallow_lightness / ambidextrous).
## Populated by battlefield.gd from character_data.traits (encounter battles;
## empty in the tutorial).
var traits: Array[String] = []

## True while a movement tween is playing. Blocks new input during animation.
var is_moving: bool = false

## Index of the currently selected skill, or -1 for basic attack.
var selected_skill_index: int = -1

## World-px top edge of the sprite texture rect, updated every frame by
## _refresh_sprite_clamp(). Exposed for playtest surface assertions.
var sprite_top: float = 0.0

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _sprite: Sprite2D = $Sprite

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Movement animation duration in seconds (matches GridManager's tween).
const MOVE_DURATION: float = 0.15

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise the player with a CharacterData resource.
## Called by battlefield.gd after instantiating this scene.
func setup(data) -> void:
	character_data = data

	# Health.
	max_health = data.max_health
	health = max_health

	# Skills (cooldowns as int ROUNDS, initialised ready).
	skills = data.skills.duplicate()
	skill_cooldowns = []
	for _i in skills.size():
		skill_cooldowns.append(0)

	# Turn-based state from the CharacterData record.
	moves_left = data.move_range
	energy = data.energy
	initiative = data.initiative
	team = 0

	# Grid position from current world position (set by battlefield after
	# positioning the node).
	grid_pos = GridManager.world_to_grid(position)

	# Visual appearance (defensive: _sprite is null before add_child, so the
	# authoritative application happens in _ready() via _apply_sprite_visuals()).
	if _sprite != null and _sprite.texture != null:
		_sprite.modulate = Color.WHITE
		_sprite.offset = Vector2(0, -(_sprite.texture.get_height() / 2.0))
	# Deselect any skill.
	selected_skill_index = -1


## Select (or toggle off) a skill by its index. Rejects (silent no-op, no SFX,
## no selection change) indices that are out of bounds, phase-locked (palm
## arts before round 4), on cooldown, HP-gated (Seventeen Forms at >= 50% HP),
## technique-sealed (no_techniques_next_turn), or tutorial-blocked.
## Called by HUD buttons (GameManager.get_player()) and hotkeys 1-12.
func select_skill(index: int) -> void:
	var reject_reason: String = _skill_reject_reason(index)
	if reject_reason != "":
		# Rejected — surface the specific reason instead of a silent no-op.
		action_hint.emit(reject_reason)
		return

	if index == selected_skill_index:
		# Toggle off — clear the hint line.
		selected_skill_index = -1
		action_hint.emit("")
	else:
		selected_skill_index = index
		# Guide the player to the confirm key / target click.
		action_hint.emit("按 J 出招 / 点击目标")

	# Play the select SFX (single hook shared by HUD buttons and hotkeys).
	# Regression gate (fix_cascade_script_loads): AudioManager autoload parses,
	# so this call site resolves at compile time.
	AudioManager.play_select()


## Gate check for selecting (and executing) a skill at `index`. Silent no-op
## rules: out of bounds; palm arts (index >= 4) phase-locked until
## CombatManager.current_round >= 4; on cooldown (> 0 rounds); Seventeen Forms
## HP gate (usable only BELOW 50% max HP — 250 of 500); technique seal
## (no_techniques_next_turn); tutorial input allowance.
## Returns the FIRST failing rejection reason for selecting (and executing) a
## skill at `index`, or "" when the skill is selectable. Mirrors the EXACT gate
## order and conditions of the former _skill_selectable() body so the hint line
## always names the real blocker: out of bounds; palm arts (index >= 4)
## phase-locked until CombatManager.current_round >= 4; on cooldown (> 0
## rounds, with the REMAINING rounds formatted at reject time); Seventeen Forms
## HP gate (usable only BELOW 50% max HP — 250 of 500); technique seal
## (no_techniques_next_turn); tutorial input allowance. The six Chinese
## literals are grep-able acceptance points.
func _skill_reject_reason(index: int) -> String:
	if index < 0 or index >= skills.size():
		return "该招式不存在"
	if CombatManager.tutorial_battle and index >= 4 and CombatManager.current_round < 4:
		return "教程尚未解锁"  # Two-phase unlock (tutorial-only): palm arts appear at round 4+.
	if skill_cooldowns[index] > 0:
		return "冷却中 %d 回合" % skill_cooldowns[index]
	var skill = skills[index]
	if skill != null and skill.hp_gate_below_ratio > 0.0:
		var gate_hp: int = int(round(float(max_health) * skill.hp_gate_below_ratio))
		if health >= gate_hp:
			return "须在半血以下"  # "Below 50% HP": exactly 50% (250) is NOT usable.
	if _has_restriction_status("no_techniques_next_turn"):
		return "本回合无法用招"
	if not TutorialManager.is_input_allowed("skill_%d" % (index + 1)):
		return "教程尚未解锁"
	return ""


## Gate check for selecting (and executing) a skill at `index`. Thin wrapper
## over _skill_reject_reason(): selectable iff no rejection reason applies.
## Both existing call sites (select_skill / _try_attack_target) keep the exact
## same gate order and conditions.
func _skill_selectable(index: int) -> bool:
	return _skill_reject_reason(index) == ""


## True while a "next turn" restriction status is active on the player.
func _has_restriction_status(status_id: String) -> bool:
	for st in statuses:
		if st.get("id", "") == status_id and st.get("rounds", 0) >= 1:
			return true
	return false


## Returns whether the player is currently animating a movement tween.
func get_is_moving() -> bool:
	return is_moving


## True for the player unit (engine death handling uses this to distinguish
## the player from enemies).
func is_player() -> bool:
	return true


## Turn-start hook. Intentionally EMPTY: the turn engine calls
## CombatManager.begin_turn(unit), which owns the full turn-start lifecycle
## (budget reset incl. next-turn restrictions, round-based int cooldown
## decrement + cooldowns_updated emit, DoT/status ticks, constant regen).
## This hook must NEVER replicate that logic — double-decrementing cooldowns
## or re-resetting budgets would desync the engine.
func begin_turn() -> void:
	pass


## Clear the one-turn restriction statuses at the end of this turn
## (dragging mire / jade flute acupoint / acupoint lock). Called by
## CombatManager.end_current_turn().
func clear_this_turn_restrictions() -> void:
	_remove_status("move_minus_next_turn")
	_remove_status("no_techniques_next_turn")
	_remove_status("no_move_next_turn")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Apply the generated-art sprite visuals (modulate + feet anchor).
	_apply_sprite_visuals()

	# Snap to grid position if not already set.
	if grid_pos == Vector2i(-1, -1):
		grid_pos = GridManager.world_to_grid(position)
	position = GridManager.grid_to_world(grid_pos)


func _process(_delta: float) -> void:
	# Clamp the sprite into the artwork rect every frame (before the state gate
	# so sprite_top is updated during TUTORIAL too).
	# NOTE: cooldowns are int ROUNDS, decremented only by the turn engine at
	# the unit's own turn start — no per-frame ticking here.
	_refresh_sprite_clamp()


func _unhandled_input(event: InputEvent) -> void:
	# Unified input gate: battle active, the player's turn is live, not paused,
	# not mid-animation. Per-action tutorial allowance is checked in the
	# individual handlers (_try_move / select_skill / _try_attack_target).
	var state: String = GameManager.get_state()
	if state != "BATTLE":
		return
	if not CombatManager.is_player_turn():
		return
	if CombatManager.get_is_paused():
		return
	if is_moving:
		return

	# --- Movement (WASD / Arrow keys) ---
	if event.is_action_pressed("move_up"):
		_try_move(Vector2i(0, -1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_try_move(Vector2i(0, 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_try_move(Vector2i(-1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_try_move(Vector2i(1, 0))
		get_viewport().set_input_as_handled()

	# --- Skill selection (hotkeys 1-12; two-phase unlock inside select_skill) ---
	elif event.is_action_pressed("skill_1"):
		select_skill(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_2"):
		select_skill(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_3"):
		select_skill(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_4"):
		select_skill(3)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_5"):
		select_skill(4)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_6"):
		select_skill(5)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_7"):
		select_skill(6)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_8"):
		select_skill(7)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_9"):
		select_skill(8)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_10"):
		select_skill(9)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_11"):
		select_skill(10)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_12"):
		select_skill(11)
		get_viewport().set_input_as_handled()

	# --- Keyboard basic attack / skill execution (J) ---
	# Fires the selected skill (or basic attack) at the nearest valid target.
	elif event.is_action_pressed(ATTACK_ACTION):
		_try_keyboard_attack()
		get_viewport().set_input_as_handled()

	# --- End turn (Space) ---
	elif event.is_action_pressed("end_turn"):
		CombatManager.end_current_turn()
		get_viewport().set_input_as_handled()

	# --- Pause toggle (Escape) ---
	elif event.is_action_pressed("pause_game"):
		if TutorialManager.is_input_allowed("pause"):
			CombatManager.toggle_pause()
			get_viewport().set_input_as_handled()

	# --- Left-click on enemy grid position ---
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_handle_click_targeting(event)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## Attempt to move one tile in the given cardinal direction.
func _try_move(direction: Vector2i) -> void:
	# Input gating — tutorial must allow movement.
	if not TutorialManager.is_input_allowed("move"):
		return

	# Turn budget: one tile per point; blocked at zero.
	if moves_left <= 0:
		return

	var target: Vector2i = grid_pos + direction

	# Validate walkability (in-bounds and not a border wall tile).
	if not GridManager.is_walkable(target):
		return

	# 身轻如燕 (swallow_lightness): an occupied target tile can be SLID THROUGH
	# when the trait is owned and the movement budget allows — consume 2 movement
	# and land on the walkable, unoccupied tile beyond (never on the enemy tile).
	# GridManager occupancy is updated only for the departure and landing tiles;
	# the enemy tile's occupancy is untouched.
	if GridManager.is_occupied(target) and traits.has("swallow_lightness") \
			and moves_left >= 2:
		var beyond: Vector2i = target + direction
		if GridManager.is_walkable(beyond) and not GridManager.is_occupied(beyond):
			moves_left -= 2
			moved = true
			is_moving = true
			GridManager.move_unit(self, grid_pos, beyond)
			grid_pos = beyond
			var slide_tween: Tween = create_tween()
			slide_tween.tween_callback(_on_move_completed).set_delay(MOVE_DURATION)
			return

	# Validate occupancy.
	if GridManager.is_occupied(target):
		return

	# Consume one movement point and mark this turn as moved.
	moves_left -= 1
	moved = true

	# Initiate movement via GridManager (handles occupancy + tween).
	is_moving = true
	GridManager.move_unit(self, grid_pos, target)
	grid_pos = target

	# Schedule is_moving reset after the animation completes.
	var reset_tween: Tween = create_tween()
	reset_tween.tween_callback(_on_move_completed).set_delay(MOVE_DURATION)


## Called when the movement animation finishes.
func _on_move_completed() -> void:
	if not is_instance_valid(self):
		return
	is_moving = false
	# Snap position to exact grid centre (prevents floating-point drift).
	position = GridManager.grid_to_world(grid_pos)


# ---------------------------------------------------------------------------
# Skill selection (gates live in select_skill() / _skill_selectable())
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Targeting (left-click)
# ---------------------------------------------------------------------------

## Handle a left mouse click: convert the click event's own viewport coordinates
## to battlefield world space and delegate to the shared handle_world_click.
func _handle_click_targeting(event: InputEventMouseButton) -> void:
	# Use the click event's own viewport coordinates, converted to battlefield
	# world space, instead of the viewport-cached pointer position. The canvas
	# transform is identity today (no Camera2D offset in the battlefield; the
	# main camera is centered with zero offset), so event.position already equals
	# world coordinates; the affine inverse keeps the path correct if a camera
	# ever moves or zooms.
	handle_world_click(get_canvas_transform().affine_inverse() * event.position)


## Shared world-click entry point (PUBLIC — called by the mouse path above and by
## the enemy hit-surface relay in enemy.gd, which bypasses _unhandled_input).
## Carries the same 4-condition gate as _unhandled_input so the relay path is as
## safe as the keyboard/mouse path: battle active, player turn live, not paused,
## not mid-animation. Then: world → grid → living-enemy match → _try_attack_target;
## only the first matched enemy is acted on. A click during ENEMY_TURN / pause /
## mid-move is a silent no-op, identical to the keyboard path.
func handle_world_click(world_pos: Vector2) -> void:
	var state: String = GameManager.get_state()
	if state != "BATTLE":
		return
	if not CombatManager.is_player_turn():
		return
	if CombatManager.get_is_paused():
		return
	if is_moving:
		return

	var click_grid: Vector2i = GridManager.world_to_grid(world_pos)

	# Iterate living enemies to see if one occupies the clicked tile.
	var enemies: Array[Node] = GameManager.get_enemies_alive()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		if enemy.grid_pos != click_grid:
			continue

		# Found an enemy at the clicked grid position — delegate to the shared
		# targeting routine (skill vs basic attack, gates, range, auto-deselect).
		_try_attack_target(enemy)

		# Only act on the first matched enemy.
		break


## Execute an attack (or selected skill) against the given target enemy.
## Shared by the left-click path and the keyboard basic_attack path so both
## inputs run through identical gates: tutorial permission, cooldown, HP gate,
## range/shape hit test, then CombatManager.execute_action(), then skill
## auto-deselect. Any failure is a silent no-op (no cooldown, no acted — the
## engine sets cooldown/acted only on successful execution).
func _try_attack_target(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return  # Precondition guard — not a user-facing rejection.

	if acted:
		action_hint.emit("本回合已行动")
		return

	if selected_skill_index >= 0:
		# Using a skill — re-validate all gates at execution time (HP gate
		# re-check included; the engine re-checks again as belt-and-braces).
		var skill_index: int = selected_skill_index
		var reject_reason: String = _skill_reject_reason(skill_index)
		if reject_reason != "":
			action_hint.emit(reject_reason)
			return
		var skill = skills[skill_index]
		if not can_skill_hit(skill, enemy):
			# No valid target for this skill's shape/range — surface the reason.
			action_hint.emit("射程不够")
			return

		_execute_skill(skill_index, enemy)
		selected_skill_index = -1  # Auto-deselect after use.
		action_hint.emit("")  # Clear the hint line after a successful skill use.

	else:
		# Basic attack.
		if not TutorialManager.is_input_allowed(ATTACK_ACTION):
			action_hint.emit("教程尚未解锁")
			return

		# Must be adjacent (Chebyshev distance <= 1).
		if not _is_adjacent(enemy.grid_pos):
			# Out of range — surface the reason.
			action_hint.emit("射程不够")
			return

		_execute_basic_attack(enemy)
		action_hint.emit("")  # Clear the hint line after a successful basic attack.


## Keyboard basic attack / skill execution: fire the selected skill (or a basic
## attack when no skill is selected) at the nearest valid target. Silent
## no-op when no enemy satisfies the skill's shape/range (mirrors the click
## path's out-of-range ignore).
func _try_keyboard_attack() -> void:
	if acted:
		action_hint.emit("本回合已行动")
		return

	var target: Node = null
	if selected_skill_index >= 0:
		var skill = skills[selected_skill_index]
		target = _pick_nearest_enemy_for_skill(skill)
	else:
		# Basic attack: nearest adjacent enemy.
		target = _pick_nearest_enemy_in_range(1)
	if target != null:
		_try_attack_target(target)
	else:
		# No enemy satisfies the skill's shape/range (or none is adjacent for a
		# basic attack) — surface the reason instead of a silent dead branch.
		action_hint.emit("射程不够")


## Find the nearest living enemy within the given Chebyshev range of the
## player's grid position, using GameManager.get_enemies_alive() registration
## order (East Heretic, West Poison, South Emperor, North Beggar, Central
## Divine). Strictly-nearest wins; ties keep the first in iteration order, so
## the result is fully deterministic. No facing state. Returns null if none.
func _pick_nearest_enemy_in_range(range_val: int) -> Node:
	var enemies: Array[Node] = GameManager.get_enemies_alive()
	var best: Node = null
	var best_dist: int = 999999
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		var enemy_pos: Vector2i = enemy.grid_pos
		var dist: int = max(abs(grid_pos.x - enemy_pos.x), abs(grid_pos.y - enemy_pos.y))
		if dist > range_val:
			continue
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


## Find the nearest living enemy that the given skill can hit (shape/range
## aware). Returns null when none. Deterministic: registration-order tie-break.
func _pick_nearest_enemy_for_skill(skill) -> Node:
	var enemies: Array[Node] = GameManager.get_enemies_alive()
	var best: Node = null
	var best_dist: int = 999999
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		if not can_skill_hit(skill, enemy):
			continue
		var enemy_pos: Vector2i = enemy.grid_pos
		var dist: int = max(abs(grid_pos.x - enemy_pos.x), abs(grid_pos.y - enemy_pos.y))
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


## True when the skill can hit the given enemy from the player's current tile
## (Chebyshev-based shape/range hit test). The engine performs the actual AoE
## resolution and jump-landing validation at execution; this only decides
## whether a target is selectable.
func can_skill_hit(skill, enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not ("grid_pos" in enemy):
		return false
	var enemy_pos: Vector2i = enemy.grid_pos
	var dist: int = max(abs(grid_pos.x - enemy_pos.x), abs(grid_pos.y - enemy_pos.y))

	if skill.aoe_shape == "global":
		return true
	if skill.jump_tiles > 0:
		# Jump techniques: the landing tile (up to jump_tiles along the path to
		# the nearest enemy) becomes the AoE origin; reachability is validated
		# by the engine at execution. Gate: nearest enemy within skill.range.
		return dist <= skill.range
	if skill.aoe_origin == "target" or skill.aoe_shape == "single":
		# Target-origin AoEs place their center on the target tile: the target
		# itself must be within range.
		return dist <= skill.range
	if skill.aoe_shape == "line":
		# Line AoEs require the target in the same row or column within range.
		return (grid_pos.x == enemy_pos.x or grid_pos.y == enemy_pos.y) \
			and dist <= skill.range
	if skill.aoe_shape == "adjacent":
		# Self-origin ring (Seventeen Melancholy Forms).
		return dist == 1
	if skill.aoe_shape == "cross" or skill.aoe_shape == "square":
		# Self-origin area: the shape's radius (arm length for cross) covers it.
		return dist <= max(skill.aoe_size, 1)
	return dist <= skill.range


# ---------------------------------------------------------------------------
# Action execution
# ---------------------------------------------------------------------------

## Execute a basic attack against the given target enemy via the combat
## engine. Fire-and-forget: execute_action is a coroutine (awaits tweens
## internally) and may be called without awaiting; the engine applies damage
## and sets acted on successful execution.
func _execute_basic_attack(target: Node) -> void:
	CombatManager.execute_action(self, "basic_attack", target, {})


## Execute a skill against the given target enemy via the combat engine.
## Cooldown and acted are set by the engine ONLY on successful execution.
func _execute_skill(skill_index: int, target: Node) -> void:
	if skill_index < 0 or skill_index >= skills.size():
		return
	if skill_cooldowns[skill_index] > 0:
		return  # Cooldown not ready — shouldn't reach here but guard anyway.

	CombatManager.execute_action(self, "skill", target, {
		"skill_index": skill_index,
	})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns true if the given grid position is adjacent (Chebyshev distance ≤ 1).
func _is_adjacent(pos: Vector2i) -> bool:
	return abs(grid_pos.x - pos.x) <= 1 and abs(grid_pos.y - pos.y) <= 1


## Returns true if the given enemy is within the specified range (Chebyshev).
func _is_in_range(enemy: Node, range_val: int) -> bool:
	if not ("grid_pos" in enemy):
		return false
	var enemy_pos: Vector2i = enemy.grid_pos
	return abs(grid_pos.x - enemy_pos.x) <= range_val \
		and abs(grid_pos.y - enemy_pos.y) <= range_val


## Remove every status entry with the given id and sync status_names.
func _remove_status(status_id: String) -> void:
	var i: int = 0
	while i < statuses.size():
		if statuses[i].get("id", "") == status_id:
			statuses.remove_at(i)
		else:
			i += 1
	_sync_status_names()


## Rebuild status_names from the statuses table (surface observability).
func _sync_status_names() -> void:
	status_names = []
	for st in statuses:
		status_names.append(str(st.get("id", "")))


## Apply presentation-only sprite visuals (modulate + feet anchor).
## Called from _ready() where _sprite (@onready) is live and the .tscn texture
## is loaded; guarded so it is safe to call from setup() too.
func _apply_sprite_visuals() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	_sprite.modulate = Color.WHITE
	_sprite.offset = Vector2(0, -(_sprite.texture.get_height() / 2.0))


## Clamp the sprite's offset so the whole texture rect stays inside the board
## artwork rect, and publish sprite_top for playtest assertions. Idempotent:
## only writes _sprite.offset when the clamp changes it. Called every frame at
## the top of _process() (before state gates), so top-row enemies are clamped
## during TUTORIAL too. The clamp is authoritative per frame — it refines any
## feet anchor set by _apply_sprite_visuals().
func _refresh_sprite_clamp() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var tex_size: Vector2 = _sprite.texture.get_size()
	var desired: Vector2 = GridManager.clamp_sprite_offset(position, tex_size)
	if _sprite.offset != desired:
		_sprite.offset = desired
	sprite_top = position.y + desired.y - tex_size.y / 2.0
