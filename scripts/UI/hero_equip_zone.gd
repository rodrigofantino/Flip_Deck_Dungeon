extends Control
class_name HeroEquipZone

const MAX_SLOTS: int = 7
const STATE_EQUIPPED: int = 2

@export var item_card_scene: PackedScene
@export var hero_anchor_path: NodePath
@onready var slots_container: Control = $Slots
@onready var hero_anchor: Control = null

func _ready() -> void:
	if RunState:
		RunState.equip_changed.connect(_on_equip_changed)
		_on_equip_changed(RunState.get_equipped_items())
		RunState.set_completed.connect(_on_set_completed)
	hero_anchor = _resolve_hero_anchor()

func can_accept(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var instance: ItemInstance = RunState.get_item_instance(item_id)
	if instance == null or instance.archetype == null:
		return false
	return instance.archetype.item_type >= 0

func accept(item_id: String) -> int:
	return -1

func is_point_in_zone(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)

func _on_equip_changed(equipped: Array[String]) -> void:
	if slots_container == null:
		return

	var slots := _get_slot_nodes()
	for slot in slots:
		for child in slot.get_children():
			child.queue_free()

	for i in range(min(equipped.size(), MAX_SLOTS)):
		var item_id := equipped[i]
		if item_id.is_empty():
			continue
		if item_card_scene == null:
			continue
		if i >= slots.size():
			break
		var slot := slots[i]
		if slot == null:
			continue
		var card := item_card_scene.instantiate() as Control
		if card == null:
			continue
		slot.add_child(card)
		card.size = card.custom_minimum_size
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.scale = Vector2(0.15, 0.15)
		var slot_size := slot.size
		if slot_size == Vector2.ZERO:
			slot_size = slot.get_combined_minimum_size()
		var scaled_size := card.size * card.scale
		card.position = (slot_size * 0.5) - (scaled_size * 0.5)
		card.mouse_filter = Control.MOUSE_FILTER_PASS

		card.set("item_id", item_id)
		if card.has_method("set_state"):
			card.call("set_state", STATE_EQUIPPED)

		var instance: ItemInstance = RunState.get_item_instance(item_id)
		if instance == null:
			card.queue_free()
			continue
		if card.has_method("setup"):
			card.call("setup", instance)

func _get_slot_nodes() -> Array[Control]:
	var slots: Array[Control] = []
	if slots_container == null:
		return slots
	var groups := slots_container.get_children()
	var grouped_slots: Array = []
	var max_len := 0
	for group in groups:
		if group == null:
			continue
		var group_list: Array[Control] = []
		for slot in group.get_children():
			if slot is Control:
				group_list.append(slot)
		if not group_list.is_empty():
			grouped_slots.append(group_list)
			max_len = max(max_len, group_list.size())
	for i in range(max_len):
		for group_list in grouped_slots:
			if i < group_list.size():
				slots.append(group_list[i])
	if slots.is_empty():
		for slot in slots_container.get_children():
			if slot is Control:
				slots.append(slot)
	return slots

func _on_set_completed(theme: String, item_ids: Array[String]) -> void:
	if item_ids.is_empty():
		return
	var targets: Array[Control] = []
	var slots := _get_slot_nodes()
	for slot in slots:
		for child in slot.get_children():
			if child == null:
				continue
			var item_id := ""
			if child.has_method("get"):
				item_id = String(child.get("item_id"))
			if item_id != "" and item_ids.has(item_id):
				targets.append(child)

	if targets.is_empty():
		return

	var dest := _get_hero_center()
	for card in targets:
		if card == null:
			continue
		var global_pos := card.global_position
		card.reparent(get_tree().current_scene, true)
		card.global_position = global_pos
		card.z_index = 3000
		var scaled_size := card.size * card.scale
		var end_pos := dest - (scaled_size * 0.5)
		var tween := card.create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "global_position", end_pos, 0.3)
		tween.tween_property(card, "scale", card.scale * 0.1, 0.3)
		tween.tween_callback(Callable(card, "queue_free"))

func _resolve_hero_anchor() -> Control:
	if hero_anchor_path != NodePath():
		return get_node_or_null(hero_anchor_path) as Control
	return get_node_or_null("../HeroAnchor") as Control

func _get_hero_center() -> Vector2:
	if hero_anchor == null:
		hero_anchor = _resolve_hero_anchor()
	if hero_anchor != null:
		return hero_anchor.get_global_rect().get_center()
	return get_global_rect().get_center()
