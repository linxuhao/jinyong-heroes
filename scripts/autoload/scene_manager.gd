## SceneManager (autoload) — step2_design C1 / task plan scene_manager.
##
## State-driven scene router under the persistent shell (scenes/main.tscn):
## listens to GameManager.state_changed and instantiates exactly one active
## segment scene as a child of the shell's SceneHost node. Owns the swap
## lifecycle — deferred free of the outgoing scene (await tree_exited) so no
## code path ever touches a node freed in the same frame (SOTA edge case 1).
##
## Startup: autoload _ready runs BEFORE the main scene enters the tree, so the
## host is resolved after one deferred frame (mirror TutorialManager) and the
## initial battlefield is instantiated synchronously from a preloaded scene —
## the protected tutorial scenarios' frame-3 ui_accept presses hit a live
## battlefield exactly as before the shell refactor.
##
## Never calls TutorialManager.start() — battlefield.gd's own _ready defers it.
extends Node

## Surface: key of the currently hosted scene ("battlefield" | "transition" |
## "creation" | "sect_select" | "cultivation" | "map" | "ending" | "none").
var current_scene: String = "none"

## Surface: true while a deferred swap is in flight (saves are refused then).
var pending_swap: bool = false

## Surface: "" | "state_unmapped" | "host_missing" | "scene_missing".
var last_error: String = ""

## GameManager state -> scene key.
const SCENE_MAP: Dictionary = {
	"TUTORIAL": "battlefield",
	"TRANSITION": "transition",
	"CHARACTER_CREATION": "creation",
	"SECT_SELECTION": "sect_select",
	"CULTIVATION": "cultivation",
	"MAP": "map",
	"ENDING": "ending",
}

## Scene key -> PackedScene path (all preloaded at startup — no cold file loads
## on swap, so the frame budget survives scene transitions).
const SCENE_PATHS: Dictionary = {
	"battlefield": "res://scenes/battlefield.tscn",
	"transition": "res://scenes/segments/transition.tscn",
	"creation": "res://scenes/segments/creation.tscn",
	"sect_select": "res://scenes/segments/sect_select.tscn",
	"cultivation": "res://scenes/segments/cultivation.tscn",
	"map": "res://scenes/segments/map.tscn",
	"ending": "res://scenes/segments/ending.tscn",
}

var _host: Node = null
var _current_node: Node = null
var _preloaded: Dictionary = {}


func _ready() -> void:
	for key in SCENE_PATHS.keys():
		_preloaded[key] = load(SCENE_PATHS[key] as String)
		if _preloaded[key] == null:
			last_error = "scene_missing"
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
	if not GameManager.retry_requested.is_connected(reload_battle):
		GameManager.retry_requested.connect(reload_battle)
	if not GameManager.restart_requested.is_connected(reload_battle):
		GameManager.restart_requested.connect(reload_battle)
	# Autoload _ready runs before Main enters the tree — resolve the host after
	# one deferred frame so the initial battlefield lands before tutorial step 1.
	await get_tree().process_frame
	_find_host()
	swap_to("battlefield")


func _on_state_changed(state: String) -> void:
	var key: Variant = SCENE_MAP.get(state, null)
	if key == null:
		last_error = "state_unmapped"
		return
	swap_to(key as String)


## Swap to a scene key; no-op when that scene is already hosted.
func swap_to(scene_key: String) -> void:
	if scene_key == current_scene:
		return
	if not SCENE_PATHS.has(scene_key):
		last_error = "scene_missing"
		return
	_do_swap(scene_key)


## Forced re-instantiation of the battlefield (LOST retry / restart_game).
## When a swap is already in flight it is necessarily producing a fresh
## battlefield (restart_game emits state_changed BEFORE restart_requested), so
## nothing more needs to happen.
func reload_battle() -> void:
	if pending_swap:
		return
	_do_swap("battlefield")


## The swap protocol: mark in-flight, toggle HUD visibility, drop every
## per-battle reference, free the outgoing scene and AWAIT its tree_exited
## (deferred add — the incoming scene never coexists with a freed one), then
## instantiate the preloaded incoming scene under the host. Battlefield is
## named "Battlefield" (playtest surface) and the tutorial wiring in
## battlefield.gd resolves HUD/Tutorial layers via root fallback.
func _do_swap(scene_key: String) -> void:
	if pending_swap:
		return
	pending_swap = true
	var next_is_battle: bool = scene_key == "battlefield"
	var hud: CanvasLayer = get_node_or_null("/root/Main/HUDLayer") as CanvasLayer
	if hud != null:
		hud.visible = next_is_battle
	if _current_node != null:
		_teardown_battle_refs()
		if is_instance_valid(_current_node):
			_current_node.queue_free()
			if _current_node.is_inside_tree():
				await _current_node.tree_exited
		_current_node = null
	var packed: PackedScene = _preloaded.get(scene_key, null)
	if packed == null:
		last_error = "scene_missing"
		pending_swap = false
		return
	if _host == null:
		_find_host()
	if _host == null:
		last_error = "host_missing"
		pending_swap = false
		return
	var inst: Node = packed.instantiate()
	if next_is_battle:
		inst.name = "Battlefield"
	_host.add_child(inst)
	_current_node = inst
	current_scene = scene_key
	last_error = ""
	pending_swap = false


## Drop every per-battle reference before freeing the outgoing scene: HUD
## battle refs, combat engine state, grid occupancy, GameManager refs/overlay.
## All four are no-op-safe on non-battle scenes (empty arrays / IDLE state).
func _teardown_battle_refs() -> void:
	var hud: CanvasLayer = get_node_or_null("/root/Main/HUDLayer") as CanvasLayer
	if hud != null:
		var hud_control: Node = hud.get_node_or_null("HUD")
		if hud_control != null and hud_control.has_method("clear_battle_refs"):
			hud_control.clear_battle_refs()
	CombatManager.reset_battle()
	GridManager.clear_grid()
	GameManager.clear_battle()


func _find_host() -> void:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null:
		last_error = "host_missing"
		return
	_host = main_node.get_node_or_null("SceneHost")
	if _host == null:
		last_error = "host_missing"
		return
