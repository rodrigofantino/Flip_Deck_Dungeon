extends Node
class_name RunManager
# Nodo global que mantiene y controla la run actual

# =========================
# ESTADO DE LA RUN
# =========================

var run_mode: String = "normal"
# "tutorial", "normal", "endless"

var is_temporary_run: bool = false
# Las runs temporales no se guardan

var cards := {}
# Diccionario de CardInstances de la run actual

var enemy_draw_queues_by_deck: Array = [] # Array[Array[Dictionary]] (orden real de robo por mazo)

# =========================
# ITEMS (HAND / EQUIP)
# =========================
const MAX_HAND_SIZE: int = 6
const MAX_EQUIP_SLOTS: int = 7
const ITEM_DROP_CHANCE: float = 0.5
const ITEM_ARCHETYPE_CATALOG_DEFAULT_PATH: String = "res://data/item_archetype_catalog_default.tres"
const EQUIPMENT_LAYOUT_KNIGHT_PATH: String = "res://data/equipment_layouts/knight_layout.tres"

@export var item_archetype_catalog: ItemArchetypeCatalog
@export var equipment_layout_knight: EquipmentLayoutDefinition

var item_instances: Dictionary = {}
var item_instance_counter: int = 0
var equipment_manager: EquipmentManager = null

var hand_items: Array[String] = []
var equipped_items: Array[String] = ["", "", "", "", "", "", ""]
var completed_set_themes: Array[String] = []

var set_bonus_armour: int = 0
var set_bonus_damage: int = 0
var set_bonus_life: int = 0
var set_bonus_initiative: int = 0
var set_bonus_lifesteal: int = 0
var set_bonus_thorns: int = 0
var set_bonus_regen: int = 0
var set_bonus_crit: int = 0

var item_drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# =========================
# SEÃƒÆ’Ã¢â‚¬ËœALES DE PROGRESIÃƒÆ’Ã¢â‚¬Å“N
# =========================

signal gold_changed(new_gold: int)
signal danger_level_changed(new_danger: int)
signal enemy_stats_changed()
signal active_decks_changed(new_count: int)
signal crossroads_requested()
signal item_dropped(item_id: String)
signal hand_changed(hand_items: Array[String])
signal equip_changed(equipped_items: Array[String])
signal hero_stats_changed()
signal set_completed(theme: String, item_ids: Array[String])
signal dust_changed(new_dust: int, delta: int)

# =========================
# ESTADO ECONOMÃƒÆ’Ã‚ÂA / RIESGO
# =========================

var gold: int = 0
var danger_level: int = 0
var active_decks_count: int = 1
const MAX_ACTIVE_DECKS: int = 5
var enemies_defeated_count: int = 0
@export var crossroads_every_n: int = 3
var dust: int = 0

# =========================
# WAVES
# =========================
signal wave_started(wave_index: int, waves_total: int)
signal wave_progress_changed(wave_index: int, defeated: int, total: int)
signal wave_completed(wave_index: int)
signal final_boss_started(boss_id: String)
signal mini_boss_started(boss_id: String)

var current_wave: int = 1
var waves_per_run: int = 20
var enemies_per_wave: int = 5
var enemies_defeated_in_wave: int = 0

# =========================
# TRAITS ACTIVOS
# =========================

var active_hero_traits: Array[TraitResource] = []
var active_enemy_traits: Array[TraitResource] = []
var run_loaded: bool = false
var selection_pending: bool = false
var active_enemy_ids: Array[String] = []

# =========================
# SELECCION / RUN DECK (TYPES)
# =========================
var selected_hero_def_id: String = ""
var selected_enemy_types: Array[String] = []
var enemy_weights: Dictionary = {}
var run_deck_types: Array[String] = [] # Deck 0 (legacy/compat)
var run_deck_types_by_deck: Array = [] # Array[Array[String]]
var run_seed: int = 0
var enemy_spawn_counter: int = 0
const RUN_DECK_SIZE: int = 20
const MAX_WAVES: int = 20

# =========================
# PROGRESIÃƒÆ’Ã¢â‚¬Å“N DEL JUGADOR
# =========================

signal hero_xp_changed(current_xp: int, xp_to_next: int)
signal hero_level_up(new_level: int)

var hero_level: int = 1
var hero_xp: int = 0
var xp_to_next_level: int = 4

const XP_GROWTH_FACTOR: float = 2.0
const HERO_LEVEL_UP_STAT_MULT: float = 1.2
const ENEMY_LEVEL_UP_STAT_MULT: float = 1.25
var hero_level_multiplier: float = 1.0
var enemy_level_multiplier: float = 1.0
var _upgrade_level_map: Dictionary = {}

# =========================
# HERO XP (SLOW LEVEL-UP)
# =========================
const XP_PER_COMMON_KILL: int = 1
const XP_PER_MINI_BOSS: int = 3
const BASE_XP_TO_LEVEL: int = 6
const XP_PER_LEVEL_STEP: int = 4

# =========================
# BASE DE DATOS DE TRAITS
# =========================
const TRAIT_DB_PATH := "res://data/traits/trait_database_default.tres"
@export var trait_database: TraitDatabase

# =========================
# BOSSES
# =========================
const BOSS_DEFS_FOLDER := "res://data/bosses/defs"
const MINI_BOSS_WAVES: Array[int] = [5, 10, 15]
const FINAL_BOSS_WAVES: Array[int] = [20]
const MINI_BOSS_IDS: Array[String] = [
	"forest_stag_king",
	"forest_boar_warden",
	"forest_fungus_patriarch"
]
const FINAL_BOSS_ID: String = "forest_fallen_elf"

@export var boss_catalog: BossCatalog



func _ready() -> void:
	item_drop_rng.randomize()
	if trait_database == null:
		trait_database = load(TRAIT_DB_PATH)
	if item_archetype_catalog == null:
		item_archetype_catalog = load(ITEM_ARCHETYPE_CATALOG_DEFAULT_PATH)
	if equipment_layout_knight == null:
		equipment_layout_knight = load(EQUIPMENT_LAYOUT_KNIGHT_PATH)
	_ensure_equipment_manager()
	_ensure_boss_catalog()
	_load_upgrade_levels()
	_apply_equipment_to_hero()

	if trait_database == null:
		push_error("[RunManager] TraitDatabase NO pudo cargarse")
	else:
		print("[RunManager] TraitDatabase cargada OK")
		debug_print_traits()

func _ensure_boss_catalog() -> void:
	if boss_catalog == null:
		boss_catalog = BossCatalog.new()
		boss_catalog.bosses_folder = BOSS_DEFS_FOLDER
	boss_catalog.load_all()

func get_boss_definition(boss_id: String) -> BossDefinition:
	if boss_catalog == null:
		_ensure_boss_catalog()
	if boss_catalog == null:
		return null
	return boss_catalog.get_by_id(boss_id)

######################################
# INIT RUN
######################################
func init_run() -> void:
	if trait_database == null:
		return

	trait_database.load_all()
	debug_print_traits()

	if run_loaded:
		return

	if selected_hero_def_id == "":
		return

	_load_upgrade_levels()

	if cards.is_empty() or not cards.has("th"):
		cards.clear()
		_build_cards_from_run_deck()
		_sync_hero_card_level(false)

	# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Ëœ APLICAR TRAITS ACTIVOS A ENEMIGOS YA EXISTENTES
	for card in cards.values():
		if card.get("id", "") == "th":
			recalc_card_stats(card, active_hero_traits)
		else:
			recalc_card_stats(card, active_enemy_traits)

	if not run_loaded:
		start_wave_encounter()



# =========================
# =========================
# SELECCION / RUN DECK (TYPES)
# =========================
func set_run_selection(hero_def_id: String, weights: Dictionary) -> void:
	selected_hero_def_id = hero_def_id
	enemy_weights.clear()
	for key in weights.keys():
		var enemy_id := String(key)
		if enemy_id == "":
			continue
		var weight := int(weights.get(key, 1))
		enemy_weights[enemy_id] = clampi(weight, 1, 3)
	_sync_selected_enemy_types_from_weights()
	run_deck_types.clear()
	run_deck_types_by_deck.clear()
	enemy_draw_queues_by_deck.clear()
	enemy_spawn_counter = 0
	run_seed = int(Time.get_ticks_msec())
	current_wave = 1
	hero_level = 1
	hero_xp = 0
	xp_to_next_level = _calc_xp_to_next_level(hero_level)
	item_instances.clear()
	item_instance_counter = 0
	hand_items.clear()
	equipped_items = ["", "", "", "", "", "", ""]

