extends Node2D


@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(player: Node2D) -> void:
	if player.has_method("open_unlock_screen"):
		player.open_unlock_screen()
