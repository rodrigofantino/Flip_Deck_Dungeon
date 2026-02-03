extends Node

@export var catalog: ItemCatalog

const DEFAULT_CATALOG_PATH := "res://data/item_catalog_default.tres"

func _ready() -> void:
	var cat := catalog
	if cat == null:
		cat = load(DEFAULT_CATALOG_PATH) as ItemCatalog

	if cat == null:
		push_error("[ItemCatalogTest] No se pudo cargar catalogo: " + DEFAULT_CATALOG_PATH)
		return

	var item := cat.get_item_by_id("wooden_sword")
	if item == null:
		push_error("[ItemCatalogTest] No se encontro item 'wooden_sword'")
		return

	print("[ItemCatalogTest] item_id=", item.item_id, " name=", item.item_name, " damage_flat=", item.damage_flat)
