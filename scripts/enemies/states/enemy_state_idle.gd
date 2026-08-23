class_name EnemyStateIdle
extends EnemyState

var _next_state: EnemyState

func _init(p_enemy: Node, next_state: EnemyState) -> void:
	super(p_enemy)
	_next_state = next_state

func physics_process(_delta: float) -> void:
	if enemy.active:
		enemy.state_machine.transition_to(_next_state)
