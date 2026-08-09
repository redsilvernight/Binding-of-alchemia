extends ProgressBar

func _on_ammo_changed(current_ammo: float, max_ammo: float) -> void:
	max_value = max_ammo
	value = current_ammo
