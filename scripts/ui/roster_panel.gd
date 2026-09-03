## RosterPanel — the roster / character panel (人物栏 · 功法栏 · 物品栏).
##
## A self-contained Control surface consumed by the cultivation and map segments
## (each instantiates res://scenes/ui/roster_panel.tscn as a node named exactly
## "RosterPanel"). It reads SaveManager.profile and writes EXACTLY ONE profile
## surface: the 物品 section's equipment-row buttons call
## SaveManager.profile.equip(...) / unequip_slot(...) — nothing else. The panel
## still never calls SaveManager.autosave()/save_game(), never consumes a
## month/action, never changes any phase or counter, and never writes any other
## profile field. (The previous "reads ... and writes nothing" guarantee was
## deliberately superseded by jinyong-equipment-battle; the superseding ruling is
## recorded in design/90_decisions.md — never silently deleted.)
##
## Single-operation-surface conformance (jinyong-touch-ui form): the only new
## controls are Buttons with focus_mode = 0 (no Godot built-in focus — a focused
## button swallows ui_up/ui_down before _unhandled_input), so the panel still
## never prints a "▶" option list and publishes `cursor_markers_visible` (false
## iff the composed body contains no "▶") exactly like the four existing segments.
## Equipping is a free action: a button press toggles one equipped slot, then
## refresh() — no side effects, no autosave.
##
## Name resolution degrades lazily, never crash / push_error:
##   item  -> CardData.display_name_of(id)                (frozen; "" -> raw id)
##   gongfa-> ProgressionGongfaData.display_name_of(id)   ("" -> raw id)
##   trait -> TraitData.get_def(id).display_name          (null -> raw id)
##   sect  -> ProgressionGongfaData.SECTS scan            (miss -> raw id; "" -> 无门无派)
class_name RosterPanel extends Control

## Attribute key -> display label (tr() keys; 根骨/内力/身法/悟性/福缘 already in
## the EN table from the creation screen).
const _ATTR_LABELS := {
	"bone": "根骨",
	"inner": "内力",
	"agility": "身法",
	"wisdom": "悟性",
	"fortune": "福缘",
}

## Read-only mode (C4 battle/ending instances): when true the panel binds ZERO
## equip pool buttons AND hides all twelve EquipButton0..11, so no 装上/卸下
## button can ever render or write a profile slot. The 物品 section shows a
## 只读 marker line. Default false -> cultivation/map instances keep interactive
## equip byte-identical. Observable on the playtest surface.
@export var read_only: bool = false

var is_open: bool = false
var body_text: String = ""
## Huashan readiness verdict line (R3 D4). Recomputed each refresh() from the
## LIVE profile via BattleSetup.readiness — the same math the duel uses, so the
## warning can never drift from the actual fight numbers. Rendered as a 华山评估
## line in _compose_character. Empty string when the profile is not yet ready to
## judge (defensive; the panel never crashes on a null profile).
var readiness_text: String = ""
var cursor_markers_visible: bool = false   # recomputed each refresh: "▶" in body_text
var pressed_connected: Dictionary = {}
var item_count: int = 0
var gongfa_count: int = 0
## Equipment slot mirrors — recomputed each refresh() from the live profile via
## the defensive equipped_id(slot) (same pattern as item_count/gongfa_count).
var equipped_weapon: String = ""
var equipped_armor: String = ""
var equipped_boots: String = ""
var equip_button_count: int = 0          # pool buttons currently bound to a row
var equip_pressed_connected: int = 0     # bound pool buttons whose `pressed` is connected
var _equip_row_ids: Array[String] = []   # per pool index k -> inventory id
## == the 12 distinct equipment cards (3 slots x 4 tiers); rows beyond the cap
## keep today's text-only rendering (recorded bound — every distinct id stays
## reachable since equip state is keyed by id, so any one row can toggle it).
const MAX_EQUIP_BUTTONS := 12


