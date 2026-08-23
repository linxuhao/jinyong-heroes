## CultivationScreen — segment 5: the 36-month cultivation loop.
##
## Month flow (all keyboard-driven; every rendered string Chinese):
##   year 2/3 month 1 -> YEAR_AUGMENT (3 yearly cards) -> CARD_PICK
##   CARD_PICK  (3 monthly cards, one per category) -> apply picked card
##   ACTION_PICK (练功/修习/做工/游历 + menu row 存盘/读档/删档)
##   GONGFA_PICK (first unmastered autofocused) / ATTR_PICK / EVENT / immediate
##   month 12 -> YEAR_END (留下/换门派); month 36 -> MAP
##
## _apply_month-style helpers: _apply_card / _apply_action / _after_action are
## the ONLY paths that consume a month's card + action, and the unbound DEBUG
## action `debug_fast_forward` drives the same phase machine with fixed
## auto-choices (first card; 练功 on the first unmastered gongfa else 修习 根骨;
## year-end stay) — same RNG draws as manual play, same determinism.
##
## RNG discipline: every draw goes through SaveManager.rng in operation order
## (card draws inside SaveManager.draw_cards, 修习 gain, 游历 event draw).
extends Control

const TraitEffects = preload("res://scripts/data/trait_effects.gd")

## Debug-grant school -> external A art id (GongfaData carries no id field;
## ids are row-derived, hence the const map; see _debug_grant_art).
const _A_ID_BY_SCHOOL := {
	"sword": "a_sword",
	"palm": "a_palm",
	"polearm": "a_polearm",
	"dart": "a_dart",
}

## Surface: cultivation year (1..3).
var year: int = 1

## Surface: cultivation month (1..12).
var month: int = 1

## Surface: current sect id (profile.cultivation.sect_id).
var sect_id: String = ""

## Surface: "YEAR_AUGMENT" | "CARD_PICK" | "ACTION_PICK" | "GONGFA_PICK" |
## "ATTR_PICK" | "EVENT" | "YEAR_END" | "SECT_SWITCH".
var phase: String = "CARD_PICK"

## Surface: profile.silver.
var silver: int = 0

## Surface: the five attrs, mirrored from the profile.
var attr_bone: int = 10
var attr_inner: int = 10
var attr_agility: int = 10
var attr_wisdom: int = 10
var attr_fortune: int = 10

## Surface: profile.gongfa.size().
var gongfa_count: int = 0

## Surface: count of mastered gongfa.
var mastered_count: int = 0

## Surface: the profile's gongfa rows in grant order (ids / grades / display
## names) — the observability the sect-switch scenario asserts on.
var gongfa_ids: Array[String] = []
var gongfa_grades: Array[String] = []
var gongfa_names: Array[String] = []

## Surface: the three categories of the current month's cards.
var drawn_card_categories: Array = []

## Surface: id of the currently displayed 游历 event ("" when none).
var event_id: String = ""

## Surface: true once the DEBUG fast-forward has run.
var fast_forward_used: bool = false

var _monthly_cards: Array = []
var _yearly_cards: Array = []
var _card_focus: int = 0
var _action_focus: int = 0
var _gongfa_focus: int = 0
var _attr_focus: int = 0
var _event_focus: int = 0
var _year_choice: int = 0
var _switch_focus: int = 0
var _delete_armed: bool = false


func _ready() -> void:
	_sync_surface()
	# Year-start grant: entering (fresh or via load) at month 1 grants the
	# sect's arts for the current year (year 1 -> 丁, 2 -> 丙, 3 -> 乙).
	# add_gongfa is idempotent, so a reloaded save never double-grants.
	if month == 1:
		_grant_year_arts()
	_stage_next_month()
	_render()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_fast_forward"):
		if not fast_forward_used:
			fast_forward_used = true
			_fast_forward()
	if Input.is_action_just_pressed("debug_step_month"):
		_debug_step_month()
	if Input.is_action_just_pressed("debug_grant_art"):
		_debug_grant_art()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != "CULTIVATION":
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_accept()
	elif event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_cycle_focus(-1)
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		_cycle_focus(1)
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_cycle_focus(-1)
	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_cycle_focus(1)


