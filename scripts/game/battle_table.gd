extends Control

# ==========================================
# NODOS DE LA ESCENA
# ==========================================

@onready var background: Sprite2D = $Background
@onready var cards_layer: Node2D = $CardsLayer
# CardsLayer es una capa neutra Node2D donde se instancian TODAS las cartas

@onready var hero_anchor: Control = $UI/HeroArea/HeroAnchor
@onready var enemy_decks_container: Control = $UI/EnemyArea/EnemyDeck
@onready var enemy_slots_container: Control = $UI/EnemyArea/EnemySlots
@onready var equipment_slots_view: EquipmentSlotsView = $UI/HeroArea/EquipmentSlotsView
@onready var trait_overlay_view: TraitOverlayView = $UI/TraitOverlayView

@onready var battle_hud: Control = $UI/BattleHUD
@onready var ui_root: Control = $UI

@export var defeat_popup_scene: PackedScene
var defeat_popup: DefeatPopup = null
var run_initialized: bool = false
var suppress_level_up_popup: bool = false
var victory_gold_awarded: bool = false
var end_of_wave_pending: bool = false
var pending_hero_upgrades: bool = false

# =========================
# VICTORY POPUP
# =========================
@export var victory_popup_scene: PackedScene
var victory_popup: VictoryPopup = null
@export var wave_popup_scene: PackedScene
var wave_popup: WavePopup = null
var wave_popup_open: bool = false
var suppress_wave_popup_once: bool = false
var pending_wave_popup: bool = false
var pending_trait_popup: bool = false

# ==========================================
# REGISTRO DE CARD VIEWS (UI)
# ==========================================
var card_views: Dictionary = {}
# key: String (card_id)
# value: CardView

# =========================

# =========================
# CROSSROADS POPUP
# =========================
@export var crossroads_popup_scene: PackedScene
var crossroads_popup: CrossroadsPopup = null
var crossroads_open: bool = false

# LEVEL UP POPUP
# =========================
@export var level_up_popup_scene: PackedScene
var level_up_popup: LevelUpPopup
@export var hero_upgrades_window_scene: PackedScene
var hero_upgrades_window: HeroUpgradesWindow = null

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
var enemy_card_views: Array[CardView] = []
var enemy_card_views_by_deck: Dictionary = {}
var enemy_deck_slots: Array[Control] = []
var enemy_slots: Array[Control] = []
var pending_enemy_moves: int = 0

# ==========================================
# COMBAT MANAGER
# ==========================================
var combat_manager: CombatManager
const CARD_ZONE_META := "battle_zone"
const CARD_ZONE_DECK := "enemy_deck"
const CARD_ZONE_ACTIVE := "enemy_active"
const CARD_ZONE_HERO := "hero"

# ==========================================
# CONFIGURACIÃƒÆ’Ã¢â‚¬Å“N
# ==========================================

@export var card_view_scene: PackedScene
@export var card_margin_factor: float = 0.75
@export var card_base_size: Vector2 = Vector2(620, 860)
@export var card_display_size: Vector2 = Vector2(124, 172)
@export var debug_card_positions: bool = true

const DECK_OFFSET_Y := -2.0
const BATTLE_LIGHT_MASK: int = 4

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
# CONFIGURACIÃƒÆ’Ã¢â‚¬Å“N DE AUTOMATIZACIÃƒÆ’Ã¢â‚¬Å“N
# ==========================================

var auto_draw_enabled: bool = false
var auto_combat_enabled: bool = false

# ==========================================
# LOOP AUTOMÃƒÆ’Ã‚ÂTICO DE BATALLA
# ==========================================

func _process(_delta: float) -> void:
	_process_battle_flow()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_phase == BattlePhase.UI_LOCKED:
			return
		var mouse_event := event as InputEventMouseButton
		_try_handle_card_click_at(mouse_event.global_position)

func _process_battle_flow() -> void:
	match current_phase:
		BattlePhase.IDLE:
			if auto_draw_enabled:
				_draw_enemy()

		BattlePhase.ENEMY_ACTIVE:
			pass # El combate se dispara por seÃƒÆ’Ã‚Â±al, no por polling

		BattlePhase.UI_LOCKED:
			pass


# ==========================================
# CICLO DE VIDA
# ==========================================

func _ready() -> void:
	if MusicManager:
		MusicManager.play_battle()
	_apply_battle_light_mask()
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
	RunState.hero_stats_changed.connect(_on_enemy_stats_changed)
	RunState.wave_started.connect(_on_wave_started)
	RunState.wave_completed.connect(_on_wave_completed)
	_setup_equipment_slots_view()

# ==========================================
# LIGHT MASK (BATTLE TABLE)
# ==========================================

func _apply_battle_light_mask() -> void:
	_set_light_mask_recursive(self, BATTLE_LIGHT_MASK)

