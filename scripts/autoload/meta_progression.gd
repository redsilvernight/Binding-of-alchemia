extends Node
## Progression méta (Phase 8.2) : monnaie et déblocages gagnés en run,
## dépensables au hub. Autoload (persiste à travers change_scene_to_file,
## contrairement à Inventory qui est un Node par-joueur recréé à chaque run,
## cf. run_manager.gd) mais les données restent PAR JOUEUR
## (currency_by_peer/unlocked_by_peer, clés = peer_id) : la roadmap tranche
## déjà ce point pour la sauvegarde (8.3, "a priori locale à chaque joueur
## pour sa progression méta"), donc 8.2 suit la même règle par cohérence en
## amont de 8.3.
##
## Gating de contenu (cf. spawn_table.gd) : le donjon est une ressource
## PARTAGÉE par le groupe (une seule génération pour toute la partie), donc
## un item devient disponible en donjon dès qu'UN SEUL joueur de la partie
## l'a débloqué (is_unlocked_by_party), même si chacun paie son propre achat
## de sa propre monnaie.

signal currency_changed(new_amount: int)
signal run_currency_changed(new_amount: int)
signal unlocks_changed

const UNLOCKABLES: Array[Dictionary] = [
	{"item_path": "res://resources/Ingredients/sang_hydre.tres", "display_name": "Sang d'Hydre", "cost": 80},
	{"item_path": "res://resources/Ingredients/eclair_zeus.tres", "display_name": "Éclair de Zeus", "cost": 80},
	{"item_path": "res://resources/GunParts/core_apollo.tres", "display_name": "Cœur d'Apollon", "cost": 120},
	{"item_path": "res://resources/GunParts/tank_titan.tres", "display_name": "Réservoir Titan", "cost": 120},
]

var currency_by_peer: Dictionary = {} # int peer_id -> int
var unlocked_by_peer: Dictionary = {} # int peer_id -> Dictionary[String, bool] (ensemble des item_path débloqués)
# Sous-ensemble de currency_by_peer, remis à zéro à chaque lancement de run
# (cf. RunManager.request_start_run) -- panneau de résumé de run (8.6), pour
# afficher "monnaie gagnée pendant cette run" sans perdre le total cumulatif.
var run_currency_by_peer: Dictionary = {} # int peer_id -> int


func _ready() -> void:
	# currency_changed/unlocks_changed n'émettent déjà que pour le joueur
	# LOCAL (cf. _notify_currency/_notify_unlock) : pas besoin de nouvelle
	# plomberie réseau pour savoir quand sauvegarder, juste écouter ce qui
	# existe déjà (8.3).
	currency_changed.connect(_on_local_progression_changed.unbind(1))
	unlocks_changed.connect(_on_local_progression_changed)


func get_currency(peer_id: int) -> int:
	return currency_by_peer.get(peer_id, 0)


func get_run_currency(peer_id: int) -> int:
	return run_currency_by_peer.get(peer_id, 0)


func is_unlocked(peer_id: int, item_path: String) -> bool:
	return unlocked_by_peer.get(peer_id, {}).get(item_path, false)


## Cf. spawn_table.gd : le donjon est partagé, un item débloqué par un seul
## joueur de la partie doit apparaître pour tout le monde.
func is_unlocked_by_party(item_path: String) -> bool:
	for peer_id in unlocked_by_peer:
		if unlocked_by_peer[peer_id].get(item_path, false):
			return true
	return false


