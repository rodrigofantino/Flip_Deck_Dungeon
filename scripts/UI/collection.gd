extends Control

@export var design_resolution: Vector2 = Vector2(1280, 720)

@onready var book_view: Control = $BookView
@onready var prev_button: Button = $TopBar/PrevButton
@onready var next_button: Button = $TopBar/NextButton
@onready var title_label: Label = $TopBar/TitleLabel
@onready var page_label: Label = $TopBar/PageLabel
@onready var upgrades_button: Button = $TopBar/UpgradesButton
@onready var selection_panel: VBoxContainer = $SelectionPanel
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
@onready var card_popup: Control = $CardPopup
@onready var card_popup_dimmer: ColorRect = $CardPopup/Dimmer
@onready var card_popup_container: Control = $CardPopup/Panel/Content/CardContainer
@onready var card_popup_count: Label = $CardPopup/Panel/Content/CountLabel
@onready var card_popup_upgrade: Button = $CardPopup/Panel/Content/Buttons/UpgradeButton
@onready var card_popup_back: Button = $CardPopup/Panel/Content/Buttons/BackButton

const PACK_STACK_OFFSET_X: float = 2.0
const PACK_STACK_OFFSET_Y: float = 2.0
const PACK_STACK_MAX: int = 12
const PACK_PREVIEW_SIZE: Vector2 = Vector2(128, 192)
const PACK_STACK_ITEM_MIN_SIZE: Vector2 = Vector2(188, 244)
const PACK_STACK_CONTAINER_MIN_SIZE: Vector2 = Vector2(172, 214)
const FOREST_BOOSTER_FRAME_PATH_FMT: String = "res://assets/boosterpacks/forest/forest_boosterpack_frame_%02d.png"
const FOREST_BOOSTER_FRAME_COUNT: int = 12
const PACK_FOREST_COLOR: Color = Color(0.6, 0.85, 0.6, 1.0)
const PACK_DARK_FOREST_COLOR: Color = Color(0.12, 0.35, 0.2, 1.0)
const PACK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_forest.tres"
const PACK_DARK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_dark_forest.tres"
const OPEN_CARD_OFFSET: Vector2 = Vector2(2.0, 2.0)
const OPEN_CARD_BASE: Vector2 = Vector2(620, 860)
const OPEN_CARD_DISPLAY: Vector2 = Vector2(155, 215)
const OPEN_CARDS_PER_PACK: int = 5
const OPEN_CARD_FLY_DURATION: float = 0.45
const OPEN_CARD_FLY_MAX_WAIT: float = 1.2
const BOOSTER_PREVIEW_AUTO_STEP_SEC: float = 0.08
const BIOME_FOREST: String = "Forest"
const BIOME_DARK_FOREST: String = "Dark Forest"
const CARD_VIEW_SCENE: PackedScene = preload("res://Scenes/cards/card_view.tscn")
const HERO_UPGRADES_SCENE: PackedScene = preload("res://Scenes/ui/hero_upgrades_window.tscn")

class PackView:
	var pack_type: String
	var name_key: String
	var color: Color

enum OpenPopupMode {
	NONE,
	PREVIEW,
	REVEAL,
}

var selected_pack: PackView = null
var open_defs: Array[CardDefinition] = []
var open_cards: Array[CardView] = []
var open_collection: PlayerCollection = null
var _pending_book_refresh: bool = false
var _popup_def: CardDefinition = null
var hero_upgrades_window: HeroUpgradesWindow = null
var _forest_booster_frames: Array[Texture2D] = []
var _forest_booster_popup_frame_index: int = 0
var _booster_open_in_progress: bool = false
var _open_popup_preview_texture: TextureRect = null
var _open_popup_mode: int = OpenPopupMode.NONE
var _preview_auto_advance_active: bool = false

