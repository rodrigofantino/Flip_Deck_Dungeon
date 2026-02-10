extends Resource
class_name QuestCatalog

@export_dir var quests_folder: String

var quests: Array[QuestDefinition] = []
var _quest_map: Dictionary = {}
var _cached_count: int = -1

func load_all() -> void:
	quests = _load_quests_from_folder(quests_folder)
	_rebuild_cache()

	if quests.is_empty():
		if quests_folder.strip_edges().is_empty():
			print("[QuestCatalog] Quest folder not set. No quests loaded.")
		else:
			print("[QuestCatalog] Quest folder empty. No quests loaded.")
	else:
		print("[QuestCatalog] Loaded quests:", quests.size())

func get_by_id(quest_id: String) -> QuestDefinition:
	if quest_id.strip_edges().is_empty():
		return null
	_ensure_cache()
	return _quest_map.get(quest_id, null)

func _load_quests_from_folder(path: String) -> Array[QuestDefinition]:
	var result: Array[QuestDefinition] = []
	if path.strip_edges().is_empty():
		return result
	_load_quests_recursive(path, result)
	return result

func _load_quests_recursive(path: String, result: Array[QuestDefinition]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[QuestCatalog] Cannot open folder: " + path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_load_quests_recursive(path + "/" + file_name, result)
		elif file_name.ends_with(".tres"):
			var full_path := path + "/" + file_name
			var res := load(full_path)
			if res is QuestDefinition:
				result.append(res)
			else:
				push_warning("[QuestCatalog] File is not QuestDefinition: " + full_path)
		file_name = dir.get_next()

	dir.list_dir_end()

func _ensure_cache() -> void:
	if _cached_count != quests.size():
		_rebuild_cache()

func _rebuild_cache() -> void:
	_quest_map.clear()
	var seen: Dictionary = {}
	for quest in quests:
		if quest == null:
			continue
		if quest.quest_id.strip_edges().is_empty():
			continue
		if seen.has(quest.quest_id):
			push_warning("[QuestCatalog] quest_id duplicado: " + quest.quest_id)
			continue
		seen[quest.quest_id] = true
		_quest_map[quest.quest_id] = quest
	_cached_count = quests.size()
