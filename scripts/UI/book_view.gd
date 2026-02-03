extends Control

@export var fit_height_ratio: float = 0.6
@export var closed_bottom_margin: float = 50.0
@export var closed_scale: float = 0.25
@export var slots_per_page: int = 9
@export var edge_click_ratio: float = 0.18
@export var edge_click_band_px: float = 200.0
@export var edge_click_vertical_margin_px: float = 16.0
@export var close_center_duration: float = 0.25
@export var open_center_duration: float = 0.45
@export var open_scale_multiplier: float = 1.0
@export var closed_scale_multiplier: float = 0.75
@export var open_center_offset: Vector2 = Vector2.ZERO : set = _set_open_center_offset
@export var closed_front_offset: Vector2 = Vector2.ZERO : set = _set_closed_front_offset
@export var closed_back_offset: Vector2 = Vector2.ZERO : set = _set_closed_back_offset
@export var debug_book: bool = false
@export var perspective_top_inset_px: float = 30.0
@export var perspective_top_drop_px: float = 28.0
@export var perspective_top_tilt_px: float = 12.0
@export var perspective_transition_duration: float = 0.35
@export var supported_transition_duration: float = 0.35
@export var supported: bool = true
@export var perspective_debug_print: bool = false
@export var permitir_flip: bool = false

@onready var book: PageFlip2D = $Book
var _resize_version: int = 0
var _center_tween: Tween = null
var _pending_open: bool = false
var _base_scale: Vector2 = Vector2.ONE

enum BookPerspectiveState {
	CLOSED,
	OPEN,
	OPENING,
	CLOSING,
}

var _visual_state: int = BookPerspectiveState.CLOSED
var _rest_blend: float = 0.0
var _rest_tween: Tween = null
var _deform_targets: Array = []
var _was_animating: bool = false
var _supported_internal: bool = true
var _sort_reference_vertices: PackedVector2Array = PackedVector2Array()
var _last_logged_rest_blend: float = -1.0

func _enter_tree() -> void:
	var node := get_node_or_null("Book")
	if node and node is CanvasItem:
		(node as CanvasItem).visible = false

func _ready() -> void:
	_configure_book()
	_ensure_input_enabled()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	_hide_visuals_until_ready()
	call_deferred("_initial_layout")
	if book.anim_player:
		book.anim_player.animation_finished.connect(func(_name: String) -> void:
			_apply_book_position_on_state_change()
		)
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_on_viewport_resized)
	resized.connect(_on_container_resized)
	call_deferred("_cache_deform_targets")
	call_deferred("_initialize_perspective_state")
	set_process(true)

func _configure_book() -> void:
	book.start_option = PageFlip2D.StartOption.CLOSED_FROM_FRONT
	book.start_page = 2
	book.close_condition = PageFlip2D.CloseCondition.NEVER
	book.blank_page_color = Color(0.88, 0.88, 0.88, 1.0)
	book.enable_composite_pages = true
	book.target_page_size = Vector2(900, 1000)
	book.closed_skew = 0.0
	book.closed_rotation = 0.0
	book.closed_scale = Vector2.ONE
	book.open_scale = Vector2.ONE
	book.call("_apply_new_size")
	book.center_on_owner = false
	book.ignore_camera_for_center = true
	book.lock_container_position = true
	if book.visuals_container:
		book.visuals_container.position = Vector2.ZERO
	var cam := book.get_node_or_null("Camera2D")
	if cam:
		var camera := cam as Camera2D
		camera.enabled = false
		camera.zoom = Vector2.ONE
	book.tex_cover_front_out = preload("res://assets/card_book/card_book_cover_front.png")
	book.tex_cover_front_in = preload("res://assets/card_book/card_book_inside.png")
	book.tex_cover_back_in = preload("res://assets/card_book/card_book_inside.png")
	book.tex_cover_back_out = preload("res://assets/card_book/card_book_cover_back.png")
	book.flip_mirror_enabled = false
	_prepare_collection_pages()
	_tune_page_curvature()

func _prepare_collection_pages() -> void:
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
	_ensure_visual_deform_targets()
	call_deferred("_cache_deform_targets")

func _refresh_book_content() -> void:
	_prepare_collection_pages()
	_restore_page_interaction()

func _restore_page_interaction() -> void:
	if book == null:
		return
	if book.is_animating:
		return
	if not book.is_book_open:
		return
	if book.has_method("_check_scene_activation"):
		book.call("_check_scene_activation")

