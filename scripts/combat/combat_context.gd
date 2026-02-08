extends Node
class_name CombatManager
# Orquestador logico del combate.
# NO maneja UI ni animaciones.

# ==========================================
# FASES DEL COMBATE
# ==========================================
enum CombatPhase {
	IDLE,
	START_COMBAT,
	HERO_TURN,
	ENEMY_TURN,
	END_TURN,
	END_COMBAT
}


var current_phase: CombatPhase = CombatPhase.IDLE

# ==========================================
# REFERENCIAS
# ==========================================
var run_manager: RunManager
var hero_id: String = "th"
var enemy_ids: Array[String] = []
var preferred_target_id: String = ""
@export var initiative_debug: bool = false

# ==========================================
# SENALES
# ==========================================
signal phase_changed(phase: CombatPhase)

signal attack_started(attacker_id: String, target_id: String)
signal damage_applied(target_id: String, amount: int)
signal card_died(card_id: String)
signal combat_finished(victory: bool)
signal attack_animation_finished
signal ready_for_next_round

# ==========================================
# BOSS TRAITS (IDS)
# ==========================================
const TRAIT_GORE_CHARGE := "gore_charge"
const TRAIT_RAGE_TUSK := "rage_tusk"
const TRAIT_SPORE_RENEWAL := "spore_renewal"
const TRAIT_PRETERNATURAL_INIT := "preternatural_initiative"

# Estado por combate / ronda
var _round_first_actor_id: String = ""
var _trait_state: Dictionary = {}

# ==========================================
# INITIATIVE (UTILS)
# ==========================================

static func calc_hero_first_chance(hero_init: int, enemy_init: int) -> float:
	# P(hero_first) = clamp(0.15, 0.85, 0.5 + (hero_init - enemy_init) * 0.05)
	# hero_init: iniciativa del heroe
	# enemy_init: iniciativa del enemigo
	var diff: int = hero_init - enemy_init
	var p: float = 0.5 + float(diff) * 0.05
	return clamp(p, 0.15, 0.85)

static func resolve_hero_first(hero_init: int, enemy_init: int, rng: RandomNumberGenerator) -> bool:
	var p: float = calc_hero_first_chance(hero_init, enemy_init)
	var roll: float = rng.randf()
	return roll < p

static func resolve_hero_first_global(hero_init: int, enemy_init: int) -> bool:
	var p: float = calc_hero_first_chance(hero_init, enemy_init)
	var roll: float = randf()
	return roll < p

func debug_simulate_initiative(hero_init: int, enemy_init: int, trials: int = 10000) -> void:
	if not OS.is_debug_build():
		return
	if trials <= 0:
		return
	var p: float = calc_hero_first_chance(hero_init, enemy_init)
	var wins: int = 0
	for i in range(trials):
		if resolve_hero_first_global(hero_init, enemy_init):
			wins += 1
	var observed: float = float(wins) / float(trials)
	print(
		"[InitiativeTest] hero:",
		hero_init,
		"enemy:",
		enemy_init,
		"expected:",
		p,
		"observed:",
		observed
	)
# ==========================================
# SETUP
# ==========================================
func setup(run: RunManager) -> void:
	run_manager = run

# ==========================================
# API PUBLICA
# ==========================================


func start_combat(enemy_card_ids: Array[String]) -> void:
	if run_manager == null:
		push_error("[CombatManager] RunManager no asignado")
		return

	enemy_ids = _filter_alive_enemy_ids(enemy_card_ids)
	if enemy_ids.is_empty():
		_finish_combat(true)
		return
	_trait_state.clear()
	_round_first_actor_id = ""
	current_phase = CombatPhase.START_COMBAT
	phase_changed.emit(current_phase)

	_resolve_initiative_turn()

func set_preferred_target(target_id: String) -> void:
	preferred_target_id = target_id

func clear_preferred_target() -> void:
	preferred_target_id = ""

# ==========================================
# TURNOS
# ==========================================
func _resolve_initiative_turn() -> void:
	var hero: Dictionary = run_manager.get_card(hero_id)
	if hero.is_empty():
		_finish_combat(true)
		return

	enemy_ids = _filter_alive_enemy_ids(enemy_ids)
	if enemy_ids.is_empty():
		_finish_combat(true)
		return

	var order := _build_turn_order(hero, enemy_ids)
	_resolve_turn_order(order)