func _set_light_mask_recursive(node: Node, mask: int) -> void:
	if node is CardView:
		return
	if node is CanvasItem:
		(node as CanvasItem).light_mask = mask
	for child in node.get_children():
		_set_light_mask_recursive(child, mask)
	
	
# ==========================================
# SETUP GENERAL DE BATALLA
# ==========================================

func setup_battle() -> void:
	if not run_initialized:
		RunState.init_run() ## SOLO SE PUEDE LLAMAR 1 VEZ a ESTA FUNCION POR PARTIDA
		run_initialized = true
		victory_gold_awarded = false

	spawn_hero()
	_cache_enemy_slots()
	setup_enemy_deck()
	_restore_active_enemies_if_needed()
	_setup_equipment_slots_view()

func _setup_equipment_slots_view() -> void:
	if equipment_slots_view == null or RunState == null:
		return
	equipment_slots_view.setup("knight", RunState)

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
# HÃƒÆ’Ã¢â‚¬Â°ROE
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
		hero_card_view.set_meta(CARD_ZONE_META, CARD_ZONE_HERO)
		if RunState.run_loaded:
			hero_card.show_front()
		else:
			hero_card.show_back()
			hero_card.flip_to_front()

		# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Ëœ Setear HP real inicial
		hero_card_view.refresh(hero_data)

# ==========================================	
# MAZO ENEMIGO (VISUAL)
# ==========================================

func setup_enemy_deck() -> void:
	if enemy_decks_container == null:
		return
	_cache_enemy_slots()
	_apply_enemy_deck_visibility()
	enemy_card_views_by_deck.clear()
	enemy_card_views.clear()

	if RunState.are_enemy_draw_queues_empty():
		RunState.prepare_progressive_deck()

	for deck_index in range(min(enemy_deck_slots.size(), RunState.get_active_decks_count())):
		var deck_slot := enemy_deck_slots[deck_index]
		for child in deck_slot.get_children():
			child.queue_free()
		var queue: Array[Dictionary] = RunState.get_enemy_draw_queue(deck_index)
		var current_y_offset := 0.0
		for i in range(queue.size() - 1, -1, -1):
			var enemy_data: Dictionary = queue[i]
			var card := _create_and_fit_card(deck_slot, enemy_data)
			if not card:
				continue
			card.global_position.y += current_y_offset
			card.show_back()
			card.set_meta(CARD_ZONE_META, CARD_ZONE_DECK)
			current_y_offset += DECK_OFFSET_Y


# ==========================================
# LOOP DE ENEMIGOS
# ==========================================

func check_enemy_slot() -> void:
	if _are_all_enemy_slots_empty():
		spawn_enemies_from_decks()

func spawn_enemies_from_decks() -> void:
	if enemy_decks_container == null or enemy_slots_container == null:
		return
	_cache_enemy_slots()
	_apply_enemy_deck_visibility()

	pending_enemy_moves = 0
	var deck_count: int = min(enemy_slots.size(), RunState.get_active_decks_count())
	for deck_index in range(deck_count):
		var slot := enemy_slots[deck_index]
		if slot.get_child_count() > 0:
			continue
		var enemy_data: Dictionary = RunState.draw_enemy_card_from_deck(deck_index)
		if enemy_data.is_empty():
			continue
		var card: CardView = card_views.get(enemy_data.id, null)
		if card == null:
			push_error("No CardView found for enemy: " + enemy_data.id)
			continue
		card.reparent(slot, true)
		card.set_meta(CARD_ZONE_META, CARD_ZONE_ACTIVE)
		card.show_back()
		var slot_rect := slot.get_global_rect()
		var scaled_size := card_base_size * card.scale
		var end_pos := slot_rect.get_center() - (scaled_size * 0.5)
		pending_enemy_moves += 1
		var tween := create_tween()
		tween.tween_property(card, "global_position", end_pos, 0.5)
		tween.finished.connect(_on_enemy_move_finished.bind(card, deck_index))
	if pending_enemy_moves == 0:
		current_phase = BattlePhase.IDLE
		_update_hud_state()


# ==========================================
# ESTADO: ENEMIGO ACTIVO
# ==========================================

func _register_enemy_active(card: CardView, deck_index: int) -> void:
	enemy_card_views_by_deck[deck_index] = card
	_rebuild_enemy_card_views()
	RunState.active_enemy_ids = _get_active_enemy_ids()
	if card:
		card.set_meta(CARD_ZONE_META, CARD_ZONE_ACTIVE)

	var enemy_data: Variant = RunState.get_card(card.card_id)
	if enemy_data != null:
		card.refresh(enemy_data)

	current_phase = BattlePhase.ENEMY_ACTIVE
	_update_hud_state()
	_update_initiative_chance_for_active_enemy()

	if auto_combat_enabled and pending_enemy_moves == 0:
		await get_tree().process_frame
		_start_combat()

