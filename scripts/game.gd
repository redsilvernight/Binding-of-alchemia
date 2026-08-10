# game.gd
extends Control
@onready var rooms: Node2D = $Rooms
@onready var room_spawner: MultiplayerSpawner = $RoomSpawner
@onready var players: Node2D = $Players
@onready var ennemis: Node2D = $Ennemis
@onready var HUD: Node2D = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var pickups: Node2D = $Pickups
@onready var pickup_spawner: MultiplayerSpawner = $PickupSpawner

# Phase 6.1 : toutes les salles ont le même gabarit (modèle grille fixe,
# cf. DungeonGenerator) — obligatoire pour que les portes de deux salles
# voisines s'alignent toujours sans avoir à les valider au cas par cas.
const ROOM_CELL_SIZE: Vector2 = Vector2(500, 648)
const DUNGEON_ROOM_COUNT: int = 6
const ROOM_TEMPLATE_PATHS: Array[String] = [
	"res://scenes/rooms/room_template_a.tscn",
	"res://scenes/rooms/room_template_b.tscn",
]
# Une seule salle spéciale par donjon, choisie au hasard entre alchimie et
# arme — jamais les deux ensemble (cf. room_alchemy.tscn / room_weapon.tscn).
const SPECIAL_ROOM_TEMPLATE_PATHS: Array[String] = [
	"res://scenes/rooms/room_alchemy.tscn",
	"res://scenes/rooms/room_weapon.tscn",
]

const INGREDIENT_PATHS: Array[String] = [
	"res://resources/Ingredients/braise.tres",
	"res://resources/Ingredients/cristal_givre.tres",
	"res://resources/Ingredients/bave_toxique.tres",
]

# DEBUG / TEMPORAIRE : à retirer quand la Phase 6.3 (placement procédural
# via spawn_table.gd, points de spawn Marker2D par salle, table pondérée)
# sera en place. Ici, ingrédients et pièces d'arme sont juste dispersés au
# hasard dans les salles explorables générées (hors salle spéciale) pour pouvoir
# tester la boucle ramasser -> crafter de bout en bout — aucune rareté,
# aucun contrôle sur quelle salle reçoit quoi.
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
const ROOM_SPAWN_MARGIN: float = 80.0

func _ready() -> void:
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	room_spawner.spawn_function = _spawn_room
	projectile_spawner.spawn_function = _spawn_bullet
	enemy_spawner.spawn_function = _spawn_enemy
	player_spawner.spawn_function = _spawn_player
	pickup_spawner.spawn_function = _spawn_pickup

	if multiplayer.is_server():
		var dungeon_layout: Array[Dictionary] = DungeonGenerator.generate(DUNGEON_ROOM_COUNT, ROOM_TEMPLATE_PATHS, SPECIAL_ROOM_TEMPLATE_PATHS)
		for room_data in dungeon_layout:
			room_spawner.spawn(room_data)

		player_spawner.spawn(NetworkManager.get_unique_id())
		for i in range(1):
			var enemy_room: Dictionary = _random_explorable_room(dungeon_layout, true)
			var enemy_rect: Rect2 = _room_world_rect(enemy_room)
			enemy_spawner.spawn({"position": enemy_rect.position + ROOM_CELL_SIZE / 2})
		for pickup_data in _generate_ingredient_pickups(dungeon_layout):
			pickup_spawner.spawn(pickup_data)
		for pickup_data in _generate_weapon_part_pickups(dungeon_layout):
			pickup_spawner.spawn(pickup_data)

func _spawn_room(data: Dictionary) -> Node:
	var room: Node2D = (load(data["template_path"]) as PackedScene).instantiate()
	room.position = Vector2(data["grid_position"]) * ROOM_CELL_SIZE
	# set_open_sides() lit des noeuds enfants via @onready : le noeud doit
	# être entré dans l'arbre (donc _ready() déjà passé) avant qu'on
	# l'appelle, sans quoi les références sont encore nulles (même piège
	# documenté pour launch() en Phase 3.5).
	room.set_open_sides.call_deferred(data["open_sides"])
	return room

func _room_world_rect(room_data: Dictionary) -> Rect2:
	return Rect2(Vector2(room_data["grid_position"]) * ROOM_CELL_SIZE, ROOM_CELL_SIZE)

func _random_explorable_room(dungeon_layout: Array[Dictionary], exclude_start: bool = false) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for room_data in dungeon_layout:
		if room_data["is_special"]:
			continue
		if exclude_start and room_data["is_start"]:
			continue
		candidates.append(room_data)
	if candidates.is_empty():
		candidates = dungeon_layout
	return candidates[randi() % candidates.size()]

func _random_position_in_room(room_data: Dictionary) -> Vector2:
	var rect: Rect2 = _room_world_rect(room_data)
	return Vector2(
		rect.position.x + randf_range(ROOM_SPAWN_MARGIN, rect.size.x - ROOM_SPAWN_MARGIN),
		rect.position.y + randf_range(ROOM_SPAWN_MARGIN, rect.size.y - ROOM_SPAWN_MARGIN)
	)

func _generate_ingredient_pickups(dungeon_layout: Array[Dictionary]) -> Array[Dictionary]:
	var pickups: Array[Dictionary] = []
	for path in INGREDIENT_PATHS:
		var room_data: Dictionary = _random_explorable_room(dungeon_layout)
		pickups.append({"item_type": "ingredient", "item_resource_path": path, "position": _random_position_in_room(room_data)})
	return pickups

func _generate_weapon_part_pickups(dungeon_layout: Array[Dictionary]) -> Array[Dictionary]:
	var paths := WEAPON_PART_PATHS.duplicate()
	paths.shuffle()
	var pickups: Array[Dictionary] = []
	for path in paths:
		var room_data: Dictionary = _random_explorable_room(dungeon_layout)
		pickups.append({"item_type": "weapon_part", "item_resource_path": path, "position": _random_position_in_room(room_data)})
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
	# La salle de départ est toujours à la cellule de grille (0,0), donc
	# son centre monde est constant : pas besoin de connaître la layout ici.
	player.position = ROOM_CELL_SIZE / 2
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
