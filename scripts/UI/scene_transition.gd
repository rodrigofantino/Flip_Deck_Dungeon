extends CanvasLayer

@export var fade_duration: float = 0.2
@export var fade_color: Color = Color(0, 0, 0, 1)
@export var static_effects_scene_path: String = "res://Scenes/shaders_and_particles/static_effects.tscn"

var _rect: ColorRect
var _tween: Tween
var _busy: bool = false
var _queued_path: String = ""
var _fire: Sprite2D
var _pulse_tween: Tween
var _base_fire_scale: Vector2 = Vector2.ONE
var _last_click_pos: Vector2 = Vector2.ZERO
var _has_click_pos: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	layer = 1000
	_rect = ColorRect.new()
	_rect.color = fade_color
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.visible = false
	_rect.modulate.a = 0.0
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.size = get_viewport().get_visible_rect().size
	add_child(_rect)
	_init_loading_fx()
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	if _rect == null:
		return
	_rect.size = get_viewport().get_visible_rect().size
	_update_fire_position_for_viewport()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_last_click_pos = event.position
		_has_click_pos = true

func _init_loading_fx() -> void:
	if not ResourceLoader.exists(static_effects_scene_path):
		return
	var packed := load(static_effects_scene_path) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	if root == null:
		return
	var fire := root.get_node_or_null("StaticFire") as Sprite2D
	if fire == null:
		root.queue_free()
		return
	root.remove_child(fire)
	add_child(fire)
	root.queue_free()
	fire.visible = false
	fire.modulate.a = 0.0
	fire.position = Vector2.ZERO
	_fire = fire
	_base_fire_scale = fire.scale
	_center_loading_fx()

func _center_loading_fx() -> void:
	if _fire == null:
		return
	var size := get_viewport().get_visible_rect().size
	_fire.position = size * 0.5

func _update_fire_position_for_viewport() -> void:
	if _fire == null:
		return
	var size := get_viewport().get_visible_rect().size
	if not _has_click_pos:
		_fire.position = size * 0.5
		return
	_fire.position = _clamp_to_viewport(_last_click_pos, size)

func _get_spawn_pos() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	if _has_click_pos:
		return _clamp_to_viewport(_last_click_pos, size)
	return size * 0.5

func _clamp_to_viewport(pos: Vector2, size: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, 0.0, size.x),
		clampf(pos.y, 0.0, size.y)
	)

func _start_pulse() -> void:
	if _fire == null:
		return
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()
	_fire.scale = _base_fire_scale
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_fire, "scale", _base_fire_scale * 1.08, 0.35)
	_pulse_tween.tween_property(_fire, "scale", _base_fire_scale * 0.92, 0.35)

func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

func change_scene(path: String) -> Error:
	if path.strip_edges() == "":
		return ERR_INVALID_PARAMETER
	if not ResourceLoader.exists(path):
		return ERR_DOES_NOT_EXIST
	_start_transition(path)
	return OK

func _start_transition(path: String) -> void:
	if _busy:
		_queued_path = path
		return
	_busy = true
	_queued_path = ""
	if _fire != null:
		_fire.position = _get_spawn_pos()
		_fire.visible = true
		_fire.modulate.a = 0.0
		_start_pulse()
	_rect.visible = true
	_rect.modulate.a = 0.0
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	if _fire != null:
		_tween.parallel().tween_property(_fire, "modulate:a", 1.0, fade_duration)
	_tween.tween_property(_rect, "modulate:a", 1.0, fade_duration)
	_tween.tween_callback(func() -> void:
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			push_error("[SceneTransition] change_scene_to_file failed: %s" % str(err))
	)
	if _fire != null:
		_tween.parallel().tween_property(_fire, "modulate:a", 0.0, fade_duration)
	_tween.tween_property(_rect, "modulate:a", 0.0, fade_duration)
	_tween.tween_callback(func() -> void:
		_rect.visible = false
		if _fire != null:
			_fire.visible = false
			_stop_pulse()
		_busy = false
		if _queued_path != "":
			var next := _queued_path
			_queued_path = ""
			_start_transition(next)
	)
