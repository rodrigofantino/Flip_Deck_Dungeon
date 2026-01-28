extends Resource
class_name TraitResource


@export var trait_id: String
# ID lógico único (ej: "holy_strength")

@export var display_name: String
# Nombre visible en UI

@export_multiline var description: String
# Texto descriptivo

enum TraitType {
	HERO,
	ENEMY
}

@export var trait_type: TraitType

# Define a quién afecta

# =========================
# HERO
# =========================
@export var hero_max_hp_bonus: int = 0
@export var hero_damage_bonus: int = 0
@export var hero_damage_multiplier: float = 1.0
@export var hero_hp_multiplier: float = 1.0

# =========================
# ENEMY
# =========================
@export var enemy_hp_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var enemy_add_level: int = 0
@export var enemy_add_initiative: int = 0
@export var enemy_add_flat_damage: int = 0
@export var enemy_add_flat_hp: int = 0
