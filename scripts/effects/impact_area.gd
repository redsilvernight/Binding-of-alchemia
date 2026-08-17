extends ImpactEffect
class_name ImpactArea

const AREA_VFX_SCENE: String = "res://scenes/effects/area_effect_vfx.tscn"

@export var damage: float = 1.0
@export var radius: float = 50.0
## Même sémantique que ImpactDamage.duration : 0 = instantané, sinon dégâts
## répartis en tics par ennemi touché (le rayon n'est mesuré qu'une fois, à
## l'impact -- pas de re-scan pendant les tics).
@export var duration: float = 0.0
## Type d'origine (cf. MixtureToEffect._creer_impact) : purement visuel, ne
## joue aucun rôle dans apply() -- détermine quel sprite area_effect_vfx.gd
## affiche pour cette zone.
@export var type_alchimie: Ingredient.TypeAlchimie = Ingredient.TypeAlchimie.FEU

func apply(target: Node, source_position: Vector2, _shooter_id: int = 0) -> void:
	var tree := target.get_tree()
	if tree == null:
		return
	var enemies = tree.get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.global_position.distance_to(source_position) <= radius:
			_apply_damage_over_time(enemy, damage, duration)

func spawn_visual(tree: SceneTree, source_position: Vector2) -> void:
	if tree == null or tree.current_scene == null:
		return
	var vfx: Node2D = (load(AREA_VFX_SCENE) as PackedScene).instantiate()
	tree.current_scene.add_child(vfx)
	vfx.global_position = source_position
	vfx.play(type_alchimie, radius, duration)

func to_dict() -> Dictionary:
	return {"type": "area", "damage": damage, "radius": radius, "duration": duration, "type_alchimie": type_alchimie}
