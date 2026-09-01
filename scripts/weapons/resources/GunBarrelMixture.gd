extends Resource
class_name GunBarrelMixture

@export var nom: String = ""
@export_multiline var description: String = ""
@export var fire_rate: float
@export var damage_multiplier: float
@export var projectile_speed: float
@export var trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.LINEAR
@export var impact_effect: ImpactEffect = null
@export var bounce_count: int = 0
@export var icon: Texture2D = null
