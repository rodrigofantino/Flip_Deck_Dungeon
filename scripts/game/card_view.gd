extends Control
class_name CardView

# =========================
# NODOS VISUALES
# =========================

@onready var front: Control = $Front
@onready var back: Control = $Back

@onready var art: TextureRect = $Front/Art
@onready var name_label: Label = $Front/Name
@onready var description_label: Label = $Front/Description
@onready var front_frame: TextureRect = $Front/FrontFrame

@onready var level_label: Label = $Front/Stats/LevelLabel
@onready var initiative_label: Label = $Front/Stats/PowerLabel
@onready var hp_label: Label = $Front/Stats/HPLabel
@onready var damage_label: Label = $Front/Stats/DamageLabel
@onready var heal_effect: AnimatedSprite2D = $Front/Stats/HealEffect
@onready var holo_light: PointLight2D = $Front/Node2D/PointLight2D
@onready var holo_light_2: PointLight2D = get_node_or_null("Front/Node2D/PointLight2D2")
@onready var holo_light_3: PointLight2D = get_node_or_null("Front/Node2D/PointLight2D3")
@onready var foil_layer: Control = $FoilLayer
@onready var motion_tilt: Control = $MotionTiltDriver

@export var display_name: String
@export var description: String
@export var heal_effect_offset: Vector2 = Vector2(0, 0)

const FLIP_SFX_PATH: String = "res://audio/sfx/card_flip.mp3"
const FLIP_SFX_BUS: String = "SFX"
const HOLO_AREA_X_MIN: float = 0.0
const HOLO_AREA_X_MAX: float = 1.0
const HOLO_AREA_Y_MIN: float = 0.5
const HOLO_AREA_Y_MAX: float = 1.0
const HOLO_TARGET_MIN_TIME: float = 0.80
const HOLO_TARGET_MAX_TIME: float = 1.90
const HOLO_MOVE_SPEED: float = 4

# ==========================================
# IDENTIDAD DE LA CARTA (RunManager)
# ==========================================

var card_id: String = ""
var flip_sfx: AudioStreamPlayer = null
var run_manager: RunManager = null
var trait_overlay: TraitOverlayView = null
var _is_boss_card: bool = false
var _holo_states: Array[HoloState] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _holo_enabled: bool = true
var _holo_light_mask: int = 0

const MAX_HOLO_LIGHT_MASK_BITS: int = 20
static var _light_mask_pool: Array[int] = []
static var _next_light_mask_bit: int = 0
static var _light_cull_property: String = ""
static var _light_cull_property_checked: bool = false

class HoloState:
	var light: PointLight2D = null
	var tex: GradientTexture2D = null
	var pos: Vector2 = Vector2(0.0, 0.5)
	var target: Vector2 = Vector2(0.0, 0.5)
	var target_time_remaining: float = 0.0

# =========================
# INIT
# =========================

func _ready() -> void:
	_setup_flip_sfx()
	if not is_in_group("card_view"):
		add_to_group("card_view")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_rng.seed = Time.get_ticks_usec() + int(get_instance_id())
	_holo_init()
	_assign_holo_light_mask()
	_apply_holo_enabled()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _exit_tree() -> void:
	_release_holo_light_mask()

func _process(delta: float) -> void:
	if _holo_states.is_empty():
		return
	holo_animation(delta)

func _setup_flip_sfx() -> void:
	if flip_sfx != null:
		return
	flip_sfx = AudioStreamPlayer.new()
	flip_sfx.name = "FlipSfx"
	flip_sfx.stream = load(FLIP_SFX_PATH)
	flip_sfx.bus = FLIP_SFX_BUS
	add_child(flip_sfx)

func _apply_holo_enabled() -> void:
	var enabled := _holo_enabled
	if foil_layer:
		foil_layer.visible = enabled
	if motion_tilt:
		motion_tilt.visible = enabled
	_set_holo_lights_visible(enabled)
	set_process(enabled and not _holo_states.is_empty())

func _set_holo_lights_visible(enabled: bool) -> void:
	if holo_light:
		holo_light.visible = enabled
	if holo_light_2:
		holo_light_2.visible = enabled
	if holo_light_3:
		holo_light_3.visible = enabled

