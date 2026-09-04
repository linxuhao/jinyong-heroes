## HUD — Main UI layer containing floating health bars, the round indicator,
## the energy label, the up-to-12 programmatic skill buttons (fa hui du labels +
## round-based cooldown overlays; two rows × 6 when the player owns more than 8
## skills, one row otherwise), and the pause button. Lives on CanvasLayer
## layer 10. Button `disabled` state is recomputed every frame from combat +
## player state (phase lock / cooldown / HP gate).
extends Control

const SkillData = preload("res://scripts/data/skill_data.gd")
const SkillButtonScript = preload("res://scripts/ui/skill_button.gd")

## Display aliases for health-bar name labels: Chinese shrimp-nickname display
## names (R4 owner ruling — every rendered string ships in Chinese; no personal
## name ever appears on screen). The nicknames are longer than the old personal
## names, so readability is covered by the UiOcclusionWatch gate (violations == 0)
## plus same-frame before/after comparisons — never a pixel-literal width pin.
## Only the health-bar display layer is affected — character_data.character_name,
## node names, turn-order names and order_names stay canonical and unchanged.
## The two trailing entries close the raw-canonical leak seen on screen in the
## 2026-09-02 pt2/pt3 frames (ProgressionHero / Sparring Partner rendered bare).
const _DISPLAY_ALIASES := {
	"Yang Guo": "独臂大虾",
	"East Heretic": "东邪虾",
	"West Poison": "西毒虾",
	"South Emperor": "南帝虾",
	"North Beggar": "北丐虾",
	"Central Divine": "中神通虾",
	"ProgressionHero": "侠客虾",
	"Sparring Partner": "陪练虾",
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

## Battle action buttons (defect 6): `pressed_connected` is the wiring-proof
## snapshot taken AFTER the connects (creation.gd middle-chain pattern);
## `hud_button_overlap` / `hud_desc_overlap` are per-frame geometry observables
## asserted false whenever the HUD is visible.
var pressed_connected: Dictionary = {}
var hud_button_overlap: bool = false
var hud_desc_overlap: bool = false

## Touch-reachable undo (Defect: no right-click on phones). `undo_desc_overlap`
## is the per-frame geometry observable for the UndoButton: true iff the
## SkillDescLabel rect and the UndoButton rect intersect (plain Rect2.intersects,
## the same predicate hud_desc_overlap uses — NOT the 1px-inset variant). Static
## geometry (UndoButton y[176,212] vs SkillDescLabel y[216,396], a 4 px gap)
## keeps it false; asserted false while the HUD is visible.
var undo_desc_overlap: bool = false

## C4 roster mirror: true while the RosterPanel overlay is open. Mirrored every
## _process frame from panel.is_open (never from RosterOpenButton.visible — the
## entry button is hidden while open, so reading it would report a false close).
var roster_panel_open: bool = false

## R5 pause-menu mirrors (playtest surface). Both resolved FRESH every frame,
## before the player null-check, so they are readable pre-battle too:
##   - pause_menu_open — true while the PauseMenu panel is visible;
##   - pause_menu_armed — true while 返回主菜单's two-press arm is set.
## The menu itself never writes combat state; these are mirrors only.
var pause_menu_open: bool = false
var pause_menu_armed: bool = false

## R5 combat-log relay: mirrors the CombatLog node's `rendered_text` (a child
## of the CombatManager autoload — not a proven assert target in the harness,
## so the content lands on the proven-resolvable HUD surface instead). The
## node is created lazily by CombatManager's first fx hook, so this reads ""
## until the first hit/no-move — the feedback scenario asserts during an
## enemy round, after hits, which is safely post-creation.
var combat_log_text: String = ""

## Round-2 top-strip observables (playtest surface under HUD.): the five top
## texts (RoundLabel / ActiveLabel / OrderLabel / EnergyLabel, plus
## ActionHintLabel ONLY while visible) must be pairwise non-overlapping and
## fully inside the TopStrip backing band, whose panel stylebox must carry a
## real backing alpha. hint_hpbar_overlap / hpbar_strip_overlap pin the
## floating HP widgets clear of the strip and of the visible hint. Convention:
## overlap = 1px-inset Rect2 intersect (_inset_overlap); hidden widgets are
## skipped, never asserted.
var top_text_pairwise_overlap: bool = false
var top_text_in_strip: bool = true
var top_strip_alpha: float = 1.0
var hint_hpbar_overlap: bool = false
var hpbar_strip_overlap: bool = false

## Nameplate-overlap observables (playtest surface, pinned by
## ui_geometry_readability.yaml). Recomputed every `_process` frame inside
## `_update_geometry_observables()`:
##   - nameplate_pairwise_overlap — true iff ANY pair of visible HealthBar
##     NameLabel rects inset-intersects (1px inset); the ~2px seam between
##     adjacent units' nameplates must be preserved (hence NameLabel 64x9 rects,
##     NOT the 68x24 widget, which would overlap by 4px and force this true).
##   - hint_nameplate_overlap — true iff any VISIBLE hint label rect
##     (MoveHintLabel, SkillDescLabel) inset-intersects any nameplate rect.
## Both default false and stay false on empty rect sets.
var nameplate_pairwise_overlap: bool = false
var hint_nameplate_overlap: bool = false

## Lazily-resolved TopStrip node (nullable — NOT an @onready var, so scenes
## without the node stay safe; resolved inside _update_geometry_observables()
## like the existing _round_indicator pattern).
var _top_strip: Panel = null

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
@onready var _end_turn_button: Button = $EndTurnButton
@onready var _attack_button: Button = $AttackButton
@onready var _undo_button: Button = $UndoButton

## Resolve a skill button by its deterministic name (SkillButton1..SkillButton12).
## Buttons live under SkillRow1/SkillRow2 in the two-row layout, so resolve
## recursively (find_child searches the whole subtree). Safe by construction:
## find_child returns null for freed/absent nodes — never a stored freed-object
## cast. Do NOT cache buttons in a typed array (typed arrays validate on write).
func _skill_button(n: String) -> Control:
	return _skill_bar.find_child(n, true, false) as Control

## The ONE overlap predicate every round-2 top-strip observable uses: a pair
## "overlaps" iff the two rects intersect after each is inset 1px on all sides.
## Rect2.intersects() is inclusive of touching edges, so two stacked labels
## with a 2px gap must NOT read as overlapping.
func _inset_overlap(a: Rect2, b: Rect2) -> bool:
	return a.grow(-1.0).intersects(b.grow(-1.0))

## Collect the global rect of every VISIBLE HealthBar's NameLabel node. Uses the
## NameLabel rect (64x9 in the authored tscn), NOT the 68x24 widget: two adjacent
## units' NameLabel rects touch exactly and become a 2px gap under the 1px-inset
## rule — the required seam. Bars that are freed, hidden, or lack a NameLabel are
## skipped. All rects share the HUD layer-10 scale-1 coordinate space.
func get_nameplate_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for bar in _health_bars:
		if not is_instance_valid(bar) or not bar.visible:
			continue
		var name_label: Control = bar.get_node_or_null("NameLabel") as Control
		if name_label != null and is_instance_valid(name_label):
			rects.append(name_label.get_global_rect())
	return rects

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

	# Battle action buttons + skill description label geometry (defect 6):
	#   hud_button_overlap — either new button's rect intersects any existing
	#     HUD widget (PauseButton / RoundIndicator / SkillBar / ActionHintLabel);
	#   hud_desc_overlap — SkillDescLabel's rect intersects any of those OR
	#     either new button.
	# Both must stay false while the HUD is visible (asserted by
	# ui_geometry_readability and battle_end_turn_attack_buttons). All rects
	# share the HUD layer-10 coordinate system (scale-1 viewport: HUD coords
	# == pixels), so a single intersects() chain is exact.
	var end_btn: Button = _end_turn_button
	if end_btn == null or not is_instance_valid(end_btn):
		end_btn = get_node_or_null("EndTurnButton") as Button
		if end_btn != null:
			_end_turn_button = end_btn
	var atk_btn: Button = _attack_button
	if atk_btn == null or not is_instance_valid(atk_btn):
		atk_btn = get_node_or_null("AttackButton") as Button
		if atk_btn != null:
			_attack_button = atk_btn
	var desc: Label = _skill_desc_label
	if desc == null or not is_instance_valid(desc):
		desc = get_node_or_null("SkillDescLabel") as Label
		if desc != null:
			_skill_desc_label = desc
	var undo_btn: Button = _undo_button
	if undo_btn == null or not is_instance_valid(undo_btn):
		undo_btn = get_node_or_null("UndoButton") as Button
		if undo_btn != null:
			_undo_button = undo_btn

	hud_button_overlap = false
	hud_desc_overlap = false
	undo_desc_overlap = false
	if end_btn == null or atk_btn == null:
		return

	var button_rects: Array[Rect2] = [
		end_btn.get_global_rect(),
		atk_btn.get_global_rect(),
	]
	if undo_btn != null:
		button_rects.append(undo_btn.get_global_rect())
	var hud_widgets: Array[Rect2] = []
	if indicator != null:
		hud_widgets.append(indicator.get_global_rect())
	if pause != null:
		hud_widgets.append(pause.get_global_rect())
	if is_instance_valid(_skill_bar):
		hud_widgets.append(_skill_bar.get_global_rect())
	if is_instance_valid(_action_hint_label):
		hud_widgets.append(_action_hint_label.get_global_rect())

	for r in button_rects:
		for w in hud_widgets:
			if r.intersects(w):
				hud_button_overlap = true
	if desc != null:
		var d: Rect2 = desc.get_global_rect()
		for w in hud_widgets:
			if d.intersects(w):
				hud_desc_overlap = true
		for r in button_rects:
			if d.intersects(r):
				hud_desc_overlap = true
	# UndoButton vs SkillDescLabel: the specific pair the touch-undo scenario
	# pins false. Plain Rect2.intersects (edge-inclusive), same predicate as
	# hud_desc_overlap — NOT the 1px-inset variant.
	if desc != null and undo_btn != null:
		undo_desc_overlap = desc.get_global_rect().intersects(
			undo_btn.get_global_rect())

	# --- Round-2 top strip geometry (top-bar non-overlap) ---
	# The five top texts live inside the TopStrip backing band, pairwise
	# non-overlapping; the floating HP widgets stay clear of the strip and of
	# the visible skill hint. Overlap convention: _inset_overlap (1px-inset
	# Rect2 intersect) so touching edges and 2px-gap stacked labels never read
	# as overlapping. Hidden widgets are skipped — a hidden ActionHintLabel
	# still reports a real get_global_rect(). All rects share the HUD layer-10
	# scale-1 coordinate system: no coordinate conversion anywhere.
	if _top_strip == null or not is_instance_valid(_top_strip):
		_top_strip = get_node_or_null("TopStrip") as Panel
	if _top_strip == null or not is_instance_valid(_top_strip):
		return  # scene without the strip: keep last values
	var strip_rect: Rect2 = _top_strip.get_global_rect()

	# Resolve the four always-participating top labels (same re-resolution
	# style as the block above; indicator is the already re-resolved
	# _round_indicator from the top of this function).
	var round_label: Label = null
	var active_label: Label = null
	var order_label: Label = null
	if indicator != null:
		round_label = indicator.get_node_or_null("RoundLabel") as Label
		active_label = indicator.get_node_or_null("ActiveLabel") as Label
		order_label = indicator.get_node_or_null("OrderLabel") as Label
	var energy_label: Label = _energy_label
	if energy_label == null or not is_instance_valid(energy_label):
		energy_label = get_node_or_null("EnergyLabel") as Label
		if energy_label != null:
			_energy_label = energy_label

	var top_rects: Array[Rect2] = []
	for label in [round_label, active_label, order_label, energy_label]:
		if label != null and is_instance_valid(label):
			top_rects.append(label.get_global_rect())
	# The hint participates ONLY when visible (hidden widgets still have rects;
	# a hidden hint at its old position must not false-positive).
	if _action_hint_label != null and is_instance_valid(_action_hint_label) \
			and _action_hint_label.visible:
		top_rects.append(_action_hint_label.get_global_rect())

	top_text_pairwise_overlap = false
	for i in range(top_rects.size()):
		for j in range(i + 1, top_rects.size()):
			if _inset_overlap(top_rects[i], top_rects[j]):
				top_text_pairwise_overlap = true

	top_text_in_strip = true
	for r in top_rects:
		if not (strip_rect.grow(2.0).encloses(r) and r.size.x > 0):
			top_text_in_strip = false

	top_strip_alpha = 1.0
	var sb := _top_strip.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		top_strip_alpha = sb.bg_color.a

	hpbar_strip_overlap = false
	for bar in _health_bars:
		if not is_instance_valid(bar) or not bar.visible:
			continue
		if _inset_overlap(bar.get_global_rect(), strip_rect):
			hpbar_strip_overlap = true

	# hint_hpbar_overlap is only meaningful while the hint is visible; when it
	# is hidden the variable keeps its last value (it is only asserted on
	# visible-hint frames).
	if _action_hint_label != null and is_instance_valid(_action_hint_label) \
			and _action_hint_label.visible:
		hint_hpbar_overlap = false
		var hint_rect: Rect2 = _action_hint_label.get_global_rect()
		for bar in _health_bars:
			if not is_instance_valid(bar) or not bar.visible:
				continue
			if _inset_overlap(hint_rect, bar.get_global_rect()):
				hint_hpbar_overlap = true

	# --- Nameplate overlap observables (ui_geometry_readability) ---
	# Computed from get_nameplate_rects() (NameLabel rects only). Both default to
	# false and stay false on empty rect sets. SkillDescLabel participates only
	# when visible; MoveHintLabel participates only when visible (hidden hint
	# labels report a stale rect and must not false-positive).
	var nameplates: Array[Rect2] = get_nameplate_rects()

	nameplate_pairwise_overlap = false
	for i in range(nameplates.size()):
		for j in range(i + 1, nameplates.size()):
			if _inset_overlap(nameplates[i], nameplates[j]):
				nameplate_pairwise_overlap = true

	hint_nameplate_overlap = false
	var hint_labels: Array[Control] = []
	if is_instance_valid(_skill_desc_label) and _skill_desc_label.visible:
		hint_labels.append(_skill_desc_label)
	var move_hint: Control = get_node_or_null("MoveHintLabel") as Control
	if move_hint != null and is_instance_valid(move_hint) and move_hint.visible:
		hint_labels.append(move_hint)
	for label in hint_labels:
		var lr: Rect2 = label.get_global_rect()
		for r in nameplates:
			if _inset_overlap(lr, r):
				hint_nameplate_overlap = true

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

	# --- Energy label: keep the top-strip number in sync with the live pool
	# (jinyong-spend-qi — casting deducts inner force, so a setup()-only write
	# would freeze the number at the starting pool). ---
	_refresh_energy_label(player)

	# Wire the player's action_hint signal to the hint line (idempotent:
	# disconnects any stale connection first, so repeated setup() calls are safe).
	_wire_action_hint(player)

	# Skill description label: start every battle from the default guidance
	# (nothing is selected yet).
	_refresh_skill_desc_text()

	# Battle action buttons: wire EndTurnButton / AttackButton to their
	# handlers (idempotent disconnect-first) and snapshot the wiring proof.
	_wire_battle_action_buttons()


## Keep the top-strip EnergyLabel ("内力: %d") in sync with the LIVE inner-force
## pool. Casting deducts inner force (jinyong-spend-qi), so this is refreshed
## every frame from the real `player.energy` — a setup()-only write would freeze
## the number at the starting pool once casts start deducting. Called from
## setup() (player guaranteed non-null there) and from _process's per-frame
## refresh (after the player null-guard). Defensive: silently returns when the
## player or label is null / freed, and when the player exposes no `energy`
## property falls back to 0. Pure text write — no rect / node / geometry change.
func _refresh_energy_label(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	var energy_label: Label = _energy_label
	if energy_label == null or not is_instance_valid(energy_label):
		# Safe: get_node_or_null re-resolves the path each call; null for
		# freed nodes — never a freed-object cast.
		energy_label = get_node_or_null("EnergyLabel") as Label
		if energy_label != null:
			_energy_label = energy_label
	if energy_label == null:
		return
	var qi: int = int(player.energy) if "energy" in player else 0
	energy_label.text = tr("内力: %d") % qi


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


## Wire the two battle action buttons (EndTurn / Attack) to their handlers.
## Idempotent: disconnects any stale connection before connecting, so repeated
## setup() calls are safe (mirrors _wire_action_hint). After the connects,
## snapshot `pressed_connected` — the same middle-chain wiring proof creation.gd
## uses; the snapshot MUST be taken after connect(), because
## get_signal_connection_list("pressed") is empty before the signal is wired.
func _wire_battle_action_buttons() -> void:
	var end_btn: Button = _end_turn_button
	if end_btn == null or not is_instance_valid(end_btn):
		end_btn = get_node_or_null("EndTurnButton") as Button
		if end_btn != null:
			_end_turn_button = end_btn
	if end_btn != null:
		if end_btn.pressed.is_connected(_on_end_turn_pressed):
			end_btn.pressed.disconnect(_on_end_turn_pressed)
		end_btn.pressed.connect(_on_end_turn_pressed)

	var atk_btn: Button = _attack_button
	if atk_btn == null or not is_instance_valid(atk_btn):
		atk_btn = get_node_or_null("AttackButton") as Button
		if atk_btn != null:
			_attack_button = atk_btn
	if atk_btn != null:
		if atk_btn.pressed.is_connected(_on_attack_pressed):
			atk_btn.pressed.disconnect(_on_attack_pressed)
		atk_btn.pressed.connect(_on_attack_pressed)

	var undo_btn: Button = _undo_button
	if undo_btn == null or not is_instance_valid(undo_btn):
		undo_btn = get_node_or_null("UndoButton") as Button
		if undo_btn != null:
			_undo_button = undo_btn
	if undo_btn != null:
		if undo_btn.pressed.is_connected(_on_undo_button_pressed):
			undo_btn.pressed.disconnect(_on_undo_button_pressed)
		undo_btn.pressed.connect(_on_undo_button_pressed)

	pressed_connected = {
		"EndTurnButton": end_btn != null
			and end_btn.get_signal_connection_list("pressed").size() > 0,
		"AttackButton": atk_btn != null
			and atk_btn.get_signal_connection_list("pressed").size() > 0,
		"UndoButton": undo_btn != null
			and undo_btn.get_signal_connection_list("pressed").size() > 0,
	}


## Shared input gate for the two battle action buttons: input is allowed only
## while it is the player's turn and the game is not paused.
## CombatManager.end_current_turn() has NO internal turn gate, so this check is
## the caller's responsibility — it mirrors the keyboard paths' own gating.
func _battle_input_allowed() -> bool:
	return CombatManager.is_player_turn() and not CombatManager.get_is_paused()


## EndTurnButton handler: the same engine call the Space key makes. A silent
## no-op when the gate is closed (enemy turn / paused), matching the keyboard
## path exactly.
func _on_end_turn_pressed() -> void:
	if not _battle_input_allowed():
		return
	CombatManager.end_current_turn()


## AttackButton handler: the same call the J key makes — fires the selected
## skill, or a basic attack at the nearest adjacent enemy when none is
## selected. Uses a LIVE GameManager.get_player() lookup (never a stored ref)
## and guards the call before invoking the player method.
func _on_attack_pressed() -> void:
	if not _battle_input_allowed():
		return
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("_try_keyboard_attack"):
		player._try_keyboard_attack()


## UndoButton handler: delegates to the player's SHARED, self-gated undo entry
## — the same call the right-click path makes (phones have no right-click, so
## this finger-reachable button is the touch undo). NO synthetic InputEvent
## (that would re-enter _unhandled_input and double-count the raw counter) and
## NO forked undo logic: the deep gates (state / turn / pause / is_moving / the
## acted lock and the 「已出手,无法退回」 rejection) and the turn-start restore
## stay owned by player.handle_world_right_click. Uses a LIVE
## GameManager.get_player() lookup (never a stored ref), like the siblings.
## The `world_pos` argument is position-independent in that entry; the unit
## node origin (= own tile centre) is the semantically correct value.
func _on_undo_button_pressed() -> void:
	if not _battle_input_allowed():
		return
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("handle_world_right_click"):
		player.handle_world_right_click(player.global_position)


# ---------------------------------------------------------------------------
# Process — update health bar positions
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Geometric observables first — readable every frame, including pre-battle
	# frames where the player does not exist yet (before the null-check below).
	_update_geometry_observables()

	# C4 roster mirror: publish the panel's open state every frame, BEFORE the
	# player null-check so it is readable pre-battle too. Reads panel.is_open
	# (never RosterOpenButton.visible — the entry button is hidden while open,
	# so reading it would report a false close).
	roster_panel_open = _roster_is_open()

	# R5 pause-menu mirrors + combat-log relay: published BEFORE the player
	# null-check so they are readable on every frame. All three are null-safe
	# mirrors — the menu node and the log node may not exist (pre-battle /
	# before the first hit), in which case they read their falsy defaults.
	var pause_menu: Control = get_node_or_null("PauseMenu") as Control
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu_open = bool(pause_menu.visible)
		pause_menu_armed = bool(pause_menu.confirm_armed)
	else:
		pause_menu_open = false
		pause_menu_armed = false
	var combat_log_node: Node = CombatManager.get_node_or_null("CombatLog")
	if combat_log_node != null and is_instance_valid(combat_log_node) \
			and "rendered_text" in combat_log_node:
		combat_log_text = String(combat_log_node.rendered_text)
	else:
		combat_log_text = ""

	# Battle action buttons: disabled whenever the battle input gate is closed
	# (not the player's turn, or paused). Must run BEFORE the player null-check
	# so the state is readable every frame. A click on a disabled Button emits
	# nothing — double protection behind the handler gates. Pre-battle
	# (phase == IDLE) the gate is closed, so both buttons start disabled.
	if is_instance_valid(_end_turn_button) and is_instance_valid(_attack_button):
		var allowed: bool = _battle_input_allowed()
		_end_turn_button.disabled = not allowed
		_attack_button.disabled = not allowed

	# UndoButton: disabled unless the battle input gate is open AND the player
	# reports undo_available (recomputed every frame in player._process — never
	# a HUD-side copy of the turn-start state). A disabled Button emits nothing
	# on click, so this is the visible lock surface; the handler gate is the
	# second layer. Player null (pre-battle) short-circuits to disabled=true
	# without ever reading undo_available. Must run BEFORE the player
	# null-check below so the state is readable every frame.
	if is_instance_valid(_undo_button):
		var undo_p: Node = GameManager.get_player()
		var undo_allowed: bool = _battle_input_allowed() and undo_p != null \
			and is_instance_valid(undo_p) and "undo_available" in undo_p \
			and bool(undo_p.undo_available)
		_undo_button.disabled = not undo_allowed

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

	# Skill button states (phase lock / cooldown / HP gate / inner-force) +
	# cooldown overlays refresh every frame. Skip until the player exists
	# (pre-battle safety).
	var player: Node = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	_refresh_skill_button_states(player)
	# Energy label: refresh the live inner-force number every frame — casting
	# deducts the pool (jinyong-spend-qi), so a setup()-only write would freeze
	# it at the starting value.
	_refresh_energy_label(player)
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

		# GOAL 4 no_energy derivation: insufficient inner force. Reads the
		# skill's cost (0 when skill data is missing/absent — same guard as the
		# hp_gate_below_ratio read above) and the player's energy (0 when the
		# player exposes no `energy`, same pattern as the EnergyLabel write in
		# setup()). Real per-skill costs are now defined (jinyong-spend-qi,
		# design/20_content.md cost table), so no_energy fires in live play
		# whenever the pool drops below a move's cost — including the tutorial's
		# skill_2/3/4/5/6/7/8 once qi is spent down.
		var cost: int = 0
		if "_skill_data" in btn and btn._skill_data != null:
			cost = int(btn._skill_data.cost)
		var energy: int = int(player.energy) if "energy" in player else 0
		var no_energy: bool = SkillButtonScript.no_energy_predicate(cost, energy)
		# Expose the pure predicate on the button (drives `disabled` below and is
		# the observable the unit test checks); skill_button.gd declares the var
		# but never writes it (mirror hp_gated).
		if "no_energy" in btn:
			btn.no_energy = no_energy

		# UX-04 lock reason (surface): derive from the SAME phase-lock
		# predicate that disables the button (tutorial palm-art slots 5-8
		# while current_round < 4), so the reason disappears exactly when
		# the lock does. Written every frame at a general position in the
		# loop (it flips at round 4 without a re-setup, and must survive
		# the `waiting` override during enemy turns). Never a hardcoded
		# always-on string — encounter battles and rounds >= 4 render "".
		# Guarded with `if "lock_reason_text" in btn` so nodes without the
		# observable (e.g. plain Buttons in headless tests) are skipped.
		if "lock_reason_text" in btn:
			btn.lock_reason_text = "第 4 轮解锁" if phase_locked else ""

		btn.disabled = phase_locked or on_cooldown or hp_gated or no_energy

		# Cooldown overlay: remaining rounds / total rounds (ints).
		var remaining: int = int(cooldowns[i]) if i < cooldowns.size() else 0
		var total: int = 0
		if "_skill_data" in btn and btn._skill_data != null:
			total = int(btn._skill_data.cooldown)
		if btn.has_method("update_cooldown"):
			btn.update_cooldown(remaining, total)

			# State derivation via the shared skill_button.gd single source of
			# truth (`waiting` is checked FIRST and is the true override; for waiting == false the priority is phase_locked > cooldown > hp_gated >
			# no_energy > ready; while the battle is live but
			# it is NOT the player's turn, EVERY visible button renders "waiting",
			# design/30_presentation.md #3). Written every frame as observables and
			# applied visually via _apply_state. The `disabled` computation above
			# stays untouched. With real per-skill costs (jinyong-spend-qi)
			# no_energy can fire; the priority chain (phase_locked > cooldown >
			# hp_gated > no_energy > ready) still matches the HUD derivation.
			var waiting: bool = CombatManager.phase != "IDLE" and not CombatManager.is_player_turn()
			var state: String = SkillButtonScript.derive_state(
				phase_locked, on_cooldown, hp_gated, no_energy, waiting)
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


# ---------------------------------------------------------------------------
# CARD 0b — ACTING-UNIT MARKER MOUNT (APPEND-ONLY)
#
# Mount the acting-unit pulse ring (scenes/ui/acting_unit_marker.tscn) as a
# child of this HUD Control — NOT inside the LOCKED scripts/battlefield.gd. It
# rides the HUD CanvasLayer above the board. The marker is a self-driving poller
# (its own _process resolves CombatManager.get_active_unit() fresh each frame,
# positions the ring at the unit's foot anchor, and mirrors visibility back into
# CombatManager.acting_marker_visible / acting_marker_unit_name). It is
# MOUSE_FILTER_IGNORE, so it is never the interaction surface and eats no board
# clicks during ENEMY_TURN (the SegmentHost STOP-filter defect class). No
# existing HUD field, signal, method or ordering is touched: a NEW idempotent
# _ready() (this file defines no prior _ready) is appended so a HUD that re-enters
# the tree never double-instantiates the marker.
# ---------------------------------------------------------------------------
func _ready() -> void:
	if get_node_or_null("ActingUnitMarker") != null:
		return
	var marker_scene: PackedScene = preload("res://scenes/ui/acting_unit_marker.tscn")
	add_child(marker_scene.instantiate())
	# C4 roster entry: reposition the panel's RosterOpenButton into the
	# PauseButton(y8-44) <-> EndTurnButton(y96-132) gap (y48-84) so it does not
	# collide with the top-right stack, and keep its label 角色.
	var ob: Button = get_node_or_null("RosterPanel/RosterOpenButton") as Button
	if ob != null:
		ob.anchor_left = 1.0
		ob.anchor_right = 1.0
		ob.offset_left = -130.0
		ob.offset_top = 48.0
		ob.offset_right = -10.0
		ob.offset_bottom = 84.0
		ob.text = tr("角色")


## C4 roster helpers: resolve the panel instance (null-safe) and its open state.
func _roster_panel() -> Control:
	return get_node_or_null("RosterPanel") as Control


func _roster_is_open() -> bool:
	var panel: Control = _roster_panel()
	return panel != null and is_instance_valid(panel) and bool(panel.is_open)


## C4 input shield: while the roster panel is open, consume ALL unhandled input
## so keyboard never reaches the battle handlers through a panel the locked
## battlefield host does not know about. NOTE (intentional, not a regression):
## while the panel is open, Esc/keyboard CANNOT close it — close is touch/click
## only (RosterCloseButton / tap-outside), per the brief's touch-reachability
## requirement.
func _unhandled_input(event: InputEvent) -> void:
	if _roster_is_open():
		get_viewport().set_input_as_handled()
		return
