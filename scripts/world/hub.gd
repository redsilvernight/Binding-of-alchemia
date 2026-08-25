extends Room

@onready var players: Node2D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var HUD: Node2D = $HUD
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
@onready var _ambient_light: DirectionalLight2D = $AmbientLight
@onready var _run_start_station: Node2D = $RunStartStation
@onready var _arrival_portal: Node2D = $ArrivalPortal

const SHOP_LIGHT_COLOR: Color = Color(1.0, 0.78, 0.45)
const SHOP_LANTERN_SOURCE_ID: int = 1
const SHOP_LANTERN_ROW: int = 0
const SHOP_LANTERN_COLS: Array[int] = [7, 14]

const SHOP_SHELF_TEXTURE: Texture2D = preload("res://assets/tiles/hub_shop_shelf.png")
const SHOP_SHELF_POSITIONS: Array[Vector2] = [
	Vector2(128, 300), Vector2(128, 620),
	Vector2(1216, 300), Vector2(1216, 620),
]
var SHOP_SHELF_OCCLUSION_POLYGON: PackedVector2Array = PackedVector2Array([
	Vector2(-49.0, -76.0), Vector2(49.0, -75.0), Vector2(51.0, -70.0), Vector2(51.0, -65.0),
	Vector2(48.0, -63.0), Vector2(48.0, 16.0), Vector2(51.0, 22.0), Vector2(51.0, 28.0),
	Vector2(48.0, 30.0), Vector2(49.0, 74.0), Vector2(41.0, 75.0), Vector2(39.0, 70.0),
	Vector2(-40.0, 70.0), Vector2(-42.0, 75.0), Vector2(-50.0, 74.0), Vector2(-49.0, 30.0),
	Vector2(-52.0, 28.0), Vector2(-49.0, 16.0), Vector2(-49.0, -63.0), Vector2(-52.0, -65.0),
	Vector2(-50.0, -75.0),
])
var SHOP_SHELF_COLLISION_POLYGON: PackedVector2Array = PackedVector2Array([
	Vector2(-52.0, 28.0), Vector2(51.0, 28.0), Vector2(48.0, 30.0), Vector2(48.0, 75.0),
	Vector2(41.0, 75.0), Vector2(39.0, 70.0), Vector2(-40.0, 70.0), Vector2(-42.0, 75.0),
	Vector2(-49.0, 75.0), Vector2(-49.0, 30.0), Vector2(-51.0, 29.0),
])
var _shop_item_props: Dictionary = {}
var _shop_slot_assignment: Dictionary = {}
const SHOP_ITEM_SLOTS: Array[Vector2] = [
	Vector2(-28, -42), Vector2(-2, -42), Vector2(24, -42),
	Vector2(-30, 11), Vector2(0, 11), Vector2(26, 11),
]
const SHOP_SHELF_FRONT_Y: float = 90.0

const PORTAL_LIGHT_COLOR: Color = Color(0.55, 0.45, 0.95)
const PORTAL_LIGHT_OFFSET: Vector2 = Vector2(0, 80)
const ARRIVAL_PORTAL_LIGHT_COLOR: Color = Color(0.35, 0.85, 0.8)
const ARRIVAL_PORTAL_SCALE: float = 0.65
const ARRIVAL_PORTAL_LIGHT_OFFSET: Vector2 = Vector2(0, -52)


func _ready() -> void:
	_setup_shop_wall_lights()
	super._ready()
	set_open_sides([])
	_setup_shop_shelves()
	_setup_portal_glow()
	_setup_arrival_portal_glow()
	_setup_ambient_lighting()
	AudioManager.play_music("hub")
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	player_spawner.spawn_function = _spawn_player
	MetaProgression.shop_pool_changed.connect(_setup_shop_items)
	if multiplayer.is_server():
		player_spawner.spawn(NetworkManager.get_unique_id())
		MetaProgression.ensure_shop_pool()
		for peer_id in NetworkManager.get_peers():
			player_spawner.spawn(peer_id)
			MetaProgression._rpc_shop_pool.rpc_id(peer_id, MetaProgression.get_shop_pool())
		RunManager.hide_loading_screen()
	_setup_shop_items()


