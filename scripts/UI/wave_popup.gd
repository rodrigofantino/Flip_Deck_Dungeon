extends Control
class_name WavePopup

signal continue_pressed
signal retreat_pressed

@onready var title_label: Label = $Panel/Content/TitleLabel
@onready var continue_button: Button = $Panel/Content/Buttons/ContinueButton
@onready var retreat_button: Button = $Panel/Content/Buttons/RetreatButton

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if retreat_button:
		retreat_button.pressed.connect(_on_retreat_pressed)

func show_popup(wave_index: int) -> void:
	visible = true
	z_index = 250
	if title_label:
		title_label.text = tr("WAVE_POPUP_TITLE").format({
			"value": wave_index
		})

func hide_popup() -> void:
	visible = false

func _on_continue_pressed() -> void:
	continue_pressed.emit()

func _on_retreat_pressed() -> void:
	retreat_pressed.emit()
