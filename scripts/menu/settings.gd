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
@onready var video_label: Label = $VBoxContainer/VideoLabel
@onready var display_mode_label: Label = $VBoxContainer/DisplayModeRow/DisplayModeLabel
@onready var display_mode_option: OptionButton = $VBoxContainer/DisplayModeRow/DisplayModeOption
@onready var resolution_label: Label = $VBoxContainer/ResolutionRow/ResolutionLabel
@onready var resolution_option: OptionButton = $VBoxContainer/ResolutionRow/ResolutionOption
@onready var vsync_label: Label = $VBoxContainer/VsyncRow/VsyncLabel
@onready var vsync_check: CheckBox = $VBoxContainer/VsyncRow/VsyncCheck
@onready var fps_label: Label = $VBoxContainer/FpsRow/FpsLabel
@onready var fps_option: OptionButton = $VBoxContainer/FpsRow/FpsOption

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const FPS_VALUES: Array[int] = [30, 60, 120, 0]

enum DisplayMode {
	WINDOWED,
	FULLSCREEN,
	BORDERLESS
}

var _resolution_values: Array[Vector2i] = []
var _syncing_sliders: bool = false

func _ready() -> void:
	_refresh_texts()

	language_button.pressed.connect(_on_language_pressed)
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	_ensure_audio_busses()
	_sync_sliders_from_buses()
	if MusicManager and MusicManager.has_method("refresh_bus"):
		MusicManager.call("refresh_bus")
	_setup_video_options()

func _refresh_texts() -> void:
	language_label.text = tr("SETTINGS_LANGUAGE_LABEL")
	language_button.text = tr("SETTINGS_LANGUAGE_BUTTON")
	back_button.text = tr("SETTINGS_BACK_BUTTON")
	master_label.text = tr("SETTINGS_MASTER_LABEL")
	sfx_label.text = tr("SETTINGS_SFX_LABEL")
	music_label.text = tr("SETTINGS_MUSIC_LABEL")
	if video_label:
		video_label.text = tr("SETTINGS_VIDEO_LABEL")
	if display_mode_label:
		display_mode_label.text = tr("SETTINGS_DISPLAY_MODE_LABEL")
	if resolution_label:
		resolution_label.text = tr("SETTINGS_RESOLUTION_LABEL")
	if vsync_label:
		vsync_label.text = tr("SETTINGS_VSYNC_LABEL")
	if fps_label:
		fps_label.text = tr("SETTINGS_MAX_FPS_LABEL")
	if vsync_check:
		vsync_check.text = tr("SETTINGS_VSYNC_TOGGLE")

func _on_language_pressed() -> void:
	LocalizationManager.next_language()
	_refresh_texts() # ðŸ”‘ refrescÃ¡s SOLO ESTA PANTALLA

func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")

func _sync_sliders_from_buses() -> void:
	_syncing_sliders = true
	master_slider.value = _get_bus_volume_linear("Master")
	sfx_slider.value = _get_bus_volume_linear("SFX")
	music_slider.value = _get_bus_volume_linear("Music")
	_syncing_sliders = false

func _on_master_volume_changed(value: float) -> void:
	if _syncing_sliders:
		return
	_set_bus_volume_linear("Master", value)

func _on_sfx_volume_changed(value: float) -> void:
	if _syncing_sliders:
		return
	_set_bus_volume_linear("SFX", value)

func _on_music_volume_changed(value: float) -> void:
	if _syncing_sliders:
		return
	_set_bus_volume_linear("Music", value)

func _get_bus_index(name: String) -> int:
	var idx := AudioServer.get_bus_index(name)
	if idx >= 0:
		return idx
	var target := name.to_lower()
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i).to_lower() == target:
			return i
	push_warning("[Settings] Audio bus not found: %s" % name)
	return -1

func _get_bus_volume_linear(name: String) -> float:
	var idx := _get_bus_index(name)
	if idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _set_bus_volume_linear(name: String, linear: float) -> void:
	var idx := _get_bus_index(name)
	if idx < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	var mute := clamped <= 0.001
	AudioServer.set_bus_mute(idx, mute)
	if mute:
		AudioServer.set_bus_volume_db(idx, linear_to_db(0.001))
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))

