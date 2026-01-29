extends Node
class_name RunInitializer

func create_new_run() -> PlayerCollection:
	var collection := PlayerCollection.new()
	_add_hero(collection)
	_add_enemies(collection)
	return collection

func _add_hero(collection: PlayerCollection) -> void:
	var hero_def: CardDefinition = load("res://data/card_definitions/tutorialhero_knight.tres")
	var hero := CardFactory.create_card(hero_def)
	collection.add_card(hero)

func _add_enemies(collection: PlayerCollection) -> void:
	_add_multiple(collection, "res://data/card_definitions/tutorialslime.tres", 2)
	_add_multiple(collection, "res://data/card_definitions/tutorialspider.tres", 2)
	_add_multiple(collection, "res://data/card_definitions/tutorialwolf.tres", 2)
	_add_multiple(collection, "res://data/card_definitions/tutorialforest_spirit.tres", 1)

func _add_multiple(collection: PlayerCollection, definition_path: String, amount: int) -> void:
	var definition: CardDefinition = load(definition_path)
	for i in amount:
		var card := CardFactory.create_card(definition)
		collection.add_card(card)