func _ready() -> void:
	_configure_design_layout()
	add_to_group("collection_root")
	set_process_input(true)
	_wire_ui()
	_load_forest_booster_frames()
	_setup_book_view()
	_refresh_boosters()
	_hide_selection_ui()
	_set_booster_interactivity(true)
	_refresh_book_content()
	_update_book_input_block()

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
	if book_view and book_view.has_method("refresh_layout"):
		book_view.call_deferred("refresh_layout")

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
		page_label.visible = false
	if upgrades_button:
		upgrades_button.text = tr("COLLECTION_UPGRADES_BUTTON")
		upgrades_button.pressed.connect(_on_upgrades_pressed)
	if back_button:
		back_button.pressed.connect(func() -> void:
			SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")
		)
	if booster_popup:
		booster_popup.visible = false
	if booster_popup and booster_popup_title:
		booster_popup_title.text = tr("COLLECTION_BOOSTER_POPUP_TITLE")
	if open_popup_title:
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE")
	if open_popup_add_all:
		open_popup_add_all.text = tr("COLLECTION_BOOSTER_OPEN")
		open_popup_add_all.pressed.connect(_on_add_all_pressed)
	if open_popup_back:
		open_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		open_popup_back.pressed.connect(_close_open_popup)
	if card_popup_back:
		card_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		card_popup_back.pressed.connect(_close_card_popup)
	if card_popup_upgrade:
		card_popup_upgrade.pressed.connect(_on_card_upgrade_pressed)
	if open_popup != null and open_popup_cards != null:
		open_popup_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup != null:
		booster_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if booster_popup_dimmer:
		booster_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		booster_popup_dimmer.gui_input.connect(_on_popup_dimmer_gui_input)
	if open_popup_dimmer:
		open_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		open_popup_dimmer.gui_input.connect(_on_popup_dimmer_gui_input)
	if card_popup_dimmer:
		card_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		card_popup_dimmer.gui_input.connect(_on_popup_dimmer_gui_input)
	if card_popup:
		card_popup.mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if book_view == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_click_blocked_by_ui(event.global_position):
			return
		if book_view.has_method("try_open_from_click"):
			var opened := bool(book_view.call("try_open_from_click", event.global_position))
			if opened:
				accept_event()

func _is_click_blocked_by_ui(global_pos: Vector2) -> bool:
	var blockers: Array[Control] = []
	if selection_panel and selection_panel.visible:
		blockers.append(selection_panel)
	if booster_popup and booster_popup.visible:
		blockers.append(booster_popup)
	if open_popup and open_popup.visible:
		blockers.append(open_popup)
	if card_popup and card_popup.visible:
		blockers.append(card_popup)
	if hero_upgrades_window and hero_upgrades_window.visible:
		blockers.append(hero_upgrades_window)
	for ctrl in blockers:
		if ctrl and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(global_pos):
			return true
	return false

func _is_modal_popup_visible() -> bool:
	return (
		(booster_popup and booster_popup.visible)
		or (open_popup and open_popup.visible)
		or (card_popup and card_popup.visible)
		or (hero_upgrades_window and hero_upgrades_window.visible)
	)

func _update_book_input_block() -> void:
	if book_view == null:
		return
	var modal := _is_modal_popup_visible()
	if book_view.has_method("set_input_blocked"):
		book_view.call("set_input_blocked", modal)
	_set_slots_input_enabled(not modal)

