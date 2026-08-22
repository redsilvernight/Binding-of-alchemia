extends Area2D
class_name Bullet

enum TrajectoryType { LINEAR, ARC, HOMING }

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var lifetime: float = 3.0
var _base_speed: float = 0.0
var trajectory: TrajectoryType = TrajectoryType.LINEAR
var impact_effect: ImpactEffect = null
## peer_id du tireur (assigné par game.gd._spawn_bullet) -- transmis à
## impact_effect.apply() pour les effets qui agissent sur le tireur plutôt
## que sur la cible touchée (ex: ImpactHeal, vol de vie d'une mixture Soin).
var shooter_id: int = 0
## Clé SFX jouée à l'impact (Phase 9.4), assignée par game.gd._spawn_bullet
## selon la scène tirée. Par défaut "impact_water" : les balles ennemies
## (enemy_projectile.tscn) ne passent pas par ce chemin de sélection mais
## restent audibles avec un son générique plutôt que muettes.
var impact_sfx_key: String = "impact_water"

# --- ARC ---
var _arc_time: float = 0.0
var _arc_height: float = 40.0
var _arc_duration: float = 0.6
var _arc_direction: Vector2 = Vector2.RIGHT
var _arc_start_position: Vector2 = Vector2.ZERO

# --- HOMING ---
var _homing_target: Node2D = null
var _homing_turn_speed: float = 5.0

## Fenêtre pendant laquelle un contact avec un MUR (node "Floor", cf.
## _on_body_entered) est ignoré depuis le tir -- retour utilisateur : un
## tireur collé pieds/corps contre un mur (la capsule "jambes" qui bloque
## physiquement le déplacement est plus petite et décalée par rapport à
## l'origine du tireur, d'où part le tir -- ex: y=46 contre y=0 côté joueur,
## cf. scenes/player.tscn) a son point de tir déjà à l'intérieur du polygone
## de collision du mur ; sans cette fenêtre, le tir s'y résout instantanément
## au lieu de partir. Scope volontairement limité aux MURS par NOM de node
## ("Floor" seulement, jamais "PropsBlocking") plutôt qu'à toute géométrie
## solide : un mur de salle est incontournable, un prop est un obstacle
## évitable -- pas de raison de le rendre traversable même brièvement (cf.
## retour utilisateur sur l'exploit "tirer au travers en restant collé à un
## prop").
const SPAWN_WALL_GRACE_TIME: float = 0.15
var _time_since_launch: float = 0.0

func setup(p_damage: float, p_speed: float, p_lifetime: float = 3.0, p_trajectory: TrajectoryType = TrajectoryType.LINEAR) -> void:
	damage = p_damage
	_base_speed = p_speed
	lifetime = p_lifetime
	trajectory = p_trajectory

func set_impact_effect(effect: ImpactEffect) -> void:
	impact_effect = effect

func set_arc_params(height: float, duration: float) -> void:
	_arc_height = height
	_arc_duration = duration

func set_homing_target(target: Node2D, turn_speed: float = 5.0) -> void:
	_homing_target = target
	_homing_turn_speed = turn_speed

func launch(from_position: Vector2, aim_direction: Vector2) -> void:
	global_position = from_position
	_arc_start_position = from_position
	_arc_direction = aim_direction.normalized()
	velocity = _arc_direction * _base_speed
	rotation = velocity.angle()
	if multiplayer.is_server():
		# process_always=false (retour utilisateur, menu pause) : par défaut
		# create_timer() continue de décompter même arbre en pause -- un
		# projectile gelé visuellement (_physics_process respecte bien la
		# pause) disparaissait quand même à l'expiration de ce minuteur.
		var timer := get_tree().create_timer(lifetime, false)
		timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	_time_since_launch += delta
	match trajectory:
		TrajectoryType.LINEAR:
			_process_linear(delta)
		TrajectoryType.ARC:
			_process_arc(delta)
		TrajectoryType.HOMING:
			_process_homing(delta)

func _process_linear(delta: float) -> void:
	global_position += velocity * delta

