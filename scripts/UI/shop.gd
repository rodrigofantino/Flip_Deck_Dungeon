extends Control

class PackUI:
	var root: Control
	var preview: ColorRect
	var title_label: Label
	var price_label: Label
	var owned_label: Label
	var buy_open_button: Button
	var buy_button: Button
	var pack_type: String
	var name_key: String
	var price: int

@onready var title_label: Label = $TitleLabel
@onready var unopened_label: Label = $UnopenedLabel
@onready var gold_label: Label = $GoldLabel
@onready var feedback_label: Label = $FeedbackLabel
@onready var back_button: Button = $BackButton

const BOOSTER_FOREST_PATH: String = "res://data/booster_packs/booster_pack_forest.tres"
const BOOSTER_DARK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_dark_forest.tres"

const PRICE_FOREST: int = 20
const PRICE_DARK_FOREST: int = 50

var collection: PlayerCollection = null
var forest_pack: PackUI = null
var dark_forest_pack: PackUI = null

func _ready() -> void:
	title_label.text = tr("SHOP_TITLE")
	feedback_label.text = ""
	feedback_label.modulate.a = 0.0

	collection = SaveSystem.ensure_collection()
	forest_pack = _build_pack_ui($PacksContainer/ForestPack, "forest", BOOSTER_FOREST_PATH, PRICE_FOREST)
	dark_forest_pack = _build_pack_ui($PacksContainer/DarkForestPack, "dark_forest", BOOSTER_DARK_FOREST_PATH, PRICE_DARK_FOREST)

	_refresh_all()
	back_button.text = tr("SHOP_BACK_BUTTON")
	back_button.pressed.connect(_on_back_pressed)

func _build_pack_ui(root: Control, pack_type: String, resource_path: String, price: int) -> PackUI:
	var ui: PackUI = PackUI.new()
	ui.root = root
	ui.preview = root.get_node("Content/Preview") as ColorRect
	ui.title_label = root.get_node("Content/PackNameLabel") as Label
	ui.price_label = root.get_node("Content/PriceLabel") as Label
	ui.owned_label = root.get_node("Content/OwnedLabel") as Label
	ui.buy_open_button = root.get_node("Content/Buttons/BuyOpenButton") as Button
	ui.buy_button = root.get_node("Content/Buttons/BuyButton") as Button
	ui.pack_type = pack_type
	ui.price = price

	var def := load(resource_path) as BoosterPackDefinition
	if def != null:
		ui.name_key = def.name_key
	else:
		ui.name_key = ""

	ui.buy_open_button.pressed.connect(func(): _on_buy_pressed(ui, true))
	ui.buy_button.pressed.connect(func(): _on_buy_pressed(ui, false))
	return ui

func _refresh_all() -> void:
	_refresh_header()
	_refresh_pack(forest_pack)
	_refresh_pack(dark_forest_pack)

func _refresh_header() -> void:
	var total := _get_total_unopened()
	unopened_label.text = tr("SHOP_PACKS_UNOPENED_HEADER") % total
	if gold_label:
		gold_label.text = "%s: %d" % [tr("MAIN_MENU_LABEL_GOLD"), collection.gold]

func _refresh_pack(ui: PackUI) -> void:
	if ui == null:
		return
	if ui.name_key != "":
		ui.title_label.text = tr(ui.name_key)
	else:
		ui.title_label.text = tr("SHOP_PACK_FOREST")

	if ui.pack_type == "forest":
		ui.price_label.text = tr("SHOP_PACK_FOREST_PRICE")
	elif ui.pack_type == "dark_forest":
		ui.price_label.text = tr("SHOP_PACK_DARK_FOREST_PRICE")
	else:
		ui.price_label.text = "%dg" % ui.price

	var owned := _get_pack_owned(ui.pack_type)
	ui.owned_label.text = tr("SHOP_PACK_OWNED") % owned

	var can_afford := _can_afford(ui.price)
	ui.buy_open_button.text = tr("SHOP_BUY_OPEN_BUTTON")
	ui.buy_button.text = tr("SHOP_BUY_BUTTON")
	ui.buy_open_button.disabled = not can_afford
	ui.buy_button.disabled = not can_afford

func _get_pack_owned(pack_type: String) -> int:
	if collection == null:
		return 0
	return collection.get_booster_count(pack_type)

func _get_total_unopened() -> int:
	if collection == null:
		return 0
	var total: int = 0
	for key in collection.booster_packs.keys():
		total += int(collection.booster_packs.get(key, 0))
	return total

func _can_afford(price: int) -> bool:
	if collection == null:
		return false
	return collection.gold >= price

func _on_buy_pressed(ui: PackUI, buy_open: bool) -> void:
	if collection == null or ui == null:
		return
	if collection.gold < ui.price:
		_show_feedback(tr("SHOP_FEEDBACK_NOT_ENOUGH_GOLD"), Color(1.0, 0.45, 0.45, 1.0), 0.8)
		_refresh_pack(ui)
		return

	collection.gold -= ui.price
	collection.add_booster(ui.pack_type, 1)
	SaveSystem.save_collection(collection)

	# TODO: si buy_open es true, abrir el pack inmediatamente (flujo futuro)
	_show_feedback(tr("SHOP_FEEDBACK_PURCHASED"), Color(0.65, 1.0, 0.65, 1.0), 0.5)
	_refresh_all()

func _show_feedback(text: String, color: Color, duration: float) -> void:
	feedback_label.text = text
	feedback_label.modulate = color
	var tween := create_tween()
	tween.tween_property(feedback_label, "modulate:a", 1.0, 0.05)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.2).set_delay(duration)

func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")
