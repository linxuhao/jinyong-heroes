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


## Validate one event option's deliverability (purchase all-or-nothing, R2 D4).
## Returns "" when the WHOLE option is deliverable; "silver" when the option's
## NET silver cost exceeds profile.silver; "owned" when any item effect targets
## an id already in profile.inventory. Pure arithmetic over the option's own
## effects — NO mutation, NO RNG (the deterministic-stream lifeline).
## Priority: payment capacity is checked first, then ownership.
static func validate_option(profile: PlayerProfile, opt: EventData.EventOption) -> String:
	var net_cost: int = 0
	for eff in opt.effects:
		match eff.get("type", "none"):
			"silver":
				net_cost += -int(eff.get("value", 0))
			"item":
				var target: String = eff.get("target", "")
				if target != "" and profile.inventory.has(target):
					return "owned"
	if net_cost > profile.silver:
		return "silver"
	return ""


## Apply one event option's effects — validate-then-apply (the 5 sanctioned
## types). On refusal the ENTIRE option does nothing: {"ok": false, "reason":
## "silver"|"owned"} with ZERO profile mutation (no charge without delivery,
## no delivery without charge). On success every effect applies exactly as
## before, EXCEPT the silver line loses the old maxi(..., 0) clamp — the
## balance is proven sufficient by the validation. Returns {"ok": true,
## "reason": ""}.
## Does NOT touch profile.flags, clear any id, or sync any surface — the
## seen-mark / event_id / _sync_surface bookkeeping stays with the caller.
static func apply_option_effects(profile: PlayerProfile, opt: EventData.EventOption) -> Dictionary:
	var reason: String = validate_option(profile, opt)
	if reason != "":
		return {"ok": false, "reason": reason}
	for eff in opt.effects:
		match eff.get("type", "none"):
			"silver":
				profile.silver = profile.silver + int(eff.get("value", 0))
			"attr":
				profile.add_attr(eff.get("target", ""), int(eff.get("value", 0)))
			"item":
				var target: String = eff.get("target", "")
				if target != "" and not profile.inventory.has(target):
					profile.inventory.append(target)
			"practice":
				add_practice(profile, int(eff.get("value", 0)))
	return {"ok": true, "reason": ""}


## Add practice to the player-CHOSEN gongfa (target_id) when it names an
## unmastered row; otherwise fall back to the first unmastered gongfa. Masters
## it on reaching the grade's threshold (丁4/丙6/乙8). A mastered art is never
## re-offered. The sha_po_lang transform keeps its exact order (pure arithmetic,
## zero RNG). A practice month is never silently dropped: an empty / unknown /
## already-mastered target falls back to the first unmastered row, and only a
## profile with NO unmastered rows at all no-ops (existing behavior).
## (verbatim from cultivation._add_practice; the first-unmastered scan is
## re-implemented privately here over the profile parameter)
static func add_practice(profile: PlayerProfile, amount: int, target_id: String = "") -> void:
	if profile.has_trait("sha_po_lang"):
		amount = TraitEffects.pojun_practice(amount)
	var gid: String = _resolve_target(profile, target_id)
	if gid == "":
		return
	var entry: Dictionary = profile.get_gongfa(gid)
	entry["practice"] = int(entry.get("practice", 0)) + amount
	var grade: String = entry.get("grade", "D")
	if int(entry["practice"]) >= int(ProgressionGongfaData.PRACTICE_TO_MASTER.get(grade, 4)):
		entry["mastered"] = true


## Resolve the practice target: if target_id is non-empty AND names an
## unmastered row in the profile, return it; otherwise (empty / unknown id /
## already mastered) fall back to the first unmastered id. Returns "" only when
## the profile has no unmastered rows at all. Deterministic, zero RNG — the
## caller may call this for bookkeeping and add_practice re-resolves internally
## with the same result (no mutation between the two calls).
static func _resolve_target(profile: PlayerProfile, target_id: String) -> String:
	if target_id != "":
		var entry: Dictionary = profile.get_gongfa(target_id)
		if not entry.is_empty() and not bool(entry.get("mastered", false)):
			return target_id
	return _first_unmastered_id(profile)


## True when an art id names a sect INTERNAL art — ids are
## `<sect_id>_<internal_pinyin>_<grade>` (progression_gongfa_data art-id
## convention), so the internal pinyin segment decides. External arts
## (shaolin_luohan_d) and the hand-authored 甲 pool (a_sword) return false.
## Pure data lookup, zero RNG. Used by the 练功 month's builds-the-body side
## effect (cultivation.gd): internal arts train 内力, external arts 根骨.
static func is_internal_art_id(art_id: String) -> bool:
	for row in ProgressionGongfaData.SECTS:
		if art_id.begins_with("%s_%s_" % [str(row["id"]), str(row["internal_pinyin"])]):
			return true
	return false


## First unmastered gongfa id over profile.gongfa, in order (rows with
## mastered != true and a non-empty String id); "" when none.
static func _first_unmastered_id(profile: PlayerProfile) -> String:
	for entry in profile.gongfa:
		if not bool(entry.get("mastered", false)):
			var id: Variant = entry.get("id", "")
			if id is String and id != "":
				return id as String
	return ""
