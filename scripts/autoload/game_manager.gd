## GameManager (autoload)
##
## Top-level game state machine. Owns win/lose conditions, scene references,
## and battle lifecycle. Runs as an autoload singleton.
##
## State machine: TUTORIAL -> BATTLE -> (WON | LOST)
## PAUSED is a sub-state of BATTLE managed by CombatManager.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the battle starts (transition TUTORIAL -> BATTLE).
signal battle_started()

## Emitted when all enemies are defeated (transition BATTLE -> WON).
signal game_won()

## Emitted when the player's health reaches zero (transition BATTLE -> LOST).
signal game_lost()

## Emitted on every state transition. Passes the new state name.
signal state_changed(new_state: String)

## Emitted when the player presses continue on the WON overlay (routes to the
## next segment). SceneManager connects here to perform the actual scene swap.
signal continue_requested()

## Emitted when the player presses retry on the LOST overlay (routes back to a
## fresh tutorial battle). SceneManager connects here to reload the battlefield.
signal retry_requested()

## Emitted by restart_game() after state_changed("TUTORIAL"). SceneManager
## (sibling task) connects here to reload a fresh battlefield for the restarted
## tutorial.
signal restart_requested()

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## State string constants. The playtest spec asserts these raw values verbatim
## (GameManager.current_state == "WON" etc.) — never rename them.
const STATE_TUTORIAL: String = "TUTORIAL"
const STATE_BATTLE: String = "BATTLE"
const STATE_WON: String = "WON"
const STATE_LOST: String = "LOST"
const STATE_TRANSITION: String = "TRANSITION"
const STATE_CHARACTER_CREATION: String = "CHARACTER_CREATION"
const STATE_SECT_SELECTION: String = "SECT_SELECTION"
const STATE_CULTIVATION: String = "CULTIVATION"
const STATE_MAP: String = "MAP"
const STATE_ENDING: String = "ENDING"
## Menu states — deliberately NOT segment states, NOT in SEGMENT_PREDECESSORS,
## and never saveable: SaveManager.STABLE_STATES is only ["CULTIVATION", "MAP"],
## so save_slot() naturally refuses them. Reached only through the menu_* methods
## below, which set state + emit directly and never consult the predecessor map.
const STATE_MENU: String = "MENU"
const STATE_SETTINGS: String = "SETTINGS"

## enter_segment()'s validation domain: the six segment scenes only. The battle
## states (TUTORIAL/BATTLE/WON/LOST) are reached through their own entry points
## (start_battle / end_battle / request_retry / request_continue) and are
## deliberately excluded.
const SEGMENT_STATES: Array[String] = [
	STATE_TRANSITION, STATE_CHARACTER_CREATION, STATE_SECT_SELECTION,
	STATE_CULTIVATION, STATE_MAP, STATE_ENDING,
]

## Legal predecessor map for enter_segment() (design §4 table): each segment
## state lists the single state it may be entered from. Values reference the
## STATE_* constants so a rename cannot silently desync the table.
const SEGMENT_PREDECESSORS: Dictionary = {
	"TRANSITION": [STATE_WON],
	"CHARACTER_CREATION": [STATE_TRANSITION],
	"SECT_SELECTION": [STATE_CHARACTER_CREATION, STATE_TRANSITION],
	"CULTIVATION": [STATE_SECT_SELECTION],
	"MAP": [STATE_CULTIVATION],
	"ENDING": [STATE_MAP],
}

## The current game state — one of the STATE_* constants above.
var current_state: String = STATE_TUTORIAL

## Routing flags (boot defaults preserve the legacy path exactly):
## creation_entry discriminates how creation was entered — "MENU" (new flow:
## confirm routes to TUTORIAL) or "TRANSITION" (legacy boot-flow path: confirm
## routes to SECT_SELECTION, byte-identical). creation_done is set when the
## MENU-entry creation confirms; the TRANSITION screen's last-page advance
## branches on it (creation_done ? SECT_SELECTION : CHARACTER_CREATION).
## Both are reset in restart_game().
var creation_entry: String = "TRANSITION"
var creation_done: bool = false

