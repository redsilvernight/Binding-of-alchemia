# player.gd
extends Character
signal instance_hud(hud: Node)
signal instance_projectile(data: Dictionary)
@export var speed: float = 300.0
@export var hud_scene: PackedScene = preload("res://scenes/HUD/hud.tscn")
@onready var player_camera: Camera2D = $Camera2D
@onready var damage_timer: Timer = $DamageTimer
@onready var weapon: Weapon = $Weapon
var was_water_pressed: bool = false
var was_mixture_pressed: bool = false
var last_aim_direction: Vector2 = Vector2.RIGHT
var last_stick_activity_time: float = -INF
var last_mouse_activity_time: float = -INF
var last_mouse_screen_position: Vector2 = Vector2.ZERO
var mouse_position_initialized: bool = false

func _ready() -> void:
	super()
	add_to_group("Players")
	weapon.projectile_requested.connect(_on_projectile_requested)
	if is_multiplayer_authority():
		player_camera.enabled = true
		var hud = hud_scene.instantiate()
		health_changed.connect(hud.get_node("VBoxBar").get_node("LifeBar")._on_heal_changed)
		var mixture_bar = hud.get_node("VBoxBar").get_node("MixtureBar")
		weapon.ammo_changed.connect(mixture_bar._on_ammo_changed)
		mixture_bar._on_ammo_changed(weapon.mixture_max_capacity, weapon.current_mixture_ammo)
		instance_hud.emit(hud)

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
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

func _on_projectile_requested(data: Dictionary) -> void:
	instance_projectile.emit(data)

func _on_damage_timer_timeout() -> void:
	can_take_damage = true
