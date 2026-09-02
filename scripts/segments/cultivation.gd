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
const ProgressionMath = preload("res://scripts/data/progression_math.gd")
const BattleSetup = preload("res://scripts/data/battle_setup.gd")

## Debug-grant school -> external A art id (GongfaData carries no id field;
## ids are row-derived, hence the const map; see _debug_grant_art).
const _A_ID_BY_SCHOOL := {
	"sword": "a_sword",
	"palm": "a_palm",
	"polearm": "a_polearm",
	"dart": "a_dart",
}

## Debug- grant fixed equipment id (青锋剑 eq_sword_3). Routed through
## EventLogic.apply_option_effects (the same item grant pipeline every
## event/card item effect takes — merchant option_a included), never a bare
## profile.inventory append. See _debug_grant_equip.
const _DEBUG_EQUIP_ID: String = "eq_sword_3"

## Showcase event id: the single id the debug seeder leaves unseen, so a
## 1-element draw is deterministic. Introduced by the event-pool-36 round.
const SHOWCASE_ID: String = "cliff_herbs"

## Practice action gain per 练功 month (PROVISIONAL R3 D3 — the M1 yield curve
## justifies it; the free gr_practice_2 card grants +2, so the action must match
## or beat the card to have a niche).
const PRACTICE_ACTION_GAIN: int = 2

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

## Surface: size of the sanitized events_seen bag — the no-repeat proof. Grows
## by 1 per resolved 游历 event; drops to 0 when the pool is exhausted and the
## reset branch of _draw_event refills it (guaranteeing a non-empty draw — never
## an empty event, never a stall).
var events_seen_count: int = 0

## Surface: title of the currently displayed 游历 event ("" when none).
## Published as RAW zh (== what the zh-rendered build displays); playtest
## exact-literal pins assume zh. Do not tr() here.
var event_title: String = ""

## Surface: body text of the currently displayed 游历 event ("" when none).
## Same locale coupling as event_title: raw zh literal.
var event_body: String = ""

## Surface: true once the DEBUG fast-forward has run.
var fast_forward_used: bool = false

## Surface: the month captured at the very top of _on_accept() BEFORE any phase
## match — the pre-advance month for the differential nail. Assigned ONLY in
## _on_accept (never re-assigned, and never written by _sync_surface, which
## re-reads the profile's month on every call and would clobber the snapshot).
var month_before_accept: int = 1

## Surface: an on-screen notice for the current accept ("", nothing to say).
## Rendered by _render() as an appended body line whenever non-empty. Cleared at
## the top of _on_accept() and written by the branches that need to explain
## themselves (e.g. the empty-practice exit). Same facility_result_text shape:
## tr() at the composition site; nails assert shape-only (!= "").
var status_text: String = ""

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

## Surface: "CultOptionButton%d" -> pressed-signal wired (true iff the
## button's pressed signal has a live connection). Re-snapshotted on every
## OptionsBox rebuild, so the contract can assert the pool is WIRED, not just
## present — a hittable button connected to nothing is the defect class the
## click gate cannot see on a button it never clicks.
var pressed_connected: Dictionary = {}

## Surface: true iff the composed BodyLabel still contains a ▶ cursor marker —
## the runtime probe that the keyboard cursor text list is gone (creation.gd
## precedent: cursor_markers_visible). Recomputed on every _render.
var cursor_markers_visible: bool = false

## Surface: the active phase's focus index — the option row whose button is
## highlighted (mirror of the internal focus var; playtest asserts game-level
## focus without reading underscore vars). Recomputed on every _render.
var option_focus: int = 0

## Surface: the text of the button at option_focus ("" when none). Recomputed
## on every _render.
var focused_option_text: String = ""

## Surface: true iff the current options box actually wears the focused
## stylebox on a row — the runtime proof the script-driven focus marker (not the
## old 2-3% modulate trick) is applied. Recomputed on every _render, driven by
## the same focused bool that selects the stylebox in _rebuild_options_box.
var focus_marker_active: bool = false

## Surface: the kind of the monthly action just applied — "practice" /
## "cultivate" / "work" / "travel". Assigned at each action's own call site
## (travel is routed through _on_accept's ACTION_PICK branch 3, never through
## _apply_action). Stale (previous value) on the empty-GONGFA soft-lock month,
## which never applies an action.
var last_action_kind: String = ""

## Surface: silver granted by the monthly ACTION itself. work = the actual
## ProgressionMath.work_income value; practice / cultivate / travel are always 0
## (travel's event silver is EVENT income, not action income — that separation
## is what makes work's silver niche assertable).
var last_action_silver: int = 0