# ---------------------------------------------------------------------------
# Input: directional cycling per phase
# ---------------------------------------------------------------------------

func _cycle_focus(dir: int) -> void:
	_delete_armed = false
	match phase:
		"YEAR_AUGMENT", "CARD_PICK":
			var n: int = 3
			_card_focus = (_card_focus + dir + n) % n
		"ACTION_PICK":
			_action_focus = (_action_focus + dir + 7) % 7
		"GONGFA_PICK":
			var ids: Array[String] = _unmastered_ids()
			if not ids.is_empty():
				_gongfa_focus = (_gongfa_focus + dir + ids.size()) % ids.size()
		"ATTR_PICK":
			_attr_focus = (_attr_focus + dir + 5) % 5
		"EVENT":
			_event_focus = 0 if dir > 0 else 1
		"YEAR_END":
			_year_choice = 0 if dir > 0 else 1
		"SECT_SWITCH":
			_switch_focus = (_switch_focus + dir + 5) % 5
		_:
			return
	_render()


func _on_accept() -> void:
	_delete_armed = false
	match phase:
		"YEAR_AUGMENT":
			var card: Dictionary = _yearly_cards[_card_focus] if _card_focus < _yearly_cards.size() else {}
			_apply_card(card)
			_start_month_cards()
		"CARD_PICK":
			var card: Dictionary = _monthly_cards[_card_focus] if _card_focus < _monthly_cards.size() else {}
			_apply_card(card)
			phase = "ACTION_PICK"
			_action_focus = 0
		"ACTION_PICK":
			match _action_focus:
				0:
					phase = "GONGFA_PICK"
					_gongfa_focus = 0
				1:
					phase = "ATTR_PICK"
					_attr_focus = 0
				2:
					_apply_action({"kind": "work"})
					_after_action()
					return
				3:
					event_id = _draw_event()
					phase = "EVENT"
					_event_focus = 0
				4:
					_on_save()
					return
				5:
					_on_load()
					return
				6:
					_on_delete()
					return
		"GONGFA_PICK":
			var ids: Array[String] = _unmastered_ids()
			if ids.is_empty():
				phase = "ACTION_PICK"
			else:
				var gid: String = ids[_gongfa_focus % ids.size()]
				_apply_action({"kind": "practice", "target": gid})
				_after_action()
				return
		"ATTR_PICK":
			var key: String = PlayerProfile.ATTR_KEYS[_attr_focus % 5]
			_apply_action({"kind": "cultivate", "target": key})
			_after_action()
			return
		"EVENT":
			_apply_event_option(_event_focus)
			_after_action()
			return
		"YEAR_END":
			_resolve_year_end(_year_choice)
			return
		"SECT_SWITCH":
			_resolve_sect_switch(_switch_focus)
			return
	_render()


# ---------------------------------------------------------------------------
# Month machinery — the single advance path (manual + fast-forward)
# ---------------------------------------------------------------------------

## Stage the next month: year 2/3 starts first show the yearly augment; every
## other month starts with the monthly 3-category card draw.
func _stage_next_month() -> void:
	if month == 1 and year >= 2:
		_yearly_cards = SaveManager.draw_cards(false)
		drawn_card_categories = _categories_of(_yearly_cards)
		_card_focus = 0
		phase = "YEAR_AUGMENT"
	else:
		_start_month_cards()


func _start_month_cards() -> void:
	_monthly_cards = SaveManager.draw_cards(true)
	drawn_card_categories = _categories_of(_monthly_cards)
	_card_focus = 0
	phase = "CARD_PICK"


