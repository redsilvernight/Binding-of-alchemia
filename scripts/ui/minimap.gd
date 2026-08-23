extends Control


const CELL_SIZE: float = 18.0
const CELL_GAP: float = 4.0
const COLOR_UNVISITED_ADJACENT: Color = Color(1.0, 1.0, 1.0, 0.25)
const COLOR_VISITED: Color = Color(0.6, 0.6, 0.65, 0.9)
const COLOR_START: Color = Color(0.3, 0.75, 0.9, 0.9)
const COLOR_SPECIAL: Color = Color(0.85, 0.7, 0.25, 0.9)
const COLOR_BOSS: Color = Color(0.8, 0.2, 0.25, 0.9)
const COLOR_CURRENT_OUTLINE: Color = Color(1.0, 0.35, 0.35, 1.0)

var _game: Node = null
var _local_player: Node2D = null
var _current_room: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("Game")
	if _game:
		_game.dungeon_map_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	if _game == null:
		return
	if _local_player == null or not is_instance_valid(_local_player):
		_local_player = _find_local_player()
	if _local_player == null:
		return
	var room: Vector2i = Vector2i((_local_player.position / _game.ROOM_CELL_SIZE).floor())
	if room != _current_room:
		_current_room = room
		queue_redraw()


func _find_local_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_multiplayer_authority():
			return player
	return null


func _draw() -> void:
	if _game == null:
		return
	var step: float = CELL_SIZE + CELL_GAP
	var center: Vector2 = size / 2.0
	for grid_position in _game.dungeon_map.keys():
		var room_info: Dictionary = _game.dungeon_map[grid_position]
		var color: Color
		if room_info["visited"]:
			if room_info["is_special"]:
				color = COLOR_SPECIAL
			elif room_info["is_boss"]:
				color = COLOR_BOSS
			elif room_info["is_start"]:
				color = COLOR_START
			else:
				color = COLOR_VISITED
		elif _is_adjacent_to_visited(grid_position, room_info):
			color = COLOR_UNVISITED_ADJACENT
		else:
			continue
		var top_left: Vector2 = center + Vector2(grid_position) * step - Vector2(CELL_SIZE, CELL_SIZE) / 2.0
		var cell_rect := Rect2(top_left, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(cell_rect, color)
		if room_info["visited"] and grid_position == _current_room:
			draw_rect(cell_rect, COLOR_CURRENT_OUTLINE, false, 2.0)


func _is_adjacent_to_visited(grid_position: Vector2i, room_info: Dictionary) -> bool:
	for side in room_info["open_sides"]:
		var neighbor: Vector2i = grid_position + DungeonGenerator.DIRECTIONS[side]
		if _game.dungeon_map.has(neighbor) and _game.dungeon_map[neighbor]["visited"]:
			return true
	return false
