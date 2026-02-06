extends Control

# ==========================================
# SENIALES (la UI no decide nada, solo avisa)
# ==========================================

signal draw_pressed
signal combat_pressed
signal auto_draw_toggled(enabled: bool)
signal auto_combat_toggled(enabled: bool)
signal pause_pressed


# ==========================================
# NODOS DE LA ESCENA
# ==========================================

@onready var danger_label: Label = $TopBar/DangerLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var initiative_label: Label = $TopBar/InitiativeLabel
@onready var wave_label: Label = $TopBar/WaveLabel
@onready var wave_progress_label: Label = $TopBar/WaveProgressLabel
@onready var dust_label: Label = $TopBar/DustLabel

@onready var draw_button: Button = $Controls/VBoxButtons/HBoxDraw/DrawButton
@onready var combat_button: Button = $Controls/VBoxButtons/HboxCombat/CombatButton
@onready var auto_draw_check: CheckButton = $Controls/VBoxButtons/HBoxDraw/AutoDrawCheck
@onready var auto_combat_check: CheckButton = $Controls/VBoxButtons/HboxCombat/AutoCombatCheck
@onready var pause_button: Button = $PauseButton


# ==========================================
# ESTADO VISUAL (NO logica de juego)
# ==========================================

var danger_level: int = 0
var gold_amount: int = 0
var gold_display_value: int = 0
var gold_count_tween: Tween = null

var coin_drop_schedule: Array[float] = []
var coin_drop_elapsed: float = 0.0
var coin_drop_active: bool = false
var coin_drop_index: int = 0
var coin_drop_stream: AudioStream = null
var coin_drop_pool: Array[AudioStreamPlayer] = []
var coin_drop_active_players: Array[AudioStreamPlayer] = []
var coin_drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()

const GOLD_GAIN_DURATION: float = 2.5
const COIN_DROP_SFX_PATH: String = "res://audio/sfx/drop_coin.mp3"
const COIN_DROP_SFX_BUS: String = "SFX"
const COIN_DROP_MAX_TOTAL: int = 96
const COIN_DROP_MAX_CONCURRENT: int = 28
const COIN_DROP_CURVE_POWER: float = 0.45


# ==========================================
# CICLO DE VIDA
# ==========================================

func _ready() -> void:
	# Mantener el conteo/sfx de oro activo aunque la escena se pause (victoria/derrota).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	coin_drop_stream = load(COIN_DROP_SFX_PATH)
	coin_drop_rng.randomize()

	draw_button.text = tr("BATTLE_HUD_BUTTON_DRAW")
	combat_button.text = tr("BATTLE_HUD_BUTTON_COMBAT")
	auto_draw_check.text = tr("BATTLE_HUD_CHECK_AUTO_DRAW")
	auto_combat_check.text = tr("BATTLE_HUD_CHECK_AUTO_COMBAT")
	pause_button.text = tr("BATTLE_HUD_BUTTON_PAUSE")

	draw_button.pressed.connect(_on_draw_button_pressed)
	combat_button.pressed.connect(_on_combat_button_pressed)
	auto_draw_check.toggled.connect(_on_auto_draw_toggled)
	auto_combat_check.toggled.connect(_on_auto_combat_toggled)
	pause_button.pressed.connect(_on_pause_button_pressed)

	# Escuchar al RunManager
	RunState.gold_changed.connect(update_gold)
	RunState.danger_level_changed.connect(update_danger)
	RunState.dust_changed.connect(update_dust)
	RunState.wave_started.connect(update_wave)
	RunState.wave_progress_changed.connect(update_wave_progress)

	# Inicial
	gold_amount = RunState.gold
	gold_display_value = RunState.gold
	_update_gold_label(gold_display_value)
	update_danger(RunState.danger_level)
	update_dust(RunState.dust, 0)
	update_initiative_chance(0.0)
	update_wave(RunState.current_wave, RunState.waves_per_run)
	update_wave_progress(
		RunState.current_wave,
		RunState.enemies_defeated_in_wave,
		RunState.enemies_per_wave
	)

	set_draw_enabled(true)
	set_combat_enabled(false)


# ==========================================
# FUNCIONES PUBLICAS (BattleTable llama a estas)
# ==========================================

func update_danger(value: int) -> void:
	print("[HUD] Danger updated:", value)
	danger_level = value
	danger_label.text = "%s: %d" % [
		tr("BATTLE_HUD_LABEL_DANGER"),
		danger_level
	]


func update_gold(value: int) -> void:
	print("[HUD] Gold updated:", value)

	var delta: int = value - gold_amount
	gold_amount = value

	if delta <= 0:
		_stop_coin_drop_schedule()
		_set_gold_display(float(gold_amount))
		return

	_start_gold_gain_count(delta, GOLD_GAIN_DURATION)

func update_dust(value: int, _delta: int) -> void:
	if dust_label == null:
		return
	dust_label.text = "Dust: %d" % value


