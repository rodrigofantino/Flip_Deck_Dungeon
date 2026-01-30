extends Control

@export var design_resolution: Vector2 = Vector2(1280, 720)

@onready var book_view: Control = $BookView
@onready var prev_button: Button = $TopBar/PrevButton
@onready var next_button: Button = $TopBar/NextButton
@onready var title_label: Label = $TopBar/TitleLabel
@onready var page_label: Label = $TopBar/PageLabel
@onready var selection_panel: VBoxContainer = $SelectionPanel
@onready var select_hero_label: Label = $SelectionPanel/SelectHeroLabel
@onready var select_enemies_label: Label = $SelectionPanel/SelectEnemiesLabel
@onready var start_dungeon_button: Button = $SelectionPanel/StartDungeonButton
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
@onready var open_popup_dimmer: ColorRect = $OpenPackPopup/Dimmer
@onready var open_popup_title: Label = $OpenPackPopup/Panel/Content/TitleLabel
@onready var open_popup_cards: Control = $OpenPackPopup/Panel/Content/CardsContainer
@onready var open_popup_add_all: Button = $OpenPackPopup/Panel/Content/Buttons/AddAllButton
@onready var open_popup_back: Button = $OpenPackPopup/Panel/Content/Buttons/BackButton

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
const CARD_VIEW_SCENE: PackedScene = preload("res://Scenes/cards/card_view.tscn")

class PackView:
	var pack_type: String
	var name_key: String
	var color: Color

var selection_mode: bool = false
var selected_hero_id: String = ""
var selected_enemy_ids: Dictionary = {}
var selected_pack: PackView = null
var open_defs: Array[CardDefinition] = []
var open_cards: Array[CardView] = []
var open_collection: PlayerCollection = null
var _pending_book_refresh: bool = false

func _ready() -> void:
	_configure_design_layout()
	add_to_group("collection_root")
	_wire_ui()
	_setup_book_view()
	_refresh_boosters()
	_init_selection_ui()
	_set_booster_interactivity(true)
	_refresh_book_content()

func _configure_design_layout() -> void:
	size = design_resolution
	call_deferred("_apply_design_layout")
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_apply_design_layout)

func _apply_design_layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var view := vp.get_visible_rect().size
	if view == Vector2.ZERO:
		return
	var ratio: float = min(view.x / design_resolution.x, view.y / design_resolution.y)
	scale = Vector2.ONE * ratio
	size = design_resolution
	position = (view - design_resolution * ratio) * 0.5

func _wire_ui() -> void:
	if title_label:
		title_label.text = tr("COLLECTION_TITLE")
	if prev_button:
		prev_button.text = tr("COLLECTION_PREV")
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.text = tr("COLLECTION_NEXT")
		next_button.pressed.connect(_on_next_pressed)
	if page_label:
		_update_page_label()
	if back_button:
		back_button.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
		)
	if booster_popup and booster_popup_title:
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
		open_popup_back.pressed.connect(_close_open_popup)
	if open_popup != null and open_popup_cards != null:
		open_popup_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup != null:
		booster_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if booster_popup_dimmer:
		booster_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup_dimmer:
		open_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

func _setup_book_view() -> void:
	if book_view == null:
		return
	book_view.visible = true
	if book_view.has_method("force_show"):
		book_view.call("force_show")
	var book: PageFlip2D = _get_book() as PageFlip2D
	if book == null:
		return
	var anim_player: AnimationPlayer = book.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player and anim_player is AnimationPlayer:
		var cb := Callable(self, "_on_book_animation_finished")
		if not anim_player.is_connected("animation_finished", cb):
			anim_player.animation_finished.connect(cb)
	_update_page_label()
	_update_navigation_state()

func _get_book() -> Node:
	if book_view == null:
		return null
	var node := book_view.get_node_or_null("Book")
	if node == null:
		return null
	return node

func _refresh_book_content() -> void:
	if book_view == null:
		_update_page_label()
		_update_navigation_state()
		return
	var book_node := _get_book() as PageFlip2D
	if book_node != null and book_node.is_animating:
		_pending_book_refresh = true
		return
	_pending_book_refresh = false
	if book_view.has_method("_refresh_book_content"):
		book_view.call("_refresh_book_content")
	_update_page_label()
	_update_navigation_state()

