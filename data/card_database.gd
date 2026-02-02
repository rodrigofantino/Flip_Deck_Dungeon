extends Node
class_name CardDatabases
# Base de datos global de definiciones de cartas

# Preloads garantizan que las definiciones de tutorial estén en la build final
const TUTORIAL_DEFINITION_PRELOADS := {
	"hero_knight": preload("res://data/card_definitions/tutorialhero_knight.tres"),
	"slime": preload("res://data/card_definitions/tutorialslime.tres"),
	"wolf": preload("res://data/card_definitions/tutorialwolf.tres"),
	"spider": preload("res://data/card_definitions/tutorialspider.tres"),
	"forest_spirit": preload("res://data/card_definitions/tutorialforest_spirit.tres")
}

var definitions: Dictionary = {}
# Diccionario que guarda todas las CardDefinition cargadas

func _ready() -> void:
	# Carga todas las definiciones al iniciar el juego
	load_definitions()

func load_definitions() -> void:
	# Carga todas las definiciones desde la carpeta y subcarpetas
	definitions.clear()
	_scan_card_definitions("res://data/card_definitions")
	_register_preloaded_tutorial_definitions()

	# Alias legacy para no romper referencias viejas
	if definitions.has("hero_knight"):
		definitions["hero"] = definitions["hero_knight"]

func get_definition(key: String):
	# Devuelve una definicion de carta por su clave
	return definitions.get(key, null)

func _scan_card_definitions(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("[CardDatabase] No se pudo abrir: " + path)
		return

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if file_name.begins_with("."):
			continue

		var full_path := path + "/" + file_name
		if dir.current_is_dir():
			_scan_card_definitions(full_path)
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is CardDefinition:
				var card_def: CardDefinition = res
				if card_def.definition_id != "":
					definitions[card_def.definition_id] = card_def

	dir.list_dir_end()

func _register_preloaded_tutorial_definitions() -> void:
	for def_id in TUTORIAL_DEFINITION_PRELOADS.keys():
		if definitions.has(def_id):
			continue

		var card_def: CardDefinition = TUTORIAL_DEFINITION_PRELOADS[def_id]
		if card_def == null:
			push_error("[CardDatabase] No se pudo cargar la definicion tutorial preloaded: %s" % def_id)
			continue

		definitions[def_id] = card_def
