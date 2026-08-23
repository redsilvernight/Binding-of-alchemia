extends Label

func _ready() -> void:
	RunManager.floor_changed.connect(_on_floor_changed)
	_on_floor_changed(RunManager.current_floor)

func _on_floor_changed(new_floor: int) -> void:
	text = "Étage : %d" % new_floor
