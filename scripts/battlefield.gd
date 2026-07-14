## Battlefield — Main battlefield controller
##
## Attached to battlefield.tscn. Orchestrates the full battlefield
## initialisation: procedural tile textures, TileMap setup, character
## and skill data creation, player/enemy instantiation, AI wiring,
## HUD setup, and tutorial start.
extends Node2D

const SkillData = preload("res://scripts/data/skill_data.gd")
const CharacterData = preload("res://scripts/data/character_data.gd")

# ---------------------------------------------------------------------------
# Constants (mirror GridManager for convenience)
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 15
const GRID_HEIGHT: int = 11

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _backdrop: ColorRect = $SummitBackdrop
@onready var _tilemap: TileMap = $Grid
@onready var _characters_container: Node2D = $Characters

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# 1. Create procedural tile textures.
	var textures: Dictionary = _create_tile_textures()

	# 2. Build the TileSet and paint the grid.
	_setup_tilemap(textures.floor, textures.border)

	# 3. Size the backdrop to cover grid + padding.
	_backdrop.size = Vector2(
		GRID_WIDTH * TILE_SIZE + 128,
		GRID_HEIGHT * TILE_SIZE + 128
	)
	_backdrop.position = Vector2(-64, -64)

	# 4. Pass TileMap to GridManager and build the AStar graph.
	GridManager.set_tilemap(_tilemap)
	GridManager.setup_grid()

	# 5. Create all skill data (referenced by character data).
	var all_skills: Dictionary = _create_all_skill_data()

	# 6. Create all character data.
	var all_characters: Dictionary = _create_all_character_data(all_skills)

	# 7. Instantiate player (Yang Guo).
	var player_node: Node = _instantiate_player(all_characters["Yang Guo"])

	# 8. Instantiate the five enemies.
	var enemy_list: Array[Node] = _instantiate_enemies(all_characters)

	# 9. Wire the HUD (deferred — HUD._ready() hasn't run yet,
	#    so its @onready vars (health bar container, skill bar) are null).
	_wire_hud.call_deferred(player_node, enemy_list)

	# 10. Store tutorial overlay reference and start tutorial (also deferred
	#    for the same reason — TutorialOverlay may not be ready yet).
	_wire_tutorial_overlay.call_deferred()
	TutorialManager.start.call_deferred()


# ---------------------------------------------------------------------------
# Procedural tile textures
# ---------------------------------------------------------------------------

## Create 64×64 procedural tile textures for floor and border.
## Returns a Dictionary with keys "floor" and "border" (ImageTexture values).
func _create_tile_textures() -> Dictionary:
	var floor_img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	floor_img.fill(Color(0.3, 0.6, 0.2, 1.0))  # grass green
	var floor_tex: ImageTexture = ImageTexture.create_from_image(floor_img)

	var border_img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	border_img.fill(Color(0.35, 0.35, 0.35, 1.0))  # stone gray
	var border_tex: ImageTexture = ImageTexture.create_from_image(border_img)

	return {
		floor = floor_tex,
		border = border_tex,
	}


# ---------------------------------------------------------------------------
# TileMap setup
# ---------------------------------------------------------------------------

## Create a TileSet with two tiles (floor=0, border=1), assign textures,
## and paint the 15×11 grid.
func _setup_tilemap(floor_tex: ImageTexture, border_tex: ImageTexture) -> void:
	var tileset: TileSet = TileSet.new()

	# Configure tile size.
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Build a single 2×1 atlas image: floor (0,0) at left half, border (1,0) at right.
	var floor_img: Image = floor_tex.get_image()
	var border_img: Image = border_tex.get_image()
	var atlas_img: Image = Image.create(TILE_SIZE * 2, TILE_SIZE, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))
	atlas_img.blit_rect(floor_img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(0, 0))
	atlas_img.blit_rect(border_img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(TILE_SIZE, 0))

	var atlas_tex: ImageTexture = ImageTexture.create_from_image(atlas_img)

	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()

	# Set the atlas texture.
	atlas_source.texture = atlas_tex

	# Define tile 0 at atlas coords (0,0) — floor.
	atlas_source.create_tile(Vector2i(0, 0))
	# Define tile 1 at atlas coords (1,0) — border.
	atlas_source.create_tile(Vector2i(1, 0))

	# Add the atlas source to the TileSet.
	tileset.add_source(atlas_source, 0)

	# Assign the tileset to the TileMap.
	_tilemap.tile_set = tileset

	# Tile IDs in the TileMap are identified by (source_id, atlas_coords).
	# source_id = 0 (the only source), atlas_coords = Vector2i(0,0) for floor
	# and Vector2i(1,0) for border.

	# Paint the grid: floor everywhere.
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))

	# Paint border tiles on edges (overwrites floor).
	for x in range(GRID_WIDTH):
		_tilemap.set_cell(0, Vector2i(x, 0), 0, Vector2i(1, 0))           # top edge
		_tilemap.set_cell(0, Vector2i(x, GRID_HEIGHT - 1), 0, Vector2i(1, 0))  # bottom edge
	for y in range(GRID_HEIGHT):
		_tilemap.set_cell(0, Vector2i(0, y), 0, Vector2i(1, 0))           # left edge
		_tilemap.set_cell(0, Vector2i(GRID_WIDTH - 1, y), 0, Vector2i(1, 0))  # right edge


