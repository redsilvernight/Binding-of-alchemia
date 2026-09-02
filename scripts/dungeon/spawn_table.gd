class_name SpawnTable
extends Resource


@export var entries: Array[SpawnTableEntry] = []
@export var min_count: int = 1
@export var max_count: int = 1


func available_entries(floor_level: int = 1) -> Array[SpawnTableEntry]:
	var available: Array[SpawnTableEntry] = []
	for entry in entries:
		if entry.requires_unlock and not MetaProgression.is_unlocked_by_party(entry.item_path):
			continue
		if entry.min_floor > floor_level:
			continue
		available.append(entry)
	return available


func _pick_entry(floor_level: int = 1) -> SpawnTableEntry:
	var available: Array[SpawnTableEntry] = available_entries(floor_level)
	var total_weight: float = 0.0
	for entry in available:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return null
	var roll: float = randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in available:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry
	return available[-1]


func pick_one(floor_level: int = 1) -> String:
	var entry: SpawnTableEntry = _pick_entry(floor_level)
	if entry == null:
		return ""
	return entry.item_path


func pick_many(floor_level: int = 1) -> Array[String]:
	var results: Array[String] = []
	for i in randi_range(min_count, max_count):
		var entry: SpawnTableEntry = _pick_entry(floor_level)
		if entry == null:
			continue
		for j in randi_range(entry.spawn_count_min, entry.spawn_count_max):
			results.append(entry.item_path)
	return results


func pick_all_shuffled() -> Array[String]:
	var paths: Array[String] = []
	for entry in available_entries():
		paths.append(entry.item_path)
	paths.shuffle()
	return paths
