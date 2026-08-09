# game.gd
extends Control
@onready var players: Node2D = $Players
@onready var ennemis: Node2D = $Ennemis
@onready var HUD: Node2D = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

func _ready() -> void:
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	projectile_spawner.spawn_function = _spawn_bullet
	enemy_spawner.spawn_function = _spawn_enemy
	player_spawner.spawn_function = _spawn_player

	if multiplayer.is_server():
		# Avant : chaque client instanciait manuellement un Player par pair
		# connu (players.add_child côté client, sans MultiplayerSpawner).
		# Ça marchait tant que peer_connected/get_peers() restaient bien
		# synchronisés, mais ne bénéficiait pas du rattrapage automatique
		# natif pour un pair qui rejoint en cours de partie (contrairement
		# aux projectiles/ennemis, qui l'ont déjà). Même pattern maintenant :
		# seul l'hôte spawn, MultiplayerSpawner réplique et rattrape seul.
		player_spawner.spawn(NetworkManager.get_unique_id())
		for i in range(1):
			enemy_spawner.spawn({"position": Vector2(i * 40, 0)})

func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawnPlayer(id)
	player.instance_hud.connect(_hud_instance)
	player.instance_projectile.connect(_on_projectile_requested)
	return player

func _spawn_bullet(data: Dictionary) -> Node:
	var bullet: Bullet = preload("res://scenes/projectiles/bullet.tscn").instantiate()
	bullet.setup(data["damage"], data["speed"], data["lifetime"], data["trajectory"])
	if data.has("impact_effect_data"):
		var effect: ImpactEffect = ImpactEffect.from_dict(data["impact_effect_data"])
		bullet.set_impact_effect(effect)
	bullet.launch.call_deferred(data["from_position"], data["direction"])
	return bullet

func _spawn_enemy(data: Dictionary) -> Node:
	var enemy: Node = EnemyManager.get_enemy_scene().instantiate()
	enemy.position = data["position"]
	return enemy

func _on_peer_disconnected(peer_id) -> void:
	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)

func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)

func _on_projectile_requested(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)
