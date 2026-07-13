## PauseButton — Toggle button for real-time-with-pause combat.
## Syncs its text and state with CombatManager's pause state.
extends Button

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_toggle_pause)

	# Sync initial text with CombatManager state.
	if CombatManager.is_paused:
		text = "▶ Unpause"
	else:
		text = "⏸ Pause"

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

## Toggle pause/unpause via CombatManager.
func _on_toggle_pause() -> void:
	CombatManager.toggle_pause()


## Update button text when paused.
func _on_paused() -> void:
	text = "▶ Unpause"


## Update button text when unpaused.
func _on_unpaused() -> void:
	text = "⏸ Pause"