## Apply one drawn card's effect (shared by monthly + yearly cards).
func _apply_card(card: Dictionary) -> void:
	var ctype: String = card.get("effect_type", "")
	match ctype:
		"silver":
			SaveManager.profile.silver = maxi(SaveManager.profile.silver + int(card.get("effect_value", 0)), 0)
		"attr":
			SaveManager.profile.add_attr(card.get("effect_target", ""), int(card.get("effect_value", 0)))
		"item":
			var target: String = card.get("effect_target", "")
			if target != "" and not SaveManager.profile.inventory.has(target):
				SaveManager.profile.inventory.append(target)
		"practice":
			_add_practice(int(card.get("effect_value", 0)))
		"trait":
			var tid: String = card.get("id", "")
			if tid == "gr_trait_pool":
				# Monthly growth card 机缘悟道 (step2_design §8.5): grant one
				# random unowned positive trait — drawn from the not-yet-owned
				# pool via the single RNG instance, in operation order. Never
				# offer an id the profile already owns.
				var pool: Array[String] = CardData.build_trait_deck(SaveManager.profile.traits)
				if not pool.is_empty():
					var pick: String = pool[SaveManager.rng.randi_range(0, pool.size() - 1)]
					SaveManager.profile.add_trait(pick)
			elif tid != "" and TraitData.get_def(tid) != null:
				# Yearly trait-deck card: the card id IS the trait id.
				SaveManager.profile.add_trait(tid)
		"shen_gong":
				# 神功 (design/40_progression §3.6; step2_design §2.5): grant one
				# random unowned 甲级 art from the 9-row A pool — one
				# SaveManager.rng draw in operation order; never an owned id.
				var pool: Array[String] = []
				for id in ProgressionGongfaData.a_pool():
					if not SaveManager.profile.has_gongfa(id):
						pool.append(id)
				if not pool.is_empty():
					var pick: String = pool[SaveManager.rng.randi_range(0, pool.size() - 1)]
					SaveManager.profile.add_gongfa(pick, "A")
		"tech_unlock", "":
			pass  # data hooks this round (step2_design §8.5)
	_sync_surface()


## Apply the chosen monthly action (with any RNG draws, in operation order).
func _apply_action(action: Dictionary) -> void:
	match action.get("kind", ""):
		"practice":
			_add_practice(1)
		"cultivate":
			# 修习 lookup table (design §4.1): one rng draw mapped to +1/+2/+3
			# by 悟性 tier — the same one-op count as the old randi_range(1, 3),
			# so the seeded RNG stream's op order is unchanged.
			var roll: float = SaveManager.rng.randf()
			var gain: int = TraitEffects.practice_gain(SaveManager.profile.get_attr("wisdom"), roll)
			SaveManager.profile.add_attr(action.get("target", "bone"), gain)
		"work":
			SaveManager.profile.silver += 10
		"travel":
			pass  # the event is drawn interactively; resolution is _apply_event_option
	_sync_surface()


## Roll the calendar after a month's action resolves: month 36 -> MAP,
## month 12 -> YEAR_END, otherwise advance one month and stage its cards.
func _after_action() -> void:
	SaveManager.profile.cultivation["year"] = year
	SaveManager.profile.cultivation["month"] = month
	if year == 3 and month == 12:
		_finish_to_map()
		return
	if month == 12:
		phase = "YEAR_END"
		_year_choice = 0
		_render()
		return
	month += 1
	SaveManager.profile.cultivation["month"] = month
	SaveManager.autosave()
	_stage_next_month()
	_render()


func _finish_to_map() -> void:
	SaveManager.autosave()
	_sync_surface()
	if not SceneManager.pending_swap:
		GameManager.enter_segment("MAP")


func _resolve_year_end(choice: int) -> void:
	if choice == 1:
		phase = "SECT_SWITCH"
		_switch_focus = 0
		_render()
		return
	_advance_year()


func _resolve_sect_switch(idx: int) -> void:
	var ids: Array[String] = ProgressionGongfaData.sect_ids()
	if idx >= 0 and idx < ids.size():
		sect_id = ids[idx]
		SaveManager.profile.cultivation["sect_id"] = sect_id
	_advance_year()


