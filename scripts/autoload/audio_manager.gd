extends Node
## Phase 9.4 : lecture centralisée de la musique et des SFX. Autoload (comme
## Settings) plutôt que noeud de scène : la musique doit survivre à
## change_scene_to_file (hub <-> donjon, cf. run_manager.gd qui utilise déjà
## ce pattern pour l'écran de chargement).
##
## Un seul AudioStreamPlayer pour la musique (piste unique à la fois, coupure
## nette sans crossfade -- suffisant pour 3 pistes fixes hub/donjon/boss).
## Un pool de AudioStreamPlayer pour les SFX plutôt qu'un noeud par appel :
## évite de créer/détruire un noeud à chaque tir, et le round-robin encaisse
## des sons qui se chevauchent (ex: plusieurs impacts la même frame) sans
## qu'un son coupe le précédent sur le même player.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_POOL_SIZE: int = 8

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _sfx_cache: Dictionary = {} # String (key) -> AudioStream

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


## Silencieux si la clé est inconnue (push_warning) : un point de déclenchement
## de gameplay ne doit jamais planter faute d'un fichier audio manquant.
func play_sfx(key: String) -> void:
	var stream: AudioStream = _load_sfx(key)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_pool.size()
	player.stream = stream
	player.play()


## No-op si la piste demandée est déjà en cours (évite de redémarrer du
## début à chaque appel redondant, ex: _rpc_mark_room_visited rejoué).
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


## Essaie .ogg puis .wav : les SFX d'origine (tir, impacts, UI...) sont en
## .ogg (Kenney), les cris de créatures ajoutés ensuite (RPG Sound Pack,
## OpenGameArt) sont fournis en .wav -- Godot importe nativement les deux,
## pas besoin de reconvertir.
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
	# Le bouclage n'est pas activé par défaut à l'import .ogg (les fichiers
	# ont été copiés directement, pas importés depuis l'éditeur avec l'option
	# cochée) -- forcé ici sur la Resource elle-même plutôt que de dépendre
	# du .import, donc indépendant de la config d'import de chaque fichier.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
