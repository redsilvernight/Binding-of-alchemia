class_name EnemyStateMachine
extends RefCounted

var _current_state: EnemyState

func _init(initial_state: EnemyState) -> void:
	_current_state = initial_state
	_current_state.enter()

func transition_to(new_state: EnemyState) -> void:
	_current_state.exit()
	_current_state = new_state
	_current_state.enter()

func physics_process(delta: float) -> void:
	_current_state.physics_process(delta)
