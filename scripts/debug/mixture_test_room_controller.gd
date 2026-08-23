extends Node

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
const WEAPON_PARTS_DIR: String = "res://resources/GunParts/"
const ROOM_SPAWN_MARGIN: float = 100.0
const ROOM_WIDTH_PX: float = 1344.0
const ROOM_HEIGHT_PX: float = 960.0

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
	add_to_group("Game")
	room.set_open_sides.call_deferred([])
	_spawn_player()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_spawn_one_enemy()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var weapon: Weapon = _player.weapon
	if weapon.current_mixture_ammo < weapon.mixture_max_capacity:
		weapon.current_mixture_ammo = weapon.mixture_max_capacity
		weapon.ammo_changed.emit(weapon.current_mixture_ammo, weapon.mixture_max_capacity)


func _spawn_player() -> void:
	var player: Node = PlayerManager.spawn_player(1)
	player.instance_hud.connect(func(hud: Node) -> void: hud_container.add_child(hud))
	player.instance_projectile.connect(_spawn_bullet_from_data)
	players_container.add_child(player)
	player.position = Vector2(ROOM_WIDTH_PX / 2.0, ROOM_HEIGHT_PX * 0.75)
	_grant_all_ingredients(player.inventory)
	_grant_all_weapon_parts(player.inventory)
	player.can_take_damage = false
	_player = player
	_add_mixture_reset_button(player)


func _add_mixture_reset_button(player: Node) -> void:
	var screen: Node = player.alchemy_crafting_screen
	if screen == null:
		return
	var content: Node = screen.get_node("Root/FramePanel/Margin/Content")
	var reset_button := Button.new()
	reset_button.text = "Réinitialiser la mixture"
	content.add_child(reset_button)
	reset_button.pressed.connect(func() -> void:
		player.weapon.mixture_impact_effect = null
		var empty_paths: Array[String] = []
		player.weapon.set_mixture_ingredients_networked(empty_paths)
		screen.result_label.text = "Mixture réinitialisée."
	)


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


func _grant_all_weapon_parts(inventory: Inventory) -> void:
	var dir := DirAccess.open(WEAPON_PARTS_DIR)
	if dir == null:
		push_error("mixture_test_room: dossier pièces d'arme introuvable: %s" % WEAPON_PARTS_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var part: Resource = load(WEAPON_PARTS_DIR + file_name)
			if part:
				inventory.add_weapon_part(part)
		file_name = dir.get_next()
	dir.list_dir_end()


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


func request_currency_drop(_position: Vector2, _amount: int) -> void:
	pass


func request_enemy_drop(_position: Vector2, _item_resource_path: String) -> void:
	pass


func _spawn_one_enemy() -> void:
	var scene_path: String = ENEMY_SCENE_PATHS[randi() % ENEMY_SCENE_PATHS.size()]
	var enemy: Node = (load(scene_path) as PackedScene).instantiate()
	enemy.position = _random_position_in_room()
	enemies_container.add_child(enemy)
	enemy.active = true


func _random_position_in_room() -> Vector2:
	return Vector2(
		randf_range(ROOM_SPAWN_MARGIN, ROOM_WIDTH_PX - ROOM_SPAWN_MARGIN),
		randf_range(ROOM_SPAWN_MARGIN, ROOM_HEIGHT_PX - ROOM_SPAWN_MARGIN)
	)
