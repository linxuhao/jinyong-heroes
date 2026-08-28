## Battlefield — Main battlefield controller
##
## Attached to battlefield.tscn. Orchestrates the full battlefield
## initialisation: terrain tile textures loaded from the generated PNG
## assets (assets/terrain/floor.png and assets/terrain/border.png),
## TileMap setup, character and skill data creation, player/enemy
## instantiation, AI wiring, HUD setup, and tutorial start.
##
## Gate verification (reverify_deployable_gates): green — terrain loads the
## generated floor.png / border.png (Image.create remains only in the
## load-failure fallback and the runtime 2x1 atlas blit); _backdrop is typed
## Sprite2D; node names (SummitBackdrop/Grid/Characters) intact.
## Documentation only, no logic changes.
extends Node2D

const SkillData = preload("res://scripts/data/skill_data.gd")
const CharacterData = preload("res://scripts/data/character_data.gd")
const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const TutorialFillers = preload("res://scripts/data/tutorial_fillers.gd")
const EncounterData = preload("res://scripts/data/encounter_data.gd")
const BattleSetup = preload("res://scripts/data/battle_setup.gd")
const AISparring = preload("res://scripts/ai/ai_sparring.gd")

# ---------------------------------------------------------------------------
# Constants (mirror GridManager for convenience)
# ---------------------------------------------------------------------------

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 15
const GRID_HEIGHT: int = 11

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _backdrop: Sprite2D = $SummitBackdrop
@onready var _tilemap: TileMap = $Grid
@onready var _grid_lines: Node2D = $GridLines
@onready var _characters_container: Node2D = $Characters

## Observable for the playtest contract: true when the SummitBackdrop sprite
## spans exactly the board rect [0,960]x[0,704] after the runtime fit (W7).
var board_aligned: bool = false

## Observable for the playtest contract: true when the GridLines overlay node
## exists and is visible (grid-cell lines drawn above backdrop/tiles).
var grid_lines_visible: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# 0. Grid overlay observable: true iff the GridLines node exists and is
	#    visible (playtest surface; set before any other wiring).
	grid_lines_visible = _grid_lines != null and _grid_lines.visible

	# 1. Load the generated terrain tile textures.
	var textures: Dictionary = _create_tile_textures()

	# 2. Build the TileSet and paint the grid.
	_setup_tilemap(textures.floor, textures.border)

	# 3. Pass TileMap to GridManager and build the AStar graph.
	GridManager.set_tilemap(_tilemap)
	GridManager.setup_grid()

	# 4. Fit the SummitBackdrop to span the board rect exactly (W7). Runs
	#    before the first frame so board_aligned is set for the playtest gate.
	_fit_backdrop_to_board()

	# Encounter mode (design C8): a CULTIVATION-context battle (battle_return_state
	# == "CULTIVATION", set by GameManager.start_encounter) has NO tutorial content.
	# Branch BEFORE the tutorial path: build the BattleSetup hero + the sparring
	# partner, never start the tutorial, and return — the tutorial character
	# factory / overlay wiring never runs.
	if GameManager.get_battle_return_state() == "CULTIVATION":
		_setup_encounter_battle()
		return

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

	# Tutorial mode flag — LAST statement of the tutorial branch: a
	# CombatManager.reset_battle() that ran during this scene's swap (SceneManager
	# teardown) defaults it to false, so the tutorial's two-phase palm unlock must
	# re-assert it after the scene is fully wired.
	CombatManager.tutorial_battle = true


# ---------------------------------------------------------------------------
# Terrain tile textures (loaded from generated PNGs)
# ---------------------------------------------------------------------------

## Load the 64×64 tile textures for floor and border from the generated
## PNG assets. Returns a Dictionary with keys "floor" and "border"
## (Texture2D values). Falls back to a plain flat-color tile (last resort)
## if a PNG is missing.
func _create_tile_textures() -> Dictionary:
	var floor_tex: Texture2D = load("res://assets/terrain/floor.png")
	var border_tex: Texture2D = load("res://assets/terrain/border.png")

	# Fallback: if a generated PNG is missing, build a plain flat-color tile
	# so the game never hard-crashes.
	if floor_tex == null:
		push_warning("Battlefield: res://assets/terrain/floor.png missing — using procedural fallback")
		var floor_img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		floor_img.fill(Color(0.3, 0.6, 0.2, 1.0))  # grass green
		floor_tex = ImageTexture.create_from_image(floor_img)
	if border_tex == null:
		push_warning("Battlefield: res://assets/terrain/border.png missing — using procedural fallback")
		var border_img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		border_img.fill(Color(0.35, 0.35, 0.35, 1.0))  # stone gray
		border_tex = ImageTexture.create_from_image(border_img)

	return {
		floor = floor_tex,
		border = border_tex,
	}


