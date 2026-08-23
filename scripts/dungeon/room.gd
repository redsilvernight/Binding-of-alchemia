class_name Room
extends Node2D


signal room_cleared
signal player_entered(player: Node2D)

const SIDES: Array[String] = ["north", "south", "east", "west"]
const SIDE_OFFSETS: Dictionary = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}
const OPPOSITE_SIDE: Dictionary = {
	"north": "south",
	"south": "north",
	"east": "west",
	"west": "east",
}

const ROOM_WIDTH_PX: int = 1344
const ROOM_HEIGHT_PX: int = 960
const DOOR_TILES: int = 5
const TILE_SIZE_PX: float = 64.0

@onready var _trigger: Area2D = $RoomTrigger
@onready var _floor: TileMapLayer = get_node_or_null("Floor")
@onready var _door_by_side: Dictionary = {
	"north": get_node_or_null("North/Door"),
	"south": get_node_or_null("South/Door"),
	"east": get_node_or_null("East/Door"),
	"west": get_node_or_null("West/Door"),
}

var grid_position: Vector2i = Vector2i.ZERO
var _open_sides: Array = []
var _locked: bool = false
var _alive_enemies: Array[Node] = []
var _enemies_activation_scheduled: bool = false
var _cols: int = 0
var _rows: int = 0
var _nav_region: NavigationRegion2D
var _props_decor: TileMapLayer
var _pending_decor_cells: Array = []
var _pending_decor_source_ids: Array = []
var _props_blocking: TileMapLayer
var _pending_blocking_cells: Array = []
var _pending_blocking_source_ids: Array = []
var _pending_wall_light_cells: Array = []
var _pending_wall_light_color: Color = Color.WHITE
var _wall_painter := WallTilePainter.new()


func _ready() -> void:
	y_sort_enabled = true
	_trigger.body_entered.connect(_on_trigger_body_entered)
	_paint_floor()
	_setup_props_decor_layer()
	_setup_props_blocking_layer()
	_setup_navigation()
	_setup_wall_light()


func set_floor_tileset(tile_set: TileSet) -> void:
	(get_node("Floor") as TileMapLayer).tile_set = tile_set


func _setup_navigation() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	_nav_region = NavigationRegion2D.new()
	_nav_region.y_sort_enabled = true
	add_child(_nav_region)
	move_child(_nav_region, 0)
	for layer in [_floor, _props_decor, _props_blocking]:
		if layer != null:
			remove_child(layer)
			_nav_region.add_child(layer)
	var nav_poly := NavigationPolygon.new()
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nav_poly.agent_radius = 34.0
	nav_poly.add_outline(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(ROOM_WIDTH_PX, 0.0),
		Vector2(ROOM_WIDTH_PX, ROOM_HEIGHT_PX),
		Vector2(0.0, ROOM_HEIGHT_PX),
	]))
	_nav_region.navigation_polygon = nav_poly


func _bake_navigation() -> void:
	if _nav_region == null:
		return
	_floor.update_internals()
	if _props_blocking != null:
		_props_blocking.update_internals()
	_nav_region.bake_navigation_polygon(true)


func set_decor_props(cells: Array, source_ids: Array) -> void:
	_pending_decor_cells = cells
	_pending_decor_source_ids = source_ids


func set_blocking_props(cells: Array, source_ids: Array) -> void:
	_pending_blocking_cells = cells
	_pending_blocking_source_ids = source_ids


func set_wall_light(cells: Array, color: Color) -> void:
	_pending_wall_light_cells = cells
	_pending_wall_light_color = color


func _setup_props_decor_layer() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	_props_decor = TileMapLayer.new()
	_props_decor.name = "PropsDecor"
	_props_decor.tile_set = _floor.tile_set
	add_child(_props_decor)
	for i in _pending_decor_cells.size():
		_props_decor.set_cell(_pending_decor_cells[i], _pending_decor_source_ids[i], Vector2i.ZERO)


func _setup_props_blocking_layer() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	_props_blocking = TileMapLayer.new()
	_props_blocking.name = "PropsBlocking"
	_props_blocking.tile_set = _floor.tile_set
	_props_blocking.light_mask = 2
	_props_blocking.y_sort_enabled = true
	add_child(_props_blocking)
	for i in _pending_blocking_cells.size():
		_props_blocking.set_cell(_pending_blocking_cells[i], _pending_blocking_source_ids[i], Vector2i.ZERO)


func _setup_wall_light() -> void:
	for cell in _pending_wall_light_cells:
		var light: WallLight = WallLight.new()
		light.set_color(_pending_wall_light_color)
		light.position = Vector2(cell) * TILE_SIZE_PX + Vector2.ONE * (TILE_SIZE_PX / 2.0)
		add_child(light)


