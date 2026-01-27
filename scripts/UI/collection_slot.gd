extends Control
class_name CollectionSlot

@export var card_view_scene: PackedScene
@export var card_base_size: Vector2 = Vector2(620, 860)

@onready var background: ColorRect = $Background
@onready var card_container: Control = $CardContainer

var card_view: CardView = null

func set_occupied(definition: CardDefinition) -> void:
	_clear_card()
	background.color = Color(0.2, 0.2, 0.2, 0.85)
	if card_view_scene == null or definition == null:
		return

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
	call_deferred("_fit_card")
	resized.connect(_fit_card)

func set_empty() -> void:
	_clear_card()
	background.color = Color(0.15, 0.15, 0.15, 0.5)

func _clear_card() -> void:
	if card_view != null:
		card_view.queue_free()
		card_view = null

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