## Surface: i18n'd receipt for the last applied action (e.g. 「做工：银两 +N」).
## Non-empty for all four kinds; tr() at the assignment site.
var last_yield_text: String = ""

## Surface: the gongfa id the last 练功 action targeted ("" when none).
var last_practice_target: String = ""

## Surface: the practice amount the last 练功 action granted (== PRACTICE_ACTION_GAIN).
var last_practice_amount: int = 0

## Surface: true when the last 练功 month left every unmastered row OTHER than
## the resolved target's practice count unchanged (zero-diff pin). Computed
## boolean — no absolute counts. false until a practice month runs.
var last_practice_other_rows_unchanged: bool = false

## Surface: true when the last 练功 month increased the resolved target row's
## practice count. Computed boolean — no absolute counts. false until a practice
## month runs (and false when the month no-oped with no unmastered rows).
var last_practice_target_increased: bool = false

## Surface: true when the last action's receipt is player-readable — i.e.
## last_yield_text is non-empty AND contains no '_' AND no pure-ASCII raw id
## (practice -> the resolved gid, cultivate -> the attr key, work -> constant
## true). Honest false-degradation when a display-name miss leaves a raw id in
## the receipt. false until an action runs.
var last_yield_readable: bool = false

## Private: the raw attr key the last 修习 action targeted, kept so
## last_yield_readable can verify the receipt carries no raw id (identity
## fallback when _attr_label misses an unknown key).
var _last_cultivate_target_key: String = "bone"

## Surface: travel-event rerolls remaining this year (year-scoped budget minus
## profile.deeds.rerolls_used_this_year, clamped >= 0). Published by
## _sync_surface(). The reroll affordance (EventRerollButton + event_reroll key)
## is visible ONLY while this is > 0.
var rerolls_left: int = 0


func _ready() -> void:
	# Refresh the surface whenever a load succeeds while this scene is already
	# hosted (SceneManager.swap_to early-returns on the same scene key, so a
	# load from the in-screen 读档 menu would otherwise leave stale
	# year/month/attr_* behind). The signal fires synchronously on load_slot
	# success only — failed loads never invoke _on_loaded. Staging stays in
	# _on_load() (in-screen loads) and _ready() (fresh instances); the handler
	# only re-syncs + re-renders.
	SaveManager.loaded.connect(_on_loaded)
	_sync_surface()
	# Year-start grant: entering (fresh or via load) at month 1 grants the
	# sect's arts for the current year (year 1 -> 丁, 2 -> 丙, 3 -> 乙).
	# add_gongfa is idempotent, so a reloaded save never double-grants.
	if month == 1:
		_grant_year_arts()
	_stage_next_month()
	_render()


func _on_loaded(_slot: int) -> void:
	_sync_surface()
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
	if Input.is_action_just_pressed("debug_grant_equip"):
		_debug_grant_equip()
	if Input.is_action_just_pressed("debug_seed_events_seen"):
		_debug_seed_events_seen()


func _roster_open() -> bool:
	var panel := get_node_or_null("RosterPanel")
	return panel != null and panel.is_open


func _unhandled_input(event: InputEvent) -> void:
	if _roster_open():
		return
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
	elif event.is_action_pressed("event_reroll"):
		get_viewport().set_input_as_handled()
		_on_event_reroll()


# ---------------------------------------------------------------------------
# Input: directional cycling per phase
# ---------------------------------------------------------------------------

## Travel-event reroll (fortune consumer, design D2): spend one of the
## year-scoped rerolls to re-draw the current 游历 event. Player-initiated ONLY
## (the event_reroll key / EventRerollButton) — old timelines that never press
## it keep byte-identical RNG streams. Exactly ONE EventLogic.draw_unseen_id
## draw per successful press (the same op the original travel draw used); the
## exhausted branch performs ZERO RNG draws.
func _on_event_reroll() -> void:
	if phase != "EVENT":
		return
	if rerolls_left <= 0:
		# Exhausted: inert — zero RNG, counters unchanged, receipt non-empty.
		status_text = tr("今年已无重掷次数")
		_render()
		return
	SaveManager.profile.deeds["rerolls_used_this_year"] = SaveManager.profile.get_deed("rerolls_used_this_year") + 1
	event_id = EventLogic.draw_unseen_id(SaveManager.profile, SaveManager.rng)
	_sync_surface()
	status_text = tr("重掷：剩余 %d 次") % rerolls_left
	_render()

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
			_event_focus = (_event_focus + dir + 2) % 2
		"YEAR_END":
			_year_choice = 1 if dir > 0 else 0  # down -> 另投他派(1), up -> 留在本门(0)
		"SECT_SWITCH":
			_switch_focus = (_switch_focus + dir + 5) % 5
		_:
			return
	_render()