func _on_enemy_move_finished(card: CardView, deck_index: int) -> void:
	card.update_pivot_to_center()
	card.flip_to_front()
	pending_enemy_moves = max(0, pending_enemy_moves - 1)
	_register_enemy_active(card, deck_index)

# ==========================================
# MUERTE DE ENEMIGO
# ==========================================

func on_enemy_defeated() -> void:
	if enemy_slots.is_empty():
		return
	for slot in enemy_slots:
		if slot.get_child_count() > 0:
			slot.get_child(0).queue_free()
			return

func _handle_enemy_defeated(card_id: String) -> void:
	if card_id == "":
		return
	if combat_manager != null and combat_manager.preferred_target_id == card_id:
		combat_manager.clear_preferred_target()
	var enemy_data: Dictionary = RunState.get_card(card_id)
	suppress_wave_popup_once = _is_final_boss_enemy(enemy_data)
	var is_miniboss := _is_mini_boss_enemy(enemy_data)
	RunState.active_enemy_ids = _get_active_enemy_ids()
	var victory_after_defeat: bool = not RunState.has_remaining_enemies(card_id)
	suppress_level_up_popup = victory_after_defeat

	# 1 Recompensas
	if enemy_data != null:
		RunState.apply_enemy_rewards(enemy_data)
		RunState.apply_enemy_dust(enemy_data)
		RunState.try_drop_item_from_enemy(enemy_data)
	suppress_level_up_popup = false

	var has_remaining_enemies: bool = not victory_after_defeat
	RunState.register_enemy_defeated(has_remaining_enemies)

	# 2 Eliminar del estado
	RunState.cards.erase(card_id)

	# 3 Recalcular danger level
	RunState.recalculate_danger_level()

	# 4 Visual
	_remove_enemy_view(card_id)
	var run_completed := RunState.handle_enemy_defeated_for_wave(enemy_data)
	if run_completed:
		_show_victory()
		return
	if is_miniboss:
		pending_trait_popup = true
		_show_level_up_popup(RunState.hero_level)
	if wave_popup_open:
		return
	if _get_active_enemy_ids().size() > 0:
		current_phase = BattlePhase.ENEMY_ACTIVE
		_update_hud_state()
		_update_initiative_chance_for_active_enemy()
		return
	if RunState.has_remaining_enemies():
		if crossroads_open:
			current_phase = BattlePhase.UI_LOCKED
		else:
			current_phase = BattlePhase.IDLE
		_update_hud_state()
		return
	# Si no hay enemigos y no hay encrucijada, asegurar inicio de nueva oleada.
	if RunState.current_wave <= RunState.waves_per_run and not wave_popup_open:
		RunState.start_wave_encounter()
		setup_enemy_deck()
	current_phase = BattlePhase.IDLE
	_update_hud_state()

func _open_end_of_wave_crossroads() -> void:
	if crossroads_open:
		return
	end_of_wave_pending = true
	_on_crossroads_requested()

func _connect_run_signals() -> void:
	RunState.hero_level_up.connect(_on_hero_level_up)

func _on_enemy_stats_changed() -> void:
	_refresh_all_card_views()

func _on_wave_started(_wave_index: int, _waves_total: int) -> void:
	setup_enemy_deck()
	current_phase = BattlePhase.IDLE
	_update_hud_state()

func _on_wave_completed(_wave_index: int) -> void:
	if suppress_wave_popup_once:
		suppress_wave_popup_once = false
		return
	if pending_hero_upgrades or (hero_upgrades_window != null and hero_upgrades_window.visible):
		pending_wave_popup = true
		return
	if pending_trait_popup:
		pending_wave_popup = true
		return
	if RunState.current_wave >= RunState.waves_per_run and RunState.is_current_wave_boss():
		return
	_show_wave_popup()

func _show_wave_popup() -> void:
	if wave_popup_open:
		return
	if wave_popup_scene == null:
		push_error("WavePopup scene not assigned")
		return
	if wave_popup == null:
		wave_popup = wave_popup_scene.instantiate()
		add_child(wave_popup)
		wave_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		wave_popup.z_index = 220
		wave_popup.continue_pressed.connect(_on_wave_continue)
		wave_popup.retreat_pressed.connect(_on_wave_retreat)
	wave_popup_open = true
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	get_tree().paused = true
	wave_popup.show_popup(RunState.current_wave)

func _try_show_pending_wave_popup() -> void:
	if not pending_wave_popup:
		return
	if wave_popup_open:
		return
	if pending_hero_upgrades:
		return
	if level_up_popup != null and level_up_popup.visible:
		return
	if hero_upgrades_window != null and hero_upgrades_window.visible:
		return
	pending_wave_popup = false
	_show_wave_popup()

