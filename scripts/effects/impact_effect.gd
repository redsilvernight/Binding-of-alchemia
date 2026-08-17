extends Resource
class_name ImpactEffect

## shooter_id : identifiant réseau (peer_id) de qui a tiré -- 0 si inconnu
## (ex: script de test hors arbre). Seul ImpactHeal s'en sert (soigner le
## tireur, pas la cible touchée) ; les autres effets l'ignorent.
func apply(_target: Node, _source_position: Vector2, _shooter_id: int = 0) -> void:
	pass

## Feedback visuel pur (pas de gameplay) : à surcharger dans les sous-classes
## qui en ont un (aujourd'hui : ImpactArea uniquement). Appelée par
## Bullet._on_body_entered AVANT la garde hôte (comme le SFX d'impact) --
## chaque pair simule sa propre collision indépendamment, donc chacun doit
## afficher l'effet lui-même plutôt que d'attendre une RPC dédiée.
func spawn_visual(_tree: SceneTree, _source_position: Vector2) -> void:
	pass

## Sérialise cet effet en Dictionary de types de base (String/float/Array),
## pour pouvoir le transmettre via RPC sans dépendre d'un resource_path.
## À surcharger dans chaque sous-classe.
func to_dict() -> Dictionary:
	return {"type": "none"}

## Reconstruit un ImpactEffect depuis un Dictionary produit par to_dict().
static func from_dict(data: Dictionary) -> ImpactEffect:
	match data.get("type", "none"):
		"damage":
			var e := ImpactDamage.new()
			e.damage = data.get("damage", 0.0)
			e.duration = data.get("duration", 0.0)
			return e
		"area":
			var e := ImpactArea.new()
			e.damage = data.get("damage", 0.0)
			e.radius = data.get("radius", 0.0)
			e.duration = data.get("duration", 0.0)
			e.type_alchimie = data.get("type_alchimie", Ingredient.TypeAlchimie.FEU)
			return e
		"heal":
			var e := ImpactHeal.new()
			e.amount = data.get("amount", 0.0)
			return e
		"composite":
			var e := ImpactComposite.new()
			var sous_effets: Array[ImpactEffect] = []
			for sous_data in data.get("effects", []):
				sous_effets.append(ImpactEffect.from_dict(sous_data))
			e.effets = sous_effets
			return e
		_:
			return null

## Dégâts instantanés (duration <= 0) ou répartis en tics réguliers sur
## `duration` secondes -- partagé par ImpactDamage/ImpactArea (2 appelants
## concrets, cf. design_no_premature_genericity) plutôt que dupliqué. Le
## Timer est un enfant de `target` : il est libéré automatiquement avec elle
## (mort/despawn), pas de fuite possible.
const DOT_TICK_INTERVAL: float = 0.5

func _apply_damage_over_time(target: Node, total_damage: float, duration: float) -> void:
	if not target.has_method("take_damage"):
		return
	if duration <= 0.0:
		target.take_damage(total_damage)
		return
	var ticks: int = maxi(1, roundi(duration / DOT_TICK_INTERVAL))
	var damage_per_tick: float = total_damage / ticks
	var timer := Timer.new()
	timer.wait_time = DOT_TICK_INTERVAL
	timer.one_shot = false
	target.add_child(timer)
	var ticks_left: Array[int] = [ticks]
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			timer.queue_free()
			return
		target.take_damage(damage_per_tick)
		ticks_left[0] -= 1
		if ticks_left[0] <= 0:
			timer.queue_free()
	)
	timer.start()
