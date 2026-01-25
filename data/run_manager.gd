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
# SEÑALES DE PROGRESIÓN
# =========================

signal gold_changed(new_gold: int)
signal danger_level_changed(new_danger: int)

# =========================
# ESTADO ECONOMÍA / RIESGO
# =========================

var gold: int = 0
var danger_level: int = 0

# =========================
# TRAITS ACTIVOS
# =========================

var active_hero_traits: Array[TraitResource] = []
var active_enemy_traits: Array[TraitResource] = []

# =========================
# PROGRESIÓN DEL JUGADOR
# =========================

signal hero_xp_changed(current_xp: int, xp_to_next: int)
signal hero_level_up(new_level: int)

var hero_level: int = 1
var hero_xp: int = 0
var xp_to_next_level: int = 100

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

	# 🔑 APLICAR TRAITS ACTIVOS A ENEMIGOS YA EXISTENTES
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
	is_tutorial := false
) -> void:
	var def: CardDefinition = CardDatabase.get_definition(definition_key)
	if def == null:
		push_error("Definition no encontrada: " + definition_key)
		return

	var card := {
		"id": id,
		"definition": definition_key,
		"is_tutorial": is_tutorial,

		# BASE
		"base_hp": def.max_hp,
		"base_damage": def.damage,

		# RUNTIME
		"max_hp": def.max_hp,
		"current_hp": def.max_hp,
		"damage": def.damage,

		"level": def.level
	}

	cards[id] = card

	# 🔑 APLICAR TRAITS ACTIVOS
	if id == "th":
		recalc_card_stats(card, active_hero_traits)
	else:
		recalc_card_stats(card, active_enemy_traits)


	# =========================
	# 🧬 APLICAR TRAITS A ENEMIGOS NUEVOS
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

	var flat_hp := 0
	var flat_damage := 0
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
			hp_mult *= trait_res.enemy_hp_multiplier
			damage_mult *= trait_res.enemy_damage_multiplier
			card["level"] += trait_res.enemy_add_level

	var new_max_hp := int((base_hp + flat_hp) * hp_mult)
	var new_damage := int((base_damage + flat_damage) * damage_mult)

	card["max_hp"] = new_max_hp
	card["damage"] = new_damage
	card["current_hp"] = min(card["current_hp"], new_max_hp)


########################################
# DRAW REAL DE ENEMIGO
########################################
func draw_enemy_card() -> Dictionary:
	if enemy_draw_queue.is_empty():
		prepare_progressive_deck()

	if enemy_draw_queue.is_empty():
		return {}

	var enemy: Dictionary = enemy_draw_queue.pop_front()

	print(
		"[DRAW] TOP OF DECK →",
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
	return cards.get(id, null)

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
	hero_level_up.emit(hero_level)


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

	var data := {
		"run_mode": run_mode,
		"cards": cards
	}

	var file = FileAccess.open("user://save_run.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_run():
	if not FileAccess.file_exists("user://save_run.json"):
		return

	var file = FileAccess.open("user://save_run.json", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if data == null:
		push_error("Save corrupto")
		return

	run_mode = data.get("run_mode", "normal")
	cards = data.get("cards", {})


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
		print(" ", i, "→", enemy_draw_queue[i].get("id", "?"))

	# =========================
	# RECALCULAR RIESGO
	# =========================
	recalculate_danger_level()

	
# =========================
# APLICACIÓN DE TRAITS
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

	recalculate_danger_level()










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