func _on_wave_continue() -> void:
	if wave_popup == null:
		return
	wave_popup.hide_popup()
	wave_popup_open = false
	get_tree().paused = false
	if RunState.current_wave <= RunState.waves_per_run:
		RunState.start_wave_encounter()
		setup_enemy_deck()
	current_phase = BattlePhase.IDLE
	_update_hud_state()
	_try_show_pending_hero_upgrades()

func _on_wave_retreat() -> void:
	if wave_popup != null:
		wave_popup.hide_popup()
	wave_popup_open = false
	RunState.apply_withdraw_25_cost_75()
	SaveSystem.clear_run_save()
	RunState.reset_run()
	get_tree().paused = false
	if MusicManager:
		MusicManager.play_menu()
	SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")

func _on_pause_pressed() -> void:
	_toggle_pause()


func _on_hero_level_up(new_level: int) -> void:
	if suppress_level_up_popup:
		return
	RunState.save_run()
	if hero_card_view != null:
		hero_card_view.play_heal_effect()
	pending_hero_upgrades = true
	_try_show_pending_hero_upgrades()

# ==========================================
# CREAR + POSICIONAR + ESCALAR
# ==========================================

func _create_and_fit_card(slot: Control, card_data: Dictionary) -> CardView:
	if not card_view_scene:
		return null

	# Instanciar CardView
	var card: CardView = card_view_scene.instantiate()
	cards_layer.add_child(card)
	# Base size explÃƒÆ’Ã‚Â­cito para layout interno del CardView
	card.custom_minimum_size = card_base_size
	card.size = card_base_size
	# Asegurar layout fijo del Control (sin anchors dependientes del parent)
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = card_base_size.x
	card.offset_bottom = card_base_size.y
	card.pivot_offset = card_base_size * 0.5
	card.run_manager = RunState
	card.trait_overlay = trait_overlay_view
	_connect_card_input(card)

	# =========================
	# ID + REGISTRO UI
	# =========================
	if card_data.has("id"):
		card.card_id = String(card_data["id"])
		card_views[card.card_id] = card   # ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Ëœ REGISTRO CENTRAL

	# =========================
	# DEFINICIÃƒÆ’Ã¢â‚¬Å“N (Resource)
	# =========================
	var def_id: String = String(card_data["definition"])
	var card_type: String = ""
	if bool(card_data.get("is_boss", false)) or card_data.has("boss_id"):
		var boss_id: String = String(card_data.get("boss_id", def_id))
		var boss_def: BossDefinition = RunState.get_boss_definition(boss_id)
		if boss_def != null:
			card.setup_from_boss_definition(boss_def)
			card_type = "enemy"
	else:
		var definition: CardDefinition = CardDatabase.get_definition(def_id)
		if definition != null:
			var upgrade_level := int(card_data.get("upgrade_level", 0))
			card.setup_from_definition(definition, upgrade_level)
			card_type = definition.card_type

	# =========================
	# POSICIÃƒÆ’Ã¢â‚¬Å“N BASE
	# =========================
	var slot_rect: Rect2 = slot.get_global_rect()

	# =========================
	# ESCALADO VISUAL
	# =========================
	card.scale = Vector2(0.20384, 0.20384)

	# =========================
	# POSICIÃƒÆ’Ã¢â‚¬Å“N CENTRADA (GLOBAL)
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
# COMBATE - DAÃƒÆ’Ã¢â‚¬ËœO
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
		level_up_popup.z_index = 260

		level_up_popup.trait_selected.connect(_on_trait_selected)

	# Pedir traits al RunManager
	var hero_traits: Array[TraitResource] = RunState.get_random_hero_traits(3)

	level_up_popup.show_popup(
		new_level,
		hero_traits
	)

func _show_hero_upgrades_popup() -> void:
	if hero_upgrades_window_scene == null:
		push_error("[BattleTable] HeroUpgradesWindow scene not assigned")
		return
	if hero_upgrades_window == null:
		hero_upgrades_window = hero_upgrades_window_scene.instantiate()
		add_child(hero_upgrades_window)
		hero_upgrades_window.z_index = 240
		hero_upgrades_window.closed.connect(_on_hero_upgrades_closed)
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	get_tree().paused = true
	hero_upgrades_window.visible = true
	hero_upgrades_window.show_for_hero(StringName(RunState.selected_hero_def_id))
	pending_hero_upgrades = false

func _is_modal_popup_open() -> bool:
	if wave_popup_open or crossroads_open or pause_open:
		return true
	if level_up_popup != null and level_up_popup.visible:
		return true
	if hero_upgrades_window != null and hero_upgrades_window.visible:
		return true
	if victory_popup != null and victory_popup.visible:
		return true
	if defeat_popup != null and defeat_popup.visible:
		return true
	return false

func _try_show_pending_hero_upgrades() -> void:
	if not pending_hero_upgrades:
		return
	if _is_modal_popup_open():
		return
	_show_hero_upgrades_popup()

