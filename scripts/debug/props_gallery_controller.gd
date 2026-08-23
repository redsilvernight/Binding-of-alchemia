extends Node2D

const PROPS_TEXTURE_DIR := "res://assets/tiles/props/"
const SLOT_CELLS := 4
const COLS_PER_THEME := 3
const GRID_OFFSET_COL := 5
const GRID_OFFSET_ROW := 2
const DOOR_SCENE_PATH := "res://scenes/rooms/door.tscn"
const AMBIENT_COLOR := Color(0.75, 0.73, 0.8, 1.0)
const AMBIENT_LIGHT_ENERGY := 0.35
const THEMES := [
	{
		"label": "Cave",
		"tileset_path": "res://resources/tilesets/dungeon_cave_terrain.tres",
		"wall_light_path": "res://assets/tiles/props/cristaux_lumineux.png",
		"light_color": Color(0.4, 0.65, 0.9, 1.0),
	},
	{
		"label": "Crypte",
		"tileset_path": "res://resources/tilesets/dungeon_crypt_terrain.tres",
		"wall_light_path": "res://assets/tiles/props/torche_murale.png",
		"light_color": Color(0.55, 0.7, 0.45, 1.0),
	},
	{
		"label": "Alchimie",
		"tileset_path": "res://resources/tilesets/dungeon_alchemy_terrain.tres",
		"wall_light_path": "res://assets/tiles/props/brasero_alchimique.png",
		"light_color": Color(0.7, 0.4, 0.9, 1.0),
	},
]

var _prop_count: int = 0


func _ready() -> void:
	y_sort_enabled = true
	_build_ambient_lighting()
	_build_rooms()

	var players := Node2D.new()
	players.name = "Players"
	players.y_sort_enabled = true
	add_child(players)
	var hud_layer := Node2D.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	_spawn_player(Vector2(Room.ROOM_WIDTH_PX / 2.0, 150.0), players, hud_layer)

	_build_instructions_label()


func _build_ambient_lighting() -> void:
	var canvas_modulate := CanvasModulate.new()
	canvas_modulate.color = AMBIENT_COLOR
	add_child(canvas_modulate)

	var ambient_light := DirectionalLight2D.new()
	ambient_light.energy = AMBIENT_LIGHT_ENERGY
	ambient_light.shadow_enabled = false
	add_child(ambient_light)


func _build_rooms() -> void:
	for i in THEMES.size():
		var theme: Dictionary = THEMES[i]
		var tile_set: TileSet = load(theme["tileset_path"])
		var prop_sources := _prop_sources(tile_set)
		_prop_count += prop_sources.size()

		var room := _build_theme_room(theme, tile_set, prop_sources)
		room.position = Vector2(0.0, i * Room.ROOM_HEIGHT_PX)
		room.grid_position = Vector2i(0, i)
		add_child(room)

		var open_sides: Array[String] = []
		if i > 0:
			open_sides.append("north")
		if i < THEMES.size() - 1:
			open_sides.append("south")
		room.set_open_sides.call_deferred(open_sides)


func _build_theme_room(theme: Dictionary, tile_set: TileSet, prop_sources: Array[Dictionary]) -> Room:
	var room := Room.new()
	room.name = "Room" + theme["label"]

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floor"
	room.add_child(floor_layer)

	var trigger := Area2D.new()
	trigger.name = "RoomTrigger"
	room.add_child(trigger)

	_add_door(room, "North", Vector2(Room.ROOM_WIDTH_PX / 2.0, 0.0))
	_add_door(room, "South", Vector2(Room.ROOM_WIDTH_PX / 2.0, Room.ROOM_HEIGHT_PX))

	room.set_floor_tileset(tile_set)

	var decor_cells: Array[Vector2i] = []
	var decor_source_ids: Array[int] = []
	var blocking_cells: Array[Vector2i] = []
	var blocking_source_ids: Array[int] = []
	var wall_light_cells: Array[Vector2i] = []

	var col := 0
	var row := 0
	for prop_source in prop_sources:
		var cell := Vector2i(
			GRID_OFFSET_COL + col * SLOT_CELLS,
			GRID_OFFSET_ROW + row * SLOT_CELLS
		)
		if prop_source["blocking"]:
			blocking_cells.append(cell)
			blocking_source_ids.append(prop_source["source_id"])
		else:
			decor_cells.append(cell)
			decor_source_ids.append(prop_source["source_id"])
		if prop_source["texture_path"] == theme["wall_light_path"]:
			wall_light_cells.append(cell)
		_add_prop_label(room, prop_source["name"], cell)
		col += 1
		if col >= COLS_PER_THEME:
			col = 0
			row += 1

	room.set_decor_props(decor_cells, decor_source_ids)
	room.set_blocking_props(blocking_cells, blocking_source_ids)
	room.set_wall_light(wall_light_cells, theme["light_color"])

	_add_theme_label(room, theme["label"])

	return room


func _add_door(room: Room, side_name: String, position: Vector2) -> void:
	var side_container := Node2D.new()
	side_container.name = side_name
	room.add_child(side_container)

	var door := (load(DOOR_SCENE_PATH) as PackedScene).instantiate()
	door.name = "Door"
	door.position = position
	side_container.add_child(door)


func _prop_sources(tile_set: TileSet) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for i in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(i)
		var source := tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var texture_path: String = source.texture.resource_path
		if not texture_path.begins_with(PROPS_TEXTURE_DIR):
			continue
		var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
		sources.append({
			"source_id": source_id,
			"texture_path": texture_path,
			"name": texture_path.get_file().get_basename().replace("_", " "),
			"blocking": tile_data != null and tile_data.get_collision_polygons_count(0) > 0,
		})
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"] < b["name"])
	return sources


func _add_prop_label(room: Room, prop_name: String, cell: Vector2i) -> void:
	var cell_center := Vector2(cell) * Room.TILE_SIZE_PX + Vector2.ONE * (Room.TILE_SIZE_PX / 2.0)
	var slot_width := SLOT_CELLS * Room.TILE_SIZE_PX
	var label := Label.new()
	label.text = prop_name
	label.position = cell_center + Vector2(-slot_width / 2.0 + 8.0, 90.0)
	label.size = Vector2(slot_width - 16.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	room.add_child(label)


func _add_theme_label(room: Room, theme_name: String) -> void:
	var label := Label.new()
	label.text = "-- %s --" % theme_name
	label.position = Vector2(0.0, 12.0)
	label.size = Vector2(Room.ROOM_WIDTH_PX, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	room.add_child(label)


func _spawn_player(spawn_position: Vector2, players: Node2D, hud_layer: Node2D) -> void:
	var player: Node = PlayerManager.spawn_player(1)
	player.instance_hud.connect(func(hud: Node) -> void: hud_layer.add_child(hud))
	players.add_child(player)
	player.position = spawn_position


func _build_instructions_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var label := Label.new()
	label.text = (
		"Bac à sable donjon -- %d props -- ZQSD/flèches : marcher dedans"
		% _prop_count
	)
	label.position = Vector2(16.0, 16.0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)