## Array of living enemy nodes registered via register_enemy().
var enemies_alive: Array[Node] = []

## Reference to the player character Node, stored via set_player().
var _player: Node = null

## Reference to the end-game overlay CanvasLayer (guards against duplicates).
var _overlay_layer: CanvasLayer = null

## Battle context: where end_battle()'s WON/LOST route once the overlay is
## dismissed. "TUTORIAL" = the tutorial battle (WON -> TRANSITION, LOST ->
## retry); future encounter battles set it to "CULTIVATION" via
## set_battle_return_state(). This is the seam that makes WON/LOST transitions,
## not terminal states.
var battle_return_state: String = "TUTORIAL"

## Build-source signal for a node-entry (map) battle, decoupled from the return
## target: battle_return_state decides ONLY where WON/LOST routes, while
## map_battle_id decides who builds the player character. Non-empty means a MAP
## battle that must profile-build via BattleSetup.build_character(SaveManager.
## profile) and resolve its opponent roster from the id (huashan_duel). Empty
## means the tutorial / encounter fallthrough (tutorial Yang Guo) stays intact.
## Lifecycle = write-at-entry (start_map_battle writes the id; start_encounter /
## start_battle / restart_game write "") + clear-at-route (request_continue /
## request_retry write ""). clear_battle() deliberately never touches it (it runs
## mid-swap on every scene change; a mid-swap clear sits exactly between the
## entry write and the new battlefield's _ready() read and re-creates the defect).
var map_battle_id: String = ""

## Session mirror of MapScreen.events_resolved_count. The MapScreen is rebuilt on
## return from a map battle (SceneManager._do_swap frees it), so its own counter
## would reset to 0; this mirror carries the count across the swap. Seeded in
## map._ready() and written through on every resolve; reset to 0 when a run
## begins (SaveManager.profile_created) or a save is loaded (SaveManager.loaded).
## Session-scoped only — never persisted.
var map_events_resolved_count: int = 0

## Session mirror of the facility monthly-use epoch (jinyong-loop R2). The
## MapScreen is rebuilt on return from a map battle, so its own per-month counter
## would reset to 0; this mirror carries the (month, count) pair across the swap.
## `facility_use_month` is the profile month of the last facility use (-1 = never
## used this session); `facility_use_count_this_month` counts uses within that
## month. Both reset when a run begins (SaveManager.profile_created) or a save is
## loaded (SaveManager.loaded) — the same lifecycle as map_events_resolved_count.
## Session-scoped only — never persisted (no save-schema change).
var facility_use_month: int = -1
var facility_use_count_this_month: int = 0

## Session mirror of the settled node-event set (jinyong-loop R2). Keys are the
## (node_id, event_id) PAIR "<node_id>/<event_id>" -> true — never an
## event-id-global flag: the cultivation bag channel is documented independent
## of the map node channel, so a bag-drawn night_rain must not suppress the
## shaolin node binding. Written by MapScreen on every APPLIED node-event
## resolution; read by _resolve_node_event()'s settled path so a revisit
## re-SHOWS the event (re-fire is pinned by gates (b)) but never re-settles its
## economy/attr effects. Survives the MapScreen rebuild on return from a map
## battle; reset (clear) in the SAME handler as map_events_resolved_count when a
## run begins or a save is loaded. Session-scoped only — never persisted (no
## save-schema change; documented consequence: a loaded save may re-settle once
## per session, identical to the map_events_resolved_count mirror's behavior).
var settled_node_events: Dictionary = {}


## Whether this (node, event) pair has already applied its effects this session.
func is_node_event_settled(node_id: String, event_id: String) -> bool:
	return settled_node_events.get(node_id + "/" + event_id, false)


