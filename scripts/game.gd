extends Control

@onready var players: Node2D = $Players

func _ready() -> void:
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	var player = PlayerManager.spawnPlayer(NetworkManager.get_unique_id())
	players.add_child(player)
	
	_on_peer_connected()

func _on_peer_disconnected(peer_id) -> void:
	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()
	
func _on_peer_connected(peer_id: int = -1):
	var player
	if peer_id == -1:
		for peer in NetworkManager.get_peers():
			player = PlayerManager.spawnPlayer(peer)
			players.add_child(player)
	else:
		player = PlayerManager.spawnPlayer(peer_id)
		players.add_child(player)
