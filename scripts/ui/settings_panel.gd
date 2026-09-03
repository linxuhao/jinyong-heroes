## SettingsPanel (step2_design C8 / task plan settings_panel_ui).
##
## The settings screen: five rows (音效音量 / 音乐音量 / 全屏 / 语言 / 返回),
## keyboard + mouse hybrid, mirroring the MenuPanel pattern. Single activation
## path: Button.pressed (mouse), ui_accept (keyboard) and the harness
## debug_click_settings_row action all converge on _activate_row(i).
##
## Keyboard adjust: move_up/move_down cycle focus_index (0..4); move_left /
## move_right step the focused row (volume rows +/-3 dB, 全屏/语言 toggle, 返回
## no-op); ui_accept activates the focused row (返回 ->
## GameManager.menu_close_settings()).
##
## Buttons use focus_mode = 0 so button-native ui_accept never fires — this
## panel's _unhandled_input is the single keyboard consumer, avoiding double
## activation and focus fights with GameManager's global listeners.
##
## All rendering reads SettingsManager.* mirrors ONLY — never AudioManager
## player state, never window state (headless has no window). Values are
## asserted on SettingsManager/AudioManager surface vars, not window state.
##
## NO boot-claim here: the panel only reacts to GameManager.current_state ==
## "SETTINGS". SceneManager routed us in via swap_to("settings") because
## GameManager emitted SETTINGS; the swap protocol already hid the HUD for a
## non-battle scene. This panel never claims the boot, never emits state,
## never touches the HUD.
extends Control

const ROW_COUNT: int = 5
const STEP_DB: float = 3.0

## R4 build stamp (review-mandated): a single constant so playtest reports can
## be matched to the exact build across the local and web exports. Display layer
## only — rendered by a programmatic Label in _ready() (settings_panel.tscn is
## frozen); it is NOT enumerated in _refresh_title_overlap, so it can never flip
## title_rows_overlap, and it sits outside the five option rows.
const BUILD_STAMP: String = "R4 · 2026-09-03"

## Surface: currently focused row index (0..4) — keyboard/debug activation
## target.
var focus_index: int = 0

## Surface: pressed_connected[i] is true when Button{i}'s pressed signal is
## wired to _activate_row(i). This is the ONLY observable proof of the middle
## of the mouse chain — debug_click_settings_row calls _activate_row directly
## and deliberately bypasses the signal link.
var pressed_connected: Array[bool] = []

## Surface: true when the Title label's GLOBAL rect intersects ANY option row
## (SettingsBox itself, or Button0..Button3), each rect inset 1px via grow(-1.0)
## so a shared edge is never an overlap. false = title disjoint from every option
## row. Recomputed on every _render() and every _process() frame.
var title_rows_overlap: bool = false


