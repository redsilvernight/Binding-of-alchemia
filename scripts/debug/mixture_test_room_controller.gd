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
const WAVE_RESPAWN_DELAY: float = 2.0
const ROOM_SPAWN_MARGIN: float = 100.0
const ROOM_WIDTH_PX: float = 1344.0
const ROOM_HEIGHT_PX: float = 960.0

@onready var room: Room = get_parent() as Room
@onready var players_container: Node2D = $"../Players"
@onready var enemies_container: Node2D = $"../Enemies"
@onready var hud_container: Node2D = $"../HUD"

var _alive_enemies: Array[Node] = []


func _ready() -> void:
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


func _spawn_wave() -> void:
	for i in range(WAVE_SIZE):
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
	if _alive_enemies.is_empty():
		get_tree().create_timer(WAVE_RESPAWN_DELAY).timeout.connect(_spawn_wave)
