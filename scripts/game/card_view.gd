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

@export var display_name: String
@export var description: String
@export var heal_effect_offset: Vector2 = Vector2(0, 0)

const FLIP_SFX_PATH: String = "res://audio/sfx/card_flip.mp3"
const FLIP_SFX_BUS: String = "SFX"

# ==========================================
# IDENTIDAD DE LA CARTA (RunManager)
# ==========================================

var card_id: String = ""
var flip_sfx: AudioStreamPlayer = null

# =========================
# INIT
# =========================

func _ready() -> void:
	_setup_flip_sfx()

func _setup_flip_sfx() -> void:
	if flip_sfx != null:
		return
	flip_sfx = AudioStreamPlayer.new()
	flip_sfx.name = "FlipSfx"
	flip_sfx.stream = load(FLIP_SFX_PATH)
	flip_sfx.bus = FLIP_SFX_BUS
	add_child(flip_sfx)

# =========================
# SETUP (ESTÁTICO)
# =========================

func setup_from_definition(definition: CardDefinition) -> void:
	if definition == null:
		return

	_fit_art(Vector2(200, 120))
	_refresh_all_labels(definition)

	if definition.art:
		art.texture = definition.art
	if definition.frame_texture and front_frame:
		front_frame.texture = definition.frame_texture

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
# AJUSTE AUTOMÁTICO DE TEXTO
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

func _refresh_all_labels(definition: CardDefinition) -> void:
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
		"%d" % definition.level,
		10
	)

	_fit_label_text(
		initiative_label,
		"%s %d" % [tr("CARD_VIEW_STATS_POWER"), definition.initiative],
		10
	)

	_fit_label_text(
		hp_label,
		"%s %d" % [tr("CARD_VIEW_STATS_HP"), definition.max_hp],
		10
	)

	_fit_label_text(
		damage_label,
		"%s %d" % [tr("CARD_VIEW_STATS_DAMAGE"), definition.damage],
		10
	)
