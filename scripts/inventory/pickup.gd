class_name Pickup
extends Area2D

@export var item_resource: Resource # Ingredient ou pièce d'arme (GunBarrelWater, etc.)
@export var item_type: String = "ingredient" # "ingredient", "weapon_part" ou "currency"
@export var currency_amount: int = 0 # utilisé seulement si item_type == "currency"

## Un drop de kill (Phase 9.2 : request_enemy_drop/request_currency_drop)
## apparaît à la position de mort de l'ennemi, souvent collée au joueur en
## mêlée -- sans délai, body_entered se déclenche dès l'instanciation et le
## pickup disparaît avant même d'être visible. monitoring désactivé le temps
## de ce délai, sur chaque pair indépendamment (état purement local/visuel,
## pas de coordination réseau nécessaire).
const PICKUP_DELAY: float = 0.3

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	_apply_icon()
	await get_tree().create_timer(PICKUP_DELAY).timeout
	if is_instance_valid(self):
		monitoring = true


## item_resource porte son propre icon (Ingredient, Phase 9.3) -- sinon on
## garde le sprite placeholder déjà posé dans la scène (couleur par item_type).
func _apply_icon() -> void:
	if item_resource == null or not ("icon" in item_resource):
		return
	var icon: Texture2D = item_resource.icon
	if icon:
		sprite.texture = icon
		sprite.modulate = Color.WHITE


func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("Players"):
		return

	if item_type == "currency":
		# Partagée à toute la partie dès le ramassage par n'importe quel
		# joueur (pas individuelle) : les améliorations méta débloquables
		# (Phase 8.2) n'ont de sens que si l'équipe progresse ensemble,
		# même logique que l'ancien crédit instantané de kill.
		for peer_id in NetworkManager.get_peers():
			MetaProgression.add_currency(peer_id, currency_amount)
		MetaProgression.add_currency(NetworkManager.get_unique_id(), currency_amount)
		queue_free()
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
