extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:


	# Asumimos que los botones ya existen en la escena
	# y están conectados por señal (_on_*_pressed)
	var play_button: Button = $VBoxContainer/PlayButton
	var tutorial_button: Button = $VBoxContainer/TutorialButton
	var endless_button: Button = $VBoxContainer/EndlessButton
	var shop_button: Button = $VBoxContainer/ShopButton
	var settings_button: Button = $VBoxContainer/SettingsButton

	play_button.text = tr("MAIN_MENU_BUTTON_PLAY")
	tutorial_button.text = tr("MAIN_MENU_BUTTON_TUTORIAL")
	endless_button.text = tr("MAIN_MENU_BUTTON_ENDLESS")
	shop_button.text = tr("MAIN_MENU_BUTTON_SHOP")
	settings_button.text = tr("MAIN_MENU_BUTTON_SETTINGS")
# Called every frame. 'delta' is the elapsed time since the previous frame.


func _process(delta: float) -> void:
	pass


	
func _on_p_lay_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/table.tscn")


func _on_tutorial_pressed() -> void:
	print("tutorial pressed")
	# Inicia el tutorial creando las cartas fijas
	TutorialManage.start_tutorial()
	# Cambia a la escena principal de batalla
	get_tree().change_scene_to_file("res://Scenes/battle_table.tscn")


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu/Settings.tscn")
