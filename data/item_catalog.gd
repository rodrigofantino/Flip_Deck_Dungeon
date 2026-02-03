extends Resource
class_name ItemCatalog

@export var items: Array[ItemCardDefinition] = []

var _item_map: Dictionary = {}
var _cached_count: int = -1

func get_item_by_id(id: String) -> ItemCardDefinition:
	if id.strip_edges().is_empty():
		return null

	_ensure_cache()
	return _item_map.get(id, null)

func _ensure_cache() -> void:
	if _cached_count != items.size():
		_rebuild_cache()

func _rebuild_cache() -> void:
	_item_map.clear()

	for item in items:
		if item == null:
			continue
		if item.item_id.strip_edges().is_empty():
			continue
		if _item_map.has(item.item_id):
			push_warning("[ItemCatalog] item_id duplicado: " + item.item_id)
			continue

		_item_map[item.item_id] = item

	_cached_count = items.size()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var seen_ids: Dictionary = {}

	for item in items:
		if item == null:
			warnings.append("Hay un item null en el catalogo.")
			continue
		if item.item_id.strip_edges().is_empty():
			warnings.append("Item sin item_id: " + item.resource_path)
			continue
		if seen_ids.has(item.item_id):
			warnings.append("item_id duplicado en catalogo: " + item.item_id)
		else:
			seen_ids[item.item_id] = true

	return warnings
