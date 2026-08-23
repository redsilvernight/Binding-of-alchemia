extends Label

func _ready() -> void:
	visible = false
	if multiplayer.get_unique_id() != 1:
		return
	NetworkManager.session_code_ready.connect(_on_session_code_ready)
	if NetworkManager.session_code != "":
		_on_session_code_ready(NetworkManager.session_code)

func _on_session_code_ready(code: String) -> void:
	text = "Code : %s" % code
	visible = true