func _ensure_visual_deform_targets() -> void:
	if not book:
		return
	var visual := book.get_node_or_null("Visual")
	if visual == null:
		return
	var targets := {
		"StaticPageLeft": "front",
		"StaticPageRight": "back"
	}
	for name in targets.keys():
		var node := visual.get_node_or_null(name)
		if node and node is Polygon2D:
			_set_deform_metadata(node as Polygon2D, targets[name])

func _set_deform_metadata(target: Polygon2D, side: String) -> void:
	if not target:
		return
	if not target.is_in_group("book_deform_target"):
		target.add_to_group("book_deform_target")
	if not target.has_meta("book_side"):
		target.set_meta("book_side", side)

func _tune_page_curvature() -> void:
	if book.dynamic_poly == null:
		return
	if book.dynamic_poly is DynamicPage:
		var dyn := book.dynamic_poly as DynamicPage
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
	var view_h := size.y
	if view_h > 0.0:
		var scale := (view_h * fit_height_ratio) / base_h
		_base_scale = Vector2(scale, scale)
		book.scale = _base_scale * closed_scale_multiplier

func _apply_book_position(ignore_anim: bool = false) -> void:
	if book and book.is_animating:
		if not ignore_anim:
			return
	var view := size
	var container_scale := book.closed_scale if not book.is_book_open else book.open_scale
	if container_scale == Vector2.ZERO:
		container_scale = Vector2.ONE
	var effective_scale := Vector2(book.scale.x * container_scale.x, book.scale.y * container_scale.y)
	var page_w := book.target_page_size.x * effective_scale.x
	var book_open_w := page_w * 2.0
	var page_h := book.target_page_size.y * effective_scale.y
	if book.is_book_open:
		# Open: spine centered on screen, pages centered vertically.
		book.position = _get_open_center_target()
	else:
		# Closed (front): keep the cover centered horizontally and resting near bottom.
		book.position = _get_closed_center_target()
	_dbg("apply_pos")

func _get_page_count() -> int:
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var total := collection.get_all_types().size()
	if not RunState.selection_pending:
		total = CardDatabase.definitions.size()
	return int(ceili(float(total) / float(slots_per_page)))

func _apply_book_position_on_state_change() -> void:
	if book == null:
		return
	if book.is_animating:
		return
	if book.is_book_open:
		_animate_to_open(open_center_duration)
	else:
		_animate_to_closed(close_center_duration)
	_enable_page_inputs()

func _hide_visuals_until_ready() -> void:
	if book.visuals_container:
		book.visuals_container.visible = false
	call_deferred("_show_visuals_deferred")

func _show_visuals_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_force_visibility()

func force_show() -> void:
	if book.visuals_container:
		book.visuals_container.visible = true

func _ensure_input_enabled() -> void:
	if book:
		book.set_process_unhandled_input(false)
		book.set_process_input(true)
		_enable_page_inputs()

func _enable_page_inputs() -> void:
	if book == null:
		return
	if book.has_method("_pageflip_set_input_enabled"):
		book.call("_pageflip_set_input_enabled", false)

func _recenter_book_internal() -> void:
	if book and book.is_animating:
		return
	_apply_book_position(true)
	_dbg("recenter_internal")

