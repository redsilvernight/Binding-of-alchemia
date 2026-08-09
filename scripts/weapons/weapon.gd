# weapon.gd
extends Node2D
class_name Weapon

signal ammo_changed(current: float, max: float)
signal projectile_requested(data: Dictionary)

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
var water_cooldown_accum: float = 0.0
var mixture_cooldown_accum: float = 0.0
var water_trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.LINEAR
var mixture_trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.LINEAR
var mixture_impact_effect: ImpactEffect = null

func _ready() -> void:
	_recalculate_stats()

func _process(delta: float) -> void:
	water_cooldown_accum += delta
	mixture_cooldown_accum += delta

	if tank == null:
		return

	time_since_last_mixture_fire += delta

	if time_since_last_mixture_fire >= tank.regen_delay and current_mixture_ammo < mixture_max_capacity:
		var previous_ammo = current_mixture_ammo
		current_mixture_ammo = min(current_mixture_ammo + mixture_regen_rate * delta, mixture_max_capacity)
		if current_mixture_ammo != previous_ammo:
			ammo_changed.emit(current_mixture_ammo, mixture_max_capacity)

func equip(piece) -> void:
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

func _recalculate_stats():
	var base_speed_water = 0.0
	var base_speed_mixture = 0.0
	if barrel_water:
		water_fire_rate = barrel_water.fire_rate
		water_damage = barrel_water.base_damage
		base_speed_water = barrel_water.projectile_speed
		water_trajectory = barrel_water.trajectory
	else:
		water_fire_rate = 0
		water_damage = 0
		push_warning("Weapon: aucun barrel_water équipé, le tir eau est désactivé.")
	if barrel_mixture:
		mixture_fire_rate = barrel_mixture.fire_rate
		mixture_damage_multiplier = barrel_mixture.damage_multiplier
		base_speed_mixture = barrel_mixture.projectile_speed
		mixture_trajectory = barrel_mixture.trajectory
		mixture_impact_effect = barrel_mixture.impact_effect
	else:
		mixture_fire_rate = 0
		mixture_damage_multiplier = 0
		mixture_impact_effect = null
	if tank:
		mixture_max_capacity = tank.max_capacity
		mixture_regen_rate = tank.regen_rate
	else:
		mixture_max_capacity = 0
		mixture_regen_rate = 0
	var speed_modifier = 1.0
	var range_modifier = 0.0
	if core:
		speed_modifier = core.projectile_speed_modifier
		range_modifier = core.range_modifier
	water_projectile_speed = base_speed_water * speed_modifier
	mixture_projectile_speed = base_speed_mixture * speed_modifier
	_range = range_modifier

	can_fire_water = water_fire_rate > 0
	can_fire_mixture = mixture_fire_rate > 0 and tank != null
	if not _initialized:
		current_mixture_ammo = mixture_max_capacity
		_initialized = true
	else:
		current_mixture_ammo = min(current_mixture_ammo, mixture_max_capacity)
	ammo_changed.emit(current_mixture_ammo, mixture_max_capacity)

func try_fire_water(direction: Vector2) -> bool:
	if not can_fire_water:
		return false
	if water_cooldown_accum < 1.0 / water_fire_rate:
		return false

	water_cooldown_accum = 0.0
	_fire_bullet(water_damage, water_projectile_speed, direction, water_trajectory, null)
	return true

func try_fire_mixture(direction: Vector2) -> bool:
	if not can_fire_mixture:
		return false
	if mixture_cooldown_accum < 1.0 / mixture_fire_rate:
		return false
	if current_mixture_ammo < tank.mixture_cost_per_shot:
		return false

	mixture_cooldown_accum = 0.0
	current_mixture_ammo -= tank.mixture_cost_per_shot
	time_since_last_mixture_fire = 0.0
	ammo_changed.emit(current_mixture_ammo, mixture_max_capacity)

	_fire_bullet(mixture_damage_multiplier, mixture_projectile_speed, direction, mixture_trajectory, mixture_impact_effect)
	return true

func _fire_bullet(damage: float, speed: float, direction: Vector2, trajectory: Bullet.TrajectoryType, effect: ImpactEffect) -> void:
	var data: Dictionary = {
		"damage": damage,
		"speed": speed,
		"lifetime": 3.0,
		"trajectory": trajectory,
		"from_position": global_position,
		"direction": direction,
	}
	if effect != null:
		data["impact_effect_path"] = effect.resource_path
	projectile_requested.emit(data)