func set_enemy_selected(enemy_id: String, selected: bool) -> void:
	if enemy_id.is_empty():
		return
	if selected:
		if not enemy_weights.has(enemy_id):
			enemy_weights[enemy_id] = 1
	else:
		enemy_weights.erase(enemy_id)
	_sync_selected_enemy_types_from_weights()

func set_enemy_weight(enemy_id: String, weight: int) -> void:
	if enemy_id.is_empty():
		return
	if not enemy_weights.has(enemy_id):
		return
	enemy_weights[enemy_id] = clampi(weight, 1, 3)

func get_selected_enemy_ids() -> Array[String]:
	return _get_enemy_weights_keys()

func is_valid_selection() -> bool:
	var count := enemy_weights.size()
	if count < 2 or count > 5:
		return false
	for key in enemy_weights.keys():
		var weight := int(enemy_weights.get(key, 0))
		if weight < 1 or weight > 3:
			return false
	return true

func get_selection_error_message() -> String:
	var count := enemy_weights.size()
	if count < 2:
		return "Seleccioná al menos 2 enemigos."
	if count > 5:
		return "Máximo 5 enemigos."
	for key in enemy_weights.keys():
		var weight := int(enemy_weights.get(key, 0))
		if weight < 1 or weight > 3:
			return "Peso inválido en selección."
	return ""

func _sync_selected_enemy_types_from_weights() -> void:
	selected_enemy_types = _get_enemy_weights_keys()

func _get_enemy_weights_keys() -> Array[String]:
	var ids: Array[String] = []
	for key in enemy_weights.keys():
		var id_str := String(key)
		if id_str != "":
			ids.append(id_str)
	return ids

func build_run_deck_from_selection() -> void:
	if selected_enemy_types.is_empty():
		return
	if run_seed == 0:
		run_seed = int(Time.get_ticks_msec())
	_build_run_deck_types_for_decks(active_decks_count)
	SaveSystem.save_run_deck(run_deck_types_by_deck)

func _build_run_deck_types_for_decks(deck_count: int) -> void:
	run_deck_types.clear()
	run_deck_types_by_deck.clear()
	if selected_enemy_types.is_empty():
		return
	if run_seed == 0:
		run_seed = int(Time.get_ticks_msec())
	_ensure_deck_arrays(deck_count)
	for deck_index in range(deck_count):
		var deck := _build_single_run_deck_types(deck_index)
		run_deck_types_by_deck[deck_index] = deck
	if run_deck_types_by_deck.size() > 0:
		run_deck_types = (run_deck_types_by_deck[0] as Array).duplicate()

func _build_single_run_deck_types(deck_index: int) -> Array[String]:
	var result: Array[String] = []
	if selected_enemy_types.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + ((deck_index + 1) * 7919) + (current_wave * 104729)
	for i in range(RUN_DECK_SIZE):
		var idx := rng.randi_range(0, selected_enemy_types.size() - 1)
		result.append(selected_enemy_types[idx])
	return result

func _ensure_deck_arrays(deck_count: int) -> void:
	while run_deck_types_by_deck.size() < deck_count:
		run_deck_types_by_deck.append([])
	while enemy_draw_queues_by_deck.size() < deck_count:
		enemy_draw_queues_by_deck.append([])
	while run_deck_types_by_deck.size() > deck_count:
		run_deck_types_by_deck.pop_back()
	while enemy_draw_queues_by_deck.size() > deck_count:
		enemy_draw_queues_by_deck.pop_back()

func remove_run_deck_type(definition_id: String, deck_index: int = 0) -> void:
	if definition_id == "":
		return
	if deck_index < 0:
		deck_index = 0
	if deck_index >= run_deck_types_by_deck.size():
		return
	var deck: Array[String] = []
	var raw_deck: Variant = run_deck_types_by_deck[deck_index]
	if raw_deck is Array:
		for entry in raw_deck:
			if entry is String:
				deck.append(entry)
	for i in range(deck.size()):
		if deck[i] == definition_id:
			deck.remove_at(i)
			break
	run_deck_types_by_deck[deck_index] = deck
	if deck_index == 0:
		run_deck_types = deck.duplicate()

func _generate_enemy_id(definition_id: String) -> String:
	enemy_spawn_counter += 1
	return "e_%s_%d" % [definition_id, enemy_spawn_counter]

# CREATE CARD INSTANCE (RUNTIME)
# =========================
func create_card_instance(
	id: String,
	definition_key: String,
	is_tutorial := false,
	deck_index: int = -1
) -> Dictionary:
	var def: CardDefinition = CardDatabase.get_definition(definition_key)
	if def == null:
		push_error("Definition no encontrada: " + definition_key)
		return {}

	var is_hero_card: bool = id == "th"
	var upgrade_level: int = _get_upgrade_level(definition_key)
	var scaled_hp: int = _scale_stat(def.max_hp, is_hero_card, upgrade_level)
	var scaled_damage: int = _scale_stat(def.damage, is_hero_card, upgrade_level)
	var scaled_initiative: int = _scale_stat(def.initiative, is_hero_card, upgrade_level)

	var card_level: int = def.level
	if id == "th":
		card_level = hero_level + upgrade_level
	else:
		card_level = def.level + max(0, hero_level - 1) + upgrade_level

	var card: Dictionary = {
		"id": id,
		"definition": definition_key,
		"is_tutorial": is_tutorial,
		"upgrade_level": upgrade_level,
		"deck_index": deck_index,

		# BASE
		"base_hp": scaled_hp,
		"base_damage": scaled_damage,
		"base_initiative": scaled_initiative,

		# RUNTIME
		"max_hp": scaled_hp,
		"current_hp": scaled_hp,
		"damage": scaled_damage,
		"initiative": scaled_initiative,

		"level": card_level
	}

	cards[id] = card

	# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Ëœ APLICAR TRAITS ACTIVOS
	if id == "th":
		recalc_card_stats(card, active_hero_traits)
	else:
		recalc_card_stats(card, active_enemy_traits)


	# =========================
	# ÃƒÂ°Ã…Â¸Ã‚Â§Ã‚Â¬ APLICAR TRAITS A ENEMIGOS NUEVOS
	# =========================
	if id != "th":
		for trait_res: TraitResource in active_enemy_traits:
			print("[TRAIT] Aplicando trait activo a enemigo NUEVO:", id)
			

	return card

func create_boss_instance(
	boss_def: BossDefinition,
	deck_index: int = 0
) -> Dictionary:
	if boss_def == null:
		return {}

	var id := _generate_boss_instance_id(boss_def.boss_id)
	var trait_ids: Array[String] = []
	for trait_res in boss_def.boss_traits:
		if trait_res != null and not trait_res.trait_id.strip_edges().is_empty():
			trait_ids.append(trait_res.trait_id)

	var card: Dictionary = {
		"id": id,
		"definition": boss_def.boss_id,
		"boss_id": boss_def.boss_id,
		"is_boss": true,
		"boss_kind": boss_def.boss_kind,
		"boss_trait_ids": trait_ids,
		"deck_index": deck_index,

		# BASE
		"base_hp": boss_def.base_max_hp,
		"base_damage": boss_def.base_damage,
		"base_initiative": boss_def.base_initiative,
		"base_armour": boss_def.base_armour,

		# RUNTIME
		"max_hp": boss_def.base_max_hp,
		"current_hp": boss_def.base_max_hp,
		"damage": boss_def.base_damage,
		"initiative": boss_def.base_initiative,
		"armour": boss_def.base_armour,

		"level": boss_def.base_level,
		"upgrade_level": 0
	}

	cards[id] = card
	recalc_card_stats(card, active_enemy_traits)
	return card

func _generate_boss_instance_id(boss_id: String) -> String:
	var index := 1
	var id := "b_%s_%d" % [boss_id, index]
	while cards.has(id):
		index += 1
		id = "b_%s_%d" % [boss_id, index]
	return id

