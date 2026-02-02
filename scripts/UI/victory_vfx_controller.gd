extends Control
class_name VictoryVFXController

signal gold_flourish

const MAX_PARTICLES: int = 320
const AMBIENT_INTERVAL_MIN: float = 2.0
const AMBIENT_INTERVAL_MAX: float = 3.0

var safe_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)
var title_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)
var gold_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)

var dimmer: ColorRect = null
var rays: RaysLayer = null
var particle_layer: ParticleLayer = null
var shine_container: Control = null
var shine_band: ColorRect = null
var idle_timer: Timer = null
var confetti_timer: Timer = null
var gold_coin_timer: Timer = null
var gold_coin_time_left: float = 0.0
var active_tweens: Array[Tween] = []

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	size = get_viewport_rect().size

func configure(safe_rect_in: Rect2, title_rect_in: Rect2, gold_rect_in: Rect2) -> void:
	safe_rect = safe_rect_in
	title_rect = title_rect_in
	gold_rect = gold_rect_in
	if get_parent() is Control:
		size = (get_parent() as Control).size
	_build_layers()

func play_intro_timeline() -> void:
	if dimmer == null or particle_layer == null:
		return

	_play_dimmer_intro()
	_schedule_bursts_and_shine()
	_start_idle_loop_delayed()

func start_idle_loop() -> void:
	if idle_timer == null:
		idle_timer = Timer.new()
		idle_timer.one_shot = true
		add_child(idle_timer)
		idle_timer.timeout.connect(_on_idle_timeout)
	_schedule_next_idle()
	_start_confetti_rain()

func stop_and_cleanup() -> void:
	for tween in active_tweens:
		if tween != null and tween.is_running():
			tween.kill()
	active_tweens.clear()

	if idle_timer != null:
		idle_timer.stop()
		idle_timer.queue_free()
		idle_timer = null
	if confetti_timer != null:
		confetti_timer.stop()
		confetti_timer.queue_free()
		confetti_timer = null
	if gold_coin_timer != null:
		gold_coin_timer.stop()
		gold_coin_timer.queue_free()
		gold_coin_timer = null

	for child in get_children():
		child.queue_free()

func _build_layers() -> void:
	for child in get_children():
		child.queue_free()

	dimmer = ColorRect.new()
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.z_index = -100
	add_child(dimmer)

	rays = RaysLayer.new()
	rays.position = _get_center()
	rays.radius = max(size.x, size.y) * 0.6
	rays.modulate.a = 0.22
	rays.z_index = -50
	add_child(rays)

	particle_layer = ParticleLayer.new()
	particle_layer.z_index = 0
	particle_layer.setup(safe_rect, MAX_PARTICLES)
	add_child(particle_layer)

	_build_shine_layer()

func _build_shine_layer() -> void:
	shine_container = Control.new()
	shine_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine_container.clip_contents = true
	shine_container.position = title_rect.position
	shine_container.size = title_rect.size
	shine_container.z_index = 5
	add_child(shine_container)

	shine_band = ColorRect.new()
	shine_band.color = Color(1.0, 1.0, 1.0, 0.0)
	shine_band.size = Vector2(title_rect.size.x * 0.6, title_rect.size.y * 2.0)
	shine_band.pivot_offset = shine_band.size * 0.5
	shine_band.rotation = -0.45
	shine_band.position = Vector2(-shine_band.size.x, -title_rect.size.y * 0.5)
	shine_container.add_child(shine_band)

