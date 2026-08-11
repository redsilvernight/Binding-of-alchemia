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

# Phase 6.3 : QUOI/COMBIEN spawn vient de ces tables pondérées (voir
# scripts/dungeon/spawn_table.gd), le OÙ reste une position aléatoire dans
# la salle (_random_position_in_room) — pas de Marker2D dédiés tant qu'un
# seul type d'ennemi et un placement uniforme suffisent.
const ENEMY_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/enemies_normal.tres"
const INGREDIENT_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/ingredients.tres"
const WEAPON_PART_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/weapon_parts.tres"
const ROOM_SPAWN_MARGIN: float = 80.0

# Phase 6.4 : carte du donjon pour la mini-map (scripts/ui/minimap.gd). Toutes
# les salles y sont enregistrées dès leur spawn (_spawn_room tourne sur
# chaque pair avec les mêmes données répliquées par le RoomSpawner, donc ce
# dictionnaire est identique partout sans RPC dédié). Seul "visited" change
# après coup, et seul l'hôte décide quand — répliqué via _rpc_mark_room_visited,
# même pattern que Room._rpc_set_locked.
signal dungeon_map_changed
var dungeon_map: Dictionary = {} # Vector2i (grid_position) -> {is_start, is_special, open_sides, visited}

func _ready() -> void:
	add_to_group("Game")
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	room_spawner.spawn_function = _spawn_room
	projectile_spawner.spawn_function = _spawn_bullet
	enemy_spawner.spawn_function = _spawn_enemy
	player_spawner.spawn_function = _spawn_player
	pickup_spawner.spawn_function = _spawn_pickup

	if multiplayer.is_server():
		var dungeon_layout: Array[Dictionary] = DungeonGenerator.generate(DUNGEON_ROOM_COUNT, ROOM_TEMPLATE_PATHS, SPECIAL_ROOM_TEMPLATE_PATHS)
		var room_nodes: Dictionary = {} # Vector2i (grid_position) -> Room
		for room_data in dungeon_layout:
			var room: Room = room_spawner.spawn(room_data)
			room_nodes[room_data["grid_position"]] = room

		player_spawner.spawn(NetworkManager.get_unique_id())

		var enemy_table: SpawnTable = load(ENEMY_SPAWN_TABLE_PATH) as SpawnTable
		for room_data in dungeon_layout:
			if room_data["is_special"] or room_data["is_start"]:
				continue
			var room: Room = room_nodes[room_data["grid_position"]]
			for enemy_scene_path in enemy_table.pick_many():
				var enemy: Node = enemy_spawner.spawn({
					"scene_path": enemy_scene_path,
					"position": _random_position_in_room(room_data),
				})
				room.register_enemy(enemy)

		var ingredient_table: SpawnTable = load(INGREDIENT_SPAWN_TABLE_PATH) as SpawnTable
		for pickup_data in _generate_pickups_from_table(ingredient_table, "ingredient", dungeon_layout, false):
			pickup_spawner.spawn(pickup_data)
		var weapon_part_table: SpawnTable = load(WEAPON_PART_SPAWN_TABLE_PATH) as SpawnTable
		for pickup_data in _generate_pickups_from_table(weapon_part_table, "weapon_part", dungeon_layout, true):
			pickup_spawner.spawn(pickup_data)

func _spawn_room(data: Dictionary) -> Node:
	var room: Room = (load(data["template_path"]) as PackedScene).instantiate()
	room.position = Vector2(data["grid_position"]) * ROOM_CELL_SIZE
	# set_open_sides() lit des noeuds enfants via @onready : le noeud doit
	# être entré dans l'arbre (donc _ready() déjà passé) avant qu'on
	# l'appelle, sans quoi les références sont encore nulles (même piège
	# documenté pour launch() en Phase 3.5).
	room.set_open_sides.call_deferred(data["open_sides"])
	room.player_entered.connect(_on_room_player_entered.bind(data["grid_position"]))
	_register_room_in_map(data)
	return room

func _register_room_in_map(data: Dictionary) -> void:
	dungeon_map[data["grid_position"]] = {
		"is_start": data["is_start"],
		"is_special": data["is_special"],
		"open_sides": data["open_sides"],
		"visited": data["is_start"], # la salle de départ est toujours déjà "découverte"
	}
	dungeon_map_changed.emit()

## Ne s'exécute jamais côté client : Room.player_entered n'est émis que
## lorsque la salle hôte détecte l'entrée (cf. room.gd, garde is_server()
## avant l'émission) — pas besoin de re-vérifier ici.
func _on_room_player_entered(grid_position: Vector2i) -> void:
	_rpc_mark_room_visited.rpc(grid_position)

@rpc("authority", "call_local", "reliable")
func _rpc_mark_room_visited(grid_position: Vector2i) -> void:
	if not dungeon_map.has(grid_position) or dungeon_map[grid_position]["visited"]:
		return
	dungeon_map[grid_position]["visited"] = true
	dungeon_map_changed.emit()

func _room_world_rect(room_data: Dictionary) -> Rect2:
	return Rect2(Vector2(room_data["grid_position"]) * ROOM_CELL_SIZE, ROOM_CELL_SIZE)

func _random_explorable_room(dungeon_layout: Array[Dictionary]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for room_data in dungeon_layout:
		if room_data["is_special"]:
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

## unique = true : chaque entrée de la table apparaît exactement une fois
## (garantit la couverture complète d'un pool, ex : une pièce d'arme de
## chaque catégorie). unique = false : tirage pondéré avec remise sur
## min_count..max_count de la table (rareté relative, doublons possibles).
func _generate_pickups_from_table(table: SpawnTable, item_type: String, dungeon_layout: Array[Dictionary], unique: bool) -> Array[Dictionary]:
	var paths: Array[String] = table.pick_all_shuffled() if unique else table.pick_many()
	var pickups: Array[Dictionary] = []
	for path in paths:
		var room_data: Dictionary = _random_explorable_room(dungeon_layout)
		pickups.append({"item_type": item_type, "item_resource_path": path, "position": _random_position_in_room(room_data)})
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

## scene_path optionnel (Phase 7.3) : les projectiles ennemis (voir
## enemy_ranged.gd) passent leur propre scène (layer/mask pour toucher les
## joueurs, pas les ennemis) ; sans cette clé, comportement identique à avant
## (balle du joueur).
func _spawn_bullet(data: Dictionary) -> Node:
	var scene_path: String = data.get("scene_path", "res://scenes/projectiles/bullet.tscn")
	var bullet: Bullet = (load(scene_path) as PackedScene).instantiate()
	bullet.setup(data["damage"], data["speed"], data["lifetime"], data["trajectory"])
	if data.has("impact_effect_data"):
		var effect: ImpactEffect = ImpactEffect.from_dict(data["impact_effect_data"])
		bullet.set_impact_effect(effect)
	bullet.launch.call_deferred(data["from_position"], data["direction"])
	return bullet

func _spawn_enemy(data: Dictionary) -> Node:
	var enemy: Node = (load(data["scene_path"]) as PackedScene).instantiate()
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

## Même pipeline que _on_projectile_requested, mais appelé directement par un
## script d'ennemi (EnemyStateRangedAttack via enemy_ranged.gd.fire_at) plutôt
## que déclenché par un signal joueur.
func request_enemy_projectile(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)
