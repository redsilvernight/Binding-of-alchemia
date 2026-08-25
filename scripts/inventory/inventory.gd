class_name Inventory
extends Node

signal ingredient_added(ingredient: Ingredient, new_quantity: int)
signal ingredient_removed(ingredient: Ingredient, new_quantity: int)
signal weapon_part_added(part: Resource)
signal weapon_part_removed(part: Resource)

var ingredients: Dictionary = {}
var ingredient_resources: Dictionary = {}
var weapon_parts: Array[Resource] = []


func add_ingredient(ingredient: Ingredient, amount: int = 1) -> void:
	if not multiplayer.is_server():
		return

	var key: String = ingredient.resource_path
	if key.is_empty():
		push_error("Inventory.add_ingredient: ingredient sans resource_path (Resource non sauvegardée sur disque)")
		return

	var new_quantity: int = ingredients.get(key, 0) + amount
	_apply_ingredient_update(key, new_quantity)
	_notify_owner_ingredient_update(key, new_quantity)


func remove_ingredient(ingredient: Ingredient, amount: int = 1) -> bool:
	if not multiplayer.is_server():
		return false

	var key: String = ingredient.resource_path
	var current: int = ingredients.get(key, 0)
	if current < amount:
		return false

	var new_quantity: int = current - amount
	_apply_ingredient_update(key, new_quantity)
	_notify_owner_ingredient_update(key, new_quantity)

	return true


func _notify_owner_ingredient_update(key: String, new_quantity: int) -> void:
	var owner_peer_id: int = _get_owner_peer_id()
	if owner_peer_id != multiplayer.get_unique_id():
		_rpc_ingredient_updated.rpc_id(owner_peer_id, key, new_quantity)


func get_ingredient_count(ingredient: Ingredient) -> int:
	return ingredients.get(ingredient.resource_path, 0)


func restore_snapshot(ingredients_snapshot: Dictionary, weapon_part_paths: Array) -> void:
	if not multiplayer.is_server():
		return
	for key in ingredients_snapshot.keys():
		var quantity: int = ingredients_snapshot[key]
		_apply_ingredient_update(key, quantity)
		_notify_owner_ingredient_update(key, quantity)
	for part_path in weapon_part_paths:
		_apply_weapon_part_added(part_path)
		_notify_owner_weapon_part_added(part_path)


func add_weapon_part(part: Resource) -> void:
	if not multiplayer.is_server():
		return

	_apply_weapon_part_added(part.resource_path)
	_notify_owner_weapon_part_added(part.resource_path)


func remove_weapon_part(part: Resource) -> bool:
	if not multiplayer.is_server():
		return false

	var index: int = weapon_parts.find(part)
	if index == -1:
		return false

	_apply_weapon_part_removed(part.resource_path)
	_notify_owner_weapon_part_removed(part.resource_path)

	return true


func _notify_owner_weapon_part_added(part_path: String) -> void:
	var owner_peer_id: int = _get_owner_peer_id()
	if owner_peer_id != multiplayer.get_unique_id():
		_rpc_weapon_part_added.rpc_id(owner_peer_id, part_path)


func _notify_owner_weapon_part_removed(part_path: String) -> void:
	var owner_peer_id: int = _get_owner_peer_id()
	if owner_peer_id != multiplayer.get_unique_id():
		_rpc_weapon_part_removed.rpc_id(owner_peer_id, part_path)


func _get_owner_peer_id() -> int:
	return int(get_parent().name)


func _apply_ingredient_update(ingredient_path: String, new_quantity: int) -> void:
	var ingredient: Ingredient = load(ingredient_path) as Ingredient
	ingredient_resources[ingredient_path] = ingredient
	if new_quantity > ingredients.get(ingredient_path, 0):
		ingredients[ingredient_path] = new_quantity
		ingredient_added.emit(ingredient, new_quantity)
	else:
		ingredients[ingredient_path] = new_quantity
		ingredient_removed.emit(ingredient, new_quantity)


func _apply_weapon_part_added(part_path: String) -> void:
	var part: Resource = load(part_path)
	weapon_parts.append(part)
	weapon_part_added.emit(part)


func _apply_weapon_part_removed(part_path: String) -> void:
	var part: Resource = load(part_path)
	var index: int = weapon_parts.find(part)
	if index != -1:
		weapon_parts.remove_at(index)
	weapon_part_removed.emit(part)


@rpc("authority", "call_local", "reliable")
func _rpc_ingredient_updated(ingredient_path: String, new_quantity: int) -> void:
	_apply_ingredient_update(ingredient_path, new_quantity)


@rpc("authority", "call_local", "reliable")
func _rpc_weapon_part_added(part_path: String) -> void:
	_apply_weapon_part_added(part_path)


@rpc("authority", "call_local", "reliable")
func _rpc_weapon_part_removed(part_path: String) -> void:
	_apply_weapon_part_removed(part_path)
