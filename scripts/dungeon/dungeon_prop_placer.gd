class_name DungeonPropPlacer
extends RefCounted


const PROP_DOOR_CLEARANCE: float = 160.0
const PROP_CENTER_CLEARANCE_RADIUS: float = 180.0
const PROP_PLACEMENT_ATTEMPTS: int = 20
const PROP_MIN_SPACING: float = 110.0
const ROOM_COLS: int = 21
const ROOM_ROWS: int = 15
const WALL_LIGHT_SIDES: Array[String] = ["north", "south"]
const WALL_LIGHT_TEXTURE_PATHS: Array[String] = [
	"res://assets/tiles/props/cristaux_lumineux.png",
	"res://assets/tiles/props/torche_murale.png",
	"res://assets/tiles/props/brasero_alchimique.png",
]

var _room_world_rect: Callable
var _random_position_in_room: Callable

func _init(room_world_rect_fn: Callable, random_position_in_room_fn: Callable) -> void:
	_room_world_rect = room_world_rect_fn
	_random_position_in_room = random_position_in_room_fn

func prop_tile_sources_by_texture(tile_set: TileSet) -> Dictionary:
	var decor: Dictionary = {}
	var blocking: Dictionary = {}
	for i in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(i)
		var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
		if tile_data == null:
			continue
		if tile_data.get_collision_polygons_count(0) > 0:
			blocking[source.texture.resource_path] = source_id
		else:
			decor[source.texture.resource_path] = source_id
	return {"decor": decor, "blocking": blocking}

func prepare_room_props(room_data: Dictionary, prop_table: SpawnTable, prop_tile_sources: Dictionary, pool_index: int, prop_spawner: MultiplayerSpawner) -> void:
	var decor_cells: Array[Vector2i] = []
	var decor_source_ids: Array[int] = []
	var blocking_cells: Array[Vector2i] = []
	var blocking_source_ids: Array[int] = []
	var wall_light_cells: Array[Vector2i] = []
	if not (room_data["is_start"] or room_data["is_boss"]):
		var room_origin: Vector2 = (_room_world_rect.call(room_data) as Rect2).position
		var placed_positions: Array[Vector2] = []
		for prop_path in prop_table.pick_many():
			var prop_position: Vector2 = _random_prop_position_in_room(room_data, placed_positions)
			placed_positions.append(prop_position)
			var local_pos: Vector2 = prop_position - room_origin
			var cell: Vector2i = Vector2i(floori(local_pos.x / Room.TILE_SIZE_PX), floori(local_pos.y / Room.TILE_SIZE_PX))
			if prop_tile_sources["blocking"].has(prop_path):
				blocking_cells.append(cell)
				blocking_source_ids.append(prop_tile_sources["blocking"][prop_path])
			elif prop_tile_sources["decor"].has(prop_path):
				decor_cells.append(cell)
				decor_source_ids.append(prop_tile_sources["decor"][prop_path])
			else:
				prop_spawner.spawn({
					"scene_path": prop_path,
					"position": prop_position,
				})
		var wall_light_source_id: int = prop_tile_sources["decor"][WALL_LIGHT_TEXTURE_PATHS[pool_index]]
		for side in WALL_LIGHT_SIDES:
			for cell in _wall_light_cell_for_side(room_data, side):
				wall_light_cells.append(cell)
				decor_cells.append(cell)
				decor_source_ids.append(wall_light_source_id)
	room_data["decor_cells"] = decor_cells
	room_data["decor_source_ids"] = decor_source_ids
	room_data["blocking_cells"] = blocking_cells
	room_data["blocking_source_ids"] = blocking_source_ids
	room_data["wall_light_cells"] = wall_light_cells

func _prop_exclusion_rects(room_data: Dictionary) -> Array[Rect2]:
	var rect: Rect2 = _room_world_rect.call(room_data)
	var door_span: float = Room.DOOR_TILES * Room.TILE_SIZE_PX
	var exclusions: Array[Rect2] = []
	for side in room_data["open_sides"]:
		match side:
			"north":
				exclusions.append(Rect2(rect.position.x + (rect.size.x - door_span) / 2.0, rect.position.y, door_span, PROP_DOOR_CLEARANCE))
			"south":
				exclusions.append(Rect2(rect.position.x + (rect.size.x - door_span) / 2.0, rect.end.y - PROP_DOOR_CLEARANCE, door_span, PROP_DOOR_CLEARANCE))
			"west":
				exclusions.append(Rect2(rect.position.x, rect.position.y + (rect.size.y - door_span) / 2.0, PROP_DOOR_CLEARANCE, door_span))
			"east":
				exclusions.append(Rect2(rect.end.x - PROP_DOOR_CLEARANCE, rect.position.y + (rect.size.y - door_span) / 2.0, PROP_DOOR_CLEARANCE, door_span))
	if room_data["is_special"] or room_data["is_treasure"]:
		var center: Vector2 = rect.get_center()
		exclusions.append(Rect2(center - Vector2.ONE * PROP_CENTER_CLEARANCE_RADIUS, Vector2.ONE * PROP_CENTER_CLEARANCE_RADIUS * 2.0))
	return exclusions

func _random_prop_position_in_room(room_data: Dictionary, placed_positions: Array[Vector2]) -> Vector2:
	var exclusions: Array[Rect2] = _prop_exclusion_rects(room_data)
	var candidate: Vector2 = _random_position_in_room.call(room_data)
	for attempt in PROP_PLACEMENT_ATTEMPTS:
		if _is_valid_prop_position(candidate, exclusions, placed_positions):
			return candidate
		candidate = _random_position_in_room.call(room_data)
	return candidate

func _is_valid_prop_position(candidate: Vector2, exclusions: Array[Rect2], placed_positions: Array[Vector2]) -> bool:
	for zone in exclusions:
		if zone.has_point(candidate):
			return false
	for other in placed_positions:
		if candidate.distance_to(other) < PROP_MIN_SPACING:
			return false
	return true

func _wall_light_cell_for_side(room_data: Dictionary, side: String) -> Array[Vector2i]:
	var door_col_start: int = (ROOM_COLS - Room.DOOR_TILES) / 2
	var door_col_end: int = door_col_start + Room.DOOR_TILES
	var open_here: bool = side in room_data["open_sides"]
	var y: int = 0 if side == "north" else ROOM_ROWS - 1
	var candidates: Array[Vector2i] = []
	for x in range(1, ROOM_COLS - 1):
		if open_here and x >= door_col_start - 1 and x <= door_col_end:
			continue
		candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return []
	return [candidates[randi() % candidates.size()]]
