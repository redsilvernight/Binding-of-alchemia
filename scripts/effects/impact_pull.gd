extends ImpactEffect
class_name ImpactPull

const AREA_VFX_SCENE: String = "res://scenes/effects/area_effect_vfx.tscn"

@export var radius: float = 300.0
@export var duration: float = 1.2
@export var pull_strength: float = 220.0

func apply(target: Node, source_position: Vector2, _shooter_id: int = 0) -> void:
	var tree := target.get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("Enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(source_position) <= radius:
			enemy.apply_pull(source_position, pull_strength, duration)

func spawn_visual(tree: SceneTree, source_position: Vector2) -> void:
	if tree == null or tree.current_scene == null:
		return
	var vfx: Node2D = (load(AREA_VFX_SCENE) as PackedScene).instantiate()
	tree.current_scene.add_child(vfx)
	vfx.global_position = source_position
	vfx.play_pull(radius, duration)

func to_dict() -> Dictionary:
	return {"type": "pull", "radius": radius, "duration": duration, "pull_strength": pull_strength}