func _assign_holo_light_mask() -> void:
	if _holo_light_mask != 0:
		return
	if _get_light_cull_property(holo_light) == "":
		return
	if _light_mask_pool.is_empty():
		if _next_light_mask_bit < MAX_HOLO_LIGHT_MASK_BITS:
			_holo_light_mask = 1 << _next_light_mask_bit
			_next_light_mask_bit += 1
	else:
		_holo_light_mask = _light_mask_pool.pop_back()
	if _holo_light_mask != 0:
		_set_light_mask_recursive(self, _holo_light_mask)
		_apply_light_cull_mask(_holo_light_mask)
	else:
		_apply_light_cull_mask(0)

func _release_holo_light_mask() -> void:
	if _holo_light_mask == 0:
		return
	_light_mask_pool.append(_holo_light_mask)
	_holo_light_mask = 0

func _apply_light_cull_mask(mask: int) -> void:
	var prop := _get_light_cull_property(holo_light)
	if prop == "":
		return
	if holo_light:
		holo_light.set(prop, mask)
	if holo_light_2:
		holo_light_2.set(prop, mask)
	if holo_light_3:
		holo_light_3.set(prop, mask)

func _get_light_cull_property(light: Light2D) -> String:
	if _light_cull_property_checked:
		return _light_cull_property
	_light_cull_property_checked = true
	if light == null:
		return ""
	for info in light.get_property_list():
		var name := String(info.get("name", ""))
		if name == "item_cull_mask" or name == "range_item_cull_mask":
			_light_cull_property = name
			break
	return _light_cull_property

func _set_light_mask_recursive(node: Node, mask: int) -> void:
	if node is CanvasItem and not (node is Light2D):
		(node as CanvasItem).light_mask = mask
	for child in node.get_children():
		_set_light_mask_recursive(child, mask)

# =========================
# SETUP (ESTÃTICO)
# =========================

func setup_from_definition(definition: CardDefinition, upgrade_level: int = 0) -> void:
	if definition == null:
		return
	_is_boss_card = false

	_fit_art(Vector2(200, 120))
	_refresh_all_labels(definition, upgrade_level)

	if definition.art:
		art.texture = definition.art
	if definition.frame_texture and front_frame:
		front_frame.texture = definition.frame_texture

func setup_from_boss_definition(definition: BossDefinition) -> void:
	if definition == null:
		return
	_is_boss_card = true

	_fit_art(Vector2(200, 120))
	_refresh_boss_labels(definition)

	if definition.art:
		art.texture = definition.art
	if definition.frame_texture and front_frame:
		front_frame.texture = definition.frame_texture

func set_holo_enabled(enabled: bool) -> void:
	_holo_enabled = enabled
	_apply_holo_enabled()

func apply_display_overrides(
	display_level: int,
	display_hp: int,
	display_damage: int,
	display_initiative: int
) -> void:
	_fit_label_text(
		level_label,
		"%d" % display_level,
		10
	)

	_fit_label_text(
		initiative_label,
		"%s %d" % [tr("CARD_VIEW_STATS_POWER"), display_initiative],
		10
	)

	_fit_label_text(
		hp_label,
		"%s %d" % [tr("CARD_VIEW_STATS_HP"), display_hp],
		10
	)

	_fit_label_text(
		damage_label,
		"%s %d" % [tr("CARD_VIEW_STATS_DAMAGE"), display_damage],
		10
	)

# =========================
# REFRESH DESDE RUNTIME (TRAITS / COMBATE)
# =========================

func refresh(data: Dictionary) -> void:
	if data.is_empty():
		return

	# =========================
	# LEVEL
	# =========================
	if data.has("level"):
		level_label.text = "%d" % int(data.level)

	# =========================
	# HP (MAX + CURRENT)
	# =========================
	if data.has("max_hp") and data.has("current_hp"):
		hp_label.text = "%s %d / %d" % [
			tr("CARD_VIEW_STATS_HP"),
			int(data.current_hp),
			int(data.max_hp)
		]

	# =========================
	# DAMAGE
	# =========================
	if data.has("damage"):
		damage_label.text = "%s %d" % [
			tr("CARD_VIEW_STATS_DAMAGE"),
			int(data.damage)
		]

	# =========================
	# INITIATIVE
	# =========================
	if data.has("initiative"):
		initiative_label.text = "%s %d" % [
			tr("CARD_VIEW_STATS_POWER"),
			int(data.initiative)
		]


# =========================
# HEAL EFFECT
# =========================

