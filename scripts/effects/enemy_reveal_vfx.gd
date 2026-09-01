class_name EnemyRevealVfx
extends Node2D

@onready var _particles: GPUParticles2D = $Particles


func _ready() -> void:
	_particles.finished.connect(queue_free)
