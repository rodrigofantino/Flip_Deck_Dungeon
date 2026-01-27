extends Node
class_name CombatManager
# Orquestador lógico del combate.
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
var enemy_id: String = ""
@export var initiative_debug: bool = false

# ==========================================
# SEÑALES
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
	# hero_init: iniciativa del héroe
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
# API PÚBLICA
# ==========================================


func start_combat(enemy_card_id: String) -> void:
	if run_manager == null:
		push_error("[CombatManager] RunManager no asignado")
		return

	enemy_id = enemy_card_id
	current_phase = CombatPhase.START_COMBAT
	phase_changed.emit(current_phase)

	_resolve_initiative_turn()

# ==========================================
# TURNOS
# ==========================================
func _resolve_initiative_turn() -> void:
	var hero: Dictionary = run_manager.get_card(hero_id)
	var enemy: Dictionary = run_manager.get_card(enemy_id)

	if hero.is_empty() or enemy.is_empty():
		_finish_combat(true)
		return

	var hero_init: int = int(hero.get("initiative", 0))
	var enemy_init: int = int(enemy.get("initiative", 0))
	var p: float = calc_hero_first_chance(hero_init, enemy_init)
	var roll: float = randf()
	var hero_first: bool = roll < p

	if initiative_debug:
		var diff: int = hero_init - enemy_init
		print(
			"[Initiative] hero:",
			hero_init,
			"enemy:",
			enemy_init,
			"diff:",
			diff,
			"p:",
			p,
			"roll:",
			roll,
			"hero_first:",
			hero_first
		)

	if hero_first:
		_resolve_hero_turn()
	else:
		_resolve_enemy_first_turn()

func _resolve_hero_turn() -> void:
	current_phase = CombatPhase.HERO_TURN
	phase_changed.emit(current_phase)

	var hero: Dictionary = run_manager.get_card(hero_id)
	var enemy: Dictionary = run_manager.get_card(enemy_id)

	if hero.is_empty() or enemy.is_empty():
		_finish_combat(true)
		return

	attack_started.emit(hero_id, enemy_id)
	await attack_animation_finished

	_apply_damage(enemy_id, int(hero.damage))

	if int(enemy.current_hp) <= 0:
		_handle_death(enemy_id)
		_finish_combat(true)
		return

	_resolve_enemy_turn()


func _resolve_enemy_turn() -> void:
	current_phase = CombatPhase.ENEMY_TURN
	phase_changed.emit(current_phase)

	var hero: Dictionary = run_manager.get_card(hero_id)
	var enemy: Dictionary = run_manager.get_card(enemy_id)

	if hero.is_empty() or enemy.is_empty():
		_finish_combat(false)
		return

	attack_started.emit(enemy_id, hero_id)
	await attack_animation_finished

	_apply_damage(hero_id, int(enemy.damage))

	if int(hero.current_hp) <= 0:
		_handle_death(hero_id)
		_finish_combat(false)
		return

	# 🔑 NADIE MURIÓ → FIN DE RONDA
	_finish_combat(false)

func _resolve_enemy_first_turn() -> void:
	current_phase = CombatPhase.ENEMY_TURN
	phase_changed.emit(current_phase)

	var hero: Dictionary = run_manager.get_card(hero_id)
	var enemy: Dictionary = run_manager.get_card(enemy_id)

	if hero.is_empty() or enemy.is_empty():
		_finish_combat(false)
		return

	attack_started.emit(enemy_id, hero_id)
	await attack_animation_finished

	_apply_damage(hero_id, int(enemy.damage))

	if int(hero.current_hp) <= 0:
		_handle_death(hero_id)
		_finish_combat(false)
		return

	current_phase = CombatPhase.HERO_TURN
	phase_changed.emit(current_phase)

	attack_started.emit(hero_id, enemy_id)
	await attack_animation_finished

	_apply_damage(enemy_id, int(hero.damage))

	if int(enemy.current_hp) <= 0:
		_handle_death(enemy_id)
		_finish_combat(true)
		return

	_finish_combat(false)



# ==========================================
# DAÑO Y MUERTE
# ==========================================
func _apply_damage(target_id: String, amount: int) -> void:
	var card: Dictionary = run_manager.get_card(target_id)
	if card.is_empty():
		return

	card.current_hp -= amount
	card.current_hp = max(card.current_hp, 0)

	damage_applied.emit(target_id, amount)


func _handle_death(card_id: String) -> void:
	card_died.emit(card_id)

# ==========================================
# FIN DE COMBATE
# ==========================================
func _finish_combat(victory: bool) -> void:

	combat_finished.emit(victory)

	# 🔑 RESET LIMPIO PARA PRÓXIMO COMBATE
	await get_tree().process_frame
	current_phase = CombatPhase.IDLE
	phase_changed.emit(current_phase)
	ready_for_next_round.emit()
