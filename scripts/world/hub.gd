extends Node2D
## Scène hub (Phase 8.1) : écran "hors run", chargé quand tous les joueurs
## meurent (cf. game.gd._check_all_players_dead / RunManager.end_run) et
## point de départ d'une nouvelle run via RunStartStation. Spawn minimal des
## joueurs, réutilise PlayerManager.spawnPlayer comme game.gd — pas de
## donjon, d'ennemis ni de pickups ici, ces systèmes restent propres à
## game.gd.

@onready var players: Node2D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var HUD: Node2D = $HUD


func _ready() -> void:
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	player_spawner.spawn_function = _spawn_player
	if multiplayer.is_server():
		player_spawner.spawn(NetworkManager.get_unique_id())
		for peer_id in NetworkManager.get_peers():
			player_spawner.spawn(peer_id)


func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawnPlayer(id)
	player.instance_hud.connect(_hud_instance)
	return player


func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)