func _advance_year() -> void:
	year += 1
	month = 1
	SaveManager.profile.cultivation["year"] = year
	SaveManager.profile.cultivation["month"] = month
	_grant_year_arts()
	SaveManager.autosave()
	_stage_next_month()
	_render()


## Grant the CURRENT sect's arts for the current year's grade: 丁 (year 1),
## 丙 (year 2), 乙 (year 3). The 孤煞 trait (lone_bane) suppresses the internal
## grant — its only implemented hook this round.
func _grant_year_arts() -> void:
	var grade: String = ProgressionGongfaData.GRADE_BY_YEAR[clampi(year - 1, 0, 2)]
	if not SaveManager.profile.has_trait("lone_bane"):
		var internal: String = ProgressionGongfaData.art_id(sect_id, "internal", grade)
		if internal != "":
			SaveManager.profile.add_gongfa(internal, grade)
	var external: String = ProgressionGongfaData.art_id(sect_id, "external", grade)
	if external != "":
		SaveManager.profile.add_gongfa(external, grade)
	if SaveManager.profile.main_external_id == "":
		SaveManager.profile.main_external_id = external
	_sync_surface()


## Add practice to the first unmastered gongfa; masters it on reaching the
## grade's threshold (丁4/丙6/乙8). A mastered art is never re-offered.
func _add_practice(amount: int) -> void:
	if SaveManager.profile.has_trait("sha_po_lang"):
		amount = TraitEffects.pojun_practice(amount)
	var gid: String = _first_unmastered_id()
	if gid == "":
		return
	var entry: Dictionary = SaveManager.profile.get_gongfa(gid)
	entry["practice"] = int(entry.get("practice", 0)) + amount
	var grade: String = entry.get("grade", "D")
	if int(entry["practice"]) >= int(ProgressionGongfaData.PRACTICE_TO_MASTER.get(grade, 4)):
		entry["mastered"] = true


func _unmastered_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in SaveManager.profile.gongfa:
		if not bool(entry.get("mastered", false)):
			var id: Variant = entry.get("id", "")
			if id is String and id != "":
				out.append(id as String)
	return out


func _first_unmastered_id() -> String:
	var ids: Array[String] = _unmastered_ids()
	return ids[0] if not ids.is_empty() else ""


## 游历 event draw: one rng draw, no repeat until the pool is exhausted.
func _draw_event() -> String:
	var pool: Array[String] = []
	for def in EventData.all():
		if not (SaveManager.profile.flags.get("events_seen", []) as Array).has(def.id):
			pool.append(def.id)
	if pool.is_empty():
		SaveManager.profile.flags["events_seen"] = []
		for def in EventData.all():
			pool.append(def.id)
	var idx: int = SaveManager.rng.randi_range(0, pool.size() - 1)
	return pool[idx]


## Apply one event option's effects and mark the event seen.
func _apply_event_option(opt_index: int) -> void:
	var def = EventData.def(event_id)
	if def != null:
		var opt = def.option_a if opt_index == 0 else def.option_b
		for eff in opt.effects:
			match eff.get("type", "none"):
				"silver":
					SaveManager.profile.silver = maxi(SaveManager.profile.silver + int(eff.get("value", 0)), 0)
				"attr":
					SaveManager.profile.add_attr(eff.get("target", ""), int(eff.get("value", 0)))
				"item":
					var target: String = eff.get("target", "")
					if target != "" and not SaveManager.profile.inventory.has(target):
						SaveManager.profile.inventory.append(target)
				"practice":
					_add_practice(int(eff.get("value", 0)))
	var seen: Array = SaveManager.profile.flags.get("events_seen", [])
	if event_id != "" and not seen.has(event_id):
		seen.append(event_id)
	event_id = ""
	_sync_surface()


# ---------------------------------------------------------------------------
# Save / load / delete menu (slot 1; 删档 is a two-step confirm)
# ---------------------------------------------------------------------------

func _on_save() -> void:
	SaveManager.save_slot(1)
	phase = "ACTION_PICK"
	_action_focus = 4
	_render()


