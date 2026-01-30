extends Node2D

@export var use_collection_cards: bool = true
@export var slots_per_page: int = 9
@export var desired_page_height: float = 880.0
@export var table_scale: float = 1.05
@export var fixed_zoom: float = 0.5
@export var fit_height_ratio: float = 0.75
@export var closed_bottom_margin: float = 50.0
@export var card_view_scene: PackedScene = preload("res://Scenes/cards/card_view.tscn")

@onready var book: PageFlip2D = $Book
@onready var back_button: Button = $CanvasLayer/UI/BackButton
@onready var prev_button: Button = $CanvasLayer/UI/TopBar/PrevButton
@onready var next_button: Button = $CanvasLayer/UI/TopBar/NextButton
@onready var title_label: Label = $CanvasLayer/UI/TopBar/TitleLabel
@onready var page_label: Label = $CanvasLayer/UI/TopBar/PageLabel

@onready var booster_area: Control = $CanvasLayer/UI/BoosterArea
@onready var booster_list: VBoxContainer = $CanvasLayer/UI/BoosterArea/BoosterList
@onready var booster_popup: Control = $CanvasLayer/UI/BoosterPopup
@onready var booster_popup_dimmer: ColorRect = $CanvasLayer/UI/BoosterPopup/Dimmer
@onready var booster_popup_title: Label = $CanvasLayer/UI/BoosterPopup/Panel/Content/TitleLabel
@onready var booster_popup_preview: ColorRect = $CanvasLayer/UI/BoosterPopup/Panel/Content/Preview
@onready var booster_popup_name: Label = $CanvasLayer/UI/BoosterPopup/Panel/Content/NameLabel
@onready var booster_popup_open: Button = $CanvasLayer/UI/BoosterPopup/Panel/Content/Buttons/OpenButton
@onready var booster_popup_back: Button = $CanvasLayer/UI/BoosterPopup/Panel/Content/Buttons/BackButton

@onready var open_popup: Control = $CanvasLayer/UI/OpenPackPopup
@onready var open_popup_dimmer: ColorRect = $CanvasLayer/UI/OpenPackPopup/Dimmer
@onready var open_popup_title: Label = $CanvasLayer/UI/OpenPackPopup/Panel/Content/TitleLabel
@onready var open_popup_cards: Control = $CanvasLayer/UI/OpenPackPopup/Panel/Content/CardsContainer
@onready var open_popup_add_all: Button = $CanvasLayer/UI/OpenPackPopup/Panel/Content/Buttons/AddAllButton
@onready var open_popup_back: Button = $CanvasLayer/UI/OpenPackPopup/Panel/Content/Buttons/BackButton

const SLOTS_PER_PAGE: int = 12
const SLOTS_PER_SPREAD: int = 24
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

var _selected_pack: PackView = null
var _open_defs: Array[CardDefinition] = []
var _open_cards: Array[CardView] = []
var _open_collection: PlayerCollection = null
var _last_open_state: bool = true

func _ready() -> void:
	book.visible = true
	if book.visuals_container:
		book.visuals_container.visible = false
	_configure_book()
	_wire_ui()
	_refresh_boosters()
	_update_page_label()
	_apply_book_scale()
	_apply_book_position()
	call_deferred("_apply_book_scale")
	call_deferred("_apply_book_position")
	call_deferred("_deferred_show_book")
	if book.anim_player:
		var anim_finished_cb: Callable = Callable(self, "_on_book_animation_finished")
		if not book.anim_player.is_connected("animation_finished", anim_finished_cb):
			book.anim_player.animation_finished.connect(anim_finished_cb)
	var vp: Viewport = get_viewport()
	if vp:
		vp.size_changed.connect(func() -> void:
			call_deferred("_apply_book_scale")
			call_deferred("_apply_book_position")
		)

