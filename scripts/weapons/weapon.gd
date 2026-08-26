extends Node2D
class_name Weapon

signal ammo_changed(current: float, max: float)
signal projectile_requested(data: Dictionary)
signal part_equipped(piece: Resource)
signal mixture_changed(ingredient_paths: Array[String])

const WATER_BULLET_SCENE: String = "res://scenes/projectiles/bullet_water.tscn"
const MIXTURE_BULLET_SCENE: String = "res://scenes/projectiles/bullet_mixture.tscn"

@export var barrel_water: GunBarrelWater
@export var barrel_mixture: GunBarrelMixture
@export var tank: GunTank
@export var core: GunCore

var _initialized: bool = false
var water_fire_rate: float
var water_damage: float
var water_projectile_speed: float
var mixture_fire_rate: float
var mixture_damage_multiplier: float
var mixture_projectile_speed: float
var mixture_max_capacity: float
var mixture_regen_rate: float
var _range: float
var current_mixture_ammo: float = 0.0
var time_since_last_mixture_fire: float = 0.0
var can_fire_water: bool = false
var can_fire_mixture: bool = false
var water_cooldown_accum: float = INF
var mixture_cooldown_accum: float = INF
var water_trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.LINEAR
var mixture_trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.LINEAR
var mixture_impact_effect: ImpactEffect = null
var mixture_ingredient_paths: Array[String] = []

func _ready() -> void:
	_recalculate_stats()

func _process(delta: float) -> void:
	water_cooldown_accum += delta
	mixture_cooldown_accum += delta

	if not multiplayer.is_server():
		return

	if tank == null:
		return

	time_since_last_mixture_fire += delta

	if time_since_last_mixture_fire >= tank.regen_delay and current_mixture_ammo < mixture_max_capacity:
		var previous_ammo: float = current_mixture_ammo
		current_mixture_ammo = min(current_mixture_ammo + mixture_regen_rate * delta, mixture_max_capacity)
		if current_mixture_ammo != previous_ammo:
			_broadcast_ammo()

func get_socket_occupant(piece: Resource) -> Resource:
	if piece is GunBarrelWater:
		return barrel_water
	elif piece is GunBarrelMixture:
		return barrel_mixture
	elif piece is GunTank:
		return tank
	elif piece is GunCore:
		return core
	return null

func equip(piece: Resource) -> void:
	if piece is GunBarrelWater:
		barrel_water = piece
	elif piece is GunBarrelMixture:
		barrel_mixture = piece
	elif piece is GunTank:
		tank = piece
		current_mixture_ammo = piece.max_capacity
	elif piece is GunCore:
		core = piece
	_recalculate_stats()
	part_equipped.emit(piece)

func equip_networked(piece: Resource) -> void:
	if is_inside_tree():
		_rpc_equip.rpc(piece.resource_path)
	else:
		equip(piece)

@rpc("any_peer", "call_local", "reliable")
func _rpc_equip(part_path: String) -> void:
	equip(load(part_path))
	if is_multiplayer_authority():
		AudioManager.play_sfx("weapon_equip")

func set_mixture_ingredients_networked(ingredient_paths: Array[String]) -> void:
	if is_inside_tree():
		_rpc_set_mixture_ingredients.rpc(ingredient_paths)
	else:
		mixture_ingredient_paths = ingredient_paths
		mixture_changed.emit(ingredient_paths)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_mixture_ingredients(ingredient_paths: Array[String]) -> void:
	mixture_ingredient_paths = ingredient_paths
	mixture_changed.emit(ingredient_paths)
	if is_multiplayer_authority():
		AudioManager.play_sfx("craft_success")

func _recalculate_stats() -> void:
	var stats: WeaponStats = WeaponStatsResolver.resoudre(barrel_water, barrel_mixture, tank, core)
	water_fire_rate = stats.water_fire_rate
	water_damage = stats.water_damage
	water_projectile_speed = stats.water_projectile_speed
	mixture_fire_rate = stats.mixture_fire_rate
	mixture_damage_multiplier = stats.mixture_damage_multiplier
	mixture_projectile_speed = stats.mixture_projectile_speed
	mixture_max_capacity = stats.mixture_max_capacity
	mixture_regen_rate = stats.mixture_regen_rate
	_range = stats.range_value

	if barrel_water:
		water_trajectory = barrel_water.trajectory
	else:
		push_warning("Weapon: aucun barrel_water équipé, le tir eau est désactivé.")
	if barrel_mixture:
		mixture_trajectory = barrel_mixture.trajectory
		mixture_impact_effect = barrel_mixture.impact_effect
	else:
		mixture_impact_effect = null

	can_fire_water = water_fire_rate > 0
	can_fire_mixture = mixture_fire_rate > 0 and tank != null
	if not _initialized:
		current_mixture_ammo = mixture_max_capacity
		_initialized = true
	else:
		current_mixture_ammo = min(current_mixture_ammo, mixture_max_capacity)
	ammo_changed.emit(current_mixture_ammo, mixture_max_capacity)

