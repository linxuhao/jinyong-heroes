## SkillButton — A button representing a martial arts skill.
## Shows cooldown overlay (gray fill from top), hotkey label, and skill name.
extends Button

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when this skill button is pressed, passing its skill_index.
signal skill_selected(index: int)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The index of this skill in the player's skills array.
## Set by HUD when instantiating/arranging skill buttons.
var skill_index: int = -1

## Reference to the SkillData resource for this button.
var _skill_data: SkillData = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _cooldown_overlay: ColorRect = $CooldownOverlay
@onready var _hotkey_label: Label = $HotkeyLabel

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Configure this button with a skill and hotkey label.
## hotkey is a string like "1" or "2".
func setup(skill: SkillData, hotkey: String) -> void:
	_skill_data = skill

	if is_instance_valid(_hotkey_label):
		_hotkey_label.text = hotkey

	if skill != null:
		text = skill.skill_name
		tooltip_text = skill.description
	else:
		text = "Empty"
		tooltip_text = ""


## Update the cooldown overlay's visual state.
## remaining: seconds left on cooldown (0 = ready).
## total: total cooldown duration in seconds.
func update_cooldown(remaining: float, total: float) -> void:
	if not is_instance_valid(_cooldown_overlay):
		return

	var is_on_cooldown: bool = remaining > 0.0
	_cooldown_overlay.visible = is_on_cooldown
	disabled = is_on_cooldown

	if is_on_cooldown and total > 0.0:
		# The overlay covers from the top, shrinking downward as cooldown
		# progresses. anchor_bottom moves from 1.0 (full height) upward.
		var progress: float = remaining / total
		_cooldown_overlay.anchor_top = 0.0
		_cooldown_overlay.anchor_bottom = progress
		_cooldown_overlay.offset_bottom = 0.0

# ---------------------------------------------------------------------------
# Signal handling
# ---------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	skill_selected.emit(skill_index)
