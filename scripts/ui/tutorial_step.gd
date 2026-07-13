## TutorialStep — Controller for the tutorial overlay CanvasLayer.
## Provides show_step/hide methods called by TutorialManager.
## The button wiring (Next → TutorialManager.advance, Skip → TutorialManager.skip)
## is handled by TutorialManager.set_overlay() — this script focuses on
## display methods and helper wiring.
extends CanvasLayer

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _dim_rect: ColorRect = $Dim
@onready var _title_label: Label = $Panel/Title
@onready var _body_label: RichTextLabel = $Panel/Body
@onready var _next_button: Button = $Panel/Buttons/Next
@onready var _skip_button: Button = $Panel/Buttons/SkipTutorial

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Register this overlay with TutorialManager.
	# TutorialManager.set_overlay will wire Next/Skip buttons and
	# store cached references.
	visible = false
	TutorialManager.set_overlay(self)


## Show the tutorial step with the given title and body text.
## If show_skip is false, the Skip button is hidden (e.g. on WELCOME step).
func show_step(title: String, body: String, show_skip: bool) -> void:
	if is_instance_valid(_title_label):
		_title_label.text = title

	if is_instance_valid(_body_label):
		_body_label.text = body

	if is_instance_valid(_skip_button):
		_skip_button.visible = show_skip

	visible = true


## Hide the entire overlay.
## (Inherits hide() from CanvasLayer — visible = false is implicit.)
