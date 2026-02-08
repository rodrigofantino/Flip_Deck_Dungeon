extends Control

@export var design_resolution: Vector2 = Vector2(1280, 720)

@onready var book_view: Control = $BookView
@onready var prev_button: Button = $TopBar/PrevButton
@onready var next_button: Button = $TopBar/NextButton
@onready var title_label: Label = $TopBar/TitleLabel
@onready var page_label: Label = $TopBar/PageLabel
@onready var upgrades_button: Button = $TopBar/UpgradesButton
@onready var selection_panel: VBoxContainer = $SelectionPanel
@onready var select_hero_label: Label = $SelectionPanel/SelectHeroLabel
@onready var select_enemies_label: Label = $SelectionPanel/SelectEnemiesLabel
@onready var selection_error_label: Label = $SelectionPanel/SelectionErrorLabel
@onready var start_dungeon_button: Button = $SelectionPanel/StartDungeonButton
@onready var back_button: Button = $SelectionPanel/BackButton
@onready var item_type_panel: VBoxContainer = $SelectionPanel/ItemTypeDistribution
@onready var label_helmet: Label = $SelectionPanel/ItemTypeDistribution/RowHelmet/LabelHelmet
@onready var label_armour: Label = $SelectionPanel/ItemTypeDistribution/RowArmour/LabelArmour
@onready var label_gloves: Label = $SelectionPanel/ItemTypeDistribution/RowGloves/LabelGloves
@onready var label_boots: Label = $SelectionPanel/ItemTypeDistribution/RowBoots/LabelBoots
@onready var label_one_hand: Label = $SelectionPanel/ItemTypeDistribution/RowOneHand/LabelOneHand
@onready var label_two_hands: Label = $SelectionPanel/ItemTypeDistribution/RowTwoHands/LabelTwoHands
@onready var bar_helmet: ProgressBar = $SelectionPanel/ItemTypeDistribution/RowHelmet/BarHelmet
@onready var bar_armour: ProgressBar = $SelectionPanel/ItemTypeDistribution/RowArmour/BarArmour
@onready var bar_gloves: ProgressBar = $SelectionPanel/ItemTypeDistribution/RowGloves/BarGloves
@onready var bar_boots: ProgressBar = $SelectionPanel/ItemTypeDistribution/RowBoots/BarBoots
@onready var bar_one_hand: ProgressBar = $SelectionPanel/ItemTypeDistribution/RowOneHand/BarOneHand
@onready var bar_two_hands: ProgressBar = $SelectionPanel/ItemTypeDistribution/RowTwoHands/BarTwoHands
@onready var booster_area: Control = $BoosterArea
@onready var booster_list: VBoxContainer = $BoosterArea/BoosterList
@onready var booster_popup: Control = $BoosterPopup
@onready var booster_popup_title: Label = $BoosterPopup/Panel/Content/TitleLabel
@onready var booster_popup_preview: ColorRect = $BoosterPopup/Panel/Content/Preview
@onready var booster_popup_name: Label = $BoosterPopup/Panel/Content/NameLabel
@onready var booster_popup_open: Button = $BoosterPopup/Panel/Content/Buttons/OpenButton
@onready var booster_popup_back: Button = $BoosterPopup/Panel/Content/Buttons/BackButton
@onready var booster_popup_dimmer: ColorRect = $BoosterPopup/Dimmer
@onready var open_popup: Control = $OpenPackPopup
@onready var open_popup_dimmer: ColorRect = $OpenPackPopup/Dimmer
@onready var open_popup_title: Label = $OpenPackPopup/Panel/Content/TitleLabel
@onready var open_popup_cards: Control = $OpenPackPopup/Panel/Content/CardsContainer
@onready var open_popup_add_all: Button = $OpenPackPopup/Panel/Content/Buttons/AddAllButton
@onready var open_popup_back: Button = $OpenPackPopup/Panel/Content/Buttons/BackButton
@onready var card_popup: Control = $CardPopup
@onready var card_popup_dimmer: ColorRect = $CardPopup/Dimmer
@onready var card_popup_container: Control = $CardPopup/Panel/Content/CardContainer
@onready var card_popup_count: Label = $CardPopup/Panel/Content/CountLabel
@onready var card_popup_upgrade: Button = $CardPopup/Panel/Content/Buttons/UpgradeButton
@onready var card_popup_back: Button = $CardPopup/Panel/Content/Buttons/BackButton

const PACK_STACK_OFFSET_X: float = 2.0
const PACK_STACK_OFFSET_Y: float = 2.0
const PACK_STACK_MAX: int = 12
const PACK_PREVIEW_SIZE: Vector2 = Vector2(140, 80)
const PACK_FOREST_COLOR: Color = Color(0.6, 0.85, 0.6, 1.0)
const PACK_DARK_FOREST_COLOR: Color = Color(0.12, 0.35, 0.2, 1.0)
const PACK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_forest.tres"
const PACK_DARK_FOREST_PATH: String = "res://data/booster_packs/booster_pack_dark_forest.tres"
const OPEN_CARD_OFFSET: Vector2 = Vector2(2.0, 2.0)
const OPEN_CARD_BASE: Vector2 = Vector2(620, 860)
const OPEN_CARD_DISPLAY: Vector2 = Vector2(155, 215)
const OPEN_CARDS_PER_PACK: int = 5
const OPEN_CARD_FLY_DURATION: float = 0.45
const OPEN_CARD_FLY_MAX_WAIT: float = 1.2
const BIOME_FOREST: String = "Forest"
const BIOME_DARK_FOREST: String = "Dark Forest"
const CARD_VIEW_SCENE: PackedScene = preload("res://Scenes/cards/card_view.tscn")
const HERO_UPGRADES_SCENE: PackedScene = preload("res://Scenes/ui/hero_upgrades_window.tscn")

class PackView:
	var pack_type: String
	var name_key: String
	var color: Color

var selection_mode: bool = false
var selected_hero_def_id: String = ""
var selected_enemy_weights: Dictionary = {}
var selected_pack: PackView = null
var open_defs: Array[CardDefinition] = []
var open_cards: Array[CardView] = []
var open_collection: PlayerCollection = null
var _pending_book_refresh: bool = false
var _popup_def: CardDefinition = null
var _selection_error_override: String = ""
var hero_upgrades_window: HeroUpgradesWindow = null
var _last_weight_click_ms: Dictionary = {}

