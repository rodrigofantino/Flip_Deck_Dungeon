extends Control

@export var slot_scene: PackedScene
@export var card_view_scene: PackedScene

@onready var title_label: Label = $TopBar/TitleLabel
@onready var prev_button: Button = $TopBar/PrevButton
@onready var next_button: Button = $TopBar/NextButton
@onready var page_label: Label = $TopBar/PageLabel
@onready var left_grid: GridContainer = $Spread/LeftPage/LeftGrid
@onready var right_grid: GridContainer = $Spread/RightPage/RightGrid
@onready var back_button: Button = $SelectionPanel/BackButton
@onready var booster_area: Control = $BoosterArea
@onready var booster_list: VBoxContainer = $BoosterArea/BoosterList
@onready var booster_popup: Control = $BoosterPopup
@onready var booster_popup_title: Label = $BoosterPopup/Panel/Content/TitleLabel
@onready var booster_popup_preview: ColorRect = $BoosterPopup/Panel/Content/Preview
@onready var booster_popup_name: Label = $BoosterPopup/Panel/Content/NameLabel
@onready var booster_popup_open: Button = $BoosterPopup/Panel/Content/Buttons/OpenButton
@onready var booster_popup_back: Button = $BoosterPopup/Panel/Content/Buttons/BackButton
@onready var booster_popup_dimmer: ColorRect = $BoosterPopup/Dimmer
@onready var open_popup: Control = $OpenPackPopup
@onready var open_popup_title: Label = $OpenPackPopup/Panel/Content/TitleLabel
@onready var open_popup_cards: Control = $OpenPackPopup/Panel/Content/CardsContainer
@onready var open_popup_add_all: Button = $OpenPackPopup/Panel/Content/Buttons/AddAllButton
@onready var open_popup_back: Button = $OpenPackPopup/Panel/Content/Buttons/BackButton
@onready var selection_panel: VBoxContainer = $SelectionPanel
@onready var select_hero_label: Label = $SelectionPanel/SelectHeroLabel
@onready var select_enemies_label: Label = $SelectionPanel/SelectEnemiesLabel
@onready var start_dungeon_button: Button = $SelectionPanel/StartDungeonButton
@onready var open_popup_dimmer: ColorRect = $OpenPackPopup/Dimmer

const SLOTS_PER_PAGE: int = 12
const SLOTS_PER_SPREAD: int = 24

var card_keys: Array[String] = []
var collection_map: Dictionary = {}
var spread_index: int = 0
var selection_mode: bool = false
var selected_hero_id: String = ""
var selected_enemy_ids: Dictionary = {}

const PACK_STACK_OFFSET_X: float = 2.0
const PACK_STACK_OFFSET_Y: float = 2.0
const PACK_STACK_MAX: int = 12
const PACK_PREVIEW_SIZE: Vector2 = Vector2(140, 80)
const PACK_FOREST_COLOR: Color = Color(0.6, 0.85, 0.6, 1.0)
const PACK_DARK_FOREST_COLOR: Color = Color(0.12, 0.35, 0.2, 1.0)
const PACK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_forest.tres"
const PACK_DARK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_dark_forest.tres"
const OPEN_CARD_OFFSET: Vector2 = Vector2(2.0, 2.0)
const OPEN_CARD_BASE: Vector2 = Vector2(620, 860)
const OPEN_CARD_DISPLAY: Vector2 = Vector2(155, 215)
const OPEN_CARDS_PER_PACK: int = 5
const BIOME_FOREST: String = "Forest"
const BIOME_DARK_FOREST: String = "Dark Forest"

class PackView:
	var pack_type: String
	var name_key: String
	var color: Color

var selected_pack: PackView = null
var open_defs: Array[CardDefinition] = []
var open_cards: Array[CardView] = []
var open_collection: PlayerCollection = null

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
	_refresh_boosters()
	_refresh_view()
	_init_selection_ui()

	if booster_popup != null:
		booster_popup.visible = false
		booster_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if booster_area:
		booster_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_list:
		booster_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup_dimmer:
		booster_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup != null:
		open_popup.visible = false
		open_popup.modulate.a = 1.0
		open_popup.scale = Vector2.ONE
		open_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup_dimmer:
		open_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup_cards:
		open_popup_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup_title:
		booster_popup_title.text = tr("COLLECTION_BOOSTER_POPUP_TITLE")
	if booster_popup_open:
		booster_popup_open.text = tr("COLLECTION_BOOSTER_OPEN")
		booster_popup_open.pressed.connect(_on_booster_open_pressed)
	if booster_popup_back:
		booster_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		booster_popup_back.pressed.connect(_close_booster_popup)
	if open_popup_title:
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE")
	if open_popup_add_all:
		open_popup_add_all.text = tr("COLLECTION_OPEN_ADD_ALL")
		open_popup_add_all.pressed.connect(_on_add_all_pressed)
	if open_popup_back:
		open_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		open_popup_back.pressed.connect(_on_add_all_pressed)

