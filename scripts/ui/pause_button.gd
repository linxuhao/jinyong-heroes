## PauseButton — Toggle button for real-time-with-pause combat.
## Syncs its text and state with CombatManager's pause state.
extends Button

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_toggle_pause)

	# Sync initial text with CombatManager state. Plain CJK labels only — the
	# U+23F8 (pause) and U+25B6 (play) symbols are NOT covered by
	# NotoSansSC-Regular.otf (tofu risk), and no assertion reads this text.
	if CombatManager.is_paused:
		text = "继续"
	else:
		text = "暂停"

	# Connect to CombatManager signals for state changes.
	if CombatManager.paused.is_connected(_on_paused):
		CombatManager.paused.disconnect(_on_paused)
	CombatManager.paused.connect(_on_paused)

	if CombatManager.unpaused.is_connected(_on_unpaused):
		CombatManager.unpaused.disconnect(_on_unpaused)
	CombatManager.unpaused.connect(_on_unpaused)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Toggle pause/unpause via CombatManager. (Contract unchanged.)
func _on_toggle_pause() -> void:
	CombatManager.toggle_pause()


## Update button text when paused. ONE R5 addition: opening the pause menu.
## The menu is resolved FRESH each call (`../PauseMenu` — PauseButton is a
## direct child of the HUD root, where the sibling PauseMenu node lives), so
## the two files cannot disagree on the path. open_menu() writes zero combat
## state — is_paused semantics stay owned by toggle_pause().
func _on_paused() -> void:
	text = "继续"
	var menu: Control = get_node_or_null("../PauseMenu") as Control
	if menu != null and menu.has_method("open_menu"):
		menu.open_menu()


## Update button text when unpaused. R5: close the pause menu (the Continue
## button's second toggle lands here — net effect identical to today's second
## press, and is_paused is still written only by toggle_pause()).
func _on_unpaused() -> void:
	text = "暂停"
	var menu: Control = get_node_or_null("../PauseMenu") as Control
	if menu != null and menu.has_method("close_menu"):
		menu.close_menu()