func _ready() -> void:
	# Re-sync after an in-scene load so a loaded save never shows stale data
	# (cultivation.gd _on_loaded precedent). Success-only signal — a failed load
	# never emits.
	SaveManager.loaded.connect(_on_loaded)
	_wire_buttons()
	refresh()


func _on_loaded(_slot: int) -> void:
	refresh()


# ---------------------------------------------------------------------------
# Open / close / refresh — the read-only hard guarantee lives here.
# ---------------------------------------------------------------------------

func open() -> void:
	is_open = true
	var overlay: Control = _overlay_node()
	if overlay != null:
		overlay.visible = true
	var ob: Button = _open_button_node()
	if ob != null:
		ob.visible = false
	refresh()


func close() -> void:
	is_open = false
	var overlay: Control = _overlay_node()
	if overlay != null:
		overlay.visible = false
	var ob: Button = _open_button_node()
	if ob != null:
		ob.visible = true


## Recompose body_text and every published observable from the LIVE profile.
## Never caches the profile — other systems may mutate it between calls, so each
## refresh reads SaveManager.profile afresh.
func refresh() -> void:
	var p: PlayerProfile = SaveManager.profile
	readiness_text = _compose_readiness(p)
	body_text = _compose_body(p)
	cursor_markers_visible = body_text.contains("▶")
	item_count = p.inventory.size()
	gongfa_count = p.gongfa.size()
	equipped_weapon = p.equipped_id("weapon")
	equipped_armor = p.equipped_id("armor")
	equipped_boots = p.equipped_id("boots")
	_remap_equip_buttons(p)
	var label: Label = get_node_or_null("RosterOverlay/RosterBox/RosterBodyLabel") as Label
	if label != null:
		label.text = body_text


## Rebuild the 物品 section's equipment row->button map from the live profile.
## For each inventory entry whose id is a known equipment id (EquipmentData
## slot_of(id) != ""), the next pool button (k < MAX_EQUIP_BUTTONS) is bound; its
## text is the equip state — 卸下 if that slot holds this id, else 装上 — so the
## label IS the state (no separate "已装备" marker). Non-equipment rows render
## text-only exactly as today (the body string is untouched here). Rows beyond
## the pool cap keep text-only rendering. Node access is null-safe so a bare
## unit-test instance (no scene tree) is safe — the row map still builds.
func _remap_equip_buttons(p: PlayerProfile) -> void:
	# Read-only mode (C4 battle/ending): bind ZERO pool buttons AND hide all
	# twelve EquipButton0..11 so no 装上/卸下 button can ever render or write a
	# profile slot. Clear the row map first, then hide the FULL pool range
	# (the tail loop below alone only covers the range when the array is already
	# empty). equip_button_count / equip_pressed_connected read 0.
	if read_only:
		_equip_row_ids.clear()
		equip_button_count = 0
		equip_pressed_connected = 0
		for k in range(MAX_EQUIP_BUTTONS):
			var btn: Button = _equip_button_node(k)
			if btn != null:
				btn.visible = false
		return
	_equip_row_ids.clear()
	for i in range(p.inventory.size()):
		if _equip_row_ids.size() >= MAX_EQUIP_BUTTONS:
			break
		var id: String = str(p.inventory[i])
		if EquipmentData.slot_of(id) != "":
			_equip_row_ids.append(id)
	equip_button_count = _equip_row_ids.size()
	equip_pressed_connected = 0
	for k in range(_equip_row_ids.size()):
		var btn: Button = _equip_button_node(k)
		if btn == null:
			continue
		var id: String = _equip_row_ids[k]
		var slot: String = EquipmentData.slot_of(id)
		btn.visible = true
		btn.text = tr("卸下") if p.equipped_id(slot) == id else tr("装上")
		if btn.get_signal_connection_list("pressed").size() > 0:
			equip_pressed_connected += 1
	# Hide any pool button not bound to a row this refresh.
	for j in range(_equip_row_ids.size(), MAX_EQUIP_BUTTONS):
		var extra: Button = _equip_button_node(j)
		if extra != null:
			extra.visible = false