func _on_hero_upgrades_closed() -> void:
	get_tree().paused = false
	if current_phase == BattlePhase.UI_LOCKED:
		current_phase = BattlePhase.IDLE
	_update_hud_state()
	_try_show_pending_hero_upgrades()
func _on_trait_selected(hero_trait_res: TraitResource) -> void:
	print("ÃƒÂ°Ã…Â¸Ã‚Â§Ã‚Âª CONFIRMED TRAIT")
	print("   hero:", hero_trait_res)

	RunState.apply_hero_trait(hero_trait_res)
	RunState.save_run()


	# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Ëœ ACTUALIZAR VISUAL DEL HÃƒÆ’Ã¢â‚¬Â°ROE
	refresh_card_view("th")
	if hero_card_view != null:
		hero_card_view.stop_heal_effect()

	# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â¥ refrescar TODOS los enemigos existentes
	for card_id in RunState.cards.keys():
		if card_id == "th":
			continue
		refresh_card_view(card_id)



	get_tree().paused = false
	current_phase = BattlePhase.IDLE
	_update_hud_state()
	pending_trait_popup = false
	_try_show_pending_wave_popup()
	_try_show_pending_hero_upgrades()


# ==========================================
# CROSSROADS
# ==========================================
func _get_or_create_crossroads_popup() -> CrossroadsPopup:
	if crossroads_popup != null:
		return crossroads_popup
	if crossroads_popup_scene == null:
		push_error("CrossroadsPopup scene not assigned")
		return null
	crossroads_popup = crossroads_popup_scene.instantiate()
	add_child(crossroads_popup)
	crossroads_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	crossroads_popup.z_index = 150
	crossroads_popup.add_deck_pressed.connect(_on_crossroads_add_deck)
	crossroads_popup.withdraw_pressed.connect(_on_crossroads_withdraw)
	crossroads_popup.trait_pressed.connect(_on_crossroads_trait)
	crossroads_popup.popup_closed.connect(_on_crossroads_closed)
	return crossroads_popup

func _on_crossroads_requested() -> void:
	if crossroads_open:
		return
	var popup := _get_or_create_crossroads_popup()
	if popup == null:
		return
	crossroads_open = true
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	var preview: Dictionary = RunState.get_withdraw_preview()
	popup.show_popup(
		RunState.get_run_gold(),
		RunState.get_active_decks_count(),
		RunState.can_add_deck(),
		int(preview.get("withdraw", 0)),
		int(preview.get("cost", 0))
	)

func _on_crossroads_add_deck() -> void:
	RunState.add_deck()
	RunState.save_run()
	_close_crossroads_popup(false)

func _on_crossroads_withdraw() -> void:
	RunState.apply_withdraw_25_cost_75()
	RunState.save_run()
	_close_crossroads_popup(false)

func _on_crossroads_trait() -> void:
	_close_crossroads_popup(true)
	_show_level_up_popup(RunState.hero_level)

func _close_crossroads_popup(keep_paused: bool) -> void:
	if crossroads_popup == null:
		return
	crossroads_popup.hide_popup(keep_paused)

func _on_crossroads_closed() -> void:
	crossroads_open = false
	if end_of_wave_pending:
		end_of_wave_pending = false
		if RunState.try_start_next_wave():
			setup_enemy_deck()
			current_phase = BattlePhase.IDLE
			_update_hud_state()
			_try_show_pending_hero_upgrades()
		else:
			_show_victory()
		return
	if current_phase == BattlePhase.UI_LOCKED:
		current_phase = BattlePhase.IDLE
		_update_hud_state()
	_try_show_pending_hero_upgrades()


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

	# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Ëœ Si se activa el auto-combat y hay un enemigo listo,
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
	if MusicManager:
		MusicManager.play_menu()
	if MusicManager:
		MusicManager.play_menu()
	SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")

func _on_ready_for_next_round() -> void:
	if not auto_combat_enabled:
		return

	# Si hay enemigo vivo, seguimos combatiendo
	if _get_active_enemy_ids().size() > 0:
		_start_combat()

func _on_card_gui_input(event: InputEvent, card: CardView) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if current_phase == BattlePhase.UI_LOCKED:
		return
	if card == null or card.card_id == "":
		return
	if card.card_id == "th":
		return
	card.accept_event()
	_handle_card_click(card)

func _try_handle_card_click_at(global_pos: Vector2) -> void:
	var card := _get_card_at_global_pos(global_pos)
	if card == null:
		return
	_handle_card_click(card)

func _get_card_at_global_pos(global_pos: Vector2) -> CardView:
	var hovered := get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node != null and not (node is CardView):
		node = node.get_parent()
	if node is CardView:
		return node as CardView
	# Fallback manual hit test (top-most by z_index, then by insertion)
	var best: CardView = null
	var best_z := -999999
	for card_view in card_views.values():
		if not (card_view is CardView):
			continue
		var card := card_view as CardView
		if not card.is_visible_in_tree():
			continue
		var rect := Rect2(card.global_position, card.size * card.scale)
		if rect.has_point(global_pos):
			if card.z_index >= best_z:
				best_z = card.z_index
				best = card
	return best

