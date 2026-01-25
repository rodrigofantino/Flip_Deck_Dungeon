extends Node
class_name CardDatabases
# Base de datos global de definiciones de cartas


var definitions := {}
# Diccionario que guarda todas las CardDefinition cargadas


func _ready():
	# Carga todas las definiciones al iniciar el juego
	load_definitions()


func load_definitions():
	# Carga manual de todas las definiciones de cartas
	definitions.clear()

	definitions["hero"] = load("res://data/card_definitions/tutorialhero_knight.tres")
	definitions["slime"] = load("res://data/card_definitions/tutorialslime.tres")
	definitions["wolf"] = load("res://data/card_definitions/tutorialwolf.tres")
	definitions["spider"] = load("res://data/card_definitions/tutorialspider.tres")
	definitions["forest_spirit"] = load("res://data/card_definitions/tutorialforest_spirit.tres")


func get_definition(key: String):
	# Devuelve una definición de carta por su clave
	return definitions.get(key, null)
