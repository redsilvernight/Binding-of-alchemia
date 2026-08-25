class_name ShelfBackdropLocator
extends RefCounted

const COLOR_BUCKET_LEVELS: float = 32.0
const MAX_FOREGROUND_PIXELS: int = 600
const NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func find_hidden_area(image: Image, slot_offset: Vector2, search_radius: Vector2i, color_threshold: float, padding: float) -> Dictionary:
	var image_size: Vector2i = image.get_size()
	var center: Vector2i = image_size / 2 + Vector2i(roundi(slot_offset.x), roundi(slot_offset.y))
	var min_bound := Vector2i(maxi(center.x - search_radius.x, 0), maxi(center.y - search_radius.y, 0))
	var max_bound := Vector2i(mini(center.x + search_radius.x, image_size.x - 1), mini(center.y + search_radius.y, image_size.y - 1))

	var background: Color = _dominant_color(image, min_bound, max_bound)
	var seed_pos: Vector2i = _find_seed(image, center, min_bound, max_bound, background, color_threshold)
	if seed_pos.x < 0:
		return {"rect": Rect2(), "color": background}

	var bbox_min := seed_pos
	var bbox_max := seed_pos
	var visited := {seed_pos: true}
	var queue: Array[Vector2i] = [seed_pos]
	var head := 0
	var foreground_count := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		if _color_distance(image.get_pixelv(p), background) <= color_threshold:
			continue
		foreground_count += 1
		if foreground_count > MAX_FOREGROUND_PIXELS:
			return {"rect": Rect2(), "color": background}
		bbox_min = Vector2i(mini(bbox_min.x, p.x), mini(bbox_min.y, p.y))
		bbox_max = Vector2i(maxi(bbox_max.x, p.x), maxi(bbox_max.y, p.y))
		for offset in NEIGHBOR_OFFSETS:
			var n: Vector2i = p + offset
			if n.x < min_bound.x or n.x > max_bound.x or n.y < min_bound.y or n.y > max_bound.y:
				continue
			if visited.has(n):
				continue
			visited[n] = true
			queue.append(n)

	var size: Vector2 = Vector2(bbox_max - bbox_min) + Vector2.ONE + Vector2.ONE * padding * 2.0
	var texture_center: Vector2 = Vector2(bbox_min + bbox_max) / 2.0 + Vector2(0.5, 0.5)
	var local_center: Vector2 = texture_center - Vector2(image_size) / 2.0 - slot_offset
	return {"rect": Rect2(local_center - size / 2.0, size), "color": background}


static func _dominant_color(image: Image, min_bound: Vector2i, max_bound: Vector2i) -> Color:
	var counts: Dictionary = {}
	for y in range(min_bound.y, max_bound.y + 1):
		for x in range(min_bound.x, max_bound.x + 1):
			var c: Color = image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var key := Vector3i(roundi(c.r * COLOR_BUCKET_LEVELS), roundi(c.g * COLOR_BUCKET_LEVELS), roundi(c.b * COLOR_BUCKET_LEVELS))
			counts[key] = counts.get(key, 0) + 1
	var best_key := Vector3i.ZERO
	var best_count := -1
	for key in counts:
		if counts[key] > best_count:
			best_count = counts[key]
			best_key = key
	return Color(best_key.x / COLOR_BUCKET_LEVELS, best_key.y / COLOR_BUCKET_LEVELS, best_key.z / COLOR_BUCKET_LEVELS)


static func _find_seed(image: Image, center: Vector2i, min_bound: Vector2i, max_bound: Vector2i, background: Color, threshold: float) -> Vector2i:
	if _color_distance(image.get_pixelv(center), background) > threshold:
		return center
	var max_radius: int = maxi(max_bound.x - min_bound.x, max_bound.y - min_bound.y)
	for radius in range(1, max_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var p: Vector2i = center + Vector2i(dx, dy)
				if p.x < min_bound.x or p.x > max_bound.x or p.y < min_bound.y or p.y > max_bound.y:
					continue
				if _color_distance(image.get_pixel(p.x, p.y), background) > threshold:
					return p
	return Vector2i(-1, -1)


static func _color_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
