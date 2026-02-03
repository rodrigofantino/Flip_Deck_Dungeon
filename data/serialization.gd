extends Node
class_name Serialization
# Este script se encarga de convertir objetos del juego
# a datos planos (Dictionary) y viceversa para poder guardarlos


# =========================
# CARD INSTANCE (legacy)
# =========================

static func card_instance_to_dict(card: CardInstance) -> Dictionary:
	# Convierte una CardInstance en un Dictionary guardable
	return {
		"instance_id": card.instance_id,      # ID unico persistente
		"definition_id": card.definition_id,  # Referencia a la definicion base
		"current_hp": card.current_hp,        # Vida actual (estado variable)
		"level": card.level                   # Nivel de la carta
		#"traits": card.traits                # Traits aplicados (estado variable)
	}


static func card_instance_from_dict(data: Dictionary) -> CardInstance:
	# Reconstruye una CardInstance a partir de datos guardados
	var card := CardInstance.new()             # Crea una nueva instancia vacia
	card.instance_id = data["instance_id"]    # Restaura el ID original
	card.definition_id = data["definition_id"] # Restaura la referencia a la definicion
	card.current_hp = data["current_hp"]      # Restaura la vida
	card.level = data["level"]                # Restaura el nivel
	#card.traits = data.get("traits", [])     # Restaura traits o array vacio
	return card                               # Devuelve la carta reconstruida


# =========================
# PLAYER COLLECTION
# =========================

static func player_collection_to_dict(collection: PlayerCollection) -> Dictionary:
	# Convierte toda la coleccion del jugador a datos guardables
	return {
		"obtained_types": collection.obtained_types,
		"owned_count": collection.owned_count,
		"upgrade_level": collection.upgrade_level,
		"pool_enabled_types": collection.pool_enabled_types,
		"gold": collection.gold,
		"boosters": collection.booster_packs
	}


static func player_collection_from_dict(data: Dictionary) -> PlayerCollection:
	# Reconstruye la coleccion del jugador desde datos guardados
	var collection := PlayerCollection.new()
	collection.gold = int(data.get("gold", 0))
	collection.booster_packs = data.get("boosters", {})

	var obtained_types: Array[String] = []
	var owned_count: Dictionary = {}

	if data.has("obtained_types"):
		obtained_types = _to_string_array(data.get("obtained_types", []))
		owned_count = data.get("owned_count", {})
	else:
		# Migracion desde formato viejo con instancias unicas
		for card_data in data.get("cards", []):
			var def_id := String(card_data.get("definition_id", ""))
			if def_id == "":
				continue
			if not obtained_types.has(def_id):
				obtained_types.append(def_id)
			owned_count[def_id] = int(owned_count.get(def_id, 0)) + 1

	# Asegurar que owned_count incluya todas las keys
	for def_id in obtained_types:
		if not owned_count.has(def_id):
			owned_count[def_id] = 1

	collection.obtained_types = obtained_types
	collection.owned_count = owned_count
	collection.upgrade_level = data.get("upgrade_level", {})
	if _has_property(collection, "pool_enabled_types"):
		collection.set("pool_enabled_types", _to_string_array(data.get("pool_enabled_types", [])))

	return collection

static func _has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	for entry in target.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false

static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_STRING:
			result.append(String(entry))
	return result
