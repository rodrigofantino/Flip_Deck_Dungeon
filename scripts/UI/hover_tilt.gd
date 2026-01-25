extends Control
class_name HoverTilt

##########################
#RUTA EXACTA A DONDE HAGO LA CAPA DE SHADER PARA EL EFECTO FOILED general
##########################
@onready var foil_bg: Control = $FolioOverlay


# =========================
# CONFIG
# =========================
@export var max_tilt_deg := 8.0
@export var max_offset := 8.0
@export var smooth := 10.0

# =========================
# ESTADO
# =========================
var hovering := false
var target_rot := Vector2.ZERO
var target_pos := Vector2.ZERO

var foil_input: Vector2 = Vector2.ZERO
var foil_input_target: Vector2 = Vector2.ZERO
# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchors_preset = Control.PRESET_FULL_RECT
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	# =========================
	# MATERIAL ÚNICO POR CARTA
	# =========================
	if foil_bg != null and foil_bg.material != null:
		foil_bg.material = foil_bg.material.duplicate()
		

# mouse_entered.connect(_on_mouse_entered)
# mouse_exited.connect(_on_mouse_exited)

# =========================
# INPUT
# =========================
func _gui_input(event: InputEvent) -> void:
	pass

# =========================
# PROCESS
# =========================
func _process(delta: float) -> void:
	# Interpolación suave del input del shader
	foil_input = foil_input.lerp(foil_input_target, delta * smooth)

	_update_foil_shader(foil_input)

	rotation = lerp(rotation, deg_to_rad(target_rot.x), delta * smooth)
	position = position.lerp(target_pos, delta * smooth)

# =========================
# INTERNAL
# =========================
func _on_mouse_entered() -> void:
	hovering = true

func _on_mouse_exited() -> void:
	hovering = false
	target_rot = Vector2.ZERO
	target_pos = Vector2.ZERO

func _update_target(local_mouse: Vector2) -> void:
	var rect := get_rect()
	if rect.size == Vector2.ZERO:
		return

	var nx := ((local_mouse.x / rect.size.x) - 0.5) * 2.0
	var ny := ((local_mouse.y / rect.size.y) - 0.5) * 2.0

	nx = clamp(nx, -1.0, 1.0)
	ny = clamp(ny, -1.0, 1.0)

	# rotación 3D fake (4 esquinas reales)
	target_rot.x = -ny * max_tilt_deg
	target_rot.y = nx * max_tilt_deg

	# leve desplazamiento hacia el mouse
	target_pos = Vector2(nx, ny) * max_offset

# =========================
# API (CONTROL EXTERNO)
# =========================
func set_active(value: bool) -> void:
	hovering = value
	if not hovering:
		target_rot = Vector2.ZERO
		target_pos = Vector2.ZERO

func set_input(input: Vector2) -> void:
	if not hovering:
		return

	foil_input_target = input

	target_rot.x = -input.y * max_tilt_deg
	target_rot.y =  input.x * max_tilt_deg
	target_pos = input * max_offset

func _update_foil_shader(input: Vector2) -> void:
	if foil_bg == null:
		return

	var mat := foil_bg.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("foil_dir", input)

func reset() -> void:
	hovering = false
	foil_input_target = Vector2.ZERO
	target_rot = Vector2.ZERO
	target_pos = Vector2.ZERO
