## SkillButton — A button representing a martial arts skill.
## Shows the technique name, a hotkey label, a fa hui du label
## (失常 / 正常 / 超常 + multiplier), and a round-based cooldown
## overlay (gray fill from top). `disabled` is computed every frame by the
## HUD (phase lock / cooldown / HP gate) — never written here.
extends Button

const SkillData = preload("res://scripts/data/skill_data.gd")

## Gold border color applied to the selected button's stylebox(es).
const SELECTED_BORDER_COLOR := Color(1.0, 0.84, 0.0, 1.0)

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

## Observable fa hui du label text, e.g. "超常 ×1.3" (Chinese band + digits).
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

## Observable: rendered StateTag text ("" | "锁定" | "气血"). Written by
## _apply_state; never assigned elsewhere.
var state_tag_text: String = ""

## Observable: rendered CooldownLabel text ("" when not on cooldown).
## Written by _apply_state's cooldown branch: str(cooldown_remaining).
var cooldown_label_text: String = ""

## Reference to the SkillData resource for this button.
var _skill_data = null

## Cached per-state StyleBoxFlat instances (one per state), keyed by state
## string. _apply_state runs EVERY frame for 8 buttons, so the boxes are
## allocated once per state and only border_color mutates in place (selected
## flips) — never StyleBoxFlat.new() per frame per button.
var _state_styleboxes: Dictionary = {}

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

## Band label for a fa hui du multiplier (display only, pure function): values
## < 1.0 render 失常, 1.0..1.2 render 正常, > 1.2 render 超常, each followed by
## the multiplier to one decimal place (e.g. "超常 ×1.3"). Static so unit tests
## can exercise it without instantiating a scene.
static func fa_hui_du_label(fhd: float) -> String:
	if fhd < 1.0:
		return "失常 ×%.1f" % fhd
	elif fhd <= 1.2:
		return "正常 ×%.1f" % fhd
	return "超常 ×%.1f" % fhd

## Configure this button with a skill, a hotkey label, and the fa hui du
## multiplier of the external art that produced the skill.
## hotkey is a string like "1".."8". fa_hui_du drives the FahuiLabel text via
## the static fa_hui_du_label() band helper:
##   < 1.0    -> "失常 ×<fhd>"
##   1.0..1.2 -> "正常 ×<fhd>"
##   > 1.2    -> "超常 ×<fhd>"
## The multiplier is formatted to one decimal place (Chinese + digits).
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
	fahui_text = fa_hui_du_label(fhd)

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


## Pure per-state palette for the four skill-button states (testable without
## a scene). Returns a Dictionary:
##   { "bg_color": Color, "border_color": Color, "border_width": int,
##     "tag_text": String }
## Contract values (design/30_presentation.md item 2 — pairwise distinct):
##   ready:        bg (0.20,0.24,0.30) border (0.35,0.40,0.48) w1 tag ""
##   cooldown:     bg (0.16,0.16,0.20) border (0.42,0.42,0.46) w1 tag ""
##   phase_locked: bg (0.32,0.32,0.34) border (0.55,0.55,0.58) w2 tag "锁定"
##   hp_gated:     bg (0.40,0.12,0.12) border (0.75,0.25,0.25) w2 tag "气血"
## Unknown state -> ready palette.
static func state_palette(state: String) -> Dictionary:
	match state:
		"cooldown":
			return {
				"bg_color": Color(0.16, 0.16, 0.20),
				"border_color": Color(0.42, 0.42, 0.46),
				"border_width": 1,
				"tag_text": "",
			}
		"phase_locked":
			return {
				"bg_color": Color(0.32, 0.32, 0.34),
				"border_color": Color(0.55, 0.55, 0.58),
				"border_width": 2,
				"tag_text": "锁定",
			}
		"hp_gated":
			return {
				"bg_color": Color(0.40, 0.12, 0.12),
				"border_color": Color(0.75, 0.25, 0.25),
				"border_width": 2,
				"tag_text": "气血",
			}
		_:
			return {
				"bg_color": Color(0.20, 0.24, 0.30),
				"border_color": Color(0.35, 0.40, 0.48),
				"border_width": 1,
				"tag_text": "",
			}