func recalc_card_stats(
	card: Dictionary,
	traits: Array[TraitResource]
) -> void:
	var base_hp: int = card["base_hp"]
	var base_damage: int = card["base_damage"]
	var base_initiative: int = card["base_initiative"]
	var old_max_hp: int = int(card.get("max_hp", base_hp))
	var old_current_hp: int = int(card.get("current_hp", base_hp))

	var flat_hp := 0
	var flat_damage := 0
	var flat_initiative := 0
	var hp_mult := 1.0
	var damage_mult := 1.0

	var is_hero: bool = card.get("id", "") == "th"


	for trait_res in traits:
		if is_hero and trait_res.trait_type == TraitResource.TraitType.HERO:
			flat_hp += trait_res.hero_max_hp_bonus
			flat_damage += trait_res.hero_damage_bonus
			hp_mult *= trait_res.hero_hp_multiplier
			damage_mult *= trait_res.hero_damage_multiplier

		elif not is_hero and trait_res.trait_type == TraitResource.TraitType.ENEMY:
			flat_hp += trait_res.enemy_add_flat_hp
			flat_damage += trait_res.enemy_add_flat_damage
			flat_initiative += trait_res.enemy_add_initiative
			hp_mult *= trait_res.enemy_hp_multiplier
			damage_mult *= trait_res.enemy_damage_multiplier
			card["level"] += trait_res.enemy_add_level

	var new_max_hp := int((base_hp + flat_hp) * hp_mult)
	var new_damage := int((base_damage + flat_damage) * damage_mult)
	var new_initiative := base_initiative + flat_initiative

	card["max_hp"] = new_max_hp
	card["damage"] = new_damage
	card["initiative"] = new_initiative
	if old_max_hp > 0 and new_max_hp > old_max_hp:
		var ratio := float(old_current_hp) / float(old_max_hp)
		card["current_hp"] = int(round(float(new_max_hp) * ratio))
	else:
		card["current_hp"] = min(old_current_hp, new_max_hp)


########################################
# DRAW REAL DE ENEMIGO
########################################
func draw_enemy_card() -> Dictionary:
	return draw_enemy_card_from_deck(0)

func draw_enemy_card_from_deck(deck_index: int) -> Dictionary:
	if enemy_draw_queues_by_deck.is_empty():
		prepare_progressive_deck()

	if deck_index < 0 or deck_index >= enemy_draw_queues_by_deck.size():
		return {}
	var queue: Array = enemy_draw_queues_by_deck[deck_index]
	if queue.is_empty():
		return {}

	var enemy: Dictionary = queue.pop_front()
	enemy_draw_queues_by_deck[deck_index] = queue
	recalc_card_stats(enemy, active_enemy_traits)

	print(
		"[DRAW] TOP OF DECK ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢",
		enemy.get("definition", "???"),
		"| Power:",
		calculate_enemy_power(enemy),
		"| Remaining:",
		queue.size()
	)

	return enemy

func get_enemy_draw_queue(deck_index: int) -> Array[Dictionary]:
	if deck_index < 0 or deck_index >= enemy_draw_queues_by_deck.size():
		var empty: Array[Dictionary] = []
		return empty
	var raw: Variant = enemy_draw_queues_by_deck[deck_index]
	var typed: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				typed.append(entry)
	return typed

func are_enemy_draw_queues_empty() -> bool:
	if enemy_draw_queues_by_deck.is_empty():
		return true
	for queue in enemy_draw_queues_by_deck:
		if (queue as Array).size() > 0:
			return false
	return true



########################################
# LIMPIEZA DE CARTAS DE TUTORIAL
########################################
########################################
# CONSULTA DE CARTAS
########################################
func get_card(id: String) -> Dictionary:
	return cards.get(id, {})

func get_all_cards() -> Array:
	return cards.values()


###########################
# CALCULA PODER DE ENEMIGO
###########################
func calculate_enemy_power(enemy: Dictionary) -> int:
	var base_hp: int = int(enemy.get("max_hp", 0))
	var base_damage: int = int(enemy.get("damage", 0))
	var level: int = int(enemy.get("level", 1))
	var special_bonus: int = int(enemy.get("power_bonus", 0))

	var base_power: int = base_hp + base_damage
	var power: int = base_power * level + special_bonus

	return power


###########################
# RECALCULA EL DANGER LEVEL
###########################
func recalculate_danger_level() -> void:
	var total_power: int = 0

	for card in cards.values():
		if card.id == "th":
			continue

		total_power += calculate_enemy_power(card)

	danger_level = total_power
	danger_level_changed.emit(danger_level)


#############################
# RECOMPENSAS
#############################
func apply_enemy_rewards(enemy: Dictionary) -> void:
	var enemy_level: int = int(enemy.get("level", 1))
	var gold_reward: int = max(1, enemy_level)
	var xp_reward: int = _calc_xp_reward(enemy)

	_add_gold(gold_reward)
	_add_hero_xp(xp_reward)

func _calc_xp_reward(enemy: Dictionary) -> int:
	if enemy.is_empty():
		return 0
	var is_boss: bool = bool(enemy.get("is_boss", false)) or enemy.has("boss_id")
	if is_boss:
		var boss_kind := int(enemy.get("boss_kind", BossDefinition.BossKind.MINI_BOSS))
		if boss_kind == BossDefinition.BossKind.FINAL_BOSS:
			return 0
		return XP_PER_MINI_BOSS
	return XP_PER_COMMON_KILL

func apply_enemy_dust(enemy: Dictionary) -> void:
	var enemy_level: int = int(enemy.get("level", 1))
	var dust_gain: int = 2 * enemy_level
	dust += dust_gain
	dust_changed.emit(dust, dust_gain)

func try_drop_item_from_enemy(enemy_data: Dictionary) -> void:
	if item_archetype_catalog == null or item_archetype_catalog.archetypes.is_empty():
		return
	if enemy_data.is_empty():
		return
	if item_drop_rng.randf() > ITEM_DROP_CHANCE:
		return

	var def_id := String(enemy_data.get("definition", ""))
	var enemy_def: CardDefinition = null
	if not def_id.is_empty():
		enemy_def = CardDatabase.get_definition(def_id)

	var item_type := roll_item_type_for_enemy(enemy_def)
	var pool := item_archetype_catalog.get_by_type_and_class(item_type, "knight")
	if pool.is_empty():
		pool = item_archetype_catalog.archetypes.duplicate()
	if pool.is_empty():
		return
	var idx := item_drop_rng.randi_range(0, pool.size() - 1)
	var archetype: ItemArchetype = pool[idx]
	if archetype == null:
		return

	var enemy_level: int = int(enemy_data.get("level", 1))
	var instance := _create_item_instance(archetype, enemy_level)
	if instance == null:
		return
	_add_item_to_hand(instance.instance_id)
	item_dropped.emit(instance.instance_id)

func roll_item_type_for_enemy(enemy_def: CardDefinition) -> int:
	var weights: Dictionary = {}
	if enemy_def != null:
		weights = enemy_def.get_allowed_item_type_weights()
	if weights.is_empty():
		weights = CardDefinition._get_default_item_type_weights()

	var total_weight: int = 0
	for key in weights.keys():
		var weight := int(weights.get(key, 0))
		if weight > 0:
			total_weight += weight
	if total_weight <= 0:
		weights = CardDefinition._get_default_item_type_weights()
		for key in weights.keys():
			var weight := int(weights.get(key, 0))
			if weight > 0:
				total_weight += weight
		if total_weight <= 0:
			return int(CardDefinition.ItemType.HELMET)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randi_range(1, total_weight)
	var acc: int = 0
	var keys: Array = weights.keys()
	keys.sort()
	for key in keys:
		var weight := int(weights.get(key, 0))
		if weight <= 0:
			continue
		acc += weight
		if roll <= acc:
			return int(key)
	return int(CardDefinition.ItemType.HELMET)

func get_item_instance(item_id: String) -> ItemInstance:
	if item_id.is_empty():
		return null
	var raw: Variant = item_instances.get(item_id, null)
	if raw is ItemInstance:
		return raw
	return null

func _create_item_instance(archetype: ItemArchetype, enemy_level: int) -> ItemInstance:
	if archetype == null:
		return null
	var instance := ItemInstance.new()
	item_instance_counter += 1
	instance.instance_id = "it_%s_%d" % [archetype.item_id, item_instance_counter]
	instance.archetype = archetype
	instance.item_level = max(1, enemy_level)
	instance.rarity = _roll_item_rarity()
	instance.mods = _roll_item_mods(instance.rarity, archetype.item_class)
	item_instances[instance.instance_id] = instance
	return instance

