extends CharacterBody2D

@export var speed: float = 200.0

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	move_and_slide()