func _init_selection_ui() -> void:
	selection_mode = RunState.selection_pending
	if selection_panel:
		selection_panel.visible = selection_mode
		selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if select_hero_label:
		select_hero_label.text = tr("COLLECTION_SELECT_HERO")
		select_hero_label.visible = true
	if select_enemies_label:
		select_enemies_label.text = tr("COLLECTION_SELECT_ENEMIES")
		select_enemies_label.visible = true
	if start_dungeon_button:
		start_dungeon_button.text = tr("COLLECTION_START_DUNGEON")
		start_dungeon_button.pressed.connect(_on_start_dungeon_pressed)
	_update_selection_state()
	if not selection_mode:
		# Clear any selection visuals when browsing only
		for child in left_grid.get_children():
			if child is CollectionSlot:
				child.set_selected(false)
		for child in right_grid.get_children():
			if child is CollectionSlot:
				child.set_selected(false)

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

func _refresh_boosters() -> void:
	if booster_list == null:
		return
	_clear_booster_list()

	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()

	var packs: Array[PackView] = _build_pack_views()
	for pack in packs:
		var count := collection.get_booster_count(pack.pack_type)
		if count <= 0:
			continue
		_add_booster_stack(pack, count)

func _build_pack_views() -> Array[PackView]:
	var result: Array[PackView] = []

	var forest := _load_pack_view(PACK_FOREST_PATH, "forest", PACK_FOREST_COLOR)
	if forest != null:
		result.append(forest)

	var dark_forest := _load_pack_view(PACK_DARK_FOREST_PATH, "dark_forest", PACK_DARK_FOREST_COLOR)
	if dark_forest != null:
		result.append(dark_forest)

	return result

func _load_pack_view(path: String, pack_type: String, color: Color) -> PackView:
	var def := load(path) as BoosterPackDefinition
	var view := PackView.new()
	view.pack_type = pack_type
	view.color = color
	if def != null:
		view.name_key = def.name_key
	else:
		view.name_key = ""
	return view

func _add_booster_stack(pack: PackView, count: int) -> void:
	var item := VBoxContainer.new()
	item.custom_minimum_size = Vector2(220, 110)
	item.alignment = BoxContainer.ALIGNMENT_BEGIN
	booster_list.add_child(item)

	var label := Label.new()
	var display_name: String = pack.pack_type
	if pack.name_key != "":
		display_name = tr(pack.name_key)
	label.text = tr("COLLECTION_PACK_COUNT") % [display_name, count]
	item.add_child(label)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(220, 90)
	item.add_child(stack)

	var visible_count: int = mini(count, PACK_STACK_MAX)
	for i in range(visible_count):
		var rect := ColorRect.new()
		rect.color = pack.color
		rect.custom_minimum_size = PACK_PREVIEW_SIZE
		rect.position = Vector2(PACK_STACK_OFFSET_X * float(i), PACK_STACK_OFFSET_Y * float(i))
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		rect.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_booster_popup(pack)
		)
		stack.add_child(rect)

func _clear_booster_list() -> void:
	for child in booster_list.get_children():
		child.queue_free()

func _open_pack_popup(pack: PackView) -> void:
	if open_popup == null or open_popup_cards == null:
		return
	open_popup.visible = true
	open_popup.modulate.a = 0.0
	open_popup.scale = Vector2(0.95, 0.95)
	open_collection = SaveSystem.load_collection()
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()

	_clear_open_cards()
	open_defs.clear()

	var pool := _get_pack_pool(pack.pack_type)
	if pool.is_empty():
		return

	if open_popup_title:
		var display_name: String = pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE_NAME") % display_name

	_play_open_popup_in()

	for i in range(OPEN_CARDS_PER_PACK):
		var def := pool[randi() % pool.size()]
		open_defs.append(def)

	call_deferred("_add_open_cards_visual", open_defs)