func _resolve_turn_order(order: Array[String]) -> void:
	var hero: Dictionary = run_manager.get_card(hero_id)
	if hero.is_empty():
		_finish_combat(false)
		return
	if order.size() > 0:
		_round_first_actor_id = order[0]
	else:
		_round_first_actor_id = ""

	for attacker_id in order:
		if attacker_id == hero_id:
			current_phase = CombatPhase.HERO_TURN
			phase_changed.emit(current_phase)
			hero = run_manager.get_card(hero_id)
			if hero.is_empty():
				_finish_combat(false)
				return
			var target_id := _pick_hero_target(enemy_ids)
			if target_id == "":
				_finish_combat(true)
				return
			attack_started.emit(hero_id, target_id)
			await attack_animation_finished
			_apply_damage(hero_id, target_id, int(hero.damage))
			var target: Dictionary = run_manager.get_card(target_id)
			if not target.is_empty() and int(target.current_hp) <= 0:
				_handle_death(target_id)
			_handle_end_of_actor_turn(hero_id)
		else:
			var enemy: Dictionary = run_manager.get_card(attacker_id)
			if enemy.is_empty() or int(enemy.get("current_hp", 0)) <= 0:
				continue
			current_phase = CombatPhase.ENEMY_TURN
			phase_changed.emit(current_phase)
			attack_started.emit(attacker_id, hero_id)
			await attack_animation_finished
			_apply_damage(attacker_id, hero_id, int(enemy.damage))
			hero = run_manager.get_card(hero_id)
			if hero.is_empty() or int(hero.get("current_hp", 0)) <= 0:
				_handle_death(hero_id)
				_finish_combat(false)
				return
			_handle_end_of_actor_turn(attacker_id)

	enemy_ids = _filter_alive_enemy_ids(enemy_ids)
	if enemy_ids.is_empty():
		_finish_combat(true)
		return

	_finish_combat(false)

func _build_turn_order(hero: Dictionary, enemies: Array[String]) -> Array[String]:
	var priority: Array[String] = []
	var remaining: Array[String] = []
	for enemy_id in enemies:
		var enemy: Dictionary = run_manager.get_card(enemy_id)
		if enemy.is_empty():
			continue
		if _has_boss_trait(enemy, TRAIT_PRETERNATURAL_INIT):
			priority.append(enemy_id)
		else:
			remaining.append(enemy_id)

	_sort_enemies_by_initiative(priority)
	var base_order := _build_turn_order_core(hero, remaining)
	if priority.is_empty():
		return base_order
	var final_order: Array[String] = []
	final_order.append_array(priority)
	final_order.append_array(base_order)
	return final_order

func _build_turn_order_core(hero: Dictionary, enemies: Array[String]) -> Array[String]:
	var hero_init: int = int(hero.get("initiative", 0))
	var before: Array[String] = []
	var after: Array[String] = []
	for enemy_id in enemies:
		var enemy: Dictionary = run_manager.get_card(enemy_id)
		if enemy.is_empty():
			continue
		var enemy_init: int = int(enemy.get("initiative", 0))
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var hero_first := resolve_hero_first(hero_init, enemy_init, rng)
		if initiative_debug:
			var diff: int = hero_init - enemy_init
			print(
				"[Initiative] hero:",
				hero_init,
				"enemy:",
				enemy_init,
				"diff:",
				diff,
				"hero_first:",
				hero_first
			)
		if hero_first:
			after.append(enemy_id)
		else:
			before.append(enemy_id)
	_sort_enemies_by_initiative(before)
	_sort_enemies_by_initiative(after)
	var order: Array[String] = []
	order.append_array(before)
	order.append(hero_id)
	order.append_array(after)
	return order

func _sort_enemies_by_initiative(ids: Array[String]) -> void:
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ea: Dictionary = run_manager.get_card(a)
		var eb: Dictionary = run_manager.get_card(b)
		var ia: int = int(ea.get("initiative", 0))
		var ib: int = int(eb.get("initiative", 0))
		if ia == ib:
			return a < b
		return ia > ib
	)

func _pick_hero_target(enemies: Array[String]) -> String:
	if preferred_target_id != "":
		if not enemies.has(preferred_target_id):
			preferred_target_id = ""
		else:
			var preferred: Dictionary = run_manager.get_card(preferred_target_id)
			if not preferred.is_empty() and int(preferred.get("current_hp", 0)) > 0:
				return preferred_target_id
			preferred_target_id = ""
	for enemy_id in enemies:
		var enemy: Dictionary = run_manager.get_card(enemy_id)
		if enemy.is_empty():
			continue
		if int(enemy.get("current_hp", 0)) > 0:
			return enemy_id
	return ""

