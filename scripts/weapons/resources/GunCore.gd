extends Resource
class_name GunCore

@export var nom: String = ""
@export_multiline var description: String = ""
@export var range_modifier: float
@export var base_damage: float
@export var projectile_speed_modifier: float
@export var dash_duration_modifier: float = 1.0
@export var dash_speed_modifier: float = 1.0
@export var dash_cooldown_modifier: float = 1.0
@export var icon: Texture2D = null
