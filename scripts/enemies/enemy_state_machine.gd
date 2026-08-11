## FSM minimale (Phase 7.2) : pas de noeuds enfants, juste des objets
## EnemyState enchaînés à la main — suffisant tant qu'aucun état n'a besoin
## d'être un noeud de la scène (timers, animations...) ; à revoir si 7.3/7.4
## en ont besoin.
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