func can_fire_mixture_locally() -> bool:
	return can_fire_mixture and tank != null and current_mixture_ammo >= tank.mixture_cost_per_shot

func is_water_fire_rate_ready() -> bool:
	return can_fire_water and water_cooldown_accum >= 1.0 / water_fire_rate

func is_mixture_fire_rate_ready() -> bool:
	return can_fire_mixture and mixture_cooldown_accum >= 1.0 / mixture_fire_rate

func get_water_cooldown_ratio() -> float:
	if not can_fire_water:
		return 1.0
	return clamp(water_cooldown_accum / (1.0 / water_fire_rate), 0.0, 1.0)

func get_mixture_cooldown_ratio() -> float:
	if not can_fire_mixture:
		return 1.0
	return clamp(mixture_cooldown_accum / (1.0 / mixture_fire_rate), 0.0, 1.0)

func try_fire_water(direction: Vector2) -> bool:
	if not can_fire_water:
		return false
	if water_cooldown_accum < 1.0 / water_fire_rate:
		return false

	_broadcast_water_cooldown_reset()
	_fire_bullet(water_damage, water_projectile_speed, direction, water_trajectory, null, WATER_BULLET_SCENE)
	return true

func try_fire_mixture(direction: Vector2) -> bool:
	if not multiplayer.is_server():
		return false
	if not can_fire_mixture:
		return false
	if mixture_cooldown_accum < 1.0 / mixture_fire_rate:
		return false
	if current_mixture_ammo < tank.mixture_cost_per_shot:
		return false

	_broadcast_mixture_cooldown_reset()
	current_mixture_ammo -= tank.mixture_cost_per_shot
	time_since_last_mixture_fire = 0.0
	_broadcast_ammo()

	_fire_bullet(mixture_damage_multiplier, mixture_projectile_speed, direction, mixture_trajectory, mixture_impact_effect, MIXTURE_BULLET_SCENE)
	return true

func _broadcast_water_cooldown_reset() -> void:
	if is_inside_tree():
		_reset_water_cooldown.rpc()
	else:
		water_cooldown_accum = 0.0

@rpc("any_peer", "call_local", "reliable")
func _reset_water_cooldown() -> void:
	water_cooldown_accum = 0.0

func _broadcast_mixture_cooldown_reset() -> void:
	if is_inside_tree():
		_reset_mixture_cooldown.rpc()
	else:
		mixture_cooldown_accum = 0.0

@rpc("any_peer", "call_local", "reliable")
func _reset_mixture_cooldown() -> void:
	mixture_cooldown_accum = 0.0

func _broadcast_ammo() -> void:
	if is_inside_tree():
		_update_ammo.rpc(current_mixture_ammo, mixture_max_capacity)
	else:
		ammo_changed.emit(current_mixture_ammo, mixture_max_capacity)

@rpc("any_peer", "call_local", "reliable")
func _update_ammo(current: float, max_ammo: float) -> void:
	current_mixture_ammo = current
	mixture_max_capacity = max_ammo
	ammo_changed.emit(current_mixture_ammo, mixture_max_capacity)

func _fire_bullet(damage: float, speed: float, direction: Vector2, trajectory: Bullet.TrajectoryType, effect: ImpactEffect, scene_path: String) -> void:
	var shooter_id: int = 0
	var parent_node := get_parent()
	if parent_node != null and parent_node.name.is_valid_int():
		shooter_id = int(parent_node.name)
	var data: Dictionary = {
		"damage": damage,
		"speed": speed,
		"lifetime": 3.0,
		"trajectory": trajectory,
		"from_position": global_position,
		"direction": direction,
		"scene_path": scene_path,
		"shooter_id": shooter_id,
	}
	if effect != null:
		data["impact_effect_data"] = effect.to_dict()
	projectile_requested.emit(data)