func _unhandled_input(event: InputEvent) -> void:
	if book == null:
		return
	if not permitir_flip:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vc := book.visuals_container
		if vc == null:
			return
		var local_x := _get_local_x_over_book(event.global_position)
		var page_w := _get_page_width_scaled()
		var edge_band := maxf(page_w * edge_click_ratio, edge_click_band_px)
		var in_edge_any := _is_in_edge_band(local_x, event.global_position, page_w, edge_band)
		if not in_edge_any and not _is_point_over_book(event.global_position):
			_dbg("click_outside")
			return
		if book.is_book_open:
			var left_edge := -page_w
			var right_edge := page_w
			var in_edge := _is_in_edge_band(local_x, event.global_position, page_w, edge_band)
			if not in_edge:
				if book.has_method("is_pointer_over_page_control_with_event") and book.call("is_pointer_over_page_control_with_event", event):
					# Let CardViews handle clicks when not on edge.
					get_viewport().set_input_as_handled()
					return
			if _is_point_over_card_view(event.global_position):
				get_viewport().set_input_as_handled()
				return
			if local_x >= right_edge - edge_band:
				_dbg("click_open_right_edge")
				if _will_close_to_back():
					_animate_to_center(close_center_duration, false, true)
				book.next_page()
				get_viewport().set_input_as_handled()
			elif local_x <= left_edge + edge_band:
				_dbg("click_open_left_edge")
				if _will_close_to_front():
					_animate_to_center(close_center_duration, false, false)
				book.prev_page()
				get_viewport().set_input_as_handled()
			else:
				_dbg("click_open_center")
		else:
			# Ensure the open animation starts from center.
			_animate_to_open(open_center_duration)
			_dbg("click_open_center")
			# Closed: click right side to open forward, left side to open backward.
			var in_edge := _is_in_edge_band(local_x, event.global_position, page_w, edge_band)
			if not in_edge:
				if book.has_method("is_pointer_over_page_control_with_event") and book.call("is_pointer_over_page_control_with_event", event):
					get_viewport().set_input_as_handled()
					return
			var is_back := _is_back_closed()
			if is_back:
				# Back cover visible: cover spans [-page_w, 0], outer edge is at -page_w.
				if local_x <= -page_w + edge_band:
					_dbg("click_closed_back_edge")
					_start_open_after_centering(false)
					get_viewport().set_input_as_handled()
					_dbg("click_prev")
				else:
					_dbg("click_closed_back_center")
			else:
				# Front cover visible: cover spans [0, page_w], outer edge is at page_w.
				if local_x >= page_w - edge_band:
					_dbg("click_closed_front_edge")
					_start_open_after_centering(true)
					get_viewport().set_input_as_handled()
					_dbg("click_next")
				else:
					_dbg("click_closed_front_center")

func _get_open_center(view: Vector2) -> Vector2:
	return Vector2(view.x * 0.5, view.y * 0.5)

func _get_page_width_scaled() -> float:
	var vc := book.visuals_container
	if vc == null:
		return book.target_page_size.x
	var container_scale := vc.scale
	if container_scale == Vector2.ZERO:
		container_scale = Vector2.ONE
	return book.target_page_size.x * book.scale.x * container_scale.x

func _get_page_height_scaled() -> float:
	var vc := book.visuals_container
	if vc == null:
		return book.target_page_size.y
	var container_scale := vc.scale
	if container_scale == Vector2.ZERO:
		container_scale = Vector2.ONE
	return book.target_page_size.y * book.scale.y * container_scale.y

func _get_local_x_over_book(global_pos: Vector2) -> float:
	var vc := book.visuals_container
	if vc == null:
		return 0.0
	return vc.to_local(global_pos).x

func _is_in_edge_band(local_x: float, global_pos: Vector2, page_w: float, edge_band: float) -> bool:
	var vc := book.visuals_container
	if vc == null:
		return false
	var local := vc.to_local(global_pos)
	var page_h := _get_page_height_scaled()
	var half_h := page_h * 0.5
	var in_y := local.y >= (-half_h + edge_click_vertical_margin_px) and local.y <= (half_h - edge_click_vertical_margin_px)
	if not in_y:
		return false
	return (local_x >= page_w - edge_band) or (local_x <= -page_w + edge_band)

func _is_point_over_book(global_pos: Vector2) -> bool:
	var vc := book.visuals_container
	if vc == null:
		return false
	var page_w := _get_page_width_scaled()
	var book_open_w := page_w * 2.0
	var page_h := _get_page_height_scaled()
	var local := vc.to_local(global_pos)
	var min_x: float
	var max_x: float
	if book.is_book_open:
		min_x = -(book_open_w * 0.5)
		max_x = (book_open_w * 0.5)
	else:
		var is_back := _is_back_closed()
		if is_back:
			min_x = -page_w
			max_x = 0.0
		else:
			min_x = 0.0
			max_x = page_w
	var min_y := -(page_h * 0.5)
	var max_y := (page_h * 0.5)
	return local.x >= min_x and local.x <= max_x and local.y >= min_y and local.y <= max_y

