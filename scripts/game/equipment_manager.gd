extends RefCounted
class_name EquipmentManager

enum EquipResult {
	OK,
	BLOCKED,
	FAILED
}

var run_manager: RunManager = null
var layout: EquipmentLayoutDefinition = null
var slot_index: Dictionary = {}

func setup(new_layout: EquipmentLayoutDefinition, new_run_manager: RunManager) -> void:
	layout = new_layout
	run_manager = new_run_manager
	_build_slot_index()

func _build_slot_index() -> void:
	slot_index.clear()
	if layout == null:
		return
	for i in range(layout.slots.size()):
		var slot_def: EquipmentSlotDefinition = layout.slots[i]
		if slot_def == null:
			continue
		var key := slot_def.slot_id
		if key.is_empty():
			continue
		slot_index[key] = i

func can_equip(slot_id: String, item: ItemInstance) -> bool:
	if item == null or item.archetype == null:
		return false
	if layout == null:
		return false
	var slot_def := _get_slot_def(slot_id)
	if slot_def == null or not slot_def.is_enabled:
		return false
	if item.archetype.item_type != slot_def.accepts_item_type:
		return false
	if not _passes_two_hand_block_rules(slot_id, item.archetype.item_type):
		return false
	if item.archetype.item_type == CardDefinition.ItemType.ONE_HAND:
		if not _passes_one_hand_tag_rules(slot_id, item):
			return false
	return true

func equip(slot_id: String, item: ItemInstance) -> EquipResult:
	if item == null or item.archetype == null:
		return EquipResult.FAILED
	if not can_equip(slot_id, item):
		return EquipResult.BLOCKED
	if run_manager == null:
		return EquipResult.FAILED
	var idx := _get_slot_index(slot_id)
	if idx < 0:
		return EquipResult.FAILED
	run_manager._equip_item_to_slot_index(idx, item.instance_id)
	return EquipResult.OK

func _get_slot_def(slot_id: String) -> EquipmentSlotDefinition:
	if layout == null:
		return null
	for slot_def in layout.slots:
		if slot_def != null and slot_def.slot_id == slot_id:
			return slot_def
	return null

func _get_slot_index(slot_id: String) -> int:
	if slot_index.has(slot_id):
		return int(slot_index[slot_id])
	return -1

func _passes_two_hand_block_rules(target_slot_id: String, item_type: int) -> bool:
	if run_manager == null:
		return false
	if item_type == CardDefinition.ItemType.TWO_HANDS:
		var one_hands: Array[String] = run_manager.get_equipped_item_ids_for_item_type(CardDefinition.ItemType.ONE_HAND)
		if not one_hands.is_empty():
			return false
	if item_type == CardDefinition.ItemType.ONE_HAND:
		var two_hands: Array[String] = run_manager.get_equipped_item_ids_for_item_type(CardDefinition.ItemType.TWO_HANDS)
		if not two_hands.is_empty():
			return false
	return true

func _passes_one_hand_tag_rules(target_slot_id: String, item: ItemInstance) -> bool:
	if run_manager == null or layout == null:
		return false
	if layout.class_id != "knight":
		return true
	var item_tag := _get_one_hand_tag(item.archetype)
	if item_tag == "":
		return true
	var slot_ids: Array[String] = run_manager.get_slot_ids_for_item_type(CardDefinition.ItemType.ONE_HAND)
	for slot_id in slot_ids:
		if slot_id == target_slot_id:
			continue
		var equipped_id := run_manager.get_equipped_item_id_for_slot(slot_id)
		if equipped_id.is_empty():
			continue
		var equipped_instance := run_manager.get_item_instance(equipped_id)
		if equipped_instance == null or equipped_instance.archetype == null:
			continue
		var equipped_tag := _get_one_hand_tag(equipped_instance.archetype)
		if equipped_tag == item_tag:
			return false
	return true

func _get_one_hand_tag(archetype: ItemArchetype) -> String:
	if archetype == null:
		return ""
	for tag in archetype.item_type_tags:
		var tag_str := String(tag).to_lower()
		if tag_str == "sword" or tag_str == "shield":
			return tag_str
	return ""
