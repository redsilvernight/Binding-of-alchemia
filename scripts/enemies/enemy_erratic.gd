extends EnemyBase
## Type "mobile erratique" (Phase 7.3) : erre au hasard (EnemyStateWander)
## plutôt que de poursuivre le joueur, ne blesse qu'au contact via
## CollisionArea (même mécanisme que EnnemyTest/mêlée).
@export var speed: float = 130.0
@export var damage: float = 4.0
@onready var sprite: AnimatedSprite2D = $Sprite2D

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateWander.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (Phase 9.3, même
	# raison que ennemi_test.gd/enemy_ranged.gd) : seul le nom de l'animation
	# est répliqué, chaque instance avance ses propres frames localement.
	sprite.play()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

## Hôte-only comme le reste de _physics_process (host-authoritative). Pas de
## sprite Idle : EnemyStateWander bouge en permanence tant que l'ennemi est
## actif (change juste de direction périodiquement), jamais de vitesse nulle
## comme peut l'avoir EnemyStateRangedAttack -- même raisonnement que le
## mêlée (ennemi_test.gd), qui n'a pas d'idle non plus.
func _update_facing(direction: Vector2) -> void:
	# Ne pas couper l'animation d'attaque en cours (cf. _on_collision_area_body_entered).
	if sprite.animation.begins_with("attack") and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _on_collision_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		body.take_damage(damage)
		_play_attack_animation(body.global_position - global_position)

## Même raisonnement que ennemi_test.gd::_play_attack_animation.
func _play_attack_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))
