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
	current_phase = CombatPhase.START_COMBAT
	phase_changed.emit(current_phase)

	_resolve_initiative_turn()

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

	enemy_ids = _filter_alive_enemy_ids(enemy_ids)
	if enemy_ids.is_empty():
		_finish_combat(true)
		return

	_finish_combat(false)

func _build_turn_order(hero: Dictionary, enemies: Array[String]) -> Array[String]:
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

	var armour: int = int(card.get("armour", 0))
	var mitigated: int = max(amount - armour, 0)

	card.current_hp -= mitigated
	card.current_hp = max(card.current_hp, 0)

	damage_applied.emit(target_id, mitigated)

	var lifesteal: int = 0
	if attacker_id != "":
		var attacker: Dictionary = run_manager.get_card(attacker_id)
		if not attacker.is_empty():
			lifesteal = int(attacker.get("lifesteal", 0))
			if lifesteal > 0 and mitigated > 0:
				var max_hp: int = int(attacker.get("max_hp", 0))
				attacker["current_hp"] = min(int(attacker.get("current_hp", 0)) + lifesteal, max_hp)

	var thorns: int = int(card.get("thorns", 0))
	if thorns > 0 and attacker_id != "" and mitigated > 0:
		var attacker2: Dictionary = run_manager.get_card(attacker_id)
		if not attacker2.is_empty():
			attacker2["current_hp"] = max(int(attacker2.get("current_hp", 0)) - thorns, 0)
			damage_applied.emit(attacker_id, thorns)


func _handle_death(card_id: String) -> void:
	card_died.emit(card_id)

# ==========================================
# FIN DE COMBATE
# ==========================================
func _finish_combat(victory: bool) -> void:

	combat_finished.emit(victory)

	# RESET limpio para proximo combate
	await get_tree().process_frame
	current_phase = CombatPhase.IDLE
	phase_changed.emit(current_phase)
	ready_for_next_round.emit()
