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
signal unlocks_changed

const UNLOCKABLES: Array[Dictionary] = [
	{"item_path": "res://resources/Ingredients/sang_hydre.tres", "display_name": "Sang d'Hydre", "cost": 50},
	{"item_path": "res://resources/Ingredients/eclair_zeus.tres", "display_name": "Éclair de Zeus", "cost": 50},
	{"item_path": "res://resources/GunParts/core_apollo.tres", "display_name": "Cœur d'Apollon", "cost": 80},
	{"item_path": "res://resources/GunParts/tank_titan.tres", "display_name": "Réservoir Titan", "cost": 80},
]

var currency_by_peer: Dictionary = {} # int peer_id -> int
var unlocked_by_peer: Dictionary = {} # int peer_id -> Dictionary[String, bool] (ensemble des item_path débloqués)


func get_currency(peer_id: int) -> int:
	return currency_by_peer.get(peer_id, 0)


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
	_notify_currency(peer_id)


func _notify_currency(peer_id: int) -> void:
	# rpc_id call_local ne s'exécute localement que si la cible est soi-même :
	# même piège que Inventory._notify_owner_ingredient_update, l'hôte doit
	# émettre lui-même son propre signal quand peer_id est le sien.
	var amount: int = get_currency(peer_id)
	if peer_id == NetworkManager.get_unique_id():
		currency_changed.emit(amount)
	else:
		_rpc_currency_changed.rpc_id(peer_id, amount)


@rpc("authority", "call_local", "reliable")
func _rpc_currency_changed(amount: int) -> void:
	currency_changed.emit(amount)


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