func _process_arc(delta: float) -> void:
	_arc_time += delta
	var t: float = clamp(_arc_time / _arc_duration, 0.0, 1.0)
	var forward_distance: float = _base_speed * _arc_time
	var offset: Vector2 = _arc_direction * forward_distance
	var height_offset: float = -4.0 * _arc_height * t * (1.0 - t)
	var perpendicular: Vector2 = _arc_direction.rotated(-PI / 2.0)
	global_position = _arc_start_position + offset + perpendicular * height_offset

func _process_homing(delta: float) -> void:
	if is_instance_valid(_homing_target):
		var desired_direction: Vector2 = (_homing_target.global_position - global_position).normalized()
		var current_direction: Vector2 = velocity.normalized()
		var new_direction: Vector2 = current_direction.slerp(desired_direction, _homing_turn_speed * delta)
		velocity = new_direction * _base_speed
		rotation = velocity.angle()
	global_position += velocity * delta

## Ignore un corps qui porte une Hurtbox (joueur ET ennemis désormais, cf.
## scenes/player.tscn et scenes/enemies/*.tscn) -- reste le seul chemin pour
## tout le reste (murs/props qui ne portent pas take_damage() mais doivent
## quand même faire disparaître la balle avec son SFX/VFX d'impact, cf.
## _resolve_hit()). Sans cette garde, un tir qui touche encore la collision
## physique réduite aux jambes déclencherait AUSSI ce chemin-ci au même
## instant que _on_area_entered (Hurtbox) : dégâts comptés deux fois pour un
## seul impact. has_node("Hurtbox") plutôt qu'un groupe ("Players") codé en
## dur : marche pour toute entité migrée vers ce pattern, joueur ou ennemi,
## sans liste à maintenir ici.
func _on_body_entered(body: Node) -> void:
	if body.has_node("Hurtbox"):
		return
	if body.name == "Floor" and _time_since_launch < SPAWN_WALL_GRACE_TIME:
		return
	_resolve_hit(body)


## Joueur ET ennemis détectent les dégâts via leur Hurtbox (Area2D) plutôt
## que directement via leur CharacterBody2D -- leur collision "physique"
## (celle que body_entered voit) est désormais réduite aux jambes (retour
## utilisateur : marcher devant/derrière un obstacle sans être bloqué par
## toute sa hauteur), donc trop petite pour rester une cible de dégâts
## cohérente avec le sprite affiché. La cible réelle est le PARENT de la
## Hurtbox, pas la Hurtbox elle-même : c'est lui qui porte take_damage().
func _on_area_entered(area: Area2D) -> void:
	_resolve_hit(area.get_parent())


## Commun à body_entered (murs/ennemis/joueur en collision "physique" pleine
## taille, ex: enemy_projectile.tscn) et area_entered (Hurtbox du joueur,
## cf. ci-dessus) -- même résolution de dégâts dans les deux cas.
func _resolve_hit(target: Node) -> void:
	# SFX joué AVANT la garde hôte (Phase 9.4) : ce noeud existe en vrai chez
	# chaque pair (spawné via projectile_spawner, cf. game.gd), sa trajectoire
	# est simulée localement de façon déterministe à partir des mêmes données
	# de tir -- chaque pair détecte donc sa propre collision indépendamment,
	# à peu près au même instant. Seule la RÉSOLUTION du dégât reste hôte-only.
	AudioManager.play_sfx(impact_sfx_key)
	# Même raisonnement que le SFX ci-dessus : feedback visuel pur, doit
	# jouer sur chaque pair indépendamment (pas de RPC), pas seulement l'hôte.
	if impact_effect != null:
		impact_effect.spawn_visual(get_tree(), global_position)
	if not multiplayer.is_server():
		return
	# Les dégâts d'arme (canon+cœur) et l'effet alchimique de la mixture
	# S'ADDITIONNENT au lieu de s'exclure -- esprit "Rounds" : chaque
	# ingrédient de la mixture ajoute son propre pouvoir au tir de base
	# plutôt que de le remplacer. Sans mixture chargée, impact_effect est
	# null (comportement inchangé : seuls les dégâts d'arme s'appliquent).
	if target.has_method("take_damage"):
		target.take_damage(damage)
	if impact_effect != null:
		impact_effect.apply(target, global_position, shooter_id)
	queue_free()
