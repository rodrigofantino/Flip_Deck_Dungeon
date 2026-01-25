extends Control

# ==========================================
# NODOS DE LA ESCENA
# ==========================================

@onready var hero_level_label: Label = $HBoxContainer/HeroLevelLabel
@onready var xp_bar: ProgressBar = $HBoxContainer/XPBar
@onready var current_label: Label = $HBoxContainer/XPCurrentLabel
@onready var next_label: Label = $HBoxContainer/XPNextLabel

# ==========================================
# CICLO DE VIDA
# ==========================================

func _ready() -> void:
	# Escuchar progresión del héroe
	RunState.hero_xp_changed.connect(_on_hero_xp_changed)
	RunState.hero_level_up.connect(_on_hero_level_up)

	# Inicializar valores visuales
	_update_hero_level(RunState.hero_level)
	_on_hero_xp_changed(RunState.hero_xp, RunState.xp_to_next_level)

# ==========================================
# ACTUALIZACIONES VISUALES
# ==========================================

###########################
# XP DEL HÉROE
###########################
func _on_hero_xp_changed(current_xp: int, xp_to_next: int) -> void:
	var percent: float = float(current_xp) / float(xp_to_next) * 100.0

	xp_bar.value = percent

	current_label.text = tr("XP_HUD_XP_CURRENT").format({
		"value": current_xp
	})

	next_label.text = tr("XP_HUD_XP_NEXT").format({
		"value": xp_to_next
	})

	print("[XPHUD] XP:", current_xp, "/", xp_to_next)

###########################
# NIVEL DEL HÉROE
###########################
func _on_hero_level_up(new_level: int) -> void:
	_update_hero_level(new_level)

	print("[XPHUD] LEVEL UP →", new_level)

func _update_hero_level(level: int) -> void:
	hero_level_label.text = tr("XP_HUD_HERO_LEVEL").format({
		"level": level
	})
