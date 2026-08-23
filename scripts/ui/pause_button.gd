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

## Toggle pause/unpause via CombatManager.
func _on_toggle_pause() -> void:
	CombatManager.toggle_pause()


## Update button text when paused.
func _on_paused() -> void:
	text = "继续"


## Update button text when unpaused.
func _on_unpaused() -> void:
	text = "暂停"
