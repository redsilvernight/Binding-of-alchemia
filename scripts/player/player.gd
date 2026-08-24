extends Character
signal instance_hud(hud: Node)
signal instance_projectile(data: Dictionary)
@export var speed: float = 300.0
@export var invulnerability_duration: float = 1.0
@export var hud_scene: PackedScene = preload("res://scenes/HUD/hud.tscn")
@export var inventory_screen_scene: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")
@export var alchemy_crafting_scene: PackedScene = preload("res://scenes/ui/alchemy_crafting.tscn")
@export var weapon_crafting_scene: PackedScene = preload("res://scenes/ui/weapon_crafting.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
@onready var player_camera: Camera2D = $Camera2D
@onready var damage_timer: Timer = $DamageTimer
@onready var weapon: Weapon = $Weapon
@onready var inventory: Inventory = $Inventory
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var _light: PointLight2D = $PlayerLight
@onready var water_fire_indicator: PlayerFireIndicator = $WaterFireIndicator
@onready var mixture_fire_indicator: PlayerFireIndicator = $MixtureFireIndicator
var was_water_pressed: bool = false
var was_mixture_pressed: bool = false
var last_aim_direction: Vector2 = Vector2.RIGHT
var last_stick_activity_time: float = -INF
var last_mouse_activity_time: float = -INF
var last_mouse_screen_position: Vector2 = Vector2.ZERO
var mouse_position_initialized: bool = false
var last_movement_activity_time: float = -INF
var inventory_screen: Node = null
var alchemy_crafting_screen: Node = null
var weapon_crafting_screen: Node = null
var _pending_fire_type: String = ""
var _pending_fire_direction: Vector2 = Vector2.ZERO
var _footstep_last_frame: int = -1
var _death_animation_done: bool = false
var _dungeon_camera_mode: bool = false
var _camera_controller: PlayerCameraController
var _spectator: PlayerSpectator

func _ready() -> void:
	super()
	add_to_group("Players")
	_camera_controller = PlayerCameraController.new(player_camera)
	_spectator = PlayerSpectator.new(self, player_camera)
	_light.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _light.visible = enabled)
	damage_timer.wait_time = invulnerability_duration
	weapon.projectile_requested.connect(_on_projectile_requested)
	died.connect(_on_died)
	health_changed.connect(_on_health_changed)
	sprite.play()
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.animation_changed.connect(_on_sprite_animation_changed)
	if is_multiplayer_authority():
		player_camera.enabled = true
		get_viewport().size_changed.connect(_on_viewport_size_changed)
		var hud = hud_scene.instantiate()
		health_changed.connect(hud.get_node("VBoxBar").get_node("LifeBar")._on_heal_changed)
		var mixture_bar = hud.get_node("VBoxBar").get_node("MixtureBar")
		weapon.ammo_changed.connect(mixture_bar._on_ammo_changed)
		mixture_bar._on_ammo_changed(weapon.mixture_max_capacity, weapon.current_mixture_ammo)
		instance_hud.emit(hud)
		var inventory_screen_instance = inventory_screen_scene.instantiate()
		add_child(inventory_screen_instance)
		inventory_screen_instance.bind_inventory(inventory)
		inventory_screen_instance.bind_weapon(weapon)
		inventory_screen = inventory_screen_instance
		var alchemy_crafting = alchemy_crafting_scene.instantiate()
		add_child(alchemy_crafting)
		alchemy_crafting.bind_inventory(inventory)
		alchemy_crafting_screen = alchemy_crafting
		var weapon_crafting = weapon_crafting_scene.instantiate()
		add_child(weapon_crafting)
		weapon_crafting.bind_inventory(inventory)
		weapon_crafting_screen = weapon_crafting
		add_child(pause_menu_scene.instantiate())
	else:
		player_camera.enabled = false

func enable_dungeon_camera_mode() -> void:
	_dungeon_camera_mode = true
	if not is_inside_tree():
		call_deferred("enable_dungeon_camera_mode")
		return
	if not is_multiplayer_authority():
		return
	_camera_controller.update_zoom(get_viewport_rect().size)
	_camera_controller.update_room_limits(global_position)

func _on_viewport_size_changed() -> void:
	if _dungeon_camera_mode:
		_camera_controller.update_zoom(get_viewport_rect().size)

