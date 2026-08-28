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
const VisibilityProbe = preload("res://scripts/ui/visibility_probe.gd")

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

## Turn-start grid position — the right-click undo restore target. Written by
## the engine (CombatManager.begin_turn) at every turn start, like acted.
var turn_start_grid: Vector2i = Vector2i(-1, -1)

## Movement budget remaining at turn start (AFTER next-turn restrictions) —
## what right-click undo restores moves_left to.
var turn_start_moves_left: int = 0

## Whether the unit had moved at turn start (always false in practice; part of
## the same snapshot so undo restores the exact turn-start state).
var turn_start_moved: bool = false

## True when the turn's movement can still be undone (recomputed EVERY frame in
## _process — never event-written, so it can never go stale). False once the
## move is committed: a successful action (engine sets acted) or turn end.
var undo_available: bool = false

## Queued cardinal directions for a click-move path (one entry per _try_move
## call), drained by _on_move_completed.
var _pending_move_steps: Array[Vector2i] = []

## Number of turns this unit has taken since the battle began.
var turns_taken: int = 0

## Shield pool (absorbed before HP). Managed by CombatManager status ticks.
var shield: int = 0

## Per-unit status table (poison / shield / next-turn restrictions / ...).
## Entries: { id, kind, rounds, params }. Written by CombatManager.
var statuses: Array[Dictionary] = []

## Observable status ids, kept in sync with statuses (surface contract).
var status_names: Array[String] = []

## 内力 energy pool — the live inner-force pool this battle. Decreased by the
## combat engine on every successful skill cast (CombatManager spends the
## skill's cost via SkillData.spend). Does not regenerate within a battle
## (recorded gap — regen mechanics belong to a later round).
var energy: int = 0

## 内力池上限: the pool size this battle started with. Written once in setup()
## from data.energy (tutorial 180); the pool only decreases in battle, so the
## once-written cap stays valid. Playtest surface for cap-relative qi asserts
## (energy < energy_max), mirroring the max_health discipline.
var energy_max: int = 0

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

## Live clamped portrait ink rect in world px (world == screen under the
## identity canvas transform). Top-left == drawn texture top-left, size ==
## texture size. Recomputed every frame from the LIVE clamped sprite offset
## (clamp_sprite_offset refines _sprite.offset each frame) — never from grid
## or the naive feet - 128 assumption. Consumed by the Defect-B portrait-rect
## hit resolver and the playtest surface. Sentinel Rect2() when no texture.
var portrait_ink_rect: Rect2 = Rect2()

## On-frame portrait visibility (all 6 layers pass). Computed each frame.
var portrait_visible: bool = false
## First failing visibility layer id, "" when fully visible on-frame.
var portrait_fail_layer: String = ""

## Worst single later-drawn opaque-host cover fraction of the ink rect
## ([0, 1]) — the `covered` layer's measured input. Playtest surface probe.
var portrait_covered_frac: float = 0.0
## The Sprite child's global_position (canvas space) — 3-number probe #1.
var portrait_sprite_pos: Vector2 = Vector2.ZERO
## The Sprite texture size in px — 3-number probe #2.
var portrait_tex_size: Vector2 = Vector2.ZERO
## The unit's own floating HealthBar global_position; (-1,-1) when no bar
## resolves (before HUD.setup() or after battle exit) — 3-number probe #3.
var portrait_bar_pos: Vector2 = Vector2(-1, -1)
## Forwarded anchor of this unit's floating nameplate: the HealthBar's
## health_bar_world_y / health_bar_screen_y this frame. Relayed in _process so
## the six unit surface blocks can assert the camera nail pin without a second
## rect computation.
var health_bar_screen_y: float = 0.0
var health_bar_world_y: float = 0.0

## Portrait-stands-on-its-own-tile alignment (playtest surface observable,
## recomputed every frame STRICTLY from the published portrait_ink_rect above —
## never a second rect computation):
##   ink_world_dx = ink horizontal centre - unit world x
##   ink_world_dy = ink bottom edge        - unit world y
## Both 0.0 means the drawn ink is centred on the tile the unit occupies (its
## ink bottom == its own feet). A non-zero dy is the portrait drifting off its
## tile — exactly what clamp_sprite_offset does to top-row units while the
## clamp is live (measured dy 124 at row 1, 60 at row 2). Pinned by
## playtest/portrait_grid_alignment.yaml.
var ink_world_dx: float = 0.0
var ink_world_dy: float = 0.0

