class_name EventLogic

## Shared PURE-STATIC event resolution core (design/90_decisions.md relocation
## note, jinyong-map-events round). Extracted byte-for-byte from
## scripts/segments/cultivation.gd so the cultivation 游历 channel and the map
## node-entry channel resolve events through ONE path instead of forking a
## parallel system.
##
## Contract: no `extends`, no scene, no autoload, no signal, no instance
## members. Every function operates purely on its (profile, rng) arguments.
## RNG op order is the deterministic-stream lifeline — draw_unseen_id performs
## EXACTLY one rng.randi_range call (the empty-pool reset branch performs
## zero RNG ops), identical to the original cultivation body.

const TraitEffects = preload("res://scripts/data/trait_effects.gd")


## 游历 event draw: one rng draw, no repeat until the pool is exhausted.
## (verbatim from cultivation._draw_event; the only adaptation is
## SaveManager.profile -> profile, SaveManager.rng -> rng)
static func draw_unseen_id(profile: PlayerProfile, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	for def in EventData.all():
		if not (profile.flags.get("events_seen", []) as Array).has(def.id):
			pool.append(def.id)
	if pool.is_empty():
		profile.flags["events_seen"] = []
		for def in EventData.all():
			pool.append(def.id)
	var idx: int = rng.randi_range(0, pool.size() - 1)
	return pool[idx]


## Apply one event option's effects (the 5 sanctioned types).
## (verbatim from the effect loop in cultivation._apply_event_option).
## Does NOT touch profile.flags, clear any id, or sync any surface — the
## seen-mark / event_id / _sync_surface bookkeeping stays with the caller.
static func apply_option_effects(profile: PlayerProfile, opt: EventData.EventOption) -> void:
	for eff in opt.effects:
		match eff.get("type", "none"):
			"silver":
				profile.silver = maxi(profile.silver + int(eff.get("value", 0)), 0)
			"attr":
				profile.add_attr(eff.get("target", ""), int(eff.get("value", 0)))
			"item":
				var target: String = eff.get("target", "")
				if target != "" and not profile.inventory.has(target):
					profile.inventory.append(target)
			"practice":
				add_practice(profile, int(eff.get("value", 0)))


## Add practice to the first unmastered gongfa; masters it on reaching the
## grade's threshold (丁4/丙6/乙8). A mastered art is never re-offered.
## (verbatim from cultivation._add_practice; the first-unmastered scan is
## re-implemented privately here over the profile parameter)
static func add_practice(profile: PlayerProfile, amount: int) -> void:
	if profile.has_trait("sha_po_lang"):
		amount = TraitEffects.pojun_practice(amount)
	var gid: String = _first_unmastered_id(profile)
	if gid == "":
		return
	var entry: Dictionary = profile.get_gongfa(gid)
	entry["practice"] = int(entry.get("practice", 0)) + amount
	var grade: String = entry.get("grade", "D")
	if int(entry["practice"]) >= int(ProgressionGongfaData.PRACTICE_TO_MASTER.get(grade, 4)):
		entry["mastered"] = true


## First unmastered gongfa id over profile.gongfa, in order (rows with
## mastered != true and a non-empty String id); "" when none.
static func _first_unmastered_id(profile: PlayerProfile) -> String:
	for entry in profile.gongfa:
		if not bool(entry.get("mastered", false)):
			var id: Variant = entry.get("id", "")
			if id is String and id != "":
				return id as String
	return ""
