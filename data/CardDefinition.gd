extends Resource
class_name CardDefinition

@export var definition_id: String
# ID lógico: "hero", "slime", "wolf", etc

@export var display_name: String
# Nombre visible de la carta

@export var description: String
# Texto descriptivo (traducible)

@export var art: Texture2D
# Arte específico de la carta

@export var level: int = 1
# Nivel base de la carta

@export var power: int = 0
# Power (para escalados futuros)

@export var max_hp: int
# Vida máxima

@export var damage: int
# Daño base

@export_enum("hero", "enemy") var card_type: String
# Tipo de carta
