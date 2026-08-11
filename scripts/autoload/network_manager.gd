extends Node

var peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.connection_failed.connect(_on_connection_failed)
	
func hosting() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(31000, 4)
	multiplayer.multiplayer_peer = peer
	# L'hôte est toujours peer_id 1 : la sauvegarde locale peut donc être
	# seedée directement, sans RPC (8.3).
	MetaProgression.apply_local_save_as_host()
	_switch_to_game()


func joining() -> void:
	# Un nouveau ENetMultiplayerPeer à chaque tentative : réutiliser l'ancien
	# après un échec de connexion pouvait laisser un état ENet périmé.
	peer = ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 31000)
	multiplayer.multiplayer_peer = peer
	await multiplayer.connected_to_server
	# Transmet la progression sauvegardée localement à l'hôte, qui l'attache
	# au peer_id de cette session (8.3) -- le client ne peut pas le faire
	# lui-même, seul l'hôte écrit dans MetaProgression.
	var save: Dictionary = SaveManager.load_progression()
	MetaProgression.submit_saved_progression.rpc_id(1, save["currency"], save["unlocked"])
	_switch_to_game()

func get_peers() -> PackedInt32Array:
	return multiplayer.get_peers()
	
func get_unique_id() -> int:
	return multiplayer.get_unique_id()
	
func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	print("connexion fail")
	
func _switch_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	