func _on_load() -> void:
	if SaveManager.load_slot(1):
		_sync_surface()
		if SaveManager.segment == "MAP":
			if not SceneManager.pending_swap:
				GameManager.enter_segment("MAP")
			return
		# Stay in cultivation: re-stage from the restored profile (year/month/
		# decks/rng restored by load_slot; grants are idempotent).
		if month == 1:
			_grant_year_arts()
		_stage_next_month()
	else:
		phase = "ACTION_PICK"
		_action_focus = 5
	_render()


func _on_delete() -> void:
	if not _delete_armed:
		_delete_armed = true
		_render()
		return
	SaveManager.delete_slot(1)
	_delete_armed = false
	phase = "ACTION_PICK"
	_action_focus = 6
	_render()


# ---------------------------------------------------------------------------
# DEBUG fast-forward (unbound action; identical RNG draws to manual play)
# ---------------------------------------------------------------------------

## Drive the phase machine with fixed auto-choices until month 36 completes:
## yearly/monthly card = first card; action = 练功 on the first unmastered
## gongfa, else 修习 根骨; year-end = stay. No awaits inside the loop, so the
## whole run completes within a handful of frames (spine frame budget).
func _fast_forward() -> void:
	var guard: int = 0
	while GameManager.current_state == "CULTIVATION" and guard < 250:
		guard += 1
		match phase:
			"YEAR_AUGMENT":
				var yearly: Dictionary = _yearly_cards[0] if not _yearly_cards.is_empty() else {}
				_apply_card(yearly)
				_start_month_cards()
			"CARD_PICK":
				var card: Dictionary = _monthly_cards[0] if not _monthly_cards.is_empty() else {}
				_apply_card(card)
				phase = "ACTION_PICK"
				_action_focus = 0
			"ACTION_PICK":
				phase = "GONGFA_PICK"
				_gongfa_focus = 0
			"GONGFA_PICK":
				var gid: String = _first_unmastered_id()
				if gid == "":
					phase = "ATTR_PICK"
					_attr_focus = 0
				else:
					_apply_action({"kind": "practice", "target": gid})
					_after_action()
			"ATTR_PICK":
				_apply_action({"kind": "cultivate", "target": "bone"})
				_after_action()
			"EVENT":
				_apply_event_option(0)
				_after_action()
			"YEAR_END":
				_resolve_year_end(0)
			"SECT_SWITCH":
				_resolve_sect_switch(0)
			_:
				break
	_sync_surface()
	_render()


# ---------------------------------------------------------------------------
# DEBUG: one-month step + A-art grant (unbound actions; one press per month /
# one grant per press; identical RNG draws to manual play)
# ---------------------------------------------------------------------------

## Advance EXACTLY ONE month through the phase machine with fixed auto-choices
## (first card; 练功 on the first unmastered EXTERNAL art, else first unmastered
## art, else 修习 根骨; year-end stay). A press at YEAR_END resolves the year.
## Repeatable: every press advances one month / resolves one year-end; no-op
## outside CULTIVATION. The guard loop walks the multi-phase month to its
## action + _after_action, then stops.
func _debug_step_month() -> void:
	if GameManager.current_state != "CULTIVATION":
		return
	var guard: int = 0
	while guard < 20:
		guard += 1
		match phase:
			"YEAR_AUGMENT":
				var yearly: Dictionary = _yearly_cards[0] if not _yearly_cards.is_empty() else {}
				_apply_card(yearly)
				_start_month_cards()
			"CARD_PICK":
				var card: Dictionary = _monthly_cards[0] if not _monthly_cards.is_empty() else {}
				_apply_card(card)
				phase = "ACTION_PICK"
				_action_focus = 0
			"ACTION_PICK":
				phase = "GONGFA_PICK"
				_gongfa_focus = 0
			"GONGFA_PICK":
				var gid: String = _debug_practice_target()
				if gid == "":
					phase = "ATTR_PICK"
					_attr_focus = 0
				else:
					_apply_action({"kind": "practice", "target": gid})
					_after_action()
					break
			"ATTR_PICK":
				_apply_action({"kind": "cultivate", "target": "bone"})
				_after_action()
				break
			"YEAR_END":
				_resolve_year_end(0)
				break
			"SECT_SWITCH":
				_resolve_sect_switch(0)
				break
			_:
				break
	_sync_surface()
	_render()


