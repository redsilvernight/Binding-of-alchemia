extends Node
## Options basiques (Phase 8.4) : volume et plein écran, persistés localement
## (indépendant de SaveManager, qui ne porte que la progression joueur).

const SETTINGS_PATH: String = "user://settings.json"

var master_volume: float = 1.0
var fullscreen: bool = false

var _master_bus_index: int = AudioServer.get_bus_index("Master")


func _ready() -> void:
	_load()
	_apply_master_volume()
	_apply_fullscreen()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	_save()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	_save()


func _apply_master_volume() -> void:
	AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(master_volume))


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
	fullscreen = bool(parsed.get("fullscreen", false))


func _save() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	var data: Dictionary = {"master_volume": master_volume, "fullscreen": fullscreen}
	file.store_string(JSON.stringify(data))
	file.close()