func _ensure_audio_busses() -> void:
	_ensure_bus_exists("Music", "Master")
	_ensure_bus_exists("SFX", "Master")

func _ensure_bus_exists(name: String, send_to: String) -> void:
	if _get_bus_index(name) >= 0:
		return
	var new_idx := AudioServer.get_bus_count()
	AudioServer.add_bus(new_idx)
	AudioServer.set_bus_name(new_idx, name)
	var send_idx := _get_bus_index(send_to)
	if send_idx >= 0:
		AudioServer.set_bus_send(new_idx, AudioServer.get_bus_name(send_idx))
	AudioServer.set_bus_volume_db(new_idx, 0.0)

func _setup_video_options() -> void:
	if display_mode_option:
		display_mode_option.clear()
		display_mode_option.add_item(tr("SETTINGS_DISPLAY_WINDOWED"), DisplayMode.WINDOWED)
		display_mode_option.add_item(tr("SETTINGS_DISPLAY_FULLSCREEN"), DisplayMode.FULLSCREEN)
		display_mode_option.add_item(tr("SETTINGS_DISPLAY_BORDERLESS"), DisplayMode.BORDERLESS)
		display_mode_option.item_selected.connect(_on_display_mode_selected)
	if resolution_option:
		resolution_option.clear()
		_resolution_values.clear()
		for res in RESOLUTIONS:
			_resolution_values.append(res)
			resolution_option.add_item("%dx%d" % [res.x, res.y])
		resolution_option.item_selected.connect(_on_resolution_selected)
	if fps_option:
		fps_option.clear()
		for fps in FPS_VALUES:
			var label := tr("SETTINGS_MAX_FPS_UNLIMITED") if fps == 0 else ("%d" % fps)
			fps_option.add_item(label)
		fps_option.item_selected.connect(_on_fps_selected)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)

	_sync_video_state()

func _sync_video_state() -> void:
	var mode := _get_current_display_mode()
	if display_mode_option:
		display_mode_option.select(mode)
	if resolution_option:
		_select_resolution_for_current_window()
	if vsync_check:
		var vsync_mode := DisplayServer.window_get_vsync_mode()
		vsync_check.button_pressed = vsync_mode != DisplayServer.VSYNC_DISABLED
	if fps_option:
		var fps := Engine.max_fps
		var idx := FPS_VALUES.find(fps)
		if idx < 0:
			idx = FPS_VALUES.find(0)
		fps_option.select(max(0, idx))
	_update_video_controls_for_mode(mode)

func _get_current_display_mode() -> int:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return DisplayMode.FULLSCREEN
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return DisplayMode.BORDERLESS
	return DisplayMode.WINDOWED

func _update_video_controls_for_mode(mode: int) -> void:
	if resolution_option:
		resolution_option.disabled = mode != DisplayMode.WINDOWED

func _select_resolution_for_current_window() -> void:
	if resolution_option == null:
		return
	var current := DisplayServer.window_get_size()
	var idx := _resolution_values.find(current)
	if idx < 0:
		_resolution_values.append(current)
		resolution_option.add_item("%dx%d" % [current.x, current.y])
		idx = _resolution_values.size() - 1
	resolution_option.select(idx)

func _apply_resolution(res: Vector2i) -> void:
	DisplayServer.window_set_size(res)
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i((screen.x - res.x) / 2, (screen.y - res.y) / 2))

func _on_display_mode_selected(index: int) -> void:
	match index:
		DisplayMode.WINDOWED:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if resolution_option and resolution_option.selected >= 0 and resolution_option.selected < _resolution_values.size():
				_apply_resolution(_resolution_values[resolution_option.selected])
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var size := DisplayServer.screen_get_size()
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(Vector2i.ZERO)
	_update_video_controls_for_mode(index)

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= _resolution_values.size():
		return
	if _get_current_display_mode() != DisplayMode.WINDOWED:
		return
	_apply_resolution(_resolution_values[index])

func _on_vsync_toggled(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func _on_fps_selected(index: int) -> void:
	if index < 0 or index >= FPS_VALUES.size():
		return
	Engine.max_fps = FPS_VALUES[index]
