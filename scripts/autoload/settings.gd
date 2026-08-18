extends Node
## Options basiques (Phase 8.4) : volume et plein écran, persistés localement
## (indépendant de SaveManager, qui ne porte que la progression joueur).

const SETTINGS_PATH: String = "user://settings.json"

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false
## Éclairage 2D dynamique (torche du joueur, assombrissement ambiant, ombres
## portées -- retour utilisateur). Toujours pas de _apply_dynamic_lighting()
## ici (Settings n'a pas de référence aux nodes CanvasModulate/PlayerLight,
## propres à la scène game.tscn/player.tscn) -- mais un signal est nécessaire
## dès que ce réglage peut changer APRÈS leur _ready() (menu pause en jeu,
## cf. pause_menu.tscn) : sans lui, seule la lecture initiale au chargement
## de la scène appliquait la valeur, ce qui le rendait muet une fois une
## partie déjà lancée (retour utilisateur, marchait seulement depuis le menu
## principal avant de lancer une run).
signal dynamic_lighting_changed(enabled: bool)
var dynamic_lighting: bool = true

var _master_bus_index: int = AudioServer.get_bus_index("Master")
var _music_bus_index: int = AudioServer.get_bus_index("Music")
var _sfx_bus_index: int = AudioServer.get_bus_index("SFX")


func _ready() -> void:
	_load()
	_apply_master_volume()
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_fullscreen()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	_save()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()
	_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_volume()
	_save()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	_save()


func set_dynamic_lighting(enabled: bool) -> void:
	dynamic_lighting = enabled
	dynamic_lighting_changed.emit(enabled)
	_save()


func _apply_master_volume() -> void:
	AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(master_volume))


func _apply_music_volume() -> void:
	AudioServer.set_bus_volume_db(_music_bus_index, linear_to_db(music_volume))


func _apply_sfx_volume() -> void:
	AudioServer.set_bus_volume_db(_sfx_bus_index, linear_to_db(sfx_volume))


func _apply_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	master_volume = clampf(float(parsed.get("master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(parsed.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(parsed.get("fullscreen", false))
	dynamic_lighting = bool(parsed.get("dynamic_lighting", true))


func _save() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	var data: Dictionary = {"master_volume": master_volume, "music_volume": music_volume, "sfx_volume": sfx_volume, "fullscreen": fullscreen, "dynamic_lighting": dynamic_lighting}
	file.store_string(JSON.stringify(data))
	file.close()
