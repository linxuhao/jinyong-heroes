## RosterPanel — the read-only roster / character panel (人物栏 · 功法栏 · 物品栏).
##
## A self-contained, DISPLAY-ONLY Control surface consumed by the cultivation and
## map segments (each instantiates res://scenes/ui/roster_panel.tscn as a node
## named exactly "RosterPanel"). It reads SaveManager.profile and writes nothing:
## open()/close()/refresh() never call SaveManager.autosave(), never touch a
## profile field, never consume a month/action, and never advance any counter.
##
## Single-operation-surface conformance (jinyong-touch-ui form): the panel has
## ZERO internal selectable options — the three sections are pure display rows
## (attribute values, gongfa practice, item names) — so it never prints a "▶"
## option list. It publishes `cursor_markers_visible` (false iff the composed
## body contains no "▶") exactly like the four existing segments, and both its
## buttons use focus_mode = 0 (no Godot built-in focus; open/close are click-only
## via `pressed`, plus a tap-outside dim layer for close).
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

var is_open: bool = false
var body_text: String = ""
var cursor_markers_visible: bool = false   # recomputed each refresh: "▶" in body_text
var pressed_connected: Dictionary = {}
var item_count: int = 0
var gongfa_count: int = 0


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
	body_text = _compose_body(p)
	cursor_markers_visible = body_text.contains("▶")
	item_count = p.inventory.size()
	gongfa_count = p.gongfa.size()
	var label: Label = get_node_or_null("RosterOverlay/RosterBox/RosterBodyLabel") as Label
	if label != null:
		label.text = body_text


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
	lines.append("  ".join(attr_parts))
	lines.append("%s %d" % [tr("银两"), p.silver])
	lines.append("%s %s" % [tr("先天特质"), _traits_text(p)])
	var year: int = int(p.cultivation.get("year", 1))
	var month: int = int(p.cultivation.get("month", 1))
	lines.append(tr("第 %d 年 %d 月") % [year, month])
	lines.append("%s %s" % [tr("门派"), _sect_text(p)])
	return "\n".join(lines)


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
