extends Resource

## Data-only resource defining a 功法 (gongfa) — an internal or external martial art.
## Instantiated programmatically in battlefield.gd — not saved as .tres files.
##
## Internal arts produce stat bonuses / an energy pool / passives; external arts
## produce techniques. This round the fa_hui_du (发挥度) multiplier is a flat
## interface-only stub: every unit returns 1.3 in the tutorial battle. The real
## prerequisite (甲乙丙丁 cascade) calculation is NOT implemented.

@export var gongfa_name: String = ""          # English display name
@export var grade: String = ""                # "A"|"B"|"C"|"D" (甲乙丙丁)
@export var kind: String = ""                 # "internal" | "external"
@export var school: String = ""               # "sword"|"palm"|"finger"|"music"|"polearm"|"internal"
@export var attribute: String = ""            # "yin"|"yang"|"hard"|"soft"
@export var energy_provided: int = 0          # internal only (player 180, enemies 0)
@export var passive_id: String = ""           # internal only:
                                              #  "shen_diao_power"|"finger_dart"|"toad_reflect"|
                                              #  "one_yang_renewal"|"beggar_iron_bone"|"innate_qi"
@export var stat_bonuses: Dictionary = {}     # internal only; empty this round (stats given directly)
@export var techniques: Array = []            # external only; Array of SkillData
@export var fa_hui_du: float = 1.3            # multiplier applied to damage/heal/shield only

## INTERFACE-ONLY STUB. Returns this gongfa's fa_hui_du (1.3 for every unit in
## the tutorial battle). The prerequisite (甲乙丙丁 cascade) calculation is NOT
## implemented this run.
func get_fa_hui_du(_unit) -> float:
	return fa_hui_du