# ---------------------------------------------------------------------------
# Skill data factory
# ---------------------------------------------------------------------------

## Create all SkillData resources. Returns a Dictionary keyed by skill ID.
func _create_all_skill_data() -> Dictionary:
	var skills: Dictionary = {}

	var sd

	# Sorrowful Palms (黯然销魂掌) — Yang Guo skill 1
	sd = SkillData.new()
	sd.skill_name = "Sorrowful Palms"
	sd.description = "High melee damage with knockback. 4s cooldown."
	sd.damage = 25
	sd.range = 1
	sd.cooldown = 4.0
	sd.aoe_shape = "single"
	sd.aoe_size = 0
	sd.knockback = 1
	sd.dot_damage = 0
	sd.dot_duration = 0.0
	sd.heal_amount = 0
	skills.sorrowful_palms = sd

	# Heavy Iron Sword (玄铁剑法) — Yang Guo skill 2
	sd = SkillData.new()
	sd.skill_name = "Heavy Iron Sword"
	sd.description = "Line AoE, 2-tile reach. 3s cooldown."
	sd.damage = 15
	sd.range = 2
	sd.cooldown = 3.0
	sd.aoe_shape = "line"
	sd.aoe_size = 2
	sd.knockback = 0
	sd.dot_damage = 0
	sd.dot_duration = 0.0
	sd.heal_amount = 0
	skills.heavy_iron_sword = sd

	# Poison Cloud — East Heretic skill
	sd = SkillData.new()
	sd.skill_name = "Poison Cloud"
	sd.description = "Ranged AoE poison, applies DoT. 5s cooldown."
	sd.damage = 8
	sd.range = 3
	sd.cooldown = 5.0
	sd.aoe_shape = "square"
	sd.aoe_size = 1
	sd.knockback = 0
	sd.dot_damage = 4
	sd.dot_duration = 4.0
	sd.heal_amount = 0
	skills.poison_cloud = sd

	# Venom Strike — West Poison skill
	sd = SkillData.new()
	sd.skill_name = "Venom Strike"
	sd.description = "Melee poison strike with DoT. 3s cooldown."
	sd.damage = 12
	sd.range = 1
	sd.cooldown = 3.0
	sd.aoe_shape = "single"
	sd.aoe_size = 0
	sd.knockback = 0
	sd.dot_damage = 5
	sd.dot_duration = 3.0
	sd.heal_amount = 0
	skills.venom_strike = sd

	# Healing Light — South Emperor skill
	sd = SkillData.new()
	sd.skill_name = "Healing Light"
	sd.description = "Heals self. 15s cooldown."
	sd.damage = 0
	sd.range = 0
	sd.cooldown = 15.0
	sd.aoe_shape = "single"
	sd.aoe_size = 0
	sd.knockback = 0
	sd.dot_damage = 0
	sd.dot_duration = 0.0
	sd.heal_amount = 30
	skills.healing_light = sd

	# Dragon Palm (降龙十八掌) — North Beggar skill
	sd = SkillData.new()
	sd.skill_name = "Dragon Palm"
	sd.description = "Powerful line AoE with knockback. 6s cooldown."
	sd.damage = 30
	sd.range = 3
	sd.cooldown = 6.0
	sd.aoe_shape = "line"
	sd.aoe_size = 3
	sd.knockback = 2
	sd.dot_damage = 0
	sd.dot_duration = 0.0
	sd.heal_amount = 0
	skills.dragon_palm = sd

	# Divine Burst — Central Divine skill
	sd = SkillData.new()
	sd.skill_name = "Divine Burst"
	sd.description = "Cross-shaped AoE, moderate damage. 5s cooldown."
	sd.damage = 20
	sd.range = 2
	sd.cooldown = 5.0
	sd.aoe_shape = "cross"
	sd.aoe_size = 2
	sd.knockback = 0
	sd.dot_damage = 0
	sd.dot_duration = 0.0
	sd.heal_amount = 0
	skills.divine_burst = sd

	return skills


