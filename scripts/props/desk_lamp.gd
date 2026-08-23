class_name DeskLamp
extends Node2D

const LIGHT_COLOR: Color = Color(1.0, 0.85, 0.55)

@onready var interactable: Interactable = $Interactable

var _light: WallLight = WallLight.new()
var _lit: bool = false


func _ready() -> void:
	_light.set_color(LIGHT_COLOR)
	_light.shadow_enabled = false
	_light.visible = _lit
	add_child(_light)
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Node2D) -> void:
	_lit = not _lit
	_light.visible = _lit
