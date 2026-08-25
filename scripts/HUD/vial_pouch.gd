extends Control

const DIMMED_ALPHA: float = 0.35
const FADE_DURATION: float = 0.25

var _player: Node2D = null
var _fade_tween: Tween
var _dimmed: bool = false

func bind_player(player: Node2D) -> void:
	_player = player

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * _player.global_position
	var should_dim: bool = get_global_rect().has_point(screen_position)
	if should_dim == _dimmed:
		return
	_dimmed = should_dim
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", DIMMED_ALPHA if _dimmed else 1.0, FADE_DURATION)
