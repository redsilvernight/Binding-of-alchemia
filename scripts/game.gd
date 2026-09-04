extends Control
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
@onready var _ambient_light: DirectionalLight2D = $AmbientLight
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
@onready var props: Node2D = $Props
@onready var prop_spawner: MultiplayerSpawner = $PropSpawner

const ROOM_CELL_SIZE: Vector2 = Vector2(1344, 960)
const BASE_ROOM_COUNT: int = 6
const ROOM_COUNT_PER_FLOOR: int = 1
const ROOM_COUNT_CAP: int = 12
const ROOM_TEMPLATE_PATHS: Array[String] = [
	"res://scenes/rooms/room_template_a.tscn",
	"res://scenes/rooms/room_template_b.tscn",
]
const SPECIAL_ROOM_TEMPLATE_PATHS: Array[String] = [
	"res://scenes/rooms/room_alchemy.tscn",
	"res://scenes/rooms/room_weapon.tscn",
]
const BOSS_ROOM_TEMPLATE_PATH: String = "res://scenes/rooms/boss_room.tscn"
const TREASURE_ROOM_TEMPLATE_PATH: String = "res://scenes/rooms/room_treasure.tscn"
const BOSS_SCENE_PATH: String = "res://scenes/enemies/boss_01.tscn"
const BOSS_HEALTHBAR_SCENE_PATH: String = "res://scenes/ui/boss_healthbar.tscn"
const RUN_SUMMARY_PANEL_SCENE_PATH: String = "res://scenes/ui/run_summary_panel.tscn"
const BOSS_DEFEAT_TO_HUB_DELAY: float = 2.5

const ENEMY_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/enemies_normal.tres"
const INGREDIENT_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/ingredients.tres"
const WEAPON_PART_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/weapon_parts.tres"
const INGREDIENT_CARRIER_RATIO_CAP: float = 0.5
const ROOM_SPAWN_MARGIN: float = 80.0
const ENEMY_EXTRA_ROLL_FLOORS: int = 2
const DOOR_SPAWN_EXCLUSION_DEPTH: float = 192.0
const DOOR_SPAWN_EXCLUSION_LATERAL_PADDING: float = 64.0
const DOOR_SPAWN_EXCLUSION_MAX_ATTEMPTS: int = 20

const POOL_COUNT: int = 3
const PROP_SPAWN_TABLE_PATHS: Array[String] = [
	"res://resources/spawn_tables/props_pool_a.tres",
	"res://resources/spawn_tables/props_pool_b.tres",
	"res://resources/spawn_tables/props_pool_c.tres",
]
const ROOM_TILESET_PATHS: Array[String] = [
	"res://resources/tilesets/dungeon_cave_terrain.tres",
	"res://resources/tilesets/dungeon_crypt_terrain.tres",
	"res://resources/tilesets/dungeon_alchemy_terrain.tres",
]
const ROOM_AMBIENT_COLORS: Array[Color] = [
	Color(0.62, 0.7, 0.8, 1.0),
	Color(0.68, 0.74, 0.64, 1.0),
	Color(0.76, 0.66, 0.85, 1.0),
]
const AMBIENT_LIGHT_COLORS: Array[Color] = [
	Color(0.4, 0.65, 0.9, 1.0),
	Color(0.55, 0.7, 0.45, 1.0),
	Color(0.7, 0.4, 0.9, 1.0),
]
const AMBIENT_LIGHT_ENERGY: float = 0.35
const MUSIC_KEYS: Array[String] = [
	"cave",
	"crypt",
	"alchemy",
]

signal dungeon_map_changed
var dungeon_map: Dictionary = {}

var current_boss: Node = null

var _prop_placer: DungeonPropPlacer
var _loot_roller: LootRoller

const SCENE_READY_TIMEOUT: float = 5.0
const SCENE_READY_POLL_INTERVAL: float = 0.1
var _peers_ready_for_dungeon: Dictionary = {}

var _run_summary_shown: bool = false
var _scene_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("Game")
	_canvas_modulate.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _canvas_modulate.visible = enabled)
	_ambient_light.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _ambient_light.visible = enabled)
	var pool_index_ambient: int = _pool_index_for_floor(RunManager.current_floor)
	_canvas_modulate.color = ROOM_AMBIENT_COLORS[pool_index_ambient]
	_ambient_light.color = AMBIENT_LIGHT_COLORS[pool_index_ambient]
	_ambient_light.energy = AMBIENT_LIGHT_ENERGY
	AudioManager.play_music(MUSIC_KEYS[pool_index_ambient])
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	_prop_placer = DungeonPropPlacer.new(_room_world_rect, _random_position_in_room)
	_loot_roller = LootRoller.new()
	room_spawner.spawn_function = _spawn_room
	projectile_spawner.spawn_function = _spawn_bullet
	enemy_spawner.spawn_function = _spawn_enemy
	player_spawner.spawn_function = _spawn_player
	pickup_spawner.spawn_function = _spawn_pickup
	prop_spawner.spawn_function = _spawn_prop

	if multiplayer.is_server():
		await _wait_for_connected_peers_ready()
		_generate_dungeon()
	else:
		notify_scene_ready.rpc_id(1)