func _set_slots_input_enabled(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE
	for node in get_tree().get_nodes_in_group("collection_slots"):
		if node is Control:
			(node as Control).mouse_filter = filter

func _on_popup_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

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

func _hide_selection_ui() -> void:
	if selection_panel == null:
		return
	_set_mouse_filter_recursive(selection_panel, Control.MOUSE_FILTER_IGNORE)
	var hide_paths := [
		"SelectHeroLabel",
		"SelectEnemiesLabel",
		"SelectionErrorLabel",
		"ItemTypeDistribution",
		"StartDungeonButton"
	]
	for path in hide_paths:
		var node := selection_panel.get_node_or_null(path)
		if node and node is CanvasItem:
			(node as CanvasItem).visible = false
	if back_button:
		back_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_page_slot_clicked(slot: CollectionSlot) -> void:
	if slot == null:
		return
	if slot.current_def_id == "":
		return
	if slot.current_card_type == "hero":
		_open_hero_upgrades()
	else:
		_open_card_popup(slot)

func _set_booster_interactivity(enabled: bool) -> void:
	if booster_area:
		booster_area.visible = enabled
		booster_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_list:
		booster_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup:
		booster_popup.visible = enabled and booster_popup.visible


func _on_prev_pressed() -> void:
	_change_book_page(false)

func _on_next_pressed() -> void:
	_change_book_page(true)

func _on_upgrades_pressed() -> void:
	_open_hero_upgrades()

func _open_hero_upgrades() -> void:
	if hero_upgrades_window == null:
		if HERO_UPGRADES_SCENE == null:
			return
		hero_upgrades_window = HERO_UPGRADES_SCENE.instantiate() as HeroUpgradesWindow
		if hero_upgrades_window == null:
			return
		add_child(hero_upgrades_window)
		hero_upgrades_window.z_index = 300
		hero_upgrades_window.closed.connect(_on_hero_upgrades_closed)
		hero_upgrades_window.upgrades_changed.connect(_on_hero_upgrades_changed)
	hero_upgrades_window.visible = true
	hero_upgrades_window.refresh_window()
	_update_book_input_block()

func _on_hero_upgrades_closed() -> void:
	_refresh_hero_slots()
	_update_book_input_block()

func _on_hero_upgrades_changed(_hero_id: StringName) -> void:
	_refresh_hero_slots()

func _refresh_hero_slots() -> void:
	for slot in get_tree().get_nodes_in_group("collection_slots"):
		if slot is CollectionSlot:
			(slot as CollectionSlot).refresh_hero_display()

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
	if pack == null:
		return
	selected_pack = pack
	_forest_booster_popup_frame_index = 0
	_booster_open_in_progress = false
	_open_pack_popup(pack)

func _close_booster_popup() -> void:
	_close_open_popup()

func _on_booster_open_pressed() -> void:
	_on_add_all_pressed()

func _consume_selected_booster_and_open() -> void:
	if _booster_open_in_progress:
		return
	_booster_open_in_progress = true
	_consume_selected_booster_and_open_internal()

func _consume_selected_booster_and_open_internal() -> void:
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	if selected_pack == null:
		_booster_open_in_progress = false
		return
	if not collection.remove_booster(selected_pack.pack_type, 1):
		_close_open_popup()
		_booster_open_in_progress = false
		return
	SaveSystem.save_collection(collection)
	_refresh_boosters()
	_booster_open_in_progress = false
	_reveal_open_pack_cards(selected_pack)

func _on_open_popup_preview_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _open_popup_mode != OpenPopupMode.PREVIEW:
		return
	accept_event()
	_advance_open_popup_preview()

func _advance_open_popup_preview() -> void:
	if selected_pack == null:
		return
	if _is_forest_booster_animation_enabled(selected_pack):
		_advance_forest_booster_popup_frame()
		return
	_consume_selected_booster_and_open()

func _advance_forest_booster_popup_frame() -> void:
	if selected_pack == null:
		return
	if not _is_forest_booster_animation_enabled(selected_pack):
		_consume_selected_booster_and_open()
		return
	var last_index: int = _forest_booster_frames.size() - 1
	if _forest_booster_popup_frame_index < last_index:
		_forest_booster_popup_frame_index += 1
		_update_forest_booster_popup_frame()
	if _forest_booster_popup_frame_index >= last_index:
		call_deferred("_consume_selected_booster_and_open")

func _is_forest_booster_animation_enabled(pack: PackView) -> bool:
	if pack == null:
		return false
	return pack.pack_type == "forest" and not _forest_booster_frames.is_empty()

func _update_open_popup_preview(pack: PackView) -> void:
	if open_popup_cards == null:
		return
	_clear_open_cards()
	if _is_forest_booster_animation_enabled(pack):
		_forest_booster_popup_frame_index = 0
		_ensure_open_popup_preview_texture()
		_update_forest_booster_popup_frame()
		return
	var color_preview := ColorRect.new()
	color_preview.name = "PackColorPreview"
	color_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_preview.color = pack.color
	color_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	color_preview.gui_input.connect(_on_open_popup_preview_gui_input)
	open_popup_cards.add_child(color_preview)

func _update_forest_booster_popup_frame() -> void:
	if open_popup_cards == null:
		return
	_ensure_open_popup_preview_texture()
	if _open_popup_preview_texture == null:
		return
	if _forest_booster_frames.is_empty():
		return
	var index: int = clampi(_forest_booster_popup_frame_index, 0, _forest_booster_frames.size() - 1)
	_open_popup_preview_texture.texture = _forest_booster_frames[index]

func _load_forest_booster_frames() -> void:
	_forest_booster_frames.clear()
	for i in range(1, FOREST_BOOSTER_FRAME_COUNT + 1):
		var texture_path := FOREST_BOOSTER_FRAME_PATH_FMT % i
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_warning("[Collection] Missing forest booster frame: " + texture_path)
			continue
		_forest_booster_frames.append(texture)

func _ensure_open_popup_preview_texture() -> void:
	if open_popup_cards == null:
		return
	if _open_popup_preview_texture != null:
		if not is_instance_valid(_open_popup_preview_texture) or _open_popup_preview_texture.is_queued_for_deletion():
			_open_popup_preview_texture = null
	if _open_popup_preview_texture == null:
		var existing := open_popup_cards.get_node_or_null("PackPreview") as TextureRect
		if existing != null and existing.is_queued_for_deletion():
			existing = null
		_open_popup_preview_texture = existing
	if _open_popup_preview_texture == null:
		_open_popup_preview_texture = TextureRect.new()
		_open_popup_preview_texture.name = "PackPreview"
		_open_popup_preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_open_popup_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_open_popup_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_open_popup_preview_texture.mouse_filter = Control.MOUSE_FILTER_STOP
		open_popup_cards.add_child(_open_popup_preview_texture)
	var preview_click_cb := Callable(self, "_on_open_popup_preview_gui_input")
	if not _open_popup_preview_texture.gui_input.is_connected(preview_click_cb):
		_open_popup_preview_texture.gui_input.connect(preview_click_cb)

func _set_open_popup_mode(mode: int, pack: PackView = null) -> void:
	_open_popup_mode = mode
	if mode != OpenPopupMode.PREVIEW:
		_stop_preview_auto_advance()
	var display_name := ""
	if pack != null:
		display_name = pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
	if open_popup_title:
		if display_name != "":
			open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE_NAME") % display_name
		else:
			open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE")
	if open_popup_add_all:
		open_popup_add_all.disabled = false
		if mode == OpenPopupMode.PREVIEW:
			open_popup_add_all.text = tr("COLLECTION_BOOSTER_OPEN")
		elif mode == OpenPopupMode.REVEAL:
			open_popup_add_all.text = tr("COLLECTION_OPEN_ADD_ALL")
		else:
			open_popup_add_all.text = tr("COLLECTION_BOOSTER_OPEN")

func _reveal_open_pack_cards(pack: PackView) -> void:
	if pack == null:
		return
	var pool := _get_pack_pool(pack.pack_type)
	if pool.is_empty():
		_close_open_popup()
		return
	_set_open_popup_mode(OpenPopupMode.REVEAL, pack)
	open_defs.clear()
	for i in range(OPEN_CARDS_PER_PACK):
		var card_def := pool[randi() % pool.size()]
		open_defs.append(card_def)
	call_deferred("_add_open_cards_visual", open_defs)

func _open_pack_popup(pack: PackView) -> void:
	if open_popup == null or open_popup_cards == null:
		return
	selected_pack = pack
	_forest_booster_popup_frame_index = 0
	_booster_open_in_progress = false
	open_popup.visible = true
	open_popup.z_index = 200
	open_popup.modulate.a = 0.0
	open_popup.scale = Vector2(0.95, 0.95)
	_update_book_input_block()
	open_collection = SaveSystem.load_collection()
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	_clear_open_cards()
	open_defs.clear()
	_set_open_popup_mode(OpenPopupMode.PREVIEW, pack)
	_update_open_popup_preview(pack)
	_play_open_popup_in()

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
		card.setup_from_definition(card_def, 0)
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
				card.accept_event()
				_on_open_card_clicked(card)
		)

