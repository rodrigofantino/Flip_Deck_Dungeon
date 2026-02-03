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

var enemy_draw_queue: Array[Dictionary] = [] # orden real de robo

# =========================
# ITEMS (HAND / EQUIP)
# =========================
const MAX_HAND_SIZE: int = 5
const MAX_EQUIP_SLOTS: int = 8
const ITEM_DROP_CHANCE: float = 0.25
const ITEM_CATALOG_DEFAULT_PATH: String = "res://data/item_catalog_default.tres"

@export var item_catalog: ItemCatalog

var hand_items: Array[String] = []
var equipped_items: Array[String] = ["", "", "", "", "", "", "", ""]

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

# =========================
# ESTADO ECONOMÃƒÆ’Ã‚ÂA / RIESGO
# =========================

var gold: int = 0
var danger_level: int = 0
var active_decks_count: int = 1
var enemies_defeated_count: int = 0
@export var crossroads_every_n: int = 3

# =========================
# TRAITS ACTIVOS
# =========================

var active_hero_traits: Array[TraitResource] = []
var active_enemy_traits: Array[TraitResource] = []
var run_loaded: bool = false
var selection_pending: bool = false
var active_enemy_id: String = ""

# =========================
# SELECCION / RUN DECK (TYPES)
# =========================
var selected_hero_def_id: String = ""
var selected_enemy_types: Array[String] = []
var run_deck_types: Array[String] = []
var run_seed: int = 0
var enemy_spawn_counter: int = 0
const RUN_DECK_SIZE: int = 20
var current_wave: int = 1
const MAX_WAVES: int = 5

# =========================
# PROGRESIÃƒÆ’Ã¢â‚¬Å“N DEL JUGADOR
# =========================

signal hero_xp_changed(current_xp: int, xp_to_next: int)
signal hero_level_up(new_level: int)

var hero_level: int = 1
var hero_xp: int = 0
var xp_to_next_level: int = 4

const XP_GROWTH_FACTOR: float = 2.0
const LEVEL_UP_STAT_MULT: float = 1.2
var level_stat_multiplier: float = 1.0

# =========================
# BASE DE DATOS DE TRAITS
# =========================
const TRAIT_DB_PATH := "res://data/traits/trait_database_default.tres"
@export var trait_database: TraitDatabase



func _ready() -> void:
	item_drop_rng.randomize()
	if trait_database == null:
		trait_database = load(TRAIT_DB_PATH)
	if item_catalog == null:
		item_catalog = load(ITEM_CATALOG_DEFAULT_PATH)
	_apply_equipment_to_hero()

	if trait_database == null:
		push_error("[RunManager] TraitDatabase NO pudo cargarse")
	else:
		print("[RunManager] TraitDatabase cargada OK")
		debug_print_traits()

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



# =========================
# =========================
# SELECCION / RUN DECK (TYPES)
# =========================
func set_run_selection(hero_def_id: String, enemy_types: Array[String]) -> void:
	selected_hero_def_id = hero_def_id
	selected_enemy_types = enemy_types.duplicate()
	run_deck_types.clear()
	enemy_draw_queue.clear()
	enemy_spawn_counter = 0
	run_seed = int(Time.get_ticks_msec())
	current_wave = 1

func build_run_deck_from_selection() -> void:
	if selected_enemy_types.is_empty():
		return
	if run_seed == 0:
		run_seed = int(Time.get_ticks_msec())
	_build_run_deck_types()
	SaveSystem.save_run_deck(run_deck_types)

func _build_run_deck_types() -> void:
	run_deck_types.clear()
	if selected_enemy_types.is_empty():
		return
	if run_seed == 0:
		run_seed = int(Time.get_ticks_msec())
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	for i in range(RUN_DECK_SIZE):
		var idx := rng.randi_range(0, selected_enemy_types.size() - 1)
		run_deck_types.append(selected_enemy_types[idx])

func remove_run_deck_type(definition_id: String) -> void:
	if definition_id == "":
		return
	for i in range(run_deck_types.size()):
		if run_deck_types[i] == definition_id:
			run_deck_types.remove_at(i)
			return

func _generate_enemy_id(definition_id: String) -> String:
	enemy_spawn_counter += 1
	return "e_%s_%d" % [definition_id, enemy_spawn_counter]

