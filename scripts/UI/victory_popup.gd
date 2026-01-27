extends Control
class_name VictoryPopup

# README (Victory Popup)
# - Call show_victory(gold_earned: int) to open the popup and start VFX.
# - The popup only displays the gold you pass in; it does not compute it.
# - Tweak intensity in VictoryVFXController (burst counts, max particles).

signal back_to_menu_pressed

@onready var panel: Control = $Panel
@onready var title_label: RichTextLabel = $Panel/VBoxContainer/Label
@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var back_button: Button = $Panel/VBoxContainer/Button

var vfx: VictoryVFXController = null
var gold_target: int = 0
var gold_count_tween: Tween = null
var gold_shine_container: Control = null
var gold_shine_band: ColorRect = null
var gold_shine_tween: Tween = null
const GOLD_COUNT_DURATION: float = 5.0
const TITLE_COLOR_INTERVAL: float = 0.18
const TITLE_BREATHE_SCALE: float = 1.03

var title_timer: Timer = null
var title_breathe_tween: Tween = null
var title_text: String = ""
var title_palette: Array[Color] = []
var title_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if title_label:
		title_label.bbcode_enabled = true
		title_label.fit_content = true
		title_label.text = ""
		title_text = tr("VICTORY_POPUP_LABEL")
		title_rng.randomize()
		_build_title_palette()
		_update_title_colors()
		_start_title_color_loop()
		_start_title_breathe()
	if gold_label:
		_apply_gold_style()
		gold_label.text = _format_gold_line(0)
		_setup_gold_shine()
	if back_button:
		back_button.process_mode = Node.PROCESS_MODE_ALWAYS
		back_button.text = tr("VICTORY_POPUP_BUTTON_BACK")
		back_button.pressed.connect(_on_back_pressed)

func show_victory(gold_earned: int) -> void:
	visible = true
	gold_target = max(0, gold_earned)

	_set_initial_ui_state()
	await get_tree().process_frame

	var safe_rect := _compute_safe_rect()
	var title_rect := _get_title_rect()
	var gold_rect := _get_gold_rect()
	_layout_title_breathe()
	_layout_gold_shine()
	_start_gold_shine_loop()
	_start_vfx(safe_rect, title_rect, gold_rect)
	_play_ui_intro()

func show_popup() -> void:
	show_victory(RunState.gold)

func _set_initial_ui_state() -> void:
	if panel:
		panel.scale = Vector2(0.9, 0.9)
		panel.modulate.a = 0.0
	if gold_label:
		gold_label.modulate.a = 0.0
		gold_label.scale = Vector2(0.95, 0.95)
		gold_label.text = _format_gold_line(0)
	if gold_shine_band:
		gold_shine_band.modulate.a = 0.0

func _play_ui_intro() -> void:
	if panel == null:
		return
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35).set_delay(0.15)
	tween.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.18).set_delay(0.15)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.14)

func _on_gold_flourish() -> void:
	_play_gold_pop_in()
	_start_gold_count_up()
	if vfx != null:
		vfx.play_gold_stream(GOLD_COUNT_DURATION)

func _play_gold_pop_in() -> void:
	if gold_label == null:
		return
	var tween := create_tween()
	tween.tween_property(gold_label, "modulate:a", 1.0, 0.18)
	tween.tween_property(gold_label, "scale", Vector2(1.02, 1.02), 0.14)
	tween.tween_property(gold_label, "scale", Vector2(1.0, 1.0), 0.10)

func _start_gold_count_up() -> void:
	if gold_label == null:
		return
	if gold_count_tween != null and gold_count_tween.is_running():
		gold_count_tween.kill()

	var duration := GOLD_COUNT_DURATION
	gold_count_tween = create_tween()
	gold_count_tween.tween_method(
		Callable(self, "_set_gold_count_display"),
		0,
		gold_target,
		duration
	)

func _set_gold_count_display(value: float) -> void:
	if gold_label:
		gold_label.text = _format_gold_line(int(round(value)))

func _start_vfx(safe_rect: Rect2, title_rect: Rect2, gold_rect: Rect2) -> void:
	if vfx != null:
		vfx.stop_and_cleanup()
		vfx.queue_free()
		vfx = null

	vfx = VictoryVFXController.new()
	add_child(vfx)
	move_child(vfx, 0)
	vfx.z_index = 300
	vfx.process_mode = Node.PROCESS_MODE_ALWAYS
	vfx.configure(safe_rect, title_rect, gold_rect)
	vfx.gold_flourish.connect(_on_gold_flourish)
	vfx.play_intro_timeline()

func _compute_safe_rect() -> Rect2:
	var rects: Array[Rect2] = []
	if title_label:
		rects.append(title_label.get_global_rect())
	if gold_label:
		rects.append(gold_label.get_global_rect())
	if back_button:
		rects.append(back_button.get_global_rect())
	if rects.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var combined := rects[0]
	for i in range(1, rects.size()):
		combined = combined.merge(rects[i])
	combined = combined.grow(12.0)
	return _to_local_rect(combined)

func _get_title_rect() -> Rect2:
	if title_label == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return _to_local_rect(title_label.get_global_rect())

func _get_gold_rect() -> Rect2:
	if gold_label == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return _to_local_rect(gold_label.get_global_rect())

func _to_local_rect(global_rect: Rect2) -> Rect2:
	var local_pos := global_rect.position - global_position
	return Rect2(local_pos, global_rect.size)

func _format_gold_line(value: int) -> String:
	return tr("VICTORY_POPUP_GOLD_LINE") % value