# ---------------------------------------------------------------------------
# Pure string builder — same profile in => byte-identical string out.
# ---------------------------------------------------------------------------

## Three display sections, each honest even for a fresh/default profile (empty
## lists render a "（无）" row — never blank/ambiguous output, never OOB).
func _compose_body(p: PlayerProfile) -> String:
	var parts: PackedStringArray = [
		_compose_character(p),
		_compose_gongfa(p),
		_compose_items(p),
	]
	return "\n\n".join(parts)


func _compose_character(p: PlayerProfile) -> String:
	var lines: PackedStringArray = [tr("人物")]
	var attr_parts: PackedStringArray = []
	for key in PlayerProfile.ATTR_KEYS:
		attr_parts.append("%s %d" % [tr(_ATTR_LABELS.get(key, key)), p.get_attr(key)])
	lines.append(" ".join(attr_parts))
	lines.append("%s %d" % [tr("银两"), p.silver])
	lines.append("%s %s" % [tr("先天特质"), _traits_text(p)])
	var year: int = int(p.cultivation.get("year", 1))
	var month: int = int(p.cultivation.get("month", 1))
	lines.append(tr("第 %d 年 %d 月") % [year, month])
	lines.append("%s %s" % [tr("门派"), _sect_text(p)])
	# Huashan readiness warning (R3 D4): visible on the roster panel on BOTH the
	# map and cultivation segments (the panel is instanced into both scenes), so
	# the warning exists for the ~30 months BEFORE the map opens.
	if readiness_text != "":
		lines.append(readiness_text)
	return "\n".join(lines)


## Compose the 华山评估 readiness line from the LIVE profile via
## BattleSetup.readiness (one formula source with the duel). Returns "" when the
## profile is null (defensive — the panel never crashes on a null profile).
func _compose_readiness(p: PlayerProfile) -> String:
	if p == null:
		return ""
	var verdict: Dictionary = BattleSetup.readiness(p)
	var key: String = str(verdict.get("verdict_key", "huashan_weak"))
	var wording: String = tr("华山评估：%s")
	var band: String = tr("战备不足")
	if key == "huashan_even":
		band = tr("势均力敌")
	elif key == "huashan_strong":
		band = tr("胜券在握")
	return wording % band


func _compose_gongfa(p: PlayerProfile) -> String:
	var lines: PackedStringArray = [tr("功法")]
	if p.gongfa.is_empty():
		lines.append(tr("（无）"))
	else:
		for entry in p.gongfa:
			lines.append(_gongfa_line(entry))
	return "\n".join(lines)


func _compose_items(p: PlayerProfile) -> String:
	var lines: PackedStringArray = [tr("物品")]
	# Read-only marker (C4 battle/ending): the equip section is display-only, so
	# a 只读 line follows the header to make that explicit.
	if read_only:
		lines.append(tr("（战斗中只读）"))
	if p.inventory.is_empty():
		lines.append(tr("（无）"))
	else:
		for id in p.inventory:
			lines.append(_name_of_item(id))
	return "\n".join(lines)


## One gongfa display row. Reads the entry DEFENSIVELY via .get() with defaults —
## never assumes keys present or grade non-empty (hostile save data from_dict
## coerces, but the panel must not crash either way).
func _gongfa_line(entry: Dictionary) -> String:
	var id: String = str(entry.get("id", ""))
	var grade: String = str(entry.get("grade", ""))
	var practice: int = int(entry.get("practice", 0))
	var mastered: bool = bool(entry.get("mastered", false))
	var name: String = ProgressionGongfaData.display_name_of(id)
	if name == "":
		name = id
	var cap: int = int(ProgressionGongfaData.PRACTICE_TO_MASTER.get(grade, -1))
	var line: String = name
	if grade != "":
		line += " %s" % grade
	if cap >= 0:
		line += " " + (tr("练度 %d/%d") % [practice, cap])
	else:
		# Grade "" or unknown -> practice shown WITHOUT a cap.
		line += " " + (tr("练度 %d") % [practice])
	if mastered:
		line += " " + tr("大成")
	return line


