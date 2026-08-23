class_name DungeonGenerator
extends RefCounted


const DIRECTIONS: Dictionary = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}


static func generate(room_count: int, room_template_paths: Array[String], special_room_template_paths: Array[String], boss_room_template_path: String, treasure_room_template_path: String) -> Array[Dictionary]:
	var start: Vector2i = Vector2i.ZERO
	var occupied: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]

	while occupied.size() < room_count and not frontier.is_empty():
		var from: Vector2i = frontier[randi() % frontier.size()]
		var dirs: Array = DIRECTIONS.keys()
		dirs.shuffle()
		var placed: bool = false
		for dir in dirs:
			var candidate: Vector2i = from + DIRECTIONS[dir]
			if occupied.has(candidate):
				continue
			occupied[candidate] = true
			frontier.append(candidate)
			placed = true
			break
		if not placed:
			frontier.erase(from)

	var cells: Array = occupied.keys()

	var adjacency: Dictionary = {}
	for cell in cells:
		var neighbors: Array[Vector2i] = []
		for dir in DIRECTIONS.keys():
			var neighbor: Vector2i = cell + DIRECTIONS[dir]
			if occupied.has(neighbor):
				neighbors.append(neighbor)
		adjacency[cell] = neighbors

	var start_distances: Dictionary = _bfs_distances(start, adjacency)
	var boss_cell: Vector2i = start
	var best_distance: int = -1
	for cell in cells:
		if cell == start:
			continue
		var distance: int = start_distances.get(cell, -1)
		if distance > best_distance:
			best_distance = distance
			boss_cell = cell

	var reachable_without_boss: Dictionary = _bfs_distances(start, adjacency, boss_cell)

	var special_candidates: Array = cells.filter(func(c): return c != start and c != boss_cell and reachable_without_boss.has(c))
	var special_cell: Vector2i = start
	if not special_candidates.is_empty():
		special_cell = special_candidates[randi() % special_candidates.size()]
	var special_template_path: String = special_room_template_paths[randi() % special_room_template_paths.size()]

	var treasure_candidates: Array = cells.filter(func(c): return c != start and c != boss_cell and c != special_cell and reachable_without_boss.has(c))
	var treasure_cell: Vector2i = start
	if not treasure_candidates.is_empty():
		treasure_cell = treasure_candidates[randi() % treasure_candidates.size()]

	var layout: Array[Dictionary] = []
	for cell in cells:
		var open_sides: Array[String] = []
		for dir in DIRECTIONS.keys():
			if occupied.has(cell + DIRECTIONS[dir]):
				open_sides.append(dir)
		var template_path: String = room_template_paths[randi() % room_template_paths.size()]
		if cell == special_cell:
			template_path = special_template_path
		elif cell == boss_cell:
			template_path = boss_room_template_path
		elif cell == treasure_cell:
			template_path = treasure_room_template_path
		layout.append({
			"grid_position": cell,
			"template_path": template_path,
			"open_sides": open_sides,
			"is_start": cell == start,
			"is_special": cell == special_cell,
			"is_boss": cell == boss_cell,
			"is_treasure": cell == treasure_cell,
		})
	return layout


static func _bfs_distances(start: Vector2i, adjacency: Dictionary, excluded_cell: Variant = null) -> Dictionary:
	var distances: Dictionary = {start: 0}
	if excluded_cell != null and start == excluded_cell:
		return distances
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for neighbor in adjacency.get(current, []):
			if (excluded_cell != null and neighbor == excluded_cell) or distances.has(neighbor):
				continue
			distances[neighbor] = distances[current] + 1
			queue.append(neighbor)
	return distances
