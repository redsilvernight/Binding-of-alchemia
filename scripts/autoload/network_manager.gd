extends Node

signal session_code_ready(code: String)
signal session_error(message: String)


const GAME_ID := 2
const HOST_PORT := 31000
const MAX_PLAYERS := 4

signal _auth_done(success: bool)
signal _session_create_done(result: Dictionary)
signal _session_resolve_done(result: Dictionary)

var peer: ENetMultiplayerPeer
var session_code: String = ""


func _ready() -> void:
	multiplayer.connection_failed.connect(_on_connection_failed)


func hosting() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(HOST_PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	MetaProgression.apply_local_save_as_host()
	RunManager.reset_floor()
	RunManager.request_start_run.rpc_id(1)
	_register_session()


func play_solo() -> void:
	MetaProgression.apply_local_save_as_host()
	RunManager.reset_floor()
	RunManager.request_start_run.rpc_id(1)


func joining(code: String) -> bool:
	if not await _authenticate():
		session_error.emit("Authentification GameBoarder impossible.")
		return false

	GameBoarder.session.resolve(code, func(status: int, response: Dictionary):
		if status == 200 and response.has("ip") and response.has("port"):
			_session_resolve_done.emit({"ip": response.ip, "port": int(response.port)})
		else:
			_session_resolve_done.emit({})
	)
	var resolved: Dictionary = await _session_resolve_done
	if resolved.is_empty():
		session_error.emit("Code de session introuvable ou expiré.")
		return false

	peer = ENetMultiplayerPeer.new()
	peer.create_client(resolved.ip, resolved.port)
	multiplayer.multiplayer_peer = peer
	await multiplayer.connected_to_server
	var save: Dictionary = SaveManager.load_progression()
	MetaProgression.submit_saved_progression.rpc_id(1, save["unlocked"])
	_switch_to_game()
	return true


func get_peers() -> PackedInt32Array:
	return multiplayer.get_peers()

func get_unique_id() -> int:
	return multiplayer.get_unique_id()


func leave_to_main_menu() -> void:
	_close_session()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _switch_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _authenticate() -> bool:
	if GameBoarder.player_token != "":
		return true
	GameBoarder.auth.guestLogin(GAME_ID, func(status: int, _response: Dictionary):
		_auth_done.emit(status == 200)
	)
	return await _auth_done


func _fetch_public_ipv4() -> String:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request("https://api.ipify.org")
	if err != OK:
		http.queue_free()
		return ""
	var result: Array = await http.request_completed
	http.queue_free()
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	if response_code != 200:
		return ""
	return body.get_string_from_utf8().strip_edges()


func _register_session() -> void:
	if not await _authenticate():
		session_error.emit("Authentification GameBoarder impossible.")
		return
	var public_ipv4 := await _fetch_public_ipv4()
	GameBoarder.session.create(HOST_PORT, MAX_PLAYERS, public_ipv4, func(status: int, response: Dictionary):
		if (status == 200 or status == 201) and response.has("code"):
			_session_create_done.emit({"code": response.code})
		else:
			_session_create_done.emit({})
	)
	var created: Dictionary = await _session_create_done
	if created.is_empty():
		printerr("[GameBoarder] Échec de création de session.")
		session_error.emit("Impossible de créer la session en ligne.")
		return
	session_code = created.code
	session_code_ready.emit(session_code)


func _close_session() -> void:
	if session_code == "":
		return
	GameBoarder.session.close(session_code)
	session_code = ""