# ---------------------------------------------------------------------------
# TileMap setup
# ---------------------------------------------------------------------------

## Create a TileSet with two tiles (floor=0, border=1), assign textures,
## and paint the 15×11 grid.
func _setup_tilemap(floor_tex: Texture2D, border_tex: Texture2D) -> void:
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
# Backdrop fit to board (W7)
# ---------------------------------------------------------------------------

## Fit the SummitBackdrop sprite to exactly span the board rect [0,960]x[0,704],
## regardless of the PNG's native size, and record whether the alignment landed.
## Presentation-only: a runtime fit-to-rect transform, no art regeneration.
func _fit_backdrop_to_board() -> void:
	if _backdrop == null or _backdrop.texture == null:
		return
	var tex_size: Vector2 = _backdrop.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var board := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)  # (960, 704)
	_backdrop.scale = Vector2(board.x / tex_size.x, board.y / tex_size.y)
	_backdrop.position = board / 2.0
	var half: Vector2 = tex_size * _backdrop.scale / 2.0
	var top_left: Vector2 = _backdrop.position - half
	var bottom_right: Vector2 = _backdrop.position + half
	board_aligned = top_left.is_equal_approx(Vector2.ZERO) \
		and bottom_right.is_equal_approx(board)


# ---------------------------------------------------------------------------
# Skill data factory
# ---------------------------------------------------------------------------

