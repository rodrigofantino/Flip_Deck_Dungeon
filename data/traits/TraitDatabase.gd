extends Resource
class_name TraitDatabase

@export_dir var hero_traits_folder: String
@export_dir var enemy_traits_folder: String

var hero_traits: Array[TraitResource] = []
var enemy_traits: Array[TraitResource] = []

func load_all() -> void:
	hero_traits = _load_traits_from_folder(hero_traits_folder)
	enemy_traits = _load_traits_from_folder(enemy_traits_folder)

	print("[TraitDatabase] Loaded hero traits:", hero_traits.size())
	print("[TraitDatabase] Loaded enemy traits:", enemy_traits.size())

func _load_traits_from_folder(path: String) -> Array[TraitResource]:
	var result: Array[TraitResource] = []

	if path.is_empty():
		return result

	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Cannot open folder: " + path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path + "/" + file_name
			var res := load(full_path)

			if res is TraitResource:
				result.append(res)
			else:
				push_error("Archivo no es TraitResource: " + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return result
