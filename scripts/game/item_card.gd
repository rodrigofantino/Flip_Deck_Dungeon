extends Control

signal hover_entered(card: Control)
signal hover_exited(card: Control)
signal drag_started(card: Control)
signal drag_released(card: Control, global_pos: Vector2)

enum CardState {
	IN_HAND,
	DRAGGING,
	EQUIPPED
}

@onready var item_art: TextureRect = $item_art
@onready var item_name_label: Label = $item_name
@onready var item_description_label: Label = $item_description
@onready var item_stats_label: Label = $item_stats

var definition: ItemCardDefinition = null
var item_id: String = ""
var state: CardState = CardState.IN_HAND

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _sizing_dirty: bool = false

const NAME_BASE_SIZE: int = 32
const DESC_BASE_SIZE: int = 28
const STATS_BASE_SIZE: int = 28
const MIN_FONT_SIZE: int = 12

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process_input(true)
	_request_text_fit()

func set_state(new_state: CardState) -> void:
	state = new_state

func setup(def: ItemCardDefinition) -> void:
	definition = def
	if definition == null:
		push_error("[ItemCard] Definition null")
		return

	if item_art != null:
		item_art.texture = definition.art
	if item_name_label != null:
		item_name_label.text = definition.item_name
	if item_description_label != null:
		item_description_label.text = definition.item_description
	if item_stats_label != null:
		item_stats_label.text = _build_stats_text(definition)
	_request_text_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_request_text_fit()

func _request_text_fit() -> void:
	if _sizing_dirty:
		return
	_sizing_dirty = true
	call_deferred("_fit_text_to_labels")

func _fit_text_to_labels() -> void:
	_sizing_dirty = false
	_fit_label(item_name_label, NAME_BASE_SIZE)
	_fit_label(item_description_label, DESC_BASE_SIZE)
	_fit_label(item_stats_label, STATS_BASE_SIZE)

func _fit_label(label: Label, base_size: int) -> void:
	if label == null:
		return
	var size := base_size
	label.add_theme_font_size_override("font_size", size)
	await get_tree().process_frame
	var max_width := label.size.x
	var max_height := label.size.y
	while size > MIN_FONT_SIZE:
		var min := label.get_minimum_size()
		if min.x <= max_width and min.y <= max_height:
			break
		size -= 1
		label.add_theme_font_size_override("font_size", size)
		await get_tree().process_frame

func _build_stats_text(def: ItemCardDefinition) -> String:
	var parts: Array[String] = []
	_append_stat(parts, "Armour", def.armour_flat)
	_append_stat(parts, "Damage", def.damage_flat)
	_append_stat(parts, "Life", def.life_flat)
	_append_stat(parts, "Initiative", def.initiative_flat)
	_append_stat(parts, "Lifesteal", def.lifesteal_flat)
	_append_stat(parts, "Thorns", def.thorns_flat)
	_append_stat(parts, "Regen", def.regen_flat)
	_append_stat(parts, "Crit", def.crit_chance_flat)
	return ", ".join(parts)

func _append_stat(parts: Array[String], label: String, value: int) -> void:
	if value == 0:
		return
	var sign := "+"
	if value < 0:
		sign = ""
	parts.append("%s %s%d" % [label, sign, value])

func _gui_input(event: InputEvent) -> void:
	if state != CardState.IN_HAND:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			drag_started.emit(self)

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - _drag_offset
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		drag_released.emit(self, get_global_mouse_position())

func _on_mouse_entered() -> void:
	if state != CardState.IN_HAND or _dragging:
		return
	hover_entered.emit(self)

func _on_mouse_exited() -> void:
	if state != CardState.IN_HAND or _dragging:
		return
	hover_exited.emit(self)
