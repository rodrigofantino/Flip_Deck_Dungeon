extends Node
class_name TutorialManager


# Lista fija de cartas que componen el tutorial
# Estas cartas siempre se crean iguales
const TUTORIAL_CARDS := [
	{ "id": "th",  "definition": "hero" },

	{ "id": "tw1", "definition": "wolf" },
	{ "id": "tw2", "definition": "wolf" },
	{ "id": "tw3", "definition": "wolf" },

	{ "id": "ts1", "definition": "slime" },
	{ "id": "ts2", "definition": "slime" },
	{ "id": "ts3", "definition": "slime" },

	{ "id": "tsp1", "definition": "spider" },
	{ "id": "tsp2", "definition": "spider" },
	{ "id": "tsp3", "definition": "spider" },

	{ "id": "tfs1", "definition": "forest_spirit" },
]


func start_tutorial():
	# Punto de entrada del tutorial: borra tutorial previo y crea uno nuevo
	RunState.clear_tutorial_cards()
	create_tutorial_cards()
	RunState.save_run()


func create_tutorial_cards():
	# Crea todas las cartas fijas del tutorial
	for card_data in TUTORIAL_CARDS:
		RunState.create_card_instance(
			card_data.id,
			card_data.definition,
			true
		)


func end_tutorial():
	# Elimina todas las cartas del tutorial al finalizar
	RunState.clear_tutorial_cards()
	RunState.save_run()