## Create all SkillData resources. Returns a Dictionary keyed by skill ID.
## All values match design/20_content.md EXACTLY: damage/heal/shield are base
## values (before the fa hui du multiplier); cooldowns are in ROUNDS and tick
## at each unit's own turn start.
func _create_all_skill_data() -> Dictionary:
	var skills: Dictionary = {}

	# --- Yang Guo: Profound Iron Sword Art (hotkeys 1-4) ---
	skills["heavy_edge"] = _skill("重剑无锋",
		"单体 45 伤害,击退 1 格。冷却 1 回合。",
		63, 1, 1, "single", 0, "self", 1)
	# heavy_edge: free basic per design/20_content.md §7.1 cost table (cost stays 0)
	skills["grand_simplicity"] = _skill("大巧不工",
		"直线 3 格 38 伤害。冷却 2 回合。",
		53, 3, 2, "line", 3, "self", 0)
	skills["grand_simplicity"].cost = 15
	skills["thousand_force_cleave"] = _skill("力斩千钧",
		"十字 2 格 34 伤害。冷却 3 回合。",
		48, 2, 3, "cross", 2, "self", 0)
	skills["thousand_force_cleave"].cost = 20
	var boundless_seas = _skill("四海无量",
		"以自身为心,半径 2 格全体 70 伤害。冷却 6 回合。",
		98, 2, 6, "square", 2, "self", 0)
	boundless_seas.is_finisher = true
	boundless_seas.cost = 25
	skills["boundless_seas"] = boundless_seas

	# --- Yang Guo: Melancholy Palms (hotkeys 5-8) ---
	skills["heart_rending_strike"] = _skill("心惊肉跳",
		"单体 38 伤害。冷却 1 回合。",
		53, 1, 1, "single", 0, "self", 0)
	skills["heart_rending_strike"].cost = 10
	var dragging_mire = _skill("拖泥带水",
		"单体 25 伤害,目标下一回合移动力 −2。冷却 2 回合。",
		35, 1, 2, "single", 0, "self", 0)
	dragging_mire.status_applied = "move_minus_next_turn"
	dragging_mire.cost = 15
	skills["dragging_mire"] = dragging_mire
	var wandering_valley = _skill("徘徊空谷",
		"位移:跳 3 格,落点相邻全体 20 伤害。冷却 3 回合。",
		28, 3, 3, "adjacent", 0, "landing", 0)
	wandering_valley.jump_tiles = 3
	wandering_valley.cost = 20
	skills["wandering_valley"] = wandering_valley
	var seventeen_forms = _skill("黯然销魂十七式",
		"相邻全体 70 伤害,击退 2 格。需气血低于 50%。冷却 8 回合。",
		98, 0, 8, "adjacent", 0, "self", 2)
	seventeen_forms.hp_gate_below_ratio = 0.5
	seventeen_forms.is_finisher = true
	seventeen_forms.cost = 30
	skills["seventeen_melancholy_forms"] = seventeen_forms

	# --- East Heretic: Tidal Melody Tune ---
	skills["falling_petals"] = _skill("Falling Petals",
		"以目标格为中心的 3×3 范围攻击。冷却 2 回合。",
		14, 3, 2, "square", 1, "target", 0)
	var jade_flute_acupoint = _skill("Jade Flute Acupoint",
		"封锁目标下一回合的招式。冷却 3 回合。",
		20, 1, 3, "single", 0, "self", 0)
	jade_flute_acupoint.status_applied = "no_techniques_next_turn"
	skills["jade_flute_acupoint"] = jade_flute_acupoint
	var peach_blossom_maze = _skill("Peach Blossom Maze",
		"在自身周围(半径 2)布下迷阵,进入者减速。冷却 4 回合。",
		0, 2, 4, "square", 2, "self", 0)
	peach_blossom_maze.status_applied = "hazard_zone"
	skills["peach_blossom_maze"] = peach_blossom_maze
	var tidal_melody = _skill("Tidal Melody",
		"全场旋律,降低所有目标先攻 2 回合。冷却 6 回合。",
		18, 0, 6, "global", 0, "self", 0)
	tidal_melody.status_applied = "init_minus_20"
	skills["tidal_melody"] = tidal_melody

	# --- West Poison: Spirit Serpent Fist ---
	var spirit_serpent = _skill("Spirit Serpent",
		"带毒的单体攻击。冷却 2 回合。",
		24, 1, 2, "single", 0, "self", 0)
	spirit_serpent.status_applied = "poison"
	spirit_serpent.dot_damage = 8
	spirit_serpent.dot_rounds = 2
	skills["spirit_serpent"] = spirit_serpent
	var toad_squat = _skill("Toad Squat",
		"增益自身:下一回合第一招伤害 ×1.5。冷却 3 回合。",
		0, 0, 3, "single", 0, "self", 0)
	toad_squat.status_applied = "toad_charge"
	skills["toad_squat"] = toad_squat
	var poison_sand_palm = _skill("Poison Sand Palm",
		"以自身为中心的十字攻击,附加中毒。冷却 3 回合。",
		18, 1, 3, "cross", 1, "self", 0)
	poison_sand_palm.status_applied = "poison"
	poison_sand_palm.dot_damage = 6
	poison_sand_palm.dot_rounds = 2
	skills["poison_sand_palm"] = poison_sand_palm
	skills["toad_swarm"] = _skill("Toad Swarm",
		"直线 4 格攻击,附带重击退。冷却 5 回合。",
		40, 4, 5, "line", 4, "self", 2)

	# --- South Emperor: Solar Finger Art ---
	var solar_finger = _skill("Solar Finger",
		"远程指法,无视减伤。冷却 2 回合。",
		30, 2, 2, "single", 0, "self", 0)
	solar_finger.ignore_damage_reduction = true
	skills["solar_finger"] = solar_finger
	var acupoint_lock = _skill("Acupoint Lock",
		"封锁目标下一回合的移动。冷却 3 回合。",
		12, 2, 3, "single", 0, "self", 0)
	acupoint_lock.status_applied = "no_move_next_turn"
	skills["acupoint_lock"] = acupoint_lock
	var primal_breath = _skill("Primal Breath",
		"治疗自身或一名友方。冷却 4 回合。",
		0, 1, 4, "single", 0, "self", 0)
	primal_breath.heal_amount = 35
	primal_breath.target_friendly = true
	skills["primal_breath"] = primal_breath
	skills["six_pulse_volley"] = _skill("Six-Pulse Volley",
		"远程六脉齐发,直线 3 格。冷却 6 回合。",
		34, 3, 6, "line", 3, "self", 0)

	# --- North Beggar: Twenty-One Dragon Palms ---
	skills["proud_dragon_regret"] = _skill("Proud Dragon Regret",
		"带击退的单体掌法。冷却 2 回合。",
		36, 1, 2, "single", 0, "self", 2)
	var flying_dragon = _skill("Flying Dragon",
		"跳 3 格,落点 3×3 范围攻击。冷却 3 回合。",
		22, 3, 3, "square", 1, "landing", 0)
	flying_dragon.jump_tiles = 3
	skills["flying_dragon"] = flying_dragon
	skills["dragon_in_the_field"] = _skill("Dragon in the Field",
		"直线 3 格攻击,附带击退。冷却 4 回合。",
		30, 3, 4, "line", 3, "self", 1)
	skills["hidden_dragon"] = _skill("Hidden Dragon",
		"以自身为中心半径 2 的冲击波,附带击退。冷却 6 回合。",
		48, 2, 6, "square", 2, "self", 2)

	# --- North Beggar: Dog-Beating Staff ---
	skills["dog_beating_trip"] = _skill("Dog-Beating Trip",
		"远程打狗棒法绊击。冷却 2 回合。",
		18, 2, 2, "single", 0, "self", 0)
	skills["dog_beating_poke"] = _skill("Dog-Beating Poke",
		"远程打狗棒法点戳。冷却 2 回合。",
		20, 2, 2, "single", 0, "self", 0)
	skills["dog_beating_seal"] = _skill("Dog-Beating Seal",
		"远程打狗棒法封击。冷却 2 回合。",
		22, 2, 2, "single", 0, "self", 0)

	# --- Central Divine: Quanzhen Sword Art ---
	skills["quanzhen_sword"] = _skill("Quanzhen Sword",
		"单体剑击。冷却 1 回合。",
		32, 1, 1, "single", 0, "self", 0)
	skills["seven_stars"] = _skill("Seven Stars",
		"以自身为中心的十字 2 格攻击。冷却 3 回合。",
		26, 2, 3, "cross", 2, "self", 0)
	var qi_aegis = _skill("Qi Aegis",
		"为自己加持吸收 50 伤害的护盾,持续 3 回合。冷却 5 回合。",
		0, 0, 5, "single", 0, "self", 0)
	qi_aegis.shield_amount = 50
	qi_aegis.shield_rounds = 3
	skills["qi_aegis"] = qi_aegis
	var primal_unity = _skill("Primal Unity",
		"全体攻击,并驱散敌方增益。冷却 7 回合。",
		30, 0, 7, "global", 0, "self", 0)
	primal_unity.status_applied = "dispel_hostile_buffs"
	skills["primal_unity"] = primal_unity

	return skills


