class_name EquipmentData
extends RefCounted

## Equipment formula's single home (task_plan equipment_data_layer / step2_design D2).
## Pure static layer: no autoload, no scene dependency — preloadable by both
## player_profile.gd and battle_setup.gd without direction problems.
##
## Every equipment bonus comes from the constants below, keyed on CATEGORY
## (never per-item literals — the 12 card rows in card_data.gd keep their
## effect_value: 0; the effect is derived here from the id's tier).
##
## Derivation (formula shape, magnitude anchors, phase-5 re-tune surface):
##   see design/40_progression.md §9. This header intentionally points at the
##   design doc instead of duplicating the derivation in code.

const SLOTS: Array[String] = ["weapon", "armor", "boots"]
const SLOT_PREFIXES := {"weapon": "eq_sword_", "armor": "eq_armor_", "boots": "eq_boots_"}

# ---- the ONE tier->effect formula (design/40_progression.md §9) --------
const ATTACK_PER_TIER := 2          # 兵刃 weapon -> 普攻 attack
const HEALTH_PER_TIER := 5          # 护甲 armor  -> 气血 health
const INITIATIVE_PER_TIER := 2      # 鞋履 boots  -> 先攻 initiative
const MOVE_BONUS_TIER_THRESHOLD := 3
const MOVE_BONUS := 1


## Return the slot ("weapon"/"armor"/"boots") whose SLOT_PREFIXES prefix `id`
## begins with; "" when `id` is not a known equipment id. A 3-entry prefix scan
## over categories — NOT per-item literals (a 4th tier needs zero code here).
static func slot_of(id: String) -> String:
	for slot in SLOTS:
		if id.begins_with(SLOT_PREFIXES[slot]):
			return slot
	return ""


## Parse the tier from the id's numeric suffix (eq_sword_1..4 -> 1..4).
## `id.substr(id.rfind("_") + 1)` reads the suffix after the last "_";
## int() degrades malformed input silently (int("")==0, int("x")==0, and a
## missing "_" makes rfind return -1 so substr(0) takes the whole string which
## int()s to 0). Only 1..4 is accepted; anything else -> 0. Never push_error.
static func tier_of(id: String) -> int:
	var idx: int = id.rfind("_")
	var suffix: String = id.substr(idx + 1)
	var tier: int = int(suffix)
	if tier >= 1 and tier <= 4:
		return tier
	return 0


## Per-item bonus as {"attack","health","initiative","move"} (all ints).
## Direction matrix: weapon feeds attack ONLY; armor health ONLY; boots
## initiative ONLY; move ONLY for boots at tier >= MOVE_BONUS_TIER_THRESHOLD.
## Empty/unknown id -> all zeros.
static func bonuses_for(id: String) -> Dictionary:
	var t: int = tier_of(id)
	var s: String = slot_of(id)
	var out := {
		"attack": 0,
		"health": 0,
		"initiative": 0,
		"move": 0,
	}
	if s == "weapon":
		out["attack"] = ATTACK_PER_TIER * t
	elif s == "armor":
		out["health"] = HEALTH_PER_TIER * t
	elif s == "boots":
		out["initiative"] = INITIATIVE_PER_TIER * t
		if t >= MOVE_BONUS_TIER_THRESHOLD:
			out["move"] = MOVE_BONUS
	return out


## Sum the bonuses of every equipped slot. Reads each slot via defensive
## `equipped.get(slot, "")`; any non-String slot value is treated as "". This is
## derive_stats' single call site (scripts/data/battle_setup.gd).
static func sum_bonuses(equipped: Variant) -> Dictionary:
	var total := {
		"attack": 0,
		"health": 0,
		"initiative": 0,
		"move": 0,
	}
	if not (equipped is Dictionary):
		return total
	var eq: Dictionary = equipped
	for slot in SLOTS:
		var v: Variant = eq.get(slot, "")
		if not (v is String):
			v = ""
		var b: Dictionary = bonuses_for(v as String)
		total["attack"] = int(total["attack"]) + int(b.get("attack", 0))
		total["health"] = int(total["health"]) + int(b.get("health", 0))
		total["initiative"] = int(total["initiative"]) + int(b.get("initiative", 0))
		total["move"] = int(total["move"]) + int(b.get("move", 0))
	return total
