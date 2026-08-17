extends Node
## Scène de test jetable (retour utilisateur) : bac à sable indépendant de la
## boucle de run/donjon pour tester la mixture/les VFX sans avoir à traverser
## hub -> run -> étages. À supprimer une fois les tests terminés -- rien ici
## n'est branché sur RunManager/MetaProgression/le générateur de donjon.
##
## Suppose un lancement solo (aucun pair réseau) : comme main_menu.gd::"Jouer"
## (NetworkManager.play_solo()), l'absence de multiplayer_peer fait tourner
## Godot en mode hors-ligne (is_server() == true, get_unique_id() == 1) sans
## rien à initialiser explicitement -- vrai par défaut si cette scène est
## lancée directement (F6) sans passer par le menu.

const ENEMY_SCENE_PATHS: Array[String] = [
	"res://scenes/enemies/enemy_melee.tscn",
	"res://scenes/enemies/enemy_ranged.tscn",
	"res://scenes/enemies/enemy_erratic.tscn",
	"res://scenes/enemies/enemy_melee_brute.tscn",
	"res://scenes/enemies/enemy_melee_swarm.tscn",
	"res://scenes/enemies/enemy_ranged_sniper.tscn",
	"res://scenes/enemies/enemy_ranged_gunner.tscn",
	"res://scenes/enemies/enemy_erratic_bomber.tscn",
	"res://scenes/enemies/enemy_erratic_swift.tscn",
	"res://scenes/enemies/enemy_melee_juggernaut.tscn",
	"res://scenes/enemies/enemy_ranged_turret.tscn",
	"res://scenes/enemies/enemy_erratic_phantom.tscn",
	"res://scenes/enemies/enemy_ranged_artillery.tscn",
	"res://scenes/enemies/enemy_healer.tscn",
	"res://scenes/enemies/enemy_charger.tscn",
]
const INGREDIENTS_DIR: String = "res://resources/Ingredients/"
const INGREDIENT_TEST_QUANTITY: int = 99
const WAVE_SIZE: int = 10
## Retour utilisateur : toute la vague d'un coup submergeait le joueur --
## les ennemis arrivent maintenant un par un, laissant le temps de réagir.
const WAVE_SPAWN_INTERVAL: float = 1.5
const WAVE_RESPAWN_DELAY: float = 2.0
const ROOM_SPAWN_MARGIN: float = 100.0
const ROOM_WIDTH_PX: float = 1344.0
const ROOM_HEIGHT_PX: float = 960.0

@onready var room: Room = get_parent() as Room
@onready var players_container: Node2D = $"../Players"
@onready var enemies_container: Node2D = $"../Enemies"
@onready var hud_container: Node2D = $"../HUD"
@onready var projectiles_container: Node2D = $"../Projectiles"

var _alive_enemies: Array[Node] = []
## Empêche _on_enemy_removed de planifier une relance PENDANT que la vague
## est encore en train d'apparaître (si le joueur tue plus vite qu'elle ne
## spawn, _alive_enemies peut retomber à vide avant le dernier arrivant).
var _wave_spawning: bool = false


func _ready() -> void:
	# Requis pour que enemy_ranged.gd::fire_at()/boss_01.gd (tir à distance)
	# et EnemyBase._on_death() (drops) trouvent un noeud via
	# get_tree().get_first_node_in_group("Game") -- sans lui, les ennemis à
	# distance ne tirent jamais (silencieux, cf. leur propre garde "if game
	# == null: return").
	add_to_group("Game")
	# Peint des murs pleins sur les 4 côtés (aucune salle voisine) : le
	# rework tile-based (Phase 10.x) exige que Room._paint_floor() ait déjà
	# tourné une fois (child avant parent en ordre de _ready()), d'où le
	# call_deferred plutôt qu'un appel direct ici.
	room.set_open_sides.call_deferred([])
	_spawn_player()
	_spawn_wave()


func _spawn_player() -> void:
	var player: Node = PlayerManager.spawnPlayer(1)
	player.instance_hud.connect(func(hud: Node) -> void: hud_container.add_child(hud))
	# LE bug signalé : dans game.gd, player.instance_projectile est connecté
	# à _on_projectile_requested -> projectile_spawner.spawn(data), ce qui
	# matérialise vraiment la balle. Cette scène ne connectait rien du tout
	# ici -- request_fire réussissait bien côté Weapon (ammo consommée,
	# cooldown appliqué) mais le signal projectile_requested se perdait sans
	# personne à l'écoute, donc aucune balle n'apparaissait jamais.
	player.instance_projectile.connect(_spawn_bullet_from_data)
	players_container.add_child(player)
	player.position = Vector2(ROOM_WIDTH_PX / 2.0, ROOM_HEIGHT_PX * 0.75)
	_grant_all_ingredients(player.inventory)


