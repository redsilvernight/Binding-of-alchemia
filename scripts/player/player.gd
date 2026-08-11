# player.gd
extends Character
signal instance_hud(hud: Node)
signal instance_projectile(data: Dictionary)
@export var speed: float = 300.0
@export var invulnerability_duration: float = 1.0
@export var hud_scene: PackedScene = preload("res://scenes/HUD/hud.tscn")
@export var inventory_screen_scene: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")
@export var alchemy_crafting_scene: PackedScene = preload("res://scenes/ui/alchemy_crafting.tscn")
@export var weapon_crafting_scene: PackedScene = preload("res://scenes/ui/weapon_crafting.tscn")
@export var unlock_screen_scene: PackedScene = preload("res://scenes/ui/unlock_screen.tscn")
@onready var player_camera: Camera2D = $Camera2D
@onready var damage_timer: Timer = $DamageTimer
@onready var weapon: Weapon = $Weapon
@onready var inventory: Inventory = $Inventory
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
var was_water_pressed: bool = false
var was_mixture_pressed: bool = false
var last_aim_direction: Vector2 = Vector2.RIGHT
var last_stick_activity_time: float = -INF
var last_mouse_activity_time: float = -INF
var last_mouse_screen_position: Vector2 = Vector2.ZERO
var mouse_position_initialized: bool = false
var alchemy_crafting_screen: Node = null
var weapon_crafting_screen: Node = null
var unlock_screen: Node = null
var _spectate_target: Node2D = null

func _ready() -> void:
	super()
	add_to_group("Players")
	damage_timer.wait_time = invulnerability_duration
	weapon.projectile_requested.connect(_on_projectile_requested)
	died.connect(_on_died)
	if is_multiplayer_authority():
		player_camera.enabled = true
		var hud = hud_scene.instantiate()
		health_changed.connect(hud.get_node("VBoxBar").get_node("LifeBar")._on_heal_changed)
		var mixture_bar = hud.get_node("VBoxBar").get_node("MixtureBar")
		weapon.ammo_changed.connect(mixture_bar._on_ammo_changed)
		mixture_bar._on_ammo_changed(weapon.mixture_max_capacity, weapon.current_mixture_ammo)
		instance_hud.emit(hud)
		var inventory_screen = inventory_screen_scene.instantiate()
		add_child(inventory_screen)
		inventory_screen.bind_inventory(inventory)
		var alchemy_crafting = alchemy_crafting_scene.instantiate()
		add_child(alchemy_crafting)
		alchemy_crafting.bind_inventory(inventory)
		alchemy_crafting_screen = alchemy_crafting
		var weapon_crafting = weapon_crafting_scene.instantiate()
		add_child(weapon_crafting)
		weapon_crafting.bind_inventory(inventory)
		weapon_crafting_screen = weapon_crafting
		var unlock = unlock_screen_scene.instantiate()
		add_child(unlock)
		unlock_screen = unlock
	else:
		player_camera.enabled = false

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_dead:
		_process_spectating()
		return
	var aim_direction = _get_aim_direction()
	var water_pressed = Input.is_action_pressed("fire_water")
	var mixture_pressed = Input.is_action_pressed("fire_mixture")
	if water_pressed and not mixture_pressed:
		request_fire.rpc_id(1, "water", aim_direction)
	elif mixture_pressed and not water_pressed:
		request_fire.rpc_id(1, "mixture", aim_direction)
	elif water_pressed and mixture_pressed:
		if was_water_pressed:
			request_fire.rpc_id(1, "water", aim_direction)
		elif was_mixture_pressed:
			request_fire.rpc_id(1, "mixture", aim_direction)
		else:
			request_fire.rpc_id(1, "water", aim_direction)
	was_water_pressed = water_pressed
	was_mixture_pressed = mixture_pressed
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move(input_direction, speed)

