extends Node
class_name MotionTiltDriver

# =========================
# CONFIG
# =========================
@export var motion_strength: float = 1.0
@export var smooth: float = 8.0

# =========================
# REFERENCES
# =========================
@export var target_control: Control      # CardView
@export var foil_layer: Control          # FoilLayer (con ShaderMaterial)

# =========================
# ESTADO
# =========================
var _last_global_pos: Vector2
var _motion_input: Vector2 = Vector2.ZERO
var _material: ShaderMaterial


# =========================
# CICLO DE VIDA
# =========================
func _ready() -> void:
	if foil_layer == null or not (foil_layer.material is ShaderMaterial):
		push_warning("[MotionTiltDriver] FoilLayer sin ShaderMaterial")
		return

	if target_control == null:
		push_warning("[MotionTiltDriver] target_control no asignado")
		return

	_material = foil_layer.material as ShaderMaterial
	_last_global_pos = target_control.global_position


# =========================
# PROCESS
# =========================
func _process(delta: float) -> void:
	if _material == null:
		return

	var current_pos: Vector2 = target_control.global_position
	var velocity: Vector2 = (current_pos - _last_global_pos) / max(delta, 0.0001)
	_last_global_pos = current_pos

	# Convertimos velocidad en input visual
	var target_input: Vector2 = velocity * 0.01 * motion_strength
	target_input = target_input.clamp(Vector2(-1, -1), Vector2(1, 1))

	_motion_input = _motion_input.lerp(target_input, delta * smooth)

	_material.set_shader_parameter("foil_dir", _motion_input)