const MIN_ENEMY_SELECTION: int = 2
const MAX_ENEMY_SELECTION: int = 5
const MIN_ENEMY_WEIGHT: int = 1
const MAX_ENEMY_WEIGHT: int = 3
const WEIGHT_CLICK_DEBOUNCE_MS: int = 80

const ITEM_TYPE_ORDER: Array[int] = [
	CardDefinition.ItemType.HELMET,
	CardDefinition.ItemType.ARMOUR,
	CardDefinition.ItemType.GLOVES,
	CardDefinition.ItemType.BOOTS,
	CardDefinition.ItemType.ONE_HAND,
	CardDefinition.ItemType.TWO_HANDS
]

func _ready() -> void:
	_configure_design_layout()
	add_to_group("collection_root")
	set_process_input(true)
	_wire_ui()
	_setup_book_view()
	_refresh_boosters()
	_init_selection_ui()
	_set_booster_interactivity(true)
	_refresh_book_content()
	_update_book_input_block()

func _configure_design_layout() -> void:
	size = design_resolution
	call_deferred("_apply_design_layout")
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_apply_design_layout)

func _apply_design_layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var view := vp.get_visible_rect().size
	if view == Vector2.ZERO:
		return
	var ratio: float = min(view.x / design_resolution.x, view.y / design_resolution.y)
	scale = Vector2.ONE * ratio
	size = design_resolution
	position = (view - design_resolution * ratio) * 0.5
	if book_view and book_view.has_method("refresh_layout"):
		book_view.call_deferred("refresh_layout")

func _wire_ui() -> void:
	if title_label:
		title_label.text = tr("COLLECTION_TITLE")
	if prev_button:
		prev_button.text = tr("COLLECTION_PREV")
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.text = tr("COLLECTION_NEXT")
		next_button.pressed.connect(_on_next_pressed)
	if page_label:
		page_label.visible = false
	if upgrades_button:
		upgrades_button.text = tr("COLLECTION_UPGRADES_BUTTON")
		upgrades_button.pressed.connect(_on_upgrades_pressed)
	if back_button:
		back_button.pressed.connect(func() -> void:
			SceneTransition.change_scene("res://Scenes/ui/main_menu.tscn")
		)
	if booster_popup and booster_popup_title:
		booster_popup_title.text = tr("COLLECTION_BOOSTER_POPUP_TITLE")
	if booster_popup_open:
		booster_popup_open.text = tr("COLLECTION_BOOSTER_OPEN")
		booster_popup_open.pressed.connect(_on_booster_open_pressed)
	if booster_popup_back:
		booster_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		booster_popup_back.pressed.connect(_close_booster_popup)
	if open_popup_title:
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE")
	if open_popup_add_all:
		open_popup_add_all.text = tr("COLLECTION_OPEN_ADD_ALL")
		open_popup_add_all.pressed.connect(_on_add_all_pressed)
	if open_popup_back:
		open_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		open_popup_back.pressed.connect(_close_open_popup)
	if card_popup_back:
		card_popup_back.text = tr("COLLECTION_BOOSTER_BACK")
		card_popup_back.pressed.connect(_close_card_popup)
	if card_popup_upgrade:
		card_popup_upgrade.pressed.connect(_on_card_upgrade_pressed)
	if open_popup != null and open_popup_cards != null:
		open_popup_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup != null:
		booster_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	if booster_popup_dimmer:
		booster_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		booster_popup_dimmer.gui_input.connect(_on_popup_dimmer_gui_input)
	if open_popup_dimmer:
		open_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		open_popup_dimmer.gui_input.connect(_on_popup_dimmer_gui_input)
	if card_popup_dimmer:
		card_popup_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		card_popup_dimmer.gui_input.connect(_on_popup_dimmer_gui_input)
	if card_popup:
		card_popup.mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if book_view == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_click_blocked_by_ui(event.global_position):
			return
		if book_view.has_method("try_open_from_click"):
			var opened := bool(book_view.call("try_open_from_click", event.global_position))
			if opened:
				accept_event()

func _is_click_blocked_by_ui(global_pos: Vector2) -> bool:
	var blockers: Array[Control] = []
	if selection_panel and selection_panel.visible:
		blockers.append(selection_panel)
	if booster_popup and booster_popup.visible:
		blockers.append(booster_popup)
	if open_popup and open_popup.visible:
		blockers.append(open_popup)
	if card_popup and card_popup.visible:
		blockers.append(card_popup)
	if hero_upgrades_window and hero_upgrades_window.visible:
		blockers.append(hero_upgrades_window)
	for ctrl in blockers:
		if ctrl and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(global_pos):
			return true
	return false

func _is_modal_popup_visible() -> bool:
	return (
		(booster_popup and booster_popup.visible)
		or (open_popup and open_popup.visible)
		or (card_popup and card_popup.visible)
		or (hero_upgrades_window and hero_upgrades_window.visible)
	)

func _update_book_input_block() -> void:
	if book_view == null:
		return
	var modal := _is_modal_popup_visible()
	if book_view.has_method("set_input_blocked"):
		book_view.call("set_input_blocked", modal)
	_set_slots_input_enabled(not modal)

