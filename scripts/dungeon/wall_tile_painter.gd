class_name WallTilePainter
extends RefCounted


const TILE_FLOOR: Vector2i = Vector2i(2, 1)
const WANG_ATLAS_BY_CORNERS: Dictionary = {
	0: Vector2i(2, 1),
	1: Vector2i(3, 1),
	2: Vector2i(2, 2),
	3: Vector2i(1, 2),
	4: Vector2i(2, 0),
	5: Vector2i(3, 2),
	6: Vector2i(0, 1),
	7: Vector2i(3, 3),
	8: Vector2i(1, 1),
	9: Vector2i(2, 3),
	10: Vector2i(1, 0),
	11: Vector2i(0, 2),
	12: Vector2i(3, 0),
	13: Vector2i(0, 0),
	14: Vector2i(1, 3),
	15: Vector2i(0, 3),
}
const NORTH_EDGE_INDEX: int = 12
const SOUTH_EDGE_INDEX: int = 3
const WEST_EDGE_INDEX: int = 10
const EAST_EDGE_INDEX: int = 5

func compute_wall_cells(cols: int, rows: int, door_tiles: int, open_sides: Array) -> Dictionary:
	var door_col_start: int = (cols - door_tiles) / 2
	var door_col_end: int = door_col_start + door_tiles
	var door_row_start: int = (rows - door_tiles) / 2
	var door_row_end: int = door_row_start + door_tiles
	var open_north: bool = "north" in open_sides
	var open_south: bool = "south" in open_sides
	var open_west: bool = "west" in open_sides
	var open_east: bool = "east" in open_sides

	var is_wall_vertex: Callable = func(vx: int, vy: int) -> bool:
		if vy == 0 and open_north and vx >= door_col_start and vx <= door_col_end:
			return false
		if vy == rows and open_south and vx >= door_col_start and vx <= door_col_end:
			return false
		if vx == 0 and open_west and vy >= door_row_start and vy <= door_row_end:
			return false
		if vx == cols and open_east and vy >= door_row_start and vy <= door_row_end:
			return false
		return vx == 0 or vx == cols or vy == 0 or vy == rows

	var wall_cells: Dictionary = {}
	for x in range(cols):
		for y in range(rows):
			var nw: bool = is_wall_vertex.call(x, y)
			var ne: bool = is_wall_vertex.call(x + 1, y)
			var sw: bool = is_wall_vertex.call(x, y + 1)
			var se: bool = is_wall_vertex.call(x + 1, y + 1)
			if not (nw or ne or sw or se):
				continue
			var corner_index: int = int(nw) * 8 + int(ne) * 4 + int(sw) * 2 + int(se)
			corner_index = _flatten_door_frame(x, y, corner_index, open_north, open_south, open_west, open_east, door_col_start, door_col_end, door_row_start, door_row_end, cols, rows)
			wall_cells[Vector2i(x, y)] = WANG_ATLAS_BY_CORNERS[corner_index]
	return wall_cells

func _flatten_door_frame(x: int, y: int, corner_index: int, open_north: bool, open_south: bool, open_west: bool, open_east: bool, door_col_start: int, door_col_end: int, door_row_start: int, door_row_end: int, cols: int, rows: int) -> int:
	if open_north and y == 0 and (x == door_col_start - 1 or x == door_col_end):
		return NORTH_EDGE_INDEX
	if open_south and y == rows - 1 and (x == door_col_start - 1 or x == door_col_end):
		return SOUTH_EDGE_INDEX
	if open_west and x == 0 and (y == door_row_start - 1 or y == door_row_end):
		return WEST_EDGE_INDEX
	if open_east and x == cols - 1 and (y == door_row_start - 1 or y == door_row_end):
		return EAST_EDGE_INDEX
	return corner_index
