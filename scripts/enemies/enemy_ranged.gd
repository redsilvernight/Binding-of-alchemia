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
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateRangedAttack.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (Phase 9.3, même
	# raison que ennemi_test.gd/Player) : seul le nom de l'animation est
	# répliqué, chaque instance avance ses propres frames localement.
	sprite.play()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

## Hôte-only comme le reste de _physics_process (host-authoritative). Pas de
## sprite Idle : à l'arrêt (le cas EnemyStateRangedAttack qui tire sans
## bouger), le sprite garde sa dernière frame de marche -- direction
## approximative correcte dans la plupart des cas puisque l'ennemi vient de
## se déplacer vers/depuis la cible juste avant de s'arrêter pour tirer.
func _update_facing(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

func fire_at(p_target: Node2D) -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	game.request_enemy_projectile({
		"scene_path": "res://scenes/enemies/enemy_projectile.tscn",
		"damage": damage,
		"speed": projectile_speed,
		"lifetime": 2.0,
		"trajectory": Bullet.TrajectoryType.LINEAR,
		"from_position": global_position,
		"direction": global_position.direction_to(p_target.global_position),
	})