func _set_slots_input_enabled(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE
	for node in get_tree().get_nodes_in_group("collection_slots"):
		if node is Control:
			(node as Control).mouse_filter = filter

func _on_popup_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _setup_book_view() -> void:
	if book_view == null:
		return
	book_view.visible = true
	if book_view.has_method("force_show"):
		book_view.call("force_show")
	var book: PageFlip2D = _get_book() as PageFlip2D
	if book == null:
		return
	var anim_player: AnimationPlayer = book.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player and anim_player is AnimationPlayer:
		var cb := Callable(self, "_on_book_animation_finished")
		if not anim_player.is_connected("animation_finished", cb):
			anim_player.animation_finished.connect(cb)
	_update_page_label()
	_update_navigation_state()

func _get_book() -> Node:
	if book_view == null:
		return null
	var node := book_view.get_node_or_null("Book")
	if node == null:
		return null
	return node

func _refresh_book_content() -> void:
	if book_view == null:
		_update_page_label()
		_update_navigation_state()
		return
	var book_node := _get_book() as PageFlip2D
	if book_node != null and book_node.is_animating:
		_pending_book_refresh = true
		return
	_pending_book_refresh = false
	if book_view.has_method("_refresh_book_content"):
		book_view.call("_refresh_book_content")
	_update_page_label()
	_update_navigation_state()

func _on_book_animation_finished(_name: String) -> void:
	_update_page_label()
	_update_navigation_state()
	if _pending_book_refresh:
		call_deferred("_refresh_book_content")

func _update_page_label() -> void:
	if page_label == null:
		return
	var book: PageFlip2D = _get_book() as PageFlip2D
	if book == null:
		page_label.text = tr("COLLECTION_PAGE_LABEL") % [1, 2]
		return
	var total_spreads: int = book.total_spreads
	var spread_idx: int = clamp(book.current_spread, 0, max(total_spreads - 1, 0))
	var page_left: int = (spread_idx * 2) + 1
	var page_right: int = page_left + 1
	if page_left < 1:
		page_left = 1
	if page_right < page_left:
		page_right = page_left
	page_label.text = tr("COLLECTION_PAGE_LABEL") % [page_left, page_right]

func _update_navigation_state() -> void:
	var book: PageFlip2D = _get_book() as PageFlip2D
	if prev_button:
		prev_button.disabled = book == null or book.is_animating or book.current_spread <= -1
	if next_button:
		next_button.disabled = book == null or book.is_animating or book.current_spread >= book.total_spreads

func _init_selection_ui() -> void:
	selection_mode = RunState.selection_pending
	print("[Collection] selection_pending=", RunState.selection_pending)
	if selection_panel:
		selection_panel.visible = true
		_configure_selection_panel_input()
	if selection_mode:
		_reset_selection_state()
	_set_booster_interactivity(true)
	if select_hero_label:
		select_hero_label.text = tr("COLLECTION_SELECT_HERO")
		select_hero_label.visible = selection_mode
	if select_enemies_label:
		select_enemies_label.text = tr("COLLECTION_SELECT_ENEMIES")
		select_enemies_label.visible = selection_mode
	if start_dungeon_button:
		start_dungeon_button.text = tr("COLLECTION_START_DUNGEON")
		start_dungeon_button.pressed.connect(_on_start_dungeon_pressed)
		start_dungeon_button.visible = selection_mode
	if item_type_panel:
		item_type_panel.visible = selection_mode
	if selection_error_label:
		selection_error_label.text = ""
		selection_error_label.visible = selection_mode
	_update_selection_state()
	if not selection_mode:
		_clear_selection_visuals()

func _configure_selection_panel_input() -> void:
	if selection_panel == null:
		return
	_set_mouse_filter_recursive(selection_panel, Control.MOUSE_FILTER_IGNORE)
	if start_dungeon_button:
		start_dungeon_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if back_button:
		back_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _clear_selection_visuals() -> void:
	for slot in get_tree().get_nodes_in_group("collection_slots"):
		if slot is CollectionSlot:
			(slot as CollectionSlot).set_selected(false)
			(slot as CollectionSlot).configure_run_controls(false, false, false, MIN_ENEMY_WEIGHT)

func _reset_selection_state() -> void:
	selected_hero_def_id = ""
	selected_enemy_weights.clear()
	_selection_error_override = ""
	_last_weight_click_ms.clear()
	if selection_error_label:
		selection_error_label.text = ""

func _on_page_slot_clicked(slot: CollectionSlot) -> void:
	if slot == null:
		return
	if RunState.selection_pending and not selection_mode:
		selection_mode = true
	if not selection_mode:
		if slot.current_card_type == "hero":
			_open_hero_upgrades()
		else:
			_open_card_popup(slot)
		return
	if not slot.is_obtained:
		return
	if slot.current_def_id == "":
		return
	if slot.current_card_type == "hero":
		if selected_hero_def_id == slot.current_def_id:
			selected_hero_def_id = ""
		else:
			selected_hero_def_id = slot.current_def_id
	elif slot.current_card_type == "enemy":
		_cycle_enemy_weight(slot.current_def_id, 1)
	_update_selection_state()

func _on_page_slot_right_clicked(slot: CollectionSlot) -> void:
	if slot == null:
		return
	if RunState.selection_pending and not selection_mode:
		selection_mode = true
	if not selection_mode:
		return
	if not slot.is_obtained:
		return
	if slot.current_def_id == "":
		return
	if slot.current_card_type != "enemy":
		return
	_cycle_enemy_weight(slot.current_def_id, -1)
	_update_selection_state()

func _on_page_enemy_selected(slot: CollectionSlot, selected: bool) -> void:
	if not selection_mode or slot == null:
		return
	if slot.current_card_type != "enemy":
		return
	_set_enemy_selected(slot.current_def_id, selected)
	_update_selection_state()

func _on_page_enemy_weight_changed(slot: CollectionSlot, weight: int) -> void:
	if not selection_mode or slot == null:
		return
	if slot.current_card_type != "enemy":
		return
	_set_enemy_weight(slot.current_def_id, weight)
	_update_selection_state()

func _update_slot_selection(slot: CollectionSlot) -> void:
	if slot == null:
		return
	var selected := false
	if slot.current_card_type == "hero":
		selected = slot.current_def_id == selected_hero_def_id
	elif slot.current_card_type == "enemy":
		selected = selected_enemy_weights.has(slot.current_def_id)
	print("[Collection] slot select:", slot.current_def_id, " type=", slot.current_card_type, " selected=", selected)
	slot.set_selected(selected)
	var show_controls := selection_mode and slot.current_card_type == "enemy" and slot.is_obtained
	var weight := int(selected_enemy_weights.get(slot.current_def_id, 0))
	slot.configure_run_controls(show_controls, selection_mode, selected, weight)
	if show_controls:
		var spawn_weight := int(selected_enemy_weights.get(slot.current_def_id, 0))
		var overlay_text := _build_enemy_item_type_overlay(slot.current_def_id, spawn_weight)
		slot.configure_item_type_overlay(true, overlay_text)
	else:
		slot.configure_item_type_overlay(false, "")

func _update_selection_state() -> void:
	if not selection_mode:
		if select_hero_label:
			select_hero_label.visible = false
		if select_enemies_label:
			select_enemies_label.visible = false
		if item_type_panel:
			item_type_panel.visible = false
		if start_dungeon_button:
			start_dungeon_button.visible = false
		_clear_selection_visuals()
		return
	var has_hero := selected_hero_def_id != ""
	var enemy_count := selected_enemy_weights.size()
	var has_enemies := enemy_count >= MIN_ENEMY_SELECTION
	if select_hero_label:
		_set_hint_visible(select_hero_label, not has_hero)
	if select_enemies_label:
		_set_hint_visible(select_enemies_label, not has_enemies)
	if start_dungeon_button:
		start_dungeon_button.disabled = not (has_hero and has_enemies and enemy_count <= MAX_ENEMY_SELECTION)
	if selection_error_label:
		selection_error_label.text = _get_selection_error()
		selection_error_label.visible = selection_mode and selection_error_label.text != ""
	for slot in get_tree().get_nodes_in_group("collection_slots"):
		if slot is CollectionSlot:
			_update_slot_selection(slot)
	_update_item_type_distribution()

func _set_enemy_selected(enemy_id: String, selected: bool) -> void:
	if enemy_id == "":
		return
	if selected:
		if selected_enemy_weights.size() >= MAX_ENEMY_SELECTION:
			_selection_error_override = tr("COLLECTION_ERROR_MAX_ENEMIES").format({
				"value": MAX_ENEMY_SELECTION
			})
			return
		if not selected_enemy_weights.has(enemy_id):
			selected_enemy_weights[enemy_id] = MIN_ENEMY_WEIGHT
	else:
		if selected_enemy_weights.has(enemy_id):
			selected_enemy_weights.erase(enemy_id)
	_selection_error_override = ""

func _set_enemy_weight(enemy_id: String, weight: int) -> void:
	if enemy_id == "":
		return
	if not selected_enemy_weights.has(enemy_id):
		return
	var clamped := clampi(weight, MIN_ENEMY_WEIGHT, MAX_ENEMY_WEIGHT)
	selected_enemy_weights[enemy_id] = clamped

func _cycle_enemy_weight(enemy_id: String, direction: int) -> void:
	if enemy_id == "":
		return
	var now := Time.get_ticks_msec()
	var last := int(_last_weight_click_ms.get(enemy_id, -999999))
	if (now - last) < WEIGHT_CLICK_DEBOUNCE_MS:
		return
	_last_weight_click_ms[enemy_id] = now
	var current := int(selected_enemy_weights.get(enemy_id, 0))
	var next := current
	if current == 0:
		if selected_enemy_weights.size() >= MAX_ENEMY_SELECTION:
			_selection_error_override = tr("COLLECTION_ERROR_MAX_ENEMIES").format({
				"value": MAX_ENEMY_SELECTION
			})
			return
		next = MAX_ENEMY_WEIGHT if direction < 0 else MIN_ENEMY_WEIGHT
		selected_enemy_weights[enemy_id] = next
		_selection_error_override = ""
		return

	if direction > 0:
		if current >= MAX_ENEMY_WEIGHT:
			selected_enemy_weights.erase(enemy_id)
		else:
			selected_enemy_weights[enemy_id] = current + 1
	else:
		if current <= MIN_ENEMY_WEIGHT:
			selected_enemy_weights.erase(enemy_id)
		else:
			selected_enemy_weights[enemy_id] = current - 1
	_selection_error_override = ""

func _get_selection_error() -> String:
	if _selection_error_override != "":
		return _selection_error_override
	var count := selected_enemy_weights.size()
	if count < MIN_ENEMY_SELECTION:
		return tr("COLLECTION_ERROR_MIN_ENEMIES").format({
			"value": MIN_ENEMY_SELECTION
		})
	if count > MAX_ENEMY_SELECTION:
		return tr("COLLECTION_ERROR_MAX_ENEMIES").format({
			"value": MAX_ENEMY_SELECTION
		})
	return ""

func _build_item_type_scores() -> Dictionary:
	var scores: Dictionary = {}
	for item_type in ITEM_TYPE_ORDER:
		scores[item_type] = 0

	for enemy_id in selected_enemy_weights.keys():
		var spawn_weight := int(selected_enemy_weights.get(enemy_id, 0))
		if spawn_weight <= 0:
			continue
		var def: CardDefinition = CardDatabase.get_definition(String(enemy_id))
		if def == null:
			continue
		var weights: Dictionary = def.get_allowed_item_type_weights()
		for item_type in ITEM_TYPE_ORDER:
			var weight := int(weights.get(item_type, 0))
			if weight <= 0:
				continue
			var current := int(scores.get(item_type, 0))
			scores[item_type] = current + (spawn_weight * weight)

	return scores

func _update_item_type_distribution() -> void:
	if item_type_panel == null:
		return
	var scores: Dictionary = _build_item_type_scores()
	var total: int = 0
	for item_type in ITEM_TYPE_ORDER:
		total += int(scores.get(item_type, 0))

	_update_distribution_row(label_helmet, bar_helmet, CardDefinition.ItemType.HELMET, scores, total)
	_update_distribution_row(label_armour, bar_armour, CardDefinition.ItemType.ARMOUR, scores, total)
	_update_distribution_row(label_gloves, bar_gloves, CardDefinition.ItemType.GLOVES, scores, total)
	_update_distribution_row(label_boots, bar_boots, CardDefinition.ItemType.BOOTS, scores, total)
	_update_distribution_row(label_one_hand, bar_one_hand, CardDefinition.ItemType.ONE_HAND, scores, total)
	_update_distribution_row(label_two_hands, bar_two_hands, CardDefinition.ItemType.TWO_HANDS, scores, total)

func _update_distribution_row(label: Label, bar: ProgressBar, item_type: int, scores: Dictionary, total: int) -> void:
	if label == null or bar == null:
		return
	var score := int(scores.get(item_type, 0))
	var percent: int = 0
	if total > 0:
		percent = int(round((float(score) / float(total)) * 100.0))
	label.text = "%s %d%%" % [tr(CardDefinition.get_item_type_name(item_type)), percent]
	bar.value = percent
	bar.tooltip_text = "%d%%" % percent

func _build_enemy_item_type_overlay(def_id: String, spawn_weight: int) -> String:
	var def: CardDefinition = CardDatabase.get_definition(def_id)
	if def == null:
		return ""
	var weights: Dictionary = def.get_allowed_item_type_weights()
	var total: int = 0
	for item_type in ITEM_TYPE_ORDER:
		total += int(weights.get(item_type, 0))
	if total <= 0:
		total = 1

	var lines: Array[String] = []
	lines.append(tr("COLLECTION_SPAWN_WEIGHT").format({
		"value": spawn_weight
	}))
	for item_type in ITEM_TYPE_ORDER:
		var weight := int(weights.get(item_type, 0))
		var percent := int(round((float(weight) / float(total)) * 100.0))
		var name := tr(CardDefinition.get_item_type_name(item_type))
		lines.append("%s: %d (%d%%)" % [name, weight, percent])

	return "\n".join(lines)

func _set_hint_visible(label: Label, show: bool) -> void:
	if label == null:
		return
	label.visible = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 1.0 if show else 0.0

func _set_booster_interactivity(enabled: bool) -> void:
	if booster_area:
		booster_area.visible = enabled
		booster_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_list:
		booster_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if booster_popup:
		booster_popup.visible = enabled and booster_popup.visible

func _on_start_dungeon_pressed() -> void:
	print("[Collection] StartDungeon pressed. hero=", selected_hero_def_id, " enemies=", selected_enemy_weights.size())
	var error_msg := _get_selection_error()
	if selected_hero_def_id == "" or error_msg != "":
		push_warning("[Collection] StartDungeon blocked. hero or enemies missing/invalid.")
		return
	var scene_path := "res://Scenes/battle_table.tscn"
	print("[Collection] checking scene exists:", scene_path)
	if not ResourceLoader.exists(scene_path):
		push_error("[Collection] battle_table.tscn no existe en %s" % scene_path)
		return
	print("[Collection] scene exists OK")
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_error("[Collection] No se pudo abrir battle_table.tscn. Error=%s" % str(FileAccess.get_open_error()))
	else:
		var first_line := file.get_line()
		file.close()
		print("[Collection] battle_table first line:", first_line)
	var weights: Dictionary = {}
	for key in selected_enemy_weights.keys():
		weights[String(key)] = int(selected_enemy_weights.get(key, MIN_ENEMY_WEIGHT))
	print("[Collection] enemies list size=", weights.size())
	RunState.reset_run()
	print("[Collection] RunState.reset_run OK")
	RunState.set_run_selection(selected_hero_def_id, weights)
	print("[Collection] RunState.set_run_selection OK")
	RunState.build_run_deck_from_selection()
	print("[Collection] RunState.build_run_deck_from_selection OK")
	RunState.selection_pending = false
	print("[Collection] selection_pending=false")
	var err := SceneTransition.change_scene(scene_path)
	print("[Collection] change_scene_to_file err=", err)
	if err != OK:
		_debug_battle_table_deps()
		var packed = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		var is_null: bool = packed == null
		var is_valid: bool = is_instance_valid(packed)
		var class_name_str: String = ""
		if is_valid:
			class_name_str = packed.get_class()
		print(
			"[Collection] ResourceLoader.load(scene_path)=",
			packed,
			" typeof=",
			typeof(packed),
			" null=",
			is_null,
			" valid=",
			is_valid,
			" class=",
			class_name_str
		)
		if is_null or not is_valid:
			push_error("[Collection] battle_table.tscn no cargo o es invalido")

func _debug_battle_table_deps() -> void:
	var deps := [
		"res://scripts/UI/crossroads_popup.gd",
		"res://scripts/game/battle_table.gd",
		"res://Scenes/cards/card_view.tscn",
		"res://assets/stonefglordark.png",
		"res://Scenes/ui/battle_hud.tscn",
		"res://Scenes/ui/defeat_popup.tscn",
		"res://Scenes/ui/victory_popup.tscn",
		"res://Scenes/ui/xp_hud.tscn",
		"res://Scenes/ui/level_up_popup.tscn",
		"res://Scenes/ui/crossroads_popup_fixed.tscn",
		"res://Scenes/ui/pause_popup.tscn",
	]
	for path in deps:
		var res = ResourceLoader.load(path)
		var ok := res != null and is_instance_valid(res)
		print("[Collection] dep load:", path, " ok=", ok, " type=", typeof(res))

func _on_prev_pressed() -> void:
	_change_book_page(false)

func _on_next_pressed() -> void:
	_change_book_page(true)

func _on_upgrades_pressed() -> void:
	_open_hero_upgrades()

func _open_hero_upgrades() -> void:
	if hero_upgrades_window == null:
		if HERO_UPGRADES_SCENE == null:
			return
		hero_upgrades_window = HERO_UPGRADES_SCENE.instantiate() as HeroUpgradesWindow
		if hero_upgrades_window == null:
			return
		add_child(hero_upgrades_window)
		hero_upgrades_window.z_index = 300
		hero_upgrades_window.closed.connect(_on_hero_upgrades_closed)
	hero_upgrades_window.visible = true
	hero_upgrades_window.refresh_window()
	_update_book_input_block()

func _on_hero_upgrades_closed() -> void:
	_update_book_input_block()

func _change_book_page(go_next: bool) -> void:
	var book: PageFlip2D = _get_book() as PageFlip2D
	if book == null or book.is_animating:
		return
	if go_next:
		book.next_page()
	else:
		book.prev_page()
	call_deferred("_refresh_book_change_state")

func _refresh_book_change_state() -> void:
	_update_page_label()
	_update_navigation_state()

func _open_booster_popup(pack: PackView) -> void:
	if booster_popup == null:
		return
	selected_pack = pack
	booster_popup.visible = true
	booster_popup.z_index = 150
	_update_book_input_block()
	if booster_popup_name:
		var display_name := pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
		booster_popup_name.text = display_name
	if booster_popup_preview:
		booster_popup_preview.color = pack.color

func _close_booster_popup() -> void:
	if booster_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(booster_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		booster_popup.visible = false
		booster_popup.modulate.a = 1.0
		_update_book_input_block()
	)

func _on_booster_open_pressed() -> void:
	if selected_pack == null:
		return
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	if not collection.remove_booster(selected_pack.pack_type, 1):
		_close_booster_popup()
		return
	SaveSystem.save_collection(collection)
	_refresh_boosters()
	_close_booster_popup_and_open(selected_pack)

func _close_booster_popup_and_open(pack: PackView) -> void:
	if booster_popup == null:
		_open_pack_popup(pack)
		return
	var tween := create_tween()
	tween.tween_property(booster_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		booster_popup.visible = false
		booster_popup.modulate.a = 1.0
		_update_book_input_block()
		_open_pack_popup(pack)
	)

func _open_pack_popup(pack: PackView) -> void:
	if open_popup == null or open_popup_cards == null:
		return
	open_popup.visible = true
	open_popup.z_index = 200
	open_popup.modulate.a = 0.0
	open_popup.scale = Vector2(0.95, 0.95)
	_update_book_input_block()
	open_collection = SaveSystem.load_collection()
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	_clear_open_cards()
	open_defs.clear()
	var pool := _get_pack_pool(pack.pack_type)
	if pool.is_empty():
		return
	if open_popup_title:
		var display_name := pack.pack_type
		if pack.name_key != "":
			display_name = tr(pack.name_key)
		open_popup_title.text = tr("COLLECTION_OPEN_POPUP_TITLE_NAME") % display_name
	_play_open_popup_in()
	for i in range(OPEN_CARDS_PER_PACK):
		var card_def := pool[randi() % pool.size()]
		open_defs.append(card_def)
	call_deferred("_add_open_cards_visual", open_defs)

func _add_open_cards_visual(defs: Array[CardDefinition]) -> void:
	if open_popup_cards == null:
		return
	_clear_open_cards()
	for i in range(defs.size()):
		var card_def := defs[i]
		var card := CARD_VIEW_SCENE.instantiate() as CardView
		if card == null:
			continue
		open_popup_cards.add_child(card)
		card.custom_minimum_size = OPEN_CARD_BASE
		card.size = OPEN_CARD_BASE
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.offset_left = 0.0
		card.offset_top = 0.0
		card.offset_right = OPEN_CARD_BASE.x
		card.offset_bottom = OPEN_CARD_BASE.y
		card.setup_from_definition(card_def, 0)
		card.show_front()
		_set_mouse_filter_recursive(card, Control.MOUSE_FILTER_IGNORE)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var scale_w := OPEN_CARD_DISPLAY.x / OPEN_CARD_BASE.x
		var scale_h := OPEN_CARD_DISPLAY.y / OPEN_CARD_BASE.y
		var final_scale := minf(scale_w, scale_h)
		card.scale = Vector2(final_scale, final_scale)
		var scaled_size := OPEN_CARD_BASE * final_scale
		var base_pos := (open_popup_cards.size * 0.5) - (scaled_size * 0.5)
		card.position = base_pos + Vector2(OPEN_CARD_OFFSET.x * float(i), OPEN_CARD_OFFSET.y * float(i))
		card.z_index = i
		open_cards.append(card)
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				card.accept_event()
				_on_open_card_clicked(card)
		)