# ---------------------------------------------------------------------------
# Name resolvers (all null-guarded, degrade lazily, never crash / push_error).
# ---------------------------------------------------------------------------

func _name_of_item(id: String) -> String:
	var name: String = CardData.display_name_of(id)
	return id if name == "" else name


func _name_of_trait(id: String) -> String:
	var def = TraitData.get_def(id)
	return def.display_name if def != null else id


func _traits_text(p: PlayerProfile) -> String:
	if p.traits.is_empty():
		return tr("（无）")
	var names: PackedStringArray = []
	for id in p.traits:
		names.append(_name_of_trait(id))
	return " ".join(names)


func _sect_text(p: PlayerProfile) -> String:
	var sect_id: String = str(p.cultivation.get("sect_id", ""))
	if sect_id == "":
		return tr("无门无派")
	for row in ProgressionGongfaData.SECTS:
		if str(row.get("id", "")) == sect_id:
			return str(row.get("display_name", sect_id))
	return sect_id


# ---------------------------------------------------------------------------
# Node wiring (null-safe so bare script instances in unit tests are safe).
# ---------------------------------------------------------------------------

func _open_button_node() -> Button:
	return get_node_or_null("RosterOpenButton") as Button


func _overlay_node() -> Control:
	return get_node_or_null("RosterOverlay") as Control


func _equip_button_node(k: int) -> Button:
	return get_node_or_null("RosterOverlay/RosterBox/EquipButton%d" % k) as Button


func _wire_buttons() -> void:
	var ob: Button = _open_button_node()
	var cb: Button = get_node_or_null("RosterOverlay/RosterBox/RosterCloseButton") as Button
	var dim: ColorRect = get_node_or_null("RosterOverlay/RosterDim") as ColorRect
	if ob != null and not ob.pressed.is_connected(_on_open_pressed):
		ob.pressed.connect(_on_open_pressed)
	if cb != null and not cb.pressed.is_connected(_on_close_pressed):
		cb.pressed.connect(_on_close_pressed)
	if dim != null and not dim.gui_input.is_connected(_on_dim_input):
		dim.gui_input.connect(_on_dim_input)
	# Equip-button pool: one bound callable per pool index k (bind(k) so the
	# single handler knows which row was pressed). Idempotent via a connection-
	# count check — a bound callable never equals the bare one for is_connected.
	for k in range(MAX_EQUIP_BUTTONS):
		var eb: Button = _equip_button_node(k)
		if eb != null and eb.get_signal_connection_list("pressed").is_empty():
			eb.pressed.connect(_on_equip_pressed.bind(k))
	pressed_connected = {
		"RosterOpenButton": ob != null and ob.get_signal_connection_list("pressed").size() > 0,
		"RosterCloseButton": cb != null and cb.get_signal_connection_list("pressed").size() > 0,
	}


func _on_open_pressed() -> void:
	open()


func _on_close_pressed() -> void:
	close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


## Toggle the equipped slot of the pressed row. THE ONLY new profile write in
## the codebase: it reads the row's id (via _equip_row_ids[k]), equips or
## unequips that one slot, then refresh(). It never calls autosave/save, never
## touches month/phase/any counter, and never writes any other profile field.
## Swap-on-equip: pressing a different id in the same slot overwrites (a player
## never needs unequip-first).
func _on_equip_pressed(k: int) -> void:
	if k < 0 or k >= _equip_row_ids.size():
		return
	var id: String = _equip_row_ids[k]
	var slot: String = EquipmentData.slot_of(id)
	if slot == "":
		return
	var p: PlayerProfile = SaveManager.profile
	if p.equipped_id(slot) == id:
		p.unequip_slot(slot)
	else:
		p.equip(slot, id)
	refresh()