## Mark a (node, event) pair as settled (its effects applied this session).
func settle_node_event(node_id: String, event_id: String) -> void:
	settled_node_events[node_id + "/" + event_id] = true

## Observable: the end-game overlay's rendered text, written unconditionally
## inside _show_end_game_overlay() whenever the overlay shows (WON -> text
## containing 胜利, LOST -> text containing 战败). Never contains the ellipsis
## character U+2026 "…" or "..." (repo-wide no-ellipsis rule for UI text) —
## asserted by test_game_manager_fsm and the playtest surface.
var end_overlay_text: String = ""

## Observable: whether the end-game overlay's ContinueButton/RetryButton have
## their `pressed` signal wired to the matching handler. Written in BOTH the
## construction and the re-show branches of _show_end_game_overlay(). Mirrors
## CreationScreen.pressed_connected — the clicks-only spine can only click the
## button its route happens to reach (ContinueButton on a WON run), so this
## proves RetryButton (and every future button) is actually connected even when
## no click path touches it. Shape: {"ContinueButton": bool, "RetryButton": bool}.
var end_overlay_pressed_connected: Dictionary = {}

# ---------------------------------------------------------------------------
# Public API — State queries
# ---------------------------------------------------------------------------

## Returns the current game state string.
func get_state() -> String:
	return current_state

# ---------------------------------------------------------------------------
# Public API — State transitions
# ---------------------------------------------------------------------------

## Transition from TUTORIAL to BATTLE.
## No-op if the game is already in BATTLE, WON, or LOST state.
func start_battle() -> void:
	if current_state != "TUTORIAL":
		return

	current_state = "BATTLE"
	map_battle_id = ""
	battle_started.emit()
	state_changed.emit("BATTLE")


## Enter an encounter battle from the cultivation segment: CULTIVATION -> BATTLE
## with battle_return_state == "CULTIVATION" so WON/LOST route back to the
## cultivation segment (see request_continue / request_retry). No-op outside
## CULTIVATION. Deliberately does NOT reuse start_battle(), which stays
## hard-gated to TUTORIAL.
func start_encounter() -> void:
	if current_state != STATE_CULTIVATION:
		return
	battle_return_state = STATE_CULTIVATION
	map_battle_id = ""
	current_state = STATE_BATTLE
	battle_started.emit()
	state_changed.emit(STATE_BATTLE)


## Enter a node-entry battle from the map segment: MAP -> BATTLE with
## battle_return_state == "MAP", so WON/LOST route back to the map.
##
## The return path needs no new code and none was added: request_continue() and
## request_retry() already send the player to battle_return_state whenever it
## names a segment state, and MAP is one of SEGMENT_STATES. Setting the field is
## the whole of it.
##
## SEGMENT_PREDECESSORS says MAP may be entered from CULTIVATION, and that stays
## true of enter_segment(); the WON/LOST return writes current_state directly and
## has never consulted that table. start_encounter() already established exactly
## this shape for CULTIVATION, so this is the existing seam used a second time,
## not a new one.
##
## Deliberately does NOT reuse start_battle() (hard-gated to TUTORIAL) or
## start_encounter() (hard-gated to CULTIVATION): each entry point states the one
## state it may be reached from, so a stray call cannot smuggle the player into a
## battle from somewhere the design never sanctioned. No-op outside MAP.
## The battle id is written BEFORE battle_started.emit() / state_changed.emit()
## (write-before-emit is the ordering guarantee: state_changed synchronously
## drives the SceneManager swap, and the mid-swap teardown runs after the write
## is already on record). The default parameter keeps historical no-arg call
## sites source-compatible.
func start_map_battle(battle_id: String = "") -> void:
	if current_state != STATE_MAP:
		return
	battle_return_state = STATE_MAP
	map_battle_id = battle_id
	current_state = STATE_BATTLE
	battle_started.emit()
	state_changed.emit(STATE_BATTLE)