func _process(_delta: float) -> void:
	if is_dead:
		return
	water_fire_indicator.set_fill_ratio(weapon.get_water_cooldown_ratio())
	mixture_fire_indicator.set_fill_ratio(weapon.get_mixture_cooldown_ratio())
	if not sprite.animation.begins_with("walk-"):
		_footstep_last_frame = -1
		return
	var current_frame: int = sprite.frame
	if current_frame == _footstep_last_frame:
		return
	_footstep_last_frame = current_frame
	var frame_count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
	if current_frame == 0 or current_frame == frame_count / 2:
		AudioManager.play_sfx(RunManager.footstep_key_for_floor(RunManager.current_floor))

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_dead:
		if _death_animation_done:
			_spectator.process(_dungeon_camera_mode, _camera_controller.update_room_limits)
		return
	var aim_direction: Vector2 = _get_aim_direction()
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var facing_direction: Vector2 = _get_facing_direction(aim_direction, input_direction)
	_update_facing(facing_direction, input_direction.length() > 0.0)
	var water_pressed: bool = Input.is_action_pressed("fire_water") and weapon.is_water_fire_rate_ready()
	var mixture_pressed: bool = Input.is_action_pressed("fire_mixture") and weapon.is_mixture_fire_rate_ready()
	var fire_type := ""
	if not _is_ui_open():
		if water_pressed and not mixture_pressed:
			fire_type = "water"
		elif mixture_pressed and not water_pressed:
			fire_type = "mixture"
		elif water_pressed and mixture_pressed:
			if was_water_pressed:
				fire_type = "water"
			elif was_mixture_pressed:
				fire_type = "mixture"
			else:
				fire_type = "water"
	_try_play_attack_animation(aim_direction, fire_type)
	was_water_pressed = water_pressed
	was_mixture_pressed = mixture_pressed
	move(input_direction, speed)
	if _dungeon_camera_mode:
		_camera_controller.update_room_limits(global_position)

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
	var now: float = Time.get_ticks_msec() / 1000.0
	var stick_input: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick_input.length() > 0.0:
		last_stick_activity_time = now
	var current_mouse_screen_position: Vector2 = get_viewport().get_mouse_position()
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
		var mouse_delta: Vector2 = get_global_mouse_position() - global_position
		if mouse_delta.length() > 0.0:
			last_aim_direction = mouse_delta.normalized()
	return last_aim_direction

func _get_facing_direction(aim_direction: Vector2, input_direction: Vector2) -> Vector2:
	var now: float = Time.get_ticks_msec() / 1000.0
	if input_direction.length() > 0.0:
		last_movement_activity_time = now
	var aim_activity_time: float = max(last_stick_activity_time, last_mouse_activity_time)
	if last_movement_activity_time >= aim_activity_time and input_direction.length() > 0.0:
		return input_direction.normalized()
	return aim_direction

