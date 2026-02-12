extends Control
class_name QuestSelector

signal quest_changed(quest_id: StringName, quest_name: String)

@onready var left_arrow: Button = $Row/LeftArrow
@onready var right_arrow: Button = $Row/RightArrow
@onready var quest_art: TextureRect = $Row/QuestArt
@onready var quest_name: Label = $QuestName
@onready var quest_stats: Label = $QuestStats
@onready var difficulty_row: HBoxContainer = $"../DifficultyRow"
@onready var difficulty_label: Label = $"../DifficultyRow/DifficultyLabel"
@onready var difficulty_spin: SpinBox = $"../DifficultyRow/DifficultySpin"

# Order must match QUEST_ART_PATHS and QUEST_NAMES.
const QUEST_IDS: Array[StringName] = [
	&"forest",
	&"dark_forest",
	&"frozen_plains",
	&"petrid_swamp",
	&"cursed_city",
	&"magma_cavern"
]

const QUEST_NAMES: Array[String] = [
	"Forest",
	"Dark Forest",
	"Frozen Plains",
	"Petrid Swamp",
	"Cursed City",
	"Magma Cavern"
]

const QUEST_ART_PATHS: Array[String] = [
	"res://assets/quest/forest_quest_art.png",
	"res://assets/quest/dark_forest_quest_art.png",
	"res://assets/quest/frozen_plains_quest_art.png",
	"res://assets/quest/petrid_swamp_quest_art.png",
	"res://assets/quest/cursed_city_quest_art.png",
	"res://assets/quest/magma_cavern_quest_art.png"
]
const DIFFICULTY_MIN: int = 1
const DIFFICULTY_MAX: int = 6
const DIFFICULTY_BUTTON_SIZE: Vector2 = Vector2(44.0, 44.0)
const DIFFICULTY_BUTTON_GAP: int = 8
const DIFFICULTY_CORNER_RADIUS: int = 10
const DIFFICULTY_BG_COLOR: Color = Color(0.10, 0.10, 0.10, 0.9)
const DIFFICULTY_BG_HOVER_COLOR: Color = Color(0.16, 0.16, 0.16, 0.95)
const DIFFICULTY_BORDER_IDLE_COLOR: Color = Color(0.36, 0.36, 0.36, 1.0)
const DIFFICULTY_BORDER_HOVER_COLOR: Color = Color(0.62, 0.62, 0.62, 1.0)
const DIFFICULTY_BORDER_SELECTED_COLOR: Color = Color(0.20, 0.90, 0.35, 1.0)
const DIFFICULTY_TEXT_COLOR: Color = Color(0.92, 0.92, 0.92, 1.0)
const DIFFICULTY_TEXT_SELECTED_COLOR: Color = Color(0.96, 1.0, 0.96, 1.0)
const MINI_BOSS_INTERVAL_DEFAULT: int = 5
const QUEST_HOVER_OVERLAY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.62)
const QUEST_HOVER_PADDING: float = 20.0

var current_index: int = 0
var _quest_textures: Array[Texture2D] = []
var _current_level: int = 1
var _suppress_level_signal: bool = false
var _quest_stats_text: String = ""
var _quest_art_overlay: ColorRect = null
var _quest_art_overlay_label: Label = null
var _difficulty_selector: HBoxContainer = null
var _difficulty_balance_spacer: Control = null
var _difficulty_buttons: Dictionary = {}

func _ready() -> void:
	_load_textures()
	_sync_from_state()
	_wire_ui()
	_show_current()
	set_process_unhandled_input(true)

func _wire_ui() -> void:
	if left_arrow:
		left_arrow.pressed.connect(_prev)
	if right_arrow:
		right_arrow.pressed.connect(_next)
	if difficulty_spin:
		difficulty_spin.value_changed.connect(_on_difficulty_changed)
	_setup_difficulty_selector()
	_setup_quest_art_hover_overlay()
	if quest_stats:
		quest_stats.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_left"):
			_prev()
			accept_event()
		elif event.is_action_pressed("ui_right"):
			_next()
			accept_event()

func _load_textures() -> void:
	_quest_textures.clear()
	for path in QUEST_ART_PATHS:
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("[QuestSelector] Missing quest art: %s" % path)
		_quest_textures.append(tex)

func _sync_from_state() -> void:
	var desired: StringName = &"forest"
	if GameState != null:
		desired = GameState.selected_quest_id
	var idx := QUEST_IDS.find(desired)
	if idx >= 0:
		current_index = idx
	else:
		current_index = 0
	var level: int = 1
	if GameState != null:
		level = int(GameState.selected_quest_level)
	level = clampi(level, DIFFICULTY_MIN, DIFFICULTY_MAX)
	_current_level = level
	if difficulty_spin:
		_suppress_level_signal = true
		difficulty_spin.value = float(level)
		_suppress_level_signal = false