func _on_open_card_clicked(card: CardView) -> void:
	var index := open_cards.find(card)
	if index < 0:
		return
	if open_cards.size() > 0 and card != open_cards[open_cards.size() - 1]:
		return
	var card_def := open_defs[index]
	var start_global := card.global_position
	var start_scale := _get_canvas_global_scale(card)
	_add_card_to_collection(card_def)
	open_cards.remove_at(index)
	open_defs.remove_at(index)
	card.queue_free()
	_fly_open_card_to_book(card_def, start_global, start_scale)
	if open_cards.is_empty():
		_close_open_popup()

func _add_card_to_collection(def: CardDefinition) -> String:
	if def == null:
		return ""
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	open_collection.add_type(def.definition_id, 1)
	SaveSystem.save_collection(open_collection)
	_refresh_boosters()
	_refresh_book_content()
	_go_to_card_page(def.definition_id)
	return def.definition_id

func _fly_open_card_to_book(def: CardDefinition, start_global: Vector2, start_scale: Vector2) -> void:
	if def == null:
		return
	call_deferred("_fly_open_card_to_book_deferred", def, start_global, start_scale)

func _fly_open_card_to_book_deferred(def: CardDefinition, start_global: Vector2, start_scale: Vector2) -> void:
	var book := _get_book()
	if book and book.is_animating:
		await _wait_for_book_idle()
	var slot := await _wait_for_visible_slot(def.definition_id)
	if slot == null:
		return
	var target := _get_slot_target(slot)
	if target.is_empty():
		return
	var fly := CARD_VIEW_SCENE.instantiate() as CardView
	if fly == null:
		return
	add_child(fly)
	fly.top_level = true
	fly.z_index = 500
	fly.custom_minimum_size = OPEN_CARD_BASE
	fly.size = OPEN_CARD_BASE
	fly.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fly.offset_left = 0.0
	fly.offset_top = 0.0
	fly.offset_right = OPEN_CARD_BASE.x
	fly.offset_bottom = OPEN_CARD_BASE.y
	var upgrade_level := 0
	if open_collection != null:
		upgrade_level = int(open_collection.upgrade_level.get(def.definition_id, 0))
	fly.setup_from_definition(def, _get_display_upgrade_level(def, upgrade_level))
	fly.show_front()
	fly.scale = start_scale
	fly.global_position = start_global
	_set_mouse_filter_recursive(fly, Control.MOUSE_FILTER_IGNORE)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly, "global_position", target["global_pos"], OPEN_CARD_FLY_DURATION)
	tween.parallel().tween_property(fly, "scale", target["scale"], OPEN_CARD_FLY_DURATION)
	tween.finished.connect(func() -> void:
		if is_instance_valid(fly):
			fly.queue_free()
	)

