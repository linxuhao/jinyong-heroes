## HUD — Main UI layer containing floating health bars, the round indicator,
## the energy label, the up-to-12 programmatic skill buttons (fa hui du labels +
## round-based cooldown overlays; two rows × 6 when the player owns more than 8
## skills, one row otherwise), and the pause button. Lives on CanvasLayer
## layer 10. Button `disabled` state is recomputed every frame from combat +
## player state (phase lock / cooldown / HP gate).
extends Control

const SkillData = preload("res://scripts/data/skill_data.gd")

## Display aliases for health-bar name labels: Chinese display names
## (design §2.1 — every rendered string ships in Chinese; the names are short
## enough to fit the 64 px label with no ellipsis).
## Only the health-bar display layer is affected — character_data.character_name,
## node names, turn-order names and order_names stay canonical and unchanged.
const _DISPLAY_ALIASES := {
	"Yang Guo": "杨过",
	"East Heretic": "黄药师",
	"West Poison": "欧阳锋",
	"South Emperor": "段智兴",
	"North Beggar": "洪七公",
	"Central Divine": "王重阳",
}

## Default text of the skill description label — shown whenever no skill is
## selected, so the "no introduction in battle" gap is closed even before any
## selection (the label is always visible on the HUD). Must stay in sync with
## the initial `text` authored on SkillDescLabel in hud.tscn.
const _DEFAULT_SKILL_DESC_TEXT: String = "点击招式按钮,查看招式说明"

## Map a canonical character name to its short display alias; unknown names
## are returned unchanged (fallback names like "Player"/"Enemy" unaffected).
func _alias_for(name: String) -> String:
	return _DISPLAY_ALIASES.get(name, name)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Array of instantiated HealthBar Controls, one per character.
var _health_bars: Array[Control] = []

## Geometric observables (playtest surface). Computed every `_process` frame
## BEFORE the player null-check so they are readable pre-battle too. Both
## widgets live on the same HUD canvas layer, so their get_global_rect()s
## share one coordinate system (scale-1 viewport: HUD coords == pixels).
var round_pause_overlap: bool = false
var skill8_right_edge: float = 0.0
## Row-2 right edge x of the two-row skill bar layout (skills > 8); 0.0 in the
## single-row (<= 8 skills) mode. Surface observable, updated every frame.
var skill12_right_edge: float = 0.0

## Preloaded health_bar scene for instantiation.
var _health_bar_scene: PackedScene = preload("res://scenes/ui/health_bar.tscn")

## Preloaded skill_button scene for instantiation.
var _skill_button_scene: PackedScene = preload("res://scenes/ui/skill_button.tscn")

## Player reference whose action_hint signal is wired to the hint label, for
## teardown in clear_battle_refs(). Null when no battle is set up.
var _action_hint_player: Node = null

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _health_bar_container: Control = $HealthBarContainer
@onready var _skill_bar: VBoxContainer = $SkillBar
@onready var _skill_row_1: HBoxContainer = $SkillBar/SkillRow1
@onready var _skill_row_2: HBoxContainer = $SkillBar/SkillRow2
@onready var _pause_button: Button = $PauseButton
@onready var _round_indicator: Control = $RoundIndicator
@onready var _energy_label: Label = $EnergyLabel
@onready var _action_hint_label: Label = $ActionHintLabel
@onready var _skill_desc_label: Label = $SkillDescLabel

## Resolve a skill button by its deterministic name (SkillButton1..SkillButton12).
## Buttons live under SkillRow1/SkillRow2 in the two-row layout, so resolve
## recursively (find_child searches the whole subtree). Safe by construction:
## find_child returns null for freed/absent nodes — never a stored freed-object
## cast. Do NOT cache buttons in a typed array (typed arrays validate on write).
func _skill_button(n: String) -> Control:
	return _skill_bar.find_child(n, true, false) as Control

