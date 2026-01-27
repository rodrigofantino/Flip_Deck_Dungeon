extends Control

# ==========================================
# NODOS DE LA ESCENA
# ==========================================

@onready var background: Sprite2D = $Background
@onready var cards_layer: Node2D = $CardsLayer
# CardsLayer es una capa neutra Node2D donde se instancian TODAS las cartas

@onready var hero_anchor: Control = $UI/HeroArea/HeroAnchor
@onready var enemy_deck: Control = $UI/EnemyArea/EnemyDeck
@onready var enemy_slot: Control = $UI/EnemyArea/EnemySlots

@onready var battle_hud: Control = $UI/BattleHUD

@export var defeat_popup_scene: PackedScene
var defeat_popup: DefeatPopup = null
var run_initialized: bool = false
var suppress_level_up_popup: bool = false
var victory_gold_awarded: bool = false

# =========================
# VICTORY POPUP
# =========================
@export var victory_popup_scene: PackedScene
var victory_popup: VictoryPopup = null

# ==========================================
# REGISTRO DE CARD VIEWS (UI)
# ==========================================
var card_views: Dictionary = {}
# key: String (card_id)
# value: CardView

# =========================
# LEVEL UP POPUP
# =========================
@export var level_up_popup_scene: PackedScene
var level_up_popup: LevelUpPopup

# =========================
# PAUSE POPUP
# =========================
@export var pause_popup_scene: PackedScene
var pause_popup: PausePopup = null
var pause_open: bool = false
var phase_before_pause: BattlePhase = BattlePhase.IDLE

# ==========================================
# ESTADO DEL HEROE Y ENEMIGOS
# ==========================================
var hero_card_view: CardView = null
var enemy_card_view: CardView = null

# ==========================================
# COMBAT MANAGER
# ==========================================
var combat_manager: CombatManager

# ==========================================
# CONFIGURACIÓN
# ==========================================

@export var card_view_scene: PackedScene
@export var card_margin_factor: float = 1.0
@export var card_base_size: Vector2 = Vector2(620, 860)
@export var card_display_size: Vector2 = Vector2(155, 215)
@export var debug_card_positions: bool = true

const DECK_OFFSET_Y := -2.0

# ==========================================
# ESTADOS DE LA BATALLA
# ==========================================

enum BattlePhase {
	IDLE,          # No hay enemigo activo
	ENEMY_ACTIVE,  # Hay enemigo en mesa
	UI_LOCKED,     # UI bloqueada (combate, animaciones, popups)
}

var current_phase: BattlePhase = BattlePhase.IDLE

# ==========================================
# CONFIGURACIÓN DE AUTOMATIZACIÓN
# ==========================================

var auto_draw_enabled: bool = false
var auto_combat_enabled: bool = false

# ==========================================
# LOOP AUTOMÁTICO DE BATALLA
# ==========================================

func _process(_delta: float) -> void:
	_process_battle_flow()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _process_battle_flow() -> void:
	match current_phase:
		BattlePhase.IDLE:
			if auto_draw_enabled:
				_draw_enemy()

		BattlePhase.ENEMY_ACTIVE:
			pass # El combate se dispara por señal, no por polling

		BattlePhase.UI_LOCKED:
			pass


# ==========================================
# CICLO DE VIDA
# ==========================================

func _ready() -> void:
	# --- Combat Manager ---
	combat_manager = CombatManager.new()
	add_child(combat_manager)
	combat_manager.setup(RunState)
	combat_manager.ready_for_next_round.connect(_on_ready_for_next_round)
	combat_manager.attack_started.connect(_on_attack_started)
	combat_manager.damage_applied.connect(_on_damage_applied)
	combat_manager.card_died.connect(_on_card_died)
	combat_manager.combat_finished.connect(_on_combat_finished)

	# --- Setup original ---
	RunState.debug_print_traits()
	await get_tree().process_frame
	setup_battle()
	_connect_battle_hud()
	_connect_run_signals()
	_update_hud_state()
	RunState.hero_level_up.connect(_on_hero_level_up)
	RunState.enemy_stats_changed.connect(_on_enemy_stats_changed)
	
	
# ==========================================
# SETUP GENERAL DE BATALLA
# ==========================================