func _update_facing(direction: Vector2, is_moving: bool) -> void:
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	var prefix := "walk-" if is_moving else "idle-"
	var anim_name := StringName(prefix + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _is_ui_open() -> bool:
	if inventory_screen and inventory_screen.is_open():
		return true
	if alchemy_crafting_screen and alchemy_crafting_screen.is_open():
		return true
	if weapon_crafting_screen and weapon_crafting_screen.is_open():
		return true
	return false

func _is_other_ui_open(exclude: Node) -> bool:
	if inventory_screen and inventory_screen != exclude and inventory_screen.is_open():
		return true
	if alchemy_crafting_screen and alchemy_crafting_screen != exclude and alchemy_crafting_screen.is_open():
		return true
	if weapon_crafting_screen and weapon_crafting_screen != exclude and weapon_crafting_screen.is_open():
		return true
	return false

func _try_play_attack_animation(direction: Vector2, fire_type: String) -> void:
	if fire_type == "" or direction.length() < 0.001:
		return
	if sprite.animation.begins_with("attack") and sprite.is_playing():
		return
	_pending_fire_type = fire_type
	_pending_fire_direction = direction
	var anim_name := "attack-" + FacingDirection.label_for(direction)
	sprite.play(StringName(anim_name))
	_rpc_play_attack_animation.rpc(anim_name)

@rpc("authority", "call_remote", "reliable")
func _rpc_play_attack_animation(anim_name: String) -> void:
	sprite.play(StringName(anim_name))

func _on_sprite_animation_finished() -> void:
	if not sprite.animation.begins_with("attack"):
		return
	if _pending_fire_type == "":
		return
	if _pending_fire_type == "mixture" and not weapon.can_fire_mixture_locally():
		AudioManager.play_sfx("weapon_empty")
	else:
		AudioManager.play_sfx("fire_water" if _pending_fire_type == "water" else "fire_mixture")
	request_fire.rpc_id(1, _pending_fire_type, _pending_fire_direction)
	_pending_fire_type = ""

func _on_sprite_animation_changed() -> void:
	if is_multiplayer_authority():
		return
	sprite.play()

func open_alchemy_crafting() -> void:
	if alchemy_crafting_screen == null:
		return
	if not alchemy_crafting_screen.is_open() and _is_other_ui_open(alchemy_crafting_screen):
		return
	alchemy_crafting_screen.toggle()

func close_alchemy_crafting() -> void:
	if alchemy_crafting_screen:
		alchemy_crafting_screen.close()

func open_weapon_crafting() -> void:
	if weapon_crafting_screen == null:
		return
	if not weapon_crafting_screen.is_open() and _is_other_ui_open(weapon_crafting_screen):
		return
	weapon_crafting_screen.toggle()

func close_weapon_crafting() -> void:
	if weapon_crafting_screen:
		weapon_crafting_screen.close()

func can_open_inventory() -> bool:
	return not _is_other_ui_open(inventory_screen)

@rpc("any_peer", "call_local", "reliable")
func request_equip_weapon_part(part_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return

	var owned_part: Resource = null
	for part in inventory.weapon_parts:
		if part.resource_path == part_path:
			owned_part = part
			break
	if owned_part == null:
		return

	var new_piece: Resource = load(part_path)
	var old_piece: Resource = weapon.get_socket_occupant(new_piece)

	inventory.remove_weapon_part(owned_part)
	weapon.equip_networked(new_piece)

	if old_piece != null and old_piece.resource_path != "":
		inventory.add_weapon_part(old_piece)

const MAX_INGREDIENTS_PER_CRAFT: int = 3

@rpc("any_peer", "call_local", "reliable")
func request_craft_mixture(ingredient_paths: Array[String]) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return
	if ingredient_paths.is_empty():
		return
	if ingredient_paths.size() > MAX_INGREDIENTS_PER_CRAFT:
		return
	if RunManager.has_used_alchemy(sender_id):
		return

	var required_counts: Dictionary = {}
	for path in ingredient_paths:
		required_counts[path] = required_counts.get(path, 0) + 1

	for path in required_counts.keys():
		var ingredient: Ingredient = load(path) as Ingredient
		if ingredient == null:
			push_error("request_craft_mixture: ingrédient introuvable: %s" % path)
			return
		if inventory.get_ingredient_count(ingredient) < required_counts[path]:
			return

	for path in required_counts.keys():
		inventory.remove_ingredient(load(path) as Ingredient, required_counts[path])

	var combined_ingredient_paths: Array[String] = weapon.mixture_ingredient_paths.duplicate()
	combined_ingredient_paths.append_array(ingredient_paths)

	var full_recipe: Array[Ingredient] = []
	for path in combined_ingredient_paths:
		full_recipe.append(load(path) as Ingredient)

	var mixture: Mixture = AlchemyResolver.resoudre(full_recipe)
	var effect: ImpactEffect = MixtureToEffect.convertir(mixture)
	weapon.mixture_impact_effect = effect
	weapon.set_mixture_ingredients_networked(combined_ingredient_paths)
	RunManager.mark_alchemy_used(sender_id)
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
	collision_shape.set_deferred("disabled", true)
	water_fire_indicator.visible = false
	mixture_fire_indicator.visible = false
	sprite.play(StringName("death-" + FacingDirection.label_for(last_aim_direction)))
	await sprite.animation_finished
	if not is_instance_valid(self):
		return
	sprite.visible = false
	_death_animation_done = true
	if is_multiplayer_authority():
		_spectator.show_label(self)
		_spectator.pick_target()
		player_camera.position_smoothing_enabled = true
		player_camera.position_smoothing_speed = 2.5

func _on_health_changed(_max_lifepoint: float, lifepoint: float) -> void:
	if lifepoint <= 0:
		return
	if sprite.animation.begins_with("attack"):
		return
	sprite.play(StringName("hit-" + FacingDirection.label_for(last_aim_direction)))

