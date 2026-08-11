## Ne fait rien tant que la Room n'a pas activé l'ennemi (cf. EnemyBase.active,
## Room._activate_enemies_delayed) — transitionne vers Chase dès que c'est le
## cas. `active` ne repasse jamais à false, donc cette transition est unique
## et irréversible : comportement identique à l'ancien `if not active: return`.
class_name EnemyStateIdle
extends EnemyState

func physics_process(_delta: float) -> void:
	if enemy.active:
		enemy.state_machine.transition_to(EnemyStateChase.new(enemy))
