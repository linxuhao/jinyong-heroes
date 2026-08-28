## Enemy — Generic AI-driven opponent
##
## Generic shell for all five Greats (五绝). Pluggable AI controller
## (AIControllerBase) provides distinct per-enemy behavior. The turn engine
## (CombatManager) invokes ai_controller.evaluate() exactly once per enemy
## turn and executes the returned move path + one action. Follows the same
## turn-state pattern as Player (per-turn budgets, round-based int cooldowns).
extends Node2D

const CharacterData = preload("res://scripts/data/character_data.gd")
const SkillData = preload("res://scripts/data/skill_data.gd")
const VisibilityProbe = preload("res://scripts/ui/visibility_probe.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when health changes. HUD HealthBar listens to this.
signal health_changed(new_health: int, max_health: int)

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

## Movement budget remaining this turn (tiles). Reset to move_range by the
## engine at the start of every turn.
var moves_left: int = 0

## True once the unit has moved this turn.
var moved: bool = false

## True once the unit has performed an action this turn.
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

## 身法 initiative value; drives turn order.
var initiative: int = 0

## Team id: 1 = Five Greats.
var team: int = 1

## Primary internal art's passive id (engine hooks: finger_dart, ...).
var passive_id: String = ""

## Trait ids carried into battle from the profile (playtest surface + trait
## engine hooks: sha_po_lang / iron_shirt / swallow_lightness / ambidextrous).
## Populated by battlefield.gd from character_data.traits (encounter battles;
## empty in the tutorial). Identical declaration to player.gd.
var traits: Array[String] = []

## 内力 energy pool (display only — no technique costs this run).
var energy: int = 0

## Movement range in tiles (from character_data; caps AI move budgets).
var move_range: int = 0

## True while a movement tween is playing. Set/cleared by CombatManager.
var is_moving: bool = false

## World-px top edge of the sprite texture rect, derived each frame from the
## unclamped foot anchor (feet - tex_size.y). Exposed for playtest surface
## assertions.
var sprite_top: float = 0.0

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
## Portrait ink rect in world px. Top-left == drawn texture top-left, size ==
## texture size. The sprite is never moved off its tile, so the rect is always
## the unclamped foot anchor:
##   ink = [feet.x - tex.w/2, feet.y - tex.h] .. [feet.x + tex.w/2, feet.y]
## Recomputed every frame from _sprite.offset (the foot anchor set once by the
## visual-apply step) and the fresh sprite_top — never from grid. Consumed by
## the Defect-B portrait-rect hit resolver and the playtest surface. Sentinel
## Rect2() when no texture.
var portrait_ink_rect: Rect2 = Rect2()
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
## ink bottom == its own feet) — which is the invariant now that the sprite is
## pinned to its foot anchor. HISTORY: before the clamp was deleted, top-row
## units drifted off their tiles; the measured dy then was 124 at row 1 and 60
## at row 2 (past tense — no live code path produces it any more). Pinned by
## playtest/portrait_grid_alignment.yaml.
var ink_world_dx: float = 0.0
var ink_world_dy: float = 0.0
## Measurement pin proving whether the authored ClickTarget Control's gui_input
## ever fires (the brief demands measurement, not the comment's claim). Expected
## measured value 0: Godot's GUI picker does not route events to a Control whose
## ancestor is a Node2D, so ClickTarget is dead for routing and cannot eat events.
## Lifetime accumulator — never reset in _process/_ready/setup.
var debug_click_target_fires: int = 0

## Current FSM state label. One of: "IDLE", "APPROACH", "ATTACK",
## "SKILL", "RETREAT". Updated from the AI evaluation result.
var fsm_state: String = "IDLE"

## Pluggable AI controller (AIControllerBase, RefCounted — NOT a Node).
## Set by battlefield.gd after instantiation.
var ai_controller = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _sprite: Sprite2D = $Sprite

## The HUD-side HealthBar that follows this unit, resolved by duck-typing
## (a Control with follow_character() whose _char_node == self) because bar
## node names are composition-varying. Cached; re-resolved only when null or
## invalid (bars are freed on battle exit).
var _portrait_bar: Node = null

## The authored Control hit-surface (child of this Node2D) that the playtest
## harness can click. Resolved in _ready() — never in setup(), because setup()
## runs BEFORE battlefield names the node (the name is still "Enemy" there), and
## the rename to "<EnemyNodeName>_ClickTarget" needs the FINAL node name to be
## unique across the tree.
var _click_target: Control = null

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Character name → preloaded portrait texture. Keys MUST match the
## character_name values set in battlefield.gd.
const TEXTURE_PATHS: Dictionary = {
	"East Heretic": preload("res://assets/characters/east_heretic.png"),
	"West Poison": preload("res://assets/characters/west_poison.png"),
	"South Emperor": preload("res://assets/characters/south_emperor.png"),
	"North Beggar": preload("res://assets/characters/north_beggar.png"),
	"Central Divine": preload("res://assets/characters/central_divine.png"),
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise the enemy with a CharacterData resource and AI controller.
## Called by battlefield.gd after instantiating this scene.
func setup(data, ai) -> void:
	character_data = data

	# Health.
	max_health = data.max_health
	health = max_health

	# Skills (cooldowns as int ROUNDS, initialised ready).
	skills = data.skills.duplicate()
	skill_cooldowns = []
	for _i in skills.size():
		skill_cooldowns.append(0)

	# AI controller.
	ai_controller = ai

	# Turn-based state from the CharacterData record.
	moves_left = data.move_range
	move_range = data.move_range
	initiative = data.initiative
	team = 1
	passive_id = data.passive_id
	energy = data.energy
	statuses = []
	status_names = []
	shield = 0
	turns_taken = 0
	moved = false
	acted = false

	# FSM starts idle.
	fsm_state = "IDLE"

	# Grid position from current world position (set by battlefield after
	# positioning the node).
	grid_pos = GridManager.world_to_grid(position)

	# Visual appearance.
	_apply_character_visuals()


## Returns whether the enemy is currently animating a movement tween.
## Used by the combat engine to gate animation overlap.
func get_is_moving() -> bool:
	return is_moving


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
	# Snap to grid position if not already set.
	if grid_pos == Vector2i(-1, -1):
		grid_pos = GridManager.world_to_grid(position)
	position = GridManager.grid_to_world(grid_pos)

	# Click hit-surface wiring. The external `clicks:` harness targets CONTROL
	# nodes only (get_global_rect + mouse_filter), so a bare Node2D enemy is
	# unclickable. Rename the authored ClickTarget child to
	# "<EnemyNodeName>_ClickTarget" — the harness resolves targets by recursive
	# bare-name search, so the name must be unique across the tree — and relay
	# left-presses into the player's shared world-click handler.
	# NOTE: this MUST live here, not in setup(): setup() runs BEFORE battlefield
	# names the node (the name is still "Enemy" at that point), so a setup()-time
	# rename would give every enemy the same "Enemy_ClickTarget".
	_click_target = get_node_or_null("ClickTarget") as Control
	if _click_target != null:
		_click_target.name = "%s_ClickTarget" % name
		if not _click_target.gui_input.is_connected(_on_click_target_gui_input):
			_click_target.gui_input.connect(_on_click_target_gui_input)


func _process(_delta: float) -> void:
	# Publish sprite_top every frame from the unclamped foot anchor (before the
	# state gate so it is updated during TUTORIAL too). The sprite itself is
	# never written here: its offset is the foot anchor set once by
	# _apply_character_visuals(), and the camera — not the sprite — owns
	# visibility.
	# NOTE: cooldowns are int ROUNDS, decremented only by the turn engine at
	# the unit's own turn start — no per-frame ticking, no timer-driven AI.
	if _sprite != null and _sprite.texture != null:
		var anchor_tex_size: Vector2 = _sprite.texture.get_size()
		sprite_top = position.y + _sprite.offset.y - anchor_tex_size.y / 2.0
	portrait_fail_layer = VisibilityProbe.first_fail_layer(self)
	portrait_visible = portrait_fail_layer == ""

	# 3-number probe + covered-fraction observables (UX-01a/01b) — published
	# every frame after the visibility verdict. All probe reads null-guard so
	# teardown / pre-tree states yield sentinels.
	portrait_covered_frac = VisibilityProbe.covered_fraction(self)
	if _sprite != null:
		portrait_sprite_pos = _sprite.global_position
		portrait_tex_size = _sprite.texture.get_size() if _sprite.texture != null else Vector2.ZERO
					# Live unclamped ink rect: reads the LIVE _sprite.offset (the foot
			# anchor set once by _apply_character_visuals()) and the fresh
			# sprite_top — never grid or a feet-anchored assumption (top-row/
			# edge units differ). Zero-area (null texture) falls back to the
			# sentinel Rect2().
		
		
		
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

	# Alignment pin LAST, so it reads this frame's portrait_ink_rect (itself
	# computed above from the live sprite offset + sprite_top). Derived from the
	# published rect only — no grid lookup, no clamp call, no second rect.
	ink_world_dx = portrait_ink_rect.get_center().x - position.x
	ink_world_dy = portrait_ink_rect.end.y - position.y


## Catch left-clicks on this enemy's tile directly from the input pipeline.
## The external `clicks:` harness pushes real InputEventMouseButton events, but
## Godot's GUI picker does NOT route them to a Control whose ancestor is a
## Node2D (measured: the ClickTarget's gui_input never fires), so the authored
## hit-surface alone leaves the enemy unclickable. `_input` runs on EVERY node
## BEFORE the GUI system, so it is the reliable relay: it filters left-presses,
## converts the event's own viewport coordinates to world space (identical
## formula to player._handle_click_targeting), matches the clicked tile against
## this enemy's grid_pos, and forwards into the player's shared, self-gated
## handle_world_click. The event is marked handled so the player's
## _unhandled_input mouse branch (the same handle_world_click) cannot
## double-process it — the `acted` gate in _try_attack_target is the backstop
## even if both paths ever run.
func _input(event: InputEvent) -> void:
	# Mouse OR finger: same relay. See player.gd's tap branch — the battlefield
	# was mouse-only, so a phone could not attack an enemy any more than it
	# could walk.
	var is_tap: bool = event is InputEventScreenTouch and event.pressed
	var is_click: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if not (is_tap or is_click):
		return
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	var click_grid: Vector2i = GridManager.world_to_grid(world)
	if click_grid != grid_pos:
		return
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("handle_world_click"):
		return
	get_viewport().set_input_as_handled()
	player.handle_world_click(world)


# ---------------------------------------------------------------------------
# Click hit-surface relay
# ---------------------------------------------------------------------------

## Relay a left-press on this enemy's hit-surface into the player's shared
## world-click handler. gui_input's event.position is LOCAL to the control's
## rect — never use it for world math; the world point is the rect center in
## global canvas coordinates (canvas coords == world coords under the identity
## canvas transform, the same assumption _handle_click_targeting documents).
func _on_click_target_gui_input(event: InputEvent) -> void:
	# Count ANY gui_input delivery — placed BEFORE the mouse-button guard so the
	# counter measures "does gui_input fire at all", not "how many left-presses".
	debug_click_target_fires += 1
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("handle_world_click"):
		return
	player.handle_world_click(_click_target.get_global_rect().get_center())


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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


## Assign the character portrait texture, tint and feet anchor to the Sprite.
## Resolves the node via get_node_or_null so it works even when called from
## setup() BEFORE the node enters the tree (@onready _sprite is null then).
func _apply_character_visuals() -> void:
	var sprite: Sprite2D = _sprite
	if sprite == null:
		# Safe: get_node_or_null re-resolves the path each call and returns
		# null for freed nodes — never a freed-object cast.
		sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return

	var name_key: String = character_data.character_name if character_data != null else ""
	var tex: Texture2D = TEXTURE_PATHS.get(name_key, null)
	if tex == null:
		# Null-safe fallback: sprite stays texture-less (invisible), logic intact.
		push_warning("Enemy texture not found for character: %s" % name_key)
		return

	sprite.texture = tex
	sprite.modulate = Color.WHITE
	sprite.offset = Vector2(0, -(tex.get_height() / 2.0))  # feet at tile centre
