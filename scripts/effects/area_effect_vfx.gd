extends Node2D
class_name AreaEffectVfx

const TEXTURE_SIZE: float = 128.0

# Reference used to normalize damage into a 0..1 visual intensity (same order of
# magnitude as MixturePreview.DAMAGE_BAR_MAX so the cauldron gauge and the cast look match).
const DAMAGE_REFERENCE: float = 30.0

@export var texture_feu: Texture2D
@export var texture_glace: Texture2D
@export var texture_poison: Texture2D
@export var texture_electrique: Texture2D
@export var texture_explosif: Texture2D


func play(type_alchimie: Ingredient.TypeAlchimie, radius: float, duration: float, damage: float = 0.0) -> void:
	match type_alchimie:
		Ingredient.TypeAlchimie.FEU:
			_play_fire(radius, duration, damage)
		Ingredient.TypeAlchimie.GLACE:
			_play_ice(radius, duration, damage)
		Ingredient.TypeAlchimie.EXPLOSIF:
			_play_explosion(radius, duration, damage)
		Ingredient.TypeAlchimie.POISON:
			_play_lingering_cloud(radius, duration, damage)
		Ingredient.TypeAlchimie.ELECTRIQUE:
			_play_lightning_chain(radius, duration, damage)
		_:
			queue_free()


func _free_after(seconds: float) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(queue_free)


func _scale_for(visual_radius: float) -> float:
	return maxf(visual_radius, 12.0) * 2.0 / TEXTURE_SIZE


func _intensity(damage: float) -> float:
	return clampf(damage / DAMAGE_REFERENCE, 0.25, 1.0)


# --- FEU : burst rapide et asymetrique, braises qui montent, trace de brule au sol persistante ---

func _play_fire(radius: float, duration: float, damage: float) -> void:
	var intensity: float = _intensity(damage)
	var linger: float = maxf(duration, 0.9)
	_play_burst(texture_feu, radius * 0.4, 0.5, 0.5 + 0.4 * intensity, 0.18)
	_spawn_particles(texture_feu, 3 + roundi(intensity * 4), 0.08, radius * 0.2, radius * 0.6, 0.5, 1.4, Color(1.0, 0.6, 0.2, 0.9))
	_spawn_decal(texture_feu, _scale_for(radius * 0.55), Color(0.15, 0.05, 0.03), 0.2 + 0.25 * intensity, linger)
	_play_zone_ring(radius, Color(1.0, 0.45, 0.15, 0.3 + 0.2 * intensity), linger)
	_spawn_smoke_stream(radius, linger, Color(0.08, 0.07, 0.06, 0.5 + 0.15 * intensity))
	_free_after(linger + 1.2)


# --- GLACE : expansion lente, anneau de givre qui persiste, fissures qui se figent ---

func _play_ice(radius: float, duration: float, damage: float) -> void:
	var intensity: float = _intensity(damage)
	var linger: float = maxf(duration, 1.0)
	_play_burst(texture_glace, radius * 0.45, 0.45, 0.25 + 0.25 * intensity, 0.6)
	_spawn_decal(texture_glace, _scale_for(radius * 0.85), Color(0.75, 0.95, 1.0), 0.18 + 0.15 * intensity, linger)
	_spawn_radiating_lines(4 + roundi(intensity * 3), radius * 0.8, Color(0.8, 0.97, 1.0, 0.8), 2.0, linger * 0.6 + 0.3)
	_play_zone_ring(radius, Color(0.75, 0.95, 1.0, 0.3 + 0.2 * intensity), linger)
	_spawn_smoke_stream(radius, linger, Color(0.75, 0.92, 1.0, 0.35 + 0.1 * intensity))
	_free_after(linger + 0.6)


# --- EXPLOSIF : flash + onde de choc courte, debris, trace de decombres si la zone persiste ---

