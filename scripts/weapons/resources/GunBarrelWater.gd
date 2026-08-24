extends Resource
class_name GunBarrelWater

@export var nom: String = ""
@export var fire_rate: float
@export var base_damage: float
@export var projectile_speed: float
@export var trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.HOMING
@export var icon: Texture2D = null