func _is_point_over_card_view(global_pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("card_view"):
		if not node is CardView:
			continue
		var ctrl := node as CardView
		if not ctrl.is_visible_in_tree():
			continue
		if ctrl.get_global_rect().has_point(global_pos):
			return true
	return false

func _is_back_closed() -> bool:
	if book == null:
		return false
	return (not book.is_book_open) and (book.current_spread == book.total_spreads)

func _will_close_to_back() -> bool:
	if book == null:
		return false
	return book.is_book_open and book.current_spread >= (book.total_spreads - 1)

func _will_close_to_front() -> bool:
	if book == null:
		return false
	return book.is_book_open and book.current_spread <= 0

func _apply_closed_position(is_back: bool) -> void:
	var view := size
	var container_scale := book.closed_scale
	if container_scale == Vector2.ZERO:
		container_scale = Vector2.ONE
	var effective_scale := Vector2(book.scale.x * container_scale.x, book.scale.y * container_scale.y)
	var page_w := book.target_page_size.x * effective_scale.x
	var page_h := book.target_page_size.y * effective_scale.y
	book.position = _get_closed_center_target()

func _animate_to_center(duration: float, open_target: bool, is_back: bool) -> Tween:
	if book == null:
		return null
	if _center_tween and _center_tween.is_running():
		_center_tween.kill()
	var target := _get_open_center_target() if open_target else _get_closed_center_target()
	_dbg("center_tween_start")
	_center_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_center_tween.tween_property(book, "position", target, maxf(0.05, duration))
	return _center_tween

func _start_open_after_centering(go_next: bool) -> void:
	if book == null or _pending_open:
		return
	_pending_open = true
	_dbg("start_open_centering")
	var tween := _animate_to_open(open_center_duration)
	if tween == null:
		_pending_open = false
		return
	tween.finished.connect(func() -> void:
		_dbg("open_centered")
		_pending_open = false
		if book == null:
			return
		if go_next:
			book.next_page()
		else:
			book.prev_page()
	)

func _get_open_center_target() -> Vector2:
	return _get_local_center() + open_center_offset

func _get_closed_center_target() -> Vector2:
	# Absolute closed target; do not depend on scale to avoid warp.
	var base := _get_local_center()
	var is_back := _is_back_closed()
	var offset := closed_back_offset if is_back else closed_front_offset
	return base + offset

func _animate_to_open(duration: float) -> Tween:
	if book == null:
		return null
	if _center_tween and _center_tween.is_running():
		_center_tween.kill()
	var target_pos := _get_open_center_target()
	var target_scale := _base_scale * open_scale_multiplier
	_center_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_center_tween.tween_property(book, "position", target_pos, maxf(0.05, duration))
	_center_tween.parallel().tween_property(book, "scale", target_scale, maxf(0.05, duration))
	return _center_tween

func _animate_to_closed(duration: float) -> Tween:
	if book == null:
		return null
	if _center_tween and _center_tween.is_running():
		_center_tween.kill()
	var target_pos := _get_closed_center_target()
	var target_scale := _base_scale * closed_scale_multiplier
	_center_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_center_tween.tween_property(book, "position", target_pos, maxf(0.05, duration))
	_center_tween.parallel().tween_property(book, "scale", target_scale, maxf(0.05, duration))
	return _center_tween

func _dbg(tag: String) -> void:
	if not debug_book:
		return
	var vc := book.visuals_container
	var vc_pos := vc.global_position if vc else Vector2.ZERO
	var view := size
	var book_global := book.global_position if book else Vector2.ZERO
	var rect := get_global_rect()
	print("[BookView] ", tag, " open=", book.is_book_open, " view=", view,
		" book_scale=", book.scale, " closed_scale=", book.closed_scale, " open_scale=", book.open_scale,
		" open_offset=", open_center_offset, " closed_front=", closed_front_offset, " closed_back=", closed_back_offset, " book_pos=", book.position, " book_global=", book_global,
		" rect_pos=", rect.position, " rect_size=", rect.size,
		" vc_pos=", vc_pos, " vc_visible=", vc.visible if vc else false, " book_visible=", book.visible)

func _get_local_center() -> Vector2:
	return size * 0.5

func _on_viewport_resized() -> void:
	_resize_version += 1
	var version := _resize_version
	_dbg("viewport_resized")
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if version != _resize_version:
			return
		call_deferred("_apply_book_scale")
		call_deferred("_apply_book_position", true)
		call_deferred("_recenter_book_internal")
		call_deferred("_force_visibility")
	)

func _on_container_resized() -> void:
	_on_viewport_resized()

func _force_visibility() -> void:
	if book:
		book.visible = true
	if book.visuals_container:
		book.visuals_container.visible = true