func _on_accept() -> void:
	month_before_accept = month
	status_text = ""
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
					# Travel is routed here (NOT through _apply_action — its "travel"
					# branch is unreachable from the live phase machine). Publish the
					# travel action surfaces: kind, zero action-silver (event silver
					# is event income, not action income), and the static receipt.
					last_action_kind = "travel"
					last_action_silver = 0
					last_yield_text = tr("游历：遇事")
					_sync_surface()   # NEW: publish event_title/event_body the moment the roam draw lands
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
				# Soft-lock exit: no unmastered arts — burn the month and move
				# on. Mirrors _fast_forward's transition (ATTR_PICK + advance)
				# WITHOUT its free reward: NO _apply_action here (zero RNG ops,
				# zero attribute gain — the seeded RNG stream's op order is the
				# lifeline of event_travel_effects 19/19 and save_load_roundtrip
				# 14/14). _after_action is the single month-advance path; month
				# 12 -> YEAR_END and y3/m12 -> _finish_to_map inherit for free.
				status_text = tr("无可修习的功法，本月照常过去")
				phase = "ATTR_PICK"
				_attr_focus = 0
				_after_action()
				return
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
			var silver_before: int = SaveManager.profile.silver
			SaveManager.profile.silver = maxi(SaveManager.profile.silver + int(card.get("effect_value", 0)), 0)
			# C3 M2': FREE-CARD silver is NOT counted toward the 历练 (deeds) axis.
			# Measurement (design/40_progression.md M2'): a pure 度过本月 run scores
			# the free eco_20 card's +20/month into silver_earned, and the deed axis
			# (0.05 * silver_earned) alone pushed the do-nothing route past the old
			# tier-3 threshold — so every playstyle evaluated identically. The card's
			# silver still enters profile.silver (the player keeps the money); only
			# the deed bookkeeping stops counting it, so 历练 reflects *earned*
			# effort (work / events), not free draws. Zero new systems.
			pass
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
			# 练功: +PRACTICE_ACTION_GAIN into the player-CHOSEN art (the target
			# gid comes from GONGFA_PICK). The only action where the player picks
			# WHICH art advances — the targeted-niche proof. Zero new RNG.
			var target: String = str(action.get("target", ""))
			# Resolve the target FIRST (post-fallback) so the wrapper threads the
			# RESOLVED gid and last_practice_target holds the resolved gid — never
			# the raw input. Deterministic, zero RNG; add_practice re-resolves
			# internally with the same result.
			var resolved: String = EventLogic._resolve_target(SaveManager.profile, target)
			# Pre/post snapshot for the two computed observables: every unmastered
			# row's practice count before the month vs after (zero-diff pin for the
			# non-target rows, increased pin for the target row).
			var before_counts: Dictionary = _practice_counts_by_id()
			_add_practice(PRACTICE_ACTION_GAIN, resolved)
			# 练功 builds the body (R3b scenario rebaseline, 2026-09-02): every
			# REAL practice month strengthens the art's feeding attribute —
			# internal arts 内力, external arts 根骨. The soft-lock month
			# (resolved == "") gains nothing (it applies no practice), card /
			# event practice effects do NOT fire this (only the player-chosen
			# 练功 month does), and the instrument's direct EventLogic.
			# add_practice calls are untouched. Pure arithmetic, zero RNG.
			if resolved != "":
				SaveManager.profile.add_attr(
					"inner" if EventLogic.is_internal_art_id(resolved) else "bone", 1)
			SaveManager.profile.deeds["practice_months"] = SaveManager.profile.get_deed("practice_months") + 1
			last_action_kind = "practice"
			last_action_silver = 0
			last_practice_target = resolved
			last_practice_amount = PRACTICE_ACTION_GAIN
			last_practice_other_rows_unchanged = _other_rows_unchanged(before_counts, resolved)
			last_practice_target_increased = _target_increased(before_counts, resolved)
			var display_name: String = ProgressionGongfaData.display_name_of(resolved)
			if display_name == "":
				display_name = resolved
			last_yield_text = tr("练功：%s +%d") % [display_name, PRACTICE_ACTION_GAIN]
		"cultivate":
			# 修习 lookup table (design §4.1): one rng draw mapped to +1/+2/+3
			# by 悟性 tier — the same one-op count as the old randi_range(1, 3),
			# so the seeded RNG stream's op order is unchanged. Math UNCHANGED.
			var roll: float = SaveManager.rng.randf()
			var gain: int = TraitEffects.practice_gain(SaveManager.profile.get_attr("wisdom"), roll)
			SaveManager.profile.add_attr(action.get("target", "bone"), gain)
			SaveManager.profile.deeds["cultivate_months"] = SaveManager.profile.get_deed("cultivate_months") + 1
			last_action_kind = "cultivate"
			last_action_silver = 0
			# The raw attr key is kept so last_yield_readable can verify the
			# receipt carries no raw id (identity fallback when _attr_label
			# misses an unknown key). Same default ("bone") as _attr_label.
			_last_cultivate_target_key = str(action.get("target", "bone"))
			last_yield_text = tr("修习：%s +%d") % [_attr_label(_last_cultivate_target_key), gain]
		"work":
			# 做工: silver grows with each month worked (10 + 3 * work_months) —
			# the only action whose yield compounds with the run, and the only
			# repeatable silver source that beats the one-shot free cards. Pure
			# arithmetic, zero new RNG. The gain MUST be computed from the deed
			# BEFORE work_months is incremented (current order, byte-identical).
			var gain: int = ProgressionMath.work_income(SaveManager.profile.get_deed("work_months"))
			SaveManager.profile.silver += gain
			SaveManager.profile.deeds["work_months"] = SaveManager.profile.get_deed("work_months") + 1
			SaveManager.profile.deeds["silver_earned"] = SaveManager.profile.get_deed("silver_earned") + gain
			last_action_kind = "work"
			last_action_silver = gain
			last_yield_text = tr("做工：银两 +%d") % gain
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
	# Year-scoped reroll budget reset: the fortune reroll counter is per-year,
	# so a new year restores the full budget (design D2).
	SaveManager.profile.deeds["rerolls_used_this_year"] = 0
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


