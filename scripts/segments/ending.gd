## EndingScreen — final segment: tiered ending text.
## tier = EndingLogic.evaluate(profile, deeds) — the multi-axis R3 evaluation
## (attrs + mastery + deeds), computed fresh at the ending screen from the
## persisted profile. ui_accept restarts the whole game (GameManager.restart_game
## -> fresh profile + fresh tutorial battle).
extends Control

## Surface: ending tier (1..3, MapData.ENDING_TIERS).
var tier: int = 0

## Surface: the multi-axis ending score (int, EndingLogic.evaluate).
var score: int = 0

## Surface: the rendered axis-summary text (non-empty, includes the per-axis
## summary lines the ending screen shows).
var evaluation_text: String = ""

## Surface: true when this ending's evaluation_text DIFFERS from the first
## ending reached this session (SaveManager.first_ending_evaluation). The R3
## N-1a/N-1b cross-leg differential: leg A renders first (first_ending_evaluation
## set, diverged_from_first false), leg B renders a different playstyle/action
## and diverged_from_first flips true. Self-contained in the EndingScreen
## context so the harness can assert it without cross-node references.
var diverged_from_first: bool = false

## Surface: true after restart routed onward.
var done: bool = false

## Surface: snapshot of SaveManager.profile.silver at _ready (C7 work-economy
## ratio nail — the ending silver the player actually reached).
var final_silver: int = 0

## Surface: mirror of SaveManager.first_ending_silver at this render. The C7
## ratio expression `final_silver > first_ending_silver * 3 / 2` is evaluated
## by the harness against THIS node, so the idle baseline must be readable
## here without a cross-node reference (same self-contained discipline as
## diverged_from_first). 0 until the first ending has rendered.
var first_ending_silver: int = 0

## Surface: the mastery (武学) axis value of this ending (int, EndingLogic
## evaluate axes["mastery"]). C1 scene nail reads this > 0 on a real-save
## practice route (red-first pre-C1: always 0 because GRADE_POINTS used CJK
## keys the save never wrote). Set in _render from the already-scoped axes.
var mastery_axis: int = 0

## Surface: the tier title the player actually sees on this ending screen
## (MapData.ending_def(tier)["title"], the raw untranslated key — set in
## _render). C3 three-distinct-titles nail reads SaveManager.ending_title_history
## which is appended from this value once per render.
var ending_title: String = ""

## Surface: button name -> pressed-signal wired.
var pressed_connected: Dictionary = {}

## C4 roster mirror: true while the RosterPanel overlay is open. Mirrored every
## _process frame from panel.is_open (never from RosterOpenButton.visible — the
## entry button is hidden while open, so reading it would report a false close).
var roster_panel_open: bool = false


func _ready() -> void:
	_wire_restart_button()
	final_silver = SaveManager.profile.silver
	var ev: Dictionary = EndingLogic.evaluate(SaveManager.profile, SaveManager.profile.deeds)
	tier = int(ev["tier"])
	score = int(ev["score"])
	_render()
	# C4: relabel the panel's entry button to 查看角色 and widen it so the longer
	# label fits in the top-right corner clear of BodyLabel (x[-320,320] centered)
	# and RestartButton.
	var ob: Button = get_node_or_null("RosterPanel/RosterOpenButton") as Button
	if ob != null:
		ob.anchor_left = 1.0
		ob.anchor_right = 1.0
		ob.offset_left = -170.0
		ob.offset_top = 8.0
		ob.offset_right = -10.0
		ob.offset_bottom = 48.0
		ob.text = tr("查看角色")


## C4 roster helper: resolve the panel instance (null-safe) and its open state.
func _roster_is_open() -> bool:
	var panel: Control = get_node_or_null("RosterPanel") as Control
	return panel != null and is_instance_valid(panel) and bool(panel.is_open)


## C4 roster mirror: publish the panel's open state every frame.
func _process(_delta: float) -> void:
	roster_panel_open = _roster_is_open()