func _play_explosion(radius: float, duration: float, damage: float) -> void:
	var intensity: float = _intensity(damage)
	_play_burst(texture_explosif, radius * 0.35, 0.6, 0.7 + 0.3 * intensity, 0.09)
	_play_ring(radius, Color(1.0, 0.55, 0.2, 0.5 + 0.4 * intensity), 0.3)
	_spawn_particles(texture_explosif, 3 + roundi(intensity * 5), 0.07, radius * 0.15, radius * 0.75, 0.4, 0.3, Color(0.3, 0.15, 0.1, 0.9))
	_spawn_smoke(4 + roundi(intensity * 4), radius * 0.15, radius * 0.55, 1.1, 0.35, Color(0.05, 0.05, 0.05, 0.55))

	if duration <= 0.0:
		_free_after(1.4)
		return

	var linger: float = duration
	_play_zone_ring(radius, Color(0.85, 0.35, 0.1, 0.3 + 0.2 * intensity), linger)
	_spawn_smoke_stream(radius, linger, Color(0.06, 0.05, 0.04, 0.5 + 0.15 * intensity))
	_free_after(linger + 1.2)


# --- POISON : nuage qui persiste, bulles internes qui remontent lentement ---

func _play_lingering_cloud(radius: float, duration: float, damage: float) -> void:
	var intensity: float = _intensity(damage)
	var sprite := Sprite2D.new()
	sprite.texture = texture_poison
	sprite.modulate.a = 0.0
	add_child(sprite)

	var target_scale: float = radius * 2.0 / TEXTURE_SIZE
	sprite.scale = Vector2.ONE * target_scale * 0.75

	var linger: float = maxf(duration, 1.2)
	var bubbles: Array[Sprite2D] = _spawn_poison_bubbles(radius, 2 + roundi(intensity * 3))
	_play_zone_ring(radius, Color(0.55, 0.85, 0.35, 0.3 + 0.2 * intensity), linger)
	_spawn_smoke_stream(radius, linger, Color(0.35, 0.55, 0.25, 0.4 + 0.1 * intensity))

	var peak_alpha: float = 0.16 + 0.14 * intensity
	var low_alpha: float = 0.1 + 0.08 * intensity
	var intro := create_tween()
	intro.tween_property(sprite, "modulate:a", peak_alpha, 0.4)
	intro.tween_callback(func() -> void:
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(sprite, "modulate:a", low_alpha, 0.9).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(sprite, "modulate:a", peak_alpha, 0.9).set_trans(Tween.TRANS_SINE)
		var linger_timer := get_tree().create_timer(linger, false)
		linger_timer.timeout.connect(func() -> void:
			pulse.kill()
			for bubble in bubbles:
				if not is_instance_valid(bubble):
					continue
				var bubble_tween: Tween = bubble.get_meta("tween")
				if bubble_tween != null and bubble_tween.is_valid():
					bubble_tween.kill()
				var fade := create_tween()
				fade.tween_property(bubble, "modulate:a", 0.0, 0.4)
			var outro := create_tween()
			outro.tween_property(sprite, "modulate:a", 0.0, 0.4)
			outro.tween_callback(queue_free)
		)
	)


func _spawn_poison_bubbles(radius: float, count: int) -> Array[Sprite2D]:
	var bubbles: Array[Sprite2D] = []
	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = texture_poison
		sprite.scale = Vector2.ONE * _scale_for(radius * randf_range(0.1, 0.18))
		sprite.modulate = Color(0.65, 1.0, 0.55, 0.0)
		var start: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(0.0, radius * 0.45)
		sprite.position = start
		add_child(sprite)

		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate:a", 0.3, 0.5).set_delay(randf_range(0.0, 0.4))
		tween.parallel().tween_property(sprite, "position", start + Vector2(0.0, -radius * 0.35), 1.3).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func() -> void: sprite.position = start)
		sprite.set_meta("tween", tween)
		bubbles.append(sprite)
	return bubbles


# --- ELECTRIQUE : anneau d'arcs a la source, chaine d'eclairs vers les cibles, re-decharge si la zone persiste ---

const LIGHTNING_SEGMENTS: int = 5
const LIGHTNING_JITTER: float = 10.0
const LIGHTNING_FLASH_DURATION: float = 0.16

