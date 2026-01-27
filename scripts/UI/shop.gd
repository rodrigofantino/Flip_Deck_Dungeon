extends Control

@onready var title_label: Label = $TitleLabel
@onready var pack_name_label: Label = $PackPanel/PackContent/PackNameLabel
@onready var price_label: Label = $PackPanel/PackContent/PriceLabel
@onready var buy_button: Button = $PackPanel/PackContent/BuyButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	title_label.text = tr("SHOP_TITLE")
	pack_name_label.text = tr("SHOP_PACK_FOREST")
	price_label.text = tr("SHOP_PACK_FOREST_PRICE")
	buy_button.text = tr("SHOP_BUY_BUTTON")
	back_button.text = tr("SHOP_BACK_BUTTON")

	buy_button.disabled = true
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
