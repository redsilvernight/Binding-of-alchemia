# game.gd
extends Control
@onready var players: Node2D = $Players
@onready var ennemis: Node2D = $Ennemis
@onready var HUD: Node2D = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var pickups: Node2D = $Pickups
@onready var pickup_spawner: MultiplayerSpawner = $PickupSpawner

const TEST_PICKUPS: Array[Dictionary] = [
	{"item_type": "ingredient", "item_resource_path": "res://resources/Ingredients/braise.tres", "position": Vector2(200, 150)},
	{"item_type": "weapon_part", "item_resource_path": "res://resources/GunParts/water_barel_fast.tres", "position": Vector2(950, 500)},
	{"item_type": "weapon_part", "item_resource_path": "res://resources/GunParts/core_basic.tres", "position": Vector2(585, 550)},
	{"item_type": "ingredient", "item_resource_path": "res://resources/Ingredients/cristal_givre.tres", "position": Vector2(950, 150)},
	{"item_type": "ingredient", "item_resource_path": "res://resources/Ingredients/bave_toxique.tres", "position": Vector2(200, 500)},
]

func _ready() -> void:
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	projectile_spawner.spawn_function = _spawn_bullet
	enemy_spawner.spawn_function = _spawn_enemy
	player_spawner.spawn_function = _spawn_player
	pickup_spawner.spawn_function = _spawn_pickup

	if multiplayer.is_server():
		player_spawner.spawn(NetworkManager.get_unique_id())
		for i in range(1):
			enemy_spawner.spawn({"position": Vector2(i * 40, 0)})
		for pickup_data in TEST_PICKUPS:
			pickup_spawner.spawn(pickup_data)

func _spawn_pickup(data: Dictionary) -> Node:
	var scene_path := "res://scenes/debug/ingredient_pickup.tscn" if data["item_type"] == "ingredient" else "res://scenes/debug/weapon_part_pickup.tscn"
	var pickup: Pickup = load(scene_path).instantiate() if false else (load(scene_path) as PackedScene).instantiate()
	pickup.position = data["position"]
	pickup.item_type = data["item_type"]
	pickup.item_resource = load(data["item_resource_path"])
	return pickup
	
func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawnPlayer(id)
	player.instance_hud.connect(_hud_instance)
	player.instance_projectile.connect(_on_projectile_requested)
	return player

func _spawn_bullet(data: Dictionary) -> Node:
	var bullet: Bullet = preload("res://scenes/projectiles/bullet.tscn").instantiate()
	bullet.setup(data["damage"], data["speed"], data["lifetime"], data["trajectory"])
	if data.has("impact_effect_data"):
		var effect: ImpactEffect = ImpactEffect.from_dict(data["impact_effect_data"])
		bullet.set_impact_effect(effect)
	bullet.launch.call_deferred(data["from_position"], data["direction"])
	return bullet

func _spawn_enemy(data: Dictionary) -> Node:
	var enemy: Node = EnemyManager.get_enemy_scene().instantiate()
	enemy.position = data["position"]
	return enemy

func _on_peer_disconnected(peer_id) -> void:
	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)

func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)

func _on_projectile_requested(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)
