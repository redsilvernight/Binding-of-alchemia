class_name Pickup
extends Area2D

@export var item_resource: Resource
@export var item_type: String = "ingredient"
@export var currency_amount: int = 0

const PICKUP_DELAY: float = 0.3
const DESPAWN_DELAY: float = 10.0
const BLINK_START_DELAY: float = 8.0
const BLINK_INTERVAL: float = 0.15

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("Loot")
	monitoring = false
	body_entered.connect(_on_body_entered)
	_apply_icon()
	await get_tree().create_timer(PICKUP_DELAY, false).timeout
	if is_instance_valid(self):
		monitoring = true
	if item_type != "currency":
		get_tree().create_timer(BLINK_START_DELAY, false).timeout.connect(_start_blink)
		if multiplayer.is_server():
			get_tree().create_timer(DESPAWN_DELAY, false).timeout.connect(_on_despawn_timeout)


func _on_despawn_timeout() -> void:
	if is_instance_valid(self):
		queue_free()


func _start_blink() -> void:
	if not is_instance_valid(self):
		return
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.2, BLINK_INTERVAL).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate:a", 1.0, BLINK_INTERVAL).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_start_blink)


func _apply_icon() -> void:
	if item_resource == null or not ("icon" in item_resource):
		return
	var icon: Texture2D = item_resource.icon
	if icon:
		sprite.texture = icon
		sprite.modulate = Color.WHITE


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	AudioManager.play_sfx("pickup_currency" if item_type == "currency" else "pickup_ingredient")
	if not multiplayer.is_server():
		return

	if item_type == "currency":
		MetaProgression.add_currency(currency_amount)
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
