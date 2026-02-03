extends Control
class_name HeroEquipZone

const MAX_SLOTS: int = 8
const ITEM_CATALOG_DEFAULT_PATH: String = "res://data/item_catalog_default.tres"
const STATE_EQUIPPED: int = 2

const SLOT_ORDER: Array[String] = [
	"helmet",
	"armour",
	"gloves",
	"boots",
	"one_hand",
	"two_hands",
	"amulet",
	"ring"
]

@export var item_card_scene: PackedScene
@export var item_catalog: ItemCatalog

@onready var slots_container: HBoxContainer = $Slots

func _ready() -> void:
	if RunState:
		RunState.equip_changed.connect(_on_equip_changed)
		_on_equip_changed(RunState.get_equipped_items())

func can_accept(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	return _get_item_type(item_id) != ""

func accept(item_id: String) -> int:
	var item_type := _get_item_type(item_id)
	var idx := SLOT_ORDER.find(item_type)
	if idx == -1:
		return 0
	return idx

func is_point_in_zone(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)

func _on_equip_changed(equipped: Array[String]) -> void:
	if slots_container == null:
		return

	for slot in slots_container.get_children():
		for child in slot.get_children():
			child.queue_free()

	var catalog := _get_item_catalog()

	for i in range(min(equipped.size(), MAX_SLOTS)):
		var item_id := equipped[i]
		if item_id.is_empty():
			continue
		if item_card_scene == null:
			continue
		var slot := slots_container.get_child(i) as Control
		if slot == null:
			continue
		var card := item_card_scene.instantiate() as Control
		if card == null:
			continue
		slot.add_child(card)
		card.size = card.custom_minimum_size
		card.set_anchors_preset(Control.PRESET_CENTER)
		card.offset_left = -card.size.x * 0.5
		card.offset_top = -card.size.y * 0.5
		card.offset_right = card.size.x * 0.5
		card.offset_bottom = card.size.y * 0.5
		card.scale = Vector2(0.2776, 0.2776)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		card.set("item_id", item_id)
		if card.has_method("set_state"):
			card.call("set_state", STATE_EQUIPPED)

		var def: ItemCardDefinition = null
		if catalog != null:
			def = catalog.get_item_by_id(item_id)
		if def != null and card.has_method("setup"):
			card.call("setup", def)

func _get_item_catalog() -> ItemCatalog:
	if item_catalog != null:
		return item_catalog
	item_catalog = load(ITEM_CATALOG_DEFAULT_PATH) as ItemCatalog
	return item_catalog

func _get_item_type(item_id: String) -> String:
	var catalog := _get_item_catalog()
	if catalog == null:
		return ""
	var def := catalog.get_item_by_id(item_id)
	if def == null:
		return ""
	return def.item_type
