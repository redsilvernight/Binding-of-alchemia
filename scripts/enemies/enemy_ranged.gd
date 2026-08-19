extends EnemyBase
## Type "distance" (Phase 7.3) : garde ses distances et tire des projectiles
## (EnemyStateRangedAttack) plutôt que de foncer sur le joueur. Réutilise la
## classe Bullet générique (scripts/projectiles/bullet.gd) via une scène
## séparée (enemy_projectile.tscn) : layer/mask différents des balles du
## joueur pour toucher les joueurs et non les autres ennemis.
@export var speed: float = 90.0
@export var damage: float = 8.0
@export var preferred_range: float = 200.0
@export var attack_range: float = 450.0
@export var fire_cooldown: float = 1.5
@export var projectile_speed: float = 320.0
## Son de TIR (retour utilisateur : un seul son générique "ignoble" partagé
## par tous les ennemis à distance) -- surchargé par variante directement dans
## chaque .tscn (enemy_ranged_gunner.tscn, etc.), même convention déjà utilisée
## pour ambient_sfx_key juste au-dessus dans EnemyBase. Valeur par défaut =
## conservée pour enemy_ranged.tscn (base), qui n'a pas de son propre.
@export var attack_sfx_key: String = "enemy_attack_ranged"
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
## Dernière direction non-nulle : la vitesse retombe à zéro pendant la phase
## "arrêté et tire" de EnemyStateRangedAttack, mais l'orientation doit rester
## celle du dernier déplacement plutôt que de figer une frame de marche.
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateRangedAttack.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (Phase 9.3, même
	# raison que ennemi_test.gd/Player) : seul le nom de l'animation est
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

## Hôte-only comme le reste de _physics_process (host-authoritative).
## Bascule idle/walk selon le mouvement réel (vitesse quasi nulle pendant la
## phase "arrêté et tire" de EnemyStateRangedAttack), mais l'orientation
## utilise toujours la dernière direction de déplacement connue, pas la
## vitesse instantanée -- sinon l'ennemi se réoriente vers Vector2.DOWN par
## défaut dès qu'il s'arrête.
func _update_facing(direction: Vector2) -> void:
	# Ne pas couper l'animation d'attaque en cours (cf. fire_at) : sinon
	# EnemyStateRangedAttack qui immobilise l'ennemi pendant le tir
	# (enemy.move(Vector2.ZERO, 0.0)) la remplace par idle- dès la frame
	# suivante.
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	var is_moving := direction.length() > 0.001
	if is_moving:
		_last_facing_direction = direction
	var prefix := "walk-" if is_moving else "idle-"
	var anim_name := StringName(prefix + FacingDirection.label_for(_last_facing_direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

func fire_at(p_target: Node2D) -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	var fire_direction := global_position.direction_to(p_target.global_position)
	sprite.play(StringName("attack-" + FacingDirection.label_for(fire_direction)))
	game.request_enemy_projectile({
		"scene_path": "res://scenes/enemies/enemy_projectile.tscn",
		"damage": damage,
		"speed": projectile_speed,
		"lifetime": 2.0,
		"trajectory": Bullet.TrajectoryType.LINEAR,
		"from_position": global_position,
		"direction": global_position.direction_to(p_target.global_position),
		"attack_sfx_key": attack_sfx_key,
	})

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