func _play_lightning_chain(radius: float, duration: float, damage: float) -> void:
	var intensity: float = _intensity(damage)
	_spawn_radiating_lines(3 + roundi(intensity * 4), radius * 0.3, Color(1.0, 0.95, 0.5, 0.5 + 0.4 * intensity), 1.5 + 1.5 * intensity, LIGHTNING_FLASH_DURATION)

	var tree := get_tree()
	if tree == null:
		queue_free()
		return

	var hit_any: bool = _zap_targets_in_range(radius, intensity)

	if duration <= 0.0:
		if not hit_any:
			_free_after(0.35)
			return
		_free_after(LIGHTNING_FLASH_DURATION + 0.05)
		return

	var linger: float = duration
	_play_zone_ring(radius, Color(1.0, 0.95, 0.5, 0.3 + 0.2 * intensity), linger)
	_spawn_spark_stream(radius, linger, Color(1.0, 0.9, 0.4, 0.8))
	_play_arc_pulses(radius, linger, intensity)
	_free_after(linger + 0.3)


func _zap_targets_in_range(radius: float, intensity: float, show_empty_burst: bool = true) -> bool:
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			_draw_bolt(enemy.global_position, intensity)
			hit_any = true
	if not hit_any and show_empty_burst:
		_play_burst(texture_electrique, radius * 0.25, 0.5, 0.08 + 0.1 * intensity, 0.15)
	return hit_any


func _play_arc_pulses(radius: float, linger: float, intensity: float) -> void:
	var timer := Timer.new()
	timer.wait_time = ImpactEffect.DOT_TICK_INTERVAL
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(func() -> void:
		_zap_targets_in_range(radius, intensity, false)
	)
	timer.start()
	get_tree().create_timer(linger, false).timeout.connect(timer.queue_free)


func _spawn_spark_stream(radius: float, linger: float, tint: Color) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.12
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(func() -> void:
		_spawn_particles(texture_electrique, 2, 0.05, radius * 0.95, radius * 0.12, 0.25, 0.0, tint)
	)
	timer.start()
	get_tree().create_timer(linger, false).timeout.connect(timer.queue_free)


func _draw_bolt(target_global_position: Vector2, intensity: float) -> void:
	var line := Line2D.new()
	line.width = 1.5 + 2.0 * intensity
	line.default_color = Color(1.0, 0.95, 0.45, 0.6 + 0.35 * intensity)
	add_child(line)

	var from_local: Vector2 = Vector2.ZERO
	var to_local_point: Vector2 = to_local(target_global_position)
	var direction: Vector2 = to_local_point.normalized()
	var perpendicular: Vector2 = direction.rotated(PI / 2.0)

	var points: PackedVector2Array = []
	for i in range(LIGHTNING_SEGMENTS + 1):
		var t: float = float(i) / LIGHTNING_SEGMENTS
		var base: Vector2 = from_local.lerp(to_local_point, t)
		var jitter: float = 0.0 if (i == 0 or i == LIGHTNING_SEGMENTS) else randf_range(-LIGHTNING_JITTER, LIGHTNING_JITTER)
		points.append(base + perpendicular * jitter)
	line.points = points

	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, LIGHTNING_FLASH_DURATION)


# --- Helpers partages ---

