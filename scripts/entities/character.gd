class_name Character
extends CharacterBody2D

signal health_changed(max_lifepoint: float, lifepoint: float)
signal healed(max_lifepoint: float, lifepoint: float)
signal died
@export var max_lifepoint: float = 20.0
var lifepoint: float
var is_dead: bool = false
var can_take_damage: bool = true

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	lifepoint = max_lifepoint

func move(direction: Vector2, speed: float) -> void:
	velocity = direction * speed
	move_and_slide()

func take_damage(degat: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	if not can_take_damage:
		return
	lifepoint -= degat
	_update_health.rpc(max_lifepoint, lifepoint)
	if lifepoint <= 0:
		kill()
	else:
		_start_invulnerability()

func heal(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	lifepoint = min(lifepoint + amount, max_lifepoint)
	_update_heal.rpc(lifepoint)

@rpc("any_peer", "call_local", "reliable")
func _update_heal(p_lifepoint: float) -> void:
	lifepoint = p_lifepoint
	healed.emit(max_lifepoint, lifepoint)

func _start_invulnerability() -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func _update_health(p_max_lifepoint: float, p_lifepoint: float) -> void:
	var previous_lifepoint: float = lifepoint
	max_lifepoint = p_max_lifepoint
	lifepoint = p_lifepoint
	health_changed.emit(max_lifepoint, lifepoint)
	if lifepoint < previous_lifepoint:
		AudioManager.play_sfx_at(_get_hit_sfx_key(), global_position)
		_flash_hit()
	if lifepoint <= 0 and not is_dead:
		is_dead = true
		died.emit()
		AudioManager.play_sfx_at(_get_death_sfx_key(), global_position)

func kill() -> void:
	if multiplayer.is_server():
		_die_and_free()

func _die_and_free() -> void:
	queue_free()

func _get_death_sfx_key() -> String:
	return "death"

func _get_hit_sfx_key() -> String:
	return "hit"

func _flash_hit() -> void:
	var sprite: CanvasItem = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var base_modulate: Color = sprite.modulate
	var tween: Tween = create_tween()
	sprite.modulate = base_modulate * Color(1.6, 1.6, 1.6, 1.0)
	tween.tween_property(sprite, "modulate", base_modulate, 0.12)