func _wait_for_connected_peers_ready() -> void:
	var expected_peers: PackedInt32Array = NetworkManager.get_peers()
	if expected_peers.is_empty():
		return
	var elapsed: float = 0.0
	while elapsed < SCENE_READY_TIMEOUT:
		var all_ready: bool = true
		for peer_id in expected_peers:
			if not _peers_ready_for_dungeon.has(peer_id):
				all_ready = false
				break
		if all_ready:
			return
		await get_tree().create_timer(SCENE_READY_POLL_INTERVAL).timeout
		elapsed += SCENE_READY_POLL_INTERVAL


@rpc("any_peer", "call_local", "reliable")
func notify_scene_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_unique_id()
	_peers_ready_for_dungeon[sender_id] = true


func _generate_dungeon() -> void:
	var floor_level: int = RunManager.current_floor
	var room_count: int = _room_count_for_floor(floor_level)
	var dungeon_layout: Array[Dictionary] = DungeonGenerator.generate(room_count, ROOM_TEMPLATE_PATHS, _special_room_template_for_floor(floor_level), BOSS_ROOM_TEMPLATE_PATH, TREASURE_ROOM_TEMPLATE_PATH)
	var pool_index: int = _pool_index_for_floor(floor_level)
	var prop_table: SpawnTable = load(PROP_SPAWN_TABLE_PATHS[pool_index]) as SpawnTable
	var room_tile_set: TileSet = load(ROOM_TILESET_PATHS[pool_index]) as TileSet
	var prop_tile_sources: Dictionary = _prop_placer.prop_tile_sources_by_texture(room_tile_set)
	var room_nodes: Dictionary = {}
	for room_data in dungeon_layout:
		_prop_placer.prepare_room_props(room_data, prop_table, prop_tile_sources, pool_index, prop_spawner)
		var room: Room = room_spawner.spawn(room_data)
		room_nodes[room_data["grid_position"]] = room

	player_spawner.spawn(NetworkManager.get_unique_id())
	for peer_id in NetworkManager.get_peers():
		player_spawner.spawn(peer_id)

	var enemy_table: SpawnTable = load(ENEMY_SPAWN_TABLE_PATH) as SpawnTable
	for entry in enemy_table.available_entries(floor_level):
		_load_scene(entry.item_path)
	var extra_enemy_rolls: int = _extra_enemy_rolls_for_floor(floor_level)
	var floor_enemies: Array[Node] = []
	for room_data in dungeon_layout:
		if room_data["is_special"] or room_data["is_start"] or room_data["is_boss"] or room_data["is_treasure"]:
			continue
		var room: Room = room_nodes[room_data["grid_position"]]
		var enemy_paths: Array[String] = enemy_table.pick_many(floor_level)
		for i in extra_enemy_rolls:
			var extra_path: String = enemy_table.pick_one(floor_level)
			if extra_path != "":
				enemy_paths.append(extra_path)
		for enemy_scene_path in enemy_paths:
			var enemy: Node = enemy_spawner.spawn({
				"scene_path": enemy_scene_path,
				"position": _random_position_in_room(room_data),
			})
			room.register_enemy(enemy)
			enemy.origin_room = room
			floor_enemies.append(enemy)

	var ingredient_table: SpawnTable = load(INGREDIENT_SPAWN_TABLE_PATH) as SpawnTable
	var ingredient_paths: Array[String] = ingredient_table.pick_many()
	floor_enemies.shuffle()
	var max_carriers: int = int(floor_enemies.size() * INGREDIENT_CARRIER_RATIO_CAP)
	for i in mini(ingredient_paths.size(), max_carriers):
		floor_enemies[i].carries_ingredient_path = ingredient_paths[i]

	for room_data in dungeon_layout:
		if not room_data["is_boss"]:
			continue
		var boss_room: Room = room_nodes[room_data["grid_position"]]
		var boss: Node = enemy_spawner.spawn({
			"scene_path": BOSS_SCENE_PATH,
			"position": _room_world_rect(room_data).get_center(),
		})
		boss_room.register_enemy(boss)
		current_boss = boss
		boss.tree_exiting.connect(func(): current_boss = null)
		boss.died.connect(_on_boss_defeated)
		break

	for room_data in dungeon_layout:
		if not room_data["is_treasure"]:
			continue
		var treasure_room: Room = room_nodes[room_data["grid_position"]]
		var chest: Node = treasure_room.get_node("Chest")
		chest.set_contents(_loot_roller.roll_chest_contents(room_data, _room_world_rect(room_data), ENEMY_SPAWN_TABLE_PATH, WEAPON_PART_SPAWN_TABLE_PATH))
		break

	RunManager.hide_loading_screen()

