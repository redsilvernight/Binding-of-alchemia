class_name Door
extends Node2D


const FADE_DURATION: float = 0.3

@onready var _closed_sprite: Sprite2D = $Closed
@onready var _open_sprite: Sprite2D = $Open

var _open: bool = false
var _tween: Tween
var _initialized: bool = false


func _ready() -> void:
	_closed_sprite.modulate.a = 1.0
	_open_sprite.modulate.a = 0.0


func set_state(effectively_open: bool) -> void:
	if effectively_open == _open and _initialized:
		return
	var should_play_sound: bool = _initialized
	_initialized = true
	_open = effectively_open
	if should_play_sound:
		AudioManager.play_sfx("door_open" if effectively_open else "door_close")
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_closed_sprite, "modulate:a", 0.0 if effectively_open else 1.0, FADE_DURATION)
	_tween.tween_property(_open_sprite, "modulate:a", 1.0 if effectively_open else 0.0, FADE_DURATION)
