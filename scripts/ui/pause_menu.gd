## PauseMenu — R5 battle pause menu (continuation of pause_button's pause).
##
## Shown when a toggle lands PAUSED (see pause_button.gd `_on_paused`), closed
## again on unpause. Two children:
##   PauseContinueButton  — 继续: a second CombatManager.toggle_pause() (the net
##     effect of today's second press on the pause button); the menu closes via
##     the same `unpaused` signal relay in pause_button.gd. is_paused semantics
##     stay owned by the existing pins — this menu NEVER writes combat state.
##   PauseMainMenuButton — 返回主菜单: TWO-PRESS ARM. First press only sets
##     `confirm_armed = true` + shows the warning line (zero writes, zero RNG);
##     the confirming press routes through the probe's VERDICT_A public route
##     `GameManager.enter_menu()` (no guard; lands `current_state == "MENU"`
##     → menu_panel.tscn). The copy 本局进度将丢失 is honest: enter_menu
##     abandons the in-progress battle (the save itself is untouched).
##
## KEYBOARD-TRANSPARENT by design: buttons use focus_mode = 0 and this script
## installs NO _unhandled_input — appending to hud.gd's roster shield would
## couple two rounds. Close is via the buttons only.
##
## Presentation only: no autosave, no profile write, no combat-state write.
extends Control

## Two-press arm state for 返回主菜单 (mirrored onto Hud.pause_menu_armed).
var confirm_armed: bool = false


func _ready() -> void:
	var cb: Button = get_node_or_null("PauseContinueButton") as Button
	if cb != null:
		cb.pressed.connect(_on_continue_pressed)
	var mb: Button = get_node_or_null("PauseMainMenuButton") as Button
	if mb != null:
		mb.pressed.connect(_on_main_menu_pressed)
	_set_status("")


## Open the menu and clear any stale arm. Zero combat-state writes.
func open_menu() -> void:
	confirm_armed = false
	_set_status("")
	visible = true


## Close the menu (also invoked from pause_button's `_on_unpaused` relay —
## the Continue button's toggle lands unpaused and closes it through there).
func close_menu() -> void:
	confirm_armed = false
	visible = false


## 继续 — the same public toggle the pause button's second press makes.
func _on_continue_pressed() -> void:
	CombatManager.toggle_pause()


## 返回主菜单 — first press arms only; second press routes via enter_menu().
func _on_main_menu_pressed() -> void:
	if not confirm_armed:
		confirm_armed = true
		_set_status(tr("⚠ 再按一次确认返回主菜单，本局进度将丢失"))
		return
	confirm_armed = false
	_set_status("")
	# VERDICT_A (probe): GameManager.enter_menu() — public, guard-free, lands
	# current_state == "MENU" (→ menu_panel.tscn). restart_game() would land
	# TUTORIAL (semantic mismatch with 返回主菜单) — deliberately not used.
	GameManager.enter_menu()


func _set_status(text: String) -> void:
	var label: Label = get_node_or_null("PauseStatus") as Label
	if label != null:
		label.text = text