func _apply_gold_shader() -> void:
	if gold_label == null:
		return
	var shader_code := """
shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float base = tex.a;
	float shimmer = 0.5 + 0.5 * sin(TIME * 2.6 + UV.x * 10.0);
	vec3 gold_a = vec3(0.85, 0.64, 0.16);
	vec3 gold_b = vec3(1.0, 0.88, 0.38);
	vec3 color = mix(gold_a, gold_b, shimmer);
	COLOR = vec4(color, base);
}
"""
	var shader := Shader.new()
	shader.code = shader_code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	gold_label.material = mat

func _on_back_pressed() -> void:
	if vfx != null:
		vfx.stop_and_cleanup()
		vfx.queue_free()
		vfx = null
	_stop_gold_shine()
	_stop_title_fx()
	print("BACK BUTTON PRESSED")
	emit_signal("back_to_menu_pressed")

func _apply_gold_style() -> void:
	if gold_label == null:
		return
	gold_label.modulate = Color(1.0, 0.9, 0.35, 1.0)

func _setup_gold_shine() -> void:
	if gold_label == null:
		return
	gold_shine_container = Control.new()
	gold_shine_container.clip_contents = true
	gold_shine_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent_node := gold_label.get_parent()
	if parent_node:
		parent_node.add_child(gold_shine_container)
		parent_node.move_child(gold_shine_container, parent_node.get_child_count() - 1)
	gold_shine_band = ColorRect.new()
	gold_shine_band.color = Color(1.0, 0.95, 0.7, 1.0)
	gold_shine_band.rotation = -0.35
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float dist = abs(UV.x - 0.5) * 2.0;
	float alpha = smoothstep(1.0, 0.0, dist);
	COLOR = vec4(1.0, 0.95, 0.6, alpha * 0.6);
}
"""
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	gold_shine_band.material = shader_mat
	gold_shine_container.add_child(gold_shine_band)

func _layout_gold_shine() -> void:
	if gold_label == null or gold_shine_container == null or gold_shine_band == null:
		return
	gold_shine_container.position = gold_label.position
	gold_shine_container.size = gold_label.size
	gold_shine_container.z_index = gold_label.z_index + 2
	var band_w: float = max(24.0, gold_label.size.x * 0.35)
	gold_shine_band.size = Vector2(band_w, gold_label.size.y * 2.0)
	gold_shine_band.pivot_offset = gold_shine_band.size * 0.5
	gold_shine_band.position = Vector2(-gold_shine_band.size.x, -gold_label.size.y * 0.5)

func _start_gold_shine_loop() -> void:
	if gold_shine_band == null or gold_shine_container == null:
		return
	_stop_gold_shine()
	gold_shine_band.modulate.a = 0.0
	var tween := create_tween().set_loops()
	tween.tween_property(gold_shine_band, "modulate:a", 0.7, 0.2)
	tween.tween_property(
		gold_shine_band,
		"position",
		Vector2(gold_shine_container.size.x + gold_shine_band.size.x, -gold_label.size.y * 0.5),
		1.6
	)
	tween.tween_property(gold_shine_band, "modulate:a", 0.0, 0.2)
	tween.tween_property(
		gold_shine_band,
		"position",
		Vector2(-gold_shine_band.size.x, -gold_label.size.y * 0.5),
		0.1
	)
	gold_shine_tween = tween

func _stop_gold_shine() -> void:
	if gold_shine_tween != null and gold_shine_tween.is_running():
		gold_shine_tween.kill()
	gold_shine_tween = null

func _layout_title_breathe() -> void:
	if title_label == null:
		return
	title_label.pivot_offset = title_label.size * 0.5

func _build_title_palette() -> void:
	title_palette.clear()
	title_palette.append(Color(0.96, 0.37, 0.39, 1.0))
	title_palette.append(Color(0.98, 0.78, 0.26, 1.0))
	title_palette.append(Color(0.36, 0.75, 0.55, 1.0))
	title_palette.append(Color(0.30, 0.55, 0.90, 1.0))
	title_palette.append(Color(0.90, 0.50, 0.90, 1.0))

func _start_title_color_loop() -> void:
	if title_timer == null:
		title_timer = Timer.new()
		title_timer.one_shot = false
		add_child(title_timer)
		title_timer.timeout.connect(_update_title_colors)
	title_timer.wait_time = TITLE_COLOR_INTERVAL
	title_timer.start()

func _start_title_breathe() -> void:
	if title_label == null:
		return
	if title_breathe_tween != null and title_breathe_tween.is_running():
		title_breathe_tween.kill()
	title_breathe_tween = create_tween().set_loops()
	title_breathe_tween.tween_property(title_label, "scale", Vector2(TITLE_BREATHE_SCALE, TITLE_BREATHE_SCALE), 0.9)
	title_breathe_tween.tween_property(title_label, "scale", Vector2.ONE, 0.9)

func _stop_title_fx() -> void:
	if title_timer != null:
		title_timer.stop()
		title_timer.queue_free()
		title_timer = null
	if title_breathe_tween != null and title_breathe_tween.is_running():
		title_breathe_tween.kill()
	title_breathe_tween = null

func _update_title_colors() -> void:
	if title_label == null:
		return
	if title_text == "":
		return
	var bb: String = ""
	for i in range(title_text.length()):
		var ch := title_text[i]
		if ch == " ":
			bb += " "
			continue
		var color := title_palette[title_rng.randi_range(0, title_palette.size() - 1)]
		bb += "[color=#%s]%s[/color]" % [color.to_html(false), ch]
	title_label.text = bb