# ---------------------------------------------------------------------------
# Character data factory
# ---------------------------------------------------------------------------

## Create all CharacterData resources. Returns a Dictionary keyed by name.
func _create_all_character_data(all_skills: Dictionary) -> Dictionary:
	var chars: Dictionary = {}
	var cd
	var s: Dictionary = all_skills

	# Yang Guo (player)
	cd = CharacterData.new()
	cd.character_name = "Yang Guo"
	cd.max_health = 100
	cd.move_range = 3
	cd.attack_damage = 10
	cd.attack_range = 1
	cd.skills = [s.sorrowful_palms, s.heavy_iron_sword]
	cd.ai_class = ""
	cd.color = Color(0.2, 0.5, 1.0, 1.0)  # blue
	chars["Yang Guo"] = cd

	# East Heretic (东邪黄药师)
	cd = CharacterData.new()
	cd.character_name = "East Heretic"
	cd.max_health = 80
	cd.move_range = 3
	cd.attack_damage = 8
	cd.attack_range = 2
	cd.skills = [s.poison_cloud]
	cd.ai_class = "AIControllerEastHeretic"
	cd.color = Color(0.2, 0.8, 0.2, 1.0)  # green
	chars["East Heretic"] = cd

	# West Poison (西毒欧阳锋)
	cd = CharacterData.new()
	cd.character_name = "West Poison"
	cd.max_health = 90
	cd.move_range = 3
	cd.attack_damage = 10
	cd.attack_range = 1
	cd.skills = [s.venom_strike]
	cd.ai_class = "AIControllerWestPoison"
	cd.color = Color(0.7, 0.2, 0.7, 1.0)  # purple
	chars["West Poison"] = cd

	# South Emperor (南帝段智兴)
	cd = CharacterData.new()
	cd.character_name = "South Emperor"
	cd.max_health = 85
	cd.move_range = 3
	cd.attack_damage = 9
	cd.attack_range = 1
	cd.skills = [s.healing_light]
	cd.ai_class = "AIControllerSouthEmperor"
	cd.color = Color(0.9, 0.8, 0.2, 1.0)  # gold
	chars["South Emperor"] = cd

	# North Beggar (北丐洪七公)
	cd = CharacterData.new()
	cd.character_name = "North Beggar"
	cd.max_health = 95
	cd.move_range = 3
	cd.attack_damage = 12
	cd.attack_range = 1
	cd.skills = [s.dragon_palm]
	cd.ai_class = "AIControllerNorthBeggar"
	cd.color = Color(0.8, 0.4, 0.1, 1.0)  # orange
	chars["North Beggar"] = cd

	# Central Divine (中神通王重阳)
	cd = CharacterData.new()
	cd.character_name = "Central Divine"
	cd.max_health = 100
	cd.move_range = 2
	cd.attack_damage = 10
	cd.attack_range = 1
	cd.skills = [s.divine_burst]
	cd.ai_class = "AIControllerCentralDivine"
	cd.color = Color(0.9, 0.9, 0.9, 1.0)  # white
	chars["Central Divine"] = cd

	return chars


# ---------------------------------------------------------------------------
# Player instantiation
# ---------------------------------------------------------------------------

## Load player.tscn, instance it, set up at starting position, return the node.
func _instantiate_player(data) -> Node:
	var player_scene: PackedScene = preload("res://scenes/player.tscn")
	var player: Node = player_scene.instantiate()

	# Starting position: centre of the grid.
	var start_pos: Vector2i = Vector2i(7, 5)
	player.grid_pos = start_pos
	player.position = GridManager.grid_to_world(start_pos)

	# Call setup with the character data.
	player.setup(data)

	# Register tile occupancy.
	GridManager.reserve_tile(start_pos, player)

	# Add to scene tree.
	_characters_container.add_child(player)

	# Register with GameManager.
	GameManager.set_player(player)

	return player


# ---------------------------------------------------------------------------
# Enemy instantiation
# ---------------------------------------------------------------------------

