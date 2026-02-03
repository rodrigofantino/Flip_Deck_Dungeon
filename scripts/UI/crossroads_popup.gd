extends Control
class_name CrossroadsPopup

signal add_deck_pressed
signal withdraw_pressed
signal trait_pressed
signal popup_closed

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var decks_label: Label = $Panel/VBoxContainer/DecksLabel
@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var withdraw_label: Label = $Panel/VBoxContainer/WithdrawLabel
@onready var cost_label: Label = $Panel/VBoxContainer/CostLabel

@onready var add_deck_button: Button = $Panel/VBoxContainer/Buttons/AddDeckButton
@onready var withdraw_button: Button = $Panel/VBoxContainer/Buttons/WithdrawButton
@onready var trait_button: Button = $Panel/VBoxContainer/Buttons/TraitButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	title_label.text = tr("CROSSROADS_TITLE")
	add_deck_button.text = tr("CROSSROADS_OPTION_ADD_DECK")
	withdraw_button.text = tr("CROSSROADS_OPTION_WITHDRAW")
	trait_button.text = tr("CROSSROADS_OPTION_TRAIT")

	add_deck_button.pressed.connect(_on_add_deck_pressed)
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	trait_button.pressed.connect(_on_trait_pressed)

func show_popup(
	run_gold: int,
	active_decks: int,
	can_add_deck: bool,
	withdraw_amount: int,
	cost_amount: int
) -> void:
	_update_labels(run_gold, active_decks, withdraw_amount, cost_amount)
	add_deck_button.disabled = not can_add_deck
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true

func hide_popup(keep_paused: bool = false) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not keep_paused:
		get_tree().paused = false
	popup_closed.emit()

func update_state(
	run_gold: int,
	active_decks: int,
	can_add_deck: bool,
	withdraw_amount: int,
	cost_amount: int
) -> void:
	_update_labels(run_gold, active_decks, withdraw_amount, cost_amount)
	add_deck_button.disabled = not can_add_deck

func _update_labels(
	run_gold: int,
	active_decks: int,
	withdraw_amount: int,
	cost_amount: int
) -> void:
	decks_label.text = tr("CROSSROADS_ACTIVE_DECKS").format({
		"value": active_decks,
		"max": 3
	})
	gold_label.text = tr("CROSSROADS_RUN_GOLD").format({
		"value": run_gold
	})
	withdraw_label.text = tr("CROSSROADS_WITHDRAW_LABEL").format({
		"value": withdraw_amount
	})
	cost_label.text = tr("CROSSROADS_COST_LABEL").format({
		"value": cost_amount
	})

func _on_add_deck_pressed() -> void:
	add_deck_pressed.emit()

func _on_withdraw_pressed() -> void:
	withdraw_pressed.emit()

func _on_trait_pressed() -> void:
	trait_pressed.emit()
