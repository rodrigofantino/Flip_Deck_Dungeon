extends Control

@onready var cards_container: VBoxContainer = $CardsContainer

var card_scene: PackedScene = preload("res://Scenes/cards/card_view.tscn")


func _ready() -> void:
		spawn_test_card()
		


func spawn_test_card() -> void:
	var card = card_scene.instantiate()
	
	card.card_name = "Slime"
	card.description = "A weak but sticky enemy"
	card.power = 12
	
	cards_container.add_child(card)
