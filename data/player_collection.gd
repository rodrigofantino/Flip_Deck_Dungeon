extends Resource
class_name PlayerCollection

@export var cards: Array[CardInstance] = []

# =========================
# API PÚBLICA
# =========================

func add_card(card: CardInstance) -> void:
	if card == null:
		push_error("Intento de agregar una carta null")
		return

	if has_instance(card.instance_id):
		push_error("La carta ya existe en la colección: " + card.instance_id)
		return

	cards.append(card)


func remove_card_by_instance_id(instance_id: String) -> void:
	for i in cards.size():
		if cards[i].instance_id == instance_id:
			cards.remove_at(i)
			return

	push_warning("No se encontró la carta para remover: " + instance_id)


func get_card_by_instance_id(instance_id: String) -> CardInstance:
	for card in cards:
		if card.instance_id == instance_id:
			return card
	return null


func has_instance(instance_id: String) -> bool:
	return get_card_by_instance_id(instance_id) != null


func get_all_cards() -> Array[CardInstance]:
	return cards.duplicate()


func clear() -> void:
	cards.clear()