func _spawn_room(data: Dictionary) -> Node:
	var room: Room = (load(data["template_path"]) as PackedScene).instantiate()
	room.position = Vector2(data["grid_position"]) * ROOM_CELL_SIZE
	room.grid_position = data["grid_position"]
	room.set_floor_tileset(load(ROOM_TILESET_PATHS[_pool_index_for_floor(RunManager.current_floor)]))
	room.set_decor_props(data["decor_cells"], data["decor_source_ids"])
	room.set_blocking_props(data["blocking_cells"], data["blocking_source_ids"])
	room.set_wall_light(data["wall_light_cells"], AMBIENT_LIGHT_COLORS[_pool_index_for_floor(RunManager.current_floor)])
	room.set_open_sides.call_deferred(data["open_sides"])
	room.player_entered.connect(_on_room_player_entered.bind(data["grid_position"]))
	_register_room_in_map(data)
	return room

func _register_room_in_map(data: Dictionary) -> void:
	dungeon_map[data["grid_position"]] = {
		"is_start": data["is_start"],
		"is_special": data["is_special"],
		"is_boss": data["is_boss"],
		"is_treasure": data["is_treasure"],
		"open_sides": data["open_sides"],
		"visited": data["is_start"],
	}
	dungeon_map_changed.emit()

func _on_room_player_entered(player: Node2D, grid_position: Vector2i) -> void:
	_rpc_mark_room_visited.rpc(grid_position)
	_teleport_party_to_room(player, grid_position)

func _teleport_party_to_room(entering_player: Node2D, grid_position: Vector2i) -> void:
	var room_rect: Rect2 = _room_world_rect({"grid_position": grid_position})
	var target_position: Vector2 = entering_player.position
	for player in get_tree().get_nodes_in_group("Players"):
		if player == entering_player:
			continue
		if room_rect.has_point(player.position):
			continue
		if player.is_multiplayer_authority():
			player.position = target_position
		else:
			player.teleport.rpc_id(int(player.name), target_position)

@rpc("authority", "call_local", "reliable")
func _rpc_mark_room_visited(grid_position: Vector2i) -> void:
	if not dungeon_map.has(grid_position) or dungeon_map[grid_position]["visited"]:
		return
	dungeon_map[grid_position]["visited"] = true
	dungeon_map_changed.emit()
	if dungeon_map[grid_position]["is_boss"]:
		AudioManager.play_music("boss")

func _room_world_rect(room_data: Dictionary) -> Rect2:
	return Rect2(Vector2(room_data["grid_position"]) * ROOM_CELL_SIZE, ROOM_CELL_SIZE)

func _random_position_in_room(room_data: Dictionary) -> Vector2:
	var rect: Rect2 = _room_world_rect(room_data)
	var exclusion_zones: Array[Rect2] = _door_spawn_exclusion_zones(room_data)
	var position: Vector2 = Vector2.ZERO
	for attempt in DOOR_SPAWN_EXCLUSION_MAX_ATTEMPTS:
		position = Vector2(
			rect.position.x + randf_range(ROOM_SPAWN_MARGIN, rect.size.x - ROOM_SPAWN_MARGIN),
			rect.position.y + randf_range(ROOM_SPAWN_MARGIN, rect.size.y - ROOM_SPAWN_MARGIN)
		)
		var blocked: bool = false
		for zone in exclusion_zones:
			if zone.has_point(position):
				blocked = true
				break
		if not blocked:
			break
	return position

