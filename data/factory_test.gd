extends Node

@export var test_definition: CardDefinition

func _ready() -> void:
	var card := CardFactory.create_card(test_definition)
	print(card.instance_id)
	print(card.definition_id)
	print(card.current_hp)
