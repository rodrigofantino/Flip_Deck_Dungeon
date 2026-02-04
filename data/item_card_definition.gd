extends Resource
class_name ItemCardDefinition

@export var art: Texture2D
# Arte de la carta de item

@export var item_id: String
# ID logico (ej: "wooden_sword")

@export var item_name: String
# Nombre visible

@export_multiline var item_description: String
# Descripcion visible

@export_enum("none", "knight", "sorcerer", "ranger", "bard", "rogue") var item_class: String = "none"
# Clase requerida/afinidad (si aplica). "none" = sin restriccion.

@export_enum("none", "one_hand", "two_hands", "helmet", "gloves", "boots", "armour", "amulet", "ring") var item_type: String = "none"
# Tipo de item/equipamiento.

@export var item_type_tags: Array[String] = []
# Tags de tipo (ej: ["sword"]). Lista para compatibilidad futura.

# =========================
# FLAT STATS (V1)
# Valores planos que se suman. Pueden ser negativos para debuffs.
# =========================
@export var armour_flat: int = 0
@export var damage_flat: int = 0
@export var life_flat: int = 0
@export var initiative_flat: int = 0

# =========================
# FUTURO / EXPANSION
# =========================
@export var shield_flat: int = 0
@export var lifesteal_flat: int = 0
@export var thorns_flat: int = 0
@export var regen_flat: int = 0
@export var crit_chance_flat: int = 0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if item_id.strip_edges().is_empty():
		warnings.append("item_id esta vacio.")
	if item_name.strip_edges().is_empty():
		warnings.append("item_name esta vacio.")

	return warnings
