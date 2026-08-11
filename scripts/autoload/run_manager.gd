extends Node
## Phase 8.1 : bascule de scène synchronisée hôte -> tous les pairs, entre le
## donjon et le hub. Autoload donc persiste à travers change_scene_to_file
## (contrairement à "Game"/"Hub", qui sont détruits à chaque bascule) : seul
## endroit fiable pour porter cette transition à travers les deux scènes.

const DUNGEON_SCENE_PATH: String = "res://scenes/game.tscn"
const HUB_SCENE_PATH: String = "res://scenes/world/hub.tscn"

# Bugfix hors scope (8.3, trouvé en playtest à plusieurs) : un changement de
# scène immédiat (change_scene_to_file détruit toute l'ancienne scène d'un
# coup) court-circuite le trafic MultiplayerSynchronizer encore en vol (sync
# de position continue, non fiable/UDP par nature) -- il arrive après que la
# scène soit détruite chez le destinataire (constaté en playtest :
# on_despawn_receive ERR_UNAUTHORIZED, "Node not found", cache id introuvable).
# Handshake en deux phases plutôt qu'un délai fixe deviné : l'hôte diffuse
# "préparez-vous" et attend l'accusé de réception de chaque pair avant de
# vraiment changer de scène, ce qui réduit la fenêtre de course à ~1
# aller-retour réseau au lieu de plusieurs secondes. Ça ne l'élimine pas à
# 100% (aucune garantie d'ordre entre un canal fiable et le canal non fiable
# de sync position -- limite de Godot, pas de ce code), mais la rend rare.
const SCENE_CHANGE_ACK_TIMEOUT: float = 3.0
const SCENE_CHANGE_ACK_POLL_INTERVAL: float = 0.05
var _peers_acked_scene_change: Dictionary = {} # hôte uniquement : peer_id -> true, réinitialisé à chaque transition


## Appelé côté hôte quand tous les joueurs de la run en cours sont morts
## (cf. game.gd._check_all_players_dead) ou quand le boss est vaincu (cf.
## game.gd._on_boss_defeated, qui applique son propre délai de mise en scène
## avant d'appeler ceci -- indépendant du handshake réseau ci-dessous).
func end_run() -> void:
	if not multiplayer.is_server():
		return
	_change_scene_with_handshake(HUB_SCENE_PATH)


## Requêtable par n'importe quel pair depuis le hub (RunStartStation) :
## seul l'hôte décide réellement, même garde que request_fire/request_craft_mixture.
@rpc("any_peer", "call_local", "reliable")
func request_start_run() -> void:
	if not multiplayer.is_server():
		return
	_change_scene_with_handshake(DUNGEON_SCENE_PATH)


## Hôte uniquement : diffuse "préparez-vous" à tous les pairs déjà connectés
## et attend leur accusé de réception (avec timeout de sécurité si un pair ne
## répond jamais -- déconnexion en plein transit) avant de diffuser le
## changement de scène réel.
func _change_scene_with_handshake(scene_path: String) -> void:
	_peers_acked_scene_change.clear()
	var expected_peers: PackedInt32Array = NetworkManager.get_peers()
	if not expected_peers.is_empty():
		_rpc_prepare_scene_change.rpc()
		var elapsed: float = 0.0
		while elapsed < SCENE_CHANGE_ACK_TIMEOUT:
			var all_acked: bool = true
			for peer_id in expected_peers:
				if not _peers_acked_scene_change.has(peer_id):
					all_acked = false
					break
			if all_acked:
				break
			await get_tree().create_timer(SCENE_CHANGE_ACK_POLL_INTERVAL).timeout
			elapsed += SCENE_CHANGE_ACK_POLL_INTERVAL
	_rpc_change_scene.rpc(scene_path)


## Envoyé uniquement aux clients (l'hôte n'a pas besoin de s'auto-notifier) :
## répond immédiatement par un accusé de réception, ne fait rien d'autre --
## le simple aller-retour de ce message fiable et ordonné suffit à vider le
## plus gros du trafic en vol accumulé avant ce point.
@rpc("authority", "reliable")
func _rpc_prepare_scene_change() -> void:
	_rpc_ack_scene_change.rpc_id(1)


## Toujours appelé par un pair distant (jamais l'hôte lui-même, cf.
## _rpc_prepare_scene_change qui n'est pas call_local) : get_remote_sender_id()
## y est donc toujours valide.
@rpc("any_peer", "reliable")
func _rpc_ack_scene_change() -> void:
	if not multiplayer.is_server():
		return
	_peers_acked_scene_change[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_local", "reliable")
func _rpc_change_scene(scene_path: String) -> void:
	# call_deferred : end_run() est atteint depuis take_damage() -> _update_health()
	# -> died.emit(), souvent lui-même déclenché depuis un callback physique
	# (ex : contact ennemi, cf. enemy_erratic.gd._on_collision_area_body_entered).
	# Un change_scene_to_file() direct y détruit des CollisionObject2D en plein
	# callback physique (erreur moteur) et peut libérer le noeud joueur avant
	# que les autres listeners de "died" (ex : Player._on_died) aient tourné.
	get_tree().change_scene_to_file.call_deferred(scene_path)