## Load enemy.tscn for each of the five Greats, set up at their starting
## positions with the appropriate AI controller, and return the array of
## enemy nodes.
func _instantiate_enemies(all_data: Dictionary) -> Array[Node]:
	var enemies: Array[Node] = []

	# Starting grid positions for each enemy.
	var positions: Dictionary = {
		"East Heretic":   Vector2i(3, 2),
		"West Poison":    Vector2i(11, 2),
		"South Emperor":  Vector2i(3, 8),
		"North Beggar":   Vector2i(11, 8),
		"Central Divine": Vector2i(7, 1),
	}

	# AI class name → script path mapping.
	var ai_map: Dictionary = {
		"AIControllerEastHeretic":   preload("res://scripts/ai/ai_east_heretic.gd"),
		"AIControllerWestPoison":    preload("res://scripts/ai/ai_west_poison.gd"),
		"AIControllerSouthEmperor":  preload("res://scripts/ai/ai_south_emperor.gd"),
		"AIControllerNorthBeggar":   preload("res://scripts/ai/ai_north_beggar.gd"),
		"AIControllerCentralDivine": preload("res://scripts/ai/ai_central_divine.gd"),
	}

	var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

	for name_key in positions.keys():
		var data = all_data[name_key]
		if data == null:
			continue

		var enemy: Node = enemy_scene.instantiate()
		var grid_pos: Vector2i = positions[name_key]

		enemy.grid_pos = grid_pos
		enemy.position = GridManager.grid_to_world(grid_pos)

		# Create the AI controller instance.
		var ai_class_name: String = data.ai_class
		var ai_controller = null
		if ai_map.has(ai_class_name):
			var ai_script: GDScript = ai_map[ai_class_name] as GDScript
			if ai_script != null:
				ai_controller = ai_script.new()

		# Call setup with character data and AI controller.
		enemy.setup(data, ai_controller)

		# Register tile occupancy.
		GridManager.reserve_tile(grid_pos, enemy)

		# Add to scene tree.
		_characters_container.add_child(enemy)

		# Register with GameManager.
		GameManager.register_enemy(enemy)

		enemies.append(enemy)

	return enemies


# ---------------------------------------------------------------------------
# HUD wiring
# ---------------------------------------------------------------------------

## Find the HUD CanvasLayer and call its setup method with player and enemies.
func _wire_hud(player: Node, enemies: Array[Node]) -> void:
	# The HUD is on its own CanvasLayer in the main scene. Since battlefield
	# is instanced into main, we walk up to the parent (Main) which has
	# HUDLayer as a direct child.
	var hud: CanvasLayer = get_parent().get_node_or_null("HUDLayer") as CanvasLayer
	if hud == null:
		# Try alternative: search the entire scene tree from the parent.
		hud = _find_hud_recursively(get_parent())

	# setup() lives on the HUD node INSIDE the HUDLayer wrapper (the layer is a
	# plain CanvasLayer with no script), so descend to it — otherwise the HUD is
	# never initialised: health bars aren't created and skill buttons stay unbound.
	var target: Node = hud
	if hud != null and not hud.has_method("setup"):
		target = hud.get_node_or_null("HUD")

	if target != null and target.has_method("setup"):
		target.setup(player, enemies)


## Recursively search for a CanvasLayer named "HUDLayer" in the scene tree.
func _find_hud_recursively(node: Node) -> CanvasLayer:
	if node == null:
		return null
	if node.name == "HUDLayer" and node is CanvasLayer:
		return node as CanvasLayer
	for child in node.get_children():
		var result: CanvasLayer = _find_hud_recursively(child)
		if result != null:
			return result
	return null


# ---------------------------------------------------------------------------
# Tutorial overlay wiring
# ---------------------------------------------------------------------------

## Find the Tutorial CanvasLayer and pass it to TutorialManager.set_overlay().
func _wire_tutorial_overlay() -> void:
	# The TutorialLayer is a child of the parent (Main), not a direct child
	# of the Window, so look up via get_parent().
	var tutorial_layer: CanvasLayer = get_parent().get_node_or_null("TutorialLayer") as CanvasLayer
	if tutorial_layer == null:
		# Recurse to find it from the parent.
		tutorial_layer = _find_tutorial_layer_recursively(get_parent())

	if tutorial_layer != null:
		TutorialManager.set_overlay(tutorial_layer)


## Recursively search for a CanvasLayer named "TutorialLayer".
func _find_tutorial_layer_recursively(node: Node) -> CanvasLayer:
	if node == null:
		return null
	if node.name == "TutorialLayer" and node is CanvasLayer:
		return node as CanvasLayer
	for child in node.get_children():
		var result: CanvasLayer = _find_tutorial_layer_recursively(child)
		if result != null:
			return result
	return null
