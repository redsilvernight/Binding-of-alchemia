class_name Character
extends CharacterBody2D

signal health_changed(max_lifepoint: float, lifepoint: float)
@export var max_lifepoint: float = 20.0
var lifepoint: float
var is_dead: bool = false
var can_take_damage: bool = true

func _ready() -> void:
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
		is_dead = true
		kill()
	else:
		_start_invulnerability()

## Point d'extension : ne fait rien par défaut. Les sous-classes qui veulent
## des i-frames (ex: Player, via son DamageTimer) surchargent cette méthode.
func _start_invulnerability() -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func _update_health(p_max_lifepoint: float, p_lifepoint: float) -> void:
	max_lifepoint = p_max_lifepoint
	lifepoint = p_lifepoint
	health_changed.emit(max_lifepoint, lifepoint)

func kill() -> void:
	if multiplayer.is_server():
		queue_free()
