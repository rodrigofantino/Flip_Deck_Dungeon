extends Control

@export var hero_scene: PackedScene
@export var enemy_scene: PackedScene



@onready var hero_slot: Control = $Board/HeroSlot
@onready var enemy_area: HBoxContainer = $Board/EnemyArea


func _ready() -> void:
	_spawn_hero()

func _spawn_hero() -> void:
	var hero = hero_scene.instantiate()
	hero_slot.add_child(hero)
