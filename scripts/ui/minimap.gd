extends Control


const CELL_SIZE: float = 13.0
const CELL_GAP: float = 3.0
const PANEL_MARGIN: float = 8.0
const CORNER_RIVET_RADIUS: float = 2.2

const COLOR_PANEL_FILL: Color = Color(0.15, 0.11, 0.08, 0.72)
const COLOR_PANEL_BORDER: Color = Color(0.72, 0.53, 0.24, 0.8)
const COLOR_RIVET: Color = Color(0.32, 0.2, 0.11, 0.9)

const DIMMED_ALPHA: float = 0.35
const FADE_DURATION: float = 0.25

const COLOR_UNVISITED_ADJACENT: Color = Color(0.85, 0.78, 0.6, 0.35)
const COLOR_VISITED: Color = Color(0.6, 0.5, 0.35, 0.85)
const COLOR_CORRIDOR: Color = Color(0.5, 0.41, 0.28, 0.7)
const COLOR_START: Color = Color(0.27, 0.75, 0.78, 0.95)
const COLOR_SPECIAL: Color = Color(0.88, 0.68, 0.2, 0.95)
const COLOR_BOSS: Color = Color(0.75, 0.15, 0.18, 0.95)
const COLOR_TREASURE: Color = Color(0.62, 0.32, 0.85, 0.95)
const COLOR_GLYPH_INK: Color = Color(0.15, 0.1, 0.06, 0.9)
const COLOR_CURRENT_GLOW: Color = Color(1.0, 0.82, 0.4, 1.0)

const PULSE_SPEED: float = 2.4
const PULSE_MIN_WIDTH: float = 1.4
const PULSE_MAX_WIDTH: float = 2.4

var _game: Node = null
var _local_player: Node2D = null
var _current_room: Vector2i = Vector2i.ZERO
var _pulse_time: float = 0.0
var _fade_tween: Tween
var _dimmed: bool = false


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("Game")
	if _game:
		_game.dungeon_map_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if _game == null:
		return
	if _local_player == null or not is_instance_valid(_local_player):
		_local_player = _find_local_player()
	if _local_player == null:
		return
	var room: Vector2i = Vector2i((_local_player.position / _game.ROOM_CELL_SIZE).floor())
	if room != _current_room:
		_current_room = room
	_pulse_time += delta
	queue_redraw()
	_update_player_dim()


func _update_player_dim() -> void:
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * _local_player.global_position
	var should_dim: bool = get_global_rect().has_point(screen_position)
	if should_dim == _dimmed:
		return
	_dimmed = should_dim
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", DIMMED_ALPHA if _dimmed else 1.0, FADE_DURATION)


func _find_local_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_multiplayer_authority():
			return player
	return null


func _draw() -> void:
	if _game == null:
		return
	_draw_panel()
	var step: float = CELL_SIZE + CELL_GAP
	var center: Vector2 = size / 2.0
	_draw_corridors(step, center)
	for grid_position in _game.dungeon_map.keys():
		_draw_room(grid_position, step, center)


func _draw_panel() -> void:
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, COLOR_PANEL_FILL)
	draw_rect(panel_rect, COLOR_PANEL_BORDER, false, 1.5)
	for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		var offset: Vector2 = (corner - size / 2.0).normalized() * -PANEL_MARGIN * 0.6
		draw_circle(corner + offset, CORNER_RIVET_RADIUS, COLOR_RIVET)


func _cell_rect(grid_position: Vector2i, step: float, center: Vector2) -> Rect2:
	var top_left: Vector2 = center + Vector2(grid_position) * step - Vector2(CELL_SIZE, CELL_SIZE) / 2.0
	return Rect2(top_left, Vector2(CELL_SIZE, CELL_SIZE))


func _room_visibility(grid_position: Vector2i, room_info: Dictionary) -> int:
	if room_info["visited"]:
		return 2
	if _is_adjacent_to_visited(grid_position, room_info):
		return 1
	return 0