func _create_random_item_instance_for_debug() -> ItemInstance:
	if item_archetype_catalog == null or item_archetype_catalog.archetypes.is_empty():
		return null
	var idx := item_drop_rng.randi_range(0, item_archetype_catalog.archetypes.size() - 1)
	var archetype: ItemArchetype = item_archetype_catalog.archetypes[idx]
	return _create_item_instance(archetype, 1)

func _roll_item_rarity() -> int:
	var roll := item_drop_rng.randi_range(1, 100)
	if roll <= 70:
		return 1
	if roll <= 90:
		return 2
	if roll <= 98:
		return 3
	return 4

func _roll_item_mods(count: int, item_class: String) -> Array[ItemMod]:
	var result: Array[ItemMod] = []
	if count <= 0:
		return result
	var pool := _get_mod_pool_for_class(item_class)
	if pool.is_empty():
		return result
	var available := pool.duplicate()
	for i in range(count):
		if available.is_empty():
			break
		var idx := item_drop_rng.randi_range(0, available.size() - 1)
		var mod: ItemMod = available[idx]
		available.remove_at(idx)
		result.append(mod)
	return result

func _get_mod_pool_for_class(item_class: String) -> Array[ItemMod]:
	var pool: Array[ItemMod] = []
	if item_class != "knight":
		return pool
	# Pool Knight V1 (solo stats soportadas)
	pool.append(_build_mod("knight_armour_1", 1, 0, 0, 0))
	pool.append(_build_mod("knight_armour_2", 2, 0, 0, 0))
	pool.append(_build_mod("knight_damage_1", 0, 1, 0, 0))
	pool.append(_build_mod("knight_damage_2", 0, 2, 0, 0))
	pool.append(_build_mod("knight_life_2", 0, 0, 2, 0))
	pool.append(_build_mod("knight_life_3", 0, 0, 3, 0))
	pool.append(_build_mod("knight_initiative_1", 0, 0, 0, 1))
	pool.append(_build_mod("knight_initiative_2", 0, 0, 0, 2))
	return pool

func _build_mod(id: String, armour: int, damage: int, life: int, initiative: int) -> ItemMod:
	var mod := ItemMod.new()
	mod.mod_id = id
	mod.armour_flat = armour
	mod.damage_flat = damage
	mod.life_flat = life
	mod.initiative_flat = initiative
	return mod

func register_enemy_defeated(has_remaining_enemies: bool) -> void:
	enemies_defeated_count += 1
	# Crossroads se maneja al final del mazo en BattleTable
	if not has_remaining_enemies:
		return


func _add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func get_run_gold() -> int:
	return gold

func get_active_decks_count() -> int:
	return active_decks_count

func can_add_deck() -> bool:
	return active_decks_count < MAX_ACTIVE_DECKS

func add_deck() -> void:
	if not can_add_deck():
		return
	active_decks_count += 1
	_ensure_deck_arrays(active_decks_count)
	active_decks_changed.emit(active_decks_count)

func get_withdraw_preview() -> Dictionary:
	var withdraw_amount: int = int(floor(float(gold) * 0.25))
	var cost_amount: int = gold - withdraw_amount
	return {
		"withdraw": withdraw_amount,
		"cost": cost_amount
	}

func apply_withdraw_25_cost_75() -> Dictionary:
	var preview := get_withdraw_preview()
	var withdraw_amount: int = int(preview.get("withdraw", 0))
	var cost_amount: int = int(preview.get("cost", 0))
	gold = 0
	dust = 0
	gold_changed.emit(gold)
	if withdraw_amount > 0:
		SaveSystem.add_persistent_gold(withdraw_amount)
	return {
		"withdraw": withdraw_amount,
		"cost": cost_amount
	}

func get_hand_items() -> Array[String]:
	return hand_items.duplicate()

func get_equipped_items() -> Array[String]:
	return equipped_items.duplicate()

func get_equipped_item_id_for_slot(slot_id: String) -> String:
	var idx := _get_equipment_slot_index(slot_id)
	if idx < 0:
		return ""
	if idx >= equipped_items.size():
		return ""
	return String(equipped_items[idx])

func get_equipment_layout_for_class(class_id: String) -> EquipmentLayoutDefinition:
	if class_id == "knight":
		return equipment_layout_knight
	return equipment_layout_knight

func get_equipment_manager() -> EquipmentManager:
	_ensure_equipment_manager()
	return equipment_manager

func _add_item_to_hand(item_id: String) -> void:
	if item_id.is_empty():
		return
	if not item_instances.has(item_id):
		return
	if hand_items.size() >= MAX_HAND_SIZE:
		hand_items.remove_at(0)
	hand_items.append(item_id)
	hand_changed.emit(hand_items)

func equip_item_to_slot(slot_id: String, item_id: String) -> int:
	if item_id.is_empty():
		return EquipmentManager.EquipResult.FAILED
	if not hand_items.has(item_id):
		return EquipmentManager.EquipResult.FAILED
	var instance := get_item_instance(item_id)
	if instance == null:
		return EquipmentManager.EquipResult.FAILED
	_ensure_equipment_manager()
	if equipment_manager == null:
		return EquipmentManager.EquipResult.FAILED
	return equipment_manager.equip(slot_id, instance)

func debug_add_full_set_to_hand(_theme: String = "") -> void:
	if item_archetype_catalog == null or item_archetype_catalog.archetypes.is_empty():
		return
	var added := 0
	while added < min(MAX_HAND_SIZE, 4):
		var instance := _create_random_item_instance_for_debug()
		if instance == null:
			break
		_add_item_to_hand(instance.instance_id)
		added += 1

func equip_item_from_hand(item_id: String, slot_index: int) -> void:
	if item_id.is_empty():
		return
	if not hand_items.has(item_id):
		return
	if not item_instances.has(item_id):
		return
	_ensure_equipment_manager()
	var instance := get_item_instance(item_id)
	if equipment_manager != null and instance != null:
		var slot_id := _get_slot_id_from_index(slot_index)
		if not equipment_manager.can_equip(slot_id, instance):
			return

	var idx := _find_slot_for_item(item_id)
	if idx == -1:
		idx = _find_first_empty_slot()
		if idx == -1:
			idx = 0

	equipped_items[idx] = item_id
	hand_items.erase(item_id)
	hand_changed.emit(hand_items)
	equip_changed.emit(equipped_items)
	_apply_equipment_to_hero()

func _ensure_equipment_manager() -> void:
	if equipment_manager != null:
		return
	equipment_manager = EquipmentManager.new()
	if equipment_layout_knight == null:
		equipment_layout_knight = load(EQUIPMENT_LAYOUT_KNIGHT_PATH)
	equipment_manager.setup(equipment_layout_knight, self)

func _get_equipment_slot_index(slot_id: String) -> int:
	if equipment_layout_knight == null:
		return -1
	for i in range(equipment_layout_knight.slots.size()):
		var slot_def := equipment_layout_knight.slots[i]
		if slot_def != null and slot_def.slot_id == slot_id:
			return i
	return -1

func _get_slot_id_from_index(slot_index: int) -> String:
	if equipment_layout_knight == null:
		return ""
	if slot_index < 0 or slot_index >= equipment_layout_knight.slots.size():
		return ""
	var slot_def := equipment_layout_knight.slots[slot_index]
	if slot_def == null:
		return ""
	return slot_def.slot_id

func _equip_item_to_slot_index(slot_index: int, item_id: String) -> void:
	if slot_index < 0 or slot_index >= MAX_EQUIP_SLOTS:
		return
	if item_id.is_empty():
		return
	if not hand_items.has(item_id):
		return
	equipped_items[slot_index] = item_id
	hand_items.erase(item_id)
	hand_changed.emit(hand_items)
	equip_changed.emit(equipped_items)
	_apply_equipment_to_hero()

func _find_slot_for_item(item_id: String) -> int:
	var slot_key := _get_item_slot_key(item_id)
	if slot_key.is_empty():
		return -1
	for i in range(min(equipped_items.size(), MAX_EQUIP_SLOTS)):
		var equipped_id := equipped_items[i]
		if equipped_id.is_empty():
			continue
		if _get_item_slot_key(equipped_id) == slot_key:
			return i
	return -1

func _find_first_empty_slot() -> int:
	for i in range(MAX_EQUIP_SLOTS):
		if equipped_items[i].is_empty():
			return i
	return -1

func _get_item_slot_key(item_id: String) -> String:
	var instance := get_item_instance(item_id)
	if instance == null or instance.archetype == null:
		return ""
	return _get_slot_key_from_archetype(instance.archetype)

