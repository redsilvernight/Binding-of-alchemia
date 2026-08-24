extends Node

const TEST_CURRENCY: int = 999


func _ready() -> void:
	_disconnect_autosave()
	MetaProgression.currency = TEST_CURRENCY


func _disconnect_autosave() -> void:
	for connection in MetaProgression.currency_changed.get_connections():
		if connection["callable"].get_method() == "_on_local_progression_changed":
			MetaProgression.currency_changed.disconnect(connection["callable"])
	for connection in MetaProgression.unlocks_changed.get_connections():
		if connection["callable"].get_method() == "_on_local_progression_changed":
			MetaProgression.unlocks_changed.disconnect(connection["callable"])
