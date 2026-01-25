extends Control
class_name LevelUpPopup

# =========================
# SEÑALES
# =========================
signal traits_confirmed(hero_trait_res, enemy_trait_res)

# =========================
# NODOS
# =========================
@onready var level_label: Label = $Panel/"popup container"/VBoxContainer/LevelLabel
@onready var confirm_button: Button = $Panel/"popup container"/VBoxContainer/ConfirmButton

@onready var hero_traits_container: HBoxContainer = $Panel/"popup container"/HeroColumn/HeroTraitsContainer
@onready var enemy_traits_container: HBoxContainer = $Panel/"popup container"/EnemyColumn/EnemyTraitsContainer

@export var trait_card_scene: PackedScene

# =========================
# ESTADO
# =========================
var selected_hero_trait_res: TraitResource = null
var selected_enemy_trait_res: TraitResource = null

# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	hide()

	process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_button.process_mode = Node.PROCESS_MODE_ALWAYS

	confirm_button.text = tr("LEVEL_UP_POPUP_BUTTON_CONFIRM")
	confirm_button.pressed.connect(_on_confirm_pressed)

# =========================
# API PÚBLICA
# =========================
func show_popup(
	new_level: int,
	hero_traits: Array,
	enemy_traits: Array
) -> void:
	level_label.text = tr("LEVEL_UP_POPUP_TITLE_LEVEL_REACHED") % new_level

	_populate_traits(hero_traits, enemy_traits)

	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true

	print("[LevelUpPopup] SHOW → Level", new_level)

func hide_popup() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false

	print("[LevelUpPopup] HIDE")

# =========================
# TRAITS
# =========================
func _populate_traits(hero_traits: Array, enemy_traits: Array) -> void:
	_clear_traits()

	selected_hero_trait_res = null
	selected_enemy_trait_res = null
	confirm_button.disabled = true

	for trait_res in hero_traits:
		_create_trait_card(trait_res, true)

	for trait_res in enemy_traits:
		_create_trait_card(trait_res, false)

func _clear_traits() -> void:
	for child in hero_traits_container.get_children():
		child.queue_free()

	for child in enemy_traits_container.get_children():
		child.queue_free()

func _create_trait_card(trait_res: TraitResource, is_hero: bool) -> TraitCard:
	var card: TraitCard = trait_card_scene.instantiate()

	if is_hero:
		hero_traits_container.add_child(card)
	else:
		enemy_traits_container.add_child(card)

	card.call_deferred("setup", trait_res)

	card.trait_selected.connect(func(selected_res):
		_on_trait_selected(selected_res, is_hero, card)
	)

	return card

func _on_trait_selected(trait_res: TraitResource, is_hero: bool, card: TraitCard) -> void:
	if is_hero:
		selected_hero_trait_res = trait_res
		_update_group_visual(hero_traits_container, card)
	else:
		selected_enemy_trait_res = trait_res
		_update_group_visual(enemy_traits_container, card)

	_update_confirm_state()

func _update_group_visual(container: Control, selected_card: TraitCard) -> void:
	for child in container.get_children():
		if child is TraitCard:
			child.set_selected(child == selected_card)

func _update_confirm_state() -> void:
	confirm_button.disabled = (
		selected_hero_trait_res == null
		or selected_enemy_trait_res == null
	)

# =========================
# UI
# =========================
func _on_confirm_pressed() -> void:
	print("[LevelUpPopup] CONFIRMED")
	print("Hero trait:", selected_hero_trait_res.display_name)
	print("Enemy trait:", selected_enemy_trait_res.display_name)

	traits_confirmed.emit(
		selected_hero_trait_res,
		selected_enemy_trait_res
	)

	hide_popup()