func _wait_for_book_idle() -> void:
	var book := _get_book()
	if book == null:
		return
	var start := Time.get_ticks_msec()
	while book.is_animating and (Time.get_ticks_msec() - start) < int(OPEN_CARD_FLY_MAX_WAIT * 1000.0):
		await get_tree().process_frame

func _wait_for_visible_slot(def_id: String) -> CollectionSlot:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) < int(OPEN_CARD_FLY_MAX_WAIT * 1000.0):
		var slot := _find_visible_slot_for_def(def_id)
		if slot != null:
			return slot
		await get_tree().process_frame
	return null

func _find_visible_slot_for_def(def_id: String) -> CollectionSlot:
	for node in get_tree().get_nodes_in_group("collection_slots"):
		if not (node is CollectionSlot):
			continue
		var slot := node as CollectionSlot
		if slot.current_def_id != def_id:
			continue
		if not slot.is_visible_in_tree():
			continue
		return slot
	return null

func _get_slot_target(slot: CollectionSlot) -> Dictionary:
	if slot == null:
		return {}
	var book: PageFlip2D = _get_book() as PageFlip2D
	var poly: Polygon2D = null
	if book != null:
		var slot_vp := slot.get_viewport()
		var left_vp := book.get_node_or_null("Viewports/Slots/Slot1")
		var right_vp := book.get_node_or_null("Viewports/Slots/Slot2")
		if slot_vp != null and left_vp != null and slot_vp == left_vp:
			poly = book.static_left
		elif slot_vp != null and right_vp != null and slot_vp == right_vp:
			poly = book.static_right

	var card_pos := slot.global_position
	var card_scale := Vector2.ONE
	if slot.card_view != null and slot.card_view.is_visible_in_tree():
		card_pos = slot.card_view.global_position
		card_scale = slot.card_view.scale

	var size_scaled := OPEN_CARD_BASE * card_scale
	if poly != null and book != null:
		var page_h := book.target_page_size.y
		var local_top_left := Vector2(card_pos.x, card_pos.y - (page_h * 0.5))
		var global_top_left := poly.to_global(local_top_left)
		var page_scale := _get_page_global_scale(book, poly)
		return {
			"global_pos": global_top_left,
			"scale": Vector2(card_scale.x * page_scale.x, card_scale.y * page_scale.y),
		}

	return {
		"global_pos": card_pos,
		"scale": card_scale,
	}

