extends EnemyBase
## Boss (Phase 7.4) : 2 phases sur la FSM commune, sans nouvel état.
## Phase 1 (>50% PV) : EnemyStateChase + dégâts de contact via CollisionArea,
## même mécanisme que ennemi_test.gd/enemy_erratic.gd. Phase 2 (<=50% PV) :
## EnemyStateRangedAttack + tir de projectile, même mécanisme que
## enemy_ranged.gd. Le changement de phase est une simple transition FSM
## déclenchée par un seuil de vie dans take_damage() : aucun nouvel état
## n'est nécessaire, ce qui valide l'objectif de la 7.4 (la FSM commune monte
## en complexité sans réécriture).
@export var boss_max_lifepoint: float = 180.0
@export var speed: float = 110.0
@export var contact_damage: float = 12.0
@export var preferred_range: float = 220.0
@export var attack_range: float = 500.0
@export var fire_cooldown: float = 1.0
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 340.0
var target: Node2D = null

var state_machine: EnemyStateMachine
var _phase: int = 1

func _ready() -> void:
	max_lifepoint = boss_max_lifepoint
	super()
	add_to_group("Boss")
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateChase.new(self)))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)

func _update_target() -> void:
	target = _closest_living_player()

## Dégâts de contact réservés à la phase 1 : en phase 2 le boss garde ses
## distances (EnemyStateRangedAttack), le contact ne devrait plus se
## produire normalement, mais la garde évite un coup gratuit si un joueur
## fonce dedans pendant la transition.
func _on_collision_area_body_entered(body: Node2D) -> void:
	if _phase != 1:
		return
	if body.is_in_group("Players"):
		body.take_damage(contact_damage)

func fire_at(p_target: Node2D) -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	game.request_enemy_projectile({
		"scene_path": "res://scenes/enemies/enemy_projectile.tscn",
		"damage": projectile_damage,
		"speed": projectile_speed,
		"lifetime": 2.0,
		"trajectory": Bullet.TrajectoryType.LINEAR,
		"from_position": global_position,
		"direction": global_position.direction_to(p_target.global_position),
	})

func take_damage(degat: float) -> void:
	super(degat)
	if not multiplayer.is_server():
		return
	if _phase == 1 and not is_dead and lifepoint <= max_lifepoint / 2.0:
		_phase = 2
		state_machine.transition_to(EnemyStateRangedAttack.new(self))
		_rpc_notify_phase.rpc(2)

## Cosmétique uniquement (teinte du sprite) : la FSM ne tourne déjà que
## côté hôte (cf. _physics_process), ce RPC synchronise juste le rendu chez
## tous les pairs quand la phase change, aucune décision de jeu dedans.
@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_phase(phase: int) -> void:
	if phase == 2:
		modulate = Color(1.0, 0.55, 0.55)