func _play_shine() -> void:
	if shine_band == null or shine_container == null:
		return
	shine_band.modulate.a = 0.0
	shine_band.position = Vector2(-shine_band.size.x, -title_rect.size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(shine_band, "modulate:a", 0.35, 0.08)
	tween.tween_property(
		shine_band,
		"position",
		Vector2(title_rect.size.x + shine_band.size.x, -title_rect.size.y * 0.5),
		0.35
	)
	tween.tween_property(shine_band, "modulate:a", 0.0, 0.10)
	active_tweens.append(tween)

func _play_dimmer_intro() -> void:
	var tween := create_tween()
	tween.tween_property(dimmer, "color:a", 0.55, 0.25)
	active_tweens.append(tween)

	var breathe := create_tween().set_loops()
	breathe.tween_property(dimmer, "color:a", 0.48, 1.6)
	breathe.tween_property(dimmer, "color:a", 0.55, 1.6)
	active_tweens.append(breathe)

func _schedule_bursts_and_shine() -> void:
	var t := create_tween()
	t.tween_callback(Callable(self, "_burst_big")).set_delay(0.25)
	t.tween_callback(Callable(self, "_burst_corners")).set_delay(0.45)
	t.tween_callback(Callable(self, "_emit_gold_flourish")).set_delay(0.30)
	t.tween_callback(Callable(self, "_play_shine")).set_delay(0.60)
	t.tween_callback(Callable(self, "_burst_mini")).set_delay(0.75)
	active_tweens.append(t)

func _start_idle_loop_delayed() -> void:
	var t := create_tween()
	t.tween_callback(Callable(self, "start_idle_loop")).set_delay(0.95)
	active_tweens.append(t)

func _emit_gold_flourish() -> void:
	gold_flourish.emit()
	_start_gold_coin_stream(5.0)

func play_gold_stream(duration: float) -> void:
	_start_gold_coin_stream(duration)

func _burst_big() -> void:
	if particle_layer == null:
		return
	var region := Rect2(Vector2(0, 0), Vector2(size.x, size.y * 0.15))
	particle_layer.spawn_burst(region, 60, 180.0, 320.0, 2.2, 3.2)

func _burst_corners() -> void:
	if particle_layer == null:
		return
	var padding := 30.0
	var tl := Vector2(safe_rect.position.x - padding, safe_rect.position.y - padding)
	var tr := Vector2(safe_rect.position.x + safe_rect.size.x + padding, safe_rect.position.y - padding)
	var bl := Vector2(safe_rect.position.x - padding, safe_rect.position.y + safe_rect.size.y + padding)
	var br := Vector2(safe_rect.position.x + safe_rect.size.x + padding, safe_rect.position.y + safe_rect.size.y + padding)
	particle_layer.spawn_burst_at(tl, 16, 160.0, 260.0, 2.0, 2.8)
	particle_layer.spawn_burst_at(tr, 16, 160.0, 260.0, 2.0, 2.8)
	particle_layer.spawn_burst_at(bl, 16, 160.0, 260.0, 2.0, 2.8)
	particle_layer.spawn_burst_at(br, 16, 160.0, 260.0, 2.0, 2.8)

func _burst_mini() -> void:
	if particle_layer == null:
		return
	var region := Rect2(Vector2(0, size.y * 0.1), Vector2(size.x, size.y * 0.2))
	particle_layer.spawn_burst(region, 24, 140.0, 220.0, 1.8, 2.4)

func _on_idle_timeout() -> void:
	if particle_layer == null:
		return
	var region := Rect2(Vector2(0, 0), size)
	particle_layer.spawn_burst(region, 12, 60.0, 120.0, 4.0, 6.0, true)
	_schedule_next_idle()

func _schedule_next_idle() -> void:
	if idle_timer == null:
		return
	idle_timer.wait_time = rng.randf_range(AMBIENT_INTERVAL_MIN, AMBIENT_INTERVAL_MAX)
	idle_timer.start()

func _start_confetti_rain() -> void:
	if confetti_timer == null:
		confetti_timer = Timer.new()
		confetti_timer.one_shot = true
		add_child(confetti_timer)
		confetti_timer.timeout.connect(_on_confetti_rain_tick)
	_schedule_next_confetti_tick()

func _schedule_next_confetti_tick() -> void:
	if confetti_timer == null:
		return
	confetti_timer.wait_time = rng.randf_range(0.35, 0.55)
	confetti_timer.start()

func _on_confetti_rain_tick() -> void:
	if particle_layer == null:
		return
	var region := Rect2(Vector2(0, 0), size)
	particle_layer.spawn_confetti_rain(region, 28, 40.0, 110.0, 8.0, 12.0)
	_schedule_next_confetti_tick()

func _start_gold_coin_stream(duration: float) -> void:
	gold_coin_time_left = max(0.0, duration)
	if gold_coin_timer == null:
		gold_coin_timer = Timer.new()
		gold_coin_timer.one_shot = true
		add_child(gold_coin_timer)
		gold_coin_timer.timeout.connect(_on_gold_coin_tick)
	_schedule_next_gold_coin_tick()

func _schedule_next_gold_coin_tick() -> void:
	if gold_coin_timer == null or gold_coin_time_left <= 0.0:
		return
	gold_coin_timer.wait_time = 0.12
	gold_coin_timer.start()

func _on_gold_coin_tick() -> void:
	if particle_layer == null:
		return
	if gold_coin_time_left <= 0.0:
		return
	gold_coin_time_left -= 0.12
	var origin: Rect2 = gold_rect
	if origin.size == Vector2.ZERO:
		origin = Rect2(Vector2(size.x * 0.5, size.y * 0.5), Vector2(1, 1))
	particle_layer.spawn_coin_burst(origin, 6, 60.0, 140.0, 1.6, 2.4)
	_schedule_next_gold_coin_tick()

func _get_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5)


