extends Node2D
class_name AreaEffectVfx

const TEXTURE_SIZE: float = 128.0

@export var texture_feu: Texture2D
@export var texture_glace: Texture2D
@export var texture_poison: Texture2D
@export var texture_electrique: Texture2D
@export var texture_explosif: Texture2D


func play(type_alchimie: Ingredient.TypeAlchimie, radius: float, duration: float) -> void:
	match type_alchimie:
		Ingredient.TypeAlchimie.FEU:
			_play_burst(texture_feu, radius * 0.4, 0.5, 0.22, 0.3)
		Ingredient.TypeAlchimie.GLACE:
			_play_burst(texture_glace, radius * 0.45, 0.45, 0.3, 0.55)
		Ingredient.TypeAlchimie.EXPLOSIF:
			_play_burst(texture_explosif, radius * 0.5, 0.55, 0.14, 0.22)
		Ingredient.TypeAlchimie.POISON:
			_play_lingering_cloud(radius, duration)
		Ingredient.TypeAlchimie.ELECTRIQUE:
			_play_lightning_chain(radius)
		_:
			queue_free()


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
	tween.tween_callback(queue_free)


func _play_lingering_cloud(radius: float, duration: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture_poison
	sprite.modulate.a = 0.0
	add_child(sprite)

	var target_scale: float = radius * 2.0 / TEXTURE_SIZE
	sprite.scale = Vector2.ONE * target_scale * 0.75

	var linger: float = maxf(duration, 1.2)

	var intro := create_tween()
	intro.tween_property(sprite, "modulate:a", 0.22, 0.4)
	intro.tween_callback(func() -> void:
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(sprite, "modulate:a", 0.14, 0.9).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(sprite, "modulate:a", 0.22, 0.9).set_trans(Tween.TRANS_SINE)
		var linger_timer := get_tree().create_timer(linger, false)
		linger_timer.timeout.connect(func() -> void:
			pulse.kill()
			var outro := create_tween()
			outro.tween_property(sprite, "modulate:a", 0.0, 0.4)
			outro.tween_callback(queue_free)
		)
	)


const LIGHTNING_SEGMENTS: int = 5
const LIGHTNING_JITTER: float = 10.0
const LIGHTNING_FLASH_DURATION: float = 0.16

func _play_lightning_chain(radius: float) -> void:
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	var hit_any: bool = false
	for enemy in tree.get_nodes_in_group("Enemies"):
		if not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			_draw_bolt(enemy.global_position)
			hit_any = true
	if not hit_any:
		_play_burst(texture_electrique, radius * 0.25, 0.5, 0.12, 0.15)
		return
	get_tree().create_timer(LIGHTNING_FLASH_DURATION + 0.05, false).timeout.connect(queue_free)


func _draw_bolt(target_global_position: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2.5
	line.default_color = Color(1.0, 0.95, 0.45, 0.85)
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
