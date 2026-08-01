extends VBoxContainer

func _on_host_pressed() -> void:
	NetworkManager.hosting()

func _on_join_pressed() -> void:
	NetworkManager.joining()