func _remove_equipped_item(item_id: String) -> void:
	for i in range(equipped_items.size()):
		if equipped_items[i] == item_id:
			equipped_items[i] = ""
			return

func _get_slot_key_from_archetype(archetype: ItemArchetype) -> String:
	if archetype == null:
		return ""
	if archetype.item_type == CardDefinition.ItemType.ONE_HAND:
		return "one_hand"
	if archetype.item_type == CardDefinition.ItemType.TWO_HANDS:
		return "two_hands"
	if archetype.item_type == CardDefinition.ItemType.HELMET:
		return "helmet"
	if archetype.item_type == CardDefinition.ItemType.ARMOUR:
		return "armour"
	if archetype.item_type == CardDefinition.ItemType.GLOVES:
		return "gloves"
	if archetype.item_type == CardDefinition.ItemType.BOOTS:
		return "boots"
	return ""

func _apply_equipment_to_hero() -> void:
	var hero: Dictionary = cards.get("th", {})
	if hero.is_empty():
		return
	var base_hp: int = int(hero.get("base_hp", 0))
	var base_damage: int = int(hero.get("base_damage", 0))
	var base_initiative: int = int(hero.get("base_initiative", 0))
	var old_max_hp: int = int(hero.get("max_hp", base_hp))
	var old_current_hp: int = int(hero.get("current_hp", base_hp))

	var add_hp: int = 0
	var add_damage: int = 0
	var add_initiative: int = 0
	var add_armour: int = 0
	var add_lifesteal: int = 0
	var add_thorns: int = 0
	var add_regen: int = 0
	var add_crit: int = 0

	for item_id in equipped_items:
		if item_id.is_empty():
			continue
		var instance := get_item_instance(item_id)
		if instance == null:
			continue
		add_hp += instance.get_total_life_flat()
		add_damage += instance.get_total_damage_flat()
		add_initiative += instance.get_total_initiative_flat()
		add_armour += instance.get_total_armour_flat()

	add_hp += set_bonus_life
	add_damage += set_bonus_damage
	add_initiative += set_bonus_initiative
	add_armour += set_bonus_armour
	add_lifesteal += set_bonus_lifesteal
	add_thorns += set_bonus_thorns
	add_regen += set_bonus_regen
	add_crit += set_bonus_crit

	var new_max_hp := base_hp + add_hp
	var new_damage := base_damage + add_damage
	var new_initiative := base_initiative + add_initiative

	hero["max_hp"] = new_max_hp
	hero["damage"] = new_damage
	hero["initiative"] = new_initiative
	hero["armour"] = add_armour
	hero["lifesteal"] = add_lifesteal
	hero["thorns"] = add_thorns
	hero["regen"] = add_regen
	hero["crit_chance"] = add_crit

	if old_max_hp > 0 and new_max_hp > 0:
		var ratio := float(old_current_hp) / float(old_max_hp)
		hero["current_hp"] = min(int(round(float(new_max_hp) * ratio)), new_max_hp)
	else:
		hero["current_hp"] = min(old_current_hp, new_max_hp)

	hero_stats_changed.emit()



#############################
# XP Y LEVEL UP
#############################
func _add_hero_xp(amount: int) -> void:
	if amount <= 0:
		hero_xp_changed.emit(hero_xp, xp_to_next_level)
		return
	hero_xp += amount

	while hero_xp >= xp_to_next_level:
		hero_xp -= xp_to_next_level
		_level_up()

	hero_xp_changed.emit(hero_xp, xp_to_next_level)


func _level_up() -> void:
	hero_level += 1
	xp_to_next_level = _calc_xp_to_next_level(hero_level)
	hero_level_multiplier *= HERO_LEVEL_UP_STAT_MULT
	enemy_level_multiplier *= ENEMY_LEVEL_UP_STAT_MULT
	_rescale_all_cards_from_definitions()
	_sync_hero_card_level(true)
	_apply_equipment_to_hero()
	hero_level_up.emit(hero_level)


func _sync_hero_card_level(full_heal: bool) -> void:
	var hero: Dictionary = cards.get("th", {})
	if hero.is_empty():
		return

	var upgrade_level: int = int(hero.get("upgrade_level", 0))
	hero["level"] = hero_level + upgrade_level
	if full_heal:
		hero["current_hp"] = int(hero.get("max_hp", hero.get("current_hp", 0)))

func _scale_stat(value: int, is_hero: bool, upgrade_level: int) -> int:
	var mult := hero_level_multiplier if is_hero else enemy_level_multiplier
	if upgrade_level > 0:
		mult *= pow(_get_upgrade_multiplier(is_hero), upgrade_level)
	return int(round(float(value) * mult))

func _calc_xp_to_next_level(level: int) -> int:
	return BASE_XP_TO_LEVEL + max(0, level - 1) * XP_PER_LEVEL_STEP

func _get_upgrade_multiplier(is_hero: bool) -> float:
	return HERO_LEVEL_UP_STAT_MULT if is_hero else ENEMY_LEVEL_UP_STAT_MULT

func _rescale_all_cards_from_definitions() -> void:
	for card in cards.values():
		_rescale_card_from_definition(card)
		_update_card_level_from_definition(card)
		var is_hero: bool = card.get("id", "") == "th"
		if is_hero:
			recalc_card_stats(card, active_hero_traits)
		else:
			recalc_card_stats(card, active_enemy_traits)
	for queue in enemy_draw_queues_by_deck:
		for enemy in queue:
			_rescale_card_from_definition(enemy)
			_update_card_level_from_definition(enemy)

func _rescale_card_from_definition(card: Dictionary) -> void:
	if card.is_empty():
		return
	var def_id: String = String(card.get("definition", ""))
	if def_id.is_empty():
		return
	var def: CardDefinition = CardDatabase.get_definition(def_id)
	if def == null:
		return
	var is_hero: bool = card.get("id", "") == "th"
	var upgrade_level: int = int(card.get("upgrade_level", _get_upgrade_level(def_id)))
	card["upgrade_level"] = upgrade_level
	var scaled_hp: int = _scale_stat(def.max_hp, is_hero, upgrade_level)
	var scaled_damage: int = _scale_stat(def.damage, is_hero, upgrade_level)
	var scaled_initiative: int = _scale_stat(def.initiative, is_hero, upgrade_level)

	card["base_hp"] = scaled_hp
	card["base_damage"] = scaled_damage
	card["base_initiative"] = scaled_initiative

func _update_card_level_from_definition(card: Dictionary) -> void:
	if card.is_empty():
		return
	var def_id: String = String(card.get("definition", ""))
	if def_id.is_empty():
		return
	var def: CardDefinition = CardDatabase.get_definition(def_id)
	if def == null:
		return
	var upgrade_level: int = int(card.get("upgrade_level", _get_upgrade_level(def_id)))
	if card.get("id", "") == "th":
		card["level"] = hero_level + upgrade_level
	else:
		card["level"] = def.level + max(0, hero_level - 1) + upgrade_level

func _clear_active_traits_on_level_up() -> void:
	if active_hero_traits.is_empty() and active_enemy_traits.is_empty():
		return
	active_hero_traits.clear()
	active_enemy_traits.clear()
	for card in cards.values():
		if card.get("id", "") == "th":
			recalc_card_stats(card, active_hero_traits)
		else:
			recalc_card_stats(card, active_enemy_traits)
	for queue in enemy_draw_queues_by_deck:
		for enemy in queue:
			if enemy.get("id", "") == "th":
				continue
			recalc_card_stats(enemy, active_enemy_traits)
	recalculate_danger_level()
	enemy_stats_changed.emit()


#########################################################
# TRAITS
#########################################################
func get_random_hero_traits(amount: int) -> Array[TraitResource]:
	if trait_database == null:
		return []
	var pool := _filter_active_traits(trait_database.hero_traits, active_hero_traits)
	return _get_random_traits_from_pool(pool, amount)

func get_random_enemy_traits(amount: int) -> Array[TraitResource]:
	if trait_database == null:
		return []
	return _get_random_traits_from_pool(
		trait_database.enemy_traits,
		amount
	)

func _get_random_traits_from_pool(
	pool: Array[TraitResource],
	amount: int
) -> Array[TraitResource]:
	if pool.is_empty():
		return []

	var copy := pool.duplicate()
	copy.shuffle()
	return copy.slice(0, min(amount, copy.size()))

