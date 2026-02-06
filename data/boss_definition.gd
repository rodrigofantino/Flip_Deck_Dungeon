extends Resource
class_name BossDefinition

enum BossKind {
	MINI_BOSS,
	FINAL_BOSS
}

@export var boss_id: String
# Logical id (ex: "forest_ogre")

@export var boss_name: String
# Display name for UI

@export var art: Texture2D
# Boss art (card illustration)

@export var frame_texture: Texture2D
# Card frame (use Forest frame for now)

@export var biome_id: String
# Biome identifier

@export var boss_kind: BossKind = BossKind.MINI_BOSS
# Classification: mini boss or final boss

@export var base_level: int = 1
# Base level for the boss

@export var base_max_hp: int = 0
# Base max HP (no scaling here)

@export var base_damage: int = 0
# Base damage (no scaling here)

@export var base_armour: int = 0
# Base armour (no scaling here)

@export var base_initiative: int = 0
# Base initiative (no scaling here)

@export var boss_traits: Array[TraitResource] = []
# Fixed list of traits (no pool, no random)

func is_mini_boss() -> bool:
	return boss_kind == BossKind.MINI_BOSS

func is_final_boss() -> bool:
	return boss_kind == BossKind.FINAL_BOSS

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if boss_id.strip_edges().is_empty():
		warnings.append("boss_id is empty.")

	if base_level < 0:
		warnings.append("base_level is negative.")
	if base_max_hp < 0:
		warnings.append("base_max_hp is negative.")
	if base_damage < 0:
		warnings.append("base_damage is negative.")
	if base_armour < 0:
		warnings.append("base_armour is negative.")
	if base_initiative < 0:
		warnings.append("base_initiative is negative.")

	return warnings
