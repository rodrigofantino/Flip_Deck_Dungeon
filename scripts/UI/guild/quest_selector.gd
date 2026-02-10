extends Control
class_name QuestSelector

signal quest_changed(quest_id: StringName, quest_name: String)

@onready var left_arrow: Button = $Row/LeftArrow
@onready var right_arrow: Button = $Row/RightArrow
@onready var quest_art: TextureRect = $Row/QuestArt
@onready var quest_name: Label = $QuestName
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

var current_index: int = 0
var _quest_textures: Array[Texture2D] = []
var _current_level: int = 1
var _suppress_level_signal: bool = false

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
	level = clampi(level, 1, 6)
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
	if quest_name:
		quest_name.text = QUEST_NAMES[current_index]
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
	var level := clampi(int(round(value)), 1, 6)
	_current_level = level
	if difficulty_spin and int(round(difficulty_spin.value)) != level:
		_suppress_level_signal = true
		difficulty_spin.value = float(level)
		_suppress_level_signal = false
	if GameState != null:
		GameState.selected_quest_level = level