## 练功 target for _debug_step_month: the first UNMASTERED external art in
## profile.gongfa grant order (external-first — the profile stores internal arts
## before external ones, so a naive first-unmastered pick would master the
## internal ladder first and the external 乙 art could never master in 36
## months); falls back to the first unmastered art of any kind. Unresolvable
## ids are skipped.
func _debug_practice_target() -> String:
	for entry in SaveManager.profile.gongfa:
		if bool(entry.get("mastered", false)):
			continue
		var id: Variant = entry.get("id", "")
		if not (id is String):
			continue
		var art = ProgressionGongfaData.art_by_id(id as String)
		if art != null and str(art.kind) == "external":
			return id as String
	return _first_unmastered_id()


## DEBUG: grant the A art of the profile's main external school (sword/palm/
## polearm/dart -> a_sword/a_palm/a_polearm/a_dart); falls back to the sect's
## internal A art. Idempotent (never grants an owned id); no-op outside
## CULTIVATION or when no A art can be derived.
func _debug_grant_art() -> void:
	if GameManager.current_state != "CULTIVATION":
		return
	var main = ProgressionGongfaData.art_by_id(SaveManager.profile.main_external_id)
	if main == null:
		return
	var id: String = _A_ID_BY_SCHOOL.get(str(main.school), "")
	if id == "":
		id = ProgressionGongfaData.art_id(str(SaveManager.profile.cultivation.get("sect_id", "")), "internal", "A")
	if id == "" or SaveManager.profile.has_gongfa(id):
		return
	SaveManager.profile.add_gongfa(id, "A")
	_sync_surface()


# ---------------------------------------------------------------------------
# Surface sync + rendering
# ---------------------------------------------------------------------------

func _sync_surface() -> void:
	year = int(SaveManager.profile.cultivation.get("year", 1))
	month = int(SaveManager.profile.cultivation.get("month", 1))
	sect_id = SaveManager.profile.cultivation.get("sect_id", "")
	silver = SaveManager.profile.silver
	attr_bone = SaveManager.profile.get_attr("bone")
	attr_inner = SaveManager.profile.get_attr("inner")
	attr_agility = SaveManager.profile.get_attr("agility")
	attr_wisdom = SaveManager.profile.get_attr("wisdom")
	attr_fortune = SaveManager.profile.get_attr("fortune")
	gongfa_count = SaveManager.profile.gongfa.size()
	mastered_count = 0
	for entry in SaveManager.profile.gongfa:
		if bool(entry.get("mastered", false)):
			mastered_count += 1
	gongfa_ids = []
	gongfa_grades = []
	gongfa_names = []
	for entry in SaveManager.profile.gongfa:
		var id: String = str(entry.get("id", ""))
		gongfa_ids.append(id)
		gongfa_grades.append(str(entry.get("grade", "")))
		gongfa_names.append(ProgressionGongfaData.display_name_of(id))


