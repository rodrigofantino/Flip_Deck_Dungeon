extends Node
class_name TutorialManager


func start_tutorial():
	# Punto de entrada del tutorial: borra tutorial previo y crea uno nuevo
	SaveSystem.ensure_collection()
	RunState.reset_run("tutorial")
	RunState.clear_tutorial_cards()
	var run_deck := SaveSystem.build_tutorial_run_deck()
	SaveSystem.save_run_deck(run_deck)
	create_tutorial_cards(run_deck)
	RunState.save_run()


func create_tutorial_cards(run_deck: Array[Dictionary]):
	# Crea las cartas del tutorial usando el run_deck
	for entry in run_deck:
		var run_id := String(entry.get("run_id", ""))
		var def_id := String(entry.get("definition_id", ""))
		var collection_id := String(entry.get("collection_id", ""))
		if run_id == "" or def_id == "":
			continue
		RunState.create_card_instance(run_id, def_id, true, collection_id)


func end_tutorial():
	# Elimina todas las cartas del tutorial al finalizar
	RunState.clear_tutorial_cards()
	RunState.save_run()
