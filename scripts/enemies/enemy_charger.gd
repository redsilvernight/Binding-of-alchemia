extends EnemyBase
## Type "chargeur" (Phase 9.2, 3e passe, nouveau comportement) : approche
## normalement puis, à portée, télégraphie un temps d'arrêt avant de foncer
## en ligne droite à vitesse très supérieure (EnemyStateCharge). Les dégâts
## restent au contact via CollisionArea comme les autres mêlées
## (ennemi_test.gd/enemy_erratic.gd) -- seule la trajectoire/vitesse diffère.
@export var speed: float = 110.0
@export var dash_speed: float = 650.0
@export var damage: float = 18.0
@export var charge_range: float = 380.0
@export var telegraph_duration: float = 0.6
@export var dash_duration: float = 0.45
@export var cooldown_duration: float = 1.2
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
## Même raisonnement que ennemi_test.gd (Phase 9.3, hit/mort).
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateCharge.new(self)))
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

func _update_facing(direction: Vector2) -> void:
	# Ne pas couper le télégraphe ("attack-*") ou un hit en cours -- même
	# garde que les autres types (cf. enemy_ranged.gd).
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	_last_facing_direction = direction
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

## Appelée par EnemyStateCharge juste avant la pause télégraphiée -- prévient
## le joueur qu'un coup arrive. Réutilise le jeu d'animations "attack-*" déjà
## généré plutôt qu'une nouvelle catégorie d'anim dédiée (coût d'art, cf.
## roadmap 9.2 -- décision de report des 6 ennemis avant cette passe).
func _play_telegraph_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	_last_facing_direction = direction
	sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))

func _on_collision_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("Players"):
		body.take_damage(damage)
		AudioManager.play_sfx("enemy_attack_melee")

## Même raisonnement que ennemi_test.gd::_on_health_changed.
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
