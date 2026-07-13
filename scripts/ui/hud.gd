## HUD — Main UI layer containing floating health bars, skill buttons,
## and pause button. Lives on CanvasLayer layer 10.
extends CanvasLayer

const SkillData = preload("res://scripts/data/skill_data.gd")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Array of instantiated HealthBar Controls, one per character.
var _health_bars: Array[Control] = []

## Preloaded health_bar scene for instantiation.
var _health_bar_scene: PackedScene = preload("res://scenes/ui/health_bar.tscn")

## Preloaded skill_button scene for instantiation.
var _skill_button_scene: PackedScene = preload("res://scenes/ui/skill_button.tscn")

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _health_bar_container: Control = $HealthBarContainer
@onready var _skill_bar: HBoxContainer = $SkillBar
@onready var _pause_button: Button = $PauseButton

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Set up the HUD: create health bars for the player and all enemies,
## populate skill buttons, and wire signals.
## Called by battlefield.gd after characters are placed.
func setup(player: Node, enemies: Array[Node]) -> void:
	_health_bars.clear()

	# --- Player health bar ---
	_create_health_bar(player, "Yang Guo")

	# --- Enemy health bars ---
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var char_name: String = "Enemy"
		if "character_data" in enemy and enemy.character_data != null:
			char_name = enemy.character_data.character_name
		elif "name" in enemy:
			char_name = enemy.name
		_create_health_bar(enemy, char_name)

	# --- Skill buttons ---
	_populate_skill_buttons(player)

	# --- Pause button ---
	# pause_button.gd handles its own wiring via _ready().


## Create a single health bar for a character and add it to the container.
func _create_health_bar(character: Node, display_name: String) -> void:
	if not is_instance_valid(_health_bar_scene):
		return

	var bar: Control = _health_bar_scene.instantiate() as Control
	if bar == null:
		return

	if not bar.has_method("setup"):
		return

	var max_hp: int = 100
	if "max_health" in character:
		max_hp = character.max_health

	bar.setup(display_name, max_hp, character)
	_health_bar_container.add_child(bar)
	_health_bars.append(bar)


## Populate skill buttons from the player's skills array.
## If the existing SkillBar children are already set up (from the .tscn),
## reconfigure them. Otherwise, create new buttons.
func _populate_skill_buttons(player: Node) -> void:
	var skills: Array = []
	if "skills" in player:
		skills = player.skills

	# Use existing button children in the SkillBar if present.
	var existing_buttons: Array[Node] = []
	for child in _skill_bar.get_children():
		if child is Button:
			existing_buttons.append(child)

	# Create buttons for each skill.
	var hotkeys: Array[String] = ["1", "2"]
	for i in range(skills.size()):
		if i >= hotkeys.size():
			break

		var skill = skills[i]
		if skill == null:
			continue

		var btn: Button = null
		if i < existing_buttons.size():
			btn = existing_buttons[i] as Button
		else:
			# Create a new skill button instance.
			var inst: Button = _skill_button_scene.instantiate() as Button
			if inst == null:
				continue
			_skill_bar.add_child(inst)
			btn = inst

		# Configure the button.
		if btn.has_method("setup"):
			btn.setup(skill, hotkeys[i])

		# Store the skill index.
		if "skill_index" in btn:
			btn.skill_index = i

		# Connect the skill_selected signal.
		if btn.has_signal("skill_selected"):
			if btn.skill_selected.is_connected(_on_skill_selected):
				btn.skill_selected.disconnect(_on_skill_selected)
			btn.skill_selected.connect(_on_skill_selected)

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


# ---------------------------------------------------------------------------
# Process — update health bar positions
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	for bar in _health_bars:
		if is_instance_valid(bar) and bar.has_method("follow_character"):
			bar.follow_character()

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


## Called when the player's cooldowns are updated.
## Iterates skill buttons and updates their cooldown overlays.
func _on_player_cooldowns_updated(cooldowns: Array) -> void:
	var skill_buttons: Array[Node] = []
	for child in _skill_bar.get_children():
		if child.has_method("update_cooldown"):
			skill_buttons.append(child)

	for i in range(skill_buttons.size()):
		if i < cooldowns.size():
			var btn = skill_buttons[i]
			var cooldown_remaining: float = cooldowns[i]
			# Determine total cooldown from the button's stored skill data.
			var total: float = 0.0
			if "_skill_data" in btn and btn._skill_data != null:
				total = btn._skill_data.cooldown
			btn.update_cooldown(cooldown_remaining, total)
