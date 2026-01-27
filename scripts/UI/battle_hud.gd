extends Control

# ==========================================
# SEÑALES (la UI no decide nada, solo avisa)
# ==========================================

signal draw_pressed
signal combat_pressed
signal auto_draw_toggled(enabled: bool)
signal auto_combat_toggled(enabled: bool)
signal pause_pressed


# ==========================================
# NODOS DE LA ESCENA
# ==========================================

@onready var danger_label: Label = $TopBar/DangerLabel
@onready var gold_label: Label = $TopBar/GoldLabel

@onready var draw_button: Button = $Controls/DrawButton
@onready var combat_button: Button = $Controls/CombatButton
@onready var auto_draw_check: CheckButton = $Controls/AutoDrawCheck
@onready var auto_combat_check: CheckButton = $Controls/AutoCombatCheck
@onready var pause_button: Button = $PauseButton


# ==========================================
# ESTADO VISUAL (NO lógica de juego)
# ==========================================

var danger_level: int = 0
var gold_amount: int = 0


# ==========================================
# CICLO DE VIDA
# ==========================================

func _ready() -> void:
	print_tree_pretty()

	draw_button.text = tr("BATTLE_HUD_BUTTON_DRAW")
	combat_button.text = tr("BATTLE_HUD_BUTTON_COMBAT")
	auto_draw_check.text = tr("BATTLE_HUD_CHECK_AUTO_DRAW")
	auto_combat_check.text = tr("BATTLE_HUD_CHECK_AUTO_COMBAT")
	pause_button.text = tr("BATTLE_HUD_BUTTON_PAUSE")

	draw_button.pressed.connect(_on_draw_button_pressed)
	combat_button.pressed.connect(_on_combat_button_pressed)
	auto_draw_check.toggled.connect(_on_auto_draw_toggled)
	auto_combat_check.toggled.connect(_on_auto_combat_toggled)
	pause_button.pressed.connect(_on_pause_button_pressed)

	# 🔑 Escuchar al RunManager
	RunState.gold_changed.connect(update_gold)
	RunState.danger_level_changed.connect(update_danger)

	# Inicial
	update_gold(RunState.gold)
	update_danger(RunState.danger_level)

	set_draw_enabled(true)
	set_combat_enabled(false)


# ==========================================
# FUNCIONES PÚBLICAS (BattleTable llama a estas)
# ==========================================

func update_danger(value: int) -> void:
	print("[HUD] Danger updated:", value)
	danger_level = value
	danger_label.text = "⚠ %s: %d" % [
		tr("BATTLE_HUD_LABEL_DANGER"),
		danger_level
	]


func update_gold(value: int) -> void:
	print("[HUD] Gold updated:", value)

	gold_amount = value
	gold_label.text = "💰 %s: %d" % [
		tr("BATTLE_HUD_LABEL_GOLD"),
		gold_amount
	]


func set_draw_enabled(enabled: bool) -> void:
	draw_button.disabled = not enabled


func set_combat_enabled(enabled: bool) -> void:
	combat_button.disabled = not enabled


func is_auto_draw_enabled() -> bool:
	return auto_draw_check.button_pressed


func is_auto_combat_enabled() -> bool:
	return auto_combat_check.button_pressed


# ==========================================
# MANEJO DE INPUT (solo emite señales)
# ==========================================

func _on_draw_button_pressed() -> void:
	draw_pressed.emit()


func _on_combat_button_pressed() -> void:
	combat_pressed.emit()


func _on_auto_draw_toggled(enabled: bool) -> void:
	auto_draw_toggled.emit(enabled)


func _on_auto_combat_toggled(enabled: bool) -> void:
	auto_combat_toggled.emit(enabled)

func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
