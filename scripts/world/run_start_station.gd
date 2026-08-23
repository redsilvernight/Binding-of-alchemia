extends Node2D


@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Node2D) -> void:
	RunManager.request_start_run.rpc_id(1)
