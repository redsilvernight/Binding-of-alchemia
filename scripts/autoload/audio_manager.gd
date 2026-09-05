extends Node

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

const SFX_POOL_SIZE: int = 20
const SFX_2D_POOL_SIZE: int = 14

const SFX_2D_MAX_DISTANCE: float = 1600.0
const SFX_2D_ATTENUATION: float = 1.4

const MUSIC_FADE_DURATION: float = 1.2
const MUSIC_SILENT_OFFSET_DB: float = -40.0
const DUCK_ATTACK_DURATION: float = 0.08
const DUCK_RELEASE_DURATION: float = 0.9

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_cache: Dictionary = {}
var _last_played_at: Dictionary = {}

var _music_players: Array[AudioStreamPlayer] = []
var _music_gains_db: Array[float] = [0.0, 0.0]
var _active_music_index: int = 0
var _current_music_key: String = ""
var _music_fade_tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	for i in SFX_2D_POOL_SIZE:
		var player_2d := AudioStreamPlayer2D.new()
		player_2d.bus = "SFX"
		player_2d.max_distance = SFX_2D_MAX_DISTANCE
		player_2d.attenuation = SFX_2D_ATTENUATION
		add_child(player_2d)
		_sfx_2d_pool.append(player_2d)

	for i in 2:
		var music := AudioStreamPlayer.new()
		music.bus = "Music"
		music.volume_db = MUSIC_SILENT_OFFSET_DB
		add_child(music)
		_music_players.append(music)


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if not _consume_rate_limit(key):
		return
	var stream: AudioStream = _load_sfx(key)
	if stream == null:
		return
	var player: AudioStreamPlayer = _take_sfx_player()
	player.stream = stream
	player.bus = "UI" if AudioMix.is_ui(key) else "SFX"
	player.volume_db = AudioMix.gain_db(key) + volume_db
	player.pitch_scale = _pitch_for(key)
	player.play()
	_apply_duck_for(key)


func play_sfx_at(key: String, position: Vector2, volume_db: float = 0.0) -> void:
	if not _consume_rate_limit(key):
		return
	var stream: AudioStream = _load_sfx(key)
	if stream == null:
		return
	var player: AudioStreamPlayer2D = _take_sfx_2d_player()
	player.stream = stream
	player.global_position = position
	player.volume_db = AudioMix.gain_db(key) + volume_db
	player.pitch_scale = _pitch_for(key)
	player.play()
	_apply_duck_for(key)


func play_music(key: String) -> void:
	if _current_music_key == key and _active_player().playing:
		return
	var stream: AudioStream = _load_music(key)
	if stream == null:
		return
	_current_music_key = key

	var outgoing: AudioStreamPlayer = _active_player()
	var outgoing_silent_db: float = _silent_db_for(_active_music_index)
	_active_music_index = 1 - _active_music_index
	var incoming: AudioStreamPlayer = _active_player()

	var incoming_gain_db: float = AudioMix.music_gain_db(key)
	_music_gains_db[_active_music_index] = incoming_gain_db
	incoming.stream = stream
	incoming.volume_db = _silent_db_for(_active_music_index)
	incoming.play()

	_kill_duck_tween()
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.set_parallel(true)
	_music_fade_tween.tween_property(incoming, "volume_db", incoming_gain_db, MUSIC_FADE_DURATION)
	if outgoing.playing:
		_music_fade_tween.tween_property(outgoing, "volume_db", outgoing_silent_db, MUSIC_FADE_DURATION)
		_music_fade_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade_duration: float = MUSIC_FADE_DURATION) -> void:
	_current_music_key = ""
	var outgoing: AudioStreamPlayer = _active_player()
	if not outgoing.playing:
		return
	_kill_duck_tween()
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	var silent_db: float = _silent_db_for(_active_music_index)
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(outgoing, "volume_db", silent_db, fade_duration)
	_music_fade_tween.tween_callback(outgoing.stop)


func _active_player() -> AudioStreamPlayer:
	return _music_players[_active_music_index]


func _silent_db_for(index: int) -> float:
	return _music_gains_db[index] + MUSIC_SILENT_OFFSET_DB


func _apply_duck_for(key: String) -> void:
	var amount: float = AudioMix.duck_db(key)
	if is_zero_approx(amount):
		return
	var player: AudioStreamPlayer = _active_player()
	if not player.playing:
		return
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		return
	var base_db: float = _music_gains_db[_active_music_index]
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_property(player, "volume_db", base_db + amount, DUCK_ATTACK_DURATION)
	_duck_tween.tween_property(player, "volume_db", base_db, DUCK_RELEASE_DURATION)


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()


func _consume_rate_limit(key: String) -> bool:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var last: float = _last_played_at.get(key, -INF)
	if now - last < AudioMix.min_interval(key):
		return false
	_last_played_at[key] = now
	return true


func _pitch_for(key: String) -> float:
	var jitter: float = AudioMix.pitch_jitter(key)
	if is_zero_approx(jitter):
		return 1.0
	return 1.0 + randf_range(-jitter, jitter)


func _take_sfx_player() -> AudioStreamPlayer:
	var candidate: AudioStreamPlayer = _sfx_pool[0]
	var least_remaining: float = INF
	for player in _sfx_pool:
		if not player.playing:
			return player
		var remaining: float = _remaining_time(player.stream, player.get_playback_position())
		if remaining < least_remaining:
			least_remaining = remaining
			candidate = player
	return candidate


func _take_sfx_2d_player() -> AudioStreamPlayer2D:
	var candidate: AudioStreamPlayer2D = _sfx_2d_pool[0]
	var least_remaining: float = INF
	for player in _sfx_2d_pool:
		if not player.playing:
			return player
		var remaining: float = _remaining_time(player.stream, player.get_playback_position())
		if remaining < least_remaining:
			least_remaining = remaining
			candidate = player
	return candidate


func _remaining_time(stream: AudioStream, position: float) -> float:
	if stream == null:
		return 0.0
	return maxf(stream.get_length() - position, 0.0)


func _load_sfx(key: String) -> AudioStream:
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	for ext in [".ogg", ".wav"]:
		var path: String = SFX_DIR + key + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_sfx_cache[key] = stream
			return stream
	push_warning("AudioManager: SFX introuvable pour la clé '%s'" % key)
	return null


func _load_music(key: String) -> AudioStream:
	var path: String = MUSIC_DIR + key + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: musique introuvable '%s'" % path)
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
