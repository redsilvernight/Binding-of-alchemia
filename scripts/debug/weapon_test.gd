extends Node

var water_barrel: GunBarrelWater = load("res://resources/GunParts/water_barel_basic.tres")
var mixture_barrel: GunBarrelMixture = load("res://resources/GunParts/mixture_barrel_basic.tres")
var tank: GunTank = load("res://resources/GunParts/tank_basic.tres")
var core: GunCore = load("res://resources/GunParts/core_basic.tres")

func _ready() -> void:
	var current_weapon = Weapon.new()
	
	current_weapon.equip(water_barrel)
	current_weapon.equip(mixture_barrel)
	current_weapon.equip(tank)
	current_weapon.equip(core)
	
	printStats(current_weapon)
	
func printStats(weapon: Weapon) -> void:
	print(
		"water_fire_rate :" + str(weapon.water_fire_rate) + "\n",
		"water_damage :" + str(weapon.water_damage) + "\n",
		"water_projectile_speed :" + str(weapon.water_projectile_speed) + "\n",
		"mixture_fire_rate :" + str(weapon.mixture_fire_rate) + "\n",
		"mixture_damage_multiplier :" + str(weapon.mixture_damage_multiplier) + "\n",
		"mixture_projectile_speed :" + str(weapon.mixture_projectile_speed) + "\n",
		"mixture_max_capacity :" + str(weapon.mixture_max_capacity) + "\n",
		"mixture_regen_rate :" + str(weapon.mixture_regen_rate) + "\n",
		"range :" + str(weapon._range) + "\n"
	)
