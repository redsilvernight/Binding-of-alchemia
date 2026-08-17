## Garde ses distances et tire un projectile par intervalle tant que le
## joueur ciblé reste à portée (Phase 7.3). Recule si trop proche, avance si
## trop loin, sinon s'arrête et tire — pas d'état "Retreat" séparé, reculer
## est juste un des trois cas de cette même boucle de positionnement.
## Le script concret doit exposer `target` (Node2D), `_update_target()`,
## `speed`, `preferred_range`, `attack_range`, `fire_cooldown` et `fire_at()`.
class_name EnemyStateRangedAttack
extends EnemyState

var _time_until_shot: float = 0.0

func enter() -> void:
	_time_until_shot = enemy.fire_cooldown

func physics_process(delta: float) -> void:
	enemy._update_target()
	if not enemy.target or not is_instance_valid(enemy.target):
		return
	var to_target: Vector2 = enemy.target.global_position - enemy.global_position
	var distance: float = to_target.length()
	if distance < enemy.preferred_range:
		# Recul en ligne droite, pas via nav_agent : fuir un point n'est pas du
		# pathfinding vers une destination (Phase 11.1).
		enemy.move(-to_target.normalized(), enemy.speed)
	elif distance > enemy.attack_range:
		enemy.move_toward_position(enemy.target.global_position, enemy.speed)
	else:
		enemy.move(Vector2.ZERO, 0.0)
		_time_until_shot -= delta
		if _time_until_shot <= 0.0:
			enemy.fire_at(enemy.target)
			_time_until_shot = enemy.fire_cooldown
