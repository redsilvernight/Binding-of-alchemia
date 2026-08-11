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

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateRangedAttack.new(self)))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)

func _update_target() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	var closest: Node2D = null
	var closest_distance: float = INF
	for player in players:
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = player
	target = closest

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
