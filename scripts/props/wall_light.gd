class_name WallLight
extends Node2D


const LIGHT_TEXTURE: Texture2D = preload("res://resources/vfx/point_light_radial.tres")
const FLICKER_MIN_ENERGY: float = 0.85
const FLICKER_MAX_ENERGY: float = 1.15
const FLICKER_MIN_DURATION: float = 0.4
const FLICKER_MAX_DURATION: float = 0.9

var shadow_enabled: bool = true
var _light: PointLight2D = PointLight2D.new()


func set_color(color: Color) -> void:
	_light.color = color


func _ready() -> void:
	_light.texture = LIGHT_TEXTURE
	_light.texture_scale = 1.1
	_light.shadow_enabled = shadow_enabled
	_light.shadow_color = Color(0, 0, 0, 0.3)
	add_child(_light)
	_light.energy = randf_range(FLICKER_MIN_ENERGY, FLICKER_MAX_ENERGY)
	_flicker_loop()


func _flicker_loop() -> void:
	var target_energy: float = randf_range(FLICKER_MIN_ENERGY, FLICKER_MAX_ENERGY)
	var duration: float = randf_range(FLICKER_MIN_DURATION, FLICKER_MAX_DURATION)
	var tween: Tween = create_tween()
	tween.tween_property(_light, "energy", target_energy, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_flicker_loop)