func setup_battle() -> void:
	if not run_initialized:
		RunState.init_run() ## SOLO SE PUEDE LLAMAR 1 VEZ a ESTA FUNCION POR PARTIDA
		run_initialized = true
		victory_gold_awarded = false

	spawn_hero()
	setup_enemy_deck()
	_restore_active_enemy_if_needed()

# ==========================================
# CONNECT BATTLE HUD
# ==========================================

func _connect_battle_hud() -> void:
	battle_hud.draw_pressed.connect(_on_draw_pressed)
	battle_hud.combat_pressed.connect(_on_combat_pressed)
	battle_hud.auto_draw_toggled.connect(_on_auto_draw_toggled)
	battle_hud.auto_combat_toggled.connect(_on_auto_combat_toggled)
	battle_hud.pause_pressed.connect(_on_pause_pressed)

# ==========================================
# HÉROE
# ==========================================

func spawn_hero() -> void:
	if hero_anchor == null:
		return

	var hero_data: Variant = RunState.get_card("th")
	if hero_data == null:
		push_error("Hero data not found")
		return
	if hero_data is Dictionary and hero_data.is_empty():
		push_error("Hero data empty")
		return

	var hero_card := _create_and_fit_card(hero_anchor, hero_data)
	if hero_card:
		hero_card_view = hero_card
		if RunState.run_loaded:
			hero_card.show_front()
		else:
			hero_card.show_back()
			hero_card.flip_to_front()

		# 🔑 Setear HP real inicial
		hero_card_view.refresh(hero_data)

# ==========================================	
# MAZO ENEMIGO (VISUAL)
# ==========================================

func setup_enemy_deck() -> void:
	if enemy_deck == null:
		return

	for child in enemy_deck.get_children():
		child.queue_free()

	if RunState.enemy_draw_queue.is_empty():
		RunState.prepare_progressive_deck()

	var current_y_offset := 0.0

	# 🔥 DIBUJAMOS DE ABAJO HACIA ARRIBA
	for i in range(RunState.enemy_draw_queue.size() - 1, -1, -1):
		var enemy_data := RunState.enemy_draw_queue[i]

		var card := _create_and_fit_card(enemy_deck, enemy_data)
		if not card:
			continue

		card.global_position.y += current_y_offset
		card.show_back()
		current_y_offset += DECK_OFFSET_Y


# ==========================================
# LOOP DE ENEMIGOS
# ==========================================

func check_enemy_slot() -> void:
	if enemy_slot.get_child_count() == 0:
		spawn_enemy_from_deck()

func spawn_enemy_from_deck() -> void:
	if enemy_deck == null or enemy_slot == null:
		return

	# 1️⃣ ROBAR DEL MAZO LÓGICO
	var enemy_data: Dictionary = RunState.draw_enemy_card()
	if enemy_data.is_empty():
		return

	# 2️⃣ BUSCAR LA CARD VIEW EXISTENTE
	var card: CardView = card_views.get(enemy_data.id, null)
	if card == null:
		push_error("No CardView found for enemy: " + enemy_data.id)
		return

	# 3️⃣ REPARENT (deck → slot) manteniendo posición global
	card.reparent(enemy_slot, true)
	card.show_back()

	# 4️⃣ ANIMACIÓN
	var slot_rect := enemy_slot.get_global_rect()
	var scaled_size := card_base_size * card.scale
	var end_pos := slot_rect.get_center() - (scaled_size * 0.5)

	var tween := create_tween()
	tween.tween_property(card, "global_position", end_pos, 0.5)
	tween.finished.connect(_on_enemy_move_finished.bind(card))


# ==========================================
# ESTADO: ENEMIGO ACTIVO
# ==========================================

func _set_enemy_active(card: CardView) -> void:
	enemy_card_view = card
	RunState.active_enemy_id = card.card_id

	# 🔑 Setear HP real del enemigo activo
	var enemy_data: Variant = RunState.get_card(card.card_id)
	if enemy_data != null:
		card.refresh(enemy_data)

	current_phase = BattlePhase.ENEMY_ACTIVE
	_update_hud_state()
	_update_initiative_chance_for_active_enemy()

	# 🔥 AUTO-COMBAT: primer ataque automático
	if auto_combat_enabled:
		# Esperamos 1 frame para que:
		# - termine el flip
		# - la UI se actualice
		# - no choquemos con tweens
		await get_tree().process_frame
		_start_combat()


