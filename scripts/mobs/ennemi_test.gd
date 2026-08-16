extends EnemyBase
@export var speed: float = 150.0
@export var damage: float = 5.0
var target: Node2D = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
## Dernière direction non-nulle (Phase 9.3, hit/mort) : direction de marche à
## l'instant où l'ennemi est touché ou meurt, pour choisir l'anim hit-*/death-*
## -- même raisonnement que enemy_ranged.gd/boss_01.gd (la vitesse retombe à
## zéro dès que l'état "chase" s'arrête).
var _last_facing_direction: Vector2 = Vector2.DOWN

## Démarre en Idle : Room active l'ennemi via `active` (cf. EnemyBase), lu
## par EnemyStateIdle qui transitionne vers Chase — voir scripts/enemies/states/.
var state_machine: EnemyStateMachine

func _ready() -> void:
	super()
	state_machine = EnemyStateMachine.new(EnemyStateIdle.new(self, EnemyStateChase.new(self)))
	# Doit tourner sur tous les pairs, pas seulement l'hôte (même raison que
	# Player._ready, Phase 9.3) : seul le nom de l'animation est répliqué,
	# chaque instance avance ses propres frames localement.
	sprite.play()
	# Dérivées identiquement sur tous les pairs via _update_health (Character,
	# call_local RPC) -- pas besoin de RPC dédiée comme pour l'attaque du
	# joueur (celle-là dépend d'un input local, pas d'un état déjà répliqué).
	health_changed.connect(_on_health_changed)
	died.connect(_on_death_animation)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	state_machine.physics_process(delta)
	_update_facing(velocity)

## Hôte-only comme le reste de _physics_process (les ennemis sont
## host-authoritative, cf. architecture_reseau.md) -- répliqué aux clients
## via "Sprite2D:animation" sur le MultiplayerSynchronizer existant, même
## mécanisme que .:position. Pas de sprite Idle dédié pour l'instant : à
## vitesse nulle (avant activation ou bloqué), le sprite garde juste sa
## dernière frame de marche.
func _update_facing(direction: Vector2) -> void:
	# Ne pas couper une animation d'attaque ou de hit en cours (cf.
	# _on_collision_area_body_entered / _on_health_changed) : sinon la reprise
	# du mouvement l'écrase dès la frame suivante (constaté en jeu -- le hit
	# ne durait qu'une frame, invisible).
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	_last_facing_direction = direction
	var anim_name := StringName("walk-" + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _update_target() -> void:
	target = _closest_living_player()

func _on_collision_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("Players"):
		body.take_damage(damage)
		_play_attack_animation(body.global_position - global_position)
		AudioManager.play_sfx("enemy_attack_melee")

## Direction vers la cible plutôt que la dernière direction de déplacement :
## simple et toujours valide, pas besoin de tracker un _last_facing_direction
## rien que pour ce cas (contrairement à enemy_ranged.gd/boss_01.gd où la
## vitesse retombe à zéro pendant l'attaque).
func _play_attack_animation(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	sprite.play(StringName("attack-" + FacingDirection.label_for(direction)))

## Réaction visuelle à un coup non-létal (Phase 9.3). hp<=0 est déjà géré par
## _on_death_animation (via le signal died, émis juste après health_changed
## dans Character._update_health) -- pas de jouer un hit qui serait de toute
## façon immédiatement écrasé par l'anim de mort.
func _on_health_changed(_max_lifepoint: float, lifepoint: float) -> void:
	if lifepoint <= 0:
		return
	if sprite.animation.begins_with("attack"):
		return
	sprite.play(StringName("hit-" + FacingDirection.label_for(_last_facing_direction)))

## Tourne sur tous les pairs (died vient de _update_health, call_local RPC déjà
## répliqué identiquement partout) -- pas besoin de RPC dédiée ici.
func _on_death_animation() -> void:
	sprite.play(StringName("death-" + FacingDirection.label_for(_last_facing_direction)))

## Hôte-only (appelé depuis Character.kill() -> is_server()). Attend la fin de
## l'anim de mort déjà lancée par _on_death_animation avant de libérer le
## nœud -- laisse le temps à tous les pairs de la voir jouer (is_dead bloque
## déjà toute interaction entre-temps).
func _die_and_free() -> void:
	await sprite.animation_finished
	if is_instance_valid(self):
		queue_free()
