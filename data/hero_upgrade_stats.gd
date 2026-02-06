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

const _PERCENT_PER_POINT: float = 0.10
const _PERCENT_CAP: float = 0.70

static func get_stat_name(stat: int) -> String:
	match stat:
		UpgradeStat.MAX_HP:
			return "Max HP"
		UpgradeStat.DAMAGE:
			return "Damage"
		UpgradeStat.ARMOUR:
			return "Armour"
		UpgradeStat.BLOCK_CHANCE:
			return "Block Chance"
		UpgradeStat.HP_REGEN:
			return "HP Regen"
		UpgradeStat.LIFE_STEAL:
			return "Life Steal"
		UpgradeStat.EVASION:
			return "Evasion"
		UpgradeStat.INITIATIVE:
			return "Initiative"
		UpgradeStat.HEALING_POWER:
			return "Healing Power"
		UpgradeStat.RESIST_STATUS:
			return "Status Resist"
		UpgradeStat.GOLD_GAIN:
			return "Gold Gain"
		UpgradeStat.LOOT_CHANCE:
			return "Loot Chance"
		UpgradeStat.RARITY_CHANCE:
			return "Rarity Chance"
		_:
			return "Unknown"

static func get_stat_desc(stat: int) -> String:
	match stat:
		UpgradeStat.MAX_HP:
			return "Adds flat max HP."
		UpgradeStat.DAMAGE:
			return "Adds flat damage."
		UpgradeStat.ARMOUR:
			return "Adds flat armour."
		UpgradeStat.BLOCK_CHANCE:
			return "Chance to block incoming attacks (no block amount stat)."
		UpgradeStat.HP_REGEN:
			return "Flat regen applied per combat round."
		UpgradeStat.LIFE_STEAL:
			return "Percent of damage returned as health."
		UpgradeStat.EVASION:
			return "Chance to evade incoming attacks."
		UpgradeStat.INITIATIVE:
			return "Adds flat initiative."
		UpgradeStat.HEALING_POWER:
			return "Increases healing done by percent."
		UpgradeStat.RESIST_STATUS:
			return "Chance to resist status effects."
		UpgradeStat.GOLD_GAIN:
			return "Percent bonus to gold earned."
		UpgradeStat.LOOT_CHANCE:
			return "Chance that an item drops at all."
		UpgradeStat.RARITY_CHANCE:
			return "Shifts item rarity upward when a drop happens."
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
