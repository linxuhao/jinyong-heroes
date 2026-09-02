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

## Surface: the tier title the player actually sees on this ending screen
## (MapData.ending_def(tier)["title"], the raw untranslated key — set in
## _render). C3 three-distinct-titles nail reads SaveManager.ending_title_history
## which is appended from this value once per render.
var ending_title: String = ""

## Surface: button name -> pressed-signal wired.
var pressed_connected: Dictionary = {}


func _ready() -> void:
	_wire_restart_button()
	final_silver = SaveManager.profile.silver
	var ev: Dictionary = EndingLogic.evaluate(SaveManager.profile, SaveManager.profile.deeds)
	tier = int(ev["tier"])
	score = int(ev["score"])
	_render()


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
	body.text = tr("【结局 · %s】\n\n%s\n\n%s\n\n按回车重新开始") % [tr(title), tr(text_lines), summary]
	var restart_btn: Button = get_node_or_null("RestartButton") as Button
	if restart_btn != null:
		restart_btn.text = tr("重新开始")
		restart_btn.visible = not done
