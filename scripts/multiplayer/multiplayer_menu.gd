extends VBoxContainer

func _on_host_pressed() -> void:
	NetworkManager.hosting()

func _on_join_pressed() -> void:
	NetworkManager.joining()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