func _get_page_global_scale(book: PageFlip2D, poly: Polygon2D) -> Vector2:
	if book == null or poly == null:
		return Vector2.ONE
	var page_w := book.target_page_size.x
	var page_h := book.target_page_size.y
	if page_w <= 0.0 or page_h <= 0.0:
		return Vector2.ONE
	var p0 := poly.to_global(Vector2(0.0, -page_h * 0.5))
	var p1 := poly.to_global(Vector2(page_w, -page_h * 0.5))
	var p2 := poly.to_global(Vector2(0.0, page_h * 0.5))
	var scale_x := p0.distance_to(p1) / page_w
	var scale_y := p0.distance_to(p2) / page_h
	return Vector2(scale_x, scale_y)

func _get_canvas_global_scale(item: CanvasItem) -> Vector2:
	if item == null:
		return Vector2.ONE
	var xform := item.get_global_transform()
	return Vector2(xform.x.length(), xform.y.length())

func _open_card_popup(slot: CollectionSlot) -> void:
	if slot == null:
		return
	if slot.current_def_id == "":
		return
	if not slot.is_obtained:
		return
	var def: CardDefinition = CardDatabase.get_definition(slot.current_def_id)
	if def == null:
		return
	_popup_def = def
	open_collection = SaveSystem.load_collection()
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	_build_card_popup(def)
	card_popup.visible = true
	card_popup.z_index = 220
	_update_book_input_block()

func _build_card_popup(def: CardDefinition) -> void:
	if card_popup_container == null:
		return
	for child in card_popup_container.get_children():
		child.queue_free()
	var card := CARD_VIEW_SCENE.instantiate() as CardView
	if card == null:
		return
	card_popup_container.add_child(card)
	card.custom_minimum_size = OPEN_CARD_BASE
	card.size = OPEN_CARD_BASE
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = OPEN_CARD_BASE.x
	card.offset_bottom = OPEN_CARD_BASE.y
	var upgrade_level := 0
	if open_collection != null:
		upgrade_level = int(open_collection.upgrade_level.get(def.definition_id, 0))
	card.setup_from_definition(def, _get_display_upgrade_level(def, upgrade_level))
	card.show_front()
	_set_mouse_filter_recursive(card, Control.MOUSE_FILTER_IGNORE)
	var scale_w := 220.0 / OPEN_CARD_BASE.x
	var scale_h := 300.0 / OPEN_CARD_BASE.y
	var final_scale := minf(scale_w, scale_h)
	card.scale = Vector2(final_scale, final_scale)
	var scaled_size := OPEN_CARD_BASE * final_scale
	card.position = (card_popup_container.size * 0.5) - (scaled_size * 0.5)
	_update_card_popup_count()