## Hôte uniquement, appelé depuis EnemyBase._on_death() (déjà gardé par
## kill() -> multiplayer.is_server()).
func add_currency(peer_id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	currency_by_peer[peer_id] = get_currency(peer_id) + amount
	run_currency_by_peer[peer_id] = get_run_currency(peer_id) + amount
	_notify_currency(peer_id)
	_notify_run_currency(peer_id)


## Hôte uniquement, appelé par RunManager.request_start_run au lancement
## d'une run (fraîche ou "Rejouer" depuis le panneau de résumé) : remet le
## compteur "gagné cette run" à zéro pour tous les pairs déjà connus, et
## republie 0 à chacun (même besoin de rattrapage explicite que
## _notify_currency, un pair ne "voit" jamais l'état d'un autre pair).
func reset_run_currency() -> void:
	if not multiplayer.is_server():
		return
	run_currency_by_peer.clear()
	_notify_run_currency(NetworkManager.get_unique_id())
	for peer_id in NetworkManager.get_peers():
		_notify_run_currency(peer_id)


func _notify_currency(peer_id: int) -> void:
	# rpc_id call_local ne s'exécute localement que si la cible est soi-même :
	# même piège que Inventory._notify_owner_ingredient_update, l'hôte doit
	# émettre lui-même son propre signal quand peer_id est le sien.
	var amount: int = get_currency(peer_id)
	if peer_id == NetworkManager.get_unique_id():
		currency_changed.emit(amount)
	else:
		_rpc_currency_changed.rpc_id(peer_id, amount)


func _notify_run_currency(peer_id: int) -> void:
	var amount: int = get_run_currency(peer_id)
	if peer_id == NetworkManager.get_unique_id():
		run_currency_changed.emit(amount)
	else:
		_rpc_run_currency_changed.rpc_id(peer_id, amount)


@rpc("authority", "call_local", "reliable")
func _rpc_currency_changed(amount: int) -> void:
	currency_changed.emit(amount)


@rpc("authority", "call_local", "reliable")
func _rpc_run_currency_changed(amount: int) -> void:
	run_currency_changed.emit(amount)


## Requêtable par n'importe quel pair depuis unlock_screen.gd (hub) : même
## garde que Player.request_craft_mixture/request_equip_weapon_part -- seul
## l'hôte valide et débite, jamais le client localement.
@rpc("any_peer", "call_local", "reliable")
func request_unlock(item_path: String) -> void:
	if not multiplayer.is_server():
		return
	# Contrairement à request_fire (qui compare au nom du Player node ciblé),
	# ici il n'y a pas de noeud "propriétaire" : le pair qui a envoyé la
	# requête EST le joueur dont il faut débiter la monnaie. get_remote_sender_id()
	# vaut 0 quand l'hôte s'appelle lui-même via call_local (cf. NetworkManager.get_unique_id()).
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_unique_id()

	if is_unlocked(sender_id, item_path):
		return
	var cost: int = _find_cost(item_path)
	if cost < 0:
		return # item_path hors catalogue : requête invalide, on ignore
	if get_currency(sender_id) < cost:
		return

	currency_by_peer[sender_id] = get_currency(sender_id) - cost
	if not unlocked_by_peer.has(sender_id):
		unlocked_by_peer[sender_id] = {}
	unlocked_by_peer[sender_id][item_path] = true

	_notify_currency(sender_id)
	_notify_unlock(sender_id, item_path)


func _notify_unlock(peer_id: int, item_path: String) -> void:
	if peer_id == NetworkManager.get_unique_id():
		unlocks_changed.emit()
	else:
		_rpc_unlocked.rpc_id(peer_id, item_path)


## Répliqué uniquement vers le pair concerné (unlock_screen n'affiche que les
## déblocages du joueur local, pas ceux des coéquipiers) : suffit d'enregistrer
## sous SON PROPRE peer_id local.
@rpc("authority", "call_local", "reliable")
func _rpc_unlocked(item_path: String) -> void:
	var local_id: int = NetworkManager.get_unique_id()
	if not unlocked_by_peer.has(local_id):
		unlocked_by_peer[local_id] = {}
	unlocked_by_peer[local_id][item_path] = true
	unlocks_changed.emit()


func _find_cost(item_path: String) -> int:
	for entry in UNLOCKABLES:
		if entry["item_path"] == item_path:
			return entry["cost"]
	return -1


## Appelée par NetworkManager.hosting() (8.3) : l'hôte est toujours peer_id 1
## (Godot MultiplayerAPI), donc la sauvegarde locale peut y être seedée
## directement sans passer par un RPC.
func apply_local_save_as_host() -> void:
	var save: Dictionary = SaveManager.load_progression()
	currency_by_peer[1] = int(save["currency"])
	var unlocked: Dictionary = {}
	for item_path in save["unlocked"]:
		unlocked[item_path] = true
	unlocked_by_peer[1] = unlocked


## Appelée par NetworkManager.joining() (8.3) juste après connexion, avec le
## contenu de la sauvegarde locale du client. peer_id étant réattribué à
## chaque session, ce n'est qu'ici (une fois le peer_id de cette partie
## connu) que la progression sauvegardée peut être rattachée au bon
## sender_id -- jamais calculée par le client lui-même (même règle que
## request_unlock : seul l'hôte écrit dans currency_by_peer/unlocked_by_peer).
@rpc("any_peer", "call_local", "reliable")
func submit_saved_progression(currency: int, unlocked: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_unique_id()

	# N'écrase jamais un gain déjà obtenu pendant la session en cours (ex :
	# rattrapage tardif d'un submit qui serait arrivé après coup) : la monnaie
	# n'est seedée que si absente, les déblocages sont fusionnés (union), pas
	# remplacés.
	if not currency_by_peer.has(sender_id):
		currency_by_peer[sender_id] = int(currency)
	if not unlocked_by_peer.has(sender_id):
		unlocked_by_peer[sender_id] = {}
	for item_path in unlocked:
		unlocked_by_peer[sender_id][item_path] = true

	# Republie l'état confirmé au pair -- même pattern que le rattrapage déjà
	# fait dans hub.gd._on_peer_connected pour un pair qui rejoint en cours de
	# partie.
	_notify_currency(sender_id)
	for item_path in unlocked_by_peer[sender_id].keys():
		_notify_unlock(sender_id, item_path)


func _on_local_progression_changed() -> void:
	var local_id: int = NetworkManager.get_unique_id()
	SaveManager.save_progression(get_currency(local_id), unlocked_by_peer.get(local_id, {}).keys())
