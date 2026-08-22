## SkillButton — A button representing a martial arts skill.
## Shows the technique name, a hotkey label, a fa hui du label
## (ERRATIC / NORMAL / OVERDRIVE + multiplier), and a round-based cooldown
## overlay (gray fill from top). `disabled` is computed every frame by the
## HUD (phase lock / cooldown / HP gate) — never written here.
extends Button

const SkillData = preload("res://scripts/data/skill_data.gd")

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

## Observable fa hui du label text, e.g. "OVERDRIVE x1.3"
## (English + digits only).
var fahui_text: String = ""

## Pure HP-gate predicate (Seventeen Forms only): true when this button is
## skill index 7 and the player's current HP is >= 50% of max health. Written
## EVERY frame by the HUD (_refresh_skill_button_states); never assigned here.
## Independent of phase lock / cooldown — observable for the playtest surface.
var hp_gated: bool = false

## Reference to the SkillData resource for this button.
var _skill_data = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _cooldown_overlay: ColorRect = $CooldownOverlay
@onready var _hotkey_label: Label = $HotkeyLabel
@onready var _fahui_label: Label = $FahuiLabel

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Configure this button with a skill, a hotkey label, and the fa hui du
## multiplier of the external art that produced the skill.
## hotkey is a string like "1".."8". fa_hui_du drives the FahuiLabel text:
##   < 1.0    -> "ERRATIC x<fhd>"
##   1.0..1.2 -> "NORMAL x<fhd>"
##   > 1.2    -> "OVERDRIVE x<fhd>"
## The multiplier is formatted to one decimal place (English + digits only).
## Child labels are resolved defensively via get_node_or_null (health_bar.gd
## pattern) so setup() is call-order independent.
func setup(skill, hotkey: String, fa_hui_du: float) -> void:
	_skill_data = skill

	var hotkey_label: Label = _hotkey_label
	if hotkey_label == null:
		hotkey_label = get_node_or_null("HotkeyLabel") as Label
		if hotkey_label != null:
			_hotkey_label = hotkey_label
	if hotkey_label != null:
		hotkey_label.text = hotkey

	var fhd: float = fa_hui_du
	if fhd < 1.0:
		fahui_text = "ERRATIC x%.1f" % fhd
	elif fhd <= 1.2:
		fahui_text = "NORMAL x%.1f" % fhd
	else:
		fahui_text = "OVERDRIVE x%.1f" % fhd

	var fahui_label: Label = _fahui_label
	if fahui_label == null:
		fahui_label = get_node_or_null("FahuiLabel") as Label
		if fahui_label != null:
			_fahui_label = fahui_label
	if fahui_label != null:
		fahui_label.text = fahui_text

	if skill != null:
		text = skill.skill_name
		tooltip_text = skill.description
	else:
		text = "Empty"
		tooltip_text = ""


## Update the cooldown overlay's visual state.
## remaining: rounds left on cooldown (0 = ready).
## total: the skill's total cooldown in rounds.
## The overlay is a fraction-of-rounds fill (not seconds). `disabled` is
## intentionally NOT touched here — the HUD recomputes it every frame from
## phase lock / cooldown / HP gate.
func update_cooldown(remaining: int, total: int) -> void:
	var overlay: ColorRect = _cooldown_overlay
	if overlay == null:
		overlay = get_node_or_null("CooldownOverlay") as ColorRect
		if overlay != null:
			_cooldown_overlay = overlay
	if overlay == null:
		return

	var is_on_cooldown: bool = remaining > 0 and total > 0
	overlay.visible = is_on_cooldown

	if is_on_cooldown:
		# The overlay covers from the top, shrinking downward as the cooldown
		# counts down. anchor_bottom moves from 1.0 (full height) upward.
		var progress: float = float(remaining) / float(total)
		overlay.anchor_top = 0.0
		overlay.anchor_bottom = progress
		overlay.offset_top = 0.0
		overlay.offset_bottom = 0.0

# ---------------------------------------------------------------------------
# Signal handling
# ---------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	skill_selected.emit(skill_index)
