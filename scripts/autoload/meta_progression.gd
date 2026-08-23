extends Node

signal currency_changed(new_amount: int)
signal run_currency_changed(new_amount: int)
signal unlocks_changed
signal shop_pool_changed

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
const SHOP_POOL_SIZE: int = 3

var currency_by_peer: Dictionary = {}
var unlocked_by_peer: Dictionary = {}
var run_currency_by_peer: Dictionary = {}
var shop_pool_by_peer: Dictionary = {}


func _ready() -> void:
	currency_changed.connect(_on_local_progression_changed.unbind(1))
	unlocks_changed.connect(_on_local_progression_changed)


func get_currency(peer_id: int) -> int:
	return currency_by_peer.get(peer_id, 0)


func get_run_currency(peer_id: int) -> int:
	return run_currency_by_peer.get(peer_id, 0)


func is_unlocked(peer_id: int, item_path: String) -> bool:
	return unlocked_by_peer.get(peer_id, {}).get(item_path, false)


func is_unlocked_by_party(item_path: String) -> bool:
	for peer_id in unlocked_by_peer:
		if unlocked_by_peer[peer_id].get(item_path, false):
			return true
	return false


func get_shop_pool(peer_id: int) -> Array:
	return shop_pool_by_peer.get(peer_id, [])


func add_currency(peer_id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	currency_by_peer[peer_id] = get_currency(peer_id) + amount
	run_currency_by_peer[peer_id] = get_run_currency(peer_id) + amount
	_notify_currency(peer_id)
	_notify_run_currency(peer_id)


func reset_run_currency() -> void:
	if not multiplayer.is_server():
		return
	run_currency_by_peer.clear()
	_notify_run_currency(NetworkManager.get_unique_id())
	for peer_id in NetworkManager.get_peers():
		_notify_run_currency(peer_id)


func reroll_shop_pool_for_all() -> void:
	if not multiplayer.is_server():
		return
	_reroll_shop_pool(NetworkManager.get_unique_id())
	for peer_id in NetworkManager.get_peers():
		_reroll_shop_pool(peer_id)


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


@rpc("any_peer", "call_local", "reliable")
func request_unlock(item_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_unique_id()

	if is_unlocked(sender_id, item_path):
		return
	if item_path not in get_shop_pool(sender_id):
		return
	var cost: int = _find_cost(item_path)
	if cost < 0:
		return
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


func apply_local_save_as_host() -> void:
	var save: Dictionary = SaveManager.load_progression()
	currency_by_peer[1] = int(save["currency"])
	var unlocked: Dictionary = {}
	for item_path in save["unlocked"]:
		unlocked[item_path] = true
	unlocked_by_peer[1] = unlocked


@rpc("any_peer", "call_local", "reliable")
func submit_saved_progression(currency: int, unlocked: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_unique_id()

	if not currency_by_peer.has(sender_id):
		currency_by_peer[sender_id] = int(currency)
	if not unlocked_by_peer.has(sender_id):
		unlocked_by_peer[sender_id] = {}
	for item_path in unlocked:
		unlocked_by_peer[sender_id][item_path] = true

	_notify_currency(sender_id)
	for item_path in unlocked_by_peer[sender_id].keys():
		_notify_unlock(sender_id, item_path)


func _on_local_progression_changed() -> void:
	var local_id: int = NetworkManager.get_unique_id()
	SaveManager.save_progression(get_currency(local_id), unlocked_by_peer.get(local_id, {}).keys())
