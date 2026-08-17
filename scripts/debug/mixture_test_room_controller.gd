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
const ROOM_SPAWN_MARGIN: float = 100.0
const ROOM_WIDTH_PX: float = 1344.0
const ROOM_HEIGHT_PX: float = 960.0

## minimap.gd (instanciée par hud.tscn) lit ces 3 membres sur le premier
## noeud du groupe "Game" sans garde de nullité (dungeon_map_changed.connect,
## ROOM_CELL_SIZE, dungeon_map.keys()) -- il n'y a pas de vrai donjon ici,
## donc dungeon_map reste vide en permanence : la minimap s'affiche juste
## blanche au lieu de planter à l'ouverture du HUD.
signal dungeon_map_changed
var dungeon_map: Dictionary = {}
const ROOM_CELL_SIZE: Vector2 = Vector2(ROOM_WIDTH_PX, ROOM_HEIGHT_PX)

@onready var room: Room = get_parent() as Room
@onready var players_container: Node2D = $"../Players"
@onready var enemies_container: Node2D = $"../Enemies"
@onready var hud_container: Node2D = $"../HUD"
@onready var projectiles_container: Node2D = $"../Projectiles"

var _player: Node = null


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
	# Retour utilisateur : plus de vague automatique -- un ennemi à la fois,
	# uniquement sur appui d'Espace (cf. _unhandled_input).


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_spawn_one_enemy()


## Retour utilisateur : munitions de mixture infinies pour tirer en boucle
## sans jamais attendre la régénération -- rechargée à fond chaque frame
## (moins cher/robuste qu'intercepter chaque tir) et re-émise pour que la
## barre du HUD reflète bien "toujours pleine" plutôt qu'un champ à jour
## silencieusement.
func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var weapon: Weapon = _player.weapon
	if weapon.current_mixture_ammo < weapon.mixture_max_capacity:
		weapon.current_mixture_ammo = weapon.mixture_max_capacity
		weapon.ammo_changed.emit(weapon.current_mixture_ammo, weapon.mixture_max_capacity)


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
	# Retour utilisateur : joueur invulnérable dans ce bac à sable uniquement
	# (rien de partagé touché) -- can_take_damage est le même champ que
	# Character.take_damage() vérifie déjà pour les i-frames temporaires,
	# ici simplement laissé à false en permanence.
	player.can_take_damage = false
	_player = player
	_add_mixture_reset_button(player)


## Retour utilisateur : bouton "Réinitialiser la mixture" injecté dans
## l'écran d'alchimie du joueur, uniquement dans ce bac à sable -- la scène
## scenes/ui/alchemy_crafting.tscn elle-même n'est PAS modifiée (partagée
## avec le vrai jeu) : ce bouton est ajouté à l'instance déjà créée par
## Player._ready() (alchemy_crafting_screen), donc invisible partout
## ailleurs. Ramène la mixture chargée à son état d'origine (aucune
## mixture crée), identique à un Weapon fraîchement spawné.
func _add_mixture_reset_button(player: Node) -> void:
	var screen: Node = player.alchemy_crafting_screen
	if screen == null:
		return
	var content: Node = screen.get_node("Root/Content")
	var reset_button := Button.new()
	reset_button.text = "Réinitialiser la mixture"
	content.add_child(reset_button)
	reset_button.pressed.connect(func() -> void:
		player.weapon.mixture_impact_effect = null
		player.weapon.set_mixture_ingredients_networked([])
		screen.result_label.text = "Mixture réinitialisée."
	)


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


func _spawn_one_enemy() -> void:
	var scene_path: String = ENEMY_SCENE_PATHS[randi() % ENEMY_SCENE_PATHS.size()]
	var enemy: Node = (load(scene_path) as PackedScene).instantiate()
	enemy.position = _random_position_in_room()
	enemies_container.add_child(enemy)
	enemy.active = true # pas de RoomTrigger pour retarder l'activation ici


func _random_position_in_room() -> Vector2:
	return Vector2(
		randf_range(ROOM_SPAWN_MARGIN, ROOM_WIDTH_PX - ROOM_SPAWN_MARGIN),
		randf_range(ROOM_SPAWN_MARGIN, ROOM_HEIGHT_PX - ROOM_SPAWN_MARGIN)
	)
