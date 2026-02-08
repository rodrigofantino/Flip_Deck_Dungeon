extends Resource
class_name CardDefinition

@export var definition_id: String
# ID lógico: "hero", "slime", "wolf", etc

@export var display_name: String
# Nombre visible de la carta

@export var description: String
# Texto descriptivo (traducible)

@export var art: Texture2D
# Arte específico de la carta

@export var frame_texture: Texture2D
# Marco específico de la carta (opcional)

@export var level: int = 1
# Nivel base de la carta

@export var power: int = 0
# Power (para escalados futuros)

@export var max_hp: int
# Vida máxima

@export var damage: int
# Daño base

@export var initiative: int = 1
# Iniciativa base

@export_enum("hero", "enemy") var card_type: String
# Tipo de carta

@export_enum("none", "knight", "sorcerer", "ranger", "bard", "rogue") var hero_class: String = "none"
# Clase del heroe (solo aplica si card_type == "hero")

@export var is_persistent: bool = false
# Si la carta es persistente en la colección base

@export var is_tutorial: bool = false
# Si la carta pertenece al set de tutorial


@export_enum("Base Set", "Forest", "Dark Forest", "Hero Gold") var biome_modifier: String = "Forest"
# Bioma de la carta (solo uno)

enum ItemType {
	HELMET,
	ARMOUR,
	GLOVES,
	BOOTS,
	ONE_HAND,
	TWO_HANDS
}

@export var allowed_item_types: Dictionary = {}
# Pesos por ItemType para drops (solo aplica a enemigos)

func get_allowed_item_type_weights() -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = {}
	if allowed_item_types != null:
		source = allowed_item_types

	for key in source.keys():
		var type_id := _coerce_item_type_key(key)
		if type_id < 0:
			continue
		var weight := int(source.get(key, 0))
		if weight <= 0:
			continue
		result[type_id] = weight

	if result.is_empty():
		return _get_default_item_type_weights()

	return result

static func get_item_type_name(item_type: int) -> String:
	match item_type:
		ItemType.HELMET:
			return "ITEM_TYPE_HELMET"
		ItemType.ARMOUR:
			return "ITEM_TYPE_ARMOUR"
		ItemType.GLOVES:
			return "ITEM_TYPE_GLOVES"
		ItemType.BOOTS:
			return "ITEM_TYPE_BOOTS"
		ItemType.ONE_HAND:
			return "ITEM_TYPE_ONE_HAND"
		ItemType.TWO_HANDS:
			return "ITEM_TYPE_TWO_HANDS"
		_:
			return "UNKNOWN"

static func _get_default_item_type_weights() -> Dictionary:
	return {
		ItemType.HELMET: 1,
		ItemType.ARMOUR: 1,
		ItemType.GLOVES: 1,
		ItemType.BOOTS: 1,
		ItemType.ONE_HAND: 1,
		ItemType.TWO_HANDS: 1
	}

static func _coerce_item_type_key(key: Variant) -> int:
	if typeof(key) == TYPE_INT:
		var id := int(key)
		if id >= 0 and id <= ItemType.TWO_HANDS:
			return id
	if typeof(key) == TYPE_STRING:
		var name := String(key).to_upper()
		match name:
			"HELMET":
				return ItemType.HELMET
			"ARMOUR":
				return ItemType.ARMOUR
			"GLOVES":
				return ItemType.GLOVES
			"BOOTS":
				return ItemType.BOOTS
			"ONE_HAND":
				return ItemType.ONE_HAND
			"TWO_HANDS":
				return ItemType.TWO_HANDS
	return -1
