class_name MapBattleData

## Map-battle data layer for the Huashan summit finale (jinyong-huashan round).
##
## Pure static data — zero autoload dependency, mirrors the MapData / EventData /
## FacilityData data-layer pattern. Supplies the opponent roster and spawn
## positions for each consumed map battle id, fail-safe (an unknown binding is
## inert, never a crash).
##
## The only live binding today is `huashan_duel` (华山's battle slot — see
## map_data.gd:48-49). Its opponent roster is the five greats, composed entirely
## from existing enemy/character data (no new assets, no new combat system).

## Battle id -> ordered opponent roster (the `character_name` spelling the
## CombatManager.turn_order carries, spaces preserved).
const ROSTERS: Dictionary = {
	"huashan_duel": ["East Heretic", "West Poison", "South Emperor", "North Beggar", "Central Divine"],
}

## Map-battle spawn layout — OWNED here, never read from the tutorial's
## positions dict, so the tutorial battlefield stays byte-identical.
## Invariants (each tile must satisfy all of them):
##   - inside the walkable interior: col 1..13, row 1..9
##   - NOT the player spawn (7,5) and not on the player's row 5 / column 7
##     (line-caster deny)
##   - pairwise distinct
##   - REACHABILITY (R3b C5 unlock, owner ruling 2026-09-02): every great
##     spawns at Chebyshev distance 4-5 from the player spawn (7,5), so a
##     strong real-save melee hero (move_range >= 4 once mastery points feed
##     move_range in BattleSetup.derive_stats) can close to weapon range
##     INSIDE its first turn — the measured root cause of the pre-unlock
##     unwinnability was the 6-tile flanks no melee route could cross
##     (design/40_progression.md M3''). The distance-gated AI branches
##     (approach at dist > attack_range, no round-1 shot) still hold at 4-5.
##   - HUD-column ban: no tile in the HUD-shielded columns. The HUD's right-side
##     button cluster overlaps columns 12-13 (measured 2026-09-01 — Central
##     Divine at (13,1) interpenetrated the End Turn button / health bars), so
##     the rightmost column allowed is 11 (col 11 row 2 is tutorial-proven
##     clear); left columns 1-3 are tutorial-proven clear.
## Player spawn is fixed at (7,5) for every battle path (UNCHANGED by the
## unlock — the C5 geometry lever is on the enemy side only).
const PLAYER_SPAWN: Vector2i = Vector2i(7, 5)

## Layout rationale (R3b C5 unlock geometry, measured on real saves):
##   - The two global casters keep their tutorial-proven HUD-clear anchors:
##     East Heretic on col 3, Central Divine on col 11 — both at Chebyshev 4
##     from (7,5). Their round-1 casts (Tidal Melody, Primal Unity) are
##     position-independent globals, so this does not change their behavior.
##   - The three melee/ranged-gated damage units (West Poison, South Emperor,
##     North Beggar) moved from Chebyshev 5-6 on the far-left flanks to
##     Chebyshev 4-5 in columns 3-5, keeping them off the hero's row 5 /
##     column 7 line and outside the dist <= 3 AI damage band at spawn, while
##     putting every great within ONE move-and-attack of a mastery-fortified
##     melee hero. Per-great 改前/改后 rows: design/40_progression.md M3''.
const POSITIONS: Dictionary = {
	"huashan_duel": {
		"East Heretic":   Vector2i(4, 4),
		"West Poison":    Vector2i(1, 3),
		"South Emperor":  Vector2i(3, 6),
		"North Beggar":   Vector2i(1, 7),
		"Central Divine": Vector2i(2, 2),
	},
}


## The opponent roster (as `character_name` strings, in order) for a battle id.
## An unknown / typo'd / empty binding reads as [] — inert, never a crash.
static func roster_ids(battle_id: String) -> Array[String]:
	var list: Variant = ROSTERS.get(battle_id, [])
	if typeof(list) != TYPE_ARRAY:
		return []
	var out: Array[String] = []
	for name in list:
		out.append(name as String)
	return out


## The spawn tile for a battle id's named opponent. Vector2i.ZERO when the
## battle id or the name key is unknown — inert, never a crash.
static func position_for(battle_id: String, name_key: String) -> Vector2i:
	var battle_positions: Variant = POSITIONS.get(battle_id, {})
	if typeof(battle_positions) != TYPE_DICTIONARY:
		return Vector2i.ZERO
	var tile: Variant = (battle_positions as Dictionary).get(name_key, Vector2i.ZERO)
	if typeof(tile) != TYPE_VECTOR2I:
		return Vector2i.ZERO
	return tile as Vector2i
