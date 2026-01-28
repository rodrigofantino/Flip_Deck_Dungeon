extends Control
class_name CollectionSlot

@export var card_view_scene: PackedScene
@export var card_base_size: Vector2 = Vector2(620, 860)

@onready var background: ColorRect = $Background
@onready var card_container: Control = $CardContainer
@onready var selection_outline: Panel = $SelectionOutline

var card_view: CardView = null
var current_def_id: String = ""
var current_instance_id: String = ""
var current_card_type: String = ""

signal slot_clicked(slot: CollectionSlot)

func set_occupied(definition: CardDefinition, instance_id: String = "") -> void:
	_clear_card()
	background.color = Color(0.2, 0.2, 0.2, 0.85)
	if card_view_scene == null or definition == null:
		return
	current_def_id = definition.definition_id
	current_card_type = definition.card_type
	current_instance_id = instance_id

	card_view = card_view_scene.instantiate()
	card_container.add_child(card_view)
	card_view.custom_minimum_size = card_base_size
	card_view.size = card_base_size
	card_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_view.offset_left = 0.0
	card_view.offset_top = 0.0
	card_view.offset_right = card_base_size.x
	card_view.offset_bottom = card_base_size.y
	card_view.setup_from_definition(definition)
	card_view.show_front()
	_set_mouse_filter_recursive(card_view, Control.MOUSE_FILTER_IGNORE)
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_fit_card")
	resized.connect(_fit_card)

func set_empty() -> void:
	_clear_card()
	background.color = Color(0.15, 0.15, 0.15, 0.5)
	current_def_id = ""
	current_instance_id = ""
	current_card_type = ""

func _clear_card() -> void:
	if card_view != null:
		card_view.queue_free()
		card_view = null

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group("collection_slots")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selection_outline:
		var style := StyleBoxFlat.new()
		style.border_color = Color(0.2, 0.9, 0.2, 1.0)
		style.border_width_left = 6
		style.border_width_top = 6
		style.border_width_right = 6
		style.border_width_bottom = 6
		style.bg_color = Color(0, 0, 0, 0)
		selection_outline.add_theme_stylebox_override("panel", style)
		selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[CollectionSlot] Click:", name, "inst:", current_instance_id, "def:", current_def_id)
		slot_clicked.emit(self)

func set_selected(selected: bool) -> void:
	if selection_outline:
		selection_outline.visible = selected

func _fit_card() -> void:
	if card_view == null:
		return
	var target_size: Vector2 = size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return
	var scale_w: float = target_size.x / card_base_size.x
	var scale_h: float = target_size.y / card_base_size.y
	var final_scale: float = min(scale_w, scale_h)
	card_view.scale = Vector2(final_scale, final_scale)
	card_view.position = (target_size * 0.5) - (card_base_size * final_scale * 0.5)
