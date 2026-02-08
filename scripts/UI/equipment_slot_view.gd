extends Panel
class_name EquipmentSlotView

@export var slot_id: String = ""
@export var accepts_item_type: int = CardDefinition.ItemType.HELMET
@export var is_enabled: bool = true
@export var item_card_scene: PackedScene

@onready var art_rect: TextureRect = $Art

var run_manager: RunManager = null
var equipment_manager: EquipmentManager = null
var _hover_card: Control = null

func setup(
	slot_def: EquipmentSlotDefinition,
	new_run_manager: RunManager,
	new_equipment_manager: EquipmentManager
) -> void:
	if slot_def != null:
		slot_id = slot_def.slot_id
		accepts_item_type = slot_def.accepts_item_type
		is_enabled = slot_def.is_enabled
	run_manager = new_run_manager
	equipment_manager = new_equipment_manager
	_update_enabled_state()
	_apply_placeholder_style()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_equipped_instance(item: ItemInstance) -> void:
	if art_rect == null:
		return
	if item == null or item.archetype == null:
		art_rect.texture = null
		return
	art_rect.texture = item.archetype.art

func _update_enabled_state() -> void:
	visible = is_enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if is_enabled else Control.MOUSE_FILTER_IGNORE

func _apply_placeholder_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.6)
	style.border_color = Color(0.7, 0.7, 0.75, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	add_theme_stylebox_override("panel", style)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_enabled:
		return false
	if equipment_manager == null or run_manager == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var dict := data as Dictionary
	var item_id := String(dict.get("item_id", ""))
	if item_id.is_empty():
		return false
	var instance := run_manager.get_item_instance(item_id)
	if instance == null or instance.archetype == null:
		return false
	if instance.archetype.item_type != accepts_item_type:
		return false
	return equipment_manager.can_equip(slot_id, instance)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if equipment_manager == null or run_manager == null:
		return
	if typeof(data) != TYPE_DICTIONARY:
		return
	var dict := data as Dictionary
	var item_id := String(dict.get("item_id", ""))
	if item_id.is_empty():
		return
	var instance := run_manager.get_item_instance(item_id)
	if instance == null:
		return
	var result := equipment_manager.equip(slot_id, instance)
	if result == EquipmentManager.EquipResult.OK:
		set_equipped_instance(instance)

func _on_mouse_entered() -> void:
	if run_manager == null:
		return
	var item_id := run_manager.get_equipped_item_id_for_slot(slot_id)
	if item_id.is_empty():
		return
	var instance := run_manager.get_item_instance(item_id)
	if instance == null:
		return
	_show_hover_card(instance)

func _on_mouse_exited() -> void:
	_hide_hover_card()

func _show_hover_card(instance: ItemInstance) -> void:
	if item_card_scene == null:
		return
	_hide_hover_card()
	var card := item_card_scene.instantiate() as Control
	if card == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(card)
	card.z_index = 5000
	card.scale = Vector2.ONE * 0.22
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set("item_id", instance.instance_id)
	if card.has_method("set_state"):
		card.call("set_state", 0)
	if card.has_method("setup"):
		card.call("setup", instance)
	var mouse_pos := get_global_mouse_position()
	card.global_position = mouse_pos - (card.size * card.scale * 0.5)
	_hover_card = card

func _hide_hover_card() -> void:
	if _hover_card != null:
		_hover_card.queue_free()
	_hover_card = null
