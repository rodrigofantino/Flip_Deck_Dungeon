extends Node

const PROFILE_PATH: String = "user://profile.tres"
const XP_BASE: int = 16
const XP_GROWTH: float = 1.35

var _cached_profile: PlayerProfile = null

func get_profile() -> PlayerProfile:
	if _cached_profile == null:
		_cached_profile = _load_or_create_profile()
	return _cached_profile

func save_profile(profile: PlayerProfile) -> void:
	if profile == null:
		return
	_normalize_profile(profile)
	_ensure_save_dir()
	var err: Error = ResourceSaver.save(profile, PROFILE_PATH)
	if err != OK:
		push_error("[ProfileService] Failed to save profile. Error=%s path=%s" % [str(err), PROFILE_PATH])

func load_profile() -> PlayerProfile:
	return get_profile()

func award_run_xp(hero_id: StringName, xp_earned: int) -> void:
	if hero_id == &"":
		return
	if xp_earned <= 0:
		return
	var profile: PlayerProfile = get_profile()
	if profile == null:
		return
	var progression: HeroProgression = profile.get_or_create_progression(hero_id)
	progression.xp += xp_earned
	while progression.xp >= xp_required_for_level(progression.level):
		progression.xp -= xp_required_for_level(progression.level)
		progression.level += 1
		progression.unspent_points += 1
	save_profile(profile)

func debug_grant_xp(hero_id: StringName, amount: int) -> void:
	award_run_xp(hero_id, amount)

func xp_required_for_level(level: int) -> int:
	var clamped_level: int = max(1, level)
	var required: float = float(XP_BASE) * pow(XP_GROWTH, float(clamped_level - 1))
	var rounded: int = int(round(required))
	return max(1, rounded)

func get_hero_upgrade_modifiers(hero_id: StringName) -> Dictionary:
	var flat_int_mods: Dictionary = {}
	var percent_float_mods: Dictionary = {}

	if hero_id == &"":
		return {
			"flat_int_mods": flat_int_mods,
			"percent_float_mods": percent_float_mods
		}

	var profile: PlayerProfile = get_profile()
	if profile == null:
		return {
			"flat_int_mods": flat_int_mods,
			"percent_float_mods": percent_float_mods
		}

	var progression: HeroProgression = profile.get_or_create_progression(hero_id)
	for stat: int in HeroUpgradeStats.get_all_stats():
		var points: int = progression.get_points_in_stat(stat)
		if HeroUpgradeStats.is_percent_stat(stat):
			var bonus: float = float(points) * HeroUpgradeStats.get_per_point_percent(stat)
			var cap: float = HeroUpgradeStats.get_percent_cap(stat)
			if cap >= 0.0:
				bonus = min(bonus, cap)
			percent_float_mods[stat] = bonus
		else:
			var flat: int = points * HeroUpgradeStats.get_per_point_flat(stat)
			flat_int_mods[stat] = flat

	# Example usage:
	# final_hp = base_hp + flat_int_mods[HeroUpgradeStats.UpgradeStat.MAX_HP]
	# final_evasion = min(base_evasion + percent_float_mods[HeroUpgradeStats.UpgradeStat.EVASION], 0.70)

	return {
		"flat_int_mods": flat_int_mods,
		"percent_float_mods": percent_float_mods
	}

func _load_or_create_profile() -> PlayerProfile:
	if ResourceLoader.exists(PROFILE_PATH):
		var loaded: Resource = ResourceLoader.load(PROFILE_PATH)
		if loaded is PlayerProfile:
			var existing: PlayerProfile = loaded
			_normalize_profile(existing)
			return existing

	var profile: PlayerProfile = PlayerProfile.new()
	profile.owned_heroes = _get_default_owned_heroes()
	_normalize_profile(profile)
	save_profile(profile)
	return profile

func _get_default_owned_heroes() -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	if CardDatabase.definitions.is_empty():
		CardDatabase.load_definitions()
	for def: Variant in CardDatabase.definitions.values():
		if def is CardDefinition:
			var card_def: CardDefinition = def
			if card_def.card_type == "hero" and not card_def.definition_id.is_empty():
				var key: StringName = StringName(card_def.definition_id)
				if not seen.has(key):
					seen[key] = true
					result.append(key)
	if result.is_empty():
		result.append(&"knight_aprentice")
	return result

func _normalize_profile(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var normalized: Array[StringName] = []
	var seen: Dictionary = {}
	for hero_id: StringName in profile.owned_heroes:
		var id_str: String = String(hero_id)
		if id_str == "hero":
			id_str = "knight_aprentice"
		var key: StringName = StringName(id_str)
		if key == &"":
			continue
		if seen.has(key):
			continue
		seen[key] = true
		normalized.append(key)
	profile.owned_heroes = normalized

func _ensure_save_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("[ProfileService] No se pudo abrir user://. user_dir=%s" % OS.get_user_data_dir())
		return
	var err: Error = dir.make_dir_recursive("save")
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("[ProfileService] No se pudo crear user://save. Error=%s user_dir=%s" % [str(err), OS.get_user_data_dir()])
