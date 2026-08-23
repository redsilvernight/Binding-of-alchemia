extends Control


var accepts: Callable = func(_part: Resource) -> bool: return true
signal part_dropped(part: Resource)

const HIGHLIGHT_STYLE: StyleBoxFlat = preload("res://resources/ui/socket_frame_highlight.tres")

@onready var icon_rect: TextureRect = $Icon
@onready var frame: Panel = $Frame

var _default_frame_style: StyleBox


func _ready() -> void:
	_default_frame_style = frame.get_theme_stylebox("panel")


func setup(icon: Texture2D, tooltip: String = "") -> void:
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	tooltip_text = tooltip


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("part") and accepts.call(data["part"])


func _drop_data(_position: Vector2, data: Variant) -> void:
	part_dropped.emit(data["part"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and data.has("part") and accepts.call(data["part"]):
			frame.add_theme_stylebox_override("panel", HIGHLIGHT_STYLE)
	elif what == NOTIFICATION_DRAG_END:
		frame.add_theme_stylebox_override("panel", _default_frame_style)