func _wire_restart_button() -> void:
	var btn: Button = get_node_or_null("RestartButton") as Button
	if btn == null:
		return
	btn.pressed.connect(_on_restart_pressed)
	pressed_connected["RestartButton"] = btn.get_signal_connection_list("pressed").size() > 0


func _on_restart_pressed() -> void:
	if done:
		return
	done = true
	if not SceneManager.pending_swap:
		GameManager.restart_game()


func _unhandled_input(event: InputEvent) -> void:
	# C4 input shield FIRST: while the roster panel is open, consume ALL
	# unhandled input so keyboard never reaches the restart path through a panel
	# the host does not know about. NOTE (intentional, not a regression): while
	# the panel is open, Esc/keyboard CANNOT close it — close is touch/click
	# only (RosterCloseButton / tap-outside), per touch-reachability. If this
	# shield were placed after the `done` check, opening the panel then pressing
	# Enter would silently restart the run.
	if _roster_is_open():
		get_viewport().set_input_as_handled()
		return
	if done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("tutorial_next"):
		get_viewport().set_input_as_handled()
		done = true
		if not SceneManager.pending_swap:
			GameManager.restart_game()


func _render() -> void:
	var body: Label = get_node_or_null("BodyLabel") as Label
	if body == null:
		return
	var def: Dictionary = MapData.ending_def(tier)
	var title: String = def.get("title", "") if not def.is_empty() else ""
	var text_lines: String = def.get("text", "") if not def.is_empty() else ""
	var ev: Dictionary = EndingLogic.evaluate(SaveManager.profile, SaveManager.profile.deeds)
	var axes: Dictionary = ev["axes"]
	var summary: String = tr("结局 · 属性：%d") % int(axes["attrs"])
	summary += "\n" + tr("结局 · 武学：%d") % int(axes["mastery"])
	summary += "\n" + tr("结局 · 历练：%.1f") % float(axes["deeds"])
	evaluation_text = summary
	mastery_axis = int(axes["mastery"])
	# C3: append the tier/title to the per-session history UNCONDITIONALLY, once
	# per render. A single-session multi-leg scenario (ending_tiers_differentiate)
	# renders several ENDINGs; these arrays accumulate one entry each so the
	# tier-differential ([1] vs [0]) and three-pairwise-title nails can read
	# history across legs. Deliberately OUTSIDE the once-per-session
	# first_ending_evaluation guard below — that guard records only the FIRST.
	ending_title = title
	SaveManager.ending_tier_history.append(tier)
	SaveManager.ending_title_history.append(title)
	if SaveManager.first_ending_evaluation == "":
		SaveManager.first_ending_evaluation = summary
		SaveManager.first_ending_silver = SaveManager.profile.silver
	# Mirror AFTER the once-per-session guard so later renders (leg B) read the
	# FIRST ending's baseline, not their own.
	first_ending_silver = SaveManager.first_ending_silver
	# G4 (2026-09-02 rebaseline): the declared diverged_from_first surface had
	# NO writer — "a variable that is never written reads like a variable that
	# reads false" (measured red: ending_divergent_playstyles f1350 and
	# ending_last_month_choice f1585 observed false). Assign the differential
	# here, self-contained on this node (the harness evaluates an assert
	# against the node in its KEY, so the old cross-node expression
	# `SaveManager.first_ending_evaluation != evaluation_text` could never
	# resolve). Pure string comparison, zero RNG.
	diverged_from_first = summary != SaveManager.first_ending_evaluation
	body.text = tr("【结局 · %s】\n\n%s\n\n%s\n\n点击「重新开始」重启江湖") % [tr(title), tr(text_lines), summary]
	var restart_btn: Button = get_node_or_null("RestartButton") as Button
	if restart_btn != null:
		restart_btn.text = tr("重新开始")
		restart_btn.visible = not done
