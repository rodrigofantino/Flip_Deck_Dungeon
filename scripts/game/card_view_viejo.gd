extends Control
class_name CardView_viejo

# =========================
# NODOS VISUALES
# =========================

@onready var front: Control = $Front
@onready var back: Control = $Back

@onready var art: TextureRect = $Front/Art
@onready var name_label: Label = $Front/Name
@onready var description_label: Label = $Front/Description

@onready var level_label: Label = $Front/Stats/LevelLabel
@onready var power_label: Label = $Front/Stats/PowerLabel
@onready var hp_label: Label = $Front/Stats/HPLabel
@onready var damage_label: Label = $Front/Stats/DamageLabel

@export var display_name: String
@export var description: String

# ==========================================
# IDENTIDAD DE LA CARTA (RunManager)
# ==========================================

var card_id: String = ""

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

# =========================
# REFRESH DESDE RUNTIME (TRAITS / COMBATE)
# =========================

func refresh_from_runtime(data: Dictionary) -> void:
	if data.is_empty():
		return

	# =========================
	# LEVEL
	# =========================
	if data.has("level"):
		level_label.text = "%s %d" % [
			tr("CARD_VIEW_STATS_LEVEL"),
			int(data.level)
		]

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
	tween.tween_callback(show_front)
	tween.tween_property(self, "scale:x", scale.x, 0.15)

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
	max_font_size: int,
	min_font_size: int
) -> void:
	label.text = text

	var font: Font = label.get_theme_font("font")
	if font == null:
		push_error("Label sin fuente asignada")
		return

	var available_size: Vector2 = label.size

	for size in range(max_font_size, min_font_size - 1, -1):
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
		22,
		12
	)

	_fit_label_text(
		description_label,
		tr(definition.description),
		18,
		10
	)

	_fit_label_text(
		level_label,
		"%s %d" % [tr("CARD_VIEW_STATS_LEVEL"), definition.level],
		16,
		10
	)

	_fit_label_text(
		power_label,
		"%s %d" % [tr("CARD_VIEW_STATS_POWER"), definition.power],
		16,
		10
	)

	_fit_label_text(
		hp_label,
		"%s %d" % [tr("CARD_VIEW_STATS_HP"), definition.max_hp],
		16,
		10
	)

	_fit_label_text(
		damage_label,
		"%s %d" % [tr("CARD_VIEW_STATS_DAMAGE"), definition.damage],
		16,
		10
	)

# =========================
# ACTUALIZACIÓN DE STATS (UI)
# =========================

func update_hp(current_hp: int) -> void:
	hp_label.text = "%s %d" % [
		tr("CARD_VIEW_STATS_HP"),
		current_hp
	]

func update_damage(damage: int) -> void:
	damage_label.text = "%s %d" % [
		tr("CARD_VIEW_STATS_DAMAGE"),
		damage
	]
