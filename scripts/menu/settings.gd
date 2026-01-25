extends Control

@onready var language_label: Label = $VBoxContainer/LanguageLabel
@onready var language_button: Button = $VBoxContainer/LanguageButton
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	_refresh_texts()

	language_button.pressed.connect(_on_language_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _refresh_texts() -> void:
	language_label.text = tr("SETTINGS_LANGUAGE_LABEL")
	language_button.text = tr("SETTINGS_LANGUAGE_BUTTON")
	back_button.text = tr("SETTINGS_BACK_BUTTON")

func _on_language_pressed() -> void:
	LocalizationManager.next_language()
	_refresh_texts() # 🔑 refrescás SOLO ESTA PANTALLA

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