## Recompute the two HUD geometric observables every frame:
##   - round_pause_overlap: RoundIndicator rect vs PauseButton rect (false
##     when either widget is unresolvable, e.g. pre-setup);
##   - skill8_right_edge: SkillButton8's right edge x (keeps last value / 0.0
##     when the button does not exist yet).
## Both rects come from get_global_rect() in the HUD's own coordinate space.
func _update_geometry_observables() -> void:
	var indicator: Control = _round_indicator
	if indicator == null or not is_instance_valid(indicator):
		indicator = get_node_or_null("RoundIndicator") as Control
		if indicator != null:
			_round_indicator = indicator
	var pause: Button = _pause_button
	if pause == null or not is_instance_valid(pause):
		pause = get_node_or_null("PauseButton") as Button
		if pause != null:
			_pause_button = pause
	if indicator != null and pause != null:
		round_pause_overlap = indicator.get_global_rect().intersects(
			pause.get_global_rect())

	var button8: Control = _skill_button("SkillButton8")
	if button8 != null:
		skill8_right_edge = button8.get_global_rect().end.x

	var button12: Control = _skill_button("SkillButton12")
	if button12 != null and button12.visible:
		skill12_right_edge = button12.get_global_rect().end.x

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Set up the HUD: create health bars for the player and all enemies,
## populate skill buttons, and wire signals.
## Called by battlefield.gd after characters are placed.
func setup(player: Node, enemies: Array[Node]) -> void:
	_health_bars.clear()

	# --- Player health bar ---
	var player_name: String = "Player"
	if "character_data" in player and player.character_data != null:
		player_name = player.character_data.character_name
	_create_health_bar(player, _alias_for(player_name))

	# --- Enemy health bars ---
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var char_name: String = "Enemy"
		if "character_data" in enemy and enemy.character_data != null:
			char_name = enemy.character_data.character_name
		elif "name" in enemy:
			char_name = enemy.name
		_create_health_bar(enemy, _alias_for(char_name))

	# --- Skill buttons ---
	_populate_skill_buttons(player)

	# --- Pause button ---
	# pause_button.gd handles its own wiring via _ready().

	# --- Energy label (display only; no technique costs this run) ---
	var energy_label: Label = _energy_label
	if energy_label == null:
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		energy_label = get_node_or_null("EnergyLabel") as Label
		if energy_label != null:
			_energy_label = energy_label
	if energy_label != null:
		var qi: int = int(player.energy) if "energy" in player else 0
		energy_label.text = "内力: %d" % qi

	# Wire the player's action_hint signal to the hint line (idempotent:
	# disconnects any stale connection first, so repeated setup() calls are safe).
	_wire_action_hint(player)

	# Skill description label: start every battle from the default guidance
	# (nothing is selected yet).
	_refresh_skill_desc_text()


## Battle-exit cleanup: drop every per-battle reference so a scene swap never
## touches freed nodes. Frees the floating health bars (they hold the
## soon-to-be-freed character refs — follow_character() already guards with
## is_instance_valid, but the bars must not linger into the next battle) and
## clears the skill buttons (re-populated from scratch on the next setup()).
func clear_battle_refs() -> void:
	# Clear the hint line and drop the action_hint connection so a scene swap
	# never leaves the old battle's hint text (or a freed player ref) behind.
	hide_hint()
	# Reset the skill description label to the default guidance. The player ref
	# may already be freed at this point — the refresh guards with
	# is_instance_valid and falls back to the default text.
	_refresh_skill_desc_text()
	if _action_hint_player != null and is_instance_valid(_action_hint_player):
		if _action_hint_player.has_signal("action_hint") \
				and _action_hint_player.action_hint.is_connected(_on_action_hint):
			_action_hint_player.action_hint.disconnect(_on_action_hint)
	_action_hint_player = null

	for bar in _health_bars:
		if is_instance_valid(bar):
			bar.queue_free()
	_health_bars.clear()
	if _skill_bar != null and is_instance_valid(_skill_bar):
		# Buttons live under SkillRow1/SkillRow2 — clear BOTH rows so no button
		# survives a battle exit.
		for row in [_skill_row_1, _skill_row_2]:
			if row == null or not is_instance_valid(row):
				continue
			for child in row.get_children():
				row.remove_child(child)
				child.queue_free()


## Create a single health bar for a character and add it to the container.
func _create_health_bar(character: Node, display_name: String) -> void:
	if not is_instance_valid(_health_bar_scene):
		return

	# Safe: fresh instantiate() output — never a freed reference.
	var bar: Control = _health_bar_scene.instantiate() as Control
	if bar == null:
		return

	if not bar.has_method("setup"):
		return

	var max_hp: int = 100
	if "max_health" in character:
		max_hp = character.max_health

	# Add the bar to the tree BEFORE setup() so health_bar.gd's @onready
	# refs ($Bar / $NameLabel) are live inside setup().
	_health_bar_container.add_child(bar)
	bar.setup(display_name, max_hp, character)
	_health_bars.append(bar)