func _process(_delta: float) -> void:
	if book == null:
		return
	if supported != _supported_internal:
		_supported_internal = supported
		_update_supported_target()
	_update_book_state()
	_apply_deformations()

func _update_book_state() -> void:
	var animating := book.is_animating
	if animating and not _was_animating:
		_on_book_animation_started()
	elif not animating and _was_animating:
		_on_book_animation_finished()
	_was_animating = animating
	if not animating:
		var desired := BookPerspectiveState.OPEN if book.is_book_open else BookPerspectiveState.CLOSED
		if _visual_state != desired:
			_set_visual_state(desired)

func _on_book_animation_started() -> void:
	var target := BookPerspectiveState.OPENING if book.is_book_open else BookPerspectiveState.CLOSING
	_set_visual_state(target)

func _on_book_animation_finished() -> void:
	var final_state := BookPerspectiveState.OPEN if book.is_book_open else BookPerspectiveState.CLOSED
	_set_visual_state(final_state)

func _set_visual_state(state: int) -> void:
	if _visual_state == state:
		return
	_visual_state = state
	match state:
		BookPerspectiveState.OPEN:
			_set_rest_blend(0.0, 0.0, true)
		BookPerspectiveState.OPENING:
			_set_rest_blend(0.0, perspective_transition_duration, false)
		BookPerspectiveState.CLOSING:
			var target := 1.0 if _supported_internal else 0.0
			_set_rest_blend(target, supported_transition_duration, false)
		BookPerspectiveState.CLOSED:
			var target := 1.0 if _supported_internal else 0.0
			_set_rest_blend(target, supported_transition_duration, false)