func _on_enemy_move_finished(card: CardView) -> void:
	card.update_pivot_to_center()
	card.flip_to_front()
	_set_enemy_active(card)

# ==========================================
# MUERTE DE ENEMIGO
# ==========================================

func on_enemy_defeated() -> void:
	if enemy_slot.get_child_count() == 0:
		return

	enemy_slot.get_child(0).queue_free()

func _handle_enemy_defeated() -> void:
	if enemy_card_view == null:
		return

	var enemy_data: Dictionary = RunState.get_card(enemy_card_view.card_id)
	RunState.active_enemy_id = ""
	var victory_after_defeat := not _has_remaining_enemies_after_defeat(enemy_card_view.card_id)
	suppress_level_up_popup = victory_after_defeat

	# 1️⃣ Recompensas
	if enemy_data != null:
		RunState.apply_enemy_rewards(enemy_data)
	suppress_level_up_popup = false

	# 2️⃣ Eliminar del estado
	RunState.cards.erase(enemy_card_view.card_id)

	# 🔑 3️⃣ Recalcular danger level (RunManager manda)
	RunState.recalculate_danger_level()

	# 4️⃣ Visual
	enemy_card_view.queue_free()
	card_views.erase(enemy_card_view.card_id)
	enemy_card_view = null
	if _has_remaining_enemies():
		current_phase = BattlePhase.IDLE
		_update_hud_state()
	else:
		_show_victory()
#######################################################
#### REVISAR LVL UP
######################################################

func _connect_run_signals() -> void:
	RunState.hero_level_up.connect(_on_hero_level_up)

func _on_enemy_stats_changed() -> void:
	_refresh_all_card_views()

func _on_pause_pressed() -> void:
	_toggle_pause()

func _on_hero_level_up(new_level: int) -> void:
	if suppress_level_up_popup:
		return
	if not _has_remaining_enemies():
		return
	print("[BattleTable] HERO LEVEL UP → Pausando batalla")
	RunState.save_run()

	current_phase = BattlePhase.UI_LOCKED

	_update_hud_state()

	get_tree().paused = true
	_show_level_up_popup(new_level)


	# FUTURO:
	# - Pausar combate
	# - Mostrar popup de traits
	# - Elegir recompensa

# ==========================================
# CREAR + POSICIONAR + ESCALAR
# ==========================================

func _create_and_fit_card(slot: Control, card_data: Dictionary) -> CardView:
	if not card_view_scene:
		return null

	# Instanciar CardView
	var card: CardView = card_view_scene.instantiate()
	cards_layer.add_child(card)
	# Base size explícito para layout interno del CardView
	card.custom_minimum_size = card_base_size
	card.size = card_base_size
	# Asegurar layout fijo del Control (sin anchors dependientes del parent)
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = card_base_size.x
	card.offset_bottom = card_base_size.y
	card.pivot_offset = card_base_size * 0.5

	# =========================
	# ID + REGISTRO UI
	# =========================
	if card_data.has("id"):
		card.card_id = String(card_data["id"])
		card_views[card.card_id] = card   # 🔑 REGISTRO CENTRAL

	# =========================
	# DEFINICIÓN (Resource)
	# =========================
	var def_id: String = String(card_data["definition"])
	var definition: CardDefinition = CardDatabase.get_definition(def_id)
	if definition != null:
		card.setup_from_definition(definition)

	# =========================
	# POSICIÓN BASE
	# =========================
	var slot_rect: Rect2 = slot.get_global_rect()

	# =========================
	# ESCALADO VISUAL
	# =========================
	if card_base_size.x > 0.0 and card_base_size.y > 0.0:
		var scale_w: float = card_display_size.x / card_base_size.x
		var scale_h: float = card_display_size.y / card_base_size.y
		var final_scale: float = min(scale_w, scale_h) * card_margin_factor
		card.scale = Vector2(final_scale, final_scale)

	# =========================
	# POSICIÓN CENTRADA (GLOBAL)
	# =========================
	var scaled_size := card_base_size * card.scale
	card.global_position = slot_rect.get_center() - (scaled_size * 0.5)
	if debug_card_positions:
		print(
			"[CARD POS]",
			"slot:", slot.name,
			"slot_center:", slot_rect.get_center(),
			"card_pos:", card.global_position,
			"scale:", card.scale
		)

	# =========================
	# PIVOT CORRECTO
	# =========================
	if card.has_method("update_pivot_to_center"):
		card.update_pivot_to_center()

	return card