func _start_gold_gain_count(_delta: int, duration: float) -> void:
	if gold_label == null:
		return
	if gold_count_tween != null and gold_count_tween.is_running():
		gold_count_tween.kill()

	var from_value: int = gold_display_value
	var to_value: int = gold_amount

	gold_count_tween = create_tween()
	gold_count_tween.set_trans(Tween.TRANS_QUAD)
	gold_count_tween.set_ease(Tween.EASE_OUT)
	gold_count_tween.tween_method(
		Callable(self, "_set_gold_display"),
		float(from_value),
		float(to_value),
		duration
	)

	_start_coin_drop_schedule(to_value - from_value, duration)


func _set_gold_display(value: float) -> void:
	gold_display_value = int(round(value))
	_update_gold_label(gold_display_value)


func _update_gold_label(amount: int) -> void:
	if gold_label == null:
		return
	gold_label.text = "%s: %d" % [
		tr("BATTLE_HUD_LABEL_GOLD"),
		amount
	]


func _start_coin_drop_schedule(count: int, duration: float) -> void:
	_stop_coin_drop_schedule()
	if count <= 0:
		return

	coin_drop_schedule.clear()
	coin_drop_index = 0
	coin_drop_elapsed = 0.0
	coin_drop_schedule.append(0.0)
	if count >= 2:
		coin_drop_schedule.append(duration)

	var remaining: int = max(0, count - 2)
	if remaining > 0:
		var jitter: float = max(0.02, duration / float(count) * 0.35)
		var denom: int = max(1, count - 1)
		for i in range(1, count - 1):
			var t: float = pow(float(i) / float(denom), COIN_DROP_CURVE_POWER) * duration
			t += coin_drop_rng.randf_range(-jitter, jitter)
			t = clampf(t, 0.0, duration)
			coin_drop_schedule.append(t)
	coin_drop_schedule.sort()

	coin_drop_active = true
	set_process(true)


func _process(delta: float) -> void:
	if not coin_drop_active:
		return
	coin_drop_elapsed += delta
	while coin_drop_index < coin_drop_schedule.size() and coin_drop_elapsed >= coin_drop_schedule[coin_drop_index]:
		_play_coin_drop_one_shot()
		coin_drop_index += 1
	if coin_drop_index >= coin_drop_schedule.size():
		coin_drop_active = false
		set_process(false)


func _play_coin_drop_one_shot() -> void:
	if coin_drop_stream == null:
		return
	var player: AudioStreamPlayer = null

	if not coin_drop_pool.is_empty():
		player = coin_drop_pool.pop_back()
	elif coin_drop_active_players.size() < COIN_DROP_MAX_CONCURRENT and (coin_drop_active_players.size() + coin_drop_pool.size()) < COIN_DROP_MAX_TOTAL:
		player = AudioStreamPlayer.new()
		player.stream = coin_drop_stream
		player.bus = COIN_DROP_SFX_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.finished.connect(func() -> void:
			_on_coin_drop_finished(player)
		)
		add_child(player)

	if player == null:
		return

	coin_drop_active_players.append(player)
	player.play()


func _on_coin_drop_finished(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	coin_drop_active_players.erase(player)
	if coin_drop_pool.size() < COIN_DROP_MAX_TOTAL:
		coin_drop_pool.append(player)
	else:
		player.queue_free()


func _stop_coin_drop_schedule() -> void:
	coin_drop_schedule.clear()
	coin_drop_index = 0
	coin_drop_elapsed = 0.0
	coin_drop_active = false
	set_process(false)


func update_initiative_chance(prob: float) -> void:
	if initiative_label == null:
		return
	var percent: int = int(round(prob * 100.0))
	initiative_label.text = "Chance to attack first: %d%%" % percent

func update_wave(wave_index: int, waves_total: int) -> void:
	if wave_label == null:
		return
	wave_label.text = "Wave %d/%d" % [wave_index, waves_total]
	_update_wave_progress_label(
		wave_index,
		RunState.enemies_defeated_in_wave,
		RunState.enemies_per_wave
	)

func update_wave_progress(wave_index: int, defeated: int, total: int) -> void:
	_update_wave_progress_label(wave_index, defeated, total)

func _update_wave_progress_label(wave_index: int, defeated: int, total: int) -> void:
	if wave_progress_label == null:
		return
	if RunState.is_wave_boss(wave_index):
		wave_progress_label.text = "Boss Encounter"
	else:
		wave_progress_label.text = "Kills %d/%d" % [defeated, total]


func set_draw_enabled(enabled: bool) -> void:
	draw_button.disabled = not enabled


func set_combat_enabled(enabled: bool) -> void:
	combat_button.disabled = not enabled


func is_auto_draw_enabled() -> bool:
	return auto_draw_check.button_pressed


func is_auto_combat_enabled() -> bool:
	return auto_combat_check.button_pressed


# ==========================================
# MANEJO DE INPUT (solo emite seniales)
# ==========================================

func _on_draw_button_pressed() -> void:
	draw_pressed.emit()


func _on_combat_button_pressed() -> void:
	combat_pressed.emit()


func _on_auto_draw_toggled(enabled: bool) -> void:
	auto_draw_toggled.emit(enabled)


func _on_auto_combat_toggled(enabled: bool) -> void:
	auto_combat_toggled.emit(enabled)


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
