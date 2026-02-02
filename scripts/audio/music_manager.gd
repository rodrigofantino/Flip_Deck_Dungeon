extends Node

@export var menu_music_dir: String = "res://audio/music/background"
@export var battle_music_dir: String = "res://audio/music/battle"
@export var fade_duration: float = 1.0
@export var menu_volume_db: float = -8.0
@export var battle_volume_db: float = -2.0

var _menu_player: AudioStreamPlayer
var _battle_player: AudioStreamPlayer
var _state: String = "menu"
var _menu_tracks: Array[AudioStream] = []
var _battle_tracks: Array[AudioStream] = []
var _menu_index: int = 0
var _battle_index: int = 0
var _fade_tween: Tween = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Mantener musica y crossfades activos incluso si el juego esta pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_player = AudioStreamPlayer.new()
	_battle_player = AudioStreamPlayer.new()
	add_child(_menu_player)
	add_child(_battle_player)
	_menu_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_battle_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_player.bus = _get_music_bus()
	_battle_player.bus = _get_music_bus()
	_menu_player.volume_db = menu_volume_db
	_battle_player.volume_db = -80.0
	_rng.randomize()
	_menu_tracks = _load_tracks(menu_music_dir)
	_battle_tracks = _load_tracks(battle_music_dir)
	_menu_index = _get_random_index_for(_menu_tracks)
	_battle_index = _get_random_index_for(_battle_tracks)
	_menu_player.finished.connect(func() -> void:
		if _state == "menu":
			_play_next_menu()
	)
	_battle_player.finished.connect(func() -> void:
		if _state == "battle":
			_play_next_battle()
	)
	_play_menu_immediate()

func play_menu() -> void:
	if _state == "menu":
		return
	_state = "menu"
	_play_menu_immediate()
	_crossfade(_battle_player, _menu_player, battle_volume_db, menu_volume_db)

func play_battle() -> void:
	if _state == "battle":
		return
	_state = "battle"
	_play_battle_immediate()
	_crossfade(_menu_player, _battle_player, menu_volume_db, battle_volume_db)

func _play_menu_immediate() -> void:
	if _menu_tracks.is_empty():
		return
	if _menu_player.stream == null or not _menu_player.playing:
		_menu_player.stream = _menu_tracks[_menu_index]
		_menu_player.play()
	_menu_player.volume_db = menu_volume_db

func _play_battle_immediate() -> void:
	if _battle_tracks.is_empty():
		return
	if _battle_player.stream == null or not _battle_player.playing:
		_battle_player.stream = _battle_tracks[_battle_index]
		_battle_player.play()
	_battle_player.volume_db = battle_volume_db
func _play_next_menu() -> void:
	if _menu_tracks.is_empty():
		return
	_menu_index = (_menu_index + 1) % _menu_tracks.size()
	_menu_player.stream = _menu_tracks[_menu_index]
	_menu_player.play()

func _play_next_battle() -> void:
	if _battle_tracks.is_empty():
		return
	_battle_index = (_battle_index + 1) % _battle_tracks.size()
	_battle_player.stream = _battle_tracks[_battle_index]
	_battle_player.play()

func _crossfade(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, _from_db: float, to_db: float) -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if from_player and from_player.playing:
		_fade_tween.tween_property(from_player, "volume_db", -80.0, fade_duration)
	if to_player:
		to_player.volume_db = -80.0
		if not to_player.playing:
			to_player.play()
		_fade_tween.parallel().tween_property(to_player, "volume_db", to_db, fade_duration)

func _get_music_bus() -> String:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i) == "Music":
			return "Music"
	return "Master"

func _load_tracks(dir_path: String) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	if dir_path == "":
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
				var stream := load(dir_path + "/" + file_name)
				if stream is AudioStream:
					result.append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()
	_shuffle_playlist(result)
	return result

func _shuffle_playlist(tracks: Array[AudioStream]) -> void:
	var count := tracks.size()
	for i in range(count - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := tracks[i]
		tracks[i] = tracks[j]
		tracks[j] = temp

func _get_random_index_for(tracks: Array) -> int:
	if tracks.is_empty():
		return 0
	return _rng.randi_range(0, tracks.size() - 1)