func _filter_active_traits(
	pool: Array[TraitResource],
	active: Array[TraitResource]
) -> Array[TraitResource]:
	if active.is_empty():
		return pool.duplicate()
	var active_ids: Array[String] = []
	for trait_res in active:
		if trait_res != null:
			active_ids.append(trait_res.trait_id)
	var result: Array[TraitResource] = []
	for trait_res in pool:
		if trait_res == null:
			continue
		if active_ids.has(trait_res.trait_id):
			continue
		result.append(trait_res)
	return result

func get_active_hero_traits() -> Array[TraitResource]:
	return active_hero_traits.duplicate()

func get_boss_traits_for_card(card_data: Dictionary) -> Array[TraitResource]:
	if card_data.is_empty():
		return []
	var boss_id := String(card_data.get("boss_id", ""))
	if boss_id.is_empty():
		return []
	var boss_def := get_boss_definition(boss_id)
	if boss_def == null:
		return []
	return boss_def.boss_traits.duplicate()


########################
# DEBUG
########################
func debug_print_traits() -> void:
	if trait_database == null:
		return

	print("=== HERO TRAITS ===")
	for trait_res in trait_database.hero_traits:
		print(trait_res.trait_id)

	print("=== ENEMY TRAITS ===")
	for trait_res in trait_database.enemy_traits:
		print(trait_res.trait_id)


# =========================
# GUARDADO / CARGA
# =========================

func save_run():
	if is_temporary_run:
		return

	var hero_trait_ids: Array[String] = []
	for trait_res in active_hero_traits:
		if trait_res != null:
			hero_trait_ids.append(trait_res.trait_id)

	var enemy_trait_ids: Array[String] = []
	for trait_res in active_enemy_traits:
		if trait_res != null:
			enemy_trait_ids.append(trait_res.trait_id)

	var enemy_draw_orders: Array = []
	for queue in enemy_draw_queues_by_deck:
		var ids: Array[String] = []
		for enemy in queue:
			var enemy_id := String(enemy.get("id", ""))
			if enemy_id != "":
				ids.append(enemy_id)
		enemy_draw_orders.append(ids)

	var enemy_draw_order: Array[String] = []
	if enemy_draw_orders.size() > 0 and enemy_draw_orders[0] is Array:
		enemy_draw_order = (enemy_draw_orders[0] as Array).duplicate()

	var data := {
		"run_mode": run_mode,
		"is_temporary_run": is_temporary_run,
		"gold": gold,
		"dust": dust,
		"danger_level": danger_level,
		"active_decks_count": active_decks_count,
		"enemies_defeated_count": enemies_defeated_count,
		"current_wave": current_wave,
		"waves_per_run": waves_per_run,
		"enemies_per_wave": enemies_per_wave,
		"enemies_defeated_in_wave": enemies_defeated_in_wave,
		"hero_level": hero_level,
		"hero_xp": hero_xp,
		"xp_to_next_level": xp_to_next_level,
		"cards": cards,
		"enemy_draw_orders": enemy_draw_orders,
		"enemy_draw_order": enemy_draw_order,
		"active_hero_traits": hero_trait_ids,
		"active_enemy_traits": enemy_trait_ids,
		"active_enemy_ids": active_enemy_ids,
		"active_enemy_id": active_enemy_ids[0] if active_enemy_ids.size() > 0 else "",
		"selected_hero_def_id": selected_hero_def_id,
		"selected_enemy_types": selected_enemy_types,
		"enemy_weights": enemy_weights,
		"run_deck_types": run_deck_types,
		"run_deck_types_by_deck": run_deck_types_by_deck,
		"run_seed": run_seed,
		"enemy_spawn_counter": enemy_spawn_counter,
		"hero_level_multiplier": hero_level_multiplier,
		"enemy_level_multiplier": enemy_level_multiplier,
		"item_instances": _serialize_item_instances(),
		"item_instance_counter": item_instance_counter,
		"hand_items": hand_items,
		"equipped_items": equipped_items,
		"completed_set_themes": completed_set_themes,
		"set_bonus_armour": set_bonus_armour,
		"set_bonus_damage": set_bonus_damage,
		"set_bonus_life": set_bonus_life,
		"set_bonus_initiative": set_bonus_initiative,
		"set_bonus_lifesteal": set_bonus_lifesteal,
		"set_bonus_thorns": set_bonus_thorns,
		"set_bonus_regen": set_bonus_regen,
		"set_bonus_crit": set_bonus_crit,
	}

	SaveSystem._ensure_save_dir()
	var file := FileAccess.open("user://save/save_run.json", FileAccess.WRITE)
	if file == null:
		push_error("[RunManager] No se pudo abrir save_run.json. user_dir=%s" % OS.get_user_data_dir())
		return
	file.store_string(JSON.stringify(data, "	"))
	file.close()

func load_run():
	if not FileAccess.file_exists("user://save/save_run.json"):
		return

	var file := FileAccess.open("user://save/save_run.json", FileAccess.READ)
	if file == null:
		push_error("[RunManager] No se pudo abrir save_run.json para lectura. user_dir=%s" % OS.get_user_data_dir())
		return
	var content = file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if data == null:
		push_error("Save corrupto")
		return

	if item_archetype_catalog == null:
		item_archetype_catalog = load(ITEM_ARCHETYPE_CATALOG_DEFAULT_PATH)

	run_mode = data.get("run_mode", "normal")
	is_temporary_run = data.get("is_temporary_run", false)
	gold = int(data.get("gold", 0))
	dust = int(data.get("dust", 0))
	danger_level = int(data.get("danger_level", 0))
	active_decks_count = int(data.get("active_decks_count", 1))
	enemies_defeated_count = int(data.get("enemies_defeated_count", 0))
	current_wave = int(data.get("current_wave", 1))
	waves_per_run = int(data.get("waves_per_run", 20))
	enemies_per_wave = int(data.get("enemies_per_wave", 5))
	enemies_defeated_in_wave = int(data.get("enemies_defeated_in_wave", 0))
	hero_level = int(data.get("hero_level", 1))
	hero_xp = int(data.get("hero_xp", 0))
	xp_to_next_level = _calc_xp_to_next_level(hero_level)
	cards = data.get("cards", {})
	_load_upgrade_levels()
	_sync_hero_card_level(false)
	item_instances = _deserialize_item_instances(data.get("item_instances", []))
	item_instance_counter = int(data.get("item_instance_counter", 0))
	if item_instance_counter <= 0 and not item_instances.is_empty():
		_recalc_item_instance_counter()
	hand_items = _to_string_array(data.get("hand_items", []))
	equipped_items = _to_string_array(data.get("equipped_items", []))
	hand_items = _filter_item_instance_ids(hand_items)
	equipped_items = _sanitize_equipped_items(equipped_items)
	_ensure_equipped_size()
	completed_set_themes = _to_string_array(data.get("completed_set_themes", []))
	set_bonus_armour = int(data.get("set_bonus_armour", 0))
	set_bonus_damage = int(data.get("set_bonus_damage", 0))
	set_bonus_life = int(data.get("set_bonus_life", 0))
	set_bonus_initiative = int(data.get("set_bonus_initiative", 0))
	set_bonus_lifesteal = int(data.get("set_bonus_lifesteal", 0))
	set_bonus_thorns = int(data.get("set_bonus_thorns", 0))
	set_bonus_regen = int(data.get("set_bonus_regen", 0))
	set_bonus_crit = int(data.get("set_bonus_crit", 0))

	if trait_database != null:
		trait_database.load_all()
	var trait_map := _build_trait_map()
	active_hero_traits = _resolve_traits(data.get("active_hero_traits", []), trait_map)
	active_enemy_traits = _resolve_traits(data.get("active_enemy_traits", []), trait_map)

	enemy_draw_queues_by_deck.clear()
	var enemy_draw_orders: Array = data.get("enemy_draw_orders", [])
	if enemy_draw_orders.is_empty():
		var enemy_draw_order: Array = data.get("enemy_draw_order", [])
		if not enemy_draw_order.is_empty():
			enemy_draw_orders = [enemy_draw_order]
	_ensure_deck_arrays(active_decks_count)
	for deck_index in range(active_decks_count):
		var queue: Array = []
		if deck_index < enemy_draw_orders.size() and enemy_draw_orders[deck_index] is Array:
			for enemy_id in enemy_draw_orders[deck_index]:
				var id_str := String(enemy_id)
				if cards.has(id_str):
					queue.append(cards[id_str])
		enemy_draw_queues_by_deck[deck_index] = queue

	if enemy_draw_queues_by_deck.is_empty() and not cards.is_empty():
		prepare_progressive_deck()

	var saved_ids: Array = data.get("active_enemy_ids", [])
	active_enemy_ids = _to_string_array(saved_ids)
	if active_enemy_ids.is_empty():
		var legacy_id := String(data.get("active_enemy_id", ""))
		if legacy_id != "":
			active_enemy_ids = [legacy_id]
	selected_hero_def_id = String(data.get("selected_hero_def_id", ""))
	selected_enemy_types = _to_string_array(data.get("selected_enemy_types", []))
	enemy_weights = _sanitize_enemy_weights(data.get("enemy_weights", {}))
	if enemy_weights.is_empty() and not selected_enemy_types.is_empty():
		for enemy_id in selected_enemy_types:
			if enemy_id != "":
				enemy_weights[enemy_id] = 1
	run_deck_types = _to_string_array(data.get("run_deck_types", []))
	run_deck_types_by_deck = data.get("run_deck_types_by_deck", [])
	if run_deck_types_by_deck.is_empty() and not run_deck_types.is_empty():
		run_deck_types_by_deck = [run_deck_types.duplicate()]
	_ensure_deck_arrays(active_decks_count)
	run_seed = int(data.get("run_seed", 0))
	enemy_spawn_counter = int(data.get("enemy_spawn_counter", 0))
	hero_level_multiplier = float(data.get("hero_level_multiplier", 1.0))
	enemy_level_multiplier = float(data.get("enemy_level_multiplier", 1.0))
	if active_enemy_ids.size() > 0:
		var cleaned: Array[String] = []
		for enemy_id in active_enemy_ids:
			if cards.has(enemy_id):
				cleaned.append(enemy_id)
		active_enemy_ids = cleaned

	run_loaded = true
	_emit_run_state_signals()
	_apply_equipment_to_hero()

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_STRING:
			result.append(String(entry))
	return result

