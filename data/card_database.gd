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

	var hero_def: CardDefinition = load("res://data/card_definitions/tutorialhero_knight.tres")
	var slime_def: CardDefinition = load("res://data/card_definitions/tutorialslime.tres")
	var wolf_def: CardDefinition = load("res://data/card_definitions/tutorialwolf.tres")
	var spider_def: CardDefinition = load("res://data/card_definitions/tutorialspider.tres")
	var spirit_def: CardDefinition = load("res://data/card_definitions/tutorialforest_spirit.tres")
	var df_slime_def: CardDefinition = load("res://data/card_definitions/dark_forest_slime.tres")
	var df_spider_def: CardDefinition = load("res://data/card_definitions/dark_forest_spider.tres")
	var df_wolf_def: CardDefinition = load("res://data/card_definitions/dark_forest_wolf.tres")
	var df_bat_def: CardDefinition = load("res://data/card_definitions/dark_forest_corrupted_bat.tres")
	var df_rootling_def: CardDefinition = load("res://data/card_definitions/dark_forest_rootling.tres")
	var df_shade_def: CardDefinition = load("res://data/card_definitions/dark_forest_shade.tres")
	var df_thorn_def: CardDefinition = load("res://data/card_definitions/dark_forest_thorn_beast.tres")
	var df_sporeling_def: CardDefinition = load("res://data/card_definitions/dark_forest_sporeling.tres")
	var df_stag_def: CardDefinition = load("res://data/card_definitions/dark_forest_fallen_stag.tres")
	var df_spirit_def: CardDefinition = load("res://data/card_definitions/dark_forest_corrupted_spirit.tres")

	# Guardar por definition_id (fuente de verdad)
	if hero_def != null:
		definitions[hero_def.definition_id] = hero_def
		# Alias legacy para no romper referencias viejas
		definitions["hero"] = hero_def
	if slime_def != null:
		definitions[slime_def.definition_id] = slime_def
	if wolf_def != null:
		definitions[wolf_def.definition_id] = wolf_def
	if spider_def != null:
		definitions[spider_def.definition_id] = spider_def
	if spirit_def != null:
		definitions[spirit_def.definition_id] = spirit_def
	if df_slime_def != null:
		definitions[df_slime_def.definition_id] = df_slime_def
	if df_spider_def != null:
		definitions[df_spider_def.definition_id] = df_spider_def
	if df_wolf_def != null:
		definitions[df_wolf_def.definition_id] = df_wolf_def
	if df_bat_def != null:
		definitions[df_bat_def.definition_id] = df_bat_def
	if df_rootling_def != null:
		definitions[df_rootling_def.definition_id] = df_rootling_def
	if df_shade_def != null:
		definitions[df_shade_def.definition_id] = df_shade_def
	if df_thorn_def != null:
		definitions[df_thorn_def.definition_id] = df_thorn_def
	if df_sporeling_def != null:
		definitions[df_sporeling_def.definition_id] = df_sporeling_def
	if df_stag_def != null:
		definitions[df_stag_def.definition_id] = df_stag_def
	if df_spirit_def != null:
		definitions[df_spirit_def.definition_id] = df_spirit_def


func get_definition(key: String):
	# Devuelve una definición de carta por su clave
	return definitions.get(key, null)