func _on_open_card_clicked(card: CardView) -> void:
	var index := open_cards.find(card)
	if index < 0:
		return
	if open_cards.size() > 0 and card != open_cards[open_cards.size() - 1]:
		return
	var card_def := open_defs[index]
	var start_global := card.global_position
	var start_scale := _get_canvas_global_scale(card)
	_add_card_to_collection(card_def)
	open_cards.remove_at(index)
	open_defs.remove_at(index)
	card.queue_free()
	_fly_open_card_to_book(card_def, start_global, start_scale)
	if open_cards.is_empty():
		_close_open_popup()

func _add_card_to_collection(def: CardDefinition) -> String:
	if def == null:
		return ""
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	open_collection.add_type(def.definition_id, 1)
	SaveSystem.save_collection(open_collection)
	_refresh_boosters()
	_refresh_book_content()
	_go_to_card_page(def.definition_id)
	return def.definition_id

func _fly_open_card_to_book(def: CardDefinition, start_global: Vector2, start_scale: Vector2) -> void:
	if def == null:
		return
	call_deferred("_fly_open_card_to_book_deferred", def, start_global, start_scale)

func _fly_open_card_to_book_deferred(def: CardDefinition, start_global: Vector2, start_scale: Vector2) -> void:
	var book := _get_book()
	if book and book.is_animating:
		await _wait_for_book_idle()
	var slot := await _wait_for_visible_slot(def.definition_id)
	if slot == null:
		return
	var target := _get_slot_target(slot)
	if target.is_empty():
		return
	var fly := CARD_VIEW_SCENE.instantiate() as CardView
	if fly == null:
		return
	add_child(fly)
	fly.top_level = true
	fly.z_index = 500
	fly.custom_minimum_size = OPEN_CARD_BASE
	fly.size = OPEN_CARD_BASE
	fly.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fly.offset_left = 0.0
	fly.offset_top = 0.0
	fly.offset_right = OPEN_CARD_BASE.x
	fly.offset_bottom = OPEN_CARD_BASE.y
	var upgrade_level := 0
	if open_collection != null:
		upgrade_level = int(open_collection.upgrade_level.get(def.definition_id, 0))
	fly.setup_from_definition(def, _get_display_upgrade_level(def, upgrade_level))
	fly.show_front()
	fly.scale = start_scale
	fly.global_position = start_global
	_set_mouse_filter_recursive(fly, Control.MOUSE_FILTER_IGNORE)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly, "global_position", target["global_pos"], OPEN_CARD_FLY_DURATION)
	tween.parallel().tween_property(fly, "scale", target["scale"], OPEN_CARD_FLY_DURATION)
	tween.finished.connect(func() -> void:
		if is_instance_valid(fly):
			fly.queue_free()
	)

