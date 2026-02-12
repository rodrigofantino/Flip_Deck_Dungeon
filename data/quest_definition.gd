extends Resource
class_name QuestDefinition

@export var quest_id: String = ""
@export var display_name: String = ""

@export var base_waves: int = 0
@export var base_enemies_per_wave: int = 0
@export var decks_per_wave: int = 1
@export var base_completion_gold: int = 0
@export var enemy_level_boost: int = 0
@export var item_drop_chance_mult: float = 1.0

@export var miniboss_ids: Array[String] = []
@export var boss_id: String = ""

func get_waves(level: int) -> int:
	return base_waves

func get_enemies_per_wave(level: int) -> int:
	var clamped_level := clampi(level, 1, 6)
	var factor: float = pow(1.25, float(clamped_level - 1))
	return int(ceil(float(base_enemies_per_wave) * factor))

func get_completion_gold(level: int) -> int:
	var clamped_level := clampi(level, 1, 6)
	var factor: float = pow(1.5, float(clamped_level - 1))
	return int(round(float(base_completion_gold) * factor))

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if quest_id.strip_edges().is_empty():
		warnings.append("quest_id is empty.")
	if base_waves < 0:
		warnings.append("base_waves is negative.")
	if base_enemies_per_wave < 0:
		warnings.append("base_enemies_per_wave is negative.")
	if decks_per_wave < 1:
		warnings.append("decks_per_wave should be >= 1.")
	if base_completion_gold < 0:
		warnings.append("base_completion_gold is negative.")
	if enemy_level_boost < 0:
		warnings.append("enemy_level_boost is negative.")
	if item_drop_chance_mult < 0.0:
		warnings.append("item_drop_chance_mult is negative.")
	return warnings
