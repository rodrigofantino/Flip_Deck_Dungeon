extends RefCounted
class_name ItemInstance

var instance_id: String = ""
var archetype: ItemArchetype = null
var item_level: int = 1
var rarity: int = 1
var mods: Array[ItemMod] = []
const ITEM_LEVEL_MULT: float = 1.1

func get_total_armour_flat() -> int:
	var total: int = 0
	if archetype != null:
		total += archetype.armour_flat
	for mod in mods:
		total += mod.armour_flat
	return _apply_level_multiplier(total)

func get_total_damage_flat() -> int:
	var total: int = 0
	if archetype != null:
		total += archetype.damage_flat
	for mod in mods:
		total += mod.damage_flat
	return _apply_level_multiplier(total)

func get_total_life_flat() -> int:
	var total: int = 0
	if archetype != null:
		total += archetype.life_flat
	for mod in mods:
		total += mod.life_flat
	return _apply_level_multiplier(total)

func get_total_initiative_flat() -> int:
	var total: int = 0
	if archetype != null:
		total += archetype.initiative_flat
	for mod in mods:
		total += mod.initiative_flat
	return _apply_level_multiplier(total)

func _apply_level_multiplier(value: int) -> int:
	if value == 0:
		return 0
	# Level 1 is the baseline (x1.0). Scaling starts at level 2.
	var level: int = int(max(0, item_level - 1))
	var mult: float = pow(ITEM_LEVEL_MULT, float(level))
	return int(round(float(value) * mult))

func to_dict() -> Dictionary:
	var mods_data: Array = []
	for mod in mods:
		mods_data.append(mod.to_dict())
	return {
		"id": instance_id,
		"archetype_id": archetype.item_id if archetype != null else "",
		"item_level": item_level,
		"rarity": rarity,
		"mods": mods_data
	}

static func from_dict(data: Dictionary, catalog: ItemArchetypeCatalog) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.instance_id = String(data.get("id", ""))
	var archetype_id := String(data.get("archetype_id", ""))
	if catalog != null and not archetype_id.is_empty():
		inst.archetype = catalog.get_by_id(archetype_id)
	inst.item_level = int(data.get("item_level", 1))
	inst.rarity = int(data.get("rarity", 1))
	var raw_mods: Variant = data.get("mods", [])
	if raw_mods is Array:
		for entry in raw_mods:
			if entry is Dictionary:
				inst.mods.append(ItemMod.from_dict(entry))
	return inst