# CREATE CARD INSTANCE (RUNTIME)
# =========================
func create_card_instance(
	id: String,
	definition_key: String,
	is_tutorial := false
) -> Dictionary:
	var def: CardDefinition = CardDatabase.get_definition(definition_key)
	if def == null:
		push_error("Definition no encontrada: " + definition_key)
		return {}

	var scaled_hp: int = _scale_stat(def.max_hp)
	var scaled_damage: int = _scale_stat(def.damage)
	var scaled_initiative: int = _scale_stat(def.initiative)

	var card_level: int = def.level
	if id == "th":
		card_level = hero_level
	else:
		card_level = def.level + max(0, hero_level - 1)

	var card := {
		"id": id,
		"definition": definition_key,
		"is_tutorial": is_tutorial,

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
	if enemy_draw_queue.is_empty():
		prepare_progressive_deck()

	if enemy_draw_queue.is_empty():
		return {}

	var enemy: Dictionary = enemy_draw_queue.pop_front()
	recalc_card_stats(enemy, active_enemy_traits)

	print(
		"[DRAW] TOP OF DECK ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢",
		enemy.get("definition", "???"),
		"| Power:",
		calculate_enemy_power(enemy),
		"| Remaining:",
		enemy_draw_queue.size()
	)

	return enemy



########################################
# LIMPIEZA DE CARTAS DE TUTORIAL
########################################
func clear_tutorial_cards():
	var ids_to_remove := []

	for id in cards.keys():
		if id.begins_with("t"):
			ids_to_remove.append(id)

	for id in ids_to_remove:
		cards.erase(id)


########################################
# CONSULTA DE CARTAS
########################################
func get_card(id: String):
	return cards.get(id, {})

func get_all_cards():
	return cards.values()

func get_tutorial_cards():
	var result := []
	for card in cards.values():
		if card.is_tutorial:
			result.append(card)
	return result


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
	var xp_reward: int = max(1, enemy_level)

	_add_gold(gold_reward)
	_add_hero_xp(xp_reward)

func try_drop_item_from_enemy() -> void:
	if item_catalog == null or item_catalog.items.is_empty():
		return
	if item_drop_rng.randf() > ITEM_DROP_CHANCE:
		return
	var pool: Array[ItemCardDefinition] = []
	for item_def in item_catalog.items:
		if item_def != null:
			pool.append(item_def)
	if pool.is_empty():
		return
	var idx := item_drop_rng.randi_range(0, pool.size() - 1)
	var def: ItemCardDefinition = pool[idx]
	if def == null:
		return
	_add_item_to_hand(def.item_id)
	item_dropped.emit(def.item_id)

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
	return active_decks_count < 3

func add_deck() -> void:
	if not can_add_deck():
		return
	active_decks_count += 1
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

func _add_item_to_hand(item_id: String) -> void:
	if item_id.is_empty():
		return
	if hand_items.size() >= MAX_HAND_SIZE:
		hand_items.remove_at(0)
	hand_items.append(item_id)
	hand_changed.emit(hand_items)

func equip_item_from_hand(item_id: String, slot_index: int) -> void:
	if item_id.is_empty():
		return
	if not hand_items.has(item_id):
		return

	var idx := slot_index
	if idx < 0 or idx >= MAX_EQUIP_SLOTS:
		idx = _find_first_empty_slot()
		if idx == -1:
			idx = 0

	equipped_items[idx] = item_id
	hand_items.erase(item_id)
	hand_changed.emit(hand_items)
	equip_changed.emit(equipped_items)
	_apply_equipment_to_hero()

func _find_first_empty_slot() -> int:
	for i in range(MAX_EQUIP_SLOTS):
		if equipped_items[i].is_empty():
			return i
	return -1

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

	if item_catalog != null:
		for item_id in equipped_items:
			if item_id.is_empty():
				continue
			var def := item_catalog.get_item_by_id(item_id)
			if def == null:
				continue
			add_hp += def.life_flat
			add_damage += def.damage_flat
			add_initiative += def.initiative_flat
			add_armour += def.armour_flat
			add_armour += def.shield_flat
			add_lifesteal += def.lifesteal_flat
			add_thorns += def.thorns_flat
			add_regen += def.regen_flat
			add_crit += def.crit_chance_flat

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
	hero_xp += amount

	while hero_xp >= xp_to_next_level:
		hero_xp -= xp_to_next_level
		_level_up()

	hero_xp_changed.emit(hero_xp, xp_to_next_level)


func _level_up() -> void:
	hero_level += 1
	xp_to_next_level = int(float(xp_to_next_level) * XP_GROWTH_FACTOR)
	level_stat_multiplier *= LEVEL_UP_STAT_MULT
	_rescale_all_cards_from_definitions()
	_sync_hero_card_level(true)
	_clear_active_traits_on_level_up()
	_apply_equipment_to_hero()
	hero_level_up.emit(hero_level)


func _sync_hero_card_level(full_heal: bool) -> void:
	var hero: Dictionary = cards.get("th", {})
	if hero.is_empty():
		return

	hero["level"] = hero_level
	if full_heal:
		hero["current_hp"] = int(hero.get("max_hp", hero.get("current_hp", 0)))

func _scale_stat(value: int) -> int:
	return int(round(float(value) * level_stat_multiplier))

func _rescale_all_cards_from_definitions() -> void:
	for card in cards.values():
		_rescale_card_from_definition(card)
		_update_card_level_from_definition(card)
		var is_hero: bool = card.get("id", "") == "th"
		if is_hero:
			recalc_card_stats(card, active_hero_traits)
		else:
			recalc_card_stats(card, active_enemy_traits)
	for enemy in enemy_draw_queue:
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
	var scaled_hp: int = _scale_stat(def.max_hp)
	var scaled_damage: int = _scale_stat(def.damage)
	var scaled_initiative: int = _scale_stat(def.initiative)

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
	if card.get("id", "") == "th":
		card["level"] = hero_level
	else:
		card["level"] = def.level + max(0, hero_level - 1)

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
	for enemy in enemy_draw_queue:
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
	return _get_random_traits_from_pool(
		trait_database.hero_traits,
		amount
	)

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

	var enemy_draw_order: Array[String] = []
	for enemy in enemy_draw_queue:
		var enemy_id := String(enemy.get("id", ""))
		if enemy_id != "":
			enemy_draw_order.append(enemy_id)

	var data := {
		"run_mode": run_mode,
		"is_temporary_run": is_temporary_run,
		"gold": gold,
		"danger_level": danger_level,
		"active_decks_count": active_decks_count,
		"enemies_defeated_count": enemies_defeated_count,
		"hero_level": hero_level,
		"hero_xp": hero_xp,
		"xp_to_next_level": xp_to_next_level,
		"cards": cards,
		"enemy_draw_order": enemy_draw_order,
		"active_hero_traits": hero_trait_ids,
		"active_enemy_traits": enemy_trait_ids,
		"active_enemy_id": active_enemy_id,
		"selected_hero_def_id": selected_hero_def_id,
		"selected_enemy_types": selected_enemy_types,
		"run_deck_types": run_deck_types,
		"run_seed": run_seed,
		"enemy_spawn_counter": enemy_spawn_counter,
		"level_stat_multiplier": level_stat_multiplier,
		"hand_items": hand_items,
		"equipped_items": equipped_items,
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

	run_mode = data.get("run_mode", "normal")
	is_temporary_run = data.get("is_temporary_run", false)
	gold = int(data.get("gold", 0))
	danger_level = int(data.get("danger_level", 0))
	active_decks_count = int(data.get("active_decks_count", 1))
	enemies_defeated_count = int(data.get("enemies_defeated_count", 0))
	hero_level = int(data.get("hero_level", 1))
	hero_xp = int(data.get("hero_xp", 0))
	xp_to_next_level = int(data.get("xp_to_next_level", 4))
	cards = data.get("cards", {})
	_sync_hero_card_level(false)
	hand_items = _to_string_array(data.get("hand_items", []))
	equipped_items = _to_string_array(data.get("equipped_items", []))
	_ensure_equipped_size()

	if trait_database != null:
		trait_database.load_all()
	var trait_map := _build_trait_map()
	active_hero_traits = _resolve_traits(data.get("active_hero_traits", []), trait_map)
	active_enemy_traits = _resolve_traits(data.get("active_enemy_traits", []), trait_map)

	enemy_draw_queue.clear()
	var enemy_draw_order: Array = data.get("enemy_draw_order", [])
	for enemy_id in enemy_draw_order:
		if cards.has(enemy_id):
			enemy_draw_queue.append(cards[enemy_id])

	if enemy_draw_queue.is_empty() and not cards.is_empty():
		prepare_progressive_deck()

	active_enemy_id = String(data.get("active_enemy_id", ""))
	selected_hero_def_id = String(data.get("selected_hero_def_id", ""))
	selected_enemy_types = _to_string_array(data.get("selected_enemy_types", []))
	run_deck_types = _to_string_array(data.get("run_deck_types", []))
	run_seed = int(data.get("run_seed", 0))
	enemy_spawn_counter = int(data.get("enemy_spawn_counter", 0))
	level_stat_multiplier = float(data.get("level_stat_multiplier", 1.0))
	if active_enemy_id != "" and not cards.has(active_enemy_id):
		active_enemy_id = ""

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
	danger_level_changed.emit(danger_level)
	active_decks_changed.emit(active_decks_count)
	hero_xp_changed.emit(hero_xp, xp_to_next_level)
	hand_changed.emit(hand_items)
	equip_changed.emit(equipped_items)


func _build_cards_from_run_deck() -> void:
	if selected_hero_def_id == "":
		return
	create_card_instance("th", selected_hero_def_id, false)

	if run_deck_types.is_empty():
		_build_run_deck_types()

	for def_id in run_deck_types:
		var run_id := _generate_enemy_id(def_id)
		create_card_instance(run_id, def_id, false)

func reset_run(new_mode: String = "normal") -> void:
	run_mode = new_mode
	is_temporary_run = false
	cards.clear()
	enemy_draw_queue.clear()
	active_hero_traits.clear()
	active_enemy_traits.clear()
	gold = 0
	danger_level = 0
	selected_hero_def_id = ""
	selected_enemy_types.clear()
	run_deck_types.clear()
	run_seed = 0
	enemy_spawn_counter = 0
	active_decks_count = 1
	enemies_defeated_count = 0
	current_wave = 1
	hero_level = 1
	hero_xp = 0
	xp_to_next_level = 4
	level_stat_multiplier = 1.0
	run_loaded = false
	active_enemy_id = ""
	hand_items.clear()
	equipped_items = ["", "", "", "", "", "", "", ""]
	_apply_equipment_to_hero()

func try_start_next_wave() -> bool:
	if current_wave >= MAX_WAVES:
		return false
	current_wave += 1
	_clear_enemy_cards()
	run_deck_types.clear()
	enemy_draw_queue.clear()
	enemy_spawn_counter = 0
	_build_run_deck_types()
	for def_id in run_deck_types:
		var run_id := _generate_enemy_id(def_id)
		create_card_instance(run_id, def_id, false)
	prepare_progressive_deck()
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
	enemy_draw_queue.clear()

	# =========================
	# RECOLECTAR ENEMIGOS
	# =========================
	var enemies: Array[Dictionary] = []

	for card in cards.values():
		if card.get("id", "") == "th":
			continue
		enemies.append(card)

	if enemies.is_empty():
		return

	# =========================
	# CALCULAR PODER PROMEDIO
	# =========================
	var total_power: int = 0
	for enemy in enemies:
		total_power += calculate_enemy_power(enemy)

	var avg_power: float = float(total_power) / float(enemies.size())

	# =========================
	# DETECTAR BOSS (OUTLIER)
	# =========================
	var boss: Dictionary = {}
	var boss_power: int = 0

	for enemy in enemies:
		var p: int = calculate_enemy_power(enemy)
		if p > avg_power * 2.5 and p > boss_power:
			boss = enemy
			boss_power = p

	if not boss.is_empty():
		enemies.erase(boss)

	# =========================
	# ORDENAR POR DIFICULTAD
	# =========================
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return calculate_enemy_power(a) < calculate_enemy_power(b)
	)

	# =========================
	# DIVIDIR EN BUCKETS
	# =========================
	var bucket_easy: Array[Dictionary] = []
	var bucket_mid: Array[Dictionary] = []
	var bucket_hard: Array[Dictionary] = []

	var third: int = max(1, enemies.size() / 3)

	for i in range(enemies.size()):
		if i < third:
			bucket_easy.append(enemies[i])
		elif i < third * 2:
			bucket_mid.append(enemies[i])
		else:
			bucket_hard.append(enemies[i])

	# =========================
	# SHUFFLE INTERNO
	# =========================
	bucket_easy.shuffle()
	bucket_mid.shuffle()
	bucket_hard.shuffle()

	# =========================
	# CONSTRUIR MAZO FINAL
	# =========================
	enemy_draw_queue.append_array(bucket_easy)
	enemy_draw_queue.append_array(bucket_mid)
	enemy_draw_queue.append_array(bucket_hard)

	# Boss siempre al final
	if not boss.is_empty():
		enemy_draw_queue.append(boss)

	# =========================
	# DEBUG (opcional)
	# =========================
	print("[DECK READY] Orden final:")
	for i in range(enemy_draw_queue.size()):
		var enemy := enemy_draw_queue[i]

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

	for enemy in enemy_draw_queue:
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

func replace_enemy_trait(old_trait, new_trait) -> void:
	active_enemy_traits.erase(old_trait)
	active_enemy_traits.append(new_trait)

	for card in cards.values():
		if card["id"] == "th":
			continue
		recalc_card_stats(card, active_enemy_traits)