func _wait_for_book_idle() -> void:
	var book := _get_book()
	if book == null:
		return
	var start := Time.get_ticks_msec()
	while book.is_animating and (Time.get_ticks_msec() - start) < int(OPEN_CARD_FLY_MAX_WAIT * 1000.0):
		await get_tree().process_frame

func _wait_for_visible_slot(def_id: String) -> CollectionSlot:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) < int(OPEN_CARD_FLY_MAX_WAIT * 1000.0):
		var slot := _find_visible_slot_for_def(def_id)
		if slot != null:
			return slot
		await get_tree().process_frame
	return null

func _find_visible_slot_for_def(def_id: String) -> CollectionSlot:
	for node in get_tree().get_nodes_in_group("collection_slots"):
		if not (node is CollectionSlot):
			continue
		var slot := node as CollectionSlot
		if slot.current_def_id != def_id:
			continue
		if not slot.is_visible_in_tree():
			continue
		return slot
	return null

func _get_slot_target(slot: CollectionSlot) -> Dictionary:
	if slot == null:
		return {}
	var book: PageFlip2D = _get_book() as PageFlip2D
	var poly: Polygon2D = null
	if book != null:
		var slot_vp := slot.get_viewport()
		var left_vp := book.get_node_or_null("Viewports/Slots/Slot1")
		var right_vp := book.get_node_or_null("Viewports/Slots/Slot2")
		if slot_vp != null and left_vp != null and slot_vp == left_vp:
			poly = book.static_left
		elif slot_vp != null and right_vp != null and slot_vp == right_vp:
			poly = book.static_right

	var card_pos := slot.global_position
	var card_scale := Vector2.ONE
	if slot.card_view != null and slot.card_view.is_visible_in_tree():
		card_pos = slot.card_view.global_position
		card_scale = slot.card_view.scale

	var size_scaled := OPEN_CARD_BASE * card_scale
	if poly != null and book != null:
		var page_h := book.target_page_size.y
		var local_top_left := Vector2(card_pos.x, card_pos.y - (page_h * 0.5))
		var global_top_left := poly.to_global(local_top_left)
		var page_scale := _get_page_global_scale(book, poly)
		return {
			"global_pos": global_top_left,
			"scale": Vector2(card_scale.x * page_scale.x, card_scale.y * page_scale.y),
		}

	return {
		"global_pos": card_pos,
		"scale": card_scale,
	}

