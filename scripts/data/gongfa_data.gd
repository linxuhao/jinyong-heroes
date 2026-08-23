extends Resource

## Data-only resource defining a 功法 (gongfa) — an internal or external martial art.
## Instantiated programmatically in battlefield.gd — not saved as .tres files.
##
## Internal arts produce stat bonuses / an energy pool / passives; external arts
## produce techniques. fa_hui_du (发挥度) is computed by the real 甲乙丙丁
## prerequisite cascade (design/10_systems.md §3–§4): 前置完成度 × 属性加成,
## interval 0.6~1.3. The tutorial battle's protected 1.3 values come out of this
## same cascade — TutorialFillers.fill() populates each tutorial unit with real
## mastered filler arts so the prereqs are genuinely complete (no 特判 bypass).

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

## Mastered flag — per-unit mastery state. Resource instances carry their own
## mastery; tutorial arts are marked mastered by TutorialFillers.fill().
@export var mastered: bool = false

## Grade rank map: lower number = higher grade (A is 甲, D is 丁). Grade strings
## are compared through this map, never by string ordering.
const GRADE_RANK := {"A": 0, "B": 1, "C": 2, "D": 3}

## Lower-grade prerequisite slots per grade (design/10_systems.md §3: 丁无前置 /
## 丙=同门类丁满 / 乙=同门类丙满+丁满 / 甲=同门类乙丙丁各满). The cascade counts
## slots within this art's school only; internal arts form their own 门类.
const LOWER_SLOTS := {
	"A": ["B", "C", "D"],
	"B": ["C", "D"],
	"C": ["D"],
	"D": [],
}

## Real 发挥度 (design/10_systems.md §4): 前置完成度 × 属性加成, interval
## 0.6~1.3. The pure cascade is the ONLY path — there is no 特判 (staged) branch.
##   unit == null              -> fa_hui_du (field fallback, pre-cascade default)
##   missing = count of lower-grade prerequisite slots (same school) with no
##             mastered art of that grade in unit.internal_arts+external_arts
##   base    = [1.0, 0.85, 0.7, 0.6][clamp(missing, 0, 3)]
##             (齐全 1.0 / 缺1 0.85 / 缺2 0.7 / 缺3 0.6)
##   if base < 1.0 -> return base     (prerequisites incomplete: no attribute bonus)
##   same_attr = min(count of mastered arts (internal+external) whose attribute
##                  == self.attribute, 3)   (self counts if self.mastered)
##   return 1.0 + 0.1 * same_attr     (1.0 / 1.1 / 1.2 / 1.3)
func get_fa_hui_du(unit) -> float:
	if unit == null:
		return fa_hui_du
	var missing: int = 0
	for req_grade in LOWER_SLOTS.get(grade, []):
		if not _has_mastered_same_school(str(req_grade), unit):
			missing += 1
	var base: float = [1.0, 0.85, 0.7, 0.6][clamp(missing, 0, 3)]
	if base < 1.0:
		return base
	var same_attr: int = min(_count_mastered_same_attribute(unit), 3)
	return 1.0 + 0.1 * float(same_attr)


## True when the unit has at least one MASTERED art of the given grade in this
## art's school (a single mastered art of the required grade satisfies the slot).
func _has_mastered_same_school(req_grade: String, unit) -> bool:
	for art in _all_arts(unit):
		if art != null and str(art.grade) == req_grade \
				and str(art.school) == school and art.mastered:
			return true
	return false


## Count mastered arts (internal+external) whose attribute equals this art's
## attribute. Self counts when self.mastered. The caller caps the result at 3.
func _count_mastered_same_attribute(unit) -> int:
	var count: int = 0
	for art in _all_arts(unit):
		if art != null and str(art.attribute) == attribute and art.mastered:
			count += 1
	return count


## Concatenated internal+external arts, null-tolerant (plain Arrays in practice).
## When the unit carries `all_external_arts` (progression CharacterData built by
## BattleSetup), the FULL known external list is appended too — identity-deduped
## (same art instance already present via `external_arts`) so the cascade never
## double-counts a mastered art in _count_mastered_same_attribute. Units without
## the field (tutorial path) fall back to internal+external exactly.
func _all_arts(unit) -> Array:
	var arts: Array = []
	if unit != null:
		if unit.internal_arts != null:
			arts += unit.internal_arts
		if unit.external_arts != null:
			arts += unit.external_arts
		if "all_external_arts" in unit and unit.all_external_arts != null:
			for art in unit.all_external_arts:
				if art != null and not arts.has(art):
					arts.append(art)
	return arts