func _on_book_animation_finished(_name: String) -> void:
	_update_page_label()
	_update_navigation_state()
	if _pending_book_refresh:
		call_deferred("_refresh_book_content")

func _update_page_label() -> void:
	if page_label == null:
		return
	var book: PageFlip2D = _get_book() as PageFlip2D
	if book == null:
		page_label.text = tr("COLLECTION_PAGE_LABEL") % [1, 2]
		return
	var total_spreads: int = book.total_spreads
	var spread_idx: int = clamp(book.current_spread, 0, max(total_spreads - 1, 0))
	var page_left: int = (spread_idx * 2) + 1
	var page_right: int = page_left + 1
	if page_left < 1:
		page_left = 1
	if page_right < page_left:
		page_right = page_left
	page_label.text = tr("COLLECTION_PAGE_LABEL") % [page_left, page_right]

func _update_navigation_state() -> void:
	var book: PageFlip2D = _get_book() as PageFlip2D
	if prev_button:
		prev_button.disabled = book == null or book.is_animating or book.current_spread <= -1
	if next_button:
		next_button.disabled = book == null or book.is_animating or book.current_spread >= book.total_spreads

func _init_selection_ui() -> void:
	selection_mode = RunState.selection_pending
	if selection_panel:
		selection_panel.visible = true
		selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_booster_interactivity(true)
	if select_hero_label:
		select_hero_label.text = tr("COLLECTION_SELECT_HERO")
		select_hero_label.visible = selection_mode
	if select_enemies_label:
		select_enemies_label.text = tr("COLLECTION_SELECT_ENEMIES")
		select_enemies_label.visible = selection_mode
	if start_dungeon_button:
		start_dungeon_button.text = tr("COLLECTION_START_DUNGEON")
		start_dungeon_button.pressed.connect(_on_start_dungeon_pressed)
		start_dungeon_button.visible = selection_mode
	_update_selection_state()
	if not selection_mode:
		_clear_selection_visuals()

func _clear_selection_visuals() -> void:
	for slot in get_tree().get_nodes_in_group("collection_slots"):
		if slot is CollectionSlot:
			(slot as CollectionSlot).set_selected(false)

func _on_page_slot_clicked(slot: CollectionSlot) -> void:
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
		if select_hero_label:
			select_hero_label.visible = false
		if select_enemies_label:
			select_enemies_label.visible = false
		if start_dungeon_button:
			start_dungeon_button.visible = false
		_clear_selection_visuals()
		return
	var has_hero := selected_hero_id != ""
	var has_enemies := selected_enemy_ids.size() > 0
	if select_hero_label:
		_set_hint_visible(select_hero_label, not has_hero)
	if select_enemies_label:
		_set_hint_visible(select_enemies_label, not has_enemies)
	if start_dungeon_button:
		start_dungeon_button.disabled = not (has_hero and has_enemies)
	for slot in get_tree().get_nodes_in_group("collection_slots"):
		if slot is CollectionSlot:
			_update_slot_selection(slot)

func _set_hint_visible(label: Label, show: bool) -> void:
	if label == null:
		return
	label.visible = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 1.0 if show else 0.0

func _set_booster_interactivity(enabled: bool) -> void:
	if booster_area:
		booster_area.visible = enabled
		booster_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_list:
		booster_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup:
		booster_popup.visible = enabled and booster_popup.visible

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
	_change_book_page(false)

func _on_next_pressed() -> void:
	_change_book_page(true)

func _change_book_page(go_next: bool) -> void:
	var book: PageFlip2D = _get_book() as PageFlip2D
	if book == null or book.is_animating:
		return
	if go_next:
		book.next_page()
	else:
		book.prev_page()
	call_deferred("_refresh_book_change_state")

func _refresh_book_change_state() -> void:
	_update_page_label()
	_update_navigation_state()

func _open_booster_popup(pack: PackView) -> void:
	if booster_popup == null:
		return
	selected_pack = pack
	booster_popup.visible = true
	booster_popup.z_index = 150
	if booster_popup_name:
		var display_name := pack.pack_type
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

