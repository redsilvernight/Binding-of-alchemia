extends EnemyBase
## Type "soigneur" (Phase 9.2, 3e passe, nouveau comportement) : ne blesse
## jamais directement (pas de CollisionArea, contrairement aux mêlées/erratiques)
## -- fuit le joueur le plus proche et soigne à intervalle l'allié vivant le
## plus blessé à portée (EnemyStateSupport). Cible naturellement prioritaire
## pour le joueur : le laisser vivant prolonge la vie de tous les autres
## ennemis de la salle.
@export var speed: float = 140.0
@export var heal_amount: float = 8.0
@export var heal_cooldown: float = 3.0
@export var heal_range: float = 260.0
@export var flee_range: float = 300.0
var heal_target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
## Même raisonnement que enemy_ranged.gd (Phase 9.3, hit/mort) : la vitesse
## retombe à zéro pendant la fuite/le soin, l'orientation doit rester celle
## du dernier déplacement.
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateSupport.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (même raison que
	# les autres types d'ennemi, Phase 9.3) : seul le nom de l'animation est
	# répliqué, chaque instance avance ses propres frames localement.
	sprite.play()
	health_changed.connect(_on_health_changed)
	died.connect(_on_death_animation)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

## Même raisonnement que enemy_ranged.gd::_update_facing (idle/walk selon le
## mouvement réel, orientation figée sur la dernière direction connue).
func _update_facing(direction: Vector2) -> void:
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	var is_moving := direction.length() > 0.001
	if is_moving:
		_last_facing_direction = direction
	var prefix := "walk-" if is_moving else "idle-"
	var anim_name := StringName(prefix + FacingDirection.label_for(_last_facing_direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

## Allié vivant le plus blessé en proportion (pas juste le plus proche), pour
## prioriser celui qui a le plus besoin de soin quand plusieurs sont à
## portée de recherche -- portée illimitée volontairement (une salle contient
## peu d'ennemis à la fois, cf. spawn_table.gd min_count/max_count).
func _update_heal_target() -> void:
	var best: Node2D = null
	var best_ratio: float = 1.0
	for other in get_tree().get_nodes_in_group("Enemies"):
		if other == self or other.is_dead:
			continue
		if other.lifepoint >= other.max_lifepoint:
			continue
		var ratio: float = other.lifepoint / other.max_lifepoint
		if ratio < best_ratio:
			best_ratio = ratio
			best = other
	heal_target = best

func heal_at(p_target: Node2D) -> void:
	p_target.heal(heal_amount)
	var direction: Vector2 = global_position.direction_to(p_target.global_position)
	if direction.length() >= 0.001:
		sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))

## Même raisonnement que enemy_ranged.gd::_on_health_changed.
func _on_health_changed(_max_lifepoint: float, lifepoint: float) -> void:
	if lifepoint <= 0:
		return
	if sprite.animation.begins_with("attack"):
		return
	sprite.play(StringName("hit-" + FacingDirection.label_for(_last_facing_direction)))

func _on_death_animation() -> void:
	sprite.play(StringName("death-" + FacingDirection.label_for(_last_facing_direction)))

func _die_and_free() -> void:
	await sprite.animation_finished
	if is_instance_valid(self):
		queue_free()