func _update_card_popup_count() -> void:
	if _popup_def == null or card_popup_count == null or open_collection == null:
		return
	var count := open_collection.get_owned_count(_popup_def.definition_id)
	card_popup_count.text = "x%d" % count
	if card_popup_upgrade:
		card_popup_upgrade.disabled = count < 5

func _on_card_upgrade_pressed() -> void:
	if _popup_def == null:
		return
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	var count := open_collection.get_owned_count(_popup_def.definition_id)
	if count < 5:
		return
	open_collection.owned_count[_popup_def.definition_id] = max(0, count - 5)
	var current := int(open_collection.upgrade_level.get(_popup_def.definition_id, 0))
	open_collection.upgrade_level[_popup_def.definition_id] = current + 1
	SaveSystem.save_collection(open_collection)
	if RunState:
		RunState.refresh_upgrades_for_definition(_popup_def.definition_id)
	_build_card_popup(_popup_def)
	_refresh_book_content()

func _close_card_popup() -> void:
	if card_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(card_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		card_popup.visible = false
		card_popup.modulate.a = 1.0
		_update_book_input_block()
	)

func _on_add_all_pressed() -> void:
	if _open_popup_mode == OpenPopupMode.PREVIEW:
		_start_preview_auto_advance()
		return
	for def_item in open_defs.duplicate():
		var card_def := def_item as CardDefinition
		if card_def == null:
			continue
		_add_card_to_collection(card_def)
	_clear_open_cards()
	open_defs.clear()
	_close_open_popup()

func _clear_open_cards() -> void:
	if open_popup_cards != null:
		for child in open_popup_cards.get_children():
			child.queue_free()
	open_cards.clear()
	_open_popup_preview_texture = null

func _close_open_popup() -> void:
	if open_popup == null:
		return
	_stop_preview_auto_advance()
	_open_popup_mode = OpenPopupMode.NONE
	_booster_open_in_progress = false
	_forest_booster_popup_frame_index = 0
	selected_pack = null
	open_defs.clear()
	_clear_open_cards()
	var tween := create_tween()
	tween.tween_property(open_popup, "modulate:a", 0.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(0.98, 0.98), 0.15)
	tween.tween_callback(func():
		open_popup.visible = false
		open_popup.modulate.a = 1.0
		open_popup.scale = Vector2.ONE
		_refresh_boosters()
		_refresh_book_content()
		_update_book_input_block()
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

func _start_preview_auto_advance() -> void:
	if _open_popup_mode != OpenPopupMode.PREVIEW:
		return
	if selected_pack == null:
		return
	if _preview_auto_advance_active:
		return
	_preview_auto_advance_active = true
	_run_preview_auto_advance()

func _run_preview_auto_advance() -> void:
	while _preview_auto_advance_active:
		if _open_popup_mode != OpenPopupMode.PREVIEW:
			break
		if selected_pack == null:
			break
		_advance_open_popup_preview()
		if _open_popup_mode != OpenPopupMode.PREVIEW:
			break
		if _booster_open_in_progress:
			break
		if _is_forest_booster_animation_enabled(selected_pack):
			var last_index: int = _forest_booster_frames.size() - 1
			if _forest_booster_popup_frame_index >= last_index:
				break
		await get_tree().create_timer(BOOSTER_PREVIEW_AUTO_STEP_SEC).timeout
	_preview_auto_advance_active = false

func _stop_preview_auto_advance() -> void:
	_preview_auto_advance_active = false

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
	item.custom_minimum_size = PACK_STACK_ITEM_MIN_SIZE
	item.alignment = BoxContainer.ALIGNMENT_BEGIN
	booster_list.add_child(item)
	var label := Label.new()
	var display_name := pack.pack_type
	if pack.name_key != "":
		display_name = tr(pack.name_key)
	label.text = tr("COLLECTION_PACK_COUNT") % [display_name, count]
	item.add_child(label)
	var stack := Control.new()
	stack.custom_minimum_size = PACK_STACK_CONTAINER_MIN_SIZE
	stack.clip_contents = true
	item.add_child(stack)
	var visible_count: int = min(count, PACK_STACK_MAX)
	var forest_preview: Texture2D = null
	if pack.pack_type == "forest" and not _forest_booster_frames.is_empty():
		forest_preview = _forest_booster_frames[0]
	for i in range(visible_count):
		var preview_slot := Control.new()
		preview_slot.custom_minimum_size = PACK_PREVIEW_SIZE
		preview_slot.size = PACK_PREVIEW_SIZE
		preview_slot.clip_contents = true
		preview_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		preview_slot.position = Vector2(PACK_STACK_OFFSET_X * float(i), PACK_STACK_OFFSET_Y * float(i))
		if forest_preview != null:
			var tex := TextureRect.new()
			tex.texture = forest_preview
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_slot.add_child(tex)
		else:
			var rect := ColorRect.new()
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rect.color = pack.color
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_slot.add_child(rect)
		preview_slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_booster_popup(pack)
		)
		stack.add_child(preview_slot)

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