func play_heal_effect() -> void:
	if heal_effect == null or hp_label == null:
		return

	var text: String = hp_label.text
	var slash_idx: int = text.find("/")
	if slash_idx < 0:
		slash_idx = text.length()

	var before_slash: String = text.substr(0, slash_idx).strip_edges()
	var last_space: int = before_slash.rfind(" ")
	var prefix: String = before_slash.substr(0, max(0, last_space + 1))
	var current_value: String = before_slash.substr(max(0, last_space + 1))

	var font: Font = hp_label.get_theme_font("font")
	var font_size: int = hp_label.get_theme_font_size("font_size")
	var prefix_w := 0.0
	var current_w := 0.0
	var full_w := 0.0
	if font != null and font_size > 0:
		prefix_w = font.get_string_size(prefix, font_size).x
		current_w = font.get_string_size(current_value, font_size).x
		full_w = font.get_string_size(text, font_size).x

	var hp_pos: Vector2 = hp_label.position
	var text_offset_x := 0.0
	if full_w > 0.0:
		text_offset_x = (hp_label.size.x - full_w) * 0.5
	var center_x: float = hp_pos.x + text_offset_x + prefix_w + (current_w * 0.5)
	var center_y: float = hp_pos.y + (hp_label.size.y * 0.5) + heal_effect_offset.y
	heal_effect.position = Vector2(center_x, center_y)
	heal_effect.scale = Vector2(2.0, 2.0)
	heal_effect.visible = true
	heal_effect.frame = 0
	heal_effect.process_mode = Node.PROCESS_MODE_ALWAYS
	heal_effect.play("default")

func stop_heal_effect() -> void:
	if heal_effect == null:
		return
	heal_effect.stop()
	heal_effect.visible = false


# =========================
# PIVOT
# =========================

func update_pivot_to_center() -> void:
	pivot_offset = size * 0.5

# =========================
# VISIBILIDAD
# =========================

func show_front() -> void:
	front.visible = true
	back.visible = false

func show_back() -> void:
	front.visible = false
	back.visible = true

# =========================
# FLIP (SIN WARP)
# =========================

func flip_to_front() -> void:
	show_back()
	update_pivot_to_center()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(self, "scale:x", 0.0, 0.15)
	tween.tween_callback(Callable(self, "_play_flip_sfx"))
	tween.tween_callback(show_front)
	tween.tween_property(self, "scale:x", scale.x, 0.15)

func _play_flip_sfx() -> void:
	if flip_sfx == null:
		return
	if flip_sfx.playing:
		flip_sfx.stop()
	flip_sfx.play()

# =========================
# TRAIT OVERLAY
# =========================

func _on_mouse_entered() -> void:
	if trait_overlay == null or run_manager == null:
		return
	var data: Dictionary = run_manager.get_card(card_id)
	if data.is_empty():
		return
	var traits: Array[TraitResource] = []
	if card_id == "th":
		traits = run_manager.get_active_hero_traits()
	elif bool(data.get("is_boss", false)) or data.has("boss_id"):
		traits = run_manager.get_boss_traits_for_card(data)
	else:
		return
	if traits.is_empty():
		return
	trait_overlay.show_for_traits(traits, get_global_rect())

func _on_mouse_exited() -> void:
	if trait_overlay == null:
		return
	trait_overlay.hide_overlay()

# =========================
# HOLO ANIMATION
# =========================

func holo_animation(delta: float) -> void:
	for state in _holo_states:
		if state.tex == null:
			continue
		state.target_time_remaining = max(0.0, state.target_time_remaining - delta)
		if state.target_time_remaining <= 0.0:
			_pick_holo_target(state)

		var to_target: Vector2 = state.target - state.pos
		var alpha: float = 1.0 - exp(-delta * HOLO_MOVE_SPEED)
		state.pos += to_target * alpha

		var new_from: Vector2 = state.tex.fill_from
		new_from.x = state.pos.x
		new_from.y = state.pos.y
		state.tex.fill_from = new_from

func _holo_init() -> void:
	_holo_states.clear()
	_try_add_holo_light(holo_light)
	_try_add_holo_light(holo_light_2)
	_try_add_holo_light(holo_light_3)

func _try_add_holo_light(light: PointLight2D) -> void:
	if light == null:
		return
	var tex := light.texture
	if tex == null or not (tex is GradientTexture2D):
		return
	var state := HoloState.new()
	state.light = light
	state.tex = tex as GradientTexture2D

	var start: Vector2 = state.tex.fill_from
	var start_x: float = clamp(start.x, HOLO_AREA_X_MIN, HOLO_AREA_X_MAX)
	var start_y: float = clamp(start.y, HOLO_AREA_Y_MIN, HOLO_AREA_Y_MAX)
	state.pos = Vector2(start_x, start_y)
	state.target = state.pos
	state.target_time_remaining = 0.0
	_pick_holo_target(state)

	_holo_states.append(state)

