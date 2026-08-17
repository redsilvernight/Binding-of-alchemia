## Ennemi "soigneur" (Phase 9.2, 3e passe, nouveau comportement) : fuit le
## joueur le plus proche s'il s'approche trop, sinon se rapproche de l'allié
## vivant le plus blessé à portée de recherche et le soigne à intervalle
## régulier une fois à portée de soin. Ne blesse jamais directement -- sa
## seule menace est indirecte (prolonge la vie des autres ennemis de la
## salle), donc une cible naturellement prioritaire pour le joueur.
## Le script concret doit exposer `speed` (float), `heal_cooldown` (float),
## `heal_range` (float), `flee_range` (float), `heal_target` (Node2D),
## `_update_heal_target()` (écrit `heal_target`) et `heal_at(target)`.
class_name EnemyStateSupport
extends EnemyState

var _time_until_heal: float = 0.0

func enter() -> void:
	_time_until_heal = enemy.heal_cooldown

func physics_process(delta: float) -> void:
	var player: Node2D = enemy._closest_living_player()
	if player and enemy.global_position.distance_to(player.global_position) < enemy.flee_range:
		enemy.move(enemy.global_position.direction_to(player.global_position) * -1.0, enemy.speed)
		return
	enemy._update_heal_target()
	if not enemy.heal_target or not is_instance_valid(enemy.heal_target):
		enemy.move(Vector2.ZERO, 0.0)
		return
	var to_target: Vector2 = enemy.heal_target.global_position - enemy.global_position
	var distance: float = to_target.length()
	if distance > enemy.heal_range:
		enemy.move_toward_position(enemy.heal_target.global_position, enemy.speed)
		return
	enemy.move(Vector2.ZERO, 0.0)
	_time_until_heal -= delta
	if _time_until_heal <= 0.0:
		enemy.heal_at(enemy.heal_target)
		_time_until_heal = enemy.heal_cooldown
