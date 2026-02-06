extends Control
class_name CollectionSlot

@export var card_view_scene: PackedScene
@export var card_base_size: Vector2 = Vector2(620, 860)

@onready var background: ColorRect = $Background
@onready var card_container: Control = $CardContainer
@onready var selection_outline: Panel = $SelectionOutline
@onready var count_overlay: ColorRect = $CountOverlay
@onready var count_label: Label = $CountOverlay/CountLabel
@onready var run_controls: HBoxContainer = $RunControls
@onready var include_check: CheckBox = $RunControls/IncludeCheck
@onready var weight_spin: SpinBox = $RunControls/WeightSpin
@onready var item_overlay: ColorRect = $ItemTypeOverlay
@onready var item_overlay_label: Label = $ItemTypeOverlay/OverlayLabel

var card_view: CardView = null
var current_def_id: String = ""
var current_card_type: String = ""
var is_obtained: bool = false
var owned_count: int = 0
var show_count_on_hover: bool = false
var _base_modulate: Color = Color(1, 1, 1, 1)
var _overlay_enabled: bool = false
var _overlay_text: String = ""

signal slot_clicked(slot: CollectionSlot)
signal enemy_selected_toggled(slot: CollectionSlot, selected: bool)
signal enemy_weight_changed(slot: CollectionSlot, weight: int)

var _suppress_run_signals: bool = false

func set_occupied(definition: CardDefinition, obtained: bool = true, upgrade_level: int = 0) -> void:
	_clear_card()
	is_obtained = obtained
	background.color = Color(0.2, 0.2, 0.2, 0.85) if obtained else Color(0.1, 0.1, 0.1, 0.7)
	if card_view_scene == null or definition == null:
		return
	current_def_id = definition.definition_id
	current_card_type = definition.card_type

	card_view = card_view_scene.instantiate()
	card_container.add_child(card_view)
	card_view.custom_minimum_size = card_base_size
	card_view.size = card_base_size
	card_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_view.offset_left = 0.0
	card_view.offset_top = 0.0
	card_view.offset_right = card_base_size.x
	card_view.offset_bottom = card_base_size.y
	card_view.setup_from_definition(definition, upgrade_level)
	card_view.show_front()
	card_view.modulate = Color(1, 1, 1, 1) if obtained else Color(0.35, 0.35, 0.35, 0.65)
	_base_modulate = card_view.modulate
	_set_mouse_filter_recursive(card_view, Control.MOUSE_FILTER_IGNORE)
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_fit_card")
	resized.connect(_fit_card)

func set_empty() -> void:
	_clear_card()
	background.color = Color(0.15, 0.15, 0.15, 0.5)
	current_def_id = ""
	current_card_type = ""
	is_obtained = false
	owned_count = 0
	_hide_count_overlay()

func set_owned_count(count: int, enable_hover: bool) -> void:
	owned_count = max(0, count)
	show_count_on_hover = enable_hover

func _clear_card() -> void:
	if card_view != null:
		card_view.queue_free()
		card_view = null

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group("collection_slots")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if count_overlay:
		count_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if count_label:
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if selection_outline:
		var style := StyleBoxFlat.new()
		style.border_color = Color(0.2, 0.9, 0.2, 1.0)
		style.border_width_left = 6
		style.border_width_top = 6
		style.border_width_right = 6
		style.border_width_bottom = 6
		style.bg_color = Color(0, 0, 0, 0)
		selection_outline.add_theme_stylebox_override("panel", style)
		selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if run_controls:
		run_controls.mouse_filter = Control.MOUSE_FILTER_STOP
	if include_check:
		include_check.toggled.connect(_on_include_toggled)
	if weight_spin:
		weight_spin.value_changed.connect(_on_weight_changed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[CollectionSlot] Click:", name, "def:", current_def_id)
		slot_clicked.emit(self)

func set_selected(selected: bool) -> void:
	if selection_outline:
		selection_outline.visible = selected and is_obtained

func configure_run_controls(
	visible: bool,
	enabled: bool,
	selected: bool,
	weight: int
) -> void:
	if run_controls:
		run_controls.visible = visible
	if include_check:
		include_check.visible = visible
		include_check.disabled = not enabled
	if weight_spin:
		weight_spin.visible = visible
		weight_spin.editable = enabled and selected
	_suppress_run_signals = true
	if include_check:
		include_check.button_pressed = selected
	if weight_spin:
		weight_spin.value = clampi(weight, 1, 3)
	_suppress_run_signals = false

func _fit_card() -> void:
	if card_view == null:
		return
	var target_size: Vector2 = size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return
	var scale_w: float = target_size.x / card_base_size.x
	var scale_h: float = target_size.y / card_base_size.y
	var final_scale: float = min(scale_w, scale_h)
	card_view.scale = Vector2(final_scale, final_scale)
	card_view.position = (target_size * 0.5) - (card_base_size * final_scale * 0.5)

func _on_mouse_entered() -> void:
	if card_view == null:
		return
	if show_count_on_hover:
		_show_count_overlay()
		card_view.modulate = _base_modulate * Color(0.8, 0.8, 0.8, 1.0)
	if _overlay_enabled:
		_show_item_overlay()
	if _overlay_enabled:
		_show_item_overlay()

func _on_mouse_exited() -> void:
	if card_view == null:
		return
	if show_count_on_hover:
		_hide_count_overlay()
		card_view.modulate = _base_modulate
	_hide_item_overlay()

func _show_count_overlay() -> void:
	if count_overlay == null or count_label == null:
		return
	count_label.text = "%d" % owned_count
	count_overlay.visible = true

func _hide_count_overlay() -> void:
	if count_overlay == null:
		return
	count_overlay.visible = false

func configure_item_type_overlay(enabled: bool, text: String) -> void:
	_overlay_enabled = enabled
	_overlay_text = text
	if item_overlay_label:
		item_overlay_label.text = text
	if not enabled:
		_hide_item_overlay()

func _show_item_overlay() -> void:
	if item_overlay == null:
		return
	item_overlay.visible = true

func _hide_item_overlay() -> void:
	if item_overlay == null:
		return
	item_overlay.visible = false

func _on_include_toggled(pressed: bool) -> void:
	if _suppress_run_signals:
		return
	enemy_selected_toggled.emit(self, pressed)

func _on_weight_changed(value: float) -> void:
	if _suppress_run_signals:
		return
	enemy_weight_changed.emit(self, int(round(value)))
