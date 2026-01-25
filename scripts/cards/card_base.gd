extends Control
class_name CardBase

# ===== STATS =====
@export var card_name: String = "Card"
@export var hp: int = 0
@export var shield: int = 0
@export var initiative: int = 0
@export var attacks: int = 0
@export var description: String = "Card description"
@export var power: int = 0
@export var lvl: int = 1



# ===== REFERENCES =====
@onready var name_label = $Panel/VBoxContainer/Name
@onready var hp_label = $Panel/VBoxContainer/HP
@onready var shield_label = $Panel/VBoxContainer/Shield
@onready var initiative_label = $Panel/VBoxContainer/Initiative
@onready var attacks_label = $Panel/VBoxContainer/Attacks
@onready var description_label: Label = $Panel/VBoxContainer/Description
@onready var power_label: Label = $Panel/VBoxContainer/Power
# Called when the node enters the scene tree for the first time.


func _ready():
	#card_name = "Knight"
	#hp = 30
	#shield = 5
	#initiative = 4
	#attacks = 2
	#description="a card description"
	#power = 1
	update_card()

func update_card():
	name_label.text = card_name
	hp_label.text = "HP: %d" % hp
	shield_label.text = "Shield: %d" % shield
	initiative_label.text = "Initiative: %d" % initiative
	attacks_label.text = "Attacks: %d" % attacks
	description_label.text = description
	power_label.text = "Power: %d" % power	