# ---------------------------------------------------------------------------
# Click-path diagnostics (playtest observables — measurement only, never gates)
# ---------------------------------------------------------------------------

## Count of every left-button press event observed by this node's `_input`
## (counting only; never marks the event handled). Tells the playtest whether
## the synthesized `clicks:` event reaches the tree at all.
var debug_input_events: int = 0

## The raw viewport position of the last observed left-button press.
var debug_last_raw_event_pos: Vector2 = Vector2.ZERO

## Count of entries into handle_world_click (the single convergence point of
## _unhandled_input, the enemy _input relay, and the enemy gui_input relay).
## Incremented BEFORE the gate so a gated-out click still counts.
var debug_click_events: int = 0

## The world→grid tile resolved for the last handle_world_click call.
var debug_last_click_grid: Vector2i = Vector2i(-1, -1)

## Count of every RIGHT-button press event observed by this node's `_input`
## (counting only; never marks the event handled). This is a NEW counter, not a
## widening of debug_input_events — the undo path previously had no raw counter
## at all, so a right-click swallowed in the GUI phase was invisible to the
## contract (the Defect A signature: raw>0 but never reaching _unhandled_input).
var debug_right_input_events: int = 0

## Count of entries into handle_world_right_click (the shared undo entry point).
## Incremented at the very top, BEFORE the state gate, mirroring how
## debug_click_events increments before the gate at the top of handle_world_click
## — so a gated-out right-click still counts as having reached the handler.
var debug_undo_events: int = 0

## Predicted GUI-phase event eater: at every press (left / right / touch) seen in
## _input, the InputCensus.top_eater result for that point — the topmost visible,
## non-IGNORE Control whose global rect contains it ("" when none). It is the
## *prediction* of what would swallow the event if it survived to the GUI phase;
## it is recomputed on EVERY press (never on release or motion) so a stale
## non-empty value can never mask a fixed STOP-filter hole.
var debug_gui_eater: String = ""

## The §3.B2 portrait-rect resolution step (1..5) of the last handle_world_click
## that passed the battle gate; 0 when no click has resolved yet. Written ONLY
## AFTER the gate passes, so a gated-out click leaves the previous value
## untouched (debug_click_events still increments before the gate — the
## click_move_to_tile.yaml f45 differential pin stays intact).
var debug_click_rule_step: int = 0

## The target enemy's name when the last resolved click hit step 1/2/4 (an
## attack); "" for the move / no-op steps 3/5. Measurement only, never gates.
var debug_click_rule_target: String = ""

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _sprite: Sprite2D = $Sprite