func _paint_floor() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	var tile_size: Vector2i = _floor.tile_set.tile_size
	_cols = ceili(float(ROOM_WIDTH_PX) / tile_size.x)
	_rows = ceili(float(ROOM_HEIGHT_PX) / tile_size.y)
	_floor.position = Vector2.ZERO
	for x in range(_cols):
		for y in range(_rows):
			_floor.set_cell(Vector2i(x, y), 0, WallTilePainter.TILE_FLOOR)


func _paint_walls() -> void:
	if _floor == null or _floor.tile_set == null or _cols == 0:
		return
	var wall_cells: Dictionary = _wall_painter.compute_wall_cells(_cols, _rows, DOOR_TILES, _open_sides)
	for cell in wall_cells:
		_floor.set_cell(cell, 0, wall_cells[cell])


func set_open_sides(open_sides: Array) -> void:
	_open_sides = open_sides
	_paint_walls()
	_apply_walls()
	_bake_navigation()


func register_enemy(enemy: Node) -> void:
	_alive_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_registered_enemy_removed.bind(enemy))


func _on_registered_enemy_removed(enemy: Node) -> void:
	_alive_enemies.erase(enemy)
	if not multiplayer.is_server():
		return
	if _locked and _alive_enemies.is_empty():
		_rpc_set_locked.rpc(false)


func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	if not multiplayer.is_server():
		return
	player_entered.emit(body)
	_activate_enemies_delayed()
	if _locked or _alive_enemies.is_empty():
		return
	_rpc_set_locked.rpc(true)


func _activate_enemies_delayed() -> void:
	if _enemies_activation_scheduled or _alive_enemies.is_empty():
		return
	_enemies_activation_scheduled = true
	await get_tree().create_timer(1.0, false).timeout
	for enemy in _alive_enemies:
		if is_instance_valid(enemy):
			enemy.active = true


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_locked(locked: bool) -> void:
	_locked = locked
	_apply_walls()
	if not locked:
		room_cleared.emit()


func _apply_walls() -> void:
	for side in SIDES:
		var structurally_open: bool = side in _open_sides
		var door: Door = _door_by_side[side]
		if door != null:
			door.visible = structurally_open
		if structurally_open:
			_sync_shared_door(side)


func _sync_shared_door(side: String) -> void:
	var neighbor: Room = _find_neighbor_room(side)
	var combined_locked: bool = _locked or (neighbor != null and neighbor.is_locked())
	var effectively_open: bool = not combined_locked
	(_door_by_side[side] as Door).set_state(effectively_open)
	_set_door_gap_tiles(side, combined_locked)
	if neighbor == null:
		return
	var neighbor_door: Door = neighbor.get_door(OPPOSITE_SIDE[side])
	if neighbor_door != null:
		neighbor_door.set_state(effectively_open)
	neighbor._set_door_gap_tiles(OPPOSITE_SIDE[side], combined_locked)


func _find_neighbor_room(side: String) -> Room:
	var neighbor_cell: Vector2i = grid_position + SIDE_OFFSETS[side]
	for sibling in get_parent().get_children():
		if sibling != self and sibling is Room and (sibling as Room).grid_position == neighbor_cell:
			return sibling
	return null


func is_locked() -> bool:
	return _locked


func get_door(side: String) -> Door:
	return _door_by_side.get(side)


func _set_door_gap_tiles(side: String, locked: bool) -> void:
	if _floor == null or _floor.tile_set == null or _cols == 0:
		return
	var door_col_start: int = (_cols - DOOR_TILES) / 2
	var door_row_start: int = (_rows - DOOR_TILES) / 2
	for i in range(DOOR_TILES):
		var coords: Vector2i
		var atlas_coords: Vector2i
		match side:
			"north":
				coords = Vector2i(door_col_start + i, 0)
				atlas_coords = WallTilePainter.WANG_ATLAS_BY_CORNERS[WallTilePainter.NORTH_EDGE_INDEX] if locked else WallTilePainter.TILE_FLOOR
			"south":
				coords = Vector2i(door_col_start + i, _rows - 1)
				atlas_coords = WallTilePainter.WANG_ATLAS_BY_CORNERS[WallTilePainter.SOUTH_EDGE_INDEX] if locked else WallTilePainter.TILE_FLOOR
			"west":
				coords = Vector2i(0, door_row_start + i)
				atlas_coords = WallTilePainter.WANG_ATLAS_BY_CORNERS[WallTilePainter.WEST_EDGE_INDEX] if locked else WallTilePainter.TILE_FLOOR
			"east":
				coords = Vector2i(_cols - 1, door_row_start + i)
				atlas_coords = WallTilePainter.WANG_ATLAS_BY_CORNERS[WallTilePainter.EAST_EDGE_INDEX] if locked else WallTilePainter.TILE_FLOOR
			_:
				continue
		_floor.call_deferred("set_cell", coords, 0, atlas_coords)