# ==========================================
# COMBATE - DAÑO
# ==========================================
# YA NO ES PARTE MAS DE BATTLE TABLE SE OCUPA COMBAT CONTEXT DE ESTO

# ==========================================
# HUD UPDATE
# ==========================================

func _update_hud_state() -> void:
	match current_phase:
		BattlePhase.IDLE:
			battle_hud.set_draw_enabled(true)
			battle_hud.set_combat_enabled(false)

		BattlePhase.ENEMY_ACTIVE:
			battle_hud.set_draw_enabled(false)
			battle_hud.set_combat_enabled(true)

		BattlePhase.UI_LOCKED:
			battle_hud.set_draw_enabled(false)
			battle_hud.set_combat_enabled(false)


# ==========================================
# RESPUESTA A LA UI
# ==========================================
func _show_level_up_popup(new_level: int) -> void:
	if level_up_popup == null:
		level_up_popup = level_up_popup_scene.instantiate()
		add_child(level_up_popup)
		level_up_popup.z_index = 200

		level_up_popup.traits_confirmed.connect(_on_traits_confirmed)

	# Pedir traits al RunManager
	var hero_traits := RunState.get_random_hero_traits(3)
	var enemy_traits := RunState.get_random_enemy_traits(3)

	level_up_popup.show_popup(
		new_level,
		hero_traits,
		enemy_traits
	)
func _on_traits_confirmed(hero_trait_res: TraitResource, enemy_trait_res: TraitResource) -> void:
	print("🧪 CONFIRMED TRAITS")
	print("   hero:", hero_trait_res)
	print("   enemy:", enemy_trait_res)

	RunState.apply_hero_trait(hero_trait_res)
	RunState.apply_enemy_trait(enemy_trait_res)
	RunState.save_run()


	# 🔑 ACTUALIZAR VISUAL DEL HÉROE
	refresh_card_view("th")

	# 🔥 refrescar TODOS los enemigos existentes
	for card_id in RunState.cards.keys():
		if card_id == "th":
			continue
		refresh_card_view(card_id)



	get_tree().paused = false
	current_phase = BattlePhase.IDLE
	_update_hud_state()

	
func _on_draw_pressed() -> void:
	if current_phase != BattlePhase.IDLE:
		return

	_draw_enemy()

func _on_combat_pressed() -> void:
	if current_phase != BattlePhase.ENEMY_ACTIVE:
		return

	_start_combat()

func _on_auto_draw_toggled(enabled: bool) -> void:
	auto_draw_enabled = enabled

func _on_auto_combat_toggled(enabled: bool) -> void:
	auto_combat_enabled = enabled

	# 🔑 Si se activa el auto-combat y hay un enemigo listo,
	# arrancamos inmediatamente una ronda.
	if auto_combat_enabled and current_phase == BattlePhase.ENEMY_ACTIVE:
		_start_combat()
	
	# =========================
	# defeat popup
	# =========================
func _on_back_to_menu() -> void:
	SaveSystem.clear_run_save()
	RunState.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")

func _on_ready_for_next_round() -> void:
	if not auto_combat_enabled:
		return

	# Si hay enemigo vivo, seguimos combatiendo
	if enemy_card_view != null:
		_start_combat()
# ==========================================
# UTILIDADES
# ==========================================