## Add practice to the player-CHOSEN gongfa (target_id); masters it on reaching
## the grade's threshold (丁4/丙6/乙8). A mastered art is never re-offered. The
## target is threaded through to EventLogic.add_practice, which resolves it
## (falling back to the first unmastered row when empty / unknown / mastered).
func _add_practice(amount: int, target_id: String = "") -> void:
	EventLogic.add_practice(SaveManager.profile, amount, target_id)


## Snapshot every gongfa row's practice count keyed by id (for the pre/post
## differential observables). Pure read, zero RNG.
func _practice_counts_by_id() -> Dictionary:
	var out: Dictionary = {}
	for entry in SaveManager.profile.gongfa:
		var id: String = str(entry.get("id", ""))
		if id != "":
			out[id] = int(entry.get("practice", 0))
	return out


## True when every unmastered row OTHER than the resolved target has the same
## practice count it had before the month (zero-diff pin). Trivially true when
## the target is the only unmastered row. Computed boolean — no absolute counts.
func _other_rows_unchanged(before_counts: Dictionary, resolved: String) -> bool:
	for entry in SaveManager.profile.gongfa:
		var id: String = str(entry.get("id", ""))
		if id == "" or id == resolved:
			continue
		if not bool(entry.get("mastered", false)):
			if int(entry.get("practice", 0)) != int(before_counts.get(id, 0)):
				return false
	return true


## True when the resolved target row's practice count increased over the month
## (by the pojun-transformed amount). False when the month no-oped (no unmastered
## rows -> resolved == ""). Computed boolean — no absolute counts.
func _target_increased(before_counts: Dictionary, resolved: String) -> bool:
	if resolved == "":
		return false
	var entry: Dictionary = SaveManager.profile.get_gongfa(resolved)
	if entry.is_empty():
		return false
	return int(entry.get("practice", 0)) > int(before_counts.get(resolved, 0))


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
	return EventLogic.draw_unseen_id(SaveManager.profile, SaveManager.rng)


