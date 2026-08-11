## Ne fait rien tant que la Room n'a pas activé l'ennemi (cf. EnemyBase.active,
## Room._activate_enemies_delayed) — transitionne vers l'état passé en
## paramètre dès que c'est le cas. `active` ne repasse jamais à false, donc
## cette transition est unique et irréversible : comportement identique à
## l'ancien `if not active: return`.
## `next_state` paramétrable (Phase 7.3) : chaque type d'ennemi choisit son
## propre comportement post-activation (Chase, Wander, RangedAttack...) sans
## dupliquer cet état.
class_name EnemyStateIdle
extends EnemyState

var _next_state: EnemyState

func _init(p_enemy: Node, next_state: EnemyState) -> void:
	super(p_enemy)
	_next_state = next_state

func physics_process(_delta: float) -> void:
	if enemy.active:
		enemy.state_machine.transition_to(_next_state)