func _draw_room(grid_position: Vector2i, step: float, center: Vector2) -> void:
	var room_info: Dictionary = _game.dungeon_map[grid_position]
	var visibility: int = _room_visibility(grid_position, room_info)
	var cell_rect: Rect2 = _cell_rect(grid_position, step, center)
	if visibility == 0:
		return
	if visibility == 1:
		draw_rect(cell_rect, COLOR_UNVISITED_ADJACENT, false, 1.0)
		return
	var color: Color = _visited_room_color(room_info)
	draw_rect(cell_rect, color)
	_draw_room_glyph(room_info, cell_rect.get_center())
	if grid_position == _current_room:
		var width: float = lerpf(PULSE_MIN_WIDTH, PULSE_MAX_WIDTH, (sin(_pulse_time * PULSE_SPEED) + 1.0) / 2.0)
		draw_rect(cell_rect.grow(0.8), COLOR_CURRENT_GLOW, false, width)


func _visited_room_color(room_info: Dictionary) -> Color:
	if room_info["is_boss"]:
		return COLOR_BOSS
	if room_info["is_treasure"]:
		return COLOR_TREASURE
	if room_info["is_special"]:
		return COLOR_SPECIAL
	if room_info["is_start"]:
		return COLOR_START
	return COLOR_VISITED


func _draw_room_glyph(room_info: Dictionary, cell_center: Vector2) -> void:
	if room_info["is_boss"]:
		draw_line(cell_center + Vector2(-3, -3), cell_center + Vector2(3, 3), COLOR_GLYPH_INK, 1.5)
		draw_line(cell_center + Vector2(-3, 3), cell_center + Vector2(3, -3), COLOR_GLYPH_INK, 1.5)
	elif room_info["is_treasure"]:
		var points := PackedVector2Array([
			cell_center + Vector2(0, -3.5), cell_center + Vector2(3.5, 0),
			cell_center + Vector2(0, 3.5), cell_center + Vector2(-3.5, 0),
		])
		draw_colored_polygon(points, COLOR_GLYPH_INK)
	elif room_info["is_special"]:
		draw_arc(cell_center, 3.2, 0.0, TAU, 16, COLOR_GLYPH_INK, 1.5, true)
	elif room_info["is_start"]:
		draw_circle(cell_center, 2.5, COLOR_GLYPH_INK)


func _draw_corridors(step: float, center: Vector2) -> void:
	for grid_position in _game.dungeon_map.keys():
		var room_info: Dictionary = _game.dungeon_map[grid_position]
		if _room_visibility(grid_position, room_info) == 0:
			continue
		for side in ["south", "east"]:
			if side not in room_info["open_sides"]:
				continue
			var neighbor: Vector2i = grid_position + DungeonGenerator.DIRECTIONS[side]
			if not _game.dungeon_map.has(neighbor):
				continue
			var neighbor_info: Dictionary = _game.dungeon_map[neighbor]
			if _room_visibility(neighbor, neighbor_info) == 0:
				continue
			_draw_corridor_segment(grid_position, neighbor, step, center)


func _draw_corridor_segment(grid_position: Vector2i, neighbor: Vector2i, step: float, center: Vector2) -> void:
	var a: Rect2 = _cell_rect(grid_position, step, center)
	var thickness: float = CELL_SIZE * 0.35
	var corridor_rect: Rect2
	if neighbor.x != grid_position.x:
		corridor_rect = Rect2(a.position.x + CELL_SIZE, a.get_center().y - thickness / 2.0, CELL_GAP, thickness)
	else:
		corridor_rect = Rect2(a.get_center().x - thickness / 2.0, a.position.y + CELL_SIZE, thickness, CELL_GAP)
	draw_rect(corridor_rect, COLOR_CORRIDOR)


func _is_adjacent_to_visited(grid_position: Vector2i, room_info: Dictionary) -> bool:
	for side in room_info["open_sides"]:
		var neighbor: Vector2i = grid_position + DungeonGenerator.DIRECTIONS[side]
		if _game.dungeon_map.has(neighbor) and _game.dungeon_map[neighbor]["visited"]:
			return true
	return false
