class_name PlayerCameraController
extends RefCounted


const CAMERA_ZOOM_MARGIN: float = 1.05

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
