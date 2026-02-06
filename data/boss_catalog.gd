extends Resource
class_name BossCatalog

@export_dir var bosses_folder: String

var bosses: Array[BossDefinition] = []
var _boss_map: Dictionary = {}
var _cached_count: int = -1

func load_all() -> void:
	bosses = _load_bosses_from_folder(bosses_folder)
	_rebuild_cache()

	if bosses.is_empty():
		if bosses_folder.strip_edges().is_empty():
			print("[BossCatalog] Boss folder not set. No bosses loaded.")
		else:
			print("[BossCatalog] Boss folder empty. No bosses loaded.")
	else:
		print("[BossCatalog] Loaded bosses:", bosses.size())

func get_by_biome(biome_id: String) -> Array[BossDefinition]:
	return _filter_by_biome_and_kind(biome_id, -1)

func get_by_kind(kind: BossDefinition.BossKind) -> Array[BossDefinition]:
	return _filter_by_biome_and_kind("", int(kind))

func get_by_biome_and_kind(biome_id: String, kind: BossDefinition.BossKind) -> Array[BossDefinition]:
	return _filter_by_biome_and_kind(biome_id, int(kind))

func get_by_id(boss_id: String) -> BossDefinition:
	if boss_id.strip_edges().is_empty():
		return null
	_ensure_cache()
	return _boss_map.get(boss_id, null)

func _filter_by_biome_and_kind(biome_id: String, kind: int) -> Array[BossDefinition]:
	var result: Array[BossDefinition] = []
	var biome_filter := biome_id.strip_edges()
	var has_biome := not biome_filter.is_empty()
	var has_kind := kind >= 0

	for boss in bosses:
		if boss == null:
			continue
		if has_biome and boss.biome_id != biome_filter:
			continue
		if has_kind and int(boss.boss_kind) != kind:
			continue
		result.append(boss)

	return result

func _load_bosses_from_folder(path: String) -> Array[BossDefinition]:
	var result: Array[BossDefinition] = []

	if path.strip_edges().is_empty():
		return result

	_load_bosses_recursive(path, result)
	return result

func _load_bosses_recursive(path: String, result: Array[BossDefinition]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[BossCatalog] Cannot open folder: " + path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_load_bosses_recursive(path + "/" + file_name, result)
		elif file_name.ends_with(".tres"):
			var full_path := path + "/" + file_name
			var res := load(full_path)
			if res is BossDefinition:
				result.append(res)
			else:
				push_warning("[BossCatalog] File is not BossDefinition: " + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

func _ensure_cache() -> void:
	if _cached_count != bosses.size():
		_rebuild_cache()

func _rebuild_cache() -> void:
	_boss_map.clear()
	var seen: Dictionary = {}
	for boss in bosses:
		if boss == null:
			continue
		if boss.boss_id.strip_edges().is_empty():
			continue
		if seen.has(boss.boss_id):
			push_warning("[BossCatalog] boss_id duplicado: " + boss.boss_id)
			continue
		seen[boss.boss_id] = true
		_boss_map[boss.boss_id] = boss
	_cached_count = bosses.size()