func _door_spawn_exclusion_zones(room_data: Dictionary) -> Array[Rect2]:
	var rect: Rect2 = _room_world_rect(room_data)
	var half_width: float = Room.DOOR_TILES * Room.TILE_SIZE_PX / 2.0 + DOOR_SPAWN_EXCLUSION_LATERAL_PADDING
	var zones: Array[Rect2] = []
	for side in room_data["open_sides"]:
		match side:
			"north":
				zones.append(Rect2(rect.position.x + rect.size.x / 2.0 - half_width, rect.position.y, half_width * 2.0, DOOR_SPAWN_EXCLUSION_DEPTH))
			"south":
				zones.append(Rect2(rect.position.x + rect.size.x / 2.0 - half_width, rect.position.y + rect.size.y - DOOR_SPAWN_EXCLUSION_DEPTH, half_width * 2.0, DOOR_SPAWN_EXCLUSION_DEPTH))
			"west":
				zones.append(Rect2(rect.position.x, rect.position.y + rect.size.y / 2.0 - half_width, DOOR_SPAWN_EXCLUSION_DEPTH, half_width * 2.0))
			"east":
				zones.append(Rect2(rect.position.x + rect.size.x - DOOR_SPAWN_EXCLUSION_DEPTH, rect.position.y + rect.size.y / 2.0 - half_width, DOOR_SPAWN_EXCLUSION_DEPTH, half_width * 2.0))
	return zones


func request_enemy_drop(position: Vector2, item_resource_path: String) -> void:
	if multiplayer.is_server():
		pickup_spawner.spawn.call_deferred({
			"item_type": "ingredient",
			"item_resource_path": item_resource_path,
			"position": position,
		})

func request_currency_drop(position: Vector2, amount: int) -> void:
	if not multiplayer.is_server():
		return
	for coin_position in _loot_roller.currency_coin_positions(amount, position):
		pickup_spawner.spawn.call_deferred({
			"item_type": "currency",
			"currency_amount": LootRoller.CURRENCY_PER_COIN,
			"position": coin_position,
		})

func request_enemy_split(scene_path: String, origin_position: Vector2, count: int, spawn_radius: float, room: Room) -> void:
	if not multiplayer.is_server():
		return
	_deferred_enemy_split.call_deferred(scene_path, origin_position, count, spawn_radius, room)

func _deferred_enemy_split(scene_path: String, origin_position: Vector2, count: int, spawn_radius: float, room: Room) -> void:
	for i in count:
		var offset: Vector2 = Vector2.RIGHT.rotated(TAU * i / count) * spawn_radius
		var shard: Node = enemy_spawner.spawn({
			"scene_path": scene_path,
			"position": origin_position + offset,
		})
		shard.origin_room = room
		if room != null:
			room.register_enemy(shard)
		shard.rpc("_rpc_reveal")
		shard.active = true

func request_open_chest(contents: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	if contents.get("is_trap", false):
		var enemy_path: String = contents.get("enemy_scene_path", "")
		if enemy_path != "":
			var enemy: Node = enemy_spawner.spawn({"scene_path": enemy_path, "position": contents["position"]})
			enemy.active = true
		return

	var weapon_part_path: String = contents.get("weapon_part_path", "")
	if weapon_part_path != "":
		pickup_spawner.spawn({
			"item_type": "weapon_part",
			"item_resource_path": weapon_part_path,
			"position": contents["position"],
		})

	var currency: int = contents.get("currency", 0)
	for coin_position in _loot_roller.currency_coin_positions(currency, contents["position"] as Vector2):
		pickup_spawner.spawn({
			"item_type": "currency",
			"currency_amount": LootRoller.CURRENCY_PER_COIN,
			"position": coin_position,
		})

func _spawn_pickup(data: Dictionary) -> Node:
	var scene_path: String
	match data["item_type"]:
		"ingredient":
			scene_path = "res://scenes/items/ingredient_pickup.tscn"
		"weapon_part":
			scene_path = "res://scenes/items/weapon_part_pickup.tscn"
		"currency":
			scene_path = "res://scenes/items/currency_pickup.tscn"
	var pickup: Pickup = (load(scene_path) as PackedScene).instantiate()
	pickup.position = data["position"]
	pickup.item_type = data["item_type"]
	if data["item_type"] == "currency":
		pickup.currency_amount = data["currency_amount"]
	else:
		pickup.item_resource = load(data["item_resource_path"])
	return pickup

func _spawn_prop(data: Dictionary) -> Node:
	var prop: Node2D = (load(data["scene_path"]) as PackedScene).instantiate()
	prop.position = data["position"]
	return prop

func _spawn_player(id: int) -> Node:
	var player: Node = PlayerManager.spawn_player(id)
	player.position = ROOM_CELL_SIZE / 2
	player.enable_dungeon_camera_mode()
	player.instance_hud.connect(_hud_instance)
	player.instance_projectile.connect(_on_projectile_requested)
	if multiplayer.is_server():
		player.died.connect(_check_all_players_dead)
		RunManager.restore_player_state.call_deferred(player)
	return player

func _spawn_bullet(data: Dictionary) -> Node:
	var scene_path: String = data.get("scene_path", "res://scenes/projectiles/bullet_water.tscn")
	var bullet: Bullet = (load(scene_path) as PackedScene).instantiate()
	bullet.setup(data["damage"], data["speed"], data["lifetime"], data["trajectory"])
	bullet.shooter_id = data.get("shooter_id", 0)
	bullet.set_bounce(data.get("bounce_count", 0))
	if scene_path == Weapon.MIXTURE_BULLET_SCENE:
		bullet.impact_sfx_key = "impact_mixture"
	elif scene_path.begins_with("res://scenes/enemies/enemy_projectile"):
		AudioManager.play_sfx_at(data.get("attack_sfx_key", "enemy_attack_ranged"), data["from_position"])
	if data.has("impact_effect_data"):
		var effect: ImpactEffect = ImpactEffect.from_dict(data["impact_effect_data"])
		bullet.set_impact_effect(effect)
	bullet.launch.call_deferred(data["from_position"], data["direction"])
	return bullet

func _spawn_enemy(data: Dictionary) -> Node:
	var enemy: Node = _load_scene(data["scene_path"]).instantiate()
	enemy.position = data["position"]
	if data["scene_path"] == BOSS_SCENE_PATH:
		var healthbar: Node = _load_scene(BOSS_HEALTHBAR_SCENE_PATH).instantiate()
		HUD.add_child(healthbar)
		healthbar.bind_boss(enemy)
	return enemy

func _load_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) as PackedScene
	return _scene_cache[path]

