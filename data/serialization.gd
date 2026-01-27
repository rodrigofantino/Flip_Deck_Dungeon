extends Node
class_name Serialization
# Este script se encarga de convertir objetos del juego
# a datos planos (Dictionary) y viceversa para poder guardarlos


# =========================
# CARD INSTANCE
# =========================

static func card_instance_to_dict(card: CardInstance) -> Dictionary:
	# Convierte una CardInstance en un Dictionary guardable
	return {
		"instance_id": card.instance_id,      # ID único persistente
		"definition_id": card.definition_id,  # Referencia a la definición base
		"current_hp": card.current_hp,        # Vida actual (estado variable)
		"level": card.level,                  # Nivel de la carta
		#"traits": card.traits                 # Traits aplicados (estado variable)
	}


static func card_instance_from_dict(data: Dictionary) -> CardInstance:
	# Reconstruye una CardInstance a partir de datos guardados
	var card := CardInstance.new()            # Crea una nueva instancia vacía
	card.instance_id = data["instance_id"]   # Restaura el ID original
	card.definition_id = data["definition_id"] # Restaura la referencia a la definición
	card.current_hp = data["current_hp"]     # Restaura la vida
	card.level = data["level"]               # Restaura el nivel
	#card.traits = data.get("traits", [])     # Restaura traits o array vacío
	return card                              # Devuelve la carta reconstruida


# =========================
# PLAYER COLLECTION
# =========================

static func player_collection_to_dict(collection: PlayerCollection) -> Dictionary:
	# Convierte toda la colección del jugador a datos guardables
	var cards_array: Array = []               # Array donde se guardarán las cartas

	for card in collection.cards:
		# Convierte cada CardInstance a Dictionary
		cards_array.append(card_instance_to_dict(card))

	return {
		"cards": cards_array,                 # Guarda todas las cartas del jugador
		"gold": collection.gold               # Oro persistente del jugador
	}


static func player_collection_from_dict(data: Dictionary) -> PlayerCollection:
	# Reconstruye la colección del jugador desde datos guardados
	var collection := PlayerCollection.new()  # Crea una colección vacía
	collection.gold = int(data.get("gold", 0))

	for card_data in data.get("cards", []):
		# Reconstruye cada carta individual
		var card := card_instance_from_dict(card_data)
		collection.add_card(card)             # Agrega la carta a la colección

	return collection                         # Devuelve la colección restaurada
