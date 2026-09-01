extends Node

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_POOL_SIZE: int = 8

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _sfx_cache: Dictionary = {}

var _music_player: AudioStreamPlayer
var _current_music_key: String = ""


func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _load_sfx(key)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_music(key: String) -> void:
	if _current_music_key == key and _music_player.playing:
		return
	var stream: AudioStream = _load_music(key)
	if stream == null:
		return
	_current_music_key = key
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_current_music_key = ""
	_music_player.stop()


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
