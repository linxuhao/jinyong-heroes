## MenuPanel (step2_design C2 / task plan menu_panel_shell).
##
## The main-menu screen: four mouse-first entries (新的冒险 / 读取存档 / 设置 /
## 退出), keyboard navigation, and the boot-claim that makes menu.tscn the real
## entry point without touching the 27 legacy scenario boots.
##
## Boot-claim protocol: autoload _ready runs before the main scene enters the
## tree; this panel's _ready runs before the first process frame; SceneManager's
## _ready resumes on await process_frame after that. claim_boot() therefore
## always lands before SceneManager's deferred default battlefield swap, and
## enter_menu()'s state_changed emit reaches SceneManager whose swap_to("menu")
## no-ops because the claim already set current_scene.
##
## Single activation path: Button.pressed (mouse), ui_accept (keyboard) and the
## harness debug_click_menu_entry action all converge on _activate_entry(i).
## Buttons use focus_mode = 0 so keyboard ui_accept is handled ONLY here — no
## button-native press (double activation), no focus fights with the global
## WON/LOST listeners in GameManager.
##
## Load availability is FILE EXISTENCE (SaveManager.has_save_file(1)), never
## SaveManager.has_save — has_save is session-memory (set only by a successful
## save_slot() this session) and would wrongly disable 读取存档 on a fresh boot
## that already has a file on disk.
extends Control

const ENTRY_COUNT: int = 4

## Surface: currently focused entry index (0..3) — keyboard/debug activation
## target; rendered hint line; whether autosave slot 1 has a file on disk.
var focused_entry: int = 0
var hint_text: String = ""
var load_available: bool = false

## Surface: pressed_connected[i] is true when MenuEntry{i}'s pressed signal is
## wired to _activate_entry(i). This is the ONLY observable proof of the middle
## of the mouse chain — debug_click_menu_entry calls _activate_entry directly
## and deliberately bypasses the signal link, while mouse_filter/rect prove
## clickability but not the wiring.
var pressed_connected: Array[bool] = []


func _ready() -> void:
	# (1) Hide the HUD at boot. The swap protocol only toggles HUD visibility
	# when a swap runs, so a boot-claimed menu must hide it itself. Null-guarded
	# so a direct menu_panel.tscn boot (no /root/Main shell) is safe.
	var hud: CanvasLayer = get_node_or_null("/root/Main/HUDLayer") as CanvasLayer
	if hud != null:
		hud.visible = false
	# (2) Claim the boot before SceneManager's post-frame default battlefield
	# swap fires. No-op for main.tscn boots (the default swap already set
	# current_scene) and for direct menu_panel.tscn boots (no /root/Main shell).
	SceneManager.claim_boot(self, "menu")
	# (3) MENU state. The state_changed emit reaches SceneManager, whose
	# swap_to("menu") no-ops because the claim already set current_scene.
	GameManager.enter_menu()
	# (4) Wire the mouse path: every entry's pressed signal converges on the
	# same _activate_entry the keyboard and debug paths use.
	for i in ENTRY_COUNT:
		(get_node("MenuBox/MenuEntry%d" % i) as Button).pressed.connect(_activate_entry.bind(i))
	# (5) Snapshot the wiring AFTER connecting (before connect() it is empty).
	pressed_connected.clear()
	for i in ENTRY_COUNT:
		pressed_connected.append(
			(get_node("MenuBox/MenuEntry%d" % i) as Button).get_signal_connection_list("pressed").size() > 0
		)
	# (6) File-existence load availability, then (7) first render.
	_refresh_load_availability()
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != "MENU":
		return
	if event.is_action_pressed("move_up"):
		focused_entry = (focused_entry + ENTRY_COUNT - 1) % ENTRY_COUNT
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		focused_entry = (focused_entry + 1) % ENTRY_COUNT
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate_entry(focused_entry)


func _process(_delta: float) -> void:
	# Harness-only actions (unbound empty-event lists in project.godot [input];
	# an absent action just returns false from is_action_just_pressed, never
	# crashes). debug_click_menu_entry drives the SAME _activate_entry the
	# buttons call, so a headless scenario proves the handler without coordinate
	# input. Guarded to MENU so a stray press cannot fire mid-swap.
	if GameManager.current_state == "MENU" and Input.is_action_just_pressed("debug_click_menu_entry"):
		_activate_entry(focused_entry)
	# debug_seed_save / debug_delete_save are executed by GameManager's autoload
	# _process (tree order runs autoloads first, so the fixture already landed);
	# this panel only refreshes its availability surface afterwards — do not
	# re-implement the seed/delete here.
	if Input.is_action_just_pressed("debug_seed_save") or Input.is_action_just_pressed("debug_delete_save"):
		_refresh_load_availability()
		_render()


## Single activation path: 0 新的冒险, 1 读取存档, 2 设置, 3 退出.
func _activate_entry(i: int) -> void:
	match i:
		0:
			GameManager.menu_new_adventure()
		1:
			if not GameManager.menu_load_game():
				hint_text = _failure_hint()
				_render()
		2:
			GameManager.menu_open_settings()
		3:
			GameManager.menu_quit()


## Map SaveManager.last_error to a Chinese user-facing hint line.
func _failure_hint() -> String:
	match SaveManager.last_error:
		"no_save":
			return "没有找到存档"
		"bad_json", "bad_schema", "bad_version":
			return "存档已损坏，无法读取"
		_:
			return "读取失败"


## Load availability is FILE EXISTENCE on autosave slot 1 — never
## SaveManager.has_save (session-memory). A missing file clears any stale
## failure hint; an existing file clears the hint so the entry reads enabled.
func _refresh_load_availability() -> void:
	load_available = SaveManager.has_save_file(1)
	hint_text = "" if load_available else "没有找到存档"


## Render the hint line and the 读取存档 enablement. A failed load leaves
## load_available true, so the entry stays enabled for retry and only the hint
## reflects the failure.
func _render() -> void:
	(get_node("HintLabel") as Label).text = hint_text
	(get_node("MenuBox/MenuEntry1") as Button).disabled = not load_available