func _configure_book() -> void:
	if book == null:
		return
	book.start_option = PageFlip2D.StartOption.CLOSED_FROM_FRONT
	book.start_page = 2
	book.close_condition = PageFlip2D.CloseCondition.NEVER
	book.blank_page_color = Color(0.88, 0.88, 0.88, 1.0)
	book.enable_composite_pages = true
	book.target_page_size = Vector2(1800, 2000)
	book.closed_skew = 0.0
	book.closed_rotation = 0.0
	book.closed_scale = Vector2(0.25, 0.25)
	book.open_scale = Vector2.ONE
	book.call("_apply_new_size")
	book.tex_cover_front_out = preload("res://assets/card_book/card_book_cover_front.png")
	book.tex_cover_front_in = preload("res://assets/card_book/card_book_inside.png")
	book.tex_cover_back_in = preload("res://assets/card_book/card_book_inside.png")
	book.tex_cover_back_out = preload("res://assets/card_book/card_book_cover_back.png")
	book.flip_mirror_enabled = false
	_last_open_state = book.is_book_open

	_refresh_book_content()
	_apply_book_scale()
	_tune_page_curvature()

func _refresh_book_content() -> void:
	if book == null:
		return
	var page_count: int = _get_page_count()
	if page_count <= 0:
		page_count = 1
	var page_scene_path: String = "res://Scenes/ui/collection_page.tscn"
	book.pages_paths.clear()
	for i in range(page_count):
		book.pages_paths.append(page_scene_path)
	book.call("_prepare_book_content")
	book.call("_update_static_visuals_immediate")
	book.call("_update_volume_visuals")
	_update_page_label()
	_update_navigation_state()

func _tune_page_curvature() -> void:
	if book == null:
		return
	var page: Node = book.dynamic_poly
	if page == null:
		return
	if page is DynamicPage:
		var dyn: DynamicPage = page as DynamicPage
		dyn.animation_preset = DynamicPage.PagePreset.CUSTOM
		dyn.subdivision_x = 10
		dyn.subdivision_y = 6
		dyn.paper_stiffness = 1.3
		dyn.lift_bend = -22.0
		dyn.land_bend = -12.0
		dyn.curl_mode = DynamicPage.CurlMode.TOP_CORNER_FIRST
		dyn.curl_lag = 0.8
		dyn.rebuild(book.target_page_size)

func _wire_ui() -> void:
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if back_button:
		back_button.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
		)
	if booster_popup_open:
		booster_popup_open.pressed.connect(_on_booster_open_pressed)
	if booster_popup_back:
		booster_popup_back.pressed.connect(_close_booster_popup)
	if open_popup_add_all:
		open_popup_add_all.pressed.connect(_on_add_all_pressed)
	if open_popup_back:
		open_popup_back.pressed.connect(_close_open_popup)
	if booster_popup_title:
		booster_popup_title.text = tr("COLLECTION_BOOSTER_POPUP_TITLE")
	if booster_popup_open:
		booster_popup_open.text = tr("COLLECTION_BOOSTER_OPEN")
	if booster_popup_back:
		booster_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
	if open_popup_title:
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE")
	if open_popup_add_all:
		open_popup_add_all.text = tr("COLLECTION_OPEN_ADD_ALL")
	if open_popup_back:
		open_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
	if title_label:
		title_label.text = tr("COLLECTION_TITLE")
	if prev_button:
		prev_button.text = tr("COLLECTION_PREV")
	if next_button:
		next_button.text = tr("COLLECTION_NEXT")
	if page_label:
		_update_page_label()

	if booster_popup:
		booster_popup.visible = false
		booster_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if booster_area:
		booster_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_list:
		booster_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup_dimmer:
		booster_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup:
		open_popup.visible = false
		open_popup.modulate.a = 1.0
		open_popup.scale = Vector2.ONE
		open_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup_dimmer:
		open_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if open_popup_cards:
		open_popup_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_book_scale() -> void:
	var base_h: float = book.target_page_size.y
	if base_h <= 0.0:
		return
	book.scale = Vector2.ONE
	var cam: Node = book.get_node_or_null("Camera2D")
	if not cam:
		return
	var camera: Camera2D = cam as Camera2D
	camera.make_current()
	var view_size: Vector2 = _get_viewport_size()
	var view_h: float = view_size.y
	if view_h <= 0.0:
		camera.zoom = Vector2(fixed_zoom, fixed_zoom)
		return
	var total_book_h: float = book.target_page_size.y
	var zoom: float = (view_h * fit_height_ratio) / total_book_h
	camera.zoom = Vector2(zoom, zoom)

