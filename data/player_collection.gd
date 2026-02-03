extends Resource
class_name PlayerCollection

@export var obtained_types: Array[String] = []
@export var owned_count: Dictionary = {}
@export var upgrade_level: Dictionary = {}
@export var pool_enabled_types: Array[String] = []
@export var gold: int = 0
@export var booster_packs: Dictionary = {}

# =========================
# API PUBLICA
# =========================

func add_type(definition_id: String, amount: int = 1) -> void:
	if definition_id == "":
		push_error("Intento de agregar una carta sin definition_id")
		return
	if amount <= 0:
		return
	if not obtained_types.has(definition_id):
		obtained_types.append(definition_id)
	var current := int(owned_count.get(definition_id, 0))
	owned_count[definition_id] = current + amount

func has_type(definition_id: String) -> bool:
	return obtained_types.has(definition_id)

func get_owned_count(definition_id: String) -> int:
	return int(owned_count.get(definition_id, 0))

func get_all_types() -> Array[String]:
	return obtained_types.duplicate()

func clear() -> void:
	obtained_types.clear()
	owned_count.clear()
	upgrade_level.clear()
	pool_enabled_types.clear()

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
