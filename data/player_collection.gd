extends Resource
class_name PlayerCollection

@export var cards: Array[CardInstance] = []
@export var gold: int = 0
@export var booster_packs: Dictionary = {}

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

func add_booster(pack_type: String, amount: int = 1) -> void:
	if pack_type == "":
		return
	if amount <= 0:
		return
	var current := int(booster_packs.get(pack_type, 0))
	booster_packs[pack_type] = current + amount

func get_booster_count(pack_type: String) -> int:
	return int(booster_packs.get(pack_type, 0))

func remove_booster(pack_type: String, amount: int = 1) -> bool:
	if pack_type == "":
		return false
	if amount <= 0:
		return false
	var current := int(booster_packs.get(pack_type, 0))
	if current < amount:
		return false
	var next := current - amount
	if next <= 0:
		booster_packs.erase(pack_type)
	else:
		booster_packs[pack_type] = next
	return true
