class_name HUDOcclusionDimmer
extends Node

const DIMMED_ALPHA: float = 0.35
const FADE_DURATION: float = 0.25
const WATCHED_GROUPS: Array[String] = ["Enemies", "Loot"]

var _target: Control
var _local_player: Node2D = null
var _dimmed: bool = false
var _fade_tween: Tween


func _ready() -> void:
	_target = get_parent()


func _process(_delta: float) -> void:
	if _target == null:
		return
	if _local_player == null or not is_instance_valid(_local_player):
		_local_player = _find_local_player()
	var should_dim: bool = _is_occluded()
	if should_dim == _dimmed:
		return
	_dimmed = should_dim
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_target, "modulate:a", DIMMED_ALPHA if _dimmed else 1.0, FADE_DURATION)


func _is_occluded() -> bool:
	var rect: Rect2 = _target.get_global_rect()
	var canvas_transform: Transform2D = _target.get_viewport().get_canvas_transform()
	if _local_player and rect.has_point(canvas_transform * _local_player.global_position):
		return true
	for group in WATCHED_GROUPS:
		for entity in get_tree().get_nodes_in_group(group):
			if entity is Node2D and rect.has_point(canvas_transform * entity.global_position):
				return true
	return false


func _find_local_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_multiplayer_authority():
			return player
	return null
