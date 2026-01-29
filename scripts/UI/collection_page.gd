extends Control

signal manage_pageflip(give_control_to_book: bool)

@export var slot_scene: PackedScene = preload("res://Scenes/ui/collection_slot.tscn")
@export var card_view_scene: PackedScene = preload("res://Scenes/cards/card_view.tscn")
@export var slots_per_page: int = 9

@onready var grid: GridContainer = $Grid

var _page_index: int = 0
var _card_keys: Array[String] = []
var _collection_map: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := get_node_or_null("Background")
	if bg and bg is Control:
		(bg as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grid:
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()
	_load_collection()
	_refresh()
	_fit_slots()
	if grid:
		grid.resized.connect(_fit_slots)

func set_page_index(page_index: int) -> void:
	if page_index < 0:
		_page_index = -1
	else:
		_page_index = page_index
	_load_collection()
	_refresh()

func _build_slots() -> void:
	if slot_scene == null:
		return
	_clear_grid()
	if grid:
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
	for i in range(slots_per_page):
		var slot := slot_scene.instantiate() as CollectionSlot
		if slot == null:
			continue
		slot.card_view_scene = card_view_scene
		slot.slot_clicked.connect(_on_slot_clicked)
		grid.add_child(slot)

func _on_slot_clicked(slot: CollectionSlot) -> void:
	get_tree().call_group("collection_root", "_on_page_slot_clicked", slot)

func _load_collection() -> void:
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	_collection_map.clear()
	_card_keys.clear()
	for card in collection.get_all_cards():
		var key := String(card.instance_id)
		var def_id := String(card.definition_id)
		_card_keys.append(key)
		_collection_map[key] = def_id

func _refresh() -> void:
	if _page_index < 0:
		for child in grid.get_children():
			if child is CollectionSlot:
				(child as CollectionSlot).set_empty()
		return
	var start_index := _page_index * slots_per_page
	var end_index := start_index + slots_per_page
	var slot_index := 0
	for child in grid.get_children():
		if child is CollectionSlot:
			var slot := child as CollectionSlot
			var global_index := start_index + slot_index
			if global_index < _card_keys.size():
				var key := _card_keys[global_index]
				var def_id := String(_collection_map.get(key, ""))
				var def: CardDefinition = CardDatabase.get_definition(def_id)
				if def != null:
					slot.set_occupied(def, key)
				else:
					slot.set_empty()
			else:
				slot.set_empty()
			slot_index += 1

func _clear_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

func _fit_slots() -> void:
	if grid == null:
		return
	var cols: int = 3
	var rows: int = int(ceili(float(slots_per_page) / float(cols)))
	if rows <= 0:
		return
	var h_sep := grid.get_theme_constant("h_separation")
	var v_sep := grid.get_theme_constant("v_separation")
	var cell_w := (grid.size.x - (float(h_sep) * float(cols - 1))) / float(cols)
	var cell_h := (grid.size.y - (float(v_sep) * float(rows - 1))) / float(rows)
	var cell_size := Vector2(max(10.0, cell_w), max(10.0, cell_h))
	for child in grid.get_children():
		if child is CollectionSlot:
			var slot := child as CollectionSlot
			slot.custom_minimum_size = cell_size


