extends Control
class_name DefeatPopup

signal back_to_menu_pressed

@onready var label: Label = $Panel/VBoxContainer/Label
@onready var back_button: Button = $Panel/VBoxContainer/Button

func _ready() -> void:
	visible = false
	if label:
		label.text = tr("DEFEAT_POPUP_LABEL")
	back_button.pressed.connect(_on_back_pressed)

func show_popup() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _on_back_pressed() -> void:
	print("BACK BUTTON PRESSED")
	emit_signal("back_to_menu_pressed")
