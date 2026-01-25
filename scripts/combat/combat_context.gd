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

	_resolve_hero_turn()

# ==========================================
# TURNOS
# ==========================================
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
