extends TextureProgressBar

var _fill_tween: Tween

func _ready() -> void:
	max_value = PlayerManager.MAX_LIFEPOINT
	value = PlayerManager.MAX_LIFEPOINT

func _on_heal_changed(max_lifepoint: float, lifepoint: float) -> void:
	max_value = max_lifepoint
	if _fill_tween:
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_property(self, "value", lifepoint, 0.6)
