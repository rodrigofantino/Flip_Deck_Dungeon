extends Control

@onready var language_label: Label = $VBoxContainer/LanguageLabel
@onready var language_button: Button = $VBoxContainer/LanguageButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var master_label: Label = $VBoxContainer/MasterRow/MasterLabel
@onready var master_slider: HSlider = $VBoxContainer/MasterRow/MasterSlider
@onready var sfx_label: Label = $VBoxContainer/SfxRow/SfxLabel
@onready var sfx_slider: HSlider = $VBoxContainer/SfxRow/SfxSlider
@onready var music_label: Label = $VBoxContainer/MusicRow/MusicLabel
@onready var music_slider: HSlider = $VBoxContainer/MusicRow/MusicSlider

func _ready() -> void:
	_refresh_texts()

	language_button.pressed.connect(_on_language_pressed)
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	_sync_sliders_from_buses()

func _refresh_texts() -> void:
	language_label.text = tr("SETTINGS_LANGUAGE_LABEL")
	language_button.text = tr("SETTINGS_LANGUAGE_BUTTON")
	back_button.text = tr("SETTINGS_BACK_BUTTON")
	master_label.text = "Master"
	sfx_label.text = "SFX"
	music_label.text = "Music"

func _on_language_pressed() -> void:
	LocalizationManager.next_language()
	_refresh_texts() # 🔑 refrescás SOLO ESTA PANTALLA

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")

func _sync_sliders_from_buses() -> void:
	master_slider.value = _get_bus_volume_linear("Master")
	sfx_slider.value = _get_bus_volume_linear("SFX")
	music_slider.value = _get_bus_volume_linear("Music")

func _on_master_volume_changed(value: float) -> void:
	_set_bus_volume_linear("Master", value)

func _on_sfx_volume_changed(value: float) -> void:
	_set_bus_volume_linear("SFX", value)

func _on_music_volume_changed(value: float) -> void:
	_set_bus_volume_linear("Music", value)

func _get_bus_index(name: String) -> int:
	return AudioServer.get_bus_index(name)

func _get_bus_volume_linear(name: String) -> float:
	var idx := _get_bus_index(name)
	if idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _set_bus_volume_linear(name: String, linear: float) -> void:
	var idx := _get_bus_index(name)
	if idx < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))
