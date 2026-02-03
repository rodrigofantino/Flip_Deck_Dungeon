extends Node
class_name RunInitializer

static func build_default_collection() -> PlayerCollection:
	var collection := PlayerCollection.new()
	_add_hero(collection)
	_add_enemies(collection)
	return collection

static func _add_hero(collection: PlayerCollection) -> void:
	collection.add_type("hero_knight", 1)

static func _add_enemies(collection: PlayerCollection) -> void:
	_add_multiple(collection, "res://data/card_definitions/tutorialslime.tres", 2)
	_add_multiple(collection, "res://data/card_definitions/tutorialspider.tres", 2)
	_add_multiple(collection, "res://data/card_definitions/tutorialwolf.tres", 2)
	_add_multiple(collection, "res://data/card_definitions/tutorialforest_spirit.tres", 1)

static func _add_multiple(collection: PlayerCollection, definition_path: String, amount: int) -> void:
	var def: CardDefinition = load(definition_path)
	if def == null:
		return
	collection.add_type(def.definition_id, amount)