## Populate skill buttons from the player's skills array. Always instantiates
## exactly 12 SkillButton nodes with deterministic names SkillButton1..12 (named
## BEFORE add_child to avoid duplicate-name errors); buttons beyond the player's
## skill count are created but hidden (never fewer than 12) so the playtest
## surface can read SkillButton9..12.visible in every mode. Hidden children are
## excluded from BoxContainer layout, so the 8-button tutorial geometry stays
## byte-identical. Layout: skills.size() <= 8 → every node (visible buttons +
## hidden placeholders) goes in SkillRow1 and SkillRow2 stays empty; > 8 → two
## rows × 6 (SkillButton1..6 in SkillRow1, SkillButton7..12 in SkillRow2).
## Hotkey = index + 1. fa_hui_du comes from the real cascade
## (_external_fhd_for_skill; falls back to DEFAULT_FA_HUI_DU 1.3 when the skill
## has no matching art, so every tutorial button still shows "发挥 ×1.3").
func _populate_skill_buttons(player: Node) -> void:
	var skills: Array = []
	if "skills" in player:
		skills = player.skills
	var n: int = skills.size()

	# Clear any existing button children first (idempotent re-population).
	for row in [_skill_row_1, _skill_row_2]:
		if row == null or not is_instance_valid(row):
			continue
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()

	# Single-row mode: ALL 12 nodes in SkillRow1 (hidden ones occupy no layout
	# space). Two-row mode: split 1-6 → row1, 7-12 → row2.
	var use_two_rows: bool = n > 8

	for i in range(12):
		# Safe: fresh instantiate() output — never a freed reference.
		var inst: Button = _skill_button_scene.instantiate() as Button
		if inst == null:
			continue
		inst.name = "SkillButton%d" % (i + 1)

		var row: HBoxContainer = _skill_row_2 if use_two_rows and i >= 6 else _skill_row_1
		if row == null or not is_instance_valid(row):
			continue
		row.add_child(inst)

		if i >= n:
			# No skill for this slot — hidden placeholder (surface-stable).
			inst.visible = false
			continue

		var skill = skills[i]
		if skill == null:
			inst.visible = false
			continue

		if inst.has_method("setup"):
			inst.setup(skill, str(i + 1), CombatManager._external_fhd_for_skill(player, skill))

		# Store the skill index.
		inst.skill_index = i

		# Connect the skill_selected signal.
		if inst.has_signal("skill_selected"):
			if inst.skill_selected.is_connected(_on_skill_selected):
				inst.skill_selected.disconnect(_on_skill_selected)
			inst.skill_selected.connect(_on_skill_selected)

	# Wire player cooldown updates to skill buttons.
	_wire_cooldown_updates(player)


