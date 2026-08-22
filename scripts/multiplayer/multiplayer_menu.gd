extends VBoxContainer

@onready var code_input: LineEdit = $CodeInput
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	NetworkManager.session_error.connect(_on_session_error)


func _on_host_pressed() -> void:
	status_label.text = ""
	NetworkManager.hosting()


func _on_join_pressed() -> void:
	var code := code_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Entre un code de session."
		return
	status_label.text = "Connexion..."
	var ok: bool = await NetworkManager.joining(code)
	if not ok:
		status_label.text = "Connexion échouée."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_session_error(message: String) -> void:
	status_label.text = message
