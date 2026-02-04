extends Node
class_name TutorialManager

const TUTORIAL_HERO_DEF_ID: String = "knight_aprentice"
const TUTORIAL_ENEMY_TYPES: Array[String] = ["forest_slime", "forest_wolf", "forest_spider", "forest_spirit"]

func start_tutorial():
	# Punto de entrada del tutorial: borra tutorial previo y crea uno nuevo
	SaveSystem.ensure_collection()
	RunState.reset_run("tutorial")
	RunState.clear_tutorial_cards()
	RunState.set_run_selection(TUTORIAL_HERO_DEF_ID, TUTORIAL_ENEMY_TYPES)
	RunState.save_run()

func end_tutorial():
	# Elimina todas las cartas del tutorial al finalizar
	RunState.clear_tutorial_cards()
	RunState.save_run()