func _handle_card_click(card: CardView) -> void:
	var zone := ""
	if card.has_meta(CARD_ZONE_META):
		zone = String(card.get_meta(CARD_ZONE_META))
	if zone == CARD_ZONE_DECK:
		_on_draw_pressed()
		return
	if zone == CARD_ZONE_ACTIVE:
		_on_enemy_card_clicked(card.card_id)

func _on_enemy_card_clicked(enemy_id: String) -> void:
	if enemy_id == "":
		return
	if current_phase != BattlePhase.ENEMY_ACTIVE:
		return
	if combat_manager != null:
		combat_manager.set_preferred_target(enemy_id)
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

func _cache_enemy_slots() -> void:
	enemy_deck_slots.clear()
	enemy_slots.clear()
	if enemy_decks_container:
		_reorder_group_children(enemy_decks_container, "DeckSlot")
		for child in enemy_decks_container.get_children():
			if child is Control:
				for slot in child.get_children():
					if slot is Control:
						enemy_deck_slots.append(slot)
	if enemy_slots_container:
		_reorder_group_children(enemy_slots_container, "Slot")
		for child in enemy_slots_container.get_children():
			if child is Control:
				for slot in child.get_children():
					if slot is Control:
						enemy_slots.append(slot)
	_sort_slots_by_name(enemy_deck_slots)
	_sort_slots_by_name(enemy_slots)
	call_deferred("_align_enemy_slots_to_decks")

func _reorder_group_children(container: Control, slot_prefix: String) -> void:
	for group in container.get_children():
		if group is Control:
			var children: Array = group.get_children()
			children.sort_custom(func(a: Node, b: Node) -> bool:
				return _slot_index_from_name(String(a.name), slot_prefix) < _slot_index_from_name(String(b.name), slot_prefix)
			)
			for i in range(children.size()):
				group.move_child(children[i], i)
			group.queue_sort()

func _sort_slots_by_name(list: Array[Control]) -> void:
	list.sort_custom(func(a: Control, b: Control) -> bool:
		return _slot_index_from_name(a.name) < _slot_index_from_name(b.name)
	)

func _slot_index_from_name(name: String, prefix: String = "") -> int:
	if prefix != "" and not name.begins_with(prefix):
		return 0
	for i in range(name.length() - 1, -1, -1):
		if not name[i].is_valid_int():
			var suffix := name.substr(i + 1)
			if suffix == "":
				return 0
			return int(suffix)
	return 0

func _apply_enemy_deck_visibility() -> void:
	var active: int = RunState.get_active_decks_count()
	for i in range(enemy_deck_slots.size()):
		enemy_deck_slots[i].visible = i < active
	for i in range(enemy_slots.size()):
		enemy_slots[i].visible = i < active

func _align_enemy_slots_to_decks() -> void:
	if enemy_deck_slots.is_empty() or enemy_slots.is_empty():
		return
	var count: int = min(enemy_deck_slots.size(), enemy_slots.size())
	for i in range(count):
		var deck_slot: Control = enemy_deck_slots[i]
		var enemy_slot: Control = enemy_slots[i]
		var deck_rect: Rect2 = deck_slot.get_global_rect()
		var slot_size: Vector2 = enemy_slot.size
		if slot_size == Vector2.ZERO:
			slot_size = enemy_slot.get_combined_minimum_size()
		var current_x: float = enemy_slot.get_global_rect().position.x
		var target_y: float = deck_rect.get_center().y - (slot_size.y * 0.5)
		enemy_slot.global_position = Vector2(current_x, target_y)

func _rebuild_enemy_card_views() -> void:
	enemy_card_views.clear()
	var keys: Array = enemy_card_views_by_deck.keys()
	keys.sort()
	for key in keys:
		var card: CardView = enemy_card_views_by_deck[key]
		if card != null and is_instance_valid(card):
			enemy_card_views.append(card)

func _get_active_enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	var keys: Array = enemy_card_views_by_deck.keys()
	keys.sort()
	for key in keys:
		var card: CardView = enemy_card_views_by_deck[key]
		if card != null and is_instance_valid(card):
			ids.append(card.card_id)
	return ids

func _get_first_active_enemy_id() -> String:
	var ids := _get_active_enemy_ids()
	if ids.is_empty():
		return ""
	return ids[0]

func _remove_enemy_view(card_id: String) -> void:
	var remove_key := -1
	for key in enemy_card_views_by_deck.keys():
		var card: CardView = enemy_card_views_by_deck[key]
		if card != null and is_instance_valid(card) and card.card_id == card_id:
			remove_key = int(key)
			break
	if remove_key != -1:
		var card: CardView = enemy_card_views_by_deck[remove_key]
		if card != null and is_instance_valid(card):
			card.queue_free()
		enemy_card_views_by_deck.erase(remove_key)
	card_views.erase(card_id)
	_rebuild_enemy_card_views()
	RunState.active_enemy_ids = _get_active_enemy_ids()