## End the battle with a win or loss.
## Shows a centered overlay with victory or defeat text.
## No-op if the game is already in WON or LOST state.
func end_battle(won: bool) -> void:
	if current_state == "WON" or current_state == "LOST":
		return

	if won:
		current_state = "WON"
		game_won.emit()
		state_changed.emit("WON")
		_show_end_game_overlay("胜利！华山论剑的胜者！\n\n点击「继续」进入江湖")
	else:
		current_state = "LOST"
		game_lost.emit()
		state_changed.emit("LOST")
		_show_end_game_overlay("战败于华山论剑\n\n点击「重试」再战")

# ---------------------------------------------------------------------------
# Public API — Battle context & WON/LOST routing (combat_cleanup)
# ---------------------------------------------------------------------------

## Set where the current battle's WON/LOST should route once dismissed.
func set_battle_return_state(s: String) -> void:
	battle_return_state = s


## The current battle's return-state context (see battle_return_state).
func get_battle_return_state() -> String:
	return battle_return_state


## Set the current map-battle build-source id (see map_battle_id).
func set_map_battle_id(v: String) -> void:
	map_battle_id = v


## The current map-battle build-source id (see map_battle_id).
func get_map_battle_id() -> String:
	return map_battle_id


## Autoload init. Deferred because the SaveManager autoload must already be in
## the tree before we connect its signals — a deferred flush runs after every
## autoload's _ready(), so autoload registration order can never bite here.
func _ready() -> void:
	_connect_save_signals.call_deferred()


## Connect the run-boundary signals that reset the events-resolved mirror. Both
## SaveManager.loaded (passes slot: int) and SaveManager.profile_created (no
## args) are routed to the same zeroing handler; the handler's optional Variant
## parameter absorbs either shape.
func _connect_save_signals() -> void:
	SaveManager.loaded.connect(_reset_map_events_resolved_count)
	SaveManager.profile_created.connect(_reset_map_events_resolved_count)


## Zero the events-resolved mirror when a run begins or a save is loaded.
func _reset_map_events_resolved_count(_a: Variant = null) -> void:
	map_events_resolved_count = 0
	# The facility monthly-use mirror shares the same run-boundary lifecycle.
	facility_use_month = -1
	facility_use_count_this_month = 0
	# The settled node-event set shares the same run-boundary lifecycle: a fresh
	# run (or a loaded save) starts with every (node, event) pair unsettled.
	settled_node_events.clear()


## Drop every per-battle reference owned by this autoload so a scene swap never
## touches freed nodes: clears the enemy registry, releases the player slot
## (set_player is first-call-wins — a stale _player would silently swallow the
## next battle's player), and frees the end-game overlay.
func clear_battle() -> void:
	enemies_alive.clear()
	_player = null
	if _overlay_layer != null:
		_overlay_layer.queue_free()
		_overlay_layer = null


## WON overlay continue: route to the next segment and notify listeners.
## Destination is battle_return_state when it is a segment state (future
## encounter battles route WON back to CULTIVATION); the tutorial battle keeps
## battle_return_state == "TUTORIAL" (not a segment), which falls back to the
## fixed next segment TRANSITION. Routing to a segment drops every per-battle
## ref (clear_battle) so a second encounter in one session rebuilds fresh; the
## tutorial WON path is not a segment and stays byte-identical (no
## clear_battle). No-op unless the game is in WON.
func request_continue() -> void:
	if current_state != STATE_WON:
		return
	map_battle_id = ""
	var target: String = battle_return_state if SEGMENT_STATES.has(battle_return_state) else STATE_TRANSITION
	if SEGMENT_STATES.has(battle_return_state):
		clear_battle()
	current_state = target
	state_changed.emit(target)
	continue_requested.emit()


