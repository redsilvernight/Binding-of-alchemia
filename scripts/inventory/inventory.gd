class_name Inventory
extends Node

signal ingredient_added(ingredient: Ingredient, new_quantity: int)
signal ingredient_removed(ingredient: Ingredient, new_quantity: int)
signal weapon_part_added(part: Resource)
signal weapon_part_removed(part: Resource)

var ingredients: Dictionary = {} # String (resource_path) -> int (quantity)
var ingredient_resources: Dictionary = {} # String (resource_path) -> Ingredient (cache pour retrouver la Resource depuis la clé)
var weapon_parts: Array[Resource] = []


func add_ingredient(ingredient: Ingredient, amount: int = 1) -> void:
	if not multiplayer.is_server():
		return

	var key: String = ingredient.resource_path
	if key.is_empty():
		push_error("Inventory.add_ingredient: ingredient sans resource_path (Resource non sauvegardée sur disque)")
		return

	ingredients[key] = ingredients.get(key, 0) + amount
	ingredient_resources[key] = ingredient

	var owner_peer_id: int = _get_owner_peer_id()
	_rpc_ingredient_updated.rpc_id(owner_peer_id, key, ingredients[key])


func remove_ingredient(ingredient: Ingredient, amount: int = 1) -> bool:
	if not multiplayer.is_server():
		return false

	var key: String = ingredient.resource_path
	var current: int = ingredients.get(key, 0)
	if current < amount:
		return false

	ingredients[key] = current - amount

	var owner_peer_id: int = _get_owner_peer_id()
	_rpc_ingredient_updated.rpc_id(owner_peer_id, key, ingredients[key])

	return true


func get_ingredient_count(ingredient: Ingredient) -> int:
	return ingredients.get(ingredient.resource_path, 0)


func add_weapon_part(part: Resource) -> void:
	if not multiplayer.is_server():
		return

	weapon_parts.append(part)

	var owner_peer_id: int = _get_owner_peer_id()
	_rpc_weapon_part_added.rpc_id(owner_peer_id, part.resource_path)


func remove_weapon_part(part: Resource) -> bool:
	if not multiplayer.is_server():
		return false

	var index: int = weapon_parts.find(part)
	if index == -1:
		return false

	weapon_parts.remove_at(index)

	var owner_peer_id: int = _get_owner_peer_id()
	_rpc_weapon_part_removed.rpc_id(owner_peer_id, part.resource_path)

	return true


func _get_owner_peer_id() -> int:
	# Le noeud Player parent est nommé str(peer_id) (convention PlayerManager)
	return int(get_parent().name)


@rpc("authority", "call_local", "reliable")
func _rpc_ingredient_updated(ingredient_path: String, new_quantity: int) -> void:
	var ingredient: Ingredient = load(ingredient_path) as Ingredient
	if new_quantity > ingredients.get(ingredient_path, 0):
		ingredients[ingredient_path] = new_quantity
		ingredient_resources[ingredient_path] = ingredient
		ingredient_added.emit(ingredient, new_quantity)
	else:
		ingredients[ingredient_path] = new_quantity
		ingredient_removed.emit(ingredient, new_quantity)


@rpc("authority", "call_local", "reliable")
func _rpc_weapon_part_added(part_path: String) -> void:
	var part: Resource = load(part_path)
	weapon_parts.append(part)
	weapon_part_added.emit(part)


@rpc("authority", "call_local", "reliable")
func _rpc_weapon_part_removed(part_path: String) -> void:
	var part: Resource = load(part_path)
	var index: int = weapon_parts.find(part)
	if index != -1:
		weapon_parts.remove_at(index)
	weapon_part_removed.emit(part)
