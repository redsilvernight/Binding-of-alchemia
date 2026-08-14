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
	RunManager.reset_floor() # Phase 9 : toute nouvelle partie démarre à l'étage 1
	_switch_to_game()


## "Jouer" en solo (main_menu.gd) : aucun ENet impliqué, multiplayer_peer
## reste null. Godot considère alors la partie comme "hors-ligne"
## (multiplayer.is_server() == true, get_unique_id() == 1, vérifié en sondant
## le comportement réel du moteur) -- tout le code host-authoritative
## (RPC "authority"/"any_peer" avec call_local, gardes is_server()) continue
## de fonctionner tel quel, sans code réseau ni port ouvert.
func play_solo() -> void:
	MetaProgression.apply_local_save_as_host()
	RunManager.reset_floor() # Phase 9 : toute nouvelle partie démarre à l'étage 1
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


## Quitte la session réseau localement (8.6, bouton "Retour au menu" du
## panneau de résumé de run) : pas de coordination avec les autres pairs,
## chacun décide pour lui-même, même logique que _on_connection_failed.
## Si c'est l'hôte qui quitte, son serveur ENet se ferme et les pairs
## restants perdent la connexion -- cas non géré au-delà de ça (aucun code
## du projet ne gère aujourd'hui un hôte qui part en cours de partie).
## Réassigne un OfflineMultiplayerPeer plutôt que null : c'est le peer par
## défaut de SceneMultiplayer (celui dont profite play_solo() sans jamais le
## créer explicitement) -- passer par null au lieu de lui le supprime pour de
## bon, et is_server()/get_unique_id()/RPC échouent ensuite pour le reste de
## la session (vu en jeu : plantage au nettoyage de room.gd puis à la
## relance d'une partie solo depuis le menu).
func leave_to_main_menu() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	print("connexion fail")
	
func _switch_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	
