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
	{"item_type": "ingredient", "item_resource_path": "res://resources/Ingredients/cristal_givre.tres", "position": Vector2(950, 150)},
	{"item_type": "ingredient", "item_resource_path": "res://resources/Ingredients/bave_toxique.tres", "position": Vector2(200, 500)},
]

# DEBUG / TEMPORAIRE : à retirer quand la Phase 6.3 (placement procédural
# via spawn_table.gd) sera en place. Toutes les variantes de pièce d'arme
# existantes (resources/GunParts/) apparaissent à chaque lancement pour
# permettre de tester différentes combinaisons au labo, à une position
# tirée au sort (cf. WEAPON_PART_SPAWN_MARGIN pour les bornes, calées à
# l'intérieur des murs de test_room.tscn). Ce n'est pas un vrai système de
# spawn (pas de table pondérée, pas de points de spawn en éditeur, aucune
# rareté) : juste de quoi tester le crafting d'arme sans passer par le
# weapon_switcher de debug.
const WEAPON_PART_PATHS: Array[String] = [
	"res://resources/GunParts/water_barel_basic.tres",
	"res://resources/GunParts/water_barel_fast.tres",
	"res://resources/GunParts/mixture_barrel_basic.tres",
	"res://resources/GunParts/mixture_barrel_heavy.tres",
	"res://resources/GunParts/tank_basic.tres",
	"res://resources/GunParts/tank_large.tres",
	"res://resources/GunParts/core_basic.tres",
	"res://resources/GunParts/core_range.tres",
]
const WEAPON_PART_SPAWN_MARGIN: float = 80.0
const WEAPON_PART_SPAWN_SIZE: Vector2 = Vector2(1152, 648)

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
		for pickup_data in _generate_weapon_part_pickups():
			pickup_spawner.spawn(pickup_data)

func _generate_weapon_part_pickups() -> Array[Dictionary]:
	# DEBUG / TEMPORAIRE (cf. WEAPON_PART_PATHS) : à remplacer par la Phase
	# 6.3 (spawn_table.gd, points de spawn Marker2D par salle). Décidé une
	# seule fois côté hôte (autorité), puis répliqué aux clients via les
	# données envoyées à pickup_spawner.spawn() : aucun tirage local côté
	# client, cf. architecture_reseau.md.
	var paths := WEAPON_PART_PATHS.duplicate()
	paths.shuffle()
	var pickups: Array[Dictionary] = []
	for path in paths:
		var pos := Vector2(
			randf_range(WEAPON_PART_SPAWN_MARGIN, WEAPON_PART_SPAWN_SIZE.x - WEAPON_PART_SPAWN_MARGIN),
			randf_range(WEAPON_PART_SPAWN_MARGIN, WEAPON_PART_SPAWN_SIZE.y - WEAPON_PART_SPAWN_MARGIN)
		)
		pickups.append({"item_type": "weapon_part", "item_resource_path": path, "position": pos})
	return pickups

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
