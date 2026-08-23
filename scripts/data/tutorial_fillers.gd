## Pure static helper that fills a unit's prerequisite slots with mastered
## filler arts so the real 甲乙丙丁 cascade computes 1.3 for every art on the
## unit — the 编排数值 (staged_values) replacement: tutorial numbers come out of
## the real cascade, never a bypass. Preloads gongfa_data.gd only.
##
## Fixpoint: after fill(), every art (originals AND appended fillers) has its
## full same-school lower-grade ladder AND ≥3 mastered same-attribute arts
## whenever the unit's shapes allow it (tutorial shapes: all originals are
## grade A/B). Calling fill() a second time appends nothing.

const GongfaData = preload("res://scripts/data/gongfa_data.gd")

## Mutates unit_cd.internal_arts / unit_cd.external_arts in place. Grades are
## processed DESCENDING (A→D) and the scan list is rebuilt per grade, so
## appended fillers are themselves prerequisite-closed (a B filler's C/D slots
## get their own fillers). Never touches art.fa_hui_du or unit_cd.staged_values.
static func fill(unit_cd) -> void:
	var grades: Array = ["A", "B", "C", "D"]
	for grade in grades:
		var scan: Array = _all_arts(unit_cd)
		for art in scan:
			if art == null or str(art.grade) != str(grade):
				continue
			for req_grade in GongfaData.LOWER_SLOTS.get(grade, []):
				if not _has_mastered_same_school(unit_cd, art.school, str(req_grade)):
					var filler = GongfaData.new()
					filler.grade = str(req_grade)
					filler.school = art.school
					filler.attribute = art.attribute
					filler.kind = art.kind
					filler.mastered = true
					filler.techniques = []
					filler.gongfa_name = "Filler " + str(req_grade) + " " + str(art.school)
					if str(art.kind) == "internal":
						unit_cd.internal_arts.append(filler)
					else:
						unit_cd.external_arts.append(filler)
	# Mark every art (originals and fillers) mastered. This runs after the
	# whole pass so duplicate same-grade originals do not suppress needed
	# fillers, and so the final mastered set drives the 1.3 cascade.
	for art in _all_arts(unit_cd):
		if art != null:
			art.mastered = true


## Concatenated internal+external arts, null-tolerant (plain Arrays in practice).
static func _all_arts(unit_cd) -> Array:
	var arts: Array = []
	if unit_cd != null:
		if unit_cd.internal_arts != null:
			arts += unit_cd.internal_arts
		if unit_cd.external_arts != null:
			arts += unit_cd.external_arts
	return arts


## True when the unit has at least one MASTERED art of req_grade in the given
## school across either array — the same slot rule GongfaData uses.
static func _has_mastered_same_school(unit_cd, school, req_grade: String) -> bool:
	for art in _all_arts(unit_cd):
		if art != null and str(art.grade) == req_grade \
				and str(art.school) == str(school) and art.mastered:
			return true
	return false
