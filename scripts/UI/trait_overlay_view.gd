extends Control
class_name TraitOverlayView

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_panel_style()

func show_for_traits(traits: Array[TraitResource], anchor_rect: Rect2) -> void:
	if traits.is_empty():
		hide_overlay()
		return
	_build_list(traits)
	_reposition(anchor_rect)
	show()

func hide_overlay() -> void:
	hide()
	_clear_list()

func _build_list(traits: Array[TraitResource]) -> void:
	_clear_list()
	var title := Label.new()
	title.text = tr("TRAIT_OVERLAY_TITLE")
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	vbox.add_child(title)

	for trait_res in traits:
		if trait_res == null:
			continue
		var name_label := Label.new()
		name_label.text = tr(trait_res.display_name)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = tr(trait_res.description)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		vbox.add_child(desc_label)

func _clear_list() -> void:
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()

func _reposition(anchor_rect: Rect2) -> void:
	var desired := get_combined_minimum_size()
	size = desired
	var viewport_rect := get_viewport().get_visible_rect()
	var pos := anchor_rect.position + Vector2(anchor_rect.size.x + 12.0, 0.0)
	if pos.x + size.x > viewport_rect.size.x:
		pos.x = anchor_rect.position.x - size.x - 12.0
	if pos.y + size.y > viewport_rect.size.y:
		pos.y = viewport_rect.size.y - size.y - 12.0
	if pos.y < 0.0:
		pos.y = 12.0
	global_position = pos

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	style.border_color = Color(0.6, 0.6, 0.7, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
