extends ImpactEffect
class_name ImpactArea

const AREA_VFX_SCENE: String = "res://scenes/effects/area_effect_vfx.tscn"

@export var damage: float = 1.0
@export var radius: float = 50.0
@export var duration: float = 0.0
@export var type_alchimie: Ingredient.TypeAlchimie = Ingredient.TypeAlchimie.FEU

const SLOW_MULTIPLIER: float = 0.5
const SLOW_LINGER: float = DOT_TICK_INTERVAL + 0.2

func apply(target: Node, source_position: Vector2, _shooter_id: int = 0) -> void:
	var tree := target.get_tree()
	if tree == null:
		return
	if duration <= 0.0:
		for enemy in tree.get_nodes_in_group("Enemies"):
			if enemy.global_position.distance_to(source_position) <= radius:
				_apply_damage_over_time(enemy, damage, duration)
				_apply_slow_if_ice(enemy)
		return
	_spawn_zone_ticker(tree, source_position)


func _apply_slow_if_ice(enemy: Node) -> void:
	if type_alchimie != Ingredient.TypeAlchimie.GLACE:
		return
	if enemy.has_method("apply_slow"):
		enemy.apply_slow(SLOW_MULTIPLIER, SLOW_LINGER)


func _spawn_zone_ticker(tree: SceneTree, source_position: Vector2) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var ticks: int = maxi(1, roundi(duration / DOT_TICK_INTERVAL))
	var damage_per_tick: float = damage / ticks
	var timer := Timer.new()
	timer.wait_time = DOT_TICK_INTERVAL
	timer.one_shot = false
	root.add_child(timer)
	var ticks_left: Array[int] = [ticks]
	timer.timeout.connect(func() -> void:
		for enemy in tree.get_nodes_in_group("Enemies"):
			if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
				continue
			if enemy.global_position.distance_to(source_position) <= radius:
				enemy.take_damage(damage_per_tick)
				_apply_slow_if_ice(enemy)
		ticks_left[0] -= 1
		if ticks_left[0] <= 0:
			timer.queue_free()
	)
	timer.start()


func spawn_visual(tree: SceneTree, source_position: Vector2) -> void:
	if tree == null or tree.current_scene == null:
		return
	var vfx: Node2D = (load(AREA_VFX_SCENE) as PackedScene).instantiate()
	tree.current_scene.add_child(vfx)
	vfx.global_position = source_position
	vfx.play(type_alchimie, radius, duration, damage)

func to_dict() -> Dictionary:
	return {"type": "area", "damage": damage, "radius": radius, "duration": duration, "type_alchimie": type_alchimie}