## Apply one event option's effects and mark the event seen.
func _apply_event_option(opt_index: int) -> void:
	var def = EventData.def(event_id)
	if def != null:
		var opt = def.option_a if opt_index == 0 else def.option_b
		var silver_before: int = SaveManager.profile.silver
		var res: Dictionary = EventLogic.apply_option_effects(SaveManager.profile, opt)
		if res["ok"]:
			# Successful event resolution: count the travel deed, and track any
			# silver the option actually granted (real clamped delta, never a raw
			# effect value — a refused/negative option never inflates the deed).
			SaveManager.profile.deeds["travel_resolved"] = SaveManager.profile.get_deed("travel_resolved") + 1
			SaveManager.profile.deeds["silver_earned"] = SaveManager.profile.get_deed("silver_earned") + maxi(SaveManager.profile.silver - silver_before, 0)
		else:
			# All-or-nothing refusal: the whole option did nothing. Explain on
			# screen by reason; the event is STILL marked seen below (the
			# encounter happened) and event_id is still cleared, so a refused
			# draw can never create a new soft-lock or shift a seen-count ladder.
			if res["reason"] == "silver":
				status_text = tr("银两不足")
			else:
				status_text = tr("此物已在行囊，无须再购")
	var seen: Array = SaveManager.profile.flags.get("events_seen", [])
	if event_id != "" and not seen.has(event_id):
		seen.append(event_id)
	event_id = ""
	_sync_surface()


# ---------------------------------------------------------------------------
# Save / load / delete menu (slot 2 — manual user checkpoint; slot 1 is the
# month-advance autosave and must never be clobbered by 存盘; 删档 is a
# two-step confirm)
# ---------------------------------------------------------------------------

func _on_save() -> void:
	SaveManager.save_slot(2)
	phase = "ACTION_PICK"
	_action_focus = 4
	_render()


func _on_load() -> void:
	if SaveManager.load_slot(2):
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
	SaveManager.delete_slot(2)
	_delete_armed = false
	phase = "ACTION_PICK"
	_action_focus = 6
	_render()


# ---------------------------------------------------------------------------
# Pointer path: the per-render option-button pool. A click sets the phase's
# focus var and runs the EXISTING _on_accept() — one handler, two triggers,
# zero forked logic (the keyboard branch above stays the single authority).
# ---------------------------------------------------------------------------

## Click delegate: focus := index, then _on_accept(). _on_accept's own guards
## (_delete_armed reset, per-phase bounds/modulo) stay authoritative — no
## phase logic is duplicated here.
func _on_option_pressed(index: int) -> void:
	match phase:
		"YEAR_AUGMENT", "CARD_PICK":
			_card_focus = index
		"ACTION_PICK":
			_action_focus = index
		"GONGFA_PICK":
			_gongfa_focus = index
		"ATTR_PICK":
			_attr_focus = index
		"EVENT":
			_event_focus = index
		"YEAR_END":
			_year_choice = index
		"SECT_SWITCH":
			_switch_focus = index
		_:
			return
	_on_accept()