func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawn_player(id)
	player.instance_hud.connect(_hud_instance)
	player.enable_dungeon_camera_mode()
	player.disable_combat()
	if multiplayer.is_server():
		RunManager.restore_player_state.call_deferred(player)
	return player


func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)
		MetaProgression._rpc_currency_changed.rpc_id(peer_id, MetaProgression.get_currency())
		MetaProgression.ensure_shop_pool()
		MetaProgression._rpc_shop_pool.rpc_id(peer_id, MetaProgression.get_shop_pool())


func _setup_shop_wall_lights() -> void:
	var cells: Array = []
	var source_ids: Array = []
	for col in SHOP_LANTERN_COLS:
		cells.append(Vector2i(col, SHOP_LANTERN_ROW))
		source_ids.append(SHOP_LANTERN_SOURCE_ID)
	set_decor_props(cells, source_ids)
	set_wall_light(cells, SHOP_LIGHT_COLOR)


func _setup_shop_shelves() -> void:
	var occluder_polygon: OccluderPolygon2D = OccluderPolygon2D.new()
	occluder_polygon.polygon = SHOP_SHELF_OCCLUSION_POLYGON
	for pos in SHOP_SHELF_POSITIONS:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 0
		body.position = pos
		add_child(body)

		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = SHOP_SHELF_TEXTURE
		sprite.light_mask = 2
		body.add_child(sprite)

		var collision: CollisionPolygon2D = CollisionPolygon2D.new()
		collision.polygon = SHOP_SHELF_COLLISION_POLYGON
		body.add_child(collision)

		var occluder: LightOccluder2D = LightOccluder2D.new()
		occluder.occluder = occluder_polygon
		body.add_child(occluder)


func _setup_shop_items() -> void:
	var pool: Array = MetaProgression.get_shop_pool()
	var pool_set: Dictionary = {}
	for item_path in pool:
		pool_set[item_path] = true

	for item_path in _shop_item_props.keys():
		if not pool_set.has(item_path):
			var prop: Node2D = _shop_item_props[item_path]
			if is_instance_valid(prop):
				prop.queue_free()
			_shop_item_props.erase(item_path)
			_shop_slot_assignment.erase(item_path)

	for item_path in pool:
		if _shop_item_props.has(item_path):
			continue
		var slot_index: int = _next_free_shop_slot()
		if slot_index < 0:
			continue
		var entry: Dictionary = _find_unlockable_entry(item_path)
		if entry.is_empty():
			continue
		var prop: ShopItemProp = ShopItemProp.new()
		var slot_offset: Vector2 = SHOP_ITEM_SLOTS[slot_index % SHOP_ITEM_SLOTS.size()]
		var item_pos: Vector2 = SHOP_SHELF_POSITIONS[slot_index] + slot_offset
		var front_anchor: Vector2 = Vector2(item_pos.x, SHOP_SHELF_POSITIONS[slot_index].y + SHOP_SHELF_FRONT_Y)
		prop.setup(entry, front_anchor - item_pos, slot_offset)
		prop.position = item_pos
		add_child(prop)
		_shop_item_props[item_path] = prop
		_shop_slot_assignment[item_path] = slot_index


func _next_free_shop_slot() -> int:
	for slot_index in SHOP_SHELF_POSITIONS.size():
		if not _shop_slot_assignment.values().has(slot_index):
			return slot_index
	return -1


func _find_unlockable_entry(item_path: String) -> Dictionary:
	for entry in MetaProgression.UNLOCKABLES:
		if entry["item_path"] == item_path:
			return entry
	return {}


func _setup_portal_glow() -> void:
	var glow: WallLight = WallLight.new()
	glow.set_color(PORTAL_LIGHT_COLOR)
	glow.position = _run_start_station.position + PORTAL_LIGHT_OFFSET
	add_child(glow)


func _setup_arrival_portal_glow() -> void:
	var glow: WallLight = WallLight.new()
	glow.set_color(ARRIVAL_PORTAL_LIGHT_COLOR)
	glow.scale = Vector2.ONE * ARRIVAL_PORTAL_SCALE
	glow.position = _arrival_portal.position + ARRIVAL_PORTAL_LIGHT_OFFSET
	add_child(glow)


func _setup_ambient_lighting() -> void:
	_canvas_modulate.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _canvas_modulate.visible = enabled)
	_ambient_light.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _ambient_light.visible = enabled)
