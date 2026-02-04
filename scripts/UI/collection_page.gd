extends Control

signal manage_pageflip(give_control_to_book: bool)

@export var slot_scene: PackedScene = preload("res://Scenes/ui/collection_slot.tscn")
@export var card_view_scene: PackedScene = preload("res://Scenes/cards/card_view.tscn")
@export var slots_per_page: int = 9

@onready var grid: GridContainer = $Grid

var _page_index: int = 0
var _card_types: Array[String] = []
var _card_obtained: Array[bool] = []
var _owned_count_map: Dictionary = {}
var _upgrade_level_map: Dictionary = {}
var _show_counts: bool = false
var _is_play_mode: bool = false

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
	var obtained := {}
	for def_id in collection.get_all_types():
		obtained[String(def_id)] = true
	_owned_count_map.clear()
	for def_id in collection.get_all_types():
		_owned_count_map[String(def_id)] = collection.get_owned_count(String(def_id))
	_upgrade_level_map.clear()
	for def_id in collection.upgrade_level.keys():
		_upgrade_level_map[String(def_id)] = int(collection.upgrade_level.get(def_id, 0))
	_is_play_mode = RunState.selection_pending
	_card_types.clear()
	_card_obtained.clear()
	_show_counts = not _is_play_mode
	var order := _get_ordered_def_ids(_is_play_mode)
	if _is_play_mode:
		var ids: Array[String] = []
		for def_id in collection.get_all_types():
			ids.append(String(def_id))
		ids = _sort_ids_by_order(ids, order)
		for def_id in ids:
			_card_types.append(String(def_id))
			_card_obtained.append(true)
	else:
		var all_ids: Array[String] = []
		for def_id in CardDatabase.definitions.keys():
			all_ids.append(String(def_id))
		all_ids = _sort_ids_by_order(all_ids, order)
		for def_id in all_ids:
			_card_types.append(def_id)
			_card_obtained.append(obtained.has(def_id))

func _get_ordered_def_ids(is_play_mode: bool) -> Array[String]:
	var hero_ids: Array[String] = []
	var forest_ids: Array[String] = []
	var dark_forest_ids: Array[String] = []
	var other_ids: Array[String] = []
	var all_ids: Array[String] = []

	for def_id in CardDatabase.definitions.keys():
		var def: CardDefinition = CardDatabase.get_definition(String(def_id))
		if def == null:
			continue
		if is_play_mode:
			all_ids.append(def.definition_id)
		else:
			if def.card_type == "hero":
				hero_ids.append(def.definition_id)
			elif def.biome_modifier == "Forest":
				forest_ids.append(def.definition_id)
			elif def.biome_modifier == "Dark Forest":
				dark_forest_ids.append(def.definition_id)
			else:
				other_ids.append(def.definition_id)

	if is_play_mode:
		all_ids.sort_custom(func(a: String, b: String) -> bool:
			var pa := _get_definition_power(a)
			var pb := _get_definition_power(b)
			if pa == pb:
				return a < b
			return pa < pb
		)
		return all_ids

	hero_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)
	forest_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)
	dark_forest_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)
	other_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)

	var ordered: Array[String] = []
	ordered.append_array(hero_ids)
	ordered.append_array(forest_ids)
	ordered.append_array(dark_forest_ids)
	ordered.append_array(other_ids)
	return ordered

func _compare_by_power_then_id(a: String, b: String) -> bool:
	var pa := _get_definition_power(a)
	var pb := _get_definition_power(b)
	if pa == pb:
		return a < b
	return pa < pb

func _get_definition_power(def_id: String) -> int:
	var def: CardDefinition = CardDatabase.get_definition(def_id)
	if def == null:
		return 0
	if def.power > 0:
		return def.power
	return int(def.max_hp + def.damage)

func _sort_ids_by_order(ids: Array[String], order: Array[String]) -> Array[String]:
	if order.is_empty():
		ids.sort()
		return ids
	var index_map: Dictionary = {}
	for i in range(order.size()):
		index_map[order[i]] = i
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ia := int(index_map.get(a, 999999))
		var ib := int(index_map.get(b, 999999))
		if ia == ib:
			return a < b
		return ia < ib
	)
	return ids

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
			if global_index < _card_types.size():
				var def_id := String(_card_types[global_index])
				var def: CardDefinition = CardDatabase.get_definition(def_id)
				if def != null:
					var obtained := _card_obtained[global_index] if global_index < _card_obtained.size() else true
					var upgrade_level := int(_upgrade_level_map.get(def_id, 0))
					slot.set_occupied(def, obtained, upgrade_level)
					var count := int(_owned_count_map.get(def_id, 0))
					slot.set_owned_count(count, _show_counts)
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