## Rebuild the OptionsBox pool for the CURRENT phase. Children are removed
## immediately then queue_freed (remove_child + queue_free, never plain free):
## renders are synchronous and event-driven, and a CLICK on a CultOptionButton
## re-enters this rebuild from inside that button's own `pressed` emission —
## `child.free()` on the currently-emitting button throws "Attempted to free a
## locked object (calling or emitting)" (exposed by the clicks-only storyline,
## which the keyboard path never reached). remove_child already detaches every
## old button so it cannot be hit again this frame; queue_free only defers the
## memory reclaim to end-of-frame (next click is frames later), which is safe
## and lets the emission complete. The buttons are the ONLY rendering of the
## option list — the ▶ cursor text rows are gone (cursor_markers_visible is
## the runtime probe that stays false). Every player-choice phase leaves this
## box with at least one visible, wired button: GONGFA_PICK with an empty
## unmastered list appends a single 返回行动 button whose pressed path is the
## same _on_option_pressed -> _on_accept chain every other option uses (the
## empty branch inside _on_accept performs the return to ACTION_PICK). The
## only zero-button state left is a defensive EVENT with an unresolvable event
## id, which the phase machine cannot reach; in that case the box hides and
## pressed_connected re-snapshots empty so the observable stays truthful.
func _rebuild_options_box() -> void:
	var box: VBoxContainer = get_node_or_null("OptionsBox") as VBoxContainer
	if box == null:
		focus_marker_active = false
		return
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var labels: Array[String] = []
	match phase:
		"YEAR_AUGMENT":
			for c in _yearly_cards:
				labels.append(_card_button_label(c))
		"CARD_PICK":
			for c in _monthly_cards:
				labels.append(_card_button_label(c))
		"ACTION_PICK":
			var action_labels: Array[String] = ["练功（+2 所选功法）", "修习（属性 +1~3）", "做工（银两随做工月数递增）", "游历（事件与物品）", "存盘", "读档", "删档"]
			for label in action_labels:
				labels.append(tr(label))
		"GONGFA_PICK":
			var ids: Array[String] = _unmastered_ids()
			if ids.is_empty():
				# Empty unmastered list: the single tappable exit. Its pressed
				# path is the same _on_option_pressed -> _on_accept chain every
				# other option uses — no forked phase logic.
				labels.append(tr("度过本月"))
			for i in range(ids.size()):
				var gid: String = ids[i]
				var entry: Dictionary = SaveManager.profile.get_gongfa(gid)
				labels.append(tr("%s（%d/%d）") % [
					tr(ProgressionGongfaData.display_name_of(gid)),
					int(entry.get("practice", 0)),
					int(ProgressionGongfaData.PRACTICE_TO_MASTER.get(entry.get("grade", "D"), 4)),
				])
		"ATTR_PICK":
			for i in range(PlayerProfile.ATTR_KEYS.size()):
				var key: String = PlayerProfile.ATTR_KEYS[i]
				labels.append(tr("%s %d") % [_attr_label(key), SaveManager.profile.get_attr(key)])
		"EVENT":
			var def = EventData.def(event_id)
			if def != null:
				labels.append(tr(str(def.option_a.label)))
				labels.append(tr(str(def.option_b.label)))
		"YEAR_END":
			var year_labels: Array[String] = ["留在本门", "另投他派"]
			for label in year_labels:
				labels.append(tr(label))
		"SECT_SWITCH":
			for row in ProgressionGongfaData.SECTS:
				labels.append(tr(str(row["display_name"])))
	box.visible = not labels.is_empty()
	pressed_connected = {}
	for i in range(labels.size()):
		var btn := Button.new()
		btn.name = "CultOptionButton%d" % i
		btn.text = labels[i]
		btn.focus_mode = Control.FOCUS_NONE
		# Keyboard focus is expressed ON the button via a real visual marker
		# (ThemeManager.option_style: cinnabar left bar + border + font color),
		# replacing the old 2-3% brightness (modulate 1.0 vs 0.72) cue.
		var focused: bool = i == _focused_index_for_phase()
		btn.add_theme_stylebox_override("normal", ThemeManager.option_style(focused))
		btn.add_theme_color_override("font_color", ThemeManager.OPTION_FONT_FOCUS if focused else ThemeManager.OPTION_FONT_DIM)
		btn.custom_minimum_size = Vector2(240, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_option_pressed.bind(i))
		box.add_child(btn)
		pressed_connected["CultOptionButton%d" % i] = btn.get_signal_connection_list("pressed").size() > 0
	# Travel-event reroll affordance (fortune consumer, design D2): a code-built
	# button rendered in the EVENT phase ONLY while rerolls_left > 0. Follows the
	# sibling button conventions (FOCUS_NONE, option_style, 240x40, EXPAND_FILL)
	# so it never overlaps the option rows or the body label (UiOcclusionWatch
	# discipline). Its pressed path is the same _on_event_reroll the event_reroll
	# key drives — one handler, two triggers.
	if phase == "EVENT" and rerolls_left > 0:
		var reroll_btn := Button.new()
		reroll_btn.name = "EventRerollButton"
		reroll_btn.text = tr("重掷事件（剩余 %d 次）") % rerolls_left
		reroll_btn.focus_mode = Control.FOCUS_NONE
		reroll_btn.add_theme_stylebox_override("normal", ThemeManager.option_style(false))
		reroll_btn.add_theme_color_override("font_color", ThemeManager.OPTION_FONT_DIM)
		reroll_btn.custom_minimum_size = Vector2(240, 40)
		reroll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reroll_btn.pressed.connect(_on_event_reroll)
		box.add_child(reroll_btn)
		pressed_connected["EventRerollButton"] = reroll_btn.get_signal_connection_list("pressed").size() > 0
	# The focused stylebox was applied to _focused_index_for_phase()'s row iff
	# the box holds at least one button (labels non-empty). This is the same
	# focused bool that selected the stylebox above, so the published flag is
	# sourced from the state the button actually wears.
	focus_marker_active = not labels.is_empty()


## Button label for a drawn card: name + category — the button is the only
## rendering of the option (the BodyLabel card rows are gone).
func _card_button_label(card: Dictionary) -> String:
	return tr("%s（%s）") % [
		tr(str(card.get("display_name", ""))),
		_category_label(str(card.get("category", ""))),
	]


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


