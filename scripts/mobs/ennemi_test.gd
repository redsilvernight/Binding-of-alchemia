extends Character
@export var speed: float = 150.0
@export var damage: float = 5.0
var target: Node2D = null

func _ready() -> void:
	super()
	add_to_group("Enemies")

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	_update_target()
	if target and is_instance_valid(target):
		var direction: Vector2 = global_position.direction_to(target.global_position)
		move(direction, speed)

func _update_target() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	var closest: Node2D = null
	var closest_distance: float = INF
	for player in players:
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = player
	target = closest

func _on_collision_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		body.take_damage(damage)