func _get_page_global_scale(book: PageFlip2D, poly: Polygon2D) -> Vector2:
	if book == null or poly == null:
		return Vector2.ONE
	var page_w := book.target_page_size.x
	var page_h := book.target_page_size.y
	if page_w <= 0.0 or page_h <= 0.0:
		return Vector2.ONE
	var p0 := poly.to_global(Vector2(0.0, -page_h * 0.5))
	var p1 := poly.to_global(Vector2(page_w, -page_h * 0.5))
	var p2 := poly.to_global(Vector2(0.0, page_h * 0.5))
	var scale_x := p0.distance_to(p1) / page_w
	var scale_y := p0.distance_to(p2) / page_h
	return Vector2(scale_x, scale_y)

func _get_canvas_global_scale(item: CanvasItem) -> Vector2:
	if item == null:
		return Vector2.ONE
	var xform := item.get_global_transform()
	return Vector2(xform.x.length(), xform.y.length())

func _open_card_popup(slot: CollectionSlot) -> void:
	if slot == null:
		return
	if slot.current_def_id == "":
		return
	if not slot.is_obtained:
		return
	var def: CardDefinition = CardDatabase.get_definition(slot.current_def_id)
	if def == null:
		return
	_popup_def = def
	open_collection = SaveSystem.load_collection()
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	_build_card_popup(def)
	card_popup.visible = true
	card_popup.z_index = 220
	_update_book_input_block()

