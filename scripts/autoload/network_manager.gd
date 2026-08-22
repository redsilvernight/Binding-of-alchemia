extends Node

## Émis côté hôte dès que GameBoarder a attribué un code de session
## (voir scripts/HUD/session_code_label.gd, seul abonné actuel).
signal session_code_ready(code: String)
## Émis quand l'appairage GameBoarder échoue (auth, création ou résolution
## de session) -- purement informatif, ne bloque jamais le jeu en LAN.
signal session_error(message: String)


const GAME_ID := 2
const HOST_PORT := 31000
const MAX_PLAYERS := 4

# Signaux internes servant uniquement à convertir les callbacks HTTP du
# plugin GameBoarder (API à base de Callable) en points d'`await`, comme
# `multiplayer.connected_to_server` plus bas.
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
	# L'hôte est toujours peer_id 1 : la sauvegarde locale peut donc être
	# seedée directement, sans RPC (8.3).
	MetaProgression.apply_local_save_as_host()
	RunManager.reset_floor() # Phase 9 : toute nouvelle partie démarre à l'étage 1
	_switch_to_game()
	# L'enregistrement GameBoarder est best-effort et non bloquant : un hôte
	# LAN doit pouvoir continuer à jouer même si le service est injoignable.
	_register_session()


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


## Rejoint une session via son code GameBoarder (résolu en ip:port). Retourne
## false sans faire planter l'appelant si l'auth, la résolution ou la
## connexion ENet échoue -- multiplayer_menu.gd s'en sert pour afficher un
## message d'erreur.
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

	# Un nouveau ENetMultiplayerPeer à chaque tentative : réutiliser l'ancien
	# après un échec de connexion pouvait laisser un état ENet périmé.
	peer = ENetMultiplayerPeer.new()
	peer.create_client(resolved.ip, resolved.port)
	multiplayer.multiplayer_peer = peer
	await multiplayer.connected_to_server
	# Transmet la progression sauvegardée localement à l'hôte, qui l'attache
	# au peer_id de cette session (8.3) -- le client ne peut pas le faire
	# lui-même, seul l'hôte écrit dans MetaProgression.
	var save: Dictionary = SaveManager.load_progression()
	MetaProgression.submit_saved_progression.rpc_id(1, save["currency"], save["unlocked"])
	_switch_to_game()
	return true


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
	_close_session()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	print("connexion fail")

func _switch_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


## Authentifie ce pair auprès de GameBoarder en mode invité (device_id local,
## aucun compte ni mot de passe) -- suffisant pour créer/résoudre une session
## côté API, qui exige un token "player".
func _authenticate() -> bool:
	if GameBoarder.player_token != "":
		return true
	GameBoarder.auth.guestLogin(GAME_ID, func(status: int, _response: Dictionary):
		_auth_done.emit(status == 200)
	)
	return await _auth_done


func _register_session() -> void:
	if not await _authenticate():
		session_error.emit("Authentification GameBoarder impossible.")
		return
	GameBoarder.session.create(HOST_PORT, MAX_PLAYERS, "", func(status: int, response: Dictionary):
		# POST de création REST : l'API répond 201 Created, pas 200 (constaté
		# dans l'implémentation GameBoarder fonctionnelle de new-love-letter).
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
