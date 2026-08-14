extends EnemyBase
@export var speed: float = 150.0
@export var damage: float = 5.0
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D

## Démarre en Idle : Room active l'ennemi via `active` (cf. EnemyBase), lu
## par EnemyStateIdle qui transitionne vers Chase — voir scripts/enemies/states/.
var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateChase.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (même raison que
	# Player._ready, Phase 9.3) : seul le nom de l'animation est répliqué,
	# chaque instance avance ses propres frames localement.
	sprite.play()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

## Hôte-only comme le reste de _physics_process (les ennemis sont
## host-authoritative, cf. architecture_reseau.md) -- répliqué aux clients
## via "Sprite2D:animation" sur le MultiplayerSynchronizer existant, même
## mécanisme que .:position. Pas de sprite Idle dédié pour l'instant : à
## vitesse nulle (avant activation ou bloqué), le sprite garde juste sa
## dernière frame de marche.
func _update_facing(direction: Vector2) -> void:
	# Ne pas couper l'animation d'attaque en cours (cf. _on_collision_area_body_entered) :
	# sinon la reprise du mouvement l'écrase dès la frame suivante.
	if sprite.animation.begins_with("attack") and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

func _on_collision_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		body.take_damage(damage)
		_play_attack_animation(body.global_position - global_position)

## Direction vers la cible plutôt que la dernière direction de déplacement :
## simple et toujours valide, pas besoin de tracker un _last_facing_direction
## rien que pour ce cas (contrairement à enemy_ranged.gd/boss_01.gd où la
## vitesse retombe à zéro pendant l'attaque).
func _play_attack_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))