## The HUD-side HealthBar that follows this unit, resolved by duck-typing
## (a Control with follow_character() whose _char_node == self) because bar
## node names are composition-varying. Cached; re-resolved only when null or
## invalid (bars are freed on battle exit).
var _portrait_bar: Node = null

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
	energy_max = data.energy
	initiative = data.initiative
	team = 0

	# Grid position from current world position (set by battlefield after
	# positioning the node).
	grid_pos = GridManager.world_to_grid(position)

	# Turn-start snapshot initialisation (the engine re-writes these fields at
	# every CombatManager.begin_turn; this only makes them sane pre-battle).
	turn_start_grid = grid_pos
	turn_start_moves_left = moves_left
	turn_start_moved = false

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
		return tr("冷却中 %d 回合") % skill_cooldowns[index]
	var skill = skills[index]
	if skill != null and skill.hp_gate_below_ratio > 0.0:
		var gate_hp: int = int(round(float(max_health) * skill.hp_gate_below_ratio))
		if health >= gate_hp:
			return "须在半血以下"  # "Below 50% HP": exactly 50% (250) is NOT usable.
	# jinyong-spend-qi: insufficient inner force. Selecting a skill whose cost
	# exceeds the current pool is refused with the visible reason; the HUD
	# already renders the same fact (no_energy state + 内力不足 tag) and the
	# engine hard-gates the cast (CombatManager._execute_skill). Mirrors the
	# HUD priority so an insufficient-qi skill on cooldown still reports 冷却中.
	if skill != null and SkillData.insufficient_energy(int(skill.cost), int(energy)):
		return "内力不足"
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
	portrait_fail_layer = VisibilityProbe.first_fail_layer(self)
	portrait_visible = portrait_fail_layer == ""

	# 3-number probe + covered-fraction observables (UX-01a/01b) — published
	# every frame after the visibility verdict, before the undo recompute. All
	# probe reads null-guard so teardown / pre-tree states yield sentinels.
	portrait_covered_frac = VisibilityProbe.covered_fraction(self)
	if _sprite != null:
		portrait_sprite_pos = _sprite.global_position
		portrait_tex_size = _sprite.texture.get_size() if _sprite.texture != null else Vector2.ZERO
		# Live clamped ink rect: reads the LIVE _sprite.offset (refined every
		# frame by _refresh_sprite_clamp) and the fresh sprite_top — never
		# grid or a feet-anchored assumption (top-row/edge units differ).
		# Zero-area (null texture) falls back to the sentinel Rect2().
		portrait_ink_rect = Rect2(
			Vector2(_sprite.global_position.x + _sprite.offset.x - portrait_tex_size.x / 2.0, sprite_top),
			portrait_tex_size,
		) if portrait_tex_size != Vector2.ZERO else Rect2()
	else:
		portrait_sprite_pos = Vector2.ZERO
		portrait_tex_size = Vector2.ZERO
		portrait_ink_rect = Rect2()
	var bar: Node = _resolve_portrait_bar()
	if bar != null:
		portrait_bar_pos = (bar as Control).global_position
		# Relays this bar's anchor observables onto the unit (only when a bar
		# resolves; 0.0 otherwise, so a missing bar never asserts a phantom).
		if bar.get("health_bar_screen_y") != null:
			health_bar_screen_y = float(bar.get("health_bar_screen_y"))
			health_bar_world_y = float(bar.get("health_bar_world_y"))
		else:
			health_bar_screen_y = 0.0
			health_bar_world_y = 0.0
	else:
		portrait_bar_pos = Vector2(-1, -1)
		health_bar_screen_y = 0.0
		health_bar_world_y = 0.0

	# Undo availability — recomputed EVERY frame (never event-written), so it is
	# always in sync no matter which writer changed acted / grid_pos / moves_left.
	# A successful action commits the movement (engine sets acted), which is what
	# flips this false.
	undo_available = (not acted) and (grid_pos != turn_start_grid or moves_left != turn_start_moves_left)

	# Alignment pin LAST, so it reads this frame's portrait_ink_rect (itself
	# computed above from the live sprite offset + sprite_top). Derived from the
	# published rect only — no grid lookup, no clamp call, no second rect.
	ink_world_dx = portrait_ink_rect.get_center().x - position.x
	ink_world_dy = portrait_ink_rect.end.y - position.y


