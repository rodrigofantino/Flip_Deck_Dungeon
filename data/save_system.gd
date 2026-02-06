extends Node
class_name SaveSystemScript
# Este script se encarga de escribir y leer
# el progreso permanente del jugador y la colecciÃ³n base


const SAVE_DIR := "user://save"
const PROFILE_SAVE_PATH := "user://save/save_profile.json"
# Ruta del archivo de guardado del perfil (carpeta segura de usuario)
const COLLECTION_SAVE_PATH := "user://save/card_collection.json"
# Ruta del archivo de guardado de la colecciÃ³n base
const RUN_DECK_SAVE_PATH := "user://save/run_deck.json"
# Ruta del archivo de guardado del deck de la run actual
const DEFAULT_STARTER_COUNTS := {
	"knight_aprentice": 1,
	"forest_slime": 1,
	"forest_wolf": 1
}


# =========================
# API PÃšBLICA
# =========================

static func save_profile(collection: PlayerCollection) -> void:
	# Guarda el perfil del jugador en disco
	var data := Serialization.player_collection_to_dict(collection)
	# Convierte la colecciÃ³n del jugador a datos planos

	_ensure_save_dir()

	var file := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.WRITE)
	# Abre (o crea) el archivo del perfil en modo escritura

	if file == null:
		# Maneja error si no se pudo abrir el archivo
		push_error("No se pudo abrir archivo de perfil")
		return

	file.store_string(JSON.stringify(data))
	# Escribe el JSON convertido a string en el archivo

	file.close()
	# Cierra el archivo correctamente


static func load_profile() -> PlayerCollection:
	# Carga el perfil guardado desde disco

	if not FileAccess.file_exists(PROFILE_SAVE_PATH):
		# Si no existe archivo de perfil
		push_warning("No existe perfil guardado")
		return null

	var file := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.READ)
	# Abre el archivo del perfil en modo lectura

	if file == null:
		# Maneja error si no se pudo abrir
		push_error("No se pudo abrir archivo de perfil")
		return null

	var content := file.get_as_text()
	# Lee todo el contenido del archivo como texto

	file.close()
	# Cierra el archivo

	var json := JSON.new()
	# Crea un parser JSON

	var err := json.parse(content)
	# Intenta parsear el texto a datos JSON

	if err != OK:
		# Maneja error si el JSON estÃ¡ corrupto
		push_error("Error parseando JSON de perfil")
		return null

	return Serialization.player_collection_from_dict(json.data)
	# Reconstruye y devuelve la PlayerCollection desde los datos


# =========================
# COLECCIÃ“N BASE
# =========================

static func save_collection(collection: PlayerCollection) -> void:
	var data := Serialization.player_collection_to_dict(collection)

	_ensure_save_dir()

	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir archivo de colecciÃ³n")
		return

	file.store_string(JSON.stringify(data))
	file.close()


static func load_collection() -> PlayerCollection:
	if not FileAccess.file_exists(COLLECTION_SAVE_PATH):
		return null

	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir archivo de colecciÃ³n")
		return null

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error("Error parseando JSON de colecciÃ³n")
		return null

	return Serialization.player_collection_from_dict(json.data)


static func ensure_collection() -> PlayerCollection:
	var existing := load_collection()
	if existing != null and _is_valid_starter_collection(existing):
		return existing

	var collection := build_default_starter_collection()
	save_collection(collection)
	return collection


static func add_persistent_gold(amount: int) -> void:
	if amount == 0:
		return
	var collection := ensure_collection()
	if collection == null:
		return
	collection.gold = max(0, collection.gold + amount)
	save_collection(collection)


static func get_persistent_gold() -> int:
	var collection := load_collection()
	if collection == null:
		return 0
	return collection.gold


static func reset_progress() -> void:
	if FileAccess.file_exists(PROFILE_SAVE_PATH):
		DirAccess.remove_absolute(PROFILE_SAVE_PATH)
	if FileAccess.file_exists(COLLECTION_SAVE_PATH):
		DirAccess.remove_absolute(COLLECTION_SAVE_PATH)
	if FileAccess.file_exists(RUN_DECK_SAVE_PATH):
		DirAccess.remove_absolute(RUN_DECK_SAVE_PATH)
	if FileAccess.file_exists("user://save/save_run.json"):
		DirAccess.remove_absolute("user://save/save_run.json")
	ensure_collection()

static func build_default_starter_collection() -> PlayerCollection:
	return _build_default_collection()


