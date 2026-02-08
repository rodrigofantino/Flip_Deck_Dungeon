extends Resource
class_name HeroProgression

@export var hero_id: StringName = &""
@export var xp: int = 0
@export var level: int = 1
@export var unspent_points: int = 0
@export var stat_points: Dictionary = {}

func get_points_in_stat(stat: int) -> int:
	return int(stat_points.get(stat, 0))

func can_spend_point() -> bool:
	return unspent_points > 0

func can_refund_point(stat: int) -> bool:
	return get_points_in_stat(stat) > 0

func spend_point(stat: int) -> bool:
	if unspent_points <= 0:
		return false
	unspent_points -= 1
	var current: int = int(stat_points.get(stat, 0))
	stat_points[stat] = current + 1
	return true

func refund_point(stat: int) -> bool:
	var current: int = int(stat_points.get(stat, 0))
	if current <= 0:
		return false
	stat_points[stat] = current - 1
	unspent_points += 1
	return true
