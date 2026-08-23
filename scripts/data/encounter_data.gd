## Pure static encounter-battle data (design C7). A fixed sparring partner
## whose basic-attack 发挥度 is exactly 1.0 + 0.1×3 = 1.3 through the real
## cascade: four mastered D-grade arts all of attribute 阳 (one internal + one
## external + two external fillers). Deterministic, no scene tree.
## Preloads gongfa_data.gd + character_data.gd only.

const GongfaData = preload("res://scripts/data/gongfa_data.gd")
const CharacterData = preload("res://scripts/data/character_data.gd")

## Fresh CharacterData per call: fixed stats, four mastered D 阳 arts
## (internal_arts.size() == 1, external_arts.size() == 3).
static func sparring_partner() -> Resource:
	var cd = CharacterData.new()
	cd.character_name = "Sparring Partner"
	cd.display_name = "陪练弟子"
	cd.max_health = 60
	cd.attack_damage = 12
	cd.move_range = 2
	cd.initiative = 3
	cd.attack_range = 1
	cd.team = 1
	cd.ai_class = "AIControllerSparring"
	cd.skills = []
	cd.passive_id = ""
	cd.internal_arts = [_yang_art("internal", "internal", "Sparring Internal")]
	cd.external_arts = [
		_yang_art("external", "sword", "Sparring Sword"),
		_yang_art("external", "sword", "Sparring Filler 1"),
		_yang_art("external", "sword", "Sparring Filler 2"),
	]
	return cd


## Build one mastered D-grade 阳 art with empty techniques.
static func _yang_art(kind: String, school: String, name: String) -> Resource:
	var g = GongfaData.new()
	g.grade = "D"
	g.kind = kind
	g.school = school
	g.attribute = "yang"
	g.mastered = true
	g.techniques = []
	g.gongfa_name = name
	return g


## Spawn tile for the sparring partner — adjacent to the player's (7,5).
static func sparring_partner_tile() -> Vector2i:
	return Vector2i(7, 4)
