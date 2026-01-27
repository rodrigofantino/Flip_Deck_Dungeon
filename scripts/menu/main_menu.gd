extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:


	# Asumimos que los botones ya existen en la escena
	# y están conectados por señal (_on_*_pressed)
	var title_label: Label = $Label
	var play_button: Button = $VBoxContainer/PlayButton
	var continue_button: Button = $VBoxContainer/ContinueButton
	var tutorial_button: Button = $VBoxContainer/TutorialButton
	var endless_button: Button = $VBoxContainer/EndlessButton
	var shop_button: Button = $VBoxContainer/ShopButton
	var collection_button: Button = $VBoxContainer/CollectionButton
	var settings_button: Button = $VBoxContainer/SettingsButton
	var gold_label: Label = $GoldLabel
	var dev_reset_button: Button = $DevResetButton
	var dev_add_gold_button: Button = $DevAddGoldButton

	if title_label:
		title_label.text = tr("MAIN_MENU_TITLE")
	continue_button.text = tr("MAIN_MENU_BUTTON_CONTINUE")
	play_button.text = tr("MAIN_MENU_BUTTON_PLAY")
	tutorial_button.text = tr("MAIN_MENU_BUTTON_TUTORIAL")
	endless_button.text = tr("MAIN_MENU_BUTTON_ENDLESS")
	shop_button.text = tr("MAIN_MENU_BUTTON_SHOP")
	collection_button.text = tr("MAIN_MENU_BUTTON_COLLECTION")
	settings_button.text = tr("MAIN_MENU_BUTTON_SETTINGS")
	if dev_reset_button:
		dev_reset_button.text = tr("MAIN_MENU_BUTTON_DEV_RESET")
		dev_reset_button.pressed.connect(_on_dev_reset_pressed)
	if dev_add_gold_button:
		dev_add_gold_button.text = tr("MAIN_MENU_BUTTON_DEV_ADD_GOLD")
		dev_add_gold_button.pressed.connect(_on_dev_add_gold_pressed)

	continue_button.disabled = not RunState.has_saved_run()
	_update_gold_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		var continue_button: Button = $VBoxContainer/ContinueButton
		if continue_button:
			continue_button.disabled = not RunState.has_saved_run()
		_update_gold_label()
# Called every frame. 'delta' is the elapsed time since the previous frame.


func _process(delta: float) -> void:
	pass


	
func _on_p_lay_pressed() -> void:
	RunState.selection_pending = true
	get_tree().change_scene_to_file("res://Scenes/ui/collection.tscn")

func _on_continue_pressed() -> void:
	RunState.load_run()
	get_tree().change_scene_to_file("res://Scenes/battle_table.tscn")


func _on_tutorial_pressed() -> void:
	print("tutorial pressed")
	# Inicia el tutorial creando las cartas fijas
	TutorialManage.start_tutorial()
	# Cambia a la escena principal de batalla
	get_tree().change_scene_to_file("res://Scenes/battle_table.tscn")


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu/Settings.tscn")

func _on_collection_pressed() -> void:
	RunState.selection_pending = false
	get_tree().change_scene_to_file("res://Scenes/ui/collection.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/shop.tscn")

func _on_dev_reset_pressed() -> void:
	SaveSystem.reset_progress()
	RunState.reset_run()
	var continue_button: Button = $VBoxContainer/ContinueButton
	if continue_button:
		continue_button.disabled = true
	_update_gold_label()

func _on_dev_add_gold_pressed() -> void:
	SaveSystem.add_persistent_gold(500)
	_update_gold_label()

func _update_gold_label() -> void:
	var gold_label: Label = $GoldLabel
	if gold_label:
		gold_label.text = "%s: %d" % [
			tr("MAIN_MENU_LABEL_GOLD"),
			SaveSystem.get_persistent_gold()
		]
