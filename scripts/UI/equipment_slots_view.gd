extends Control
class_name EquipmentSlotsView

@export var slot_view_scene: PackedScene

@onready var slots_container: GridContainer = $SlotsContainer

var run_manager: RunManager = null
var equipment_manager: EquipmentManager = null
var layout: EquipmentLayoutDefinition = null
var slot_views: Dictionary = {}
var _connected: bool = false

func setup(class_id: String, new_run_manager: RunManager) -> void:
	run_manager = new_run_manager
	if run_manager != null:
		layout = run_manager.get_equipment_layout_for_class(class_id)
		equipment_manager = run_manager.get_equipment_manager()
	_build_slots()
	_refresh_equipped()
	if run_manager != null:
		if not _connected:
			run_manager.equip_changed.connect(_on_equip_changed)
			_connected = true

func _build_slots() -> void:
	if slots_container == null:
		return
	for child in slots_container.get_children():
		child.queue_free()
	slot_views.clear()
	if layout == null or slot_view_scene == null:
		return
	for slot_def in layout.slots:
		if slot_def == null:
			continue
		var slot := slot_view_scene.instantiate() as Control
		if slot == null:
			continue
		slots_container.add_child(slot)
		if slot is EquipmentSlotView:
			var view := slot as EquipmentSlotView
			view.setup(slot_def, run_manager, equipment_manager)
			slot_views[slot_def.slot_id] = view

func _refresh_equipped() -> void:
	if run_manager == null:
		return
	for slot_id in slot_views.keys():
		var view: EquipmentSlotView = slot_views[slot_id]
		if view == null:
			continue
		var item_id := run_manager.get_equipped_item_id_for_slot(String(slot_id))
		var instance := run_manager.get_item_instance(item_id)
		view.set_equipped_instance(instance)

func _on_equip_changed(_equipped: Array[String]) -> void:
	_refresh_equipped()