## Connect to the player's cooldown update mechanism.
## If the player emits a "cooldowns_updated" signal, update the skill buttons.
func _wire_cooldown_updates(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_signal("cooldowns_updated"):
		if player.cooldowns_updated.is_connected(_on_player_cooldowns_updated):
			player.cooldowns_updated.disconnect(_on_player_cooldowns_updated)
		player.cooldowns_updated.connect(_on_player_cooldowns_updated)


## Show (or clear) the action hint line. Empty text hides the label; any
## non-empty text makes it visible. Surface observables: `visible` + `text`.
func show_hint(text: String) -> void:
	if _action_hint_label == null or not is_instance_valid(_action_hint_label):
		return
	if text == "":
		_action_hint_label.visible = false
		_action_hint_label.text = ""
	else:
		_action_hint_label.text = text
		_action_hint_label.visible = true


## Hide the action hint line and clear its text.
func hide_hint() -> void:
	if _action_hint_label == null or not is_instance_valid(_action_hint_label):
		return
	_action_hint_label.visible = false
	_action_hint_label.text = ""


## Refresh the skill description label from the player's CURRENT selection.
## Reads live state AFTER select_skill() so a rejected press (cooldown / phase
## lock / HP gate) or a toggle-off keeps the label truthful: default guidance
## when nothing is selected (index -1 / out of bounds), otherwise the selected
## skill's Chinese description. Safe pre-battle and during teardown (the player
## lookup is guarded with is_instance_valid).
func _refresh_skill_desc_text() -> void:
	var label: Label = _skill_desc_label
	if label == null or not is_instance_valid(label):
		label = get_node_or_null("SkillDescLabel") as Label
		if label != null:
			_skill_desc_label = label
	if label == null or not is_instance_valid(label):
		return

	var text: String = _DEFAULT_SKILL_DESC_TEXT
	var player: Node = GameManager.get_player()
	if player != null and is_instance_valid(player) \
			and "selected_skill_index" in player and "skills" in player:
		var idx: int = int(player.selected_skill_index)
		if idx >= 0 and idx < player.skills.size():
			var skill = player.skills[idx]
			if skill != null and "description" in skill:
				text = str(skill.description)
	# Cheap-diff: only write when the text actually changed (called every
	# frame; avoids redundant label property writes and keeps _process cheap).
	if label.text != text:
		label.text = text


## Signal handler for the player's action_hint signal — forwards to show_hint.
func _on_action_hint(text: String) -> void:
	show_hint(text)


## Wire the player's action_hint signal to the hint line, mirroring the
## _wire_cooldown_updates pattern: guard has_signal, disconnect any stale
## connection, then connect. Stores the player ref for teardown.
func _wire_action_hint(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_signal("action_hint"):
		if player.action_hint.is_connected(_on_action_hint):
			player.action_hint.disconnect(_on_action_hint)
		player.action_hint.connect(_on_action_hint)
	_action_hint_player = player


# ---------------------------------------------------------------------------
# Process — update health bar positions
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Geometric observables first — readable every frame, including pre-battle
	# frames where the player does not exist yet (before the null-check below).
	_update_geometry_observables()

	for bar in _health_bars:
		if is_instance_valid(bar) and bar.has_method("follow_character"):
			bar.follow_character()

	# Round indicator: always refresh from the engine (safe pre-battle — shows
	# the initial "回合 0 / 行动: / 顺序:" state).
	if is_instance_valid(_round_indicator):
		_round_indicator.update_display(
			CombatManager.current_round,
			CombatManager.active_unit_name,
			CombatManager.turn_order)

	# Skill button states (phase lock / cooldown / HP gate) + cooldown overlays
	# refresh every frame. Skip until the player exists (pre-battle safety).
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	_refresh_skill_button_states(player)
	# Skill description label: keep in sync with the LIVE selection. Hotkeys
	# 1-12 call player.select_skill() directly (bypassing _on_skill_selected)
	# and the engine auto-deselects after an attack — refresh every frame from
	# the actual selected_skill_index (cheap: writes only when the text changes).
	_refresh_skill_desc_text()


## Per-frame skill button refresh: compute each button's `disabled` from
##   (a) two-phase phase lock — TUTORIAL ONLY (CombatManager.tutorial_battle):
##       palm arts (indices 4..11) locked while CombatManager.current_round < 4;
##       encounter battles never phase-lock;
##   (b) per-round cooldown remaining — player.skill_cooldowns[i] > 0;
##   (c) HP gate — DATA-DRIVEN from each skill's hp_gate_below_ratio (e.g.
##       Seventeen Forms ratio 0.5: usable only BELOW 50% max health).
## Also keeps the round-based cooldown overlays in sync (remaining/total
## rounds). Flat iteration order (row1 children then row2 children) matches
## skill index order in both single-row and two-row layouts.
func _refresh_skill_button_states(player: Node) -> void:
	var buttons: Array[Node] = []
	for row in [_skill_row_1, _skill_row_2]:
		if row == null or not is_instance_valid(row):
			continue
		for child in row.get_children():
			if child is Button:
				buttons.append(child)

	var cooldowns: Array = player.skill_cooldowns if "skill_cooldowns" in player else []
	var has_max_health: bool = "max_health" in player
	var max_health: int = int(player.max_health) if has_max_health else 0

	for i in range(buttons.size()):
		# Safe: `buttons` is a fresh get_children() snapshot of live children —
		# never a stored freed reference.
		var btn: Button = buttons[i] as Button
		if btn == null:
			continue

		# Hidden placeholder buttons (no skill behind them) are skipped — never
		# selectable, never rendered.
		if not btn.visible:
			continue

		var phase_locked: bool = CombatManager.tutorial_battle \
			and i >= 4 and CombatManager.current_round < 4
		var on_cooldown: bool = i < cooldowns.size() and int(cooldowns[i]) > 0

		# HP gate data-driven from the skill's own hp_gate_below_ratio (0.0 =
		# never gated). Tutorial button 8 (seventeen_melancholy_forms, ratio 0.5)
		# keeps its historical behavior byte-identical.
		var ratio: float = 0.0
		if "_skill_data" in btn and btn._skill_data != null:
			ratio = float(btn._skill_data.hp_gate_below_ratio)
		var hp_gated: bool = ratio > 0.0 and "health" in player \
			and has_max_health \
			and int(player.health) >= int(round(float(max_health) * ratio))
		# Expose the pure HP-gate predicate on the button (playtest surface),
		# independent of phase lock / cooldown. hp_gated is computed here every
		# frame; skill_button.gd declares the var but never writes it.
		if "hp_gated" in btn:
			btn.hp_gated = hp_gated
		btn.disabled = phase_locked or on_cooldown or hp_gated

		# Cooldown overlay: remaining rounds / total rounds (ints).
		var remaining: int = int(cooldowns[i]) if i < cooldowns.size() else 0
		var total: int = 0
		if "_skill_data" in btn and btn._skill_data != null:
			total = int(btn._skill_data.cooldown)
		if btn.has_method("update_cooldown"):
			btn.update_cooldown(remaining, total)

			# Four-state derivation (priority: phase_locked > cooldown >
			# hp_gated > ready), written every frame as observables and applied
			# visually via _apply_state. The `disabled` computation above stays
			# untouched — the states are the data the visuals are built from.
			var state := "ready"
			if phase_locked:
				state = "phase_locked"
			elif on_cooldown:
				state = "cooldown"
			elif hp_gated:
				state = "hp_gated"
			# turn-to-whom visible (design/30_presentation.md #3 / vision Q3): while
			# the battle is live but it is NOT the player's turn, EVERY visible
			# button renders the distinct "waiting" presentation so the skill bar
			# visibly changes across player -> enemy -> player turn frames.
			# Presentation-only override of the derived four-state: the derivation
			# above stays byte-identical, `disabled` is untouched, and every
			# existing state_text assert fires during PLAYER_TURN frames where
			# this gate is false. NOT nested inside the hp_gated branch — it
			# applies to every button AFTER the chain (the Q3 bug: ready buttons
			# never entered that branch). Not tutorial-scoped — encounter battles
			# show it too.
			if CombatManager.phase != "IDLE" and not CombatManager.is_player_turn():
				state = "waiting"
			if "state_text" in btn:
				btn.state_text = state
			if "cooldown_remaining" in btn:
				btn.cooldown_remaining = remaining
			# Selected overlay: compare the player's chosen skill index against
			# the button's own skill_index (not the loop index i). The player
			# may not expose selected_skill_index (tutorial/pre-battle) — guard.
			if "selected_skill_index" in player:
				btn.selected = (int(player.selected_skill_index) == int(btn.skill_index))
			if btn.has_method("_apply_state"):
				btn._apply_state(state)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Called when a skill button is pressed.
## Forwards the skill index to the player character.
func _on_skill_selected(index: int) -> void:
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return

	if player.has_method("select_skill"):
		player.select_skill(index)

	# Refresh the description label from the LIVE selection — select_skill may
	# have rejected the press (cooldown / phase lock / HP gate) or toggled the
	# same index off, so read the actual selected_skill_index afterwards.
	_refresh_skill_desc_text()


## Called when the player's cooldowns are updated.
## Iterates skill buttons and updates their cooldown overlays.
## Cooldowns are int ROUNDS (decremented by the turn engine at the unit's own
## turn start); total is the skill's round-valued cooldown.
func _on_player_cooldowns_updated(cooldowns: Array) -> void:
	var skill_buttons: Array[Node] = []
	# Row-aware: buttons live under SkillRow1/SkillRow2; the row HBoxes themselves
	# have no update_cooldown, so iterating BOTH rows' children is required for
	# row-2 cooldown overlays to update.
	for row in [_skill_row_1, _skill_row_2]:
		if row == null or not is_instance_valid(row):
			continue
		for child in row.get_children():
			if child.has_method("update_cooldown"):
				skill_buttons.append(child)

	for i in range(skill_buttons.size()):
		if i < cooldowns.size():
			var btn = skill_buttons[i]
			var cooldown_remaining: int = int(cooldowns[i])
			# Determine total cooldown from the button's stored skill data.
			var total: int = 0
			if "_skill_data" in btn and btn._skill_data != null:
				total = int(btn._skill_data.cooldown)
			btn.update_cooldown(cooldown_remaining, total)
