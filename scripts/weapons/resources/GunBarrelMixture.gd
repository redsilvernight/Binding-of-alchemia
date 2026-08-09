extends Resource
class_name GunBarrelMixture

@export var fire_rate: float
@export var damage_multiplier: float
@export var projectile_speed: float
@export var trajectory: Bullet.TrajectoryType = Bullet.TrajectoryType.LINEAR
@export var impact_effect: ImpactEffect = null
@export var icon: Texture2D = null # Placeholder tant que l'art définitif n'existe pas (Phase 9.2)