## Cached StyleBoxFlat for a state — allocated once per state, never per frame
## per button. border_color is mutated in place when `selected` flips; nothing
## else changes after creation.
func _stylebox_for(state: String) -> StyleBoxFlat:
	if _state_styleboxes.has(state):
		return _state_styleboxes[state]
	var palette: Dictionary = state_palette(state)
	var sb := StyleBoxFlat.new()
	sb.bg_color = palette["bg_color"]
	sb.border_color = palette["border_color"]
	sb.set_border_width_all(int(palette["border_width"]))
	sb.set_corner_radius_all(3)
	_state_styleboxes[state] = sb
	return sb


## Apply the four-state visual presentation for this button. The state data
## (state_text / cooldown_remaining / selected) is derived and written EVERY
## frame by the HUD; this function only turns that data into visuals. The four
## states are pairwise distinguishable (design/30_presentation.md item 2):
##   ready        -> neutral blue-gray fill, thin border, no tag, no number
##   cooldown     -> dark desaturated fill + remaining-rounds NUMBER over the
##                   existing dark top-fill overlay (the overlay itself is
##                   driven by update_cooldown, untouched here)
##   phase_locked -> light gray fill + 2px border + 锁定 tag
##   hp_gated     -> dark red fill + 2px red border + 气血 tag
## The golden selected border (已选中) is layered on top of any state and never
## changes state_text. `modulate` is NOT used (theme stylebox overrides
## restyle the button) and `disabled` is never touched (HUD-owned).
func _apply_state(state: String) -> void:
	var palette: Dictionary = state_palette(state)

	# Per-state StyleBoxFlat override applied to BOTH "normal" and "disabled":
	# a disabled button (cooldown / phase_locked / hp_gated) renders the
	# "disabled" stylebox, so the state styling must shadow both, or the flat
	# default-theme gray wins. The cached box is shared; only border_color
	# mutates (gold when selected, palette border otherwise).
	var sb: StyleBoxFlat = _stylebox_for(state)
	sb.border_color = SELECTED_BORDER_COLOR if selected else palette["border_color"]
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("disabled", sb)

	# Light text on every state's dark background — including the disabled
	# font color, which a locked/cooling button would otherwise render in the
	# theme's low-contrast gray.
	var text_color := Color(0.92, 0.92, 0.92, 1.0)
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_disabled_color", text_color)
	add_theme_color_override("font_hover_color", text_color)
	add_theme_color_override("font_pressed_color", text_color)
	add_theme_color_override("font_focus_color", text_color)

	# Chinese state tag (界面文字一律中文): 锁定 / 气血, "" for ready/cooldown.
	state_tag_text = palette["tag_text"]
	var state_tag: Label = _state_tag
	if state_tag == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		state_tag = get_node_or_null("StateTag") as Label
		if state_tag != null:
			_state_tag = state_tag
	if state_tag != null:
		state_tag.text = state_tag_text

	# Cooldown: big remaining-rounds number over the overlay. Ready and the
	# locked states hide the number (the HUD's phase_locked > cooldown
	# priority means a locked button never needs the number visible).
	if state == "cooldown":
		cooldown_label_text = str(cooldown_remaining)
		var cooldown_label: Label = _cooldown_label
		if cooldown_label == null:
			# Safe: get_node_or_null re-resolves the path each call; null for
			# freed nodes — never a freed-object cast.
			cooldown_label = get_node_or_null("CooldownLabel") as Label
			if cooldown_label != null:
				_cooldown_label = cooldown_label
		if cooldown_label != null:
			cooldown_label.visible = true
			cooldown_label.text = cooldown_label_text
	else:
		cooldown_label_text = ""
		var cooldown_label: Label = _cooldown_label
		if cooldown_label == null:
			# Safe: get_node_or_null re-resolves the path each call; null for
			# freed nodes — never a freed-object cast.
			cooldown_label = get_node_or_null("CooldownLabel") as Label
			if cooldown_label != null:
				_cooldown_label = cooldown_label
		if cooldown_label != null:
			cooldown_label.visible = false

# ---------------------------------------------------------------------------
# Signal handling
# ---------------------------------------------------------------------------

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	skill_selected.emit(skill_index)