## DEBUG: grant a fixed equipment card (青锋剑 eq_sword_3) into the inventory
## through the REAL item grant pipeline — EventLogic.apply_option_effects, the
## same handler every event/card item effect takes (merchant option_a included).
## Never a bare profile.inventory append (roadmap rule 2: injection must not
## bypass the code the player actually exercises). Idempotent (no-op when the id
## is already owned); no-op outside CULTIVATION.
func _debug_grant_equip() -> void:
	if GameManager.current_state != "CULTIVATION":
		return
	if SaveManager.profile.inventory.has(_DEBUG_EQUIP_ID):
		return
	var opt = EventData.EventOption.new()
	opt.effects.assign([{"type": "item", "value": 0, "target": _DEBUG_EQUIP_ID}])
	EventLogic.apply_option_effects(SaveManager.profile, opt)
	_sync_surface()


## DEBUG/TEST-ONLY: mark every pool id seen EXCEPT SHOWCASE_ID, leaving exactly
## one unseen id so the next roam draw is deterministic (1-element pool).
## Reuses the identical append-if-absent branch shape as the real mark at
## _apply_event_option (line 467–469 pattern). Zero RNG ops. Never called by
## gameplay; harness-only (project.godot empty events list).
func _debug_seed_events_seen() -> void:
	if GameManager.current_state != "CULTIVATION":
		return
	var seen: Array = SaveManager.profile.flags.get("events_seen", [])
	for def in EventData.all():
		if def.id != SHOWCASE_ID and not seen.has(def.id):
			seen.append(def.id)
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
	events_seen_count = (SaveManager.profile.flags.get("events_seen", []) as Array).size()
	# Travel-event reroll budget remaining this year (year-scoped budget minus
	# the used counter, clamped >= 0). The reroll affordance is visible ONLY
	# while this is > 0. Pure arithmetic, zero RNG.
	rerolls_left = maxi(
		TraitEffects.fortune_reroll_budget(
			SaveManager.profile.get_attr("fortune"),
			SaveManager.profile.has_trait("deep_fortune")
		) - SaveManager.profile.get_deed("rerolls_used_this_year"),
		0
	)
	# Locale coupling: published as RAW zh (== zh-rendered build output); playtest
	# pins exact zh literals. Do not tr() here — mirrors how event_id is published.
	var d = EventData.def(event_id)
	event_title = d.title if d != null else ""
	event_body = d.text if d != null else ""
	if event_id != "" and d == null:
		push_warning("CultivationScreen: event_id '%s' has no EventData def - title/body stay empty" % event_id)
	# Computed receipt readability: true when the receipt is non-empty AND carries
	# no '_' AND no pure-ASCII raw id. Raw id source depends on the last action
	# kind: practice -> the resolved gid (last_practice_target), cultivate -> the
	# attr key, work -> no raw id (constant true). Honest false on display-name
	# miss (raw id surfaced). Pure string/boolean arithmetic, zero RNG.
	var raw_id: String = _last_cultivate_target_key
	if last_action_kind == "practice":
		raw_id = last_practice_target
	elif last_action_kind == "work":
		raw_id = ""
	last_yield_readable = (
		last_yield_text != ""
		and not last_yield_text.contains("_")
		and (raw_id == "" or not last_yield_text.contains(raw_id))
	)


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
	# Every literal piece goes through tr(): the body is COMPOSED, so Label
	# auto-translate cannot match it — zh renders the keys verbatim (headless
	# harness included), en renders the I18n table.
	var text: String = tr("第 %d 年 · 第 %d 月    门派: %s\n") % [year, month, _sect_display()]
	text += tr("银两 %d    根骨 %d 内力 %d 身法 %d 悟性 %d 福缘 %d\n") % [
		silver, attr_bone, attr_inner, attr_agility, attr_wisdom, attr_fortune,
	]
	text += tr("武功 %d 门 · 大成 %d\n\n") % [gongfa_count, mastered_count]
	# Huashan readiness warning (R3 D4): from year 3 month 1 onward the body
	# carries the 华山评估 line so the warning exists for the ~30 months BEFORE
	# the map opens. Same math as the roster panel (BattleSetup.readiness) — one
	# formula source with the duel.
	if year >= 3:
		var verdict: Dictionary = BattleSetup.readiness(SaveManager.profile)
		var key: String = str(verdict.get("verdict_key", "huashan_weak"))
		var band: String = tr("战备不足")
		if key == "huashan_even":
			band = tr("势均力敌")
		elif key == "huashan_strong":
			band = tr("胜券在握")
		text += tr("华山评估：%s\n\n") % band
	match phase:
		"YEAR_AUGMENT":
			text += tr("【开年际遇】\n")
			text += tr("\n左右选择，回车收取")
		"CARD_PICK":
			text += tr("【每月机缘】\n")
			text += tr("\n左右选择，回车收取")
		"ACTION_PICK":
			text += tr("【本月行动】\n")
			if _action_focus == 6 and _delete_armed:
				text += tr("\n\n⚠ 再按一次确认删除存档")
			text += tr("\n\n上下选择，回车执行")
		"GONGFA_PICK":
			text += tr("【练功】\n")
			if _unmastered_ids().is_empty():
				text += tr("功法均已大成，无可修习")
			# The keyboard hint shows even when the list is empty: the
			# 返回行动 button is the tappable exit, and the hint names the
			# confirm key for desktop players.
			text += tr("\n上下选择，回车苦练")
		"ATTR_PICK":
			text += tr("【修习】\n")
			text += tr("\n上下选择，回车修习（+1~+3）")
		"EVENT":
			text += tr("【游历 · 遇事】\n")
			var def = EventData.def(event_id)
			if def != null:
				text += tr(def.title) + "\n" + tr(def.text) + "\n\n"
			text += tr("\n上下选择，回车定夺")
		"YEAR_END":
			text += tr("【年关将至】\n")
			text += tr("\n上下选择，回车决定")
		"SECT_SWITCH":
			text += tr("【另投他派】\n")
			text += tr("\n上下选择，回车拜入")
	# On-screen feedback: any branch that set status_text this accept appends
	# its notice here so the player SEES what happened (never a silent jump).
	if status_text != "":
		text += "\n" + status_text + "\n"
	# C6: the action receipt (last_yield_text) is drawn on screen after the
	# status block so the player reads what the last action yielded. Display
	# names already applied at the assignment sites; zero new control level.
	# Drawn at TOP LEVEL (not inside the status block) so it appears on every
	# normal action month — _on_accept clears status_text, so nesting it there
	# would leave the receipt invisible on the dominant code path.
	if last_yield_text != "":
		text += "\n" + last_yield_text + "\n"
	body.text = text
	_rebuild_options_box()
	# Observables recomputed on every render. cursor_markers_visible is the
	# runtime proof the ▶ cursor text list is gone (creation.gd precedent).
	cursor_markers_visible = body.text.contains("▶")
	option_focus = _focused_index_for_phase()
	focused_option_text = _focused_option_text()
	# Published here (alongside option_focus / focused_option_text) because the
	# keyboard nav path (_cycle_focus -> _render) never calls _sync_surface.
	# _rebuild_options_box() (called above) owns the authoritative value,
	# including the box==null / empty-box paths, so this mirror stays in sync
	# with the stylebox the focused row actually wears.
	focus_marker_active = focused_option_text != ""


