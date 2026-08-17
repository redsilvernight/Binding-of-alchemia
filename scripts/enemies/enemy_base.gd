class_name EnemyBase
extends Character

## Reste inactif tant que sa Room ne l'a pas activé (cf. Room._activate_enemies_delayed) :
## sans ça, un ennemi vise le joueur le plus proche dès le lancement de la
## partie, quelle que soit la salle où il se trouve, et va se coller contre
## sa propre porte à attendre — repéré avant même que le joueur entre.
var active: bool = false

## Monnaie méta (Phase 8.2) accordée au joueur qui porte le coup fatal. Exporté
## pour permettre à des ennemis plus forts (ex : boss_01.tscn) de valoir plus.
@export var currency_reward: int = 5

## Phase 9.2 : chemin d'un ingrédient à lâcher à la mort, assigné par
## game.gd juste après spawn (budget d'ingrédients fixe réparti sur des
## ennemis choisis au hasard pour tout l'étage — pas un tirage indépendant
## par mort, cf. _generate_dungeon()). Vide = cet ennemi ne lâche rien.
var carries_ingredient_path: String = ""

## Cri d'ambiance aléatoire (Phase 9.4), mécanisme commun porté par cette
## classe de base (plutôt que dupliqué comme _on_collision_area_body_entered,
## qui préexistait à l'audio et suit la convention "dupliquer jusqu'au 3e
## besoin réel" déjà établie dans ce projet -- ceci est un mécanisme
## entièrement nouveau, donc centralisé dès le départ). Le SON lui-même est
## par contre spécifique à chaque type concret : ambient_sfx_key est surchargé
## directement sur le nœud de chaque scène .tscn (enemy_melee_brute.tscn,
## etc.), même mécanisme déjà utilisé pour différencier les stats/la teinte
## des 9 variantes d'ennemis (cf. roadmap 9.2) -- pas de nouveau script par
## type, juste une valeur exportée de plus.
const AMBIENT_MIN_INTERVAL: float = 4.0
const AMBIENT_MAX_INTERVAL: float = 10.0
## Portée en pixels au-delà de laquelle un mob est jugé "hors de portée
## d'écoute" (le son n'est pas spatialisé, cf. AudioManager) -- évite qu'un
## mob assis dans une salle pas encore visitée se fasse entendre. Un peu plus
## d'une salle (cf. game.gd::ROOM_CELL_SIZE, 1344x960).
const AMBIENT_RANGE: float = 1400.0
## Valeur par défaut = repli générique si un type n'a pas encore reçu son
## propre cri (cf. les .tscn qui surchargent cette valeur).
@export var ambient_sfx_key: String = "mob_ambient_1"

var _ambient_timer: float = 0.0

## Pathfinding (Phase 11.1) : un agent par ennemi, créé en code plutôt que
## posé dans chaque .tscn -- une quinzaine de scènes ennemis réutilisent ces
## quelques scripts de base (cf. commentaire plus bas sur les 9 variantes),
## un seul point d'ajout couvre tout le roster sans éditer chaque scène.
## avoidance_enabled : les props bloquants sont maintenant des tuiles creusées
## dans le NavigationPolygon de la salle (cf. Room._setup_navigation(), qui
## utilise `radius` ci-dessous comme agent_radius du bake pour garder le
## chemin brut à distance de sécurité) -- avoidance_enabled reste nécessaire
## pour l'évitement RVO entre agents mobiles (autres ennemis, joueurs), pas
## pour les props qui n'ont plus leur propre NavigationObstacle2D.
var nav_agent: NavigationAgent2D

func _ready() -> void:
	super()
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 28.0
	add_child(nav_agent)
	nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
	add_to_group("Enemies")
	_reset_ambient_timer()

## Remplace le `move(direction_to(target), speed)` en ligne droite historique
## dans les états qui poursuivent un point (Chase, approche de
## RangedAttack/Charge/Support) -- calcule le prochain point du chemin plutôt
## que de foncer droit sur la cible. La vitesse réelle appliquée passe par
## _on_nav_velocity_computed() (RVO, cf. commentaire sur nav_agent) : ce n'est
## qu'une demande, pas la vélocité finale.
func move_toward_position(target_position: Vector2, speed: float) -> void:
	nav_agent.target_position = target_position
	if nav_agent.is_navigation_finished():
		move(Vector2.ZERO, 0.0)
		return
	var next_point: Vector2 = nav_agent.get_next_path_position()
	nav_agent.set_velocity(global_position.direction_to(next_point) * speed)

func _on_nav_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

## Purement local à chaque pair, sans RPC (cosmétique, pas un événement de
## gameplay à synchroniser) -- même raisonnement que l'avancement des frames
## de sprite documenté ailleurs dans le projet ("chaque instance avance ses
## propres frames localement"). Gardé par la DISTANCE au joueur vivant le
## plus proche plutôt que par `active` : `active` n'est mis à true que côté
## hôte (cf. Room._activate_enemies_delayed, gardé par is_server()) -- un
## client ne le verrait jamais passer à true et ses mobs resteraient
## silencieux. La distance, elle, se calcule identiquement sur chaque pair
## puisque les positions des joueurs sont répliquées.
func _process(delta: float) -> void:
	if is_dead:
		return
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_reset_ambient_timer()
		_maybe_play_ambient_sound()

func _reset_ambient_timer() -> void:
	_ambient_timer = randf_range(AMBIENT_MIN_INTERVAL, AMBIENT_MAX_INTERVAL)

func _maybe_play_ambient_sound() -> void:
	var player: Node2D = _closest_living_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > AMBIENT_RANGE:
		return
	AudioManager.play_sfx(ambient_sfx_key)

func _get_hit_sfx_key() -> String:
	return "hit_enemy"

## Monnaie et ingrédient (si porté) lâchés comme pickups physiques au sol
## (Phase 9.2, dynamisme) -- ramassés individuellement par qui marche
## dessus, plus de crédit/attribution de "partie" à décider ici. Les
## sous-classes peuvent surcharger (en appelant super()) pour ajouter
## d'autres drops avant la destruction du noeud.
func _on_death() -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	game.request_currency_drop(global_position, currency_reward)
	if carries_ingredient_path != "":
		game.request_enemy_drop(global_position, carries_ingredient_path)

func kill() -> void:
	if multiplayer.is_server():
		_on_death()
	super()

## Joueur vivant le plus proche, pour les 3 implémentations concrètes de
## _update_target() (ennemi_test.gd, enemy_ranged.gd, boss_01.gd — dupliquées
## à l'identique jusqu'ici, cf. convention duck-typing documentée dans
## enemy_state_chase.gd/enemy_state_ranged_attack.gd). Exclut les spectateurs
## (is_dead) : un joueur mort reste un noeud figé dans le groupe "Players"
## (cf. Player.kill(), Phase 8.1) — sans ce filtre, un ennemi peut se fixer
## sur un cadavre plus proche que le joueur vivant et ne plus jamais recibler,
## peu importe où ce dernier se trouve (bug constaté en playtest à 3 joueurs).
func _closest_living_player() -> Node2D:
	var closest: Node2D = null
	var closest_distance: float = INF
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_dead:
			continue
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = player
	return closest