func _filter_alive_enemy_ids(ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in ids:
		var enemy: Dictionary = run_manager.get_card(enemy_id)
		if enemy.is_empty():
			continue
		if int(enemy.get("current_hp", 0)) <= 0:
			continue
		result.append(enemy_id)
	return result


# ==========================================
# DANO Y MUERTE
# ==========================================
func _apply_damage(attacker_id: String, target_id: String, amount: int) -> void:
	var card: Dictionary = run_manager.get_card(target_id)
	if card.is_empty():
		return

	var final_amount := _get_modified_attack_damage(attacker_id, amount)
	var evasion: float = float(card.get("evasion", 0.0))
	if evasion > 0.0 and _roll_chance(evasion):
		damage_applied.emit(target_id, 0)
		return
	var block_chance: float = float(card.get("block_chance", 0.0))
	if block_chance > 0.0 and bool(card.get("has_shield", false)) and _roll_chance(block_chance):
		damage_applied.emit(target_id, 0)
		return
	var armour: int = int(card.get("armour", 0))
	var mitigated: int = max(final_amount - armour, 0)

	card.current_hp -= mitigated
	card.current_hp = max(card.current_hp, 0)

	damage_applied.emit(target_id, mitigated)
	_handle_rage_tusk_trigger(target_id, card)

	if attacker_id != "":
		var attacker: Dictionary = run_manager.get_card(attacker_id)
		if not attacker.is_empty():
			var lifesteal_flat: int = int(attacker.get("lifesteal", 0))
			var lifesteal_pct: float = float(attacker.get("lifesteal_pct", 0.0))
			if mitigated > 0 and (lifesteal_flat > 0 or lifesteal_pct > 0.0):
				var heal_amount := lifesteal_flat + int(round(float(mitigated) * lifesteal_pct))
				heal_amount = _apply_healing_power(attacker, heal_amount)
				if heal_amount > 0:
					var max_hp: int = int(attacker.get("max_hp", 0))
					var new_hp: int = min(int(attacker.get("current_hp", 0)) + heal_amount, max_hp)
					if new_hp != int(attacker.get("current_hp", 0)):
						attacker["current_hp"] = new_hp
						damage_applied.emit(attacker_id, 0)

	var thorns: int = int(card.get("thorns", 0))
	if thorns > 0 and attacker_id != "" and mitigated > 0:
		var attacker2: Dictionary = run_manager.get_card(attacker_id)
		if not attacker2.is_empty():
			attacker2["current_hp"] = max(int(attacker2.get("current_hp", 0)) - thorns, 0)
			damage_applied.emit(attacker_id, thorns)

func _get_modified_attack_damage(attacker_id: String, base_amount: int) -> int:
	if attacker_id == "":
		return base_amount
	var attacker: Dictionary = run_manager.get_card(attacker_id)
	if attacker.is_empty():
		return base_amount
	var amount := base_amount
	if _has_boss_trait(attacker, TRAIT_GORE_CHARGE) and attacker_id == _round_first_actor_id:
		amount += 2
	return amount

func _handle_rage_tusk_trigger(target_id: String, card: Dictionary) -> void:
	if not _has_boss_trait(card, TRAIT_RAGE_TUSK):
		return
	var state := _get_trait_state(target_id)
	if state.get("rage_tusk_triggered", false):
		return
	var max_hp: int = int(card.get("max_hp", 0))
	if max_hp <= 0:
		return
	var current_hp: int = int(card.get("current_hp", 0))
	var hp_pct: float = float(current_hp) / float(max_hp)
	if hp_pct <= 0.60:
		card["damage"] = int(card.get("damage", 0)) + 1
		state["rage_tusk_triggered"] = true
		_trait_state[target_id] = state
		damage_applied.emit(target_id, 0)

func _handle_end_of_actor_turn(attacker_id: String) -> void:
	if attacker_id == "":
		return
	var attacker: Dictionary = run_manager.get_card(attacker_id)
	if attacker.is_empty():
		return
	if not _has_boss_trait(attacker, TRAIT_SPORE_RENEWAL):
		return
	var max_hp: int = int(attacker.get("max_hp", 0))
	if max_hp <= 0:
		return
	var current_hp: int = int(attacker.get("current_hp", 0))
	if current_hp <= 0:
		return
	var new_hp: int = min(current_hp + 1, max_hp)
	if new_hp != current_hp:
		attacker["current_hp"] = new_hp
		damage_applied.emit(attacker_id, 0)

func _has_boss_trait(card: Dictionary, trait_id: String) -> bool:
	if card.is_empty():
		return false
	var raw: Variant = card.get("boss_trait_ids", [])
	if raw is Array:
		for entry in raw:
			if String(entry) == trait_id:
				return true
	return false

func _get_trait_state(card_id: String) -> Dictionary:
	if not _trait_state.has(card_id):
		_trait_state[card_id] = {}
	return _trait_state[card_id]

func _roll_chance(chance: float) -> bool:
	if chance <= 0.0:
		return false
	return randf() < clampf(chance, 0.0, 1.0)

func _apply_healing_power(card: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var power: float = float(card.get("healing_power", 0.0))
	if power <= 0.0:
		return amount
	return int(round(float(amount) * (1.0 + power)))

func _apply_end_of_round_regen() -> void:
	var hero: Dictionary = run_manager.get_card(hero_id)
	if hero.is_empty():
		return
	if int(hero.get("current_hp", 0)) <= 0:
		return
	var regen: int = int(hero.get("regen", 0))
	if regen <= 0:
		return
	var heal := _apply_healing_power(hero, regen)
	if heal <= 0:
		return
	var max_hp: int = int(hero.get("max_hp", 0))
	var new_hp: int = min(int(hero.get("current_hp", 0)) + heal, max_hp)
	if new_hp != int(hero.get("current_hp", 0)):
		hero["current_hp"] = new_hp
		damage_applied.emit(hero_id, 0)


func _handle_death(card_id: String) -> void:
	card_died.emit(card_id)

# ==========================================
# FIN DE COMBATE
# ==========================================
func _finish_combat(victory: bool) -> void:
	_apply_end_of_round_regen()
	combat_finished.emit(victory)

	# RESET limpio para proximo combate
	await get_tree().process_frame
	current_phase = CombatPhase.IDLE
	phase_changed.emit(current_phase)
	ready_for_next_round.emit()