func _open_pack_popup(pack: PackView) -> void:
	if open_popup == null or open_popup_cards == null:
		return
	open_popup.visible = true
	open_popup.z_index = 200
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
		var display_name := pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE_NAME") % display_name
	_play_open_popup_in()
	for i in range(OPEN_CARDS_PER_PACK):
		var card_def := pool[randi() % pool.size()]
		open_defs.append(card_def)
	call_deferred("_add_open_cards_visual", open_defs)

func _add_open_cards_visual(defs: Array[CardDefinition]) -> void:
	if open_popup_cards == null:
		return
	_clear_open_cards()
	for i in range(defs.size()):
		var card_def := defs[i]
		var card := CARD_VIEW_SCENE.instantiate() as CardView
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
		card.setup_from_definition(card_def)
		card.show_front()
		_set_mouse_filter_recursive(card, Control.MOUSE_FILTER_IGNORE)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var scale_w := OPEN_CARD_DISPLAY.x / OPEN_CARD_BASE.x
		var scale_h := OPEN_CARD_DISPLAY.y / OPEN_CARD_BASE.y
		var final_scale := minf(scale_w, scale_h)
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

func _on_open_card_clicked(card: CardView) -> void:
	var index := open_cards.find(card)
	if index < 0:
		return
	if open_cards.size() > 0 and card != open_cards[open_cards.size() - 1]:
		return
	var card_def := open_defs[index]
	var instance_id := _add_card_to_collection(card_def)
	open_cards.remove_at(index)
	open_defs.remove_at(index)
	card.queue_free()
	if open_cards.is_empty():
		_close_open_popup()

func _add_card_to_collection(def: CardDefinition) -> String:
	if def == null:
		return ""
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	var card := CardFactory.create_card(def)
	if card == null:
		return ""
	open_collection.add_card(card)
	SaveSystem.save_collection(open_collection)
	_refresh_boosters()
	_refresh_book_content()
	_go_to_card_page(card.instance_id)
	return card.instance_id

func _on_add_all_pressed() -> void:
	for def_item in open_defs.duplicate():
		var card_def := def_item as CardDefinition
		if card_def == null:
			continue
		_add_card_to_collection(card_def)
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
		_refresh_book_content()
	)

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _play_open_popup_in() -> void:
	if open_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(open_popup, "modulate:a", 1.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(1.0, 1.0), 0.2)

func _refresh_boosters() -> void:
	if booster_list == null:
		return
	for child in booster_list.get_children():
		child.queue_free()
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var packs := _build_pack_views()
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
	if booster_list == null:
		return
	var item := VBoxContainer.new()
	item.custom_minimum_size = Vector2(220, 110)
	item.alignment = BoxContainer.ALIGNMENT_BEGIN
	booster_list.add_child(item)
	var label := Label.new()
	var display_name := pack.pack_type
	if pack.name_key != "":
		display_name = tr(pack.name_key)
	label.text = tr("COLLECTION_PACK_COUNT") % [display_name, count]
	item.add_child(label)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(220, 90)
	item.add_child(stack)
	var visible_count: int = min(count, PACK_STACK_MAX)
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

func _go_to_card_page(instance_id: String) -> void:
	if instance_id == "":
		return
	var book_node := _get_book()
	if book_node == null:
		return
	var book_page := book_node as PageFlip2D
	if book_page == null:
		return
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var cards := collection.get_all_cards()
	if cards.is_empty():
		return
	var slots_per_page: int = 9
	if book_view != null:
		var exported_value: Variant = book_view.get("slots_per_page")
		if typeof(exported_value) == TYPE_INT:
			var override_pages: int = exported_value as int
			if override_pages > 0:
				slots_per_page = override_pages
	for i in range(cards.size()):
		var card := cards[i]
		if card.instance_id == instance_id:
			var page_index := int(i / max(1, slots_per_page))
			var target_page := page_index + 1
			book_page.call("go_to_page", target_page, PageFlip2D.JumpTarget.CONTENT_PAGE)
			return
