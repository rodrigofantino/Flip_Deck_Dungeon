extends Control
class_name TraitCard

# =========================
# SEÑALES
# =========================
signal trait_selected(trait_res: TraitResource)

# =========================
# ESTADO
# =========================
var trait_res: TraitResource
var selected: bool = false

@onready var hover_tilt: HoverTilt = $HoverTilt

@onready var name_label: Label = \
	$HoverTilt/PanelContainer/MarginContainer/VBoxContainer/NameLabel

@onready var description_label: Label = \
	$HoverTilt/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel

# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_set_children_mouse_ignore(self)

	print("[TraitCard] READY OK")

func _set_children_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_ignore(child)

# =========================
# API
# =========================
func setup(res: TraitResource) -> void:
	trait_res = res

	name_label.text = tr(res.display_name)
	description_label.text = tr(res.description)

func set_selected(value: bool) -> void:
	selected = value
	modulate = Color.WHITE if selected else Color(0.6, 0.6, 0.6, 1)

func reset_visual() -> void:
	selected = false
	modulate = Color.WHITE

# =========================
# HOVER TILT
# =========================
func _process(delta: float) -> void:
	if not hover_tilt:
		return
	if not hover_tilt.hovering:
		return

	var rect := get_rect()
	if rect.size == Vector2.ZERO:
		return

	var local_mouse := get_local_mouse_position()

	var nx := ((local_mouse.x / rect.size.x) - 0.5) * 2.0
	var ny := ((local_mouse.y / rect.size.y) - 0.5) * 2.0

	var input := Vector2(
		clamp(nx, -1.0, 1.0),
		clamp(ny, -1.0, 1.0)
	)

	hover_tilt.set_input(input)

func _on_mouse_entered() -> void:
	if hover_tilt:
		hover_tilt.set_active(true)

func _on_mouse_exited() -> void:
	if hover_tilt:
		hover_tilt.reset()

# =========================
# INPUT
# =========================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		trait_selected.emit(trait_res)
		print("[TraitCard] Clicked:", trait_res.trait_id)
