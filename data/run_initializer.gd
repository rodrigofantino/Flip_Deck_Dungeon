extends Node
class_name RunInitializer

# =========================
# API PRINCIPAL (PÚBLICA)
# =========================

func create_new_run() -> PlayerCollection:
	var collection := PlayerCollection.new()

	_add_hero(collection)
	_add_enemies(collection)

	return collection


# =========================
# IMPLEMENTACIÓN INTERNA
# (helpers privados)
# =========================

func _add_hero(collection: PlayerCollection) -> void:
	var hero_def: CardDefinition = load("res://data/card_definitions/hero_knight.tres")
	var hero := CardFactory.create_card(hero_def)
	collection.add_card(hero)


func _add_enemies(collection: PlayerCollection) -> void:
	_add_multiple(collection, "res://data/card_definitions/forest/forest_slime.tres", 3)
	_add_multiple(collection, "res://data/card_definitions/forest/forest_wolf.tres", 3)
	_add_multiple(collection, "res://data/card_definitions/forest/forest_spider.tres", 3)
	_add_multiple(collection, "res://data/card_definitions/forest/forest_spirit.tres", 1)


func _add_multiple(
	collection: PlayerCollection,
	definition_path: String,
	amount: int
) -> void:
	var definition: CardDefinition = load(definition_path)

	for i in amount:
		var card := CardFactory.create_card(definition)
		collection.add_card(card)
