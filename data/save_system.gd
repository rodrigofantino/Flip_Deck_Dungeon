extends Node
class_name SaveSystem
# Este script se encarga de escribir y leer
# el progreso permanente del jugador y la colección base


const SAVE_DIR := "user://save"
const PROFILE_SAVE_PATH := "user://save/save_profile.json"
# Ruta del archivo de guardado del perfil (carpeta segura de usuario)
const COLLECTION_SAVE_PATH := "user://save/card_collection.json"
# Ruta del archivo de guardado de la colección base
const RUN_DECK_SAVE_PATH := "user://save/run_deck.json"
# Ruta del archivo de guardado del deck de la run actual


# =========================
# API PÚBLICA
# =========================

static func save_profile(collection: PlayerCollection) -> void:
	# Guarda el perfil del jugador en disco
	var data := Serialization.player_collection_to_dict(collection)
	# Convierte la colección del jugador a datos planos

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
		# Maneja error si el JSON está corrupto
		push_error("Error parseando JSON de perfil")
		return null

	return Serialization.player_collection_from_dict(json.data)
	# Reconstruye y devuelve la PlayerCollection desde los datos


# =========================
# COLECCIÓN BASE
# =========================

static func save_collection(collection: PlayerCollection) -> void:
	var data := Serialization.player_collection_to_dict(collection)

	_ensure_save_dir()

	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir archivo de colección")
		return

	file.store_string(JSON.stringify(data))
	file.close()


static func load_collection() -> PlayerCollection:
	if not FileAccess.file_exists(COLLECTION_SAVE_PATH):
		return null

	var file := FileAccess.open(COLLECTION_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir archivo de colección")
		return null

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error("Error parseando JSON de colección")
		return null

	return Serialization.player_collection_from_dict(json.data)


static func ensure_collection() -> PlayerCollection:
	var existing := load_collection()
	if existing != null and _is_valid_tutorial_collection(existing):
		return existing

	var collection := _build_default_collection()
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


static func _build_default_collection() -> PlayerCollection:
	var collection := PlayerCollection.new()

	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()

	var def_hero: CardDefinition = CardDatabase.get_definition("hero_knight")
	var def_slime: CardDefinition = CardDatabase.get_definition("slime")
	var def_wolf: CardDefinition = CardDatabase.get_definition("wolf")
	var def_spider: CardDefinition = CardDatabase.get_definition("spider")
	var def_spirit: CardDefinition = CardDatabase.get_definition("forest_spirit")

	if def_hero != null:
		collection.add_card(_build_instance(def_hero))
	if def_slime != null:
		for i in range(3):
			collection.add_card(_build_instance(def_slime))
	if def_wolf != null:
		for i in range(3):
			collection.add_card(_build_instance(def_wolf))
	if def_spider != null:
		for i in range(3):
			collection.add_card(_build_instance(def_spider))
	if def_spirit != null:
		collection.add_card(_build_instance(def_spirit))

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


static func _is_valid_tutorial_collection(collection: PlayerCollection) -> bool:
	if collection == null:
		return false

	var counts := {
		"hero_knight": 0,
		"slime": 0,
		"wolf": 0,
		"spider": 0,
		"forest_spirit": 0
	}

	for card in collection.get_all_cards():
		var def_id := String(card.definition_id)
		if counts.has(def_id):
			counts[def_id] += 1

	return counts["hero_knight"] == 1 \
		and counts["slime"] == 3 \
		and counts["wolf"] == 3 \
		and counts["spider"] == 3 \
		and counts["forest_spirit"] == 1


# =========================
# RUN DECK
# =========================

static func save_run_deck(run_deck: Array[Dictionary]) -> void:
	_ensure_save_dir()
	var file := FileAccess.open(RUN_DECK_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir archivo de run deck")
		return
	file.store_string(JSON.stringify(run_deck))
	file.close()


static func load_run_deck() -> Array[Dictionary]:
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

	var result: Array[Dictionary] = []
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


static func clear_run_deck() -> void:
	if FileAccess.file_exists(RUN_DECK_SAVE_PATH):
		DirAccess.remove_absolute(RUN_DECK_SAVE_PATH)


static func remove_from_run_deck(run_id: String) -> void:
	if run_id == "":
		return
	var deck := load_run_deck()
	if deck.is_empty():
		return
	for i in range(deck.size() - 1, -1, -1):
		var entry: Dictionary = deck[i]
		if String(entry.get("run_id", "")) == run_id:
			deck.remove_at(i)
	save_run_deck(deck)


static func build_tutorial_run_deck() -> Array[Dictionary]:
	var collection := ensure_collection()
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()

	var run_deck: Array[Dictionary] = []
	var hero_added := false
	var counters := {}

	for card in collection.get_all_cards():
		var def: CardDefinition = CardDatabase.get_definition(card.definition_id)
		if def == null:
			continue
		if not def.is_tutorial:
			continue

		if def.card_type == "hero":
			if hero_added:
				continue
			run_deck.append({
				"run_id": "th",
				"collection_id": card.instance_id,
				"definition_id": def.definition_id,
				"is_persistent": def.is_persistent
			})
			hero_added = true
			continue

		var key := def.definition_id
		var index := int(counters.get(key, 0)) + 1
		counters[key] = index
		var run_id := "t_%s_%d" % [key, index]
		run_deck.append({
			"run_id": run_id,
			"collection_id": card.instance_id,
			"definition_id": def.definition_id,
			"is_persistent": def.is_persistent
		})

		if not def.is_persistent:
			collection.remove_card_by_instance_id(card.instance_id)

	save_collection(collection)
	return run_deck


static func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