func _build_card_popup(def: CardDefinition) -> void:
	if card_popup_container == null:
		return
	for child in card_popup_container.get_children():
		child.queue_free()
	var card := CARD_VIEW_SCENE.instantiate() as CardView
	if card == null:
		return
	card_popup_container.add_child(card)
	card.custom_minimum_size = OPEN_CARD_BASE
	card.size = OPEN_CARD_BASE
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = OPEN_CARD_BASE.x
	card.offset_bottom = OPEN_CARD_BASE.y
	var upgrade_level := 0
	if open_collection != null:
		upgrade_level = int(open_collection.upgrade_level.get(def.definition_id, 0))
	card.setup_from_definition(def, _get_display_upgrade_level(def, upgrade_level))
	card.show_front()
	_set_mouse_filter_recursive(card, Control.MOUSE_FILTER_IGNORE)
	var scale_w := 220.0 / OPEN_CARD_BASE.x
	var scale_h := 300.0 / OPEN_CARD_BASE.y
	var final_scale := minf(scale_w, scale_h)
	card.scale = Vector2(final_scale, final_scale)
	var scaled_size := OPEN_CARD_BASE * final_scale
	card.position = (card_popup_container.size * 0.5) - (scaled_size * 0.5)
	_update_card_popup_count()

func _update_card_popup_count() -> void:
	if _popup_def == null or card_popup_count == null or open_collection == null:
		return
	var count := open_collection.get_owned_count(_popup_def.definition_id)
	card_popup_count.text = "x%d" % count
	if card_popup_upgrade:
		card_popup_upgrade.disabled = count < 5

func _on_card_upgrade_pressed() -> void:
	if _popup_def == null:
		return
	if open_collection == null:
		open_collection = SaveSystem.ensure_collection()
	var count := open_collection.get_owned_count(_popup_def.definition_id)
	if count < 5:
		return
	open_collection.owned_count[_popup_def.definition_id] = max(0, count - 5)
	var current := int(open_collection.upgrade_level.get(_popup_def.definition_id, 0))
	open_collection.upgrade_level[_popup_def.definition_id] = current + 1
	SaveSystem.save_collection(open_collection)
	if RunState:
		RunState.refresh_upgrades_for_definition(_popup_def.definition_id)
	_build_card_popup(_popup_def)
	_refresh_book_content()

func _close_card_popup() -> void:
	if card_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(card_popup, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		card_popup.visible = false
		card_popup.modulate.a = 1.0
		_update_book_input_block()
	)

func _on_add_all_pressed() -> void:
	for def_item in open_defs.duplicate():
		var card_def := def_item as CardDefinition
		if card_def == null:
			continue
		_add_card_to_collection(card_def)
	_clear_open_cards()
	open_defs.clear()
	_close_open_popup()

func _clear_open_cards() -> void:
	for card in open_cards:
		card.queue_free()
	open_cards.clear()

func _close_open_popup() -> void:
	if open_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(open_popup, "modulate:a", 0.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(0.98, 0.98), 0.15)
	tween.tween_callback(func():
		open_popup.visible = false
		open_popup.modulate.a = 1.0
		open_popup.scale = Vector2.ONE
		_refresh_boosters()
		_refresh_book_content()
		_update_book_input_block()
	)

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _play_open_popup_in() -> void:
	if open_popup == null:
		return
	var tween := create_tween()
	tween.tween_property(open_popup, "modulate:a", 1.0, 0.15)
	tween.tween_property(open_popup, "scale", Vector2(1.0, 1.0), 0.2)

func _refresh_boosters() -> void:
	if booster_list == null:
		return
	for child in booster_list.get_children():
		child.queue_free()
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var packs := _build_pack_views()
	for pack in packs:
		var count := collection.get_booster_count(pack.pack_type)
		if count <= 0:
			continue
		_add_booster_stack(pack, count)

