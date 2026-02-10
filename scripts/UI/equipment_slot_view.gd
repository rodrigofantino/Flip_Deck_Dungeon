extends Panel
class_name EquipmentSlotView

static var _active_hover_owner: EquipmentSlotView = null
static var _all_slots: Array[EquipmentSlotView] = []

@export var slot_id: String = ""
@export var accepts_item_type: int = CardDefinition.ItemType.HELMET
@export var is_enabled: bool = true
@export var item_card_scene: PackedScene

@onready var art_rect: TextureRect = $Art

var run_manager: RunManager = null
var equipment_manager: EquipmentManager = null
var _hover_card: Control = null
var _hover_item_id: String = ""
var _hover_fade_tween: Tween = null
var _is_hovering_slot: bool = false

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
	gui_input.connect(_on_gui_input)
	if not _all_slots.has(self):
		_all_slots.append(self)

func _exit_tree() -> void:
	if _all_slots.has(self):
		_all_slots.erase(self)
	if _active_hover_owner == self:
		_active_hover_owner = null

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
	_is_hovering_slot = true
	if run_manager == null:
		return
	var item_id := run_manager.get_equipped_item_id_for_slot(slot_id)
	if item_id.is_empty():
		return
	if _hover_card != null and _hover_item_id == item_id and is_instance_valid(_hover_card):
		return
	var instance := run_manager.get_item_instance(item_id)
	if instance == null:
		return
	_show_hover_card(instance)

func _on_mouse_exited() -> void:
	_is_hovering_slot = false
	call_deferred("_validate_hover_exit")

func _validate_hover_exit() -> void:
	if get_global_rect().has_point(get_global_mouse_position()):
		_is_hovering_slot = true
		return
	_hide_hover_card()

func _on_gui_input(event: InputEvent) -> void:
	if not _is_hovering_slot:
		return
	if event is InputEventMouseMotion:
		if not get_global_rect().has_point(get_global_mouse_position()):
			_is_hovering_slot = false
			_hide_hover_card()

func _process(_delta: float) -> void:
	if _active_hover_owner != self and _hover_card != null:
		_force_hide_hover_card()
		return
	if _hover_card == null:
		return
	if _is_mouse_over_any_slot():
		return
	_is_hovering_slot = false
	_hide_hover_card()

static func _is_mouse_over_any_slot() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var vp: Viewport = tree.root
	if vp == null:
		return false
	var pos: Vector2 = vp.get_mouse_position()
	for slot: EquipmentSlotView in _all_slots:
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.get_global_rect().has_point(pos):
			return true
	return false

func _show_hover_card(instance: ItemInstance) -> void:
	if item_card_scene == null:
		return
	if _hover_card != null and is_instance_valid(_hover_card) and _hover_item_id == instance.instance_id:
		_active_hover_owner = self
		return
	if _active_hover_owner != null and _active_hover_owner != self:
		_active_hover_owner._force_hide_hover_card()
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
	card.modulate.a = 0.0
	card.set("item_id", instance.instance_id)
	if card.has_method("set_state"):
		card.call("set_state", 0)
	if card.has_method("setup"):
		card.call("setup", instance)
	var mouse_pos := get_global_mouse_position()
	card.global_position = mouse_pos - (card.size * card.scale * 0.5)
	_hover_card = card
	_hover_item_id = instance.instance_id
	_active_hover_owner = self
	_hover_fade_tween = create_tween()
	_hover_fade_tween.set_trans(Tween.TRANS_SINE)
	_hover_fade_tween.set_ease(Tween.EASE_OUT)
	_hover_fade_tween.tween_property(card, "modulate:a", 1.0, 0.12)

func _hide_hover_card() -> void:
	if _hover_fade_tween != null and _hover_fade_tween.is_valid():
		_hover_fade_tween.kill()
		_hover_fade_tween = null
	if _hover_card != null and is_instance_valid(_hover_card):
		var card := _hover_card
		_hover_fade_tween = create_tween()
		_hover_fade_tween.set_trans(Tween.TRANS_SINE)
		_hover_fade_tween.set_ease(Tween.EASE_OUT)
		_hover_fade_tween.tween_property(card, "modulate:a", 0.0, 0.12)
		_hover_fade_tween.finished.connect(func():
			if card != null and is_instance_valid(card):
				card.queue_free()
		)
	_hover_card = null
	_hover_item_id = ""
	if _active_hover_owner == self:
		_active_hover_owner = null

func _force_hide_hover_card() -> void:
	_is_hovering_slot = false
	_hide_hover_card()
