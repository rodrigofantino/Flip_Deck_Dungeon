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
# SEÃ‘ALES DE PROGRESIÃ“N
# =========================

signal gold_changed(new_gold: int)
signal danger_level_changed(new_danger: int)
signal enemy_stats_changed()

# =========================
# ESTADO ECONOMÃA / RIESGO
# =========================

var gold: int = 0
var danger_level: int = 0

# =========================
# TRAITS ACTIVOS
# =========================

var active_hero_traits: Array[TraitResource] = []
var active_enemy_traits: Array[TraitResource] = []
var run_loaded: bool = false
var selection_pending: bool = false
var active_enemy_id: String = ""

# =========================
# PROGRESIÃ“N DEL JUGADOR
# =========================

signal hero_xp_changed(current_xp: int, xp_to_next: int)
signal hero_level_up(new_level: int)

var hero_level: int = 1
var hero_xp: int = 0
var xp_to_next_level: int = 4

const XP_GROWTH_FACTOR: float = 1.25

# =========================
# BASE DE DATOS DE TRAITS
# =========================
const TRAIT_DB_PATH := "res://data/traits/trait_database_default.tres"
@export var trait_database: TraitDatabase



func _ready() -> void:
	if trait_database == null:
		trait_database = load(TRAIT_DB_PATH)

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

	if cards.is_empty() or not cards.has("th"):
		cards.clear()
		_build_cards_from_run_deck()
		_sync_hero_card_level(false)

	# ðŸ”‘ APLICAR TRAITS ACTIVOS A ENEMIGOS YA EXISTENTES
	for card in cards.values():
		if card.get("id", "") == "th":
			recalc_card_stats(card, active_hero_traits)
		else:
			recalc_card_stats(card, active_enemy_traits)



# =========================
# CREATE CARD INSTANCE (RUNTIME)
# =========================
func create_card_instance(
	id: String,
	definition_key: String,
	is_tutorial := false,
	collection_id: String = ""
) -> void:
	var def: CardDefinition = CardDatabase.get_definition(definition_key)
	if def == null:
		push_error("Definition no encontrada: " + definition_key)
		return

	var card := {
		"id": id,
		"collection_id": collection_id,
		"definition": definition_key,
		"is_tutorial": is_tutorial,

		# BASE
		"base_hp": def.max_hp,
		"base_damage": def.damage,
		"base_initiative": def.initiative,

		# RUNTIME
		"max_hp": def.max_hp,
		"current_hp": def.max_hp,
		"damage": def.damage,
		"initiative": def.initiative,

		"level": def.level
	}

	cards[id] = card

	# ðŸ”‘ APLICAR TRAITS ACTIVOS
	if id == "th":
		recalc_card_stats(card, active_hero_traits)
	else:
		recalc_card_stats(card, active_enemy_traits)


	# =========================
	# ðŸ§¬ APLICAR TRAITS A ENEMIGOS NUEVOS
	# =========================
	if id != "th":
		for trait_res: TraitResource in active_enemy_traits:
			print("[TRAIT] Aplicando trait activo a enemigo NUEVO:", id)
			

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
		"[DRAW] TOP OF DECK â†’",
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
	var power: int = calculate_enemy_power(enemy)

	var gold_reward: int = int(power * 0.5)
	var xp_reward: int = int(power * 0.75)

	_add_gold(gold_reward)
	_add_hero_xp(xp_reward)

func _add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


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
	_sync_hero_card_level(true)
	hero_level_up.emit(hero_level)


func _sync_hero_card_level(full_heal: bool) -> void:
	var hero: Dictionary = cards.get("th", {})
	if hero.is_empty():
		return

	hero["level"] = hero_level
	if full_heal:
		hero["current_hp"] = int(hero.get("max_hp", hero.get("current_hp", 0)))


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
		"hero_level": hero_level,
		"hero_xp": hero_xp,
		"xp_to_next_level": xp_to_next_level,
		"cards": cards,
		"enemy_draw_order": enemy_draw_order,
		"active_hero_traits": hero_trait_ids,
		"active_enemy_traits": enemy_trait_ids,
		"active_enemy_id": active_enemy_id
	}

	SaveSystem._ensure_save_dir()
	var file := FileAccess.open("user://save/save_run.json", FileAccess.WRITE)
	if file == null:
		push_error("[RunManager] No se pudo abrir save_run.json. user_dir=%s" % OS.get_user_data_dir())
		return
	file.store_string(JSON.stringify(data, "\t"))
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
	hero_level = int(data.get("hero_level", 1))
	hero_xp = int(data.get("hero_xp", 0))
	xp_to_next_level = int(data.get("xp_to_next_level", 4))
	cards = data.get("cards", {})
	_sync_hero_card_level(false)

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
	if active_enemy_id != "" and not cards.has(active_enemy_id):
		active_enemy_id = ""

	run_loaded = true
	_emit_run_state_signals()

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
	hero_xp_changed.emit(hero_xp, xp_to_next_level)


func _build_cards_from_run_deck() -> void:
	var run_deck := SaveSystem.load_run_deck()
	if run_deck.is_empty():
		return

	for entry in run_deck:
		var run_id := String(entry.get("run_id", ""))
		var def_id := String(entry.get("definition_id", ""))
		var collection_id := String(entry.get("collection_id", ""))
		if run_id == "" or def_id == "":
			continue
		var def: CardDefinition = CardDatabase.get_definition(def_id)
		var is_tutorial := false
		if def != null:
			is_tutorial = def.is_tutorial
		create_card_instance(run_id, def_id, is_tutorial, collection_id)


func reset_run(new_mode: String = "normal") -> void:
	run_mode = new_mode
	is_temporary_run = false
	cards.clear()
	enemy_draw_queue.clear()
	active_hero_traits.clear()
	active_enemy_traits.clear()
	gold = 0
	danger_level = 0
	hero_level = 1
	hero_xp = 0
	xp_to_next_level = 4
	run_loaded = false
	active_enemy_id = ""


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
		print(" ", i, "â†’", enemy.get("id", "?"), "| def:", enemy.get("definition", "?"), "| collection:", enemy.get("collection_id", ""))

	# =========================
	# RECALCULAR RIESGO
	# =========================
	recalculate_danger_level()

	
# =========================
# APLICACIÃ“N DE TRAITS
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