func _categories_of(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		if c is Dictionary:
			out.append((c as Dictionary).get("category", ""))
	return out


func _render() -> void:
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
		return
	var text: String = "第 %d 年 · 第 %d 月    门派: %s\n" % [year, month, _sect_display()]
	text += "银两 %d    根骨 %d 内力 %d 身法 %d 悟性 %d 福缘 %d\n" % [
		silver, attr_bone, attr_inner, attr_agility, attr_wisdom, attr_fortune,
	]
	text += "武功 %d 门 · 大成 %d\n\n" % [gongfa_count, mastered_count]
	match phase:
		"YEAR_AUGMENT":
			text += "【开年际遇】\n"
			text += _card_rows(_yearly_cards, _card_focus)
			text += "\n左右选择，回车收取"
		"CARD_PICK":
			text += "【每月机缘】\n"
			text += _card_rows(_monthly_cards, _card_focus)
			text += "\n左右选择，回车收取"
		"ACTION_PICK":
			text += "【本月行动】\n"
			var labels: Array[String] = ["练功", "修习", "做工", "游历", "存盘", "读档", "删档"]
			for i in range(labels.size()):
				var marker: String = "▶" if i == _action_focus else " "
				text += "%s %s   " % [marker, labels[i]]
			if _action_focus == 6 and _delete_armed:
				text += "\n\n⚠ 再按一次确认删除存档"
			text += "\n\n上下选择，回车执行"
		"GONGFA_PICK":
			text += "【练功】\n"
			var ids: Array[String] = _unmastered_ids()
			if ids.is_empty():
				text += "暂无未大成武功，改选修习吧。"
			else:
				for i in range(ids.size()):
					var gid: String = ids[i]
					var entry: Dictionary = SaveManager.profile.get_gongfa(gid)
					var marker: String = "▶" if i == _gongfa_focus % ids.size() else " "
					text += "%s %s  （%d/%d）\n" % [marker, ProgressionGongfaData.display_name_of(gid), int(entry.get("practice", 0)), int(ProgressionGongfaData.PRACTICE_TO_MASTER.get(entry.get("grade", "D"), 4))]
				text += "\n上下选择，回车苦练"
		"ATTR_PICK":
			text += "【修习】\n"
			for i in range(PlayerProfile.ATTR_KEYS.size()):
				var key: String = PlayerProfile.ATTR_KEYS[i]
				var marker: String = "▶" if i == _attr_focus else " "
				text += "%s %s %d\n" % [marker, _attr_label(key), SaveManager.profile.get_attr(key)]
			text += "\n上下选择，回车修习（+1~+3）"
		"EVENT":
			text += "【游历 · 遇事】\n"
			var def = EventData.def(event_id)
			if def != null:
				text += def.title + "\n" + def.text + "\n\n"
				var sel: String = "▶" if _event_focus == 0 else " "
				text += "%s %s\n" % [sel, def.option_a.label]
				var sel2: String = "▶" if _event_focus == 1 else " "
				text += "%s %s\n" % [sel2, def.option_b.label]
			text += "\n上下选择，回车定夺"
		"YEAR_END":
			text += "【年关将至】\n"
			var labels2: Array[String] = ["留在本门", "另投他派"]
			for i in range(labels2.size()):
				var marker: String = "▶" if i == _year_choice else " "
				text += "%s %s\n" % [marker, labels2[i]]
			text += "\n上下选择，回车决定"
		"SECT_SWITCH":
			text += "【另投他派】\n"
			var rows: Array = ProgressionGongfaData.SECTS
			for i in range(rows.size()):
				var row: Dictionary = rows[i]
				var marker: String = "▶" if i == _switch_focus else " "
				text += "%s %s\n" % [marker, row["display_name"]]
			text += "\n上下选择，回车拜入"
	body.text = text


func _card_rows(cards: Array, focus: int) -> String:
	var out: String = ""
	for i in range(cards.size()):
		var c: Dictionary = cards[i]
		var marker: String = "▶" if i == focus else " "
		out += "%s %s（%s）\n" % [marker, c.get("display_name", ""), _category_label(c.get("category", ""))]
	return out


func _category_label(cat: String) -> String:
	match cat:
		"economy":
			return "钱财"
		"equipment":
			return "兵刃"
		"growth":
			return "成长"
		"power":
			return "机缘"
		"trait":
			return "悟道"
		"artifact":
			return "奇遇"
	return cat


func _sect_display() -> String:
	var def: Dictionary = ProgressionGongfaData.sect_def(sect_id)
	if def.is_empty():
		return "未定"
	return def.get("display_name", sect_id)


func _attr_label(key: String) -> String:
	match key:
		"bone":
			return "根骨"
		"inner":
			return "内力"
		"agility":
			return "身法"
		"wisdom":
			return "悟性"
		"fortune":
			return "福缘"
	return key
