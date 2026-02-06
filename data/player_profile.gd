extends Resource
class_name PlayerProfile

@export var owned_heroes: Array[StringName] = []
@export var hero_progressions: Array[HeroProgression] = []

func get_or_create_progression(hero_id: StringName) -> HeroProgression:
	for progression: HeroProgression in hero_progressions:
		if progression != null and progression.hero_id == hero_id:
			return progression
	var created: HeroProgression = HeroProgression.new()
	created.hero_id = hero_id
	created.level = 1
	created.xp = 0
	created.unspent_points = 0
	hero_progressions.append(created)
	if not owned_heroes.has(hero_id):
		owned_heroes.append(hero_id)
	return created