## LOST overlay retry: clear battle refs, then route to battle_return_state when
## it is a segment state (encounter battles route LOST back to CULTIVATION),
## else back to the tutorial. SceneManager reloads a fresh battlefield on
## retry_requested. No-op unless the game is in LOST.
func request_retry() -> void:
	if current_state != "LOST":
		return
	map_battle_id = ""
	clear_battle()
	var target: String = battle_return_state if SEGMENT_STATES.has(battle_return_state) else STATE_TUTORIAL
	current_state = target
	state_changed.emit(target)
	retry_requested.emit()


## Validated single-transition helper used by segment scenes (design §4 table).
## Returns true and emits state_changed(state) only when `state` is a segment
## state and current_state is its legal predecessor; any other target
## (non-segment, self, or out-of-order) returns false with no effect.
func enter_segment(state: String) -> bool:
	if not SEGMENT_STATES.has(state):
		return false
	var allowed: Variant = SEGMENT_PREDECESSORS.get(state, null)
	if not (allowed is Array) or not (allowed as Array).has(current_state):
		return false
	current_state = state
	state_changed.emit(state)
	return true

# ---------------------------------------------------------------------------
# Public API — Menu states & routing (step2: main menu before creation)
# ---------------------------------------------------------------------------

## Enter the main-menu state. Idempotent, no guard: any state moves to MENU and
## emits state_changed("MENU"). Used by the MenuPanel boot claim (menu.tscn),
## whose _ready runs before SceneManager's deferred default swap.
func enter_menu() -> void:
	current_state = STATE_MENU
	state_changed.emit(STATE_MENU)


## MENU -> CHARACTER_CREATION for a new adventure. Marks creation_entry = "MENU"
## so creation confirm routes to TUTORIAL (new flow) instead of SECT_SELECTION.
## No-op (false, no side effects) outside MENU.
func menu_new_adventure() -> bool:
	if current_state != STATE_MENU:
		return false
	creation_entry = "MENU"
	current_state = STATE_CHARACTER_CREATION
	state_changed.emit(STATE_CHARACTER_CREATION)
	return true


## MENU -> SETTINGS (settings screen entry). No-op (false, no side effects)
## outside MENU.
func menu_open_settings() -> bool:
	if current_state != STATE_MENU:
		return false
	current_state = STATE_SETTINGS
	state_changed.emit(STATE_SETTINGS)
	return true


## SETTINGS -> MENU (settings screen back button). No-op (false, no side
## effects) outside SETTINGS.
func menu_close_settings() -> bool:
	if current_state != STATE_SETTINGS:
		return false
	current_state = STATE_MENU
	state_changed.emit(STATE_MENU)
	return true


## MENU 读取存档: load autosave slot 1 and route directly into the restored
## stable segment (CULTIVATION/MAP), bypassing SEGMENT_PREDECESSORS — loading
## from the menu is not a predecessor-legal edge and must not be gated by that
## map. Returns false with no emit when the load fails (SaveManager.last_error
## already carries no_save/bad_json/bad_version/bad_schema/io_error) or when a
## hostile save claims a non-stable segment (forced to "bad_schema"). No-op
## (false, SaveManager untouched) outside MENU.
func menu_load_game() -> bool:
	if current_state != STATE_MENU:
		return false
	if not SaveManager.load_slot(1):
		return false
	if not SaveManager.STABLE_STATES.has(SaveManager.segment):
		SaveManager.last_error = "bad_schema"
		return false
	clear_battle()
	current_state = SaveManager.segment
	state_changed.emit(SaveManager.segment)
	return true


## MENU 退出: quit the game.
func menu_quit() -> void:
	get_tree().quit()


