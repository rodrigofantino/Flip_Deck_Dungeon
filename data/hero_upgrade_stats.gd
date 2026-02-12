extends Node
class_name HeroUpgradeStats

# Single source of truth for hero upgrade stats and per-point effects.

enum UpgradeStat {
	MAX_HP,
	DAMAGE,
	ARMOUR,
	BLOCK_CHANCE,
	HP_REGEN,
	LIFE_STEAL,
	EVASION,
	INITIATIVE,
	HEALING_POWER,
	RESIST_STATUS,
	GOLD_GAIN,
	LOOT_CHANCE,
	RARITY_CHANCE
}

const _PERCENT_PER_POINT: float = 0.05
const _PERCENT_CAP: float = 0.50
const _DEFENSE_PERCENT_CAP: float = 0.35

static func get_stat_name(stat: int) -> String:
	match stat:
		UpgradeStat.MAX_HP:
			return "HERO_UPGRADE_STAT_MAX_HP_NAME"
		UpgradeStat.DAMAGE:
			return "HERO_UPGRADE_STAT_DAMAGE_NAME"
		UpgradeStat.ARMOUR:
			return "HERO_UPGRADE_STAT_ARMOUR_NAME"
		UpgradeStat.BLOCK_CHANCE:
			return "HERO_UPGRADE_STAT_BLOCK_CHANCE_NAME"
		UpgradeStat.HP_REGEN:
			return "HERO_UPGRADE_STAT_HP_REGEN_NAME"
		UpgradeStat.LIFE_STEAL:
			return "HERO_UPGRADE_STAT_LIFE_STEAL_NAME"
		UpgradeStat.EVASION:
			return "HERO_UPGRADE_STAT_EVASION_NAME"
		UpgradeStat.INITIATIVE:
			return "HERO_UPGRADE_STAT_INITIATIVE_NAME"
		UpgradeStat.HEALING_POWER:
			return "HERO_UPGRADE_STAT_HEALING_POWER_NAME"
		UpgradeStat.RESIST_STATUS:
			return "HERO_UPGRADE_STAT_RESIST_STATUS_NAME"
		UpgradeStat.GOLD_GAIN:
			return "HERO_UPGRADE_STAT_GOLD_GAIN_NAME"
		UpgradeStat.LOOT_CHANCE:
			return "HERO_UPGRADE_STAT_LOOT_CHANCE_NAME"
		UpgradeStat.RARITY_CHANCE:
			return "HERO_UPGRADE_STAT_RARITY_CHANCE_NAME"
		_:
			return "UNKNOWN"

static func get_stat_desc(stat: int) -> String:
	match stat:
		UpgradeStat.MAX_HP:
			return "HERO_UPGRADE_STAT_MAX_HP_DESC"
		UpgradeStat.DAMAGE:
			return "HERO_UPGRADE_STAT_DAMAGE_DESC"
		UpgradeStat.ARMOUR:
			return "HERO_UPGRADE_STAT_ARMOUR_DESC"
		UpgradeStat.BLOCK_CHANCE:
			return "HERO_UPGRADE_STAT_BLOCK_CHANCE_DESC"
		UpgradeStat.HP_REGEN:
			return "HERO_UPGRADE_STAT_HP_REGEN_DESC"
		UpgradeStat.LIFE_STEAL:
			return "HERO_UPGRADE_STAT_LIFE_STEAL_DESC"
		UpgradeStat.EVASION:
			return "HERO_UPGRADE_STAT_EVASION_DESC"
		UpgradeStat.INITIATIVE:
			return "HERO_UPGRADE_STAT_INITIATIVE_DESC"
		UpgradeStat.HEALING_POWER:
			return "HERO_UPGRADE_STAT_HEALING_POWER_DESC"
		UpgradeStat.RESIST_STATUS:
			return "HERO_UPGRADE_STAT_RESIST_STATUS_DESC"
		UpgradeStat.GOLD_GAIN:
			return "HERO_UPGRADE_STAT_GOLD_GAIN_DESC"
		UpgradeStat.LOOT_CHANCE:
			return "HERO_UPGRADE_STAT_LOOT_CHANCE_DESC"
		UpgradeStat.RARITY_CHANCE:
			return "HERO_UPGRADE_STAT_RARITY_CHANCE_DESC"
		_:
			return ""

static func is_percent_stat(stat: int) -> bool:
	if stat == UpgradeStat.BLOCK_CHANCE:
		return true
	if stat == UpgradeStat.LIFE_STEAL:
		return true
	if stat == UpgradeStat.EVASION:
		return true
	if stat == UpgradeStat.HEALING_POWER:
		return true
	if stat == UpgradeStat.RESIST_STATUS:
		return true
	if stat == UpgradeStat.GOLD_GAIN:
		return true
	if stat == UpgradeStat.LOOT_CHANCE:
		return true
	if stat == UpgradeStat.RARITY_CHANCE:
		return true
	return false

static func get_per_point_flat(stat: int) -> int:
	match stat:
		UpgradeStat.MAX_HP:
			return 2
		UpgradeStat.DAMAGE:
			return 1
		UpgradeStat.ARMOUR:
			return 1
		UpgradeStat.HP_REGEN:
			return 1
		UpgradeStat.INITIATIVE:
			return 1
		_:
			return 0

static func get_per_point_percent(stat: int) -> float:
	if is_percent_stat(stat):
		return _PERCENT_PER_POINT
	return 0.0

static func get_percent_cap(stat: int) -> float:
	if stat == UpgradeStat.BLOCK_CHANCE or stat == UpgradeStat.EVASION:
		return _DEFENSE_PERCENT_CAP
	if is_percent_stat(stat):
		return _PERCENT_CAP
	return -1.0

static func get_all_stats() -> Array[int]:
	var result: Array[int] = []
	result.append(UpgradeStat.MAX_HP)
	result.append(UpgradeStat.DAMAGE)
	result.append(UpgradeStat.ARMOUR)
	result.append(UpgradeStat.BLOCK_CHANCE)
	result.append(UpgradeStat.HP_REGEN)
	result.append(UpgradeStat.LIFE_STEAL)
	result.append(UpgradeStat.EVASION)
	result.append(UpgradeStat.INITIATIVE)
	result.append(UpgradeStat.HEALING_POWER)
	result.append(UpgradeStat.RESIST_STATUS)
	result.append(UpgradeStat.GOLD_GAIN)
	result.append(UpgradeStat.LOOT_CHANCE)
	result.append(UpgradeStat.RARITY_CHANCE)
	return result
