extends Resource
class_name ItemArchetype

# =========================================
# ITEM ARCHETYPE (DATOS INMUTABLES)
# =========================================

@export var item_id: String = ""
# ID unico (ej: "open_helm")

@export var item_name: String = ""
# Nombre visible

@export_multiline var item_description: String = ""
# Descripcion visible

@export var item_type: int = CardDefinition.ItemType.HELMET
# Tipo (ItemType)

@export var item_class: String = "knight"
# Clase a la que pertenece el item (por ahora "knight")

@export var item_card_background: Texture2D
# Fondo de carta

@export var art: Texture2D
# Arte del item

@export var item_type_tags: Array[String] = []
# Tags para compatibilidad (ej: ["sword"], ["shield"])

# =========================
# BASE STATS (FLAT)
# =========================
@export var armour_flat: int = 0
@export var damage_flat: int = 0
@export var life_flat: int = 0
@export var initiative_flat: int = 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if item_id.strip_edges().is_empty():
		warnings.append("item_id esta vacio.")
	if item_name.strip_edges().is_empty():
		warnings.append("item_name esta vacio.")
	if art == null:
		warnings.append("art no asignado.")
	if item_card_background == null:
		warnings.append("item_card_background no asignado.")
	return warnings