## Character-creation confirm routing. MENU entry (creation_entry == "MENU"):
## creation is done — mark creation_done, set TUTORIAL directly (TUTORIAL is not
## a segment state, so enter_segment cannot express it; the battlefield _ready
## defers TutorialManager.start(), which drives TUTORIAL -> BATTLE). Legacy entry
## (boot default "TRANSITION"): byte-identical enter_segment("SECT_SELECTION")
## call and nothing else. Deliberately not guarded by current_state — it
## branches on creation_entry only.
func finish_creation() -> void:
	if creation_entry == "MENU":
		creation_done = true
		current_state = STATE_TUTORIAL
		state_changed.emit(STATE_TUTORIAL)
	else:
		enter_segment("SECT_SELECTION")


## Restart from ENDING (or anywhere): drop every battle reference, reset
## SaveManager to a fresh default profile, then route to a truly-fresh TUTORIAL.
## new_profile() now sets tutorial_done = false (creation happens before the
## tutorial); the explicit reset below is redundant but kept for clarity.
## Emits state_changed("TUTORIAL") BEFORE restart_requested() so SceneManager
## routes the scene first, then reloads a fresh battlefield.
func restart_game() -> void:
	clear_battle()
	map_battle_id = ""
	SaveManager.new_profile({}, [])
	SaveManager.profile.flags["tutorial_done"] = false
	creation_entry = "TRANSITION"
	creation_done = false
	current_state = STATE_TUTORIAL
	state_changed.emit(STATE_TUTORIAL)
	restart_requested.emit()

# ---------------------------------------------------------------------------
# Public API — Enemy tracking
# ---------------------------------------------------------------------------

## Register a living enemy node. Silently ignores duplicate registrations.
func register_enemy(node: Node) -> void:
	if node == null:
		return
	if enemies_alive.has(node):
		return
	enemies_alive.append(node)


## Unregister an enemy node (called on death).
## If all enemies are defeated while in BATTLE state, automatically triggers
## end_battle(true). Does NOT trigger a win during TUTORIAL state.
func unregister_enemy(node: Node) -> void:
	var idx: int = enemies_alive.find(node)
	if idx == -1:
		return

	enemies_alive.remove_at(idx)

	# Auto-win only during active battle.
	if current_state == "BATTLE" and enemies_alive.is_empty():
		end_battle(true)


## Returns a defensive copy of the living-enemies array.
func get_enemies_alive() -> Array[Node]:
	return enemies_alive.duplicate()

# ---------------------------------------------------------------------------
# Public API — Player reference
# ---------------------------------------------------------------------------

## Store a reference to the player character. First-call-wins — subsequent
## calls are silently ignored while the stored reference is a LIVE node,
## preventing accidental overwrites. A stale reference to a FREED node (not
## is_instance_valid) is replaced unconditionally: a dead player from a previous
## scene swap must never block the fresh player of the next battle (the
## encounter path relies on this self-heal after its guarded pre-cleanup).
func set_player(node: Node) -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = node


## Returns the stored player reference, or null if not yet set.
func get_player() -> Node:
	return _player

## Drop every stale (freed) per-battle reference held by this autoload so the
## next battle never registers against a dead node. Clears _player only when it
## is a freed node (a live player is never touched) and removes every
## enemies_alive entry that is not is_instance_valid, preserving the order of
## live entries. Reference-clearing only — NEVER frees any node (scene teardown
## owns the free) and never touches _overlay_layer (clear_battle()'s job), so
## live battle data is zero-impact and clear_battle()/register_enemy()/
## unregister_enemy() semantics are unchanged.
func release_stale_units() -> void:
	if _player != null and not is_instance_valid(_player):
		_player = null
	var kept: Array[Node] = []
	for enemy in enemies_alive:
		if is_instance_valid(enemy):
			kept.append(enemy)
	enemies_alive = kept

# ---------------------------------------------------------------------------
# Private helpers — End-game overlay
# ---------------------------------------------------------------------------

