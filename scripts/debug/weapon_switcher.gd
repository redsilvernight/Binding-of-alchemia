extends Node

@export var target_weapon: Weapon

var combos: Array[Dictionary] = [
	{
		"barrel_water": preload("res://resources/GunParts/water_barel_basic.tres"),
		"barrel_mixture": preload("res://resources/GunParts/mixture_barrel_basic.tres"),
		"tank": preload("res://resources/GunParts/tank_basic.tres"),
		"core": preload("res://resources/GunParts/core_basic.tres"),
	},
	{
		"barrel_water": preload("res://resources/GunParts/water_barel_fast.tres"),
		"barrel_mixture": preload("res://resources/GunParts/mixture_barrel_heavy.tres"),
		"tank": preload("res://resources/GunParts/tank_large.tres"),
		"core": preload("res://resources/GunParts/core_range.tres"),
	},
	{
		"barrel_water": preload("res://resources/GunParts/water_barel_basic.tres"),
		"barrel_mixture": preload("res://resources/GunParts/mixture_barrel_basic.tres"),
		"tank": preload("res://resources/GunParts/tank_basic.tres"),
		"core": null,
	},
]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	var index = event.keycode - KEY_1

	if index >= 0 and index < combos.size():
		_apply_combo(combos[index])

func _apply_combo(combo: Dictionary) -> void:
	for piece in combo.values():
		if piece != null:
			target_weapon.equip(piece)
