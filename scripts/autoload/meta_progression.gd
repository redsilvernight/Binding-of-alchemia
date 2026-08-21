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
## Retour utilisateur : la boutique ne doit pas proposer tout le catalogue
## d'un coup -- un pool restreint, cf. shop_pool_by_peer ci-dessous.
signal shop_pool_changed

## Retour utilisateur ("pas assez de déblocables actuellement") : +6
## ingrédients, choisis parmi les 36 du catalogue (resources/Ingredients/)
## comme les plus puissants par degats_base RÉEL (pas duree_base -- vérifié
## dans alchemy_resolver.gd/mixture_to_effect.gd/impact_effect.gd :
## duree_base ne fait qu'étaler le MÊME total de dégâts en ticks plus
## nombreux, cf. _apply_damage_over_time, donc un ingrédient à faible
## degats_base mais longue durée n'est PAS plus fort pour autant -- seul
## zone_base est un vrai multiplicateur de puissance, en touchant plusieurs
## cibles). Classement obtenu par grep sur tous les .tres puis lecture du
## code de résolution, pas une estimation :
## - baril_poudre (12, EXPLOSIF) / eclat_shrapnel (10, EXPLOSIF) : dégâts
##   bruts les plus élevés du jeu, toutes catégories confondues.
## - seve_de_vie (-10, SOIN) : plus gros soin du jeu (degats_base négatif =
##   soin, cf. mixture_to_effect.gd).
## - noyau_instable (8, zone 3.0, EXPLOSIF) : 2e plus grande zone du jeu.
## - orage_captif (9, ELECTRIQUE) : meilleur ingrédient électrique après
##   Éclair de Zeus (déjà déblocable).
## - braise (8, FEU) : meilleur ingrédient feu, aucun autre n'approche.
## Explosif domine nettement ce classement (3 des 6 picks) -- c'est un fait
## des données actuelles, pas un choix arbitraire ; Glace plafonne à 4
## dégâts et n'a donc aucun candidat "puissant" à proposer ici. Chaque ajout
## a aussi reçu requires_unlock=true dans resources/spawn_tables/ingredients.tres
## (sinon il resterait disponible gratuitement dès le début malgré son
## entrée ici).
const UNLOCKABLES: Array[Dictionary] = [
	{"item_path": "res://resources/Ingredients/sang_hydre.tres", "display_name": "Sang d'Hydre", "cost": 80},
	{"item_path": "res://resources/Ingredients/eclair_zeus.tres", "display_name": "Éclair de Zeus", "cost": 80},
	{"item_path": "res://resources/GunParts/core_apollo.tres", "display_name": "Cœur d'Apollon", "cost": 120},
	{"item_path": "res://resources/GunParts/tank_titan.tres", "display_name": "Réservoir Titan", "cost": 120},
	{"item_path": "res://resources/Ingredients/baril_poudre.tres", "display_name": "Baril de Poudre", "cost": 140},
	{"item_path": "res://resources/Ingredients/eclat_shrapnel.tres", "display_name": "Éclat de Shrapnel", "cost": 110},
	{"item_path": "res://resources/Ingredients/seve_de_vie.tres", "display_name": "Sève de Vie", "cost": 110},
	{"item_path": "res://resources/Ingredients/orage_captif.tres", "display_name": "Orage Captif", "cost": 110},
	{"item_path": "res://resources/Ingredients/noyau_instable.tres", "display_name": "Noyau Instable", "cost": 110},
	{"item_path": "res://resources/Ingredients/braise.tres", "display_name": "Braise", "cost": 90},
]
## Nombre d'objets proposés en vitrine à la fois (retour utilisateur : "pas
## tous d'un coup"), cf. _reroll_shop_pool().
const SHOP_POOL_SIZE: int = 3

var currency_by_peer: Dictionary = {} # int peer_id -> int
var unlocked_by_peer: Dictionary = {} # int peer_id -> Dictionary[String, bool] (ensemble des item_path débloqués)
# Sous-ensemble de currency_by_peer, remis à zéro à chaque lancement de run
# (cf. RunManager.request_start_run) -- panneau de résumé de run (8.6), pour
# afficher "monnaie gagnée pendant cette run" sans perdre le total cumulatif.
var run_currency_by_peer: Dictionary = {} # int peer_id -> int
## Sous-ensemble d'UNLOCKABLES (item_path) actuellement en vente pour ce
## pair -- régénéré à chaque lancement de run (cf. reroll_shop_pool_for_all(),
## appelée par RunManager.request_start_run) plutôt que figé pour toute la
## partie, pour que la boutique se renouvelle comme dans la plupart des
## roguelites. Par pair comme currency_by_peer/unlocked_by_peer : chacun a
## sa propre vitrine, cohérent avec le reste de la progression méta.
var shop_pool_by_peer: Dictionary = {} # int peer_id -> Array[String]


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


func get_shop_pool(peer_id: int) -> Array:
	return shop_pool_by_peer.get(peer_id, [])


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


## Host uniquement, appelé par RunManager.request_start_run() : la vitrine
## de chaque pair se renouvelle à chaque nouvelle run -- même liste de pairs
## que reset_run_currency() (soi-même + tous les pairs déjà connectés).
func reroll_shop_pool_for_all() -> void:
	if not multiplayer.is_server():
		return
	_reroll_shop_pool(NetworkManager.get_unique_id())
	for peer_id in NetworkManager.get_peers():
		_reroll_shop_pool(peer_id)


## Host uniquement : garantit qu'un pair a un pool assigné SANS le
## reroll s'il en a déjà un -- rattrapage pour l'hôte à son tout premier
## accès (hub.gd._ready()) ou un pair qui vient de se connecter en cours de
## partie (hub.gd._on_peer_connected), pas un renouvellement volontaire
## (cf. reroll_shop_pool_for_all() pour ça).
func ensure_shop_pool(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if shop_pool_by_peer.has(peer_id):
		return
	_reroll_shop_pool(peer_id)


func _reroll_shop_pool(peer_id: int) -> void:
	var candidates: Array = []
	for entry in UNLOCKABLES:
		if not is_unlocked(peer_id, entry["item_path"]):
			candidates.append(entry["item_path"])
	candidates.shuffle()
	shop_pool_by_peer[peer_id] = candidates.slice(0, SHOP_POOL_SIZE)
	_notify_shop_pool(peer_id)


func _notify_shop_pool(peer_id: int) -> void:
	var pool: Array = get_shop_pool(peer_id)
	if peer_id == NetworkManager.get_unique_id():
		shop_pool_changed.emit()
	else:
		_rpc_shop_pool.rpc_id(peer_id, pool)


@rpc("authority", "call_local", "reliable")
func _rpc_shop_pool(pool: Array) -> void:
	shop_pool_by_peer[NetworkManager.get_unique_id()] = pool
	shop_pool_changed.emit()


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
	if item_path not in get_shop_pool(sender_id):
		return # pas dans la vitrine actuelle de ce pair : requête invalide, on ignore
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
