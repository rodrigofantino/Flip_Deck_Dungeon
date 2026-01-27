extends Control

@export var slot_scene: PackedScene
@export var card_view_scene: PackedScene

@onready var title_label: Label = $TopBar/TitleLabel
@onready var prev_button: Button = $TopBar/PrevButton
@onready var next_button: Button = $TopBar/NextButton
@onready var page_label: Label = $TopBar/PageLabel
@onready var left_grid: GridContainer = $Spread/LeftPage/LeftGrid
@onready var right_grid: GridContainer = $Spread/RightPage/RightGrid
@onready var back_button: Button = $BackButton

const SLOTS_PER_PAGE: int = 12
const SLOTS_PER_SPREAD: int = 24

var card_keys: Array[String] = []
var collection_map: Dictionary = {}
var spread_index: int = 0

func _ready() -> void:
	title_label.text = tr("COLLECTION_TITLE")
	prev_button.text = tr("COLLECTION_PREV")
	next_button.text = tr("COLLECTION_NEXT")
	back_button.text = tr("COLLECTION_BACK")

	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_build_slots()
	_load_from_collection()
	_refresh_view()

func set_cards(keys: Array[String]) -> void:
	card_keys = keys.duplicate()
	spread_index = 0
	_refresh_view()

func _load_from_collection() -> void:
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()

	var keys: Array[String] = []
	collection_map.clear()
	for card in collection.get_all_cards():
		var key := String(card.instance_id)
		var def_id := String(card.definition_id)
		keys.append(key)
		collection_map[key] = def_id
	set_cards(keys)

func _build_slots() -> void:
	if slot_scene == null:
		push_error("[Collection] slot_scene no asignada")
		return

	_clear_grid(left_grid)
	_clear_grid(right_grid)

	for i in range(SLOTS_PER_PAGE):
		var slot_left: CollectionSlot = slot_scene.instantiate()
		slot_left.card_view_scene = card_view_scene
		left_grid.add_child(slot_left)

		var slot_right: CollectionSlot = slot_scene.instantiate()
		slot_right.card_view_scene = card_view_scene
		right_grid.add_child(slot_right)

func _refresh_view() -> void:
	var start_index := spread_index * SLOTS_PER_SPREAD
	var end_index := start_index + SLOTS_PER_SPREAD

	_set_grid_slots(left_grid, start_index, start_index + SLOTS_PER_PAGE)
	_set_grid_slots(right_grid, start_index + SLOTS_PER_PAGE, end_index)

	var page_left := (spread_index * 2) + 1
	var page_right := page_left + 1
	page_label.text = "Pág. %d-%d" % [page_left, page_right]

	prev_button.disabled = spread_index <= 0
	next_button.disabled = end_index >= card_keys.size()

func _set_grid_slots(grid: GridContainer, from_index: int, to_index: int) -> void:
	var slot_index := 0
	for child in grid.get_children():
		if child is CollectionSlot:
			var global_index := from_index + slot_index
			if global_index < card_keys.size():
				var key := card_keys[global_index]
				var def_id := String(collection_map.get(key, ""))
				var def: CardDefinition = CardDatabase.get_definition(def_id)
				if def != null:
					child.set_occupied(def)
				else:
					child.set_empty()
			else:
				child.set_empty()
			slot_index += 1

func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

func _on_prev_pressed() -> void:
	if spread_index <= 0:
		return
	spread_index -= 1
	_refresh_view()

func _on_next_pressed() -> void:
	var next_start := (spread_index + 1) * SLOTS_PER_SPREAD
	if next_start >= card_keys.size():
		return
	spread_index += 1
	_refresh_view()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
