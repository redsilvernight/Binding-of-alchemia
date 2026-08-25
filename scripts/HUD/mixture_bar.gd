extends TextureProgressBar

var _fill_tween: Tween

func _on_ammo_changed(current_ammo: float, max_ammo: float) -> void:
	max_value = max_ammo
	if _fill_tween:
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_property(self, "value", current_ammo, 0.6)
