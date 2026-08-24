extends Node2D
class_name PlayerFireIndicator

@export var ready_color: Color = Color.WHITE
@export var radius: float = 4.0

const READY_ALPHA: float = 0.9
const COOLDOWN_ALPHA: float = 0.22
const OUTLINE_COLOR: Color = Color(0, 0, 0, 0.35)
const ARC_SEGMENTS: int = 14

var _fill_ratio: float = 1.0

func set_fill_ratio(ratio: float) -> void:
	ratio = clamp(ratio, 0.0, 1.0)
	if is_equal_approx(ratio, _fill_ratio):
		return
	_fill_ratio = ratio
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(ready_color, COOLDOWN_ALPHA))
	if _fill_ratio > 0.0:
		_draw_fill()
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, OUTLINE_COLOR, 1.0, true)

func _draw_fill() -> void:
	var fill_color := Color(ready_color, READY_ALPHA)
	if _fill_ratio >= 1.0:
		draw_circle(Vector2.ZERO, radius, fill_color)
		return
	var chord_y: float = radius - 2.0 * radius * _fill_ratio
	var half_angle: float = asin(clamp(chord_y / radius, -1.0, 1.0))
	var points := PackedVector2Array()
	for i in range(ARC_SEGMENTS + 1):
		var theta: float = lerp(half_angle, PI - half_angle, float(i) / float(ARC_SEGMENTS))
		points.append(Vector2(radius * cos(theta), radius * sin(theta)))
	draw_polygon(points, PackedColorArray([fill_color]))
