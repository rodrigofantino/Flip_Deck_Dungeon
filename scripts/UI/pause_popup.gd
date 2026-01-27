extends Control
class_name PausePopup

signal continue_pressed
signal menu_pressed

@onready var title_label: Label = $Panel/Content/TitleLabel
@onready var continue_button: Button = $Panel/Content/ContinueButton
@onready var menu_button: Button = $Panel/Content/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if continue_button:
		continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if menu_button:
		menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	title_label.text = tr("PAUSE_POPUP_TITLE")
	continue_button.text = tr("PAUSE_POPUP_BUTTON_CONTINUE")
	menu_button.text = tr("PAUSE_POPUP_BUTTON_MENU")

	continue_button.pressed.connect(func(): continue_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		continue_pressed.emit()
