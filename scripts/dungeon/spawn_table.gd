class_name SpawnTable
extends Resource


@export var entries: Array[SpawnTableEntry] = []
@export var min_count: int = 1
@export var max_count: int = 1


func _available_entries() -> Array[SpawnTableEntry]:
	var available: Array[SpawnTableEntry] = []
	for entry in entries:
		if entry.requires_unlock and not MetaProgression.is_unlocked_by_party(entry.item_path):
			continue
		available.append(entry)
	return available


func pick_one() -> String:
	var available: Array[SpawnTableEntry] = _available_entries()
	var total_weight: float = 0.0
	for entry in available:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return ""
	var roll: float = randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in available:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.item_path
	return available[-1].item_path


func pick_many() -> Array[String]:
	var results: Array[String] = []
	for i in randi_range(min_count, max_count):
		var path: String = pick_one()
		if path != "":
			results.append(path)
	return results


func pick_all_shuffled() -> Array[String]:
	var paths: Array[String] = []
	for entry in _available_entries():
		paths.append(entry.item_path)
	paths.shuffle()
	return paths