@rpc("any_peer", "call_local", "reliable")
func request_fire(fire_type: String, direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return
	if fire_type == "water":
		weapon.try_fire_water(direction)
	else:
		weapon.try_fire_mixture(direction)

func _get_aim_direction() -> Vector2:
	var now = Time.get_ticks_msec() / 1000.0
	var stick_input = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick_input.length() > 0.0:
		last_stick_activity_time = now
	var current_mouse_screen_position = get_viewport().get_mouse_position()
	if not mouse_position_initialized:
		last_mouse_screen_position = current_mouse_screen_position
		mouse_position_initialized = true
	elif current_mouse_screen_position != last_mouse_screen_position:
		last_mouse_activity_time = now
		last_mouse_screen_position = current_mouse_screen_position
	if last_stick_activity_time > last_mouse_activity_time:
		if stick_input.length() > 0.0:
			last_aim_direction = stick_input.normalized()
	else:
		var mouse_delta = get_global_mouse_position() - global_position
		if mouse_delta.length() > 0.0:
			last_aim_direction = mouse_delta.normalized()
	return last_aim_direction

func open_alchemy_crafting() -> void:
	if alchemy_crafting_screen:
		alchemy_crafting_screen.open()

func open_weapon_crafting() -> void:
	if weapon_crafting_screen:
		weapon_crafting_screen.open()

func open_unlock_screen() -> void:
	if unlock_screen:
		unlock_screen.open()

@rpc("any_peer", "call_local", "reliable")
func request_equip_weapon_part(part_path: String) -> void:
	# Même garde que request_craft_mixture : seul l'hôte valide, et seulement
	# pour le joueur qui a réellement envoyé la requête (anti-usurpation).
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return

	var owned: bool = false
	for part in inventory.weapon_parts:
		if part.resource_path == part_path:
			owned = true
			break
	if not owned:
		return # désync UI/inventaire : on ignore plutôt que d'équiper une pièce non possédée

	weapon.equip_networked(load(part_path))

@rpc("any_peer", "call_local", "reliable")
func request_craft_mixture(ingredient_paths: Array[String]) -> void:
	# Même garde que request_fire : seul l'hôte résout, et seulement pour
	# le joueur qui a réellement envoyé la requête (anti-usurpation).
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return
	if ingredient_paths.is_empty():
		return

	# On compte d'abord tout ce qu'il faut et on vérifie le stock AVANT de
	# retirer quoi que ce soit : un retrait partiel suivi d'un échec plus
	# loin consommerait des ingrédients sans produire de mixture (perte
	# silencieuse pour le joueur). L'opération doit rester atomique.
	var required_counts: Dictionary = {} # String (resource_path) -> int
	for path in ingredient_paths:
		required_counts[path] = required_counts.get(path, 0) + 1

	var ingredients_for_recipe: Array[Ingredient] = []
	for path in required_counts.keys():
		var ingredient: Ingredient = load(path) as Ingredient
		if ingredient == null:
			push_error("request_craft_mixture: ingrédient introuvable: %s" % path)
			return
		if inventory.get_ingredient_count(ingredient) < required_counts[path]:
			return # stock insuffisant (désync UI/inventaire) : on abandonne sans rien consommer
		for i in range(required_counts[path]):
			ingredients_for_recipe.append(ingredient)

	for path in required_counts.keys():
		inventory.remove_ingredient(load(path) as Ingredient, required_counts[path])

	# Résolution et conversion en effet : appelées uniquement depuis ce
	# chemin autoritaire côté hôte (cf. architecture_reseau.md, 4.2).
	var mixture: Mixture = AlchemyResolver.resoudre(ingredients_for_recipe)
	var effect: ImpactEffect = MixtureToEffect.convertir(mixture)
	# Limite connue : ceci écrase l'effet de la mixture active tant que
	# l'inventaire ne stocke pas plusieurs mixtures en parallèle (5.5 ne
	# prévoit qu'une mixture "chargée" à la fois pour l'instant). Un futur
	# equip() sur l'arme (changement de pièce) réinitialise ce champ à
	# barrel_mixture.impact_effect — dette acceptée, à traiter si le besoin
	# de stockage multi-mixtures se confirme.
	weapon.mixture_impact_effect = effect
	print("Mixture appliquée pour %s: %s" % [name, effect])

func _on_projectile_requested(data: Dictionary) -> void:
	instance_projectile.emit(data)

func _on_damage_timer_timeout() -> void:
	can_take_damage = true

func _start_invulnerability() -> void:
	can_take_damage = false
	damage_timer.start()

@rpc("any_peer", "call_local", "reliable")
func teleport(new_position: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	position = new_position

func kill() -> void:
	pass

func _on_died() -> void:
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	if is_multiplayer_authority():
		_show_spectator_label()
		_pick_spectate_target()
		player_camera.position_smoothing_enabled = true
		player_camera.position_smoothing_speed = 2.5

func _process_spectating() -> void:
	if Input.is_action_just_pressed("spectate_next"):
		_pick_spectate_target(true)
	elif not is_instance_valid(_spectate_target) or _spectate_target.is_dead:
		_pick_spectate_target()
	if is_instance_valid(_spectate_target):
		player_camera.global_position = _spectate_target.global_position

func _pick_spectate_target(cycle: bool = false) -> void:
	var candidates: Array = []
	for p in get_tree().get_nodes_in_group("Players"):
		if p != self and not p.is_dead:
			candidates.append(p)
	if candidates.is_empty():
		_spectate_target = null
		return
	if not cycle or _spectate_target == null or not candidates.has(_spectate_target):
		_spectate_target = candidates[0]
		return
	var current_index: int = candidates.find(_spectate_target)
	_spectate_target = candidates[(current_index + 1) % candidates.size()]

func _show_spectator_label() -> void:
	var label := Label.new()
	label.text = "Vous êtes mort — Espace pour changer de vue"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 40
	label.size.x = 400
	label.position.x -= 200
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