## Build a SkillData resource with explicit values (see _create_all_skill_data
## for field conventions). Special fields (dot, shield, jump, status, gates)
## are set by the caller after this returns.
func _skill(name: String, desc: String, damage: int, range: int, cooldown: int,
		shape: String, size: int, origin: String, knockback: int):
	var skill = SkillData.new()
	skill.skill_name = name
	skill.description = desc
	skill.damage = damage
	skill.range = range
	skill.cooldown = cooldown
	skill.aoe_shape = shape
	skill.aoe_size = size
	skill.aoe_origin = origin
	skill.knockback = knockback
	return skill


# ---------------------------------------------------------------------------
# Character data factory
# ---------------------------------------------------------------------------

## Create all GongfaData (internal/external arts) and CharacterData resources.
## Returns a Dictionary keyed by character_name. Stats match
## design/20_content.md EXACTLY (values given directly, no derived formulas);
## every unit's fa_hui_du stays at the GongfaData default of 1.3.
func _create_all_character_data(all_skills: Dictionary) -> Dictionary:
	var chars: Dictionary = {}
	var s: Dictionary = all_skills

	# ------------------------------------------------------------------
	# Gongfa (one internal art + the listed external arts per unit)
	# ------------------------------------------------------------------
	var gongfa: Dictionary = {}

	# Yang Guo
	var nine_yin = _gongfa("Nine Yin Manual (Fragment)", "A", "internal", "internal", "yang", 180, "shen_diao_power")
	gongfa["nine_yin_manual"] = nine_yin
	var iron_sword = _gongfa("Profound Iron Sword Art", "A", "external", "sword", "hard", 0, "")
	iron_sword.techniques = [s["heavy_edge"], s["grand_simplicity"], s["thousand_force_cleave"], s["boundless_seas"]]
	gongfa["profound_iron_sword"] = iron_sword
	var melancholy_palms = _gongfa("Melancholy Palms", "A", "external", "palm", "yin", 0, "")
	melancholy_palms.techniques = [s["heart_rending_strike"], s["dragging_mire"], s["wandering_valley"], s["seventeen_melancholy_forms"]]
	gongfa["melancholy_palms"] = melancholy_palms

	# East Heretic
	var tidal_art = _gongfa("Tidal Melody Art", "A", "internal", "internal", "yin", 0, "finger_dart")
	gongfa["tidal_melody_art"] = tidal_art
	var tidal_tune = _gongfa("Tidal Melody Tune", "A", "external", "music", "yin", 0, "")
	tidal_tune.techniques = [s["falling_petals"], s["jade_flute_acupoint"], s["peach_blossom_maze"], s["tidal_melody"]]
	gongfa["tidal_melody_tune"] = tidal_tune

	# West Poison
	var toad_art = _gongfa("Toad Art", "A", "internal", "internal", "hard", 0, "toad_reflect")
	gongfa["toad_art"] = toad_art
	var serpent_fist = _gongfa("Spirit Serpent Fist", "A", "external", "palm", "hard", 0, "")
	serpent_fist.techniques = [s["spirit_serpent"], s["toad_squat"], s["poison_sand_palm"], s["toad_swarm"]]
	gongfa["spirit_serpent_fist"] = serpent_fist

	# South Emperor
	var primal_art = _gongfa("Primal Art", "A", "internal", "internal", "soft", 0, "one_yang_renewal")
	gongfa["primal_art"] = primal_art
	var solar_art = _gongfa("Solar Finger Art", "A", "external", "finger", "yang", 0, "")
	solar_art.techniques = [s["solar_finger"], s["acupoint_lock"], s["primal_breath"], s["six_pulse_volley"]]
	gongfa["solar_finger_art"] = solar_art

	# North Beggar
	var chaos_art = _gongfa("Chaos Art", "A", "internal", "internal", "yang", 0, "beggar_iron_bone")
	gongfa["chaos_art"] = chaos_art
	var dragon_palms = _gongfa("Twenty-One Dragon Palms", "A", "external", "palm", "yang", 0, "")
	dragon_palms.techniques = [s["proud_dragon_regret"], s["flying_dragon"], s["dragon_in_the_field"], s["hidden_dragon"]]
	gongfa["twenty_one_dragon_palms"] = dragon_palms
	var dog_staff = _gongfa("Dog-Beating Staff", "B", "external", "polearm", "yang", 0, "")
	dog_staff.techniques = [s["dog_beating_trip"], s["dog_beating_poke"], s["dog_beating_seal"]]
	gongfa["dog_beating_staff"] = dog_staff

	# Central Divine
	var primal_quanzhen = _gongfa("Primal Art (Quanzhen)", "A", "internal", "internal", "yang", 0, "innate_qi")
	gongfa["primal_art_quanzhen"] = primal_quanzhen
	var quanzhen_art = _gongfa("Quanzhen Sword Art", "A", "external", "sword", "yang", 0, "")
	quanzhen_art.techniques = [s["quanzhen_sword"], s["seven_stars"], s["qi_aegis"], s["primal_unity"]]
	gongfa["quanzhen_sword_art"] = quanzhen_art

	# ------------------------------------------------------------------
	# Characters — Yang Guo first, then the Five Greats (this is the
	# initiative tie-break order, preserved by the registration below)
	# ------------------------------------------------------------------
	# Yang Guo (player)
	var cd = CharacterData.new()
	cd.character_name = "Yang Guo"
	cd.display_name = "杨过"
	cd.max_health = 1000
	cd.move_range = 4
	cd.attack_damage = 30
	cd.attack_range = 1
	cd.initiative = 88
	cd.energy = 180
	cd.team = 0
	cd.passive_id = "shen_diao_power"
	cd.internal_arts = [nine_yin]
	cd.external_arts = [iron_sword, melancholy_palms]
	cd.skills = iron_sword.techniques + melancholy_palms.techniques
	cd.ai_class = ""
	cd.color = Color(0.2, 0.5, 1.0, 1.0)  # blue
	chars["Yang Guo"] = cd

	# East Heretic (东邪黄药师)
	cd = CharacterData.new()
	cd.character_name = "East Heretic"
	cd.display_name = "黄药师"
	cd.max_health = 95
	cd.move_range = 4
	cd.attack_damage = 22
	cd.attack_range = 3
	cd.initiative = 85
	cd.energy = 0
	cd.team = 1
	cd.passive_id = "finger_dart"
	cd.internal_arts = [tidal_art]
	cd.external_arts = [tidal_tune]
	cd.skills = tidal_tune.techniques
	cd.ai_class = "AIControllerEastHeretic"
	cd.color = Color(0.2, 0.8, 0.2, 1.0)  # green
	chars["East Heretic"] = cd

	# West Poison (西毒欧阳锋)
	cd = CharacterData.new()
	cd.character_name = "West Poison"
	cd.display_name = "欧阳锋"
	cd.max_health = 115
	cd.move_range = 3
	cd.attack_damage = 26
	cd.attack_range = 1
	cd.initiative = 70
	cd.energy = 0
	cd.team = 1
	cd.passive_id = "toad_reflect"
	cd.internal_arts = [toad_art]
	cd.external_arts = [serpent_fist]
	cd.skills = serpent_fist.techniques
	cd.ai_class = "AIControllerWestPoison"
	cd.color = Color(0.7, 0.2, 0.7, 1.0)  # purple
	chars["West Poison"] = cd

	# South Emperor (南帝段智兴)
	cd = CharacterData.new()
	cd.character_name = "South Emperor"
	cd.display_name = "段智兴"
	cd.max_health = 100
	cd.move_range = 3
	cd.attack_damage = 24
	cd.attack_range = 2
	cd.initiative = 76
	cd.energy = 0
	cd.team = 1
	cd.passive_id = "one_yang_renewal"
	cd.internal_arts = [primal_art]
	cd.external_arts = [solar_art]
	cd.skills = solar_art.techniques
	cd.ai_class = "AIControllerSouthEmperor"
	cd.color = Color(0.9, 0.8, 0.2, 1.0)  # gold
	chars["South Emperor"] = cd

	# North Beggar (北丐洪七公)
	cd = CharacterData.new()
	cd.character_name = "North Beggar"
	cd.display_name = "洪七公"
	cd.max_health = 120
	cd.move_range = 3
	cd.attack_damage = 28
	cd.attack_range = 1
	cd.initiative = 74
	cd.energy = 0
	cd.team = 1
	cd.passive_id = "beggar_iron_bone"
	cd.internal_arts = [chaos_art]
	cd.external_arts = [dragon_palms, dog_staff]
	cd.skills = dragon_palms.techniques + dog_staff.techniques
	cd.ai_class = "AIControllerNorthBeggar"
	cd.color = Color(0.8, 0.4, 0.1, 1.0)  # orange
	chars["North Beggar"] = cd

	# Central Divine (中神通王重阳)
	cd = CharacterData.new()
	cd.character_name = "Central Divine"
	cd.display_name = "王重阳"
	cd.max_health = 130
	cd.move_range = 3
	cd.attack_damage = 26
	cd.attack_range = 1
	cd.initiative = 80
	cd.energy = 0
	cd.team = 1
	cd.passive_id = "innate_qi"
	cd.internal_arts = [primal_quanzhen]
	cd.external_arts = [quanzhen_art]
	cd.skills = quanzhen_art.techniques
	cd.ai_class = "AIControllerCentralDivine"
	cd.color = Color(0.9, 0.9, 0.9, 1.0)  # white
	chars["Central Divine"] = cd

	# Tutorial units' prerequisites are 视为已满 (design/20_content.md §1): fill
	# each unit with real mastered B/C/D filler arts so the real 甲乙丙丁 cascade
	# computes the flat 1.3 (round(v * 1.3)) for every art — the flat-1.3
	# short-circuit bypass is gone. Protected playtest values stay byte-identical
	# because the cascade output for these units is exactly 1.3.
	for unit_cd in chars.values():
		TutorialFillers.fill(unit_cd)

	return chars


