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

## Observable four-state button state, written EVERY frame by the HUD
## (_refresh_skill_button_states): "ready" | "cooldown" | "phase_locked" |
## "hp_gated". Never assigned here — this script only renders from it.
var state_text: String = ""

## Observable remaining cooldown rounds (0 = ready), written every frame by
## the HUD; drives the CooldownLabel number shown over the cooldown overlay.
var cooldown_remaining: int = 0

## Observable: whether the CooldownOverlay is currently visible. Synced to
## overlay.visible on every update_cooldown() call; readable by the playtest
## surface as SkillButtonN.overlay_visible.
var overlay_visible: bool = false

## Observable selection flag: true when the player's currently selected skill
## is this button (player.selected_skill_index == skill_index). Written every
## frame by the HUD; drives the golden selected border (已选中 state).
var selected: bool = false

## Reference to the SkillData resource for this button.
var _skill_data = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _cooldown_overlay: ColorRect = $CooldownOverlay
@onready var _hotkey_label: Label = $HotkeyLabel
@onready var _fahui_label: Label = $FahuiLabel
@onready var _cooldown_label: Label = $CooldownLabel
@onready var _state_tag: Label = $StateTag

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
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
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
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		fahui_label = get_node_or_null("FahuiLabel") as Label
		if fahui_label != null:
			_fahui_label = fahui_label
	if fahui_label != null:
		fahui_label.text = fahui_text

	if skill != null:
		# Button text never clips in Godot (Button has no clip_text) — a
		# too-long name paints over the neighbor instead. The short display-name
		# set (<= ~12 chars, fixed in battlefield.gd _create_all_skill_data) is
		# the guard; if a future name exceeds that, shorten the NAME — never an
		# ellipsis (no-ellipsis sweep, design/30_presentation.md).
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
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		overlay = get_node_or_null("CooldownOverlay") as ColorRect
		if overlay != null:
			_cooldown_overlay = overlay
	if overlay == null:
		return

	# Visibility is decided by remaining > 0 alone: a cooling skill whose total
	# is missing / zero must still show a full overlay (previously the
	# `remaining > 0 and total > 0` condition hid it entirely).
	var show: bool = remaining > 0
	overlay.visible = show
	overlay_visible = show

	# Fraction-of-rounds fill from the top (anchor_bottom moves from 1.0 down);
	# fall back to a full overlay when the total is missing / zero so we never
	# divide by zero (GDScript would otherwise produce inf).
	var fraction: float = 1.0 if total <= 0 else float(remaining) / float(total)
	overlay.anchor_top = 0.0
	overlay.anchor_bottom = fraction
	overlay.offset_top = 0.0
	overlay.offset_bottom = 0.0

	if not show:
		# Cooldown ended: reset the anchors to the full rect so a later
		# cooldown never starts from a stale partial fill.
		overlay.anchor_bottom = 1.0


## Apply the four-state visual presentation for this button. The state data
## (state_text / cooldown_remaining / selected) is derived and written EVERY
## frame by the HUD; this function only turns that data into visuals. The four
## states are pairwise distinguishable (design/30_presentation.md item 2):
##   ready        -> default style, full modulate, no tag, no number
##   cooldown     -> slight desaturation + remaining-rounds NUMBER over the
##                   existing dark top-fill overlay (the overlay itself is
##                   driven by update_cooldown, untouched here)
##   phase_locked -> gray tint + "LOCKED" tag
##   hp_gated     -> red tint + "HP" tag
## The golden selected border (已选中) is layered on top of any state and never
## changes state_text.
func _apply_state(state: String) -> void:
	# Ready: default appearance, full modulate.
	if state == "ready":
		modulate = Color(1, 1, 1, 1)
		if _cooldown_label != null:
			_cooldown_label.visible = false
		if _state_tag != null:
			_state_tag.text = ""
	# Cooldown: slight desaturation + remaining-rounds number over the overlay.
	elif state == "cooldown":
		modulate = Color(0.78, 0.78, 0.82, 1.0)
		if _cooldown_label != null:
			_cooldown_label.visible = true
			_cooldown_label.text = str(cooldown_remaining)
		if _state_tag != null:
			_state_tag.text = ""
	# Phase lock (palm arts locked before round 4): gray tint + LOCKED tag.
	elif state == "phase_locked":
		modulate = Color(0.55, 0.55, 0.6)
		if _state_tag != null:
			_state_tag.text = "LOCKED"
		if _cooldown_label != null:
			_cooldown_label.visible = false
	# HP gate (Seventeen Forms above 50% max health): red tint + HP tag.
	elif state == "hp_gated":
		modulate = Color(0.85, 0.4, 0.4)
		if _state_tag != null:
			_state_tag.text = "HP"
		if _cooldown_label != null:
			_cooldown_label.visible = false

	# Selected overlay: bright golden border via a "normal" StyleBoxFlat
	# override, layered on top of the four states (a selected button is never
	# disabled, so "normal" is the rendered stylebox).
	if selected:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.22, 0.26, 1.0)
		sb.border_color = Color(1.0, 0.84, 0.0, 1.0)
		sb.set_border_width_all(2)
		add_theme_stylebox_override("normal", sb)
	else:
		remove_theme_stylebox_override("normal")

# ---------------------------------------------------------------------------
# Signal handling
# ---------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	skill_selected.emit(skill_index)
