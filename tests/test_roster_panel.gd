## Unit tests for the read-only roster panel's pure string builder
## (scripts/ui/roster_panel.gd).
##
## These are PURE _compose_body / resolver / read-only pins — NO scene boot. A
## bare RosterPanel instance (never added to a scene tree) is used so node wiring
## is never required; _compose_body(p) is called directly on it.
##
## Contract: plain GDScript (NO extends), top-level `static func run() -> bool`,
## push_error() on failure, print PASS/FAIL at the end, never assert(). Collected
## by tests/unit_test_runner.gd's TESTS registry.
##
## Numeric pins are RELATIONAL / structural (练度 cap derived from
## PRACTICE_TO_MASTER, not a literal game value); the only content literals are
## name / text-correspondence pins (青锋剑, 易筋经, 大成, （无）) — the sanctioned
## exception for a display panel.

const RosterPanelScript = preload("res://scripts/ui/roster_panel.gd")
const PlayerProfileScript = preload("res://scripts/data/player_profile.gd")


static func run() -> bool:
	# The panel composes Chinese source strings through tr(). Pin the active
	# locale to zh_CN so tr() returns the keys (Chinese) verbatim regardless of
	# the headless host's OS locale — a CI box with locale "en" would otherwise
	# translate every composed token and redden the Chinese text pins. Restore
	# the original after so a sibling test's locale assumptions are untouched.
	var orig_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var ok: bool = true
	ok = _test_item_resolution(ok)
	ok = _test_unknown_item_degrade(ok)
	ok = _test_empty_states(ok)
	ok = _test_gongfa_row(ok)
	ok = _test_purity(ok)
	ok = _test_read_only(ok)
	ok = _test_no_cursor_markers(ok)
	TranslationServer.set_locale(orig_locale)
	if ok:
		print("PASS test_roster_panel")
	else:
		print("FAIL test_roster_panel")
	return ok


## (a) crafted profile with inventory ["eq_sword_3"] -> body contains 青锋剑.
static func _test_item_resolution(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	var p: PlayerProfile = PlayerProfileScript.new_default()
	p.inventory.append("eq_sword_3")
	var body: String = panel._compose_body(p)
	if not body.contains("青锋剑"):
		push_error("roster: inventory eq_sword_3 did not render 青锋剑; body=%s" % body)
		return false
	return ok


## (b) unknown id -> body contains the raw id; no crash (degrade, never invent).
static func _test_unknown_item_degrade(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	var p: PlayerProfile = PlayerProfileScript.new_default()
	p.inventory.append("definitely_not_an_id")
	var body: String = panel._compose_body(p)
	if not body.contains("definitely_not_an_id"):
		push_error("roster: unknown item id not degraded to raw id; body=%s" % body)
		return false
	return ok


## (c) fresh/default profile -> all three sections render with honest （无） rows.
static func _test_empty_states(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	var p: PlayerProfile = PlayerProfileScript.new_default()
	var body: String = panel._compose_body(p)
	for section in ["人物", "功法", "物品"]:
		if not body.contains(section):
			push_error("roster: empty body missing section %s; body=%s" % [section, body])
			return false
	# Three-section pin: the panel has exactly 人物/功法/物品 sections; if a
	# future section is added this count must be updated together.
	if body.count("（无）") < 3:
		push_error("roster: empty profile did not render three （无） rows; body=%s" % body)
		return false
	return ok


## (d) gongfa row: display name + 练度 practice/cap (cap from PRACTICE_TO_MASTER);
## mastered -> 大成 marker; grade "" -> practice shown without cap, no crash.
static func _test_gongfa_row(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	# Resolvable id shaolin_yijin_c (易筋经·精进) with grade C (cap 6).
	var p: PlayerProfile = PlayerProfileScript.new_default()
	p.add_gongfa("shaolin_yijin_c", "C")
	var entry: Dictionary = p.get_gongfa("shaolin_yijin_c")
	entry["practice"] = 3
	var body: String = panel._compose_body(p)
	if not body.contains("易筋经"):
		push_error("roster: gongfa display name missing; body=%s" % body)
		return false
	if not body.contains("练度 3/6"):
		push_error("roster: gongfa practice/cap missing (want 练度 3/6); body=%s" % body)
		return false
	# mastered:true -> 大成 marker appended.
	entry["mastered"] = true
	var body_m: String = panel._compose_body(p)
	if not body_m.contains("大成"):
		push_error("roster: mastered marker missing; body=%s" % body_m)
		return false
	# grade:"" -> practice shown WITHOUT a cap and no crash.
	var p2: PlayerProfile = PlayerProfileScript.new_default()
	p2.gongfa.append({"id": "shaolin_yijin_c", "grade": "", "practice": 5, "mastered": false})
	var body2: String = panel._compose_body(p2)
	if not body2.contains("练度 5"):
		push_error("roster: grade '' should show practice without cap; body=%s" % body2)
		return false
	if body2.contains("/"):
		push_error("roster: grade '' should show NO cap (found '/' in body); body=%s" % body2)
		return false
	return ok


## (e) purity: same profile twice -> byte-identical string.
static func _test_purity(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	var p: PlayerProfile = PlayerProfileScript.new_default()
	p.inventory.append("eq_sword_3")
	p.add_gongfa("shaolin_yijin_c", "C")
	p.add_trait("ambidextrous")
	p.cultivation["sect_id"] = "shaolin"
	var b1: String = panel._compose_body(p)
	var b2: String = panel._compose_body(p)
	if b1 != b2:
		push_error("roster: _compose_body not pure (same profile -> different strings)")
		return false
	return ok


## (f) read-only: open()+close() on a bare instance leave the live profile
## bit-identical (no save write, no counters touched).
static func _test_read_only(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	var before: Dictionary = SaveManager.profile.to_dict()
	panel.open()
	panel.close()
	var after: Dictionary = SaveManager.profile.to_dict()
	if JSON.stringify(before) != JSON.stringify(after):
		push_error("roster: open()/close() mutated the live profile (read-only violated)")
		return false
	return ok


## (g) no composed body ever contains a ▶ cursor marker (cursor_markers_visible
## must stay false for empty, item-filled, gongfa-filled and hostile rows).
static func _test_no_cursor_markers(ok: bool) -> bool:
	var panel = RosterPanelScript.new()
	var bodies: Array[String] = [
		panel._compose_body(PlayerProfileScript.new_default()),
	]
	var p: PlayerProfile = PlayerProfileScript.new_default()
	p.inventory.append("eq_sword_3")
	p.add_gongfa("shaolin_yijin_c", "C")
	p.add_trait("ambidextrous")
	bodies.append(panel._compose_body(p))
	var p2: PlayerProfile = PlayerProfileScript.new_default()
	p2.gongfa.append({"id": "bad_id", "grade": "", "practice": 5, "mastered": false})
	p2.inventory.append("unknown_item_id")
	bodies.append(panel._compose_body(p2))
	for b in bodies:
		if b.contains("▶"):
			push_error("roster: composed body contains a ▶ cursor marker; body=%s" % b)
			return false
	return ok