## Build a GongfaData resource with explicit values. External arts get their
## techniques array attached by the caller; internal arts carry the passive id.
func _gongfa(gongfa_name: String, grade: String, kind: String, school: String,
		attribute: String, energy: int, passive_id: String):
	var gf = GongfaData.new()
	gf.gongfa_name = gongfa_name
	gf.grade = grade
	gf.kind = kind
	gf.school = school
	gf.attribute = attribute
	gf.energy_provided = energy
	gf.passive_id = passive_id
	return gf


# ---------------------------------------------------------------------------
# Encounter battle setup (design C8)
# ---------------------------------------------------------------------------

## Encounter mode entry (battle_return_state == "CULTIVATION"): build the player
## from the live cultivation profile via BattleSetup, spawn the sparring partner
## at its fixed tile, wire the HUD, and — critically — NEVER start the tutorial
## (no overlay, no step gating). Round 1 is kicked off by THIS scene: the last
## statement queues CombatManager.begin_battle() (deferred, AFTER the HUD wiring
## in FIFO order), which starts the round only once both units are registered.
## GameManager.start_encounter() emits battle_started BEFORE this scene exists
## (while the roster is still empty), so its synchronous kick is skipped there;
## begin_battle() self-guards (phase IDLE + non-empty roster) so the deferred
## flush here is the single place the encounter round starts. All AI/hazard/
## status wiring stays shared with the tutorial path.
func _setup_encounter_battle() -> void:
	# A CULTIVATION battle always has a profile; guard anyway so a stray scene
	# load never hard-crashes.
	if SaveManager.profile == null:
		push_warning("Battlefield: encounter battle requested without a profile — aborting encounter setup")
		return

	# Encounter battles never phase-lock / gate input: reset_battle() already
	# defaults this to false, but re-assert it in case a tutorial battle's flag
	# leaked into this scene's teardown.
	CombatManager.tutorial_battle = false

	# Guarded stale-ref cleanup BEFORE registering the fresh units: a previous
	# battle's freed nodes may still be registered here (set_player is
	# first-call-wins — a stale _player would silently swallow this fresh one,
	# and register_enemy does not dedupe freed nodes, so get_enemies_alive()
	# could carry dead nodes into the turn engine). release_stale_units() clears
	# only freed references — live data is untouched and nothing is freed here
	# (scene teardown owns the free).
	GameManager.release_stale_units()

	# Player: derived from the cultivation profile through the shared
	# battle-setup path (stats, arts mirrored with mastered flags, traits copied,
	# equip cap 2 / 3).
	var player_cd = BattleSetup.build_character(SaveManager.profile)
	var player_node: Node = _instantiate_player(player_cd)

	# Sparring partner: one fixed enemy via its OWN helper (NOT the tutorial
	# positions dict / ai_map — the tutorial enemy layout is untouched).
	var enemy_node: Node = _instantiate_sparring_partner()

	# Wire the HUD SYNCHRONOUSLY: this function runs during battlefield _ready,
	# long after main.tscn's HUD entered the tree, so HUDLayer/HUD are already
	# addressable and their @onready vars are resolved — HUD.setup() creates
	# SkillButton1..12 and the health bars BEFORE begin_battle's deferred flush
	# below. The teardown's clear_battle_refs() already ran in _do_swap before
	# this scene was instantiated, so no post-wire clear can race it. If the HUD
	# is somehow unreachable yet, fall back to the deferred wire (today's
	# behaviour) so the buttons still appear in the same frame.
	var wired: bool = _wire_hud(player_node, [enemy_node])
	if not wired:
		_wire_hud.call_deferred(player_node, [enemy_node])

	# Kick off round 1 deferred AFTER the wiring: Godot's MessageQueue flushes
	# call_deferred FIFO within the same frame, so HUD.setup() (buttons + signal
	# listeners) runs BEFORE round_started / turn_started fire — the same
	# ordering the tutorial path has (HUD wired, then battle starts).
	# begin_battle() self-guards (phase IDLE + non-empty roster), so the
	# profile-null early return and any stray scene load can never reach the
	# empty-round stall guard.
	CombatManager.begin_battle.call_deferred()


