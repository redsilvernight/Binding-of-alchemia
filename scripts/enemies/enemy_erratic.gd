extends EnemyBase
## Type "mobile erratique" (Phase 7.3) : erre au hasard (EnemyStateWander)
## plutôt que de poursuivre le joueur, ne blesse qu'au contact via
## CollisionArea (même mécanisme que EnnemyTest/mêlée).
@export var speed: float = 130.0
@export var damage: float = 4.0

var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateWander.new(self)))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	state_machine.physics_process(delta)

func _on_collision_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		body.take_damage(damage)