func _set_rest_blend(target: float, duration: float, immediate: bool) -> void:
	target = clamp(target, 0.0, 1.0)
	if immediate or duration <= 0.0:
		_rest_blend = target
		if _rest_tween:
			_rest_tween.kill()
		_log_perspective_state()
		return
	if _rest_tween and _rest_tween.is_running():
		_rest_tween.kill()
	_rest_tween = create_tween()
	_rest_tween.tween_property(self, "_rest_blend", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_log_perspective_state()

func _update_supported_target() -> void:
	if _visual_state in [BookPerspectiveState.CLOSING, BookPerspectiveState.CLOSED]:
		var target := 1.0 if _supported_internal else 0.0
		_set_rest_blend(target, supported_transition_duration, false)

func _cache_deform_targets() -> void:
	_deform_targets.clear()
	print("[Perspective] caching deform targets")
	for node in get_tree().get_nodes_in_group("book_deform_target"):
		if not book or not book.is_ancestor_of(node):
			continue
		if not node is Polygon2D:
			continue
		var poly := node as Polygon2D
		var base := poly.polygon.duplicate()
		if base.size() < 4:
			continue
		var top_indices := _get_top_vertex_indices(base, poly)
		if top_indices.size() < 2:
			continue
		_sort_indices_by_x(top_indices, base)
		var tl_idx := int(top_indices[0])
		var tr_idx := int(top_indices[1])
		var side := _determine_target_side(node)
		_deform_targets.append({
			"node": poly,
			"base": base,
			"top_left_idx": tl_idx,
			"top_right_idx": tr_idx,
			"side": side,
		})
	print("[Perspective] cached targets count:", _deform_targets.size())

func _initialize_perspective_state() -> void:
	_visual_state = BookPerspectiveState.OPEN if book and book.is_book_open else BookPerspectiveState.CLOSED
	_supported_internal = supported
	_rest_blend = 0.0 if _visual_state == BookPerspectiveState.OPEN else (1.0 if _supported_internal else 0.0)
	_apply_deformations()

func _apply_deformations() -> void:
	if _deform_targets.size() == 0:
		return
	var effective_inset := perspective_top_inset_px * _rest_blend
	var effective_drop := perspective_top_drop_px * _rest_blend
	var effective_tilt := perspective_top_tilt_px * _rest_blend
	if perspective_debug_print:
		var message := "[Perspective] blend=%.3f inset=%.1f drop=%.1f tilt=%.1f" % [_rest_blend, effective_inset, effective_drop, effective_tilt]
		print(message)
	for info in _deform_targets:
		_apply_supported_deform(info, effective_inset, effective_drop, effective_tilt)

func _apply_supported_deform(info: Dictionary, effective_inset: float, effective_drop: float, effective_tilt: float) -> void:
	var base := info["base"] as PackedVector2Array
	var nodes := (info["node"] as Polygon2D)
	var vertices := base.duplicate()
	var tl_idx := int(info["top_left_idx"])
	var tr_idx := int(info["top_right_idx"])
	var side := str(info["side"])
	var top_left := vertices[tl_idx]
	var top_right := vertices[tr_idx]
	if perspective_debug_print:
		print("[Perspective] before deform (%s) top L=%s R=%s" % [side, top_left, top_right])
	top_left.y += effective_drop
	top_right.y += effective_drop
	if side == "front":
		top_right.y += effective_tilt
		top_right.x -= effective_inset
	elif side == "back":
		top_left.y += effective_tilt
		top_left.x += effective_inset
	if perspective_debug_print:
		print("[Perspective] after deform (%s) top L=%s R=%s inset=%.1f drop=%.1f tilt=%.1f" % [side, top_left, top_right, effective_inset, effective_drop, effective_tilt])
	vertices[tl_idx] = top_left
	vertices[tr_idx] = top_right
	nodes.polygon = vertices

func _log_perspective_state() -> void:
	if not perspective_debug_print:
		return
	if abs(_rest_blend - _last_logged_rest_blend) < 0.001:
		return
	_last_logged_rest_blend = _rest_blend
	var status := ""
	match _visual_state:
		BookPerspectiveState.OPEN:
			status = "OPEN"
		BookPerspectiveState.OPENING:
			status = "OPENING"
		BookPerspectiveState.CLOSING:
			status = "CLOSING"
		BookPerspectiveState.CLOSED:
			status = "CLOSED"
	print("[Perspective State] %s blend=%.3f" % [status, _rest_blend])

func _determine_target_side(node: Node) -> String:
	var meta_side := ""
	if node.has_meta("book_side"):
		meta_side = str(node.get_meta("book_side")).to_lower()
	if meta_side in ["front", "back"]:
		return meta_side
	var ln := node.name.to_lower()
	if ln.find("right") != -1 or ln.find("back") != -1:
		return "back"
	return "front"

func _get_top_vertex_indices(base: PackedVector2Array, node: CanvasItem) -> Array:
	if base.size() == 0:
		return []
	var first_global: Vector2 = node.to_global(base[0])
	var min_y: float = first_global.y
	for i in range(base.size()):
		var global_y: float = node.to_global(base[i]).y
		min_y = min(min_y, global_y)
	var threshold: float = max(1.0, abs(min_y) * 0.01)
	var results: Array = []
	for i in range(base.size()):
		var global_y: float = node.to_global(base[i]).y
		if abs(global_y - min_y) <= threshold:
			results.append(i)
	return results

func _sort_indices_by_x(indices: Array, base: PackedVector2Array) -> void:
	if indices.size() <= 1:
		return
	_sort_reference_vertices = base
	var compare_ref := Callable(self, "_compare_vertex_x")
	indices.sort_custom(compare_ref)
	_sort_reference_vertices = PackedVector2Array()

func _compare_vertex_x(a: int, b: int) -> int:
	var va := _sort_reference_vertices[a]
	var vb := _sort_reference_vertices[b]
	if va.x < vb.x:
		return -1
	if va.x > vb.x:
		return 1
	return 0

func _set_open_center_offset(value: Vector2) -> void:
	open_center_offset = value
	if not is_inside_tree():
		return
	if book and book.is_animating:
		return
	_apply_book_position()

func _set_closed_front_offset(value: Vector2) -> void:
	closed_front_offset = value
	if not is_inside_tree():
		return
	if book and book.is_animating:
		return
	_apply_book_position()

func _set_closed_back_offset(value: Vector2) -> void:
	closed_back_offset = value
	if not is_inside_tree():
		return
	if book and book.is_animating:
		return
	_apply_book_position()

func _initial_layout() -> void:
	# Wait until the Control has a valid size to avoid a 1-frame giant book.
	if size == Vector2.ZERO:
		await get_tree().process_frame
		call_deferred("_initial_layout")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_book_scale()
	_apply_book_position(true)
	_force_visibility()
	_apply_saved_offsets()
	_dbg("initial_layout")

func _apply_saved_offsets() -> void:
	_set_open_center_offset(open_center_offset)
	_set_closed_front_offset(closed_front_offset)
	_set_closed_back_offset(closed_back_offset)