func get_selected_quest_id() -> StringName:
	if current_index < 0 or current_index >= QUEST_IDS.size():
		return &"forest"
	return QUEST_IDS[current_index]

func get_selected_quest_name() -> String:
	if current_index < 0 or current_index >= QUEST_NAMES.size():
		return "Forest"
	return QUEST_NAMES[current_index]

func get_selected_quest_level() -> int:
	return _current_level

func _show_current() -> void:
	if QUEST_IDS.is_empty():
		return
	current_index = wrapi(current_index, 0, QUEST_IDS.size())
	var tex := _get_texture_for_index(current_index)
	if quest_art:
		quest_art.texture = tex
		_sync_quest_art_overlay_to_art()
	if quest_name:
		quest_name.text = QUEST_NAMES[current_index]
	_update_current_stats()
	if GameState != null:
		GameState.selected_quest_id = QUEST_IDS[current_index]
	quest_changed.emit(QUEST_IDS[current_index], QUEST_NAMES[current_index])

func _get_texture_for_index(index: int) -> Texture2D:
	if index >= 0 and index < _quest_textures.size():
		var tex := _quest_textures[index]
		if tex != null:
			return tex
	# Fallback to forest if missing or out of range.
	if _quest_textures.size() > 0 and _quest_textures[0] != null:
		return _quest_textures[0]
	return null

func _next() -> void:
	if QUEST_IDS.is_empty():
		return
	current_index = (current_index + 1) % QUEST_IDS.size()
	_show_current()

func _prev() -> void:
	if QUEST_IDS.is_empty():
		return
	current_index = (current_index - 1 + QUEST_IDS.size()) % QUEST_IDS.size()
	_show_current()

func _on_difficulty_changed(value: float) -> void:
	if _suppress_level_signal:
		return
	_set_selected_difficulty(int(round(value)))

func _setup_difficulty_selector() -> void:
	if difficulty_row == null:
		return
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if difficulty_label:
		difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		difficulty_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		if not difficulty_label.resized.is_connected(_sync_difficulty_balance_spacer):
			difficulty_label.resized.connect(_sync_difficulty_balance_spacer)
	if difficulty_spin:
		difficulty_spin.visible = false
		difficulty_spin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _difficulty_selector == null or not is_instance_valid(_difficulty_selector):
		_difficulty_selector = difficulty_row.get_node_or_null("DifficultySelector") as HBoxContainer
	if _difficulty_selector == null:
		_difficulty_selector = HBoxContainer.new()
		_difficulty_selector.name = "DifficultySelector"
		difficulty_row.add_child(_difficulty_selector)
	_difficulty_selector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_difficulty_selector.alignment = BoxContainer.ALIGNMENT_CENTER
	_difficulty_selector.add_theme_constant_override("separation", DIFFICULTY_BUTTON_GAP)
	for child in _difficulty_selector.get_children():
		child.queue_free()
	_difficulty_buttons.clear()
	for level in range(DIFFICULTY_MIN, DIFFICULTY_MAX + 1):
		var btn := Button.new()
		btn.text = str(level)
		btn.custom_minimum_size = DIFFICULTY_BUTTON_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_difficulty_button_pressed.bind(level))
		_difficulty_selector.add_child(btn)
		_difficulty_buttons[level] = btn
	_ensure_difficulty_balance_spacer()
	_sync_difficulty_balance_spacer()
	call_deferred("_sync_difficulty_balance_spacer")
	_refresh_difficulty_selector()

func _ensure_difficulty_balance_spacer() -> void:
	if difficulty_row == null:
		return
	if _difficulty_balance_spacer == null or not is_instance_valid(_difficulty_balance_spacer):
		_difficulty_balance_spacer = difficulty_row.get_node_or_null("DifficultyBalanceSpacer") as Control
	if _difficulty_balance_spacer == null:
		_difficulty_balance_spacer = Control.new()
		_difficulty_balance_spacer.name = "DifficultyBalanceSpacer"
		_difficulty_balance_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		difficulty_row.add_child(_difficulty_balance_spacer)
	_difficulty_balance_spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	difficulty_row.move_child(_difficulty_balance_spacer, difficulty_row.get_child_count() - 1)

func _sync_difficulty_balance_spacer() -> void:
	if difficulty_label == null:
		return
	_ensure_difficulty_balance_spacer()
	if _difficulty_balance_spacer == null:
		return
	var label_width := maxf(difficulty_label.size.x, difficulty_label.get_combined_minimum_size().x)
	_difficulty_balance_spacer.custom_minimum_size = Vector2(label_width, 0.0)

