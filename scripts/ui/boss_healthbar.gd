extends CanvasLayer

@onready var _bar: ProgressBar = $Bar
var _boss: Node = null

func _ready() -> void:
	visible = false
	_bar.show_percentage = false
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game:
		game.dungeon_map_changed.connect(_check_boss_room_visited.bind(game))
		_check_boss_room_visited(game)

func bind_boss(boss: Node) -> void:
	_boss = boss
	_bar.max_value = boss.max_lifepoint
	_bar.value = boss.lifepoint
	boss.health_changed.connect(_on_health_changed)
	boss.tree_exiting.connect(_on_boss_removed)

func _check_boss_room_visited(game: Node) -> void:
	for room_info in game.dungeon_map.values():
		if room_info.get("is_boss", false) and room_info.get("visited", false):
			visible = true
			return

func _on_health_changed(max_lifepoint: float, lifepoint: float) -> void:
	_bar.max_value = max_lifepoint
	_bar.value = lifepoint

func _on_boss_removed() -> void:
	queue_free()