static func _build_default_collection() -> PlayerCollection:
	var collection := PlayerCollection.new()

	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()

	for def_id in DEFAULT_STARTER_COUNTS.keys():
		var def: CardDefinition = CardDatabase.get_definition(def_id)
		if def == null:
			push_warning("[SaveSystem] Falta definicion starter: " + def_id)
			continue
		var count := int(DEFAULT_STARTER_COUNTS[def_id])
		collection.add_type(def_id, count)

	return collection

static func _build_instance(def: CardDefinition) -> CardInstance:
	var card := CardInstance.new()
	card.instance_id = _generate_instance_id(def.definition_id)
	card.definition_id = def.definition_id
	card.level = def.level
	card.current_hp = def.max_hp
	return card


static func _generate_instance_id(definition_id: String) -> String:
	var time_ms := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rand := rng.randi_range(1000, 9999)
	return "%s_%d_%d" % [definition_id, time_ms, rand]


static func _is_valid_starter_collection(collection: PlayerCollection) -> bool:
	if collection == null:
		return false

	for def_id in DEFAULT_STARTER_COUNTS.keys():
		if collection.get_owned_count(def_id) != int(DEFAULT_STARTER_COUNTS[def_id]):
			return false
	return true


# =========================
# RUN DECK
# =========================

static func save_run_deck(run_deck: Array) -> void:
	_ensure_save_dir()
	var file := FileAccess.open(RUN_DECK_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir archivo de run deck")
		return
	file.store_string(JSON.stringify(run_deck))
	file.close()


static func load_run_deck() -> Array:
	if not FileAccess.file_exists(RUN_DECK_SAVE_PATH):
		return []

	var file := FileAccess.open(RUN_DECK_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir archivo de run deck")
		return []

	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if data == null or typeof(data) != TYPE_ARRAY:
		push_error("Error parseando JSON de run deck")
		return []

	var result: Array = []
	for entry in data:
		if typeof(entry) == TYPE_STRING:
			result.append(String(entry))
		elif typeof(entry) == TYPE_DICTIONARY:
			var def_id := String(entry.get("definition_id", ""))
			if def_id != "":
				result.append(def_id)
		elif typeof(entry) == TYPE_ARRAY:
			var deck_list: Array = []
			for inner in entry:
				if typeof(inner) == TYPE_STRING:
					deck_list.append(String(inner))
				elif typeof(inner) == TYPE_DICTIONARY:
					var inner_id := String(inner.get("definition_id", ""))
					if inner_id != "":
						deck_list.append(inner_id)
			result.append(deck_list)
	return result


static func clear_run_deck() -> void:
	if FileAccess.file_exists(RUN_DECK_SAVE_PATH):
		DirAccess.remove_absolute(RUN_DECK_SAVE_PATH)


static func clear_run_save() -> void:
	if FileAccess.file_exists("user://save/save_run.json"):
		DirAccess.remove_absolute("user://save/save_run.json")
	clear_run_deck()


static func remove_from_run_deck(definition_id: String) -> void:
	if definition_id == "":
		return
	var deck := load_run_deck()
	if deck.is_empty():
		return
	if deck.size() > 0 and deck[0] is Array:
		for deck_index in range(deck.size()):
			var sub_deck: Array = deck[deck_index]
			for i in range(sub_deck.size() - 1, -1, -1):
				if sub_deck[i] == definition_id:
					sub_deck.remove_at(i)
					deck[deck_index] = sub_deck
					save_run_deck(deck)
					return
	else:
		for i in range(deck.size() - 1, -1, -1):
			if deck[i] == definition_id:
				deck.remove_at(i)
				break
	save_run_deck(deck)


static func build_starter_run_deck() -> Array[String]:
	var result: Array[String] = []
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	for def_id in DEFAULT_STARTER_COUNTS.keys():
		var def: CardDefinition = CardDatabase.get_definition(def_id)
		if def == null:
			continue
		if def.card_type != "enemy":
			continue
		var count := int(DEFAULT_STARTER_COUNTS[def_id])
		for i in range(count):
			result.append(def_id)
	return result


static func build_run_deck_from_selection(
	_hero_definition_id: String,
	enemy_definition_ids: Array[String]
) -> Array[String]:
	return enemy_definition_ids.duplicate()

static func _ensure_save_dir() -> void:
	# Asegura que exista user://save en cualquier plataforma/export.
	# NOTA: make_dir_absolute puede fallar silenciosamente; usamos DirAccess.open + make_dir_recursive.

	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("[SaveSystem] No se pudo abrir user:// (sin permisos o ruta invÃ¡lida). user_dir=%s" % OS.get_user_data_dir())
		return

	var err: Error = dir.make_dir_recursive("save")
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("[SaveSystem] No se pudo crear user://save. Error=%s user_dir=%s" % [str(err), OS.get_user_data_dir()])
