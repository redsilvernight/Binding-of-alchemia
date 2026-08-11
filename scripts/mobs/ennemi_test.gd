extends EnemyBase
@export var speed: float = 150.0
@export var damage: float = 5.0
var target: Node2D = null

## Démarre en Idle : Room active l'ennemi via `active` (cf. EnemyBase), lu
## par EnemyStateIdle qui transitionne vers Chase — voir scripts/enemies/states/.
var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateChase.new(self)))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)

func _update_target() -> void:
	target = _closest_living_player()

func _on_collision_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		body.take_damage(damage)