func _ready() -> void:
	# No boot-claim / HUD / state-emission code: the swap protocol already hid
	# the HUD and SceneManager hosted this panel under SegmentHost because
	# GameManager emitted SETTINGS. Wire the mouse path: every row's pressed
	# signal converges on the same _activate_row the keyboard and debug paths
	# use.
	for i in ROW_COUNT:
		(get_node("SettingsBox/Button%d" % i) as Button).pressed.connect(_activate_row.bind(i))
	# Snapshot the wiring AFTER connecting (before connect() it is empty).
	pressed_connected.clear()
	for i in ROW_COUNT:
		pressed_connected.append(
			(get_node("SettingsBox/Button%d" % i) as Button).get_signal_connection_list("pressed").size() > 0
		)
	# First render from the current SettingsManager mirrors (never cached).
	_render()
	# Build stamp (R4). Programmatic node — the scene is frozen — anchored
	# bottom-wide beneath the option box in the free viewport band, centred.
	# Deliberately kept out of _refresh_title_overlap's node list.
	var stamp := Label.new()
	stamp.name = "BuildStamp"
	stamp.text = tr("版本") + " " + BUILD_STAMP
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stamp.offset_top = -28.0
	stamp.offset_bottom = -8.0
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stamp)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.STATE_SETTINGS:
		return
	if event.is_action_pressed("move_up"):
		focus_index = (focus_index + ROW_COUNT - 1) % ROW_COUNT
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		focus_index = (focus_index + 1) % ROW_COUNT
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_adjust_focused(-1)
	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_adjust_focused(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate_row(focus_index)


func _process(_delta: float) -> void:
	# Fresh geometry truth at every asserted frame — cheap and unconditional so the
	# observable never reports a stale value (hud.gd _inset_overlap precedent: a
	# pair overlaps iff both rects intersect after a 1px grow(-1.0) inset).
	_refresh_title_overlap()
	# Harness-only actions (unbound empty-event lists in project.godot [input];
	# an absent action just returns false from is_action_just_pressed, never
	# crashes). debug_click_settings_row drives the SAME _activate_row the
	# buttons call, so a headless scenario proves the handler without coordinate
	# input. Guarded to SETTINGS so a stray press cannot fire mid-swap.
	# debug_reset_settings is executed by SettingsManager's autoload _process
	# (tree order runs autoloads first, so the reset already landed); this panel
	# only re-renders the fresh values afterwards.
	if GameManager.current_state == GameManager.STATE_SETTINGS and Input.is_action_just_pressed("debug_click_settings_row"):
		_activate_row(focus_index)
	if Input.is_action_just_pressed("debug_reset_settings"):
		_render()


## Keyboard/debug adjustment for the focused row: 0 sfx volume, 1 music volume,
## 2 fullscreen toggle, 3 language toggle, 4 返回 no-op.
func _adjust_focused(dir: int) -> void:
	match focus_index:
		0:
			_step_sfx(dir)
		1:
			_step_music(dir)
		2:
			SettingsManager.set_fullscreen(not SettingsManager.fullscreen)
			_render()
		3:
			_toggle_language()
		4:
			pass


## Single activation path: 0 sfx volume, 1 music volume, 2 fullscreen toggle,
## 3 language toggle, 4 back to the menu.
func _activate_row(i: int) -> void:
	match i:
		0:
			_step_sfx(1)
		1:
			_step_music(1)
		2:
			SettingsManager.set_fullscreen(not SettingsManager.fullscreen)
			_render()
		3:
			_toggle_language()
		4:
			GameManager.menu_close_settings()


## Flip zh <-> en. SettingsManager applies the locale live (auto-translated
## Controls re-render on the TranslationServer relocale) and persists it; the
## re-render below refreshes this panel's code-composed row texts.
func _toggle_language() -> void:
	SettingsManager.set_language("en" if SettingsManager.language == "zh" else "zh")
	_render()


## Step the SFX volume by dir * STEP_DB. Clamping to [-40.0, 6.0] is
## SettingsManager's job — each press computes from the current mirror, so
## repeated presses self-correct; no panel-side clamp needed.
func _step_sfx(dir: int) -> void:
	SettingsManager.set_sfx_volume_db(SettingsManager.sfx_volume_db + dir * STEP_DB)
	_render()


## Step the music volume by dir * STEP_DB (same clamp delegation as _step_sfx).
func _step_music(dir: int) -> void:
	SettingsManager.set_music_volume_db(SettingsManager.music_volume_db + dir * STEP_DB)
	_render()


## Render row texts from SettingsManager mirrors ONLY. dB text uses
## int(round(v)) so -10.0 renders "-10" deterministically (playtest-friendly).
## Composed texts go through tr() (format-string keys); the language row shows
## each language in its own script (中文 / English), never translated.
func _render() -> void:
	(get_node("SettingsBox/Button0") as Button).text = tr("音效音量: %d dB") % int(round(SettingsManager.sfx_volume_db))
	(get_node("SettingsBox/Button1") as Button).text = tr("音乐音量: %d dB") % int(round(SettingsManager.music_volume_db))
	(get_node("SettingsBox/Button2") as Button).text = tr("全屏: 开") if SettingsManager.fullscreen else tr("全屏: 关")
	(get_node("SettingsBox/Button3") as Button).text = tr("语言") + ": " + ("中文" if SettingsManager.language == "zh" else "English")
	(get_node("SettingsBox/Button4") as Button).text = "返回"
	_refresh_title_overlap()


## Recompute title_rows_overlap: true iff the Title label's global rect (inset
## 1px via grow(-1.0)) intersects the global rect (also inset 1px) of ANY of
## SettingsBox or Button0..Button3. Missing nodes are skipped and the last value
## is kept (defensive, matches hud.gd's get_node_or_null pattern).
func _refresh_title_overlap() -> void:
	var title := get_node_or_null("Title") as Control
	if title == null:
		return  # keep last value; node not yet in tree
	var tr: Rect2 = title.get_global_rect().grow(-1.0)
	for node_path in [
		"SettingsBox",
		"SettingsBox/Button0",
		"SettingsBox/Button1",
		"SettingsBox/Button2",
		"SettingsBox/Button3",
		"SettingsBox/Button4",
	]:
		var other := get_node_or_null(node_path) as Control
		if other == null:
			continue
		if tr.intersects(other.get_global_rect().grow(-1.0)):
			title_rows_overlap = true
			return
	title_rows_overlap = false
