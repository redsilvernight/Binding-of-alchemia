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
	AudioManager.play_music("hub") # local à chaque pair, comme game.gd
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	player_spawner.spawn_function = _spawn_player
	if multiplayer.is_server():
		player_spawner.spawn(NetworkManager.get_unique_id())
		for peer_id in NetworkManager.get_peers():
			player_spawner.spawn(peer_id)
		# Phase 9 (loader) : cf. RunManager.hide_loading_screen.
		RunManager.hide_loading_screen()


func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawnPlayer(id)
	player.instance_hud.connect(_hud_instance)
	return player


func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)
		# Rattrape la monnaie/les déblocages déjà acquis par ce pair (8.2) :
		# MetaProgression._notify_currency/_notify_unlock ne poussent l'état
		# qu'au moment où il change, un pair qui rejoint après coup ne les a
		# jamais reçus autrement (même piège que le rattrapage HP du boss, 7.4).
		MetaProgression._rpc_currency_changed.rpc_id(peer_id, MetaProgression.get_currency(peer_id))
		for item_path in MetaProgression.unlocked_by_peer.get(peer_id, {}).keys():
			MetaProgression._rpc_unlocked.rpc_id(peer_id, item_path)