func _on_difficulty_button_pressed(level: int) -> void:
	_set_selected_difficulty(level)

func _set_selected_difficulty(level: int) -> void:
	var clamped_level := clampi(level, DIFFICULTY_MIN, DIFFICULTY_MAX)
	var changed := _current_level != clamped_level
	_current_level = clamped_level
	if difficulty_spin and int(round(difficulty_spin.value)) != clamped_level:
		_suppress_level_signal = true
		difficulty_spin.value = float(clamped_level)
		_suppress_level_signal = false
	if GameState != null:
		GameState.selected_quest_level = clamped_level
	_refresh_difficulty_selector()
	if changed:
		_update_current_stats()

func _refresh_difficulty_selector() -> void:
	for key in _difficulty_buttons.keys():
		var level := int(key)
		var btn := _difficulty_buttons[key] as Button
		if btn == null:
			continue
		_apply_difficulty_button_style(btn, level == _current_level)

func _apply_difficulty_button_style(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = DIFFICULTY_BG_COLOR
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = DIFFICULTY_CORNER_RADIUS
	normal.corner_radius_top_right = DIFFICULTY_CORNER_RADIUS
	normal.corner_radius_bottom_right = DIFFICULTY_CORNER_RADIUS
	normal.corner_radius_bottom_left = DIFFICULTY_CORNER_RADIUS
	normal.border_color = DIFFICULTY_BORDER_SELECTED_COLOR if selected else DIFFICULTY_BORDER_IDLE_COLOR
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = DIFFICULTY_BG_HOVER_COLOR
	hover.border_color = DIFFICULTY_BORDER_SELECTED_COLOR if selected else DIFFICULTY_BORDER_HOVER_COLOR
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = DIFFICULTY_BG_HOVER_COLOR
	pressed.border_color = DIFFICULTY_BORDER_SELECTED_COLOR
	var focus := pressed.duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", normal)
	var text_color := DIFFICULTY_TEXT_SELECTED_COLOR if selected else DIFFICULTY_TEXT_COLOR
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", DIFFICULTY_TEXT_SELECTED_COLOR)
	btn.add_theme_color_override("font_focus_color", DIFFICULTY_TEXT_SELECTED_COLOR)

func _update_current_stats() -> void:
	if quest_stats == null:
		return
	var quest_id: StringName = get_selected_quest_id()
	var level: int = get_selected_quest_level()
	var quest_def: QuestDefinition = _get_quest_definition(quest_id)
	if quest_def == null:
		_quest_stats_text = "Sin datos de quest."
		quest_stats.text = _quest_stats_text
		_update_quest_overlay_text()
		return
	var waves: int = max(1, quest_def.get_waves(level))
	var enemies_per_wave: int = max(1, quest_def.get_enemies_per_wave(level))
	var mini_interval: int = MINI_BOSS_INTERVAL_DEFAULT
	if RunState != null:
		mini_interval = max(1, int(RunState.MINI_BOSS_INTERVAL))
	var mini_boss_count: int = int(floor(float(waves) / float(mini_interval)))
	var total_bosses: int = mini_boss_count + 1
	var reward_gold: int = max(0, quest_def.get_completion_gold(level))
	var decks_per_wave: int = max(1, quest_def.decks_per_wave)
	var enemy_level_boost: int = max(0, int(quest_def.enemy_level_boost))
	var item_drop_pct: int = int(round(maxf(0.0, float(quest_def.item_drop_chance_mult)) * 100.0))
	_quest_stats_text = "Recompensa: %dg\nWaves: %d\nBosses: %d (%d mini + 1 final)\nCartas por wave: %d\nMazos: %d\nEnemy level boost: +%d\nItem drop chance: %d%%" % [
		reward_gold,
		waves,
		total_bosses,
		mini_boss_count,
		enemies_per_wave,
		decks_per_wave,
		enemy_level_boost,
		item_drop_pct
	]
	quest_stats.text = _quest_stats_text
	_update_quest_overlay_text()

func _get_quest_definition(quest_id: StringName) -> QuestDefinition:
	if RunState == null:
		return null
	return RunState.get_quest_definition(String(quest_id))

func _setup_quest_art_hover_overlay() -> void:
	if quest_art == null:
		return
	quest_art.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_art.clip_contents = true
	if not quest_art.resized.is_connected(_sync_quest_art_overlay_to_art):
		quest_art.resized.connect(_sync_quest_art_overlay_to_art)
	if not quest_art.mouse_entered.is_connected(_on_quest_art_mouse_entered):
		quest_art.mouse_entered.connect(_on_quest_art_mouse_entered)
	if not quest_art.mouse_exited.is_connected(_on_quest_art_mouse_exited):
		quest_art.mouse_exited.connect(_on_quest_art_mouse_exited)
	if _quest_art_overlay == null or not is_instance_valid(_quest_art_overlay):
		_quest_art_overlay = quest_art.get_node_or_null("HoverOverlay") as ColorRect
	if _quest_art_overlay == null:
		_quest_art_overlay = ColorRect.new()
		_quest_art_overlay.name = "HoverOverlay"
		_quest_art_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_quest_art_overlay.color = QUEST_HOVER_OVERLAY_COLOR
		_quest_art_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quest_art.add_child(_quest_art_overlay)
	if _quest_art_overlay_label == null or not is_instance_valid(_quest_art_overlay_label):
		_quest_art_overlay_label = _quest_art_overlay.get_node_or_null("StatsLabel") as Label
	if _quest_art_overlay_label == null:
		_quest_art_overlay_label = Label.new()
		_quest_art_overlay_label.name = "StatsLabel"
		_quest_art_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_quest_art_overlay_label.offset_left = QUEST_HOVER_PADDING
		_quest_art_overlay_label.offset_top = QUEST_HOVER_PADDING
		_quest_art_overlay_label.offset_right = -QUEST_HOVER_PADDING
		_quest_art_overlay_label.offset_bottom = -QUEST_HOVER_PADDING
		_quest_art_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_quest_art_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_quest_art_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_quest_art_overlay_label.add_theme_font_size_override("font_size", 24)
		_quest_art_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quest_art_overlay.add_child(_quest_art_overlay_label)
	_sync_quest_art_overlay_to_art()
	_set_quest_overlay_visible(false)
	_update_quest_overlay_text()

func _sync_quest_art_overlay_to_art() -> void:
	if quest_art == null or _quest_art_overlay == null:
		return
	var overlay_pos := Vector2.ZERO
	var overlay_size := quest_art.size
	var tex := quest_art.texture
	if tex != null:
		var tex_size := tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			# Match the actual visible art area (fit inside the control) to avoid darkening side padding.
			var ratio := minf(quest_art.size.x / tex_size.x, quest_art.size.y / tex_size.y)
			overlay_size = tex_size * ratio
			overlay_pos = (quest_art.size - overlay_size) * 0.5
	_quest_art_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_quest_art_overlay.offset_left = 0.0
	_quest_art_overlay.offset_top = 0.0
	_quest_art_overlay.offset_right = overlay_size.x
	_quest_art_overlay.offset_bottom = overlay_size.y
	_quest_art_overlay.position = overlay_pos
	_quest_art_overlay.size = overlay_size
	_quest_art_overlay.scale = Vector2.ONE
	_quest_art_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	_quest_art_overlay.clip_contents = true
	if _quest_art_overlay_label:
		_quest_art_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_quest_art_overlay_label.offset_left = QUEST_HOVER_PADDING
		_quest_art_overlay_label.offset_top = QUEST_HOVER_PADDING
		_quest_art_overlay_label.offset_right = -QUEST_HOVER_PADDING
		_quest_art_overlay_label.offset_bottom = -QUEST_HOVER_PADDING
	if quest_art.material is ShaderMaterial:
		var art_material := quest_art.material as ShaderMaterial
		if _quest_art_overlay.material == null:
			_quest_art_overlay.material = art_material.duplicate()
		var overlay_material := _quest_art_overlay.material as ShaderMaterial
		if overlay_material:
			overlay_material.set_shader_parameter("radius", art_material.get_shader_parameter("radius"))
			overlay_material.set_shader_parameter("aa", art_material.get_shader_parameter("aa"))
			overlay_material.set_shader_parameter("tint_color", QUEST_HOVER_OVERLAY_COLOR)
	elif _quest_art_overlay.material != null:
		_quest_art_overlay.material = null
		_quest_art_overlay.color = QUEST_HOVER_OVERLAY_COLOR

func _update_quest_overlay_text() -> void:
	if _quest_art_overlay_label == null:
		return
	_quest_art_overlay_label.text = _quest_stats_text

func _set_quest_overlay_visible(visible: bool) -> void:
	if _quest_art_overlay == null:
		return
	_quest_art_overlay.visible = visible

func _on_quest_art_mouse_entered() -> void:
	_set_quest_overlay_visible(true)

func _on_quest_art_mouse_exited() -> void:
	_set_quest_overlay_visible(false)
