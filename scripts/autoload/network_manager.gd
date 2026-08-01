extends Node

@onready var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()


func _ready() -> void:
	#multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
func hosting() -> void:
	peer.create_server(31000, 4)
	multiplayer.multiplayer_peer = peer
	_switch_to_game()
	
	
func joining() -> void:
	peer.create_client("127.0.0.1", 31000)
	multiplayer.multiplayer_peer = peer
	await multiplayer.connected_to_server 
	_switch_to_game()

func get_peers() -> PackedInt32Array:
	return multiplayer.get_peers()
	
func get_unique_id() -> int:
	return multiplayer.get_unique_id()

#func _on_peer_connected(peer_id: int) -> void:
	#print(peer_id)
	##var new_player = preload("res://scenes/player.tscn").instantiate()
	##new_player.set_multiplayer_authority(peer_id)
	##
	##Global.game_node.get_node("Players").add_child(new_player)
	
func _on_connection_failed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	print("connexion fail")
	
func _switch_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	
