class_name SpawnTableEntry
extends Resource

@export var item_path: String = ""
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var requires_unlock: bool = false
@export var min_floor: int = 1
@export var spawn_count_min: int = 1
@export var spawn_count_max: int = 1