func _find_sprite_in_card(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node
	for child in node.get_children():
		var res := _find_sprite_in_card(child)
		if res:
			return res
	return null
	
func refresh_card_view(card_id: String) -> void:
	if not card_views.has(card_id):
		return

	var card_view: CardView = card_views[card_id]
	var card_data: Dictionary = RunState.get_card(card_id)

	if card_data.is_empty():
		return

	card_view.refresh(card_data)

func _refresh_all_card_views() -> void:
	for card_id in card_views.keys():
		refresh_card_view(String(card_id))


# ==========================================
# DRAW ENEMIGO (REAL)
# Esta función NO cambia estado.
# El estado se actualiza únicamente cuando
# la carta llega al slot (_set_enemy_active)
# ==========================================

func _draw_enemy() -> void:
	# Verificación de seguridad: solo robamos si la mesa está vacía (IDLE)
	if current_phase != BattlePhase.IDLE:
		return
	# Cambiamos a RESOLVING inmediatamente para bloquear otros robos
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	spawn_enemy_from_deck()

# ==========================================
# COMBATE
# ==========================================

func _start_combat() -> void:
	if enemy_card_view == null:
		return

	if current_phase == BattlePhase.UI_LOCKED:
		return

	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()

	_update_initiative_chance_for_active_enemy()
	combat_manager.start_combat(enemy_card_view.card_id)


func _show_defeat() -> void:
	print("Defeat popup scene:", defeat_popup_scene)

	current_phase = BattlePhase.UI_LOCKED

	_update_hud_state()

	if defeat_popup_scene == null:
		push_error("DefeatPopup scene not assigned")
		return

	# Instancia UNA sola vez
	if defeat_popup == null:
		defeat_popup = defeat_popup_scene.instantiate()
		add_child(defeat_popup)
		defeat_popup.z_index = 100
		# Conexión segura
		defeat_popup.back_to_menu_pressed.connect(_on_back_to_menu)

	defeat_popup.show_popup()
	print("Popup global position:", global_position)
	print("Popup size:", size)

func _show_victory() -> void:
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	get_tree().paused = true

	if not victory_gold_awarded and not RunState.is_temporary_run:
		SaveSystem.add_persistent_gold(RunState.gold)
		victory_gold_awarded = true
	SaveSystem.clear_run_save()

	if victory_popup_scene == null:
		push_error("VictoryPopup scene not assigned")
		return

	if victory_popup == null:
		victory_popup = victory_popup_scene.instantiate()
		add_child(victory_popup)
		victory_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		victory_popup.z_index = 200
		victory_popup.back_to_menu_pressed.connect(_on_back_to_menu)

	victory_popup.show_victory(RunState.gold)


######################################
#EFECTOS VISUALES
#######################################

# ==========================================
# ANIMACIÓN DE ATAQUE (HOVER + TAMBALÉO)
# ==========================================

func _play_attack_animation(attacker: CardView, target: CardView) -> void:
	if attacker == null or target == null:
		return

	# Posiciones base
	var start_pos: Vector2 = attacker.global_position
	var target_pos: Vector2 = target.global_position

	# Dirección hacia el objetivo
	var direction: Vector2 = (target_pos - start_pos).normalized()

	# =========================
	# PARÁMETROS DE ANIMACIÓN
	# =========================

	var lift_height := 35.0              # cuánto flota
	var attack_distance := 0.85          # porcentaje de la distancia real
	var wiggle_amount := 10.0            # tambaleo lateral
	var impact_recoil := 12.0            # pequeño rebote al impactar

	# Cálculos
	var lift_offset := Vector2(0, -lift_height)
	var full_distance := target_pos.distance_to(start_pos)
	var attack_offset := direction * full_distance * attack_distance

	# Vector perpendicular para el tambaleo
	var perpendicular := Vector2(-direction.y, direction.x)

	# =========================
	# TWEEN
	# =========================

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 1️⃣ Levantar carta (hover)
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset,
		0.15
	)

	# 2️⃣ Tambaleo 1
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset + perpendicular * wiggle_amount,
		0.08
	)

	# 3️⃣ Tambaleo 2 (lado contrario)
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset - perpendicular * wiggle_amount,
		0.08
	)

	# 4️⃣ Avance fuerte hacia el enemigo
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset + attack_offset,
		0.12
	)

	# 5️⃣ Micro recoil (impacto)
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset + attack_offset - direction * impact_recoil,
		0.06
	)

	# 6️⃣ Volver a hover
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset,
		0.12
	)

	# 7️⃣ Volver a la mesa
	tween.tween_property(
		attacker,
		"global_position",
		start_pos,
		0.15
	)

	await tween.finished

# ==========================================
# COMBAT MANAGER → VISUAL
# ==========================================

