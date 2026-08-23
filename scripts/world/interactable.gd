class_name Interactable
extends Area2D


signal interacted(player: Node2D)
signal player_left(player: Node2D)

@export var prompt_text: String = "Appuyer sur E"

@onready var prompt_label: Label = $PromptLabel

var _local_player_inside: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.text = prompt_text
		prompt_label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	if not body.is_multiplayer_authority():
		return
	_local_player_inside = body
	if prompt_label:
		prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _local_player_inside:
		return
	_local_player_inside = null
	if prompt_label:
		prompt_label.visible = false
	player_left.emit(body)


func _unhandled_input(event: InputEvent) -> void:
	if _local_player_inside == null:
		return
	if event.is_action_pressed("interact"):
		interacted.emit(_local_player_inside)
