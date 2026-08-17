## Ennemi "chargeur" (Phase 9.2, 3e passe, nouveau comportement) : approche
## le joueur normalement, puis à portée de charge marque un temps d'arrêt
## télégraphié (le joueur voit le coup venir) avant de foncer en ligne
## droite à vitesse très supérieure. Les dégâts de contact restent gérés par
## CollisionArea comme les autres types mêlée (ennemi_test.gd/enemy_erratic.gd)
## -- seule la trajectoire/vitesse change ici. La direction de charge est
## figée au moment du télégraphe, pas recalculée pendant le dash (même
## raisonnement que le tir du joueur figé au lancement du swing, Phase 9.3) :
## un dash engagé va jusqu'au bout même si le joueur esquive entre-temps.
## Le script concret doit exposer `speed` (float), `dash_speed` (float),
## `charge_range` (float), `telegraph_duration` (float), `dash_duration`
## (float), `cooldown_duration` (float), `target` (Node2D), `_update_target()`
## et `_play_telegraph_animation(direction)`.
class_name EnemyStateCharge
extends EnemyState

enum Phase { APPROACH, TELEGRAPH, DASH, COOLDOWN }

var _phase: int = Phase.APPROACH
var _timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO

func physics_process(delta: float) -> void:
	enemy._update_target()
	if not enemy.target or not is_instance_valid(enemy.target):
		enemy.move(Vector2.ZERO, 0.0)
		return
	match _phase:
		Phase.APPROACH:
			_process_approach()
		Phase.TELEGRAPH:
			_process_telegraph(delta)
		Phase.DASH:
			_process_dash(delta)
		Phase.COOLDOWN:
			_process_cooldown(delta)

func _process_approach() -> void:
	var to_target: Vector2 = enemy.target.global_position - enemy.global_position
	if to_target.length() <= enemy.charge_range:
		_dash_direction = to_target.normalized()
		enemy.move(Vector2.ZERO, 0.0)
		enemy._play_telegraph_animation(_dash_direction)
		_timer = enemy.telegraph_duration
		_phase = Phase.TELEGRAPH
		return
	# Approche via pathfinding (Phase 11.1) ; le dash lui-même reste en ligne
	# droite figée (voir _process_dash) -- un charge engagé va jusqu'au bout,
	# contournement d'obstacle ou non.
	enemy.move_toward_position(enemy.target.global_position, enemy.speed)

func _process_telegraph(delta: float) -> void:
	enemy.move(Vector2.ZERO, 0.0)
	_timer -= delta
	if _timer <= 0.0:
		_timer = enemy.dash_duration
		_phase = Phase.DASH

func _process_dash(delta: float) -> void:
	enemy.move(_dash_direction, enemy.dash_speed)
	_timer -= delta
	if _timer <= 0.0:
		_timer = enemy.cooldown_duration
		_phase = Phase.COOLDOWN

func _process_cooldown(delta: float) -> void:
	enemy.move(Vector2.ZERO, 0.0)
	_timer -= delta
	if _timer <= 0.0:
		_phase = Phase.APPROACH
