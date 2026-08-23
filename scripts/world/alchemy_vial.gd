class_name AlchemyVial
extends Node2D


@onready var _whole_sprite: Sprite2D = $WholeSprite
@onready var _broken_sprite: Sprite2D = $BrokenSprite

var peer_id: int = 0


func set_broken(broken: bool) -> void:
	_whole_sprite.visible = not broken
	_broken_sprite.visible = broken


func break_effect() -> void:
	set_broken(true)
	AudioManager.play_sfx("vial_break")