func _apply_book_position() -> void:
	if book == null:
		return
	var vc: CanvasItem = book.visuals_container
	if vc == null:
		return
	var view: Vector2 = _get_viewport_size()
	var half_width: float = book.target_page_size.x * 0.5
	if book.is_book_open:
		vc.global_position = Vector2(view.x * 0.5 - half_width, view.y * 0.5)
	else:
		var y: float = view.y - closed_bottom_margin - (book.target_page_size.y * 0.5)
		vc.global_position = Vector2(view.x * 0.5 - half_width, y)
		vc.skew = 0.0
		vc.rotation = 0.0

func _get_viewport_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if not vp:
		return Vector2.ZERO
	var visible: Vector2 = vp.get_visible_rect().size
	if visible != Vector2.ZERO:
		return visible
	return vp.size

func _deferred_show_book() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if book.visuals_container:
		book.visuals_container.visible = true

func _apply_book_position_on_state_change() -> void:
	if book == null:
		return
	if book.is_book_open == _last_open_state:
		return
	_last_open_state = book.is_book_open
	call_deferred("_apply_book_position")

func _on_book_animation_finished(_name: String) -> void:
	_apply_book_position_on_state_change()
	_update_page_label()
	_update_navigation_state()

func _get_page_count() -> int:
	if not use_collection_cards:
		return 1
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var collection: PlayerCollection = SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var total: int = collection.get_all_cards().size()
	return int(ceili(float(total) / float(slots_per_page)))

func _update_page_label() -> void:
	if page_label == null or book == null:
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
	if prev_button:
		prev_button.disabled = book == null or book.is_animating or book.current_spread <= -1
	if next_button:
		next_button.disabled = book == null or book.is_animating or book.current_spread >= book.total_spreads

func _get_pack_pool(pack_type: String) -> Array[CardDefinition]:
	var pool: Array[CardDefinition] = []
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var biome: String = BIOME_FOREST
	if pack_type == "dark_forest":
		biome = BIOME_DARK_FOREST
	for def in CardDatabase.definitions.values():
		var card_def: CardDefinition = def as CardDefinition
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

func _on_prev_pressed() -> void:
	if book == null:
		return
	book.prev_page()

func _on_next_pressed() -> void:
	if book == null:
		return
	book.next_page()

func _refresh_boosters() -> void:
	if booster_list == null:
		return
	for child in booster_list.get_children():
		child.queue_free()

	var collection: PlayerCollection = SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()

	var packs: Array[PackView] = _build_pack_views()
	for pack in packs:
		var count: int = collection.get_booster_count(pack.pack_type)
		if count <= 0:
			continue
		_add_booster_stack(pack, count)

func _build_pack_views() -> Array:
	var result: Array = []
	var forest := _load_pack_view(PACK_FOREST_PATH, "forest", PACK_FOREST_COLOR)
	if forest != null:
		result.append(forest)
	var dark_forest := _load_pack_view(PACK_DARK_FOREST_PATH, "dark_forest", PACK_DARK_FOREST_COLOR)
	if dark_forest != null:
		result.append(dark_forest)
	return result

func _load_pack_view(path: String, pack_type: String, color: Color) -> PackView:
	var def: BoosterPackDefinition = load(path) as BoosterPackDefinition
	var view: PackView = PackView.new()
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
	var item: VBoxContainer = VBoxContainer.new()
	item.custom_minimum_size = Vector2(220, 110)
	item.alignment = BoxContainer.ALIGNMENT_BEGIN
	booster_list.add_child(item)

	var label: Label = Label.new()
	var display_name: String = pack.pack_type
	if pack.name_key != "":
		display_name = tr(pack.name_key)
	label.text = tr("COLLECTION_PACK_COUNT") % [display_name, count]
	item.add_child(label)

	var stack: Control = Control.new()
	stack.custom_minimum_size = Vector2(220, 90)
	item.add_child(stack)

	var visible_count: int = min(count, PACK_STACK_MAX)
	for i in range(visible_count):
		var rect: ColorRect = ColorRect.new()
		rect.color = pack.color
		rect.custom_minimum_size = PACK_PREVIEW_SIZE
		rect.position = Vector2(PACK_STACK_OFFSET_X * float(i), PACK_STACK_OFFSET_Y * float(i))
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		rect.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_booster_popup(pack)
		)
		stack.add_child(rect)

