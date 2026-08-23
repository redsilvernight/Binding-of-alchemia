extends Resource
class_name ImpactEffect

func apply(_target: Node, _source_position: Vector2, _shooter_id: int = 0) -> void:
	pass

func spawn_visual(_tree: SceneTree, _source_position: Vector2) -> void:
	pass

func to_dict() -> Dictionary:
	return {"type": "none"}

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