func _pick_holo_target(state: HoloState) -> void:
	var candidate: Vector2 = state.pos
	for i in range(3):
		candidate = Vector2(
			_rng.randf_range(HOLO_AREA_X_MIN, HOLO_AREA_X_MAX),
			_rng.randf_range(HOLO_AREA_Y_MIN, HOLO_AREA_Y_MAX)
		)
		if candidate.distance_to(state.pos) >= 0.05:
			break
	state.target = candidate
	state.target_time_remaining = _rng.randf_range(HOLO_TARGET_MIN_TIME, HOLO_TARGET_MAX_TIME)


# =========================
# ARTE
# =========================

func _fit_art(max_size: Vector2) -> void:
	if art == null or art.texture == null:
		return

	var tex_size: Vector2 = art.texture.get_size()
	if tex_size == Vector2.ZERO:
		return

	var scale_factor: float = min(
		max_size.x / tex_size.x,
		max_size.y / tex_size.y
	)

	art.scale = Vector2(scale_factor, scale_factor)

# ==========================================
# AJUSTE AUTOMÃTICO DE TEXTO
# ==========================================

func _fit_label_text(
	label: Label,
	text: String,
	min_font_size: int
) -> void:
	label.text = text

	var font: Font = label.get_theme_font("font")
	if font == null:
		push_error("Label sin fuente asignada")
		return

	var available_size: Vector2 = label.size
	var base_size: int = label.get_theme_font_size("font_size")
	if base_size <= 0:
		base_size = 16

	for size in range(base_size, min_font_size - 1, -1):
		label.add_theme_font_size_override("font_size", size)

		var text_size: Vector2 = font.get_multiline_string_size(
			text,
			label.horizontal_alignment,
			available_size.x,
			size
		)

		if text_size.y <= available_size.y:
			return

func _refresh_all_labels(definition: CardDefinition, upgrade_level: int) -> void:
	var upgrade_mult: float = _get_upgrade_multiplier(definition, upgrade_level)
	var display_level: int = definition.level + max(0, upgrade_level)
	var display_hp: int = int(round(float(definition.max_hp) * upgrade_mult))
	var display_damage: int = int(round(float(definition.damage) * upgrade_mult))
	var display_initiative: int = int(round(float(definition.initiative) * upgrade_mult))

	_fit_label_text(
		name_label,
		tr(definition.display_name),
		12
	)

	_fit_label_text(
		description_label,
		tr(definition.description),
		10
	)

	_fit_label_text(
		level_label,
		"%d" % display_level,
		10
	)

	_fit_label_text(
		initiative_label,
		"%s %d" % [tr("CARD_VIEW_STATS_POWER"), display_initiative],
		10
	)

	_fit_label_text(
		hp_label,
		"%s %d" % [tr("CARD_VIEW_STATS_HP"), display_hp],
		10
	)

	_fit_label_text(
		damage_label,
		"%s %d" % [tr("CARD_VIEW_STATS_DAMAGE"), display_damage],
		10
	)

func _refresh_boss_labels(definition: BossDefinition) -> void:
	_fit_label_text(
		name_label,
		definition.boss_name,
		12
	)

	_fit_label_text(
		description_label,
		"",
		10
	)

	_fit_label_text(
		level_label,
		"%d" % int(definition.base_level),
		10
	)

	_fit_label_text(
		initiative_label,
		"%s %d" % [tr("CARD_VIEW_STATS_POWER"), int(definition.base_initiative)],
		10
	)

	_fit_label_text(
		hp_label,
		"%s %d" % [tr("CARD_VIEW_STATS_HP"), int(definition.base_max_hp)],
		10
	)

	_fit_label_text(
		damage_label,
		"%s %d" % [tr("CARD_VIEW_STATS_DAMAGE"), int(definition.base_damage)],
		10
	)

func _get_upgrade_multiplier(definition: CardDefinition, upgrade_level: int) -> float:
	if definition == null or upgrade_level <= 0:
		return 1.0
	var base_mult: float = 1.0
	if definition.card_type == "hero":
		base_mult = RunState.HERO_LEVEL_UP_STAT_MULT
	elif definition.card_type == "enemy":
		base_mult = RunState.ENEMY_LEVEL_UP_STAT_MULT
	return pow(base_mult, upgrade_level)