func _are_all_enemy_slots_empty() -> bool:
	var active: int = RunState.get_active_decks_count()
	for i in range(min(enemy_slots.size(), active)):
		if enemy_slots[i].get_child_count() > 0:
			return false
	return true


# ==========================================
# DRAW ENEMIGO (REAL)
# Esta funciÃƒÆ’Ã‚Â³n NO cambia estado.
# El estado se actualiza ÃƒÆ’Ã‚Âºnicamente cuando
# la carta llega al slot (_set_enemy_active)
# ==========================================

func _draw_enemy() -> void:
	# VerificaciÃƒÆ’Ã‚Â³n de seguridad: solo robamos si la mesa estÃƒÆ’Ã‚Â¡ vacÃƒÆ’Ã‚Â­a (IDLE)
	if current_phase != BattlePhase.IDLE:
		return
	# Cambiamos a RESOLVING inmediatamente para bloquear otros robos
	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()
	spawn_enemies_from_decks()

# ==========================================
# COMBATE
# ==========================================

func _start_combat() -> void:
	var enemy_ids := _get_active_enemy_ids()
	if enemy_ids.is_empty():
		return

	if current_phase == BattlePhase.UI_LOCKED:
		return

	current_phase = BattlePhase.UI_LOCKED
	_update_hud_state()

	_update_initiative_chance_for_active_enemy()
	combat_manager.start_combat(enemy_ids)


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
		defeat_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		defeat_popup.z_index = 100
		# ConexiÃƒÆ’Ã‚Â³n segura
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

func _is_final_boss_enemy(enemy_data: Dictionary) -> bool:
	if enemy_data.is_empty():
		return false
	var is_boss: bool = bool(enemy_data.get("is_boss", false)) or enemy_data.has("boss_id")
	if not is_boss:
		return false
	var boss_kind := int(enemy_data.get("boss_kind", BossDefinition.BossKind.MINI_BOSS))
	return boss_kind == BossDefinition.BossKind.FINAL_BOSS

func _is_mini_boss_enemy(enemy_data: Dictionary) -> bool:
	if enemy_data.is_empty():
		return false
	var is_boss: bool = bool(enemy_data.get("is_boss", false)) or enemy_data.has("boss_id")
	if not is_boss:
		return false
	var boss_kind := int(enemy_data.get("boss_kind", BossDefinition.BossKind.MINI_BOSS))
	return boss_kind == BossDefinition.BossKind.MINI_BOSS


######################################
#EFECTOS VISUALES
#######################################

# ==========================================
# ANIMACIÃƒÆ’Ã¢â‚¬Å“N DE ATAQUE (HOVER + TAMBALÃƒÆ’Ã¢â‚¬Â°O)
# ==========================================

func _play_attack_animation(attacker: CardView, target: CardView) -> void:
	if attacker == null or target == null:
		return
	var original_z := attacker.z_index
	attacker.z_index = max(attacker.z_index, target.z_index) + 1

	# Posiciones base
	var start_pos: Vector2 = attacker.global_position
	var target_pos: Vector2 = target.global_position

	# DirecciÃƒÆ’Ã‚Â³n hacia el objetivo
	var direction: Vector2 = (target_pos - start_pos).normalized()

	# =========================
	# PARÃƒÆ’Ã‚ÂMETROS DE ANIMACIÃƒÆ’Ã¢â‚¬Å“N
	# =========================

	var lift_height := 35.0              # cuÃƒÆ’Ã‚Â¡nto flota
	var attack_distance := 0.85          # porcentaje de la distancia real
	var wiggle_amount := 10.0            # tambaleo lateral
	var impact_recoil := 12.0            # pequeÃƒÆ’Ã‚Â±o rebote al impactar

	# CÃƒÆ’Ã‚Â¡lculos
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

	# 1ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Levantar carta (hover)
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset,
		0.15
	)

	# 2ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Tambaleo 1
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset + perpendicular * wiggle_amount,
		0.08
	)

	# 3ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Tambaleo 2 (lado contrario)
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset - perpendicular * wiggle_amount,
		0.08
	)

	# 4ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Avance fuerte hacia el enemigo
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset + attack_offset,
		0.12
	)

	# 5ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Micro recoil (impacto)
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset + attack_offset - direction * impact_recoil,
		0.06
	)

	# 6ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Volver a hover
	tween.tween_property(
		attacker,
		"global_position",
		start_pos + lift_offset,
		0.12
	)

	# 7ÃƒÂ¯Ã‚Â¸Ã‚ÂÃƒÂ¢Ã†â€™Ã‚Â£ Volver a la mesa
	tween.tween_property(
		attacker,
		"global_position",
		start_pos,
		0.15
	)

	await tween.finished
	if attacker != null and is_instance_valid(attacker):
		attacker.z_index = original_z

