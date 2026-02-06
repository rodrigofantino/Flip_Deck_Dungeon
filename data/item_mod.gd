extends RefCounted
class_name ItemMod

# Mod simple con stats flat soportadas por combate.

var mod_id: String = ""
var armour_flat: int = 0
var damage_flat: int = 0
var life_flat: int = 0
var initiative_flat: int = 0

func to_dict() -> Dictionary:
	return {
		"id": mod_id,
		"armour_flat": armour_flat,
		"damage_flat": damage_flat,
		"life_flat": life_flat,
		"initiative_flat": initiative_flat
	}

static func from_dict(data: Dictionary) -> ItemMod:
	var mod := ItemMod.new()
	mod.mod_id = String(data.get("id", ""))
	mod.armour_flat = int(data.get("armour_flat", 0))
	mod.damage_flat = int(data.get("damage_flat", 0))
	mod.life_flat = int(data.get("life_flat", 0))
	mod.initiative_flat = int(data.get("initiative_flat", 0))
	return mod