func _play_burst(texture: Texture2D, visual_radius: float, scale_fraction: float, max_alpha: float, grow_duration: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.modulate.a = 0.0
	add_child(sprite)

	var target_scale: float = maxf(visual_radius * scale_fraction, 12.0) * 2.0 / TEXTURE_SIZE
	sprite.scale = Vector2.ONE * target_scale * 0.35

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", max_alpha, grow_duration * 0.35)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * target_scale, grow_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, grow_duration * 0.9)
	tween.tween_callback(sprite.queue_free)


func _spawn_decal(texture: Texture2D, target_scale: float, tint: Color, max_alpha: float, hold_duration: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * target_scale
	sprite.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	add_child(sprite)

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", max_alpha, 0.2)
	tween.tween_interval(hold_duration)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(sprite.queue_free)


func _spawn_particles(texture: Texture2D, count: int, base_scale: float, spawn_radius: float, distance: float, life: float, upward_bias: float, tint: Color) -> void:
	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.modulate = Color(tint.r, tint.g, tint.b, 0.0)
		sprite.scale = Vector2.ONE * base_scale
		var angle: float = randf() * TAU
		var start: Vector2 = Vector2.RIGHT.rotated(angle) * randf_range(0.0, spawn_radius)
		sprite.position = start
		add_child(sprite)

		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		dir.y -= upward_bias
		dir = dir.normalized()
		var target: Vector2 = start + dir * distance * randf_range(0.6, 1.0)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "position", target, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "modulate:a", tint.a, life * 0.25)
		tween.chain().tween_property(sprite, "modulate:a", 0.0, life * 0.5)
		tween.chain().tween_callback(sprite.queue_free)


static var _smoke_texture: GradientTexture2D


func _get_smoke_texture() -> GradientTexture2D:
	if _smoke_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_smoke_texture = tex
	return _smoke_texture


func _spawn_smoke(count: int, spawn_radius: float, distance: float, life: float, upward_bias: float, tint: Color) -> void:
	var texture := _get_smoke_texture()
	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.modulate = Color(tint.r, tint.g, tint.b, 0.0)
		sprite.scale = Vector2.ONE * randf_range(0.5, 0.9)
		sprite.rotation = randf_range(0.0, TAU)
		var angle: float = randf() * TAU
		var start: Vector2 = Vector2.RIGHT.rotated(angle) * randf_range(0.0, spawn_radius)
		sprite.position = start
		add_child(sprite)

		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		dir.y -= upward_bias
		dir = dir.normalized()
		var target: Vector2 = start + dir * distance * randf_range(0.7, 1.0)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "position", target, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", sprite.scale * 1.6, life).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "modulate:a", tint.a, life * 0.3)
		tween.chain().tween_property(sprite, "modulate:a", 0.0, life * 0.6)
		tween.chain().tween_callback(sprite.queue_free)


func _spawn_smoke_stream(radius: float, linger: float, tint: Color) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.35
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(func() -> void:
		_spawn_smoke(1, radius * 0.15, radius * 0.5, 1.6, 0.4, tint)
	)
	timer.start()
	get_tree().create_timer(linger, false).timeout.connect(timer.queue_free)


func _play_zone_ring(radius: float, color: Color, linger: float) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.closed = true
	var segments: int = 32
	var points: PackedVector2Array = []
	for i in range(segments):
		var a: float = TAU * float(i) / segments
		points.append(Vector2(cos(a), sin(a)) * radius)
	line.points = points
	line.modulate.a = 0.0
	add_child(line)

	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 1.0, 0.25)
	tween.tween_interval(maxf(linger - 0.5, 0.0))
	tween.tween_property(line, "modulate:a", 0.0, 0.35)
	tween.tween_callback(line.queue_free)


func _play_ring(target_radius: float, color: Color, duration: float) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.closed = true
	add_child(line)

	var segments: int = 28
	var set_radius := func(r: float) -> void:
		var points: PackedVector2Array = []
		for i in range(segments):
			var a: float = TAU * float(i) / segments
			points.append(Vector2(cos(a), sin(a)) * r)
		line.points = points
	set_radius.call(0.01)

	var tween := create_tween()
	tween.tween_method(set_radius, 0.01, target_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(line, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)
	tween.tween_callback(line.queue_free)


func _spawn_radiating_lines(count: int, length: float, color: Color, width: float, life: float) -> void:
	for i in range(count):
		var angle: float = TAU * float(i) / count + randf_range(-0.12, 0.12)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var perpendicular: Vector2 = dir.rotated(PI / 2.0)
		var segments: int = 3
		var points: PackedVector2Array = []
		for s in range(segments + 1):
			var t: float = float(s) / segments
			var base: Vector2 = dir * length * t
			var jitter: float = 0.0 if (s == 0 or s == segments) else randf_range(-length * 0.06, length * 0.06)
			points.append(base + perpendicular * jitter)

		var line := Line2D.new()
		line.width = width
		line.default_color = color
		line.points = points
		add_child(line)

		var tween := create_tween()
		tween.tween_interval(life * 0.5)
		tween.tween_property(line, "modulate:a", 0.0, life * 0.5)
		tween.tween_callback(line.queue_free)