## Creates and shows a centered victory/defeat overlay.
## Uses a CanvasLayer so it renders above all game content.
## Guarded against duplicate overlays.
func _show_end_game_overlay(text: String) -> void:
	# Observable: always record the rendered text (outside the overlay-null
	# guard) so the playtest surface reads it in every show path.
	end_overlay_text = text
	if _overlay_layer != null:
		# Overlay already exists — update text and re-sync both buttons (never
		# leave a stale/hidden button over the next screen). Safe:
		# get_node_or_null re-resolves each path and returns null for freed
		# nodes — no freed-object cast can occur.
		var existing_label: Label = _overlay_layer.get_node_or_null("Panel/Label")
		if existing_label != null:
			existing_label.text = text
		var existing_continue: Button = _overlay_layer.get_node_or_null("Panel/ContinueButton")
		if existing_continue != null:
			existing_continue.text = tr("继续")
			existing_continue.visible = (current_state == STATE_WON)
		var existing_retry: Button = _overlay_layer.get_node_or_null("Panel/RetryButton")
		if existing_retry != null:
			existing_retry.text = tr("重试")
			existing_retry.visible = (current_state == STATE_LOST)
		_refresh_end_overlay_pressed_connected()
		return

	# Create CanvasLayer at a high layer (above HUD, below tutorial).
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "EndGameOverlay"
	_overlay_layer.layer = 50
	add_child(_overlay_layer)

	# Dimming overlay — semi-transparent black.
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks through.
	_overlay_layer.add_child(dim)

	# Centered panel.
	var panel: Panel = Panel.new()
	panel.name = "Panel"
	panel.size = Vector2(500, 250)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Style the panel.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

	_overlay_layer.add_child(panel)

	# Label.
	var label: Label = Label.new()
	label.name = "Label"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -80  # Upper band only (panel is 500x250; label ends ~170) so it never overlaps the buttons. Layout only — no theme/font change.
	label.add_theme_color_override("font_color", Color.GOLD)
	label.add_theme_font_size_override("font_size", 28)
	panel.add_child(label)

	# Clickable controls (this round: pointer reachability). Added AFTER the dim
	# + panel + label, so GUI picking (topmost-first) hits them and the full-rect
	# STOP Dim does not swallow the tap. Both share the lower band of the
	# 500x250 panel; only one is visible per state. focus_mode = FOCUS_NONE means
	# the button can never grab focus, so an injected ui_accept cannot activate
	# it — keyboard dismissal stays in _unhandled_input (single-fire), while a
	# finger/click reaches only the button. Each delegates to the SAME function
	# the keyboard branch calls.
	var continue_btn: Button = Button.new()
	continue_btn.name = "ContinueButton"
	continue_btn.text = tr("继续")
	continue_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.custom_minimum_size = Vector2(200, 48)
	continue_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	continue_btn.offset_left = 150
	continue_btn.offset_top = 178
	continue_btn.offset_right = 350
	continue_btn.offset_bottom = 226
	continue_btn.pressed.connect(request_continue)
	continue_btn.visible = (current_state == STATE_WON)
	panel.add_child(continue_btn)

	var retry_btn: Button = Button.new()
	retry_btn.name = "RetryButton"
	retry_btn.text = tr("重试")
	retry_btn.focus_mode = Control.FOCUS_NONE
	retry_btn.custom_minimum_size = Vector2(200, 48)
	retry_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	retry_btn.offset_left = 150
	retry_btn.offset_top = 178
	retry_btn.offset_right = 350
	retry_btn.offset_bottom = 226
	retry_btn.pressed.connect(request_retry)
	retry_btn.visible = (current_state == STATE_LOST)
	panel.add_child(retry_btn)

	_refresh_end_overlay_pressed_connected()


