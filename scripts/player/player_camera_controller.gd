class_name PlayerCameraController
extends RefCounted


const CAMERA_ZOOM_MARGIN: float = 1.05
const IMPACT_SHAKE_DAMAGE_REFERENCE: float = 18.0
const IMPACT_SHAKE_MIN_AMOUNT: float = 2.0
const IMPACT_SHAKE_MAX_AMOUNT: float = 9.0
const IMPACT_SHAKE_MIN_DURATION: float = 0.06
const IMPACT_SHAKE_MAX_DURATION: float = 0.28

var _camera: Camera2D

func _init(camera: Camera2D) -> void:
	_camera = camera

func update_zoom(viewport_size: Vector2) -> void:
	var zoom_x: float = viewport_size.x / float(Room.ROOM_WIDTH_PX)
	var zoom_y: float = viewport_size.y / float(Room.ROOM_HEIGHT_PX)
	var target_zoom: float = max(zoom_x, zoom_y) * CAMERA_ZOOM_MARGIN
	_camera.zoom = Vector2(target_zoom, target_zoom)

func update_room_limits(reference_position: Vector2) -> void:
	var room_col := floori(reference_position.x / Room.ROOM_WIDTH_PX)
	var room_row := floori(reference_position.y / Room.ROOM_HEIGHT_PX)
	_camera.limit_left = room_col * Room.ROOM_WIDTH_PX
	_camera.limit_top = room_row * Room.ROOM_HEIGHT_PX
	_camera.limit_right = (room_col + 1) * Room.ROOM_WIDTH_PX
	_camera.limit_bottom = (room_row + 1) * Room.ROOM_HEIGHT_PX

var _shake_tween: Tween

func shake(amount: float, duration: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_camera.offset = Vector2.ZERO
	_shake_tween = _camera.create_tween()
	var steps: int = maxi(1, roundi(duration / 0.03))
	for i in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var jitter := Vector2(randf_range(-amount, amount), randf_range(-amount, amount)) * falloff
		_shake_tween.tween_property(_camera, "offset", jitter, 0.03)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, 0.03)

func shake_for_damage(damage: float) -> void:
	var ratio: float = clamp(damage / IMPACT_SHAKE_DAMAGE_REFERENCE, 0.0, 1.0)
	var amount: float = lerp(IMPACT_SHAKE_MIN_AMOUNT, IMPACT_SHAKE_MAX_AMOUNT, ratio)
	var duration: float = lerp(IMPACT_SHAKE_MIN_DURATION, IMPACT_SHAKE_MAX_DURATION, ratio)
	shake(amount, duration)