func _build_pack_views() -> Array[PackView]:
	var result: Array[PackView] = []
	var forest := _load_pack_view(PACK_FOREST_PATH, "forest", PACK_FOREST_COLOR)
	if forest != null:
		result.append(forest)
	var dark_forest := _load_pack_view(PACK_DARK_FOREST_PATH, "dark_forest", PACK_DARK_FOREST_COLOR)
	if dark_forest != null:
		result.append(dark_forest)
	return result

func _load_pack_view(path: String, pack_type: String, color: Color) -> PackView:
	var def := load(path) as BoosterPackDefinition
	var view := PackView.new()
	view.pack_type = pack_type
	view.color = color
	if def != null:
		view.name_key = def.name_key
	else:
		view.name_key = ""
	return view

func _add_booster_stack(pack: PackView, count: int) -> void:
	if booster_list == null:
		return
	var item := VBoxContainer.new()
	item.custom_minimum_size = Vector2(220, 110)
	item.alignment = BoxContainer.ALIGNMENT_BEGIN
	booster_list.add_child(item)
	var label := Label.new()
	var display_name := pack.pack_type
	if pack.name_key != "":
		display_name = tr(pack.name_key)
	label.text = tr("COLLECTION_PACK_COUNT") % [display_name, count]
	item.add_child(label)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(220, 90)
	item.add_child(stack)
	var visible_count: int = min(count, PACK_STACK_MAX)
	for i in range(visible_count):
		var rect := ColorRect.new()
		rect.color = pack.color
		rect.custom_minimum_size = PACK_PREVIEW_SIZE
		rect.position = Vector2(PACK_STACK_OFFSET_X * float(i), PACK_STACK_OFFSET_Y * float(i))
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		rect.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_booster_popup(pack)
		)
		stack.add_child(rect)

func _get_pack_pool(pack_type: String) -> Array[CardDefinition]:
	var pool: Array[CardDefinition] = []
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var biome := BIOME_FOREST
	if pack_type == "dark_forest":
		biome = BIOME_DARK_FOREST
	for def in CardDatabase.definitions.values():
		var card_def := def as CardDefinition
		if card_def == null:
			continue
		if card_def.card_type != "enemy":
			continue
		if card_def.biome_modifier != biome:
			continue
		if card_def.is_tutorial:
			continue
		pool.append(card_def)
	return pool

func _get_display_upgrade_level(def: CardDefinition, base_upgrade: int) -> int:
	if def == null:
		return base_upgrade
	if def.card_type != "hero":
		return base_upgrade
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return base_upgrade
	var progression: HeroProgression = profile.get_or_create_progression(StringName(def.definition_id))
	return base_upgrade + max(0, progression.level - 1)

func _get_ordered_def_ids(is_play_mode: bool) -> Array[String]:
	var hero_ids: Array[String] = []
	var forest_ids: Array[String] = []
	var dark_forest_ids: Array[String] = []
	var other_ids: Array[String] = []
	var seen_ids: Dictionary = {}

	for def_id in CardDatabase.definitions.keys():
		var def: CardDefinition = CardDatabase.get_definition(String(def_id))
		if def == null:
			continue
		if def.definition_id == "" or seen_ids.has(def.definition_id):
			continue
		seen_ids[def.definition_id] = true
		if def.card_type == "hero":
			hero_ids.append(def.definition_id)
		elif def.biome_modifier == BIOME_FOREST:
			forest_ids.append(def.definition_id)
		elif def.biome_modifier == BIOME_DARK_FOREST:
			dark_forest_ids.append(def.definition_id)
		else:
			other_ids.append(def.definition_id)

	hero_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)
	forest_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)
	dark_forest_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)
	other_ids.sort_custom(func(a: String, b: String) -> bool:
		return _compare_by_power_then_id(a, b)
	)

	var ordered: Array[String] = []
	ordered.append_array(hero_ids)
	ordered.append_array(forest_ids)
	ordered.append_array(dark_forest_ids)
	ordered.append_array(other_ids)
	return ordered

func _compare_by_power_then_id(a: String, b: String) -> bool:
	var pa := _get_definition_power(a)
	var pb := _get_definition_power(b)
	if pa == pb:
		return a < b
	return pa < pb

func _get_definition_power(def_id: String) -> int:
	var def: CardDefinition = CardDatabase.get_definition(def_id)
	if def == null:
		return 0
	if def.power > 0:
		return def.power
	return int(def.max_hp + def.damage)

func _sort_ids_by_order(ids: Array[String], order: Array[String]) -> Array[String]:
	if order.is_empty():
		ids.sort()
		return ids
	var index_map: Dictionary = {}
	for i in range(order.size()):
		index_map[order[i]] = i
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ia := int(index_map.get(a, 999999))
		var ib := int(index_map.get(b, 999999))
		if ia == ib:
			return a < b
		return ia < ib
	)
	return ids

func _go_to_card_page(definition_id: String) -> void:
	if definition_id == "":
		return
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	var book_node := _get_book()
	if book_node == null:
		return
	var book_page := book_node as PageFlip2D
	if book_page == null:
		return
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	var types: Array[String] = []
	var order := _get_ordered_def_ids(RunState.selection_pending)
	if RunState.selection_pending:
		var ids: Array[String] = []
		for def_id in collection.get_all_types():
			ids.append(String(def_id))
		types = _sort_ids_by_order(ids, order)
	else:
		var all_ids: Array[String] = []
		var seen_ids: Dictionary = {}
		for def_key in CardDatabase.definitions.keys():
			var def: CardDefinition = CardDatabase.get_definition(String(def_key))
			if def == null:
				continue
			var def_id := String(def.definition_id)
			if def_id == "" or seen_ids.has(def_id):
				continue
			seen_ids[def_id] = true
			all_ids.append(def_id)
		types = _sort_ids_by_order(all_ids, order)
	if types.is_empty():
		return
	var slots_per_page: int = 9
	if book_view != null:
		var exported_value: Variant = book_view.get("slots_per_page")
		if typeof(exported_value) == TYPE_INT:
			var override_pages: int = exported_value as int
			if override_pages > 0:
				slots_per_page = override_pages
	for i in range(types.size()):
		var def_id := String(types[i])
		if def_id == definition_id:
			var page_index := int(i / max(1, slots_per_page))
			var target_page := page_index + 1
			book_page.call("go_to_page", target_page, PageFlip2D.JumpTarget.CONTENT_PAGE)
			return