## Recompute the end_overlay_pressed_connected observable from the live overlay
## buttons (used by BOTH the construction and the re-show branches so the
## observable is never stale). False for a button that is absent/freed.
func _refresh_end_overlay_pressed_connected() -> void:
	if _overlay_layer == null:
		end_overlay_pressed_connected = {"ContinueButton": false, "RetryButton": false}
		return
	var cont: Button = _overlay_layer.get_node_or_null("Panel/ContinueButton")
	var ret: Button = _overlay_layer.get_node_or_null("Panel/RetryButton")
	end_overlay_pressed_connected = {
		"ContinueButton": cont != null and cont.pressed.is_connected(request_continue),
		"RetryButton": ret != null and ret.pressed.is_connected(request_retry),
	}

# ---------------------------------------------------------------------------
# Input — WON/LOST continue/retry + DEBUG hooks
# ---------------------------------------------------------------------------

## WON/LOST keyboard routing: ui_accept / tutorial_next dismiss the overlay.
## Lives in _unhandled_input (NOT on the overlay) so headless playtest key
## presses drive the routing. The overlay's ContinueButton/RetryButton are
## focus_mode = FOCUS_NONE, so they can never grab focus and ui_accept cannot
## activate them — keyboard events still reach _unhandled_input untouched and
## exactly one dismissal fires per key press. request_continue/request_retry each
## guard on current_state, so even a double delivery cannot advance two segments.
func _unhandled_input(event: InputEvent) -> void:
	if current_state == "WON":
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
			get_viewport().set_input_as_handled()
			request_continue()
	elif current_state == "LOST":
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
			get_viewport().set_input_as_handled()
			request_retry()


## Consume the unbound DEBUG actions (harness-only; empty event lists in
## project.godot, triggerable via Input.action_press). Both route through the
## real battle pipeline via CombatManager so WON/LOST behave exactly like
## normal play (debug_win_tutorial -> wipe enemies -> end_battle(true);
## debug_lose_tutorial -> kill player -> end_battle(false)).
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_win_tutorial"):
		CombatManager.debug_wipe_enemies()
	if Input.is_action_just_pressed("debug_lose_tutorial"):
		CombatManager.debug_kill_player()
	if Input.is_action_just_pressed("debug_enter_encounter"):
		start_encounter()
	if Input.is_action_just_pressed("debug_poison_player"):
		CombatManager.debug_poison_player()
	if Input.is_action_just_pressed("debug_damage_player"):
		CombatManager.debug_damage_player()
	if Input.is_action_just_pressed("debug_spend_player_qi"):
		CombatManager.debug_spend_player_qi()
	# DEBUG save fixtures (harness-only; actions registered by project.godot
	# [input] as empty-event lists). debug_seed_save walks the real atomic save
	# pipeline (autosave -> save_slot) with a temporary state swap to
	# CULTIVATION so the save dict's "segment" field records a stable state; the
	# restore to prev happens unconditionally because save_slot is fully
	# synchronous (no await). No state_changed emission, no SceneManager call,
	# no scene swap. debug_delete_save removes autosave slot 1 so the "no save"
	# menu state is deterministic against a dirty user dir.
	#
	# Data-seeding: on the MENU/SETTINGS boot path SaveManager.decks is still {}
	# (new_profile() is the only _init_decks() caller on the normal path, and it
	# is never reached before the menu), so an autosave would crash in
	# _build_save_dict/_decks_snapshot on a missing deck category key. Call
	# new_profile({}, []) FIRST so profile/decks/rng/seed are initialized (fresh
	# profile, cultivation year 1 month 1, six real DECK_CATEGORIES decks)
	# before the state swap and autosave. new_profile() semantics are unchanged;
	# the autosave then persists the seeded state as a valid save_1.json, which
	# enables the menu's 读取存档 entry.
	if Input.is_action_just_pressed("debug_seed_save"):
		if current_state == STATE_MENU or current_state == STATE_SETTINGS:
			SaveManager.new_profile({}, [])
			var prev: String = current_state
			current_state = STATE_CULTIVATION
			SaveManager.autosave()
			current_state = prev
	if Input.is_action_just_pressed("debug_delete_save"):
		SaveManager.delete_slot(1)
