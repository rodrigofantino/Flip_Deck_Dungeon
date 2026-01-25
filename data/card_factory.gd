extends Node
class_name CardFactory

static func create_card(definition: CardDefinition) -> CardInstance:
	var card := CardInstance.new()

	card.instance_id = _generate_instance_id(definition.definition_id)
	card.definition_id = definition.definition_id
	card.level = 1
	card.current_hp = definition.max_hp
	card.traits = []

	return card


static func _generate_instance_id(definition_id: String) -> String:
	var random_part := str(randi() % 1000000)
	return definition_id + "_" + random_part