func _on_peer_disconnected(peer_id) -> void:
	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()
	_check_all_players_dead.call_deferred()

func _check_all_players_dead() -> void:
	if not multiplayer.is_server():
		return
	var active_players: Array = get_tree().get_nodes_in_group("Players")
	if active_players.is_empty():
		return
	if _run_summary_shown:
		return
	for player in active_players:
		if not player.is_dead:
			return
	_run_summary_shown = true
	var final_currency: int = MetaProgression.get_currency()
	_show_run_summary.rpc(final_currency)
	MetaProgression.reset_currency()

@rpc("authority", "call_local", "reliable")
func _show_run_summary(final_currency: int) -> void:
	var panel: Node = (load(RUN_SUMMARY_PANEL_SCENE_PATH) as PackedScene).instantiate()
	HUD.add_child(panel)
	panel.show_summary(get_tree().get_nodes_in_group("Players"), final_currency)

func _on_boss_defeated() -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		RunManager.save_run_state(int(player.name), _capture_run_state(player))
	RunManager.advance_floor()
	get_tree().create_timer(BOSS_DEFEAT_TO_HUB_DELAY, false).timeout.connect(RunManager.end_run)

func _capture_run_state(player: Node) -> Dictionary:
	return {
		"ingredients": player.inventory.ingredients.duplicate(),
		"weapon_part_paths": player.inventory.weapon_parts.map(func(part: Resource) -> String: return part.resource_path),
		"mixture_impact_effect": player.weapon.mixture_impact_effect,
		"mixture_ingredient_paths": player.weapon.mixture_ingredient_paths.duplicate(),
		"equipped_water_barrel_path": player.weapon.barrel_water.resource_path if player.weapon.barrel_water else "",
		"equipped_mixture_barrel_path": player.weapon.barrel_mixture.resource_path if player.weapon.barrel_mixture else "",
		"equipped_tank_path": player.weapon.tank.resource_path if player.weapon.tank else "",
		"equipped_core_path": player.weapon.core.resource_path if player.weapon.core else "",
	}


func _room_count_for_floor(floor_level: int) -> int:
	return mini(BASE_ROOM_COUNT + (floor_level - 1) * ROOM_COUNT_PER_FLOOR, ROOM_COUNT_CAP)


func _extra_enemy_rolls_for_floor(floor_level: int) -> int:
	return (floor_level - 1) / ENEMY_EXTRA_ROLL_FLOORS


func _special_room_template_for_floor(floor_level: int) -> Array[String]:
	var index: int = (floor_level - 1) % SPECIAL_ROOM_TEMPLATE_PATHS.size()
	var result: Array[String] = [SPECIAL_ROOM_TEMPLATE_PATHS[index]]
	return result


func _pool_index_for_floor(floor_level: int) -> int:
	return (floor_level - 1) % POOL_COUNT

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)
		if is_instance_valid(current_boss):
			current_boss._update_health.rpc_id(peer_id, current_boss.max_lifepoint, current_boss.lifepoint)

func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)

func _on_projectile_requested(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)

func request_enemy_projectile(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)