func _on_attack_started(attacker_id: String, target_id: String) -> void:
	RunState.save_run()
	var attacker := _get_card_view(attacker_id)
	var target := _get_card_view(target_id)

	if attacker and target:
		await _play_attack_animation(attacker, target)

	combat_manager.attack_animation_finished.emit()

func _on_damage_applied(target_id: String, _amount: int) -> void:
	var card_view := _get_card_view(target_id)
	if card_view:
		var data: Dictionary = RunState.get_card(target_id)
		if data.is_empty():
			return
		refresh_card_view(target_id)

func _on_card_died(card_id: String) -> void:
	if card_id == "th":
		_show_defeat()
		SaveSystem.remove_from_run_deck(card_id)
		RunState.save_run()
		return

	RunState.active_enemy_id = ""
	_handle_enemy_defeated()
	SaveSystem.remove_from_run_deck(card_id)
	RunState.save_run()

func _on_combat_finished(victory: bool) -> void:
	if victory:
		current_phase = BattlePhase.IDLE
	else:
		current_phase = BattlePhase.ENEMY_ACTIVE

	_update_hud_state()

# ==========================================
# UTILIDAD
# ==========================================
func _get_card_view(card_id: String) -> CardView:
	if hero_card_view and hero_card_view.card_id == card_id:
		return hero_card_view
	if enemy_card_view and enemy_card_view.card_id == card_id:
		return enemy_card_view
	return null

func _restore_active_enemy_if_needed() -> void:
	if RunState.active_enemy_id == "":
		return
	if enemy_slot == null:
		return
	var enemy_data: Dictionary = RunState.get_card(RunState.active_enemy_id)
	if enemy_data.is_empty():
		RunState.active_enemy_id = ""
		return
	var existing: CardView = card_views.get(RunState.active_enemy_id, null)
	var card: CardView = existing
	if card == null:
		card = _create_and_fit_card(enemy_slot, enemy_data)
	if card == null:
		RunState.active_enemy_id = ""
		return
	card.reparent(enemy_slot, true)
	card.show_front()
	enemy_card_view = card
	current_phase = BattlePhase.ENEMY_ACTIVE
	_update_hud_state()
	_update_initiative_chance_for_active_enemy()

func _update_initiative_chance_for_active_enemy() -> void:
	if battle_hud == null:
		return
	var hero: Dictionary = RunState.get_card("th")
	if hero.is_empty() or enemy_card_view == null:
		battle_hud.update_initiative_chance(0.0)
		return
	var enemy: Dictionary = RunState.get_card(enemy_card_view.card_id)
	if enemy.is_empty():
		battle_hud.update_initiative_chance(0.0)
		return
	var hero_init: int = int(hero.get("initiative", 0))
	var enemy_init: int = int(enemy.get("initiative", 0))
	var p: float = CombatManager.calc_hero_first_chance(hero_init, enemy_init)
	battle_hud.update_initiative_chance(p)

func _has_remaining_enemies() -> bool:
	if not RunState.enemy_draw_queue.is_empty():
		return true
	for card in RunState.cards.values():
		if card.get("id", "") != "th":
			return true
	return false

func _has_remaining_enemies_after_defeat(defeated_id: String) -> bool:
	if not RunState.enemy_draw_queue.is_empty():
		return true
	for card in RunState.cards.values():
		if card.get("id", "") != "th" and card.get("id", "") != defeated_id:
			return true
	return false

# ==========================================
# PAUSE
# ==========================================
func _toggle_pause() -> void:
	if get_tree().paused and not pause_open:
		return
	if pause_open:
		_close_pause()
	else:
		_open_pause()

func _open_pause() -> void:
	if pause_popup == null:
		pause_popup = pause_popup_scene.instantiate()
		pause_popup.z_index = 150
		add_child(pause_popup)
		pause_popup.continue_pressed.connect(_close_pause)
		pause_popup.menu_pressed.connect(_on_pause_menu_pressed)

	pause_open = true
	phase_before_pause = current_phase
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	get_tree().paused = true

func _close_pause() -> void:
	pause_open = false
	if pause_popup != null:
		pause_popup.queue_free()
		pause_popup = null
	get_tree().paused = false
	current_phase = phase_before_pause
	_update_hud_state()

func _on_pause_menu_pressed() -> void:
	RunState.save_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")