class ParticleData:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var rotation_speed: float
	var size: Vector2
	var color: Color
	var border_color: Color
	var life: float
	var max_life: float
	var drag: float
	var kind: int


class ParticleLayer:
	extends Node2D

	const KIND_CONFETTI: int = 0
	const KIND_LEAF: int = 1
	const KIND_CARD: int = 2
	const KIND_MOTE: int = 3
	const KIND_COIN: int = 4

	var safe_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)
	var max_particles: int = 120
	var particles: Array[ParticleData] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func setup(safe_rect_in: Rect2, max_particles_in: int) -> void:
		safe_rect = safe_rect_in
		max_particles = max_particles_in
		rng.randomize()
		set_process(false)

	func spawn_burst(
		region: Rect2,
		count: int,
		speed_min: float,
		speed_max: float,
		life_min: float,
		life_max: float,
		ambient: bool = false
	) -> void:
		for i in range(count):
			if particles.size() >= max_particles:
				break
			var pos := _random_point_outside_safe(region)
			var angle := rng.randf_range(-PI * 0.75, -PI * 0.25)
			if ambient:
				angle = rng.randf_range(-PI * 0.6, -PI * 0.4)
			var speed := rng.randf_range(speed_min, speed_max)
			var vel := Vector2(cos(angle), sin(angle)) * speed
			particles.append(_build_particle(pos, vel, life_min, life_max, ambient, -1))

		set_process(true)
		queue_redraw()

	func spawn_burst_at(
		origin: Vector2,
		count: int,
		speed_min: float,
		speed_max: float,
		life_min: float,
		life_max: float
	) -> void:
		for i in range(count):
			if particles.size() >= max_particles:
				break
			var angle := rng.randf_range(0.0, TAU)
			var speed := rng.randf_range(speed_min, speed_max)
			var vel := Vector2(cos(angle), sin(angle)) * speed
			var pos := _nudge_outside_safe(origin)
			particles.append(_build_particle(pos, vel, life_min, life_max, false, -1))

		set_process(true)
		queue_redraw()

	func spawn_confetti_rain(
		region: Rect2,
		count: int,
		speed_min: float,
		speed_max: float,
		life_min: float,
		life_max: float
	) -> void:
		for i in range(count):
			if particles.size() >= max_particles:
				break
			var pos := _random_point_outside_safe(region)
			var angle := rng.randf_range(-PI * 0.55, -PI * 0.45)
			var speed := rng.randf_range(speed_min, speed_max)
			var vel := Vector2(cos(angle), sin(angle)) * speed
			particles.append(_build_particle(pos, vel, life_min, life_max, false, KIND_CONFETTI))

		set_process(true)
		queue_redraw()

	func spawn_coin_burst(
		origin_rect: Rect2,
		count: int,
		speed_min: float,
		speed_max: float,
		life_min: float,
		life_max: float
	) -> void:
		for i in range(count):
			if particles.size() >= max_particles:
				break
			var pos := origin_rect.position + Vector2(
				rng.randf_range(0.0, max(1.0, origin_rect.size.x)),
				rng.randf_range(0.0, max(1.0, origin_rect.size.y))
			)
			pos = _nudge_outside_safe(pos)
			var angle := rng.randf_range(-PI * 0.85, -PI * 0.15)
			var speed := rng.randf_range(speed_min, speed_max)
			var vel := Vector2(cos(angle), sin(angle)) * speed
			particles.append(_build_particle(pos, vel, life_min, life_max, false, KIND_COIN))

		set_process(true)
		queue_redraw()

	func _build_particle(
		pos: Vector2,
		vel: Vector2,
		life_min: float,
		life_max: float,
		ambient: bool,
		forced_kind: int
	) -> ParticleData:
		var p := ParticleData.new()
		p.position = pos
		p.velocity = vel
		p.rotation = rng.randf_range(0.0, TAU)
		p.rotation_speed = rng.randf_range(-3.0, 3.0)
		p.life = rng.randf_range(life_min, life_max)
		p.max_life = p.life
		p.drag = rng.randf_range(0.02, 0.05)

		if forced_kind >= 0:
			p.kind = forced_kind
		else:
			var roll := rng.randf()
			if ambient:
				p.kind = KIND_MOTE
			elif roll < 0.45:
				p.kind = KIND_CONFETTI
			elif roll < 0.70:
				p.kind = KIND_LEAF
			elif roll < 0.90:
				p.kind = KIND_CARD
			else:
				p.kind = KIND_MOTE

		match p.kind:
			KIND_CONFETTI:
				p.size = Vector2(rng.randf_range(6.0, 10.0), rng.randf_range(2.0, 4.0))
				p.color = _pick_color()
				p.border_color = p.color
			KIND_LEAF:
				p.size = Vector2(rng.randf_range(8.0, 14.0), rng.randf_range(4.0, 7.0))
				p.color = _pick_leaf_color()
				p.border_color = p.color
			KIND_CARD:
				p.size = Vector2(rng.randf_range(8.0, 12.0), rng.randf_range(12.0, 16.0))
				p.color = Color(0.95, 0.92, 0.84, 1.0)
				p.border_color = Color(0.2, 0.15, 0.1, 0.9)
			KIND_MOTE:
				p.size = Vector2.ONE * rng.randf_range(2.0, 4.0)
				p.color = Color(1.0, 0.95, 0.75, 0.8)
				p.border_color = p.color
			KIND_COIN:
				p.size = Vector2.ONE * rng.randf_range(4.0, 6.5)
				p.color = Color(1.0, 0.86, 0.25, 0.95)
				p.border_color = Color(0.75, 0.55, 0.12, 0.9)

		return p

	func _process(delta: float) -> void:
		if particles.is_empty():
			set_process(false)
			return

		for i in range(particles.size() - 1, -1, -1):
			var p: ParticleData = particles[i]
			p.life -= delta
			if p.life <= 0.0:
				particles.remove_at(i)
				continue

			var drag_factor := pow(1.0 - p.drag, delta * 60.0)
			p.velocity *= drag_factor
			p.position += p.velocity * delta
			p.rotation += p.rotation_speed * delta

		queue_redraw()

	func _draw() -> void:
		for p: ParticleData in particles:
			var alpha: float = clampf(p.life / p.max_life, 0.0, 1.0)
			if safe_rect.has_point(p.position):
				alpha = 0.0
			var color := Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
			draw_set_transform(p.position, p.rotation, Vector2.ONE)
			match p.kind:
				KIND_CONFETTI:
					draw_rect(Rect2(-p.size * 0.5, p.size), color, true)
				KIND_LEAF:
					var points := PackedVector2Array([
						Vector2(-p.size.x * 0.5, 0.0),
						Vector2(0.0, -p.size.y * 0.5),
						Vector2(p.size.x * 0.5, 0.0),
						Vector2(0.0, p.size.y * 0.5)
					])
					draw_polygon(points, PackedColorArray([color]))
				KIND_CARD:
					var rect := Rect2(-p.size * 0.5, p.size)
					draw_rect(rect, color, true)
					draw_rect(rect, p.border_color, false, 1.0)
				KIND_MOTE:
					draw_circle(Vector2.ZERO, p.size.x, color)
				KIND_COIN:
					draw_circle(Vector2.ZERO, p.size.x, color)
					draw_circle(Vector2.ZERO, p.size.x * 0.65, Color(1.0, 0.95, 0.6, color.a))
					draw_circle(Vector2.ZERO, p.size.x, p.border_color, false, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _random_point_outside_safe(region: Rect2) -> Vector2:
		var point := region.position + Vector2(
			rng.randf_range(0.0, region.size.x),
			rng.randf_range(0.0, region.size.y)
		)
		var tries := 0
		while safe_rect.has_point(point) and tries < 6:
			point = region.position + Vector2(
				rng.randf_range(0.0, region.size.x),
				rng.randf_range(0.0, region.size.y)
			)
			tries += 1
		return point

	func _nudge_outside_safe(point: Vector2) -> Vector2:
		if not safe_rect.has_point(point):
			return point
		var dir := (point - safe_rect.get_center()).normalized()
		return safe_rect.get_center() + dir * (safe_rect.size.length() * 0.6)

	func _pick_color() -> Color:
		var colors := [
			Color(0.96, 0.37, 0.39, 1.0),
			Color(0.98, 0.78, 0.26, 1.0),
			Color(0.36, 0.75, 0.55, 1.0),
			Color(0.30, 0.55, 0.90, 1.0),
			Color(0.90, 0.50, 0.90, 1.0)
		]
		return colors[rng.randi_range(0, colors.size() - 1)]

	func _pick_leaf_color() -> Color:
		var colors := [
			Color(0.32, 0.72, 0.36, 1.0),
			Color(0.24, 0.58, 0.32, 1.0),
			Color(0.70, 0.46, 0.18, 1.0)
		]
		return colors[rng.randi_range(0, colors.size() - 1)]


class RaysLayer:
	extends Node2D

	var rays: Array[RayData] = []
	var radius: float = 240.0
	var rotation_speed: float = 0.15
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func _ready() -> void:
		rng.randomize()
		_build_rays()
		set_process(true)

	func _process(delta: float) -> void:
		rotation += rotation_speed * delta
		queue_redraw()

	func _draw() -> void:
		for ray: RayData in rays:
			draw_set_transform(Vector2.ZERO, ray.angle, Vector2.ONE)
			var points := PackedVector2Array([
				Vector2(0.0, -ray.width * 0.5),
				Vector2(ray.length, 0.0),
				Vector2(0.0, ray.width * 0.5)
			])
			draw_polygon(points, PackedColorArray([ray.color]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _build_rays() -> void:
		rays.clear()
		var count := 14
		for i in range(count):
			var data := RayData.new()
			data.angle = (TAU / float(count)) * float(i)
			data.length = radius * rng.randf_range(0.7, 1.0)
			data.width = rng.randf_range(24.0, 46.0)
			data.color = Color(1.0, 0.95, 0.8, 0.096)
			rays.append(data)


class RayData:
	var angle: float
	var length: float
	var width: float
	var color: Color