func _get_display_upgrade_level(def: CardDefinition, base_upgrade: int) -> int:
	if def == null:
		return base_upgrade
	if def.card_type != "hero":
		return base_upgrade
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return base_upgrade
	var progression: HeroProgression = profile.get_or_create_progression(StringName(def.definition_id))
	return base_upgrade + max(0, progression.level - 1)

func _get_ordered_def_ids() -> Array[String]:
	var hero_ids: Array[String] = []
	var forest_ids: Array[String] = []
	var dark_forest_ids: Array[String] = []
	var other_ids: Array[String] = []
	var seen_ids: Dictionary = {}

	for def_id in CardDatabase.definitions.keys():
		var def: CardDefinition = CardDatabase.get_definition(String(def_id))
		if def == null:
			continue
		if def.definition_id == "" or seen_ids.has(def.definition_id):
			continue
		seen_ids[def.definition_id] = true
		if def.card_type == "hero":
			hero_ids.append(def.definition_id)
		elif def.biome_modifier == BIOME_FOREST:
			forest_ids.append(def.definition_id)
		elif def.biome_modifier == BIOME_DARK_FOREST:
			dark_forest_ids.append(def.definition_id)
		else:
			other_ids.append(def.definition_id)

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

func _go_to_card_page(definition_id: String) -> void:
	if definition_id == "":
		return
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var book_node := _get_book()
	if book_node == null:
		return
	var book_page := book_node as PageFlip2D
	if book_page == null:
		return
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var types: Array[String] = []
	var order := _get_ordered_def_ids()
	var all_ids: Array[String] = []
	var seen_ids: Dictionary = {}
	for def_key in CardDatabase.definitions.keys():
		var def: CardDefinition = CardDatabase.get_definition(String(def_key))
		if def == null:
			continue
		var def_id := String(def.definition_id)
		if def_id == "" or seen_ids.has(def_id):
			continue
		seen_ids[def_id] = true
		all_ids.append(def_id)
	types = _sort_ids_by_order(all_ids, order)
	if types.is_empty():
		return
	var slots_per_page: int = 9
	if book_view != null:
		var exported_value: Variant = book_view.get("slots_per_page")
		if typeof(exported_value) == TYPE_INT:
			var override_pages: int = exported_value as int
			if override_pages > 0:
				slots_per_page = override_pages
	for i in range(types.size()):
		var def_id := String(types[i])
		if def_id == definition_id:
			var page_index := int(i / max(1, slots_per_page))
			var target_page := page_index + 1
			book_page.call("go_to_page", target_page, PageFlip2D.JumpTarget.CONTENT_PAGE)
			return
