extends Resource
class_name ItemArchetypeCatalog

@export var archetypes: Array[ItemArchetype] = []

var _by_id: Dictionary = {}

func _ensure_index() -> void:
	if not _by_id.is_empty():
		return
	_by_id.clear()
	for archetype in archetypes:
		if archetype == null:
			continue
		var key := archetype.item_id.strip_edges()
		if key.is_empty():
			continue
		if _by_id.has(key):
			push_warning("[ItemArchetypeCatalog] item_id duplicado: " + key)
			continue
		_by_id[key] = archetype

func get_by_id(id: String) -> ItemArchetype:
	if id.is_empty():
		return null
	_ensure_index()
	if _by_id.has(id):
		return _by_id[id]
	return null

func get_by_type_and_class(item_type: int, item_class: String) -> Array[ItemArchetype]:
	var result: Array[ItemArchetype] = []
	for archetype in archetypes:
		if archetype == null:
			continue
		if archetype.item_type != item_type:
			continue
		if not item_class.is_empty() and archetype.item_class != item_class:
			continue
		result.append(archetype)
	return result
