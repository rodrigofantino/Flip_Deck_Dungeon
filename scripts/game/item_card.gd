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

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process_input(true)
	# Font sizes are configured in the scene/inspector.

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
		item_name_label.text = tr(definition.item_name)
	if item_description_label != null:
		item_description_label.text = tr(definition.item_description)
	if item_stats_label != null:
		item_stats_label.text = _build_stats_text(definition)

func _notification(what: int) -> void:
	pass

func _request_text_fit() -> void:
	pass

func _build_stats_text(def: ItemCardDefinition) -> String:
	var parts: Array[String] = []
	_append_stat(parts, tr("ITEM_STAT_ARMOUR"), def.armour_flat)
	_append_stat(parts, tr("ITEM_STAT_DAMAGE"), def.damage_flat)
	_append_stat(parts, tr("ITEM_STAT_LIFE"), def.life_flat)
	_append_stat(parts, tr("ITEM_STAT_INITIATIVE"), def.initiative_flat)
	_append_stat(parts, tr("ITEM_STAT_LIFESTEAL"), def.lifesteal_flat)
	_append_stat(parts, tr("ITEM_STAT_THORNS"), def.thorns_flat)
	_append_stat(parts, tr("ITEM_STAT_REGEN"), def.regen_flat)
	_append_stat(parts, tr("ITEM_STAT_CRIT"), def.crit_chance_flat)
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
