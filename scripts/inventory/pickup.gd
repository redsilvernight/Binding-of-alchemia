class_name Pickup
extends Area2D

@export var item_resource: Resource # Ingredient ou pièce d'arme (GunBarrelWater, etc.)
@export var item_type: String = "ingredient" # "ingredient" ou "weapon_part"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("Players"):
		return

	var player_inventory: Inventory = body.get_node("Inventory")
	if player_inventory == null:
		push_error("Pickup: noeud Inventory introuvable sur %s" % body.name)
		return

	match item_type:
		"ingredient":
			player_inventory.add_ingredient(item_resource as Ingredient)
		"weapon_part":
			player_inventory.add_weapon_part(item_resource)
		_:
			push_error("Pickup: item_type inconnu '%s'" % item_type)
			return

	queue_free()


@rpc("call_local", "reliable")
func _despawn() -> void:
	if not is_multiplayer_authority():
		queue_free()
