extends Node2D

@export var use_collection_cards: bool = true
@export var slots_per_page: int = 9
@export var desired_page_height: float = 880.0
@export var table_scale: float = 1.05
@export var fixed_zoom: float = 0.5
@export var fit_height_ratio: float = 0.75
@export var closed_bottom_margin: float = 50.0

@onready var book: PageFlip2D = $Book
@onready var back_button: Button = $CanvasLayer/UI/BackButton

var _last_open_state: bool = true

func _ready() -> void:
	book.visible = true
	if book.visuals_container:
		book.visuals_container.visible = false
	_configure_book()
	_wire_ui()
	_apply_book_scale()
	_apply_book_position()
	call_deferred("_apply_book_scale")
	call_deferred("_apply_book_position")
	call_deferred("_deferred_show_book")
	if book.anim_player:
		book.anim_player.animation_finished.connect(func(_name: String) -> void:
			_apply_book_position_on_state_change()
		)
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(func() -> void:
			call_deferred("_apply_book_scale")
			call_deferred("_apply_book_position")
		)

func _configure_book() -> void:
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

	var page_count := _get_page_count()
	if page_count <= 0:
		page_count = 1

	var page_scene_path := "res://Scenes/ui/collection_page.tscn"
	book.pages_paths.clear()
	for i in range(page_count):
		book.pages_paths.append(page_scene_path)
	book.call("_prepare_book_content")
	book.call("_update_static_visuals_immediate")
	book.call("_update_volume_visuals")
	_apply_book_scale()
	_tune_page_curvature()

func _tune_page_curvature() -> void:
	if book == null:
		return
	var page := book.dynamic_poly
	if page == null:
		return
	if page is DynamicPage:
		var dyn := page as DynamicPage
		dyn.animation_preset = DynamicPage.PagePreset.CUSTOM
		dyn.subdivision_x = 10
		dyn.subdivision_y = 6
		dyn.paper_stiffness = 1.3
		dyn.lift_bend = -22.0
		dyn.land_bend = -12.0
		dyn.curl_mode = DynamicPage.CurlMode.TOP_CORNER_FIRST
		dyn.curl_lag = 0.8
		dyn.rebuild(book.target_page_size)

func _apply_book_scale() -> void:
	var base_h := book.target_page_size.y
	if base_h <= 0.0:
		return
	book.scale = Vector2.ONE
	var cam := book.get_node_or_null("Camera2D")
	if not cam:
		return
	var camera := cam as Camera2D
	camera.make_current()
	var view_size := _get_viewport_size()
	var view_h := view_size.y
	if view_h <= 0.0:
		camera.zoom = Vector2(fixed_zoom, fixed_zoom)
		return
	var total_book_h := book.target_page_size.y
	var zoom := (view_h * fit_height_ratio) / total_book_h
	camera.zoom = Vector2(zoom, zoom)

func _apply_book_position() -> void:
	if book == null:
		return
	var vc := book.visuals_container
	if vc == null:
		return
	var view := _get_viewport_size()
	var half_width := book.target_page_size.x * 0.5
	if book.is_book_open:
		vc.global_position = Vector2(view.x * 0.5 - half_width, view.y * 0.5)
	else:
		var y := view.y - closed_bottom_margin - (book.target_page_size.y * 0.5)
		vc.global_position = Vector2(view.x * 0.5 - half_width, y)
		vc.skew = 0.0
		vc.rotation = 0.0

func _get_viewport_size() -> Vector2:
	var vp := get_viewport()
	if not vp:
		return Vector2.ZERO
	var visible := vp.get_visible_rect().size
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

func _get_page_count() -> int:
	if not use_collection_cards:
		return 1
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var total := collection.get_all_cards().size()
	return int(ceili(float(total) / float(slots_per_page)))

func _wire_ui() -> void:
	back_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
	)



