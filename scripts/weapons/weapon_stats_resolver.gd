class_name WeaponStatsResolver
extends RefCounted

static func resoudre(barrel_water: GunBarrelWater, barrel_mixture: GunBarrelMixture, tank: GunTank, core: GunCore) -> WeaponStats:
	var stats := WeaponStats.new()
	var base_speed_water: float = 0.0
	var base_speed_mixture: float = 0.0

	if barrel_water:
		stats.water_fire_rate = barrel_water.fire_rate
		stats.water_damage = barrel_water.base_damage
		base_speed_water = barrel_water.projectile_speed

	if barrel_mixture:
		stats.mixture_fire_rate = barrel_mixture.fire_rate
		stats.mixture_damage_multiplier = barrel_mixture.damage_multiplier
		base_speed_mixture = barrel_mixture.projectile_speed

	if tank:
		stats.mixture_max_capacity = tank.max_capacity
		stats.mixture_regen_rate = tank.regen_rate

	var speed_modifier: float = 1.0
	var core_damage: float = 0.0
	if core:
		speed_modifier = core.projectile_speed_modifier
		stats.range_value = core.range_modifier
		core_damage = core.base_damage

	stats.water_damage += core_damage
	stats.mixture_damage_multiplier += core_damage
	stats.water_projectile_speed = base_speed_water * speed_modifier
	stats.mixture_projectile_speed = base_speed_mixture * speed_modifier

	return stats