## The active phase's focus index — the button row that is highlighted. A pure
## switch over the internal focus vars (no state mutation); the same value the
## modulate highlight in _rebuild_options_box uses.
func _focused_index_for_phase() -> int:
	match phase:
		"YEAR_AUGMENT", "CARD_PICK":
			return _card_focus
		"ACTION_PICK":
			return _action_focus
		"GONGFA_PICK":
			return _gongfa_focus
		"ATTR_PICK":
			return _attr_focus
		"EVENT":
			return _event_focus
		"YEAR_END":
			return _year_choice
		"SECT_SWITCH":
			return _switch_focus
		_:
			return 0


## The text of the button at option_focus ("" when the box holds no button at
## that index — defensive; the constructor guarantees >= 1 for every reachable
## choice phase).
func _focused_option_text() -> String:
	var box: VBoxContainer = get_node_or_null("OptionsBox") as VBoxContainer
	if box == null:
		return ""
	var idx: int = option_focus
	if idx < 0 or idx >= box.get_child_count():
		return ""
	var btn: Button = box.get_child(idx) as Button
	return btn.text if btn != null else ""


func _category_label(cat: String) -> String:
	match cat:
		"economy":
			return tr("钱财")
		"equipment":
			return tr("兵刃")
		"growth":
			return tr("成长")
		"power":
			return tr("机缘")
		"trait":
			return tr("悟道")
		"artifact":
			return tr("奇遇")
	return cat


func _sect_display() -> String:
	var def: Dictionary = ProgressionGongfaData.sect_def(sect_id)
	if def.is_empty():
		return tr("未定")
	return tr(str(def.get("display_name", sect_id)))


func _attr_label(key: String) -> String:
	match key:
		"bone":
			return tr("根骨")
		"inner":
			return tr("内力")
		"agility":
			return tr("身法")
		"wisdom":
			return tr("悟性")
		"fortune":
			return tr("福缘")
	return key
