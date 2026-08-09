extends ProgressBar

func _ready() -> void:
	max_value = PlayerManager.MAX_LIFEPOINT
	value = PlayerManager.MAX_LIFEPOINT

func _on_heal_changed(max_lifepoint: float, lifepoint: float) -> void:
	max_value = max_lifepoint
	value = lifepoint