func _add_open_cards_visual(defs: Array[CardDefinition]) -> void:
	if open_popup_cards == null:
		return
	_clear_open_cards()
	for i in range(defs.size()):
		var def := defs[i]
		var card := card_view_scene.instantiate() as CardView
		if card == null:
			continue
		open_popup_cards.add_child(card)
		card.custom_minimum_size = OPEN_CARD_BASE
		card.size = OPEN_CARD_BASE
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.offset_left = 0.0
		card.offset_top = 0.0
		card.offset_right = OPEN_CARD_BASE.x
		card.offset_bottom = OPEN_CARD_BASE.y
		card.setup_from_definition(def)
		card.show_front()
		_set_mouse_filter_recursive(card, Control.MOUSE_FILTER_IGNORE)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var scale_w: float = OPEN_CARD_DISPLAY.x / OPEN_CARD_BASE.x
		var scale_h: float = OPEN_CARD_DISPLAY.y / OPEN_CARD_BASE.y
		var final_scale: float = minf(scale_w, scale_h)
		card.scale = Vector2(final_scale, final_scale)
		var scaled_size := OPEN_CARD_BASE * final_scale
		var base_pos := (open_popup_cards.size * 0.5) - (scaled_size * 0.5)
		card.position = base_pos + Vector2(OPEN_CARD_OFFSET.x * float(i), OPEN_CARD_OFFSET.y * float(i))
		card.z_index = i
		open_cards.append(card)
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_open_card_clicked(card)
		)

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _play_open_popup_in() -> void:
	var tween := create_tween()
	tween.tween_property(open_popup, "modulate:a", 1.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(1.0, 1.0), 0.2)

func _on_open_card_clicked(card: CardView) -> void:
	var index := open_cards.find(card)
	if index < 0:
		return
	if open_cards.size() > 0 and card != open_cards[open_cards.size() - 1]:
		return
	var def := open_defs[index]
	var instance_id := _add_card_to_collection(def)
	_ensure_page_for_instance(instance_id)
	_animate_card_to_slot(card, instance_id)
	open_cards.remove_at(index)
	open_defs.remove_at(index)
	if open_cards.is_empty():
		_close_open_popup()

func _add_card_to_collection(def: CardDefinition) -> String:
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	var card := CardFactory.create_card(def)
	open_collection.add_card(card)
	SaveSystem.save_collection(open_collection)
	_load_from_collection()
	_refresh_view()
	return card.instance_id

func _animate_card_to_slot(card: CardView, instance_id: String) -> void:
	if card == null:
		return
	var slot := _find_slot_for_instance(instance_id)
	if slot == null:
		card.queue_free()
		return
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.reparent(self, true)
	card.z_index = 100
	var target_center := slot.get_global_rect().get_center()
	var scaled_size := OPEN_CARD_BASE * card.scale
	var target_pos := target_center - (scaled_size * 0.5)
	var tween := create_tween()
	tween.tween_property(card, "global_position", target_pos, 0.35)
	tween.tween_callback(card.queue_free)

func _find_slot_for_instance(instance_id: String) -> CollectionSlot:
	for child in left_grid.get_children():
		if child is CollectionSlot:
			var slot: CollectionSlot = child
			if slot.current_instance_id == instance_id:
				return slot
	for child in right_grid.get_children():
		if child is CollectionSlot:
			var slot: CollectionSlot = child
			if slot.current_instance_id == instance_id:
				return slot
	return null

func _ensure_page_for_instance(instance_id: String) -> void:
	if instance_id == "":
		return
	var target_index := -1
	for i in range(card_keys.size()):
		var key := card_keys[i]
		if key == instance_id:
			target_index = i
			break
	if target_index < 0:
		return
	var target_spread: int = int(target_index / SLOTS_PER_SPREAD)
	if target_spread != spread_index:
		spread_index = target_spread
		_refresh_view()

func _on_add_all_pressed() -> void:
	for def in open_defs:
		_add_card_to_collection(def)
	_clear_open_cards()
	open_defs.clear()
	_close_open_popup()

func _clear_open_cards() -> void:
	for card in open_cards:
		card.queue_free()
	open_cards.clear()

func _close_open_popup() -> void:
	if open_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(open_popup, "modulate:a", 0.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(0.98, 0.98), 0.15)
	tween.tween_callback(func():
		open_popup.visible = false
		open_popup.modulate.a = 1.0
		open_popup.scale = Vector2.ONE
		_refresh_boosters()
	)

func _get_pack_pool(pack_type: String) -> Array[CardDefinition]:
	var pool: Array[CardDefinition] = []
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var biome := BIOME_FOREST
	if pack_type == "dark_forest":
		biome = BIOME_DARK_FOREST
	for def in CardDatabase.definitions.values():
		var card_def := def as CardDefinition
		if card_def == null:
			continue
		if card_def.card_type != "enemy":
			continue
		if card_def.biome_modifier != biome:
			continue
		if card_def.is_tutorial:
			continue
		pool.append(card_def)
	return pool

func _open_booster_popup(pack: PackView) -> void:
	if booster_popup == null:
		return
	selected_pack = pack
	booster_popup.visible = true
	if booster_popup_name:
		var display_name: String = pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
		booster_popup_name.text = display_name
	if booster_popup_preview:
		booster_popup_preview.color = pack.color