## Retour utilisateur : accès à tous les ingrédients UNIQUEMENT dans cette
## scène de test, en grande quantité pour ne jamais être à court en testant
## des mixtures à répétition -- bypass volontaire de la table de spawn/du
## système de déblocage (MetaProgression), sans rapport avec une vraie run.
func _grant_all_ingredients(inventory: Inventory) -> void:
	var dir := DirAccess.open(INGREDIENTS_DIR)
	if dir == null:
		push_error("mixture_test_room: dossier ingrédients introuvable: %s" % INGREDIENTS_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var ingredient: Ingredient = load(INGREDIENTS_DIR + file_name) as Ingredient
			if ingredient:
				inventory.add_ingredient(ingredient, INGREDIENT_TEST_QUANTITY)
		file_name = dir.get_next()
	dir.list_dir_end()


## Même pipeline que game.gd::_spawn_bullet -- réutilisé pour le tir du
## joueur (Player.instance_projectile, connecté dans _spawn_player) ET les
## tirs ennemis à distance (request_enemy_projectile ci-dessous, appelé via
## le groupe "Game"), les deux seuls appelants réels d'un spawn de balle
## dans cette scène (cf. design_no_premature_genericity : 2 call sites
## concrets, comme dans game.gd).
func _spawn_bullet_from_data(data: Dictionary) -> Node:
	var scene_path: String = data.get("scene_path", "res://scenes/projectiles/bullet_water.tscn")
	var bullet: Bullet = (load(scene_path) as PackedScene).instantiate()
	bullet.setup(data["damage"], data["speed"], data["lifetime"], data["trajectory"])
	bullet.shooter_id = data.get("shooter_id", 0)
	if scene_path == Weapon.MIXTURE_BULLET_SCENE:
		bullet.impact_sfx_key = "impact_mixture"
	elif scene_path == "res://scenes/enemies/enemy_projectile.tscn":
		AudioManager.play_sfx("enemy_attack_ranged")
	if data.has("impact_effect_data"):
		var effect: ImpactEffect = ImpactEffect.from_dict(data["impact_effect_data"])
		bullet.set_impact_effect(effect)
	projectiles_container.add_child(bullet)
	bullet.launch.call_deferred(data["from_position"], data["direction"])
	return bullet


func request_enemy_projectile(data: Dictionary) -> void:
	_spawn_bullet_from_data(data)


## Pas de pipeline de drop dans ce bac à sable (le joueur a déjà 99 de
## chaque ingrédient, cf. _grant_all_ingredients) -- stubs no-op requis
## uniquement pour que EnemyBase._on_death() ne plante pas : dès qu'un
## noeud "Game" existe (cf. add_to_group ci-dessus), il l'appelle sans
## garde de nullité sur ces deux méthodes.
func request_currency_drop(_position: Vector2, _amount: int) -> void:
	pass


func request_enemy_drop(_position: Vector2, _item_resource_path: String) -> void:
	pass


func _spawn_wave() -> void:
	_wave_spawning = true
	for i in range(WAVE_SIZE):
		_spawn_one_enemy()
		if i < WAVE_SIZE - 1:
			await get_tree().create_timer(WAVE_SPAWN_INTERVAL).timeout
	_wave_spawning = false
	if _alive_enemies.is_empty():
		get_tree().create_timer(WAVE_RESPAWN_DELAY).timeout.connect(_spawn_wave)


func _spawn_one_enemy() -> void:
	var scene_path: String = ENEMY_SCENE_PATHS[randi() % ENEMY_SCENE_PATHS.size()]
	var enemy: Node = (load(scene_path) as PackedScene).instantiate()
	enemy.position = _random_position_in_room()
	enemies_container.add_child(enemy)
	enemy.active = true # pas de RoomTrigger pour retarder l'activation ici
	_alive_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy))


func _random_position_in_room() -> Vector2:
	return Vector2(
		randf_range(ROOM_SPAWN_MARGIN, ROOM_WIDTH_PX - ROOM_SPAWN_MARGIN),
		randf_range(ROOM_SPAWN_MARGIN, ROOM_HEIGHT_PX - ROOM_SPAWN_MARGIN)
	)


func _on_enemy_removed(enemy: Node) -> void:
	_alive_enemies.erase(enemy)
	if _alive_enemies.is_empty() and not _wave_spawning:
		get_tree().create_timer(WAVE_RESPAWN_DELAY).timeout.connect(_spawn_wave)