# ==========================================
# COMBAT MANAGER ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ VISUAL
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
		auto_draw_enabled = false
		auto_combat_enabled = false
		_show_defeat()
		RunState.save_run()
		return

	var enemy_data: Dictionary = RunState.get_card(card_id)
	var def_id: String = String(enemy_data.get("definition", ""))
	var deck_index: int = int(enemy_data.get("deck_index", 0))
	RunState.active_enemy_ids = _get_active_enemy_ids()
	_handle_enemy_defeated(card_id)
	if def_id != "":
		RunState.remove_run_deck_type(def_id, deck_index)
	RunState.save_run()

func _on_combat_finished(victory: bool) -> void:
	if victory:
		current_phase = BattlePhase.IDLE
	else:
		var hero: Dictionary = RunState.get_card("th")
		if not hero.is_empty() and int(hero.get("current_hp", 0)) <= 0:
			current_phase = BattlePhase.UI_LOCKED
		else:
			current_phase = BattlePhase.ENEMY_ACTIVE if _get_active_enemy_ids().size() > 0 else BattlePhase.IDLE

	_update_hud_state()

# ==========================================
# UTILIDAD
# ==========================================
func _get_card_view(card_id: String) -> CardView:
	if hero_card_view and hero_card_view.card_id == card_id:
		return hero_card_view
	if card_views.has(card_id):
		return card_views[card_id]
	return null

func _restore_active_enemies_if_needed() -> void:
	if RunState.active_enemy_ids.is_empty():
		return
	if enemy_slots_container == null:
		return
	_cache_enemy_slots()
	_apply_enemy_deck_visibility()
	enemy_card_views_by_deck.clear()
	for enemy_id in RunState.active_enemy_ids:
		var enemy_data: Dictionary = RunState.get_card(enemy_id)
		if enemy_data.is_empty():
			continue
		var deck_index := int(enemy_data.get("deck_index", 0))
		if deck_index < 0 or deck_index >= enemy_slots.size():
			continue
		var slot := enemy_slots[deck_index]
		var existing: CardView = card_views.get(enemy_id, null)
		var card: CardView = existing
		if card == null:
			card = _create_and_fit_card(slot, enemy_data)
		else:
			card.run_manager = RunState
			card.trait_overlay = trait_overlay_view
		if card == null:
			continue
		card.reparent(slot, true)
		card.set_meta(CARD_ZONE_META, CARD_ZONE_ACTIVE)
		card.show_front()
		card.refresh(enemy_data)
		enemy_card_views_by_deck[deck_index] = card
	_rebuild_enemy_card_views()
	RunState.active_enemy_ids = _get_active_enemy_ids()
	current_phase = BattlePhase.ENEMY_ACTIVE if enemy_card_views.size() > 0 else BattlePhase.IDLE
	_update_hud_state()
	_update_initiative_chance_for_active_enemy()

func _update_initiative_chance_for_active_enemy() -> void:
	if battle_hud == null:
		return
	var hero: Dictionary = RunState.get_card("th")
	if hero.is_empty():
		battle_hud.update_initiative_chance(0.0)
		return
	var enemy_id := _get_first_active_enemy_id()
	if enemy_id == "":
		battle_hud.update_initiative_chance(0.0)
		return
	var enemy: Dictionary = RunState.get_card(enemy_id)
	if enemy.is_empty():
		battle_hud.update_initiative_chance(0.0)
		return
	var raw_traits: Variant = enemy.get("boss_trait_ids", [])
	var trait_ids: Array[String] = []
	if raw_traits is Array:
		for entry in raw_traits:
			trait_ids.append(String(entry))
	for trait_id in trait_ids:
		if trait_id == "preternatural_initiative":
			battle_hud.update_initiative_chance(0.0)
			return
	var hero_init: int = int(hero.get("initiative", 0))
	var enemy_init: int = int(enemy.get("initiative", 0))
	var p: float = CombatManager.calc_hero_first_chance(hero_init, enemy_init)
	battle_hud.update_initiative_chance(p)

func _has_remaining_enemies() -> bool:
	return RunState.has_remaining_enemies()

func _has_remaining_enemies_after_defeat(defeated_id: String) -> bool:
	return RunState.has_remaining_enemies(defeated_id)

func _connect_card_input(card: CardView) -> void:
	if card == null:
		return
	var callable := Callable(self, "_on_card_gui_input").bind(card)
	if card.gui_input.is_connected(callable):
		return
	card.gui_input.connect(callable)

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
	_try_show_pending_hero_upgrades()

func _on_pause_menu_pressed() -> void:
	RunState.save_run()
	get_tree().paused = false
	if MusicManager:
		MusicManager.play_menu()
	SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")