## Instantiate the sparring partner (EncounterData.sparring_partner) at its
## fixed tile, mirroring the tutorial enemy-instantiation flow: setup, guarded
## field wires, tile reservation, surface-addressable node name BEFORE
## add_child, then registration with GameManager. The AI is the trivial wait-AI
## (ai_sparring.gd) — it never moves or attacks, so the player has a clean
## damage dummy for the 发挥度 comparison.
func _instantiate_sparring_partner() -> Node:
	var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
	var enemy: Node = enemy_scene.instantiate()

	var data = EncounterData.sparring_partner()
	var grid_pos: Vector2i = EncounterData.sparring_partner_tile()

	enemy.grid_pos = grid_pos
	enemy.position = GridManager.grid_to_world(grid_pos)

	# Trivial wait-AI: evaluate() always returns {} so the partner stands still.
	enemy.setup(data, AISparring.new())

	# Wire the CharacterData fields onto the node. Guarded with `in` checks:
	# enemy.gd declares these vars, so the assignment is a no-op until then.
	if "initiative" in enemy:
		enemy.initiative = data.initiative
	if "energy" in enemy:
		enemy.energy = data.energy
	if "team" in enemy:
		enemy.team = data.team
	if "passive_id" in enemy:
		enemy.passive_id = data.passive_id
	if "traits" in enemy:
		enemy.traits = data.traits

	# Register tile occupancy.
	GridManager.reserve_tile(grid_pos, enemy)

	# Surface-addressable node name (playtest contract). Set before add_child so
	# the node enters the tree already named.
	enemy.name = "Sparring_Partner"

	# Add to scene tree.
	_characters_container.add_child(enemy)

	# Register with GameManager.
	GameManager.register_enemy(enemy)

	return enemy


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

	# Wire the new CharacterData fields (initiative/energy/team/passive_id)
	# onto the node. Guarded with `in` checks: player.gd declares these vars in
	# a sibling task, so the assignment is a no-op until they land.
	if "initiative" in player:
		player.initiative = data.initiative
	if "energy" in player:
		player.energy = data.energy
	if "team" in player:
		player.team = data.team
	if "passive_id" in player:
		player.passive_id = data.passive_id
	if "traits" in player:
		player.traits = data.traits

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

	# Starting grid positions for each enemy. All rows obey the board rule
	# MIN_LEGAL_ROW == 3 (grid_manager.gd): a 96x128 portrait anchored at a
	# unit's feet has its ink top at feet_y - 128, and feet_y must sit low
	# enough that the ink top stays at/above BOARD_TOP_MARGIN_Y = 92, i.e.
	# row >= ceil((92 + 128 - 32) / 64) = ceil(2.9375) = 3. Rows 0..2 would
	# push the art DOWN off its own tile, so Central_Divine moves (7,1)->(7,3),
	# East_Heretic (3,2)->(3,4), West_Poison (11,2)->(11,4) — formation shape
	# preserved (East/West same row; South/North same row; Central column-7 topmost).
	var positions: Dictionary = {
		"East Heretic":   Vector2i(3, 4),
		"West Poison":    Vector2i(11, 4),
		"South Emperor":  Vector2i(3, 8),
		"North Beggar":   Vector2i(11, 8),
		"Central Divine": Vector2i(7, 3),
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

		# Wire the new CharacterData fields (initiative/energy/team/passive_id)
		# onto the node. Guarded with `in` checks: enemy.gd declares these vars
		# in a sibling task, so the assignment is a no-op until they land.
		if "initiative" in enemy:
			enemy.initiative = data.initiative
		if "energy" in enemy:
			enemy.energy = data.energy
		if "team" in enemy:
			enemy.team = data.team
		if "passive_id" in enemy:
			enemy.passive_id = data.passive_id
		if "traits" in enemy:
			enemy.traits = data.traits

		# Register tile occupancy.
		GridManager.reserve_tile(grid_pos, enemy)

		# Unique, surface-addressable node name for the playtest contract
		# (e.g. "East Heretic" → "East_Heretic"). Set before add_child so
		# the node enters the tree already named.
		enemy.name = data.character_name.replace(" ", "_")

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
## Returns true iff a HUD target was found and target.setup(player, enemies)
## was actually called — the encounter path uses this to choose between the
## synchronous wire and the deferred fallback. The tutorial call site ignores
## the return value (call_deferred discards it), so its behaviour is unchanged.
func _wire_hud(player: Node, enemies: Array[Node]) -> bool:
	# The HUD is on its own CanvasLayer in the main scene. Since battlefield
	# is instanced into main, we walk up to the parent (Main) which has
	# HUDLayer as a direct child.
	var hud: CanvasLayer = get_parent().get_node_or_null("HUDLayer") as CanvasLayer
	if hud == null:
		# Try alternative: search the entire scene tree from the parent.
		hud = _find_hud_recursively(get_parent())
	if hud == null:
		# Persistent-shell layout: this battlefield lives under the shell's
		# SceneHost (a SIBLING of HUDLayer), so a parent-scoped search cannot
		# reach HUDLayer — fall back to a root-wide search.
		hud = _find_hud_recursively(get_tree().root)

	# setup() lives on the HUD node INSIDE the HUDLayer wrapper (the layer is a
	# plain CanvasLayer with no script), so descend to it — otherwise the HUD is
	# never initialised: health bars aren't created and skill buttons stay unbound.
	var target: Node = hud
	if hud != null and not hud.has_method("setup"):
		target = hud.get_node_or_null("HUD")

	if target != null and target.has_method("setup"):
		target.setup(player, enemies)
		return true
	return false


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
	if tutorial_layer == null:
		# Persistent-shell layout: battlefield is hosted under SceneHost, so the
		# parent-scoped search cannot reach the shell's TutorialLayer — fall back
		# to a root-wide search.
		tutorial_layer = _find_tutorial_layer_recursively(get_tree().root)

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