func _close_booster_popup() -> void:
	if booster_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(booster_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		booster_popup.visible = false
		booster_popup.modulate.a = 1.0
	)

func _on_booster_open_pressed() -> void:
	if selected_pack == null:
		return
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	if not collection.remove_booster(selected_pack.pack_type, 1):
		_close_booster_popup()
		return
	SaveSystem.save_collection(collection)
	_refresh_boosters()
	_close_booster_popup_and_open(selected_pack)

func _close_booster_popup_and_open(pack: PackView) -> void:
	if booster_popup == null:
		_open_pack_popup(pack)
		return
	var tween := create_tween()
	tween.tween_property(booster_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		booster_popup.visible = false
		booster_popup.modulate.a = 1.0
		_open_pack_popup(pack)
	)

func _build_slots() -> void:
	if slot_scene == null:
		push_error("[Collection] slot_scene no asignada")
		return

	_clear_grid(left_grid)
	_clear_grid(right_grid)

	for i in range(SLOTS_PER_PAGE):
		var slot_left: CollectionSlot = slot_scene.instantiate()
		slot_left.card_view_scene = card_view_scene
		slot_left.slot_clicked.connect(_on_slot_clicked)
		left_grid.add_child(slot_left)

		var slot_right: CollectionSlot = slot_scene.instantiate()
		slot_right.card_view_scene = card_view_scene
		slot_right.slot_clicked.connect(_on_slot_clicked)
		right_grid.add_child(slot_right)

func _refresh_view() -> void:
	var start_index := spread_index * SLOTS_PER_SPREAD
	var end_index := start_index + SLOTS_PER_SPREAD

	_set_grid_slots(left_grid, start_index, start_index + SLOTS_PER_PAGE)
	_set_grid_slots(right_grid, start_index + SLOTS_PER_PAGE, end_index)

	var page_left := (spread_index * 2) + 1
	var page_right := page_left + 1
	page_label.text = tr("COLLECTION_PAGE_LABEL") % [page_left, page_right]

	prev_button.disabled = spread_index <= 0
	next_button.disabled = end_index >= card_keys.size()
	_update_selection_state()

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
					child.set_occupied(def, key)
					_update_slot_selection(child)
				else:
					child.set_empty()
			else:
				child.set_empty()
			slot_index += 1

func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

func _on_slot_clicked(slot: CollectionSlot) -> void:
	if not selection_mode:
		return
	if slot.current_instance_id == "":
		return
	if slot.current_card_type == "hero":
		if selected_hero_id == slot.current_instance_id:
			selected_hero_id = ""
		else:
			selected_hero_id = slot.current_instance_id
	elif slot.current_card_type == "enemy":
		if selected_enemy_ids.has(slot.current_instance_id):
			selected_enemy_ids.erase(slot.current_instance_id)
		else:
			selected_enemy_ids[slot.current_instance_id] = true
	_update_selection_state()

func _update_slot_selection(slot: CollectionSlot) -> void:
	if slot == null:
		return
	var selected := false
	if slot.current_card_type == "hero":
		selected = slot.current_instance_id == selected_hero_id
	elif slot.current_card_type == "enemy":
		selected = selected_enemy_ids.has(slot.current_instance_id)
	slot.set_selected(selected)

func _update_selection_state() -> void:
	if not selection_mode:
		return
	var has_hero := selected_hero_id != ""
	var has_enemies := selected_enemy_ids.size() > 0
	if select_hero_label:
		_set_hint_visible(select_hero_label, not has_hero)
	if select_enemies_label:
		_set_hint_visible(select_enemies_label, not has_enemies)
	if start_dungeon_button:
		start_dungeon_button.disabled = not (has_hero and has_enemies)

	# Refresh outlines on visible slots
	for child in left_grid.get_children():
		if child is CollectionSlot:
			_update_slot_selection(child)
	for child in right_grid.get_children():
		if child is CollectionSlot:
			_update_slot_selection(child)

func _set_hint_visible(label: Label, show: bool) -> void:
	if label == null:
		return
	label.visible = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 1.0 if show else 0.0

func _on_start_dungeon_pressed() -> void:
	if selected_hero_id == "" or selected_enemy_ids.size() == 0:
		return
	var enemies: Array[String] = []
	for key in selected_enemy_ids.keys():
		enemies.append(String(key))
	var run_deck := SaveSystem.build_run_deck_from_selection(selected_hero_id, enemies)
	if run_deck.is_empty():
		return
	SaveSystem.save_run_deck(run_deck)
	RunState.reset_run()
	RunState.selection_pending = false
	get_tree().change_scene_to_file("res://Scenes/battle_table.tscn")

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