## Counting-only observation of the input pipeline: records every left-button
## press that reaches this node, so the playtest can tell whether a synthesized
## `clicks:` event arrived at all. Never marks the event handled — this must
## not interfere with the real _unhandled_input path.
func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		debug_input_events += 1
		debug_last_raw_event_pos = event.position
	# NEW (P0 Layer 1): per-press predicted GUI eater + raw RIGHT-press counter.
	# The left/touch branch above is kept byte-identical (its meaning is pinned by
	# existing scenarios and documented in the _common.yaml header). debug_gui_eater
	# is recomputed on EVERY press — left, right AND touch — so a stale non-empty
	# value cannot mask a fixed hole. debug_right_input_events counts only RIGHT
	# presses (never left / touch / release).
	if event is InputEventMouseButton:
		if event.pressed:
			debug_gui_eater = InputCensus.top_eater(get_tree().root, event.position)
			if event.button_index == MOUSE_BUTTON_RIGHT:
				debug_right_input_events += 1
	elif event is InputEventScreenTouch and event.pressed:
		debug_gui_eater = InputCensus.top_eater(get_tree().root, event.position)


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

	# --- Left-click / TAP on a grid position ---
	# A finger is not a mouse. Every board interaction in this file used to
	# test `event is InputEventMouseButton`, and an InputEventScreenTouch is
	# not one — so on a phone the menus worked (Controls handle touch natively)
	# and the battlefield did not: tapping a tile did nothing at all, with no
	# hint, while the on-screen text said 「左键点格移动」. Touch is handled
	# EXPLICITLY here rather than left to the engine's emulate-mouse-from-touch
	# setting, because that setting is a global toggle whose delivery through
	# the GUI phase is not something this game should be betting its only
	# movement input on.
	elif (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_handle_click_targeting(event)
		get_viewport().set_input_as_handled()

	# --- Right-click: undo this turn's movement back to the turn-start tile ---
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		handle_world_right_click(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## Attempt to move one tile in the given cardinal direction. Returns true when
## the step was accepted and its tween scheduled, false when gated. Existing
## callers (WASD / arrow keys) legally ignore the return in GDScript; the
## click-move step queue uses it to know whether the next queued step may run.
func _try_move(direction: Vector2i) -> bool:
	# Input gating — tutorial must allow movement.
	if not TutorialManager.is_input_allowed("move"):
		return false

	# Turn budget: one tile per point; blocked at zero.
	if moves_left <= 0:
		return false

	var target: Vector2i = grid_pos + direction

	# Validate walkability (in-bounds and not a border wall tile).
	if not GridManager.is_walkable(target):
		return false

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
			return true

	# Validate occupancy.
	if GridManager.is_occupied(target):
		return false

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

	return true


## Attempt to move to an arbitrary reachable tile by resolving it into a
## cardinal step sequence via GridManager.plan_movement (the EXACT _try_move
## cost model: walkable + unoccupied landing tiles, 身轻如燕 slide-through at
## cost 2) and executing it one _try_move call per step. Gate order: tutorial
## allowance (hint), budget (silent), own-tile no-op (silent), walkability
## (silent — clicking the border ring is not a rejection worth a hint),
## reachability (hint). Multi-step paths queue the remaining directions and are
## drained by _on_move_completed.
func _try_move_to(target_grid: Vector2i) -> void:
	if not TutorialManager.is_input_allowed("move"):
		action_hint.emit("教程尚未解锁")
		return

	if moves_left <= 0:
		return

	if target_grid == grid_pos:
		return

	if not GridManager.is_walkable(target_grid):
		return

	var plan: Dictionary = GridManager.plan_movement(
		grid_pos, moves_left, traits.has("swallow_lightness"))
	var steps: Array = plan.get("steps", {}).get(target_grid, [])
	if steps.is_empty():
		action_hint.emit("走不到那里")
		return

	if steps.size() == 1:
		_try_move(steps[0])
		return

	_pending_move_steps = steps.duplicate()
	var first: Vector2i = _pending_move_steps.pop_front()
	_try_move(first)


## Called when the movement animation finishes.
func _on_move_completed() -> void:
	if not is_instance_valid(self):
		return
	# Drain the click-move step queue first: pop the next direction and try it.
	# If it succeeded, the next completion callback is already scheduled — return
	# early. If a queued step ever fails (e.g. the target got occupied mid-queue),
	# clear the queue and fall through to the normal is_moving reset so the unit
	# can never get stuck with is_moving == true.
	if not _pending_move_steps.is_empty():
		var next_dir: Vector2i = _pending_move_steps.pop_front()
		if _try_move(next_dir):
			return
		_pending_move_steps.clear()
	is_moving = false
	# Snap position to exact grid centre (prevents floating-point drift).
	position = GridManager.grid_to_world(grid_pos)


# ---------------------------------------------------------------------------
# Skill selection (gates live in select_skill() / _skill_selectable())
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Targeting (left-click)
# ---------------------------------------------------------------------------

## Pure range-only reach predicate for the §3.B2 portrait-rect resolver. Returns
## whether `enemy_grid` is within the player's CURRENT attack reach measured from
## `player_grid`: Chebyshev distance <= reach, where reach is the selected skill's
## `range` (or 1 for a basic attack / out-of-range / null skill). Range ONLY —
## cooldown / HP / energy / acted gates stay inside _try_attack_target, so a gated
## click is a silent no-op exactly as today. Pure static: no autoloads, no self —
## callable headlessly via load("res://scripts/characters/player.gd").
static func attack_reach_covers(player_grid: Vector2i, enemy_grid: Vector2i,
		selected_skill_index: int, skills: Array) -> bool:
	var reach: int = 1
	if selected_skill_index >= 0 and selected_skill_index < skills.size():
		var skill = skills[selected_skill_index]
		if skill != null:
			var r = skill.get("range")
			if r != null:
				reach = int(r)
	var dist: int = max(abs(player_grid.x - enemy_grid.x), abs(player_grid.y - enemy_grid.y))
	return dist <= reach


## Pure decision predicate for the §3.B2 five-step portrait-rect priority rule.
## Returns which step (1..5) fires for a left-click at `click_point` resolving to
## `click_tile`, given the current `player_grid`, the living enemies (each a
## Dictionary with `grid_pos` and `rect` — the live clamped portrait ink rect),
## the reachable-empty-tile set from the move-range highlight (`reachable` maps
## Vector2i -> true), and the player's selection state (selected_skill_index +
## skills, consumed by attack_reach_covers). Pure static: no autoloads, no self —
## the headless unit truth-table pins it; handle_world_click acts on its return.
static func resolve_click_step(click_point: Vector2, click_tile: Vector2i,
		player_grid: Vector2i, enemies: Array, reachable: Dictionary,
		selected_skill_index: int, skills: Array) -> int:
	# Step 1 — an enemy occupies the clicked tile.
	for e in enemies:
		if e.get("grid_pos", Vector2i(-1, -1)) == click_tile:
			return 1
	# Step 2 — a living enemy whose portrait rect contains P AND is in reach.
	# Fires ONLY for in-reach enemies (the reach gate is what keeps an empty tile
	# clickable behind a tall out-of-reach unit — the §3.1 rule is rejected).
	for e in enemies:
		var rect: Rect2 = e.get("rect", Rect2())
		if rect.has_point(click_point) and attack_reach_covers(
				player_grid, e.get("grid_pos", Vector2i(-1, -1)),
				selected_skill_index, skills):
			return 2
	# Step 3 — a reachable empty tile in the move-range highlight.
	# NOTE: plan_movement deliberately seeds steps[origin] = [] (grid_manager.gd),
	# i.e. the reachable set INCLUDES the own tile; it is excluded here so a click
	# on the own tile falls to step 5's silent no-op instead of a move call.
	if reachable.has(click_tile) and click_tile != player_grid:
		return 3
	# Step 4 — a living enemy whose portrait rect contains P (out-of-reach body).
	for e in enemies:
		if e.get("rect", Rect2()).has_point(click_point):
			return 4
	# Step 5 — own tile no-op, else click-move.
	return 5


## Handle a left mouse click: convert the click event's own viewport coordinates
## to battlefield world space and delegate to the shared handle_world_click.
func _handle_click_targeting(event: InputEvent) -> void:
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
	debug_click_events += 1
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
	debug_last_click_grid = click_grid

	# Build the reachable-empty-tile oracle from the SAME cost model as
	# _try_move_to (GridManager.plan_movement — walkable + unoccupied landing
	# tiles, 身轻如燕 slide-through at cost 2). This is what the move-range
	# highlight paints, so "reachable empty tile" here == "highlighted tile".
	var plan: Dictionary = GridManager.plan_movement(
		grid_pos, moves_left, traits.has("swallow_lightness"))
	var reachable: Dictionary = {}
	for t in plan.get("steps", {}).keys():
		reachable[t] = true

	# Flatten the living enemies into pure data (grid_pos + the LIVE clamped
	# portrait ink rect) for the decision predicate, and keep the node array for
	# the dispatch's _try_attack_target calls. Same living-enemy guards as the
	# old feet-tile match (is_instance_valid + "grid_pos" in enemy).
	var enemies: Array[Node] = GameManager.get_enemies_alive()
	var enemy_data: Array = []
	var enemy_nodes: Array[Node] = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		enemy_data.append({"grid_pos": enemy.grid_pos, "rect": enemy.portrait_ink_rect})
		enemy_nodes.append(enemy)

	# §3.B2 five-step portrait-rect priority rule (see design/30_presentation.md).
	# Order is critical: step 2 (IN-REACH portrait body) fires before step 3
	# (reachable empty tile) so an adjacent enemy is attackable even though its
	# body hangs over an empty highlighted tile; step 3 still wins over step 4
	# (out-of-reach body) so an empty tile never becomes unclickable because a
	# tall OUT-OF-REACH unit stands behind it — the measured-broken §3.1 rule
	# (click_move_undo_right 10->6 / click_move_commit_lock 9->1 /
	# move_target_affordance 18->11) must never be reintroduced.
	var step: int = resolve_click_step(world_pos, click_grid, grid_pos,
		enemy_data, reachable, selected_skill_index, skills)
	debug_click_rule_step = step
	match step:
		1:
			# An enemy occupies the clicked tile — attack it (feet/own-tile).
			var t1: Node = _enemy_at(enemy_nodes, click_grid)
			debug_click_rule_target = t1.name if t1 != null else ""
			_try_attack_target(t1)
			return
		2:
			# IN-reach portrait body — attack the nearest (closes the reachable gap).
			var t2: Node = _pick_nearest_rect_enemy(enemy_nodes, world_pos, true)
			debug_click_rule_target = t2.name if t2 != null else ""
			_try_attack_target(t2)
			return
		3:
			# Reachable empty tile in the move-range highlight — move there.
			debug_click_rule_target = ""
			_try_move_to(click_grid)
			return
		4:
			# Out-of-reach portrait body — attack (range gate stays in _try_attack_target).
			var t4: Node = _pick_nearest_rect_enemy(enemy_nodes, world_pos, false)
			debug_click_rule_target = t4.name if t4 != null else ""
			_try_attack_target(t4)
			return
		_:
			# Own tile silent no-op, else click-move.
			debug_click_rule_target = ""
			if click_grid == grid_pos:
				return
			_try_move_to(click_grid)
			return


## Shared world right-click entry point (PUBLIC — called by the right-click
## branch of _unhandled_input). Carries the same 4-condition gate as
## handle_world_click: battle active, player turn live, not paused, not
## mid-animation. Undo restores the turn-start snapshot (grid_pos / moves_left /
## moved) ANIMATED via GridManager.move_unit — the same tween pattern as
## _try_move, not an instant snap. Refused once the move is committed: the
## engine sets acted on a successful action (attack/skill/item) and end-turn
## ends the player's turn, so commit == acted or not the player's turn.
func handle_world_right_click(world_pos: Vector2) -> void:
	debug_undo_events += 1
	var state: String = GameManager.get_state()
	if state != "BATTLE":
		return
	if not CombatManager.is_player_turn():
		return
	if CombatManager.get_is_paused():
		return
	if is_moving:
		return

	# Commit lock: a successful action locks the turn's movement — no undo.
	if acted:
		action_hint.emit("已出手,无法退回")
		return

	# Benign no-op: already at the turn-start tile with the full budget.
	if grid_pos == turn_start_grid and moves_left == turn_start_moves_left:
		return

	# Restore the exact turn-start state (animated, keeps occupancy consistent).
	moved = turn_start_moved
	moves_left = turn_start_moves_left
	_pending_move_steps = []
	is_moving = true
	GridManager.move_unit(self, grid_pos, turn_start_grid)
	grid_pos = turn_start_grid
	var undo_tween: Tween = create_tween()
	undo_tween.tween_callback(_on_move_completed).set_delay(MOVE_DURATION)


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


## Find the living enemy occupying `tile` (registration-order first). Returns
## null if none. Used by resolver step 1's dispatch.
func _enemy_at(enemies: Array, tile: Vector2i) -> Node:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		if enemy.grid_pos == tile:
			return enemy
	return null


## Find the nearest living enemy whose live clamped portrait rect contains
## `world_pos`, optionally gated to in-reach enemies only (step 2) — used by
## resolver steps 2/4. Strictly-nearest by Chebyshev distance from the clicked
## tile wins; ties keep registration order (the _pick_nearest_enemy_in_range
## precedent). 96 px art vs 64 px tiles ⇒ 32 px overlaps resolve deterministically.
## A zero-area sentinel rect never hits — correct to fall through.
func _pick_nearest_rect_enemy(enemies: Array, world_pos: Vector2, require_in_reach: bool) -> Node:
	var click_tile: Vector2i = GridManager.world_to_grid(world_pos)
	var best: Node = null
	var best_dist: int = 999999
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("grid_pos" in enemy):
			continue
		if not enemy.portrait_ink_rect.has_point(world_pos):
			continue
		if require_in_reach and not attack_reach_covers(
				grid_pos, enemy.grid_pos, selected_skill_index, skills):
			continue
		var enemy_pos: Vector2i = enemy.grid_pos
		var dist: int = max(abs(click_tile.x - enemy_pos.x), abs(click_tile.y - enemy_pos.y))
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


## Resolve the HUD-side HealthBar that follows this unit, or null. Matched by
## duck-typing (a Control with follow_character() whose _char_node == self) —
## bar node names are composition-varying, never matched by name. Cached in
## _portrait_bar; re-resolved only when the cached node is null/invalid (bars
## are freed on battle exit).
func _resolve_portrait_bar() -> Node:
	if _portrait_bar != null and is_instance_valid(_portrait_bar):
		return _portrait_bar
	_portrait_bar = null
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and n.is_visible_in_tree() and n.has_method("follow_character"):
			if n.get("_char_node") == self:
				_portrait_bar = n
				return _portrait_bar
		for child in n.get_children():
			stack.append(child)
	return null


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