func _open_booster_popup(pack: PackView) -> void:
	if booster_popup == null:
		return
	_selected_pack = pack
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
	var tween: Tween = create_tween()
	tween.tween_property(booster_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		booster_popup.visible = false
		booster_popup.modulate.a = 1.0
	)

func _on_booster_open_pressed() -> void:
	if _selected_pack == null:
		return
	var collection: PlayerCollection = SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	if not collection.remove_booster(_selected_pack.pack_type, 1):
		_close_booster_popup()
		return
	SaveSystem.save_collection(collection)
	_refresh_boosters()
	_close_booster_popup_and_open(_selected_pack)

func _close_booster_popup_and_open(pack: PackView) -> void:
	if booster_popup == null:
		_open_pack_popup(pack)
		return
	var tween: Tween = create_tween()
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
	open_popup.modulate.a = 0.0
	open_popup.scale = Vector2(0.95, 0.95)
	var loaded_collection: PlayerCollection = SaveSystem.load_collection()
	if loaded_collection == null:
		loaded_collection = SaveSystem.ensure_collection()
	_open_collection = loaded_collection
	_clear_open_cards()
	_open_defs.clear()
	var pool: Array[CardDefinition] = _get_pack_pool(pack.pack_type)
	if pool.is_empty():
		return
	if open_popup_title:
		var display_name: String = pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE_NAME") % display_name
	_play_open_popup_in()
	for i in range(OPEN_CARDS_PER_PACK):
		var card_def: CardDefinition = pool[randi() % pool.size()]
		_open_defs.append(card_def)
	call_deferred("_add_open_cards_visual", _open_defs)

func _add_open_cards_visual(defs: Array[CardDefinition]) -> void:
	if open_popup_cards == null:
		return
	_clear_open_cards()
	for i in range(defs.size()):
		var card_def: CardDefinition = defs[i]
		var card: CardView = card_view_scene.instantiate() as CardView
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
		var scale_w: float = OPEN_CARD_DISPLAY.x / OPEN_CARD_BASE.x
		var scale_h: float = OPEN_CARD_DISPLAY.y / OPEN_CARD_BASE.y
		var final_scale: float = minf(scale_w, scale_h)
		card.scale = Vector2(final_scale, final_scale)
		var scaled_size: Vector2 = OPEN_CARD_BASE * final_scale
		var base_pos: Vector2 = (open_popup_cards.size * 0.5) - (scaled_size * 0.5)
		card.position = base_pos + Vector2(OPEN_CARD_OFFSET.x * float(i), OPEN_CARD_OFFSET.y * float(i))
		card.z_index = i
		_open_cards.append(card)
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
	if open_popup == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(open_popup, "modulate:a", 1.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(1.0, 1.0), 0.2)

func _on_open_card_clicked(card: CardView) -> void:
	var index := _open_cards.find(card)
	if index < 0:
		return
	if _open_cards.size() > 0 and card != _open_cards[_open_cards.size() - 1]:
		return
	var card_def: CardDefinition = _open_defs[index]
	var instance_id := _add_card_to_collection(card_def)
	_open_cards.remove_at(index)
	_open_defs.remove_at(index)
	card.queue_free()
	if _open_cards.is_empty():
		_close_open_popup()

func _add_card_to_collection(def: CardDefinition) -> String:
	if def == null:
		return ""
	if _open_collection == null:
		_open_collection = SaveSystem.ensure_collection()
	var card := CardFactory.create_card(def)
	if card == null:
		return ""
	_open_collection.add_card(card)
	SaveSystem.save_collection(_open_collection)
	_refresh_boosters()
	_refresh_book_content()
	return card.instance_id

func _on_add_all_pressed() -> void:
	for def_item in _open_defs.duplicate():
		var card_def: CardDefinition = def_item as CardDefinition
		if card_def == null:
			continue
		_add_card_to_collection(card_def)
	_clear_open_cards()
	_open_defs.clear()
	_close_open_popup()

func _clear_open_cards() -> void:
	for card in _open_cards:
		card.queue_free()
	_open_cards.clear()

func _close_open_popup() -> void:
	if open_popup == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(open_popup, "modulate:a", 0.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(0.98, 0.98), 0.15)
	tween.tween_callback(func():
		open_popup.visible = false
		open_popup.modulate.a = 1.0
		open_popup.scale = Vector2.ONE
		_refresh_boosters()
	)