func _sanitize_enemy_weights(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var dict_value := value as Dictionary
	for key in dict_value.keys():
		var id_str := String(key)
		if id_str == "":
			continue
		var weight := int(dict_value.get(key, 1))
		result[id_str] = clampi(weight, 1, 3)
	return result

func _serialize_item_instances() -> Array:
	var result: Array = []
	for key in item_instances.keys():
		var raw: Variant = item_instances.get(key, null)
		if raw is ItemInstance:
			var inst: ItemInstance = raw
			result.append(inst.to_dict())
	return result

func _deserialize_item_instances(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_ARRAY:
		return result
	var list := value as Array
	for entry in list:
		if entry is Dictionary:
			var inst := ItemInstance.from_dict(entry, item_archetype_catalog)
			if inst != null and inst.archetype != null and not inst.instance_id.is_empty():
				result[inst.instance_id] = inst
	return result

func _filter_item_instance_ids(items: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item_id in items:
		if item_instances.has(item_id):
			result.append(item_id)
	return result

func _sanitize_equipped_items(items: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for i in range(MAX_EQUIP_SLOTS):
		var id := ""
		if i < items.size():
			id = items[i]
		if id != "" and not item_instances.has(id):
			id = ""
		result.append(id)
	return result

func _recalc_item_instance_counter() -> void:
	var max_id: int = 0
	for key in item_instances.keys():
		var id_str := String(key)
		var parts := id_str.split("_")
		if parts.size() < 3:
			continue
		var num_str := parts[parts.size() - 1]
		if not num_str.is_valid_int():
			continue
		var num := int(num_str)
		if num > max_id:
			max_id = num
	item_instance_counter = max_id

func _ensure_equipped_size() -> void:
	while equipped_items.size() < MAX_EQUIP_SLOTS:
		equipped_items.append("")
	if equipped_items.size() > MAX_EQUIP_SLOTS:
		equipped_items = equipped_items.slice(0, MAX_EQUIP_SLOTS)

func has_saved_run() -> bool:
	if not FileAccess.file_exists("user://save/save_run.json"):
		return false
	var file = FileAccess.open("user://save/save_run.json", FileAccess.READ)
	if file == null:
		return false
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	return data != null and data.size() > 0

func _build_trait_map() -> Dictionary:
	var map := {}
	if trait_database == null:
		return map
	for trait_res in trait_database.hero_traits:
		map[trait_res.trait_id] = trait_res
	for trait_res in trait_database.enemy_traits:
		map[trait_res.trait_id] = trait_res
	return map

func _resolve_traits(ids: Array, trait_map: Dictionary) -> Array[TraitResource]:
	var result: Array[TraitResource] = []
	for trait_id in ids:
		if trait_map.has(trait_id):
			result.append(trait_map[trait_id])
		else:
			push_warning("[RunManager] Trait no encontrado: " + String(trait_id))
	return result

func _emit_run_state_signals() -> void:
	gold_changed.emit(gold)
	dust_changed.emit(dust, 0)
	danger_level_changed.emit(danger_level)
	active_decks_changed.emit(active_decks_count)
	hero_xp_changed.emit(hero_xp, xp_to_next_level)
	hand_changed.emit(hand_items)
	equip_changed.emit(equipped_items)


func _build_cards_from_run_deck() -> void:
	if selected_hero_def_id == "":
		return
	create_card_instance("th", selected_hero_def_id, false, -1)

func start_wave_encounter() -> void:
	if current_wave > waves_per_run:
		return
	_clear_enemy_cards()
	enemy_draw_queues_by_deck.clear()
	_ensure_deck_arrays(1)
	active_decks_count = 1
	active_enemy_ids.clear()
	enemies_defeated_in_wave = 0

	wave_started.emit(current_wave, waves_per_run)

	if _is_mini_boss_wave(current_wave):
		var mini_id := _pick_mini_boss_id()
		if not mini_id.is_empty():
			_spawn_boss_by_id(mini_id)
			mini_boss_started.emit(mini_id)
		prepare_progressive_deck()
		wave_progress_changed.emit(current_wave, 0, 0)
		return

	if _is_final_boss_wave(current_wave):
		_spawn_boss_by_id(FINAL_BOSS_ID)
		final_boss_started.emit(FINAL_BOSS_ID)
		prepare_progressive_deck()
		wave_progress_changed.emit(current_wave, 0, 0)
		return

	if selected_enemy_types.is_empty():
		return

	for i in range(enemies_per_wave):
		var def_id := _pick_random_enemy_type()
		var run_id := _generate_enemy_id(def_id)
		create_card_instance(run_id, def_id, false, 0)

	prepare_progressive_deck()
	wave_progress_changed.emit(current_wave, enemies_defeated_in_wave, enemies_per_wave)

func handle_enemy_defeated_for_wave(enemy_data: Dictionary) -> bool:
	if enemy_data.is_empty():
		return false

	var is_boss: bool = bool(enemy_data.get("is_boss", false)) or enemy_data.has("boss_id")
	if is_boss:
		var boss_kind := int(enemy_data.get("boss_kind", BossDefinition.BossKind.MINI_BOSS))
		wave_completed.emit(current_wave)
		if boss_kind == BossDefinition.BossKind.FINAL_BOSS:
			return true
		current_wave += 1
		enemies_defeated_in_wave = 0
		if current_wave > waves_per_run:
			return true
		start_wave_encounter()
		return false

	enemies_defeated_in_wave += 1
	wave_progress_changed.emit(current_wave, enemies_defeated_in_wave, enemies_per_wave)
	if enemies_defeated_in_wave >= enemies_per_wave:
		wave_completed.emit(current_wave)
		current_wave += 1
		enemies_defeated_in_wave = 0
		if current_wave > waves_per_run:
			return true
		start_wave_encounter()

	return false

func is_wave_boss(wave_index: int) -> bool:
	return _is_mini_boss_wave(wave_index) or _is_final_boss_wave(wave_index)

func is_current_wave_boss() -> bool:
	return is_wave_boss(current_wave)

func _is_mini_boss_wave(wave_index: int) -> bool:
	return MINI_BOSS_WAVES.has(wave_index)

func _is_final_boss_wave(wave_index: int) -> bool:
	return wave_index == waves_per_run or FINAL_BOSS_WAVES.has(wave_index)

func _pick_random_enemy_type() -> String:
	if selected_enemy_types.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + (current_wave * 733) + enemy_spawn_counter
	var idx := rng.randi_range(0, selected_enemy_types.size() - 1)
	return selected_enemy_types[idx]

func _maybe_add_wave_boss() -> void:
	if MINI_BOSS_WAVES.has(current_wave):
		_spawn_mini_boss()
		return
	if FINAL_BOSS_WAVES.has(current_wave):
		_spawn_final_boss()

func _spawn_mini_boss() -> void:
	var boss_id := _pick_mini_boss_id()
	if boss_id.is_empty():
		return
	_spawn_boss_by_id(boss_id)

func _spawn_final_boss() -> void:
	_spawn_boss_by_id(FINAL_BOSS_ID)

func _spawn_boss_by_id(boss_id: String) -> void:
	_ensure_boss_catalog()
	var boss_def := get_boss_definition(boss_id)
	if boss_def == null:
		push_warning("[RunManager] BossDefinition no encontrada: " + boss_id)
		return
	create_boss_instance(boss_def, 0)

func _pick_mini_boss_id() -> String:
	if MINI_BOSS_IDS.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + (current_wave * 911) + 17
	var idx := rng.randi_range(0, MINI_BOSS_IDS.size() - 1)
	return MINI_BOSS_IDS[idx]

func reset_run(new_mode: String = "normal") -> void:
	run_mode = new_mode
	is_temporary_run = false
	cards.clear()
	enemy_draw_queues_by_deck.clear()
	active_hero_traits.clear()
	active_enemy_traits.clear()
	gold = 0
	danger_level = 0
	selected_hero_def_id = ""
	selected_enemy_types.clear()
	enemy_weights.clear()
	run_deck_types.clear()
	run_deck_types_by_deck.clear()
	run_seed = 0
	enemy_spawn_counter = 0
	active_decks_count = 1
	enemies_defeated_count = 0
	current_wave = 1
	waves_per_run = 20
	enemies_per_wave = 5
	enemies_defeated_in_wave = 0
	hero_level = 1
	hero_xp = 0
	xp_to_next_level = _calc_xp_to_next_level(hero_level)
	hero_level_multiplier = 1.0
	enemy_level_multiplier = 1.0
	_upgrade_level_map.clear()
	run_loaded = false
	active_enemy_ids.clear()
	hand_items.clear()
	item_instances.clear()
	item_instance_counter = 0
	equipped_items = ["", "", "", "", "", "", ""]
	completed_set_themes.clear()
	set_bonus_armour = 0
	set_bonus_damage = 0
	set_bonus_life = 0
	set_bonus_initiative = 0
	set_bonus_lifesteal = 0
	set_bonus_thorns = 0
	set_bonus_regen = 0
	set_bonus_crit = 0
	_apply_equipment_to_hero()

func refresh_upgrades_for_definition(def_id: String = "") -> void:
	_load_upgrade_levels()
	if cards.is_empty():
		return
	for card in cards.values():
		if not def_id.is_empty() and String(card.get("definition", "")) != def_id:
			continue
		_rescale_card_from_definition(card)
		_update_card_level_from_definition(card)
		var is_hero: bool = card.get("id", "") == "th"
		if is_hero:
			recalc_card_stats(card, active_hero_traits)
		else:
			recalc_card_stats(card, active_enemy_traits)
	for queue in enemy_draw_queues_by_deck:
		for enemy in queue:
			if not def_id.is_empty() and String(enemy.get("definition", "")) != def_id:
				continue
			_rescale_card_from_definition(enemy)
			_update_card_level_from_definition(enemy)
			recalc_card_stats(enemy, active_enemy_traits)
	_apply_equipment_to_hero()
	recalculate_danger_level()
	hero_stats_changed.emit()
	enemy_stats_changed.emit()

func _load_upgrade_levels() -> void:
	_upgrade_level_map.clear()
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	if collection == null:
		return
	for def_id in collection.upgrade_level.keys():
		var key := String(def_id)
		_upgrade_level_map[key] = int(collection.upgrade_level.get(def_id, 0))

func _get_upgrade_level(def_id: String) -> int:
	if def_id.is_empty():
		return 0
	if _upgrade_level_map.is_empty():
		_load_upgrade_levels()
	return int(_upgrade_level_map.get(def_id, 0))

func try_start_next_wave() -> bool:
	if current_wave >= waves_per_run:
		return false
	current_wave += 1
	start_wave_encounter()
	return true

func _clear_enemy_cards() -> void:
	var to_remove: Array[String] = []
	for id in cards.keys():
		if id == "th":
			continue
		to_remove.append(String(id))
	for id in to_remove:
		cards.erase(id)


#####################################################################################################
#####   ORDENAMIENTO DE CARTAS, BOSS FINAL, ETC #####################################################
#####################################################################################################

func prepare_progressive_deck() -> void:
	# =========================
	# RESET DEL MAZO
	# =========================
	enemy_draw_queues_by_deck.clear()
	_ensure_deck_arrays(active_decks_count)

	# =========================
	# RECOLECTAR ENEMIGOS
	# =========================
	var enemies_by_deck: Array = []
	for i in range(active_decks_count):
		enemies_by_deck.append([])

	for card in cards.values():
		if card.get("id", "") == "th":
			continue
		var deck_index := int(card.get("deck_index", 0))
		if deck_index < 0 or deck_index >= active_decks_count:
			deck_index = 0
		(enemies_by_deck[deck_index] as Array).append(card)

	var has_any := false
	for deck_list in enemies_by_deck:
		if (deck_list as Array).size() > 0:
			has_any = true
			break
	if not has_any:
		return

	for deck_index in range(active_decks_count):
		var deck_enemies: Array[Dictionary] = []
		var raw_deck: Variant = enemies_by_deck[deck_index]
		if raw_deck is Array:
			for entry in raw_deck:
				if entry is Dictionary:
					deck_enemies.append(entry)
		deck_enemies.shuffle()
		enemy_draw_queues_by_deck[deck_index] = deck_enemies

	# =========================
	# RECALCULAR RIESGO
	# =========================
	recalculate_danger_level()

	
# =========================
# APLICACIÃƒÆ’Ã¢â‚¬Å“N DE TRAITS
# =========================
func apply_hero_trait(trait_res: TraitResource) -> void:
	if trait_res == null:
		return

	active_hero_traits.append(trait_res)

	var hero: Dictionary = cards.get("th", {})
	if hero.is_empty():
		return

	recalc_card_stats(hero, active_hero_traits)






func apply_enemy_trait(trait_res: TraitResource) -> void:
	if trait_res == null:
		return

	active_enemy_traits.append(trait_res)

	for card in cards.values():
		if card.get("id", "") == "th":
			continue
		recalc_card_stats(card, active_enemy_traits)

	for queue in enemy_draw_queues_by_deck:
		for enemy in queue:
			if enemy.get("id", "") == "th":
				continue
			recalc_card_stats(enemy, active_enemy_traits)

	recalculate_danger_level()
	enemy_stats_changed.emit()










func remove_enemy_trait(trait_res: TraitResource) -> void:
	active_enemy_traits.erase(trait_res)

	for card in cards.values():
		if card["id"] == "th":
			continue
		recalc_card_stats(card, active_enemy_traits)

func has_remaining_enemies(exclude_id: String = "") -> bool:
	for i in range(enemy_draw_queues_by_deck.size()):
		var raw: Variant = enemy_draw_queues_by_deck[i]
		if raw is Array:
			var cleaned := _clean_enemy_queue(raw)
			if cleaned.size() > 0:
				return true
			if cleaned.size() != (raw as Array).size():
				enemy_draw_queues_by_deck[i] = cleaned
	for card in cards.values():
		if card.get("id", "") == "th":
			continue
		if exclude_id != "" and card.get("id", "") == exclude_id:
			continue
		return true
	return false

func _clean_enemy_queue(queue: Array) -> Array:
	var cleaned: Array = []
	for entry in queue:
		if entry is Dictionary:
			var id_str := String(entry.get("id", ""))
			if id_str != "" and cards.has(id_str):
				cleaned.append(entry)
	return cleaned


func replace_enemy_trait(old_trait, new_trait) -> void:
	active_enemy_traits.erase(old_trait)
	active_enemy_traits.append(new_trait)

	for card in cards.values():
		if card["id"] == "th":
			continue
		recalc_card_stats(card, active_enemy_traits)
