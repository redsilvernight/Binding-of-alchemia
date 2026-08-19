extends EnemyBase
## Boss (Phase 7.4) : 2 phases sur la FSM commune, sans nouvel état.
## Phase 1 (>50% PV) : EnemyStateChase + dégâts de contact via CollisionArea,
## même mécanisme que ennemi_test.gd/enemy_erratic.gd. Phase 2 (<=50% PV) :
## EnemyStateRangedAttack + tir de projectile, même mécanisme que
## enemy_ranged.gd. Le changement de phase est une simple transition FSM
## déclenchée par un seuil de vie dans take_damage() : aucun nouvel état
## n'est nécessaire, ce qui valide l'objectif de la 7.4 (la FSM commune monte
## en complexité sans réécriture).
@export var boss_max_lifepoint: float = 180.0
@export var speed: float = 110.0
@export var contact_damage: float = 12.0
@export var preferred_range: float = 220.0
@export var attack_range: float = 500.0
@export var fire_cooldown: float = 1.0
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 340.0
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
## Dernière direction non-nulle (Phase 9.3) : la vitesse retombe à zéro
## pendant la phase "arrêté et tire" de EnemyStateRangedAttack (phase 2),
## mais l'orientation doit rester celle du dernier déplacement -- même
## raison que enemy_ranged.gd.
var _last_facing_direction: Vector2 = Vector2.DOWN

var state_machine: EnemyStateMachine
var _phase: int = 1

func _ready() -> void:
	max_lifepoint = boss_max_lifepoint
	super()
	add_to_group("Boss")
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateChase.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (Phase 9.3, même
	# raison que les autres ennemis) : seul le nom de l'animation est
	# répliqué, chaque instance avance ses propres frames localement.
	sprite.play()
	health_changed.connect(_on_health_changed)
	died.connect(_on_death_animation)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

## Hôte-only comme le reste de _physics_process (host-authoritative).
## Bascule idle/walk selon le mouvement réel -- phase 1 (EnemyStateChase)
## bouge en permanence donc reste sur walk-*, phase 2
## (EnemyStateRangedAttack) alterne walk-*/idle-* selon qu'il se
## positionne ou qu'il s'arrête pour tirer.
func _update_facing(direction: Vector2) -> void:
	# Ne pas couper une animation d'attaque ou de hit en cours (cf.
	# _on_collision_area_body_entered phase 1 / fire_at phase 2 / _on_health_changed)
	# — même raisonnement que enemy_ranged.gd.
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	var is_moving := direction.length() > 0.001
	if is_moving:
		_last_facing_direction = direction
	var prefix := "walk-" if is_moving else "idle-"
	var anim_name := StringName(prefix + FacingDirection.label_for(_last_facing_direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

## Dégâts de contact réservés à la phase 1 : en phase 2 le boss garde ses
## distances (EnemyStateRangedAttack), le contact ne devrait plus se
## produire normalement, mais la garde évite un coup gratuit si un joueur
## fonce dedans pendant la transition.
func _on_collision_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if _phase != 1:
		return
	if body.is_in_group("Players"):
		body.take_damage(contact_damage)
		var direction: Vector2 = body.global_position - global_position
		if direction.length() >= 0.001:
			sprite.play(StringName("attack-melee-" + FacingDirection.label_for(direction)))
			AudioManager.play_sfx("enemy_attack_melee")

func fire_at(p_target: Node2D) -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	var fire_direction := global_position.direction_to(p_target.global_position)
	sprite.play(StringName("attack-ranged-" + FacingDirection.label_for(fire_direction)))
	game.request_enemy_projectile({
		"scene_path": "res://scenes/enemies/enemy_projectile.tscn",
		"damage": projectile_damage,
		"speed": projectile_speed,
		"lifetime": 2.0,
		"trajectory": Bullet.TrajectoryType.LINEAR,
		"from_position": global_position,
		"direction": global_position.direction_to(p_target.global_position),
		"attack_sfx_key": "boss_attack_ranged",
	})

func take_damage(degat: float) -> void:
	super(degat)
	if not multiplayer.is_server():
		return
	if _phase == 1 and not is_dead and lifepoint <= max_lifepoint / 2.0:
		_phase = 2
		state_machine.transition_to(EnemyStateRangedAttack.new(self))
		_rpc_notify_phase.rpc(2)

## Cosmétique uniquement (teinte du sprite) : la FSM ne tourne déjà que
## côté hôte (cf. _physics_process), ce RPC synchronise juste le rendu chez
## tous les pairs quand la phase change, aucune décision de jeu dedans.
@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_phase(phase: int) -> void:
	if phase == 2:
		modulate = Color(1.0, 0.55, 0.55)
		AudioManager.play_sfx("boss_phase")

## Même raisonnement que ennemi_test.gd::_on_health_changed -- un seul jeu de
## sprites hit/death, pas de variante par phase (même décision que pour
## attack, cf. direction_artistique.md : create_character_state jugé trop
## coûteux pour la phase 2, la teinte rouge suffit à la signaler).
func _on_health_changed(_max_lifepoint: float, lifepoint: float) -> void:
	if lifepoint <= 0:
		return
	if sprite.animation.begins_with("attack"):
		return
	sprite.play(StringName("hit-" + FacingDirection.label_for(_last_facing_direction)))

func _on_death_animation() -> void:
	sprite.play(StringName("death-" + FacingDirection.label_for(_last_facing_direction)))

func _die_and_free() -> void:
	await sprite.animation_finished
	if is_instance_valid(self):
		queue_free()

func _get_death_sfx_key() -> String:
	return "boss_death"
