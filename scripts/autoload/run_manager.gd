extends Node
## Phase 8.1 : bascule de scène synchronisée hôte -> tous les pairs, entre le
## donjon et le hub. Autoload donc persiste à travers change_scene_to_file
## (contrairement à "Game"/"Hub", qui sont détruits à chaque bascule) : seul
## endroit fiable pour porter cette transition à travers les deux scènes.

const DUNGEON_SCENE_PATH: String = "res://scenes/game.tscn"
const HUB_SCENE_PATH: String = "res://scenes/world/hub.tscn"


## Appelé côté hôte quand tous les joueurs de la run en cours sont morts
## (cf. game.gd._check_all_players_dead).
func end_run() -> void:
	if not multiplayer.is_server():
		return
	_rpc_change_scene.rpc(HUB_SCENE_PATH)


## Requêtable par n'importe quel pair depuis le hub (RunStartStation) :
## seul l'hôte décide réellement, même garde que request_fire/request_craft_mixture.
@rpc("any_peer", "call_local", "reliable")
func request_start_run() -> void:
	if not multiplayer.is_server():
		return
	_rpc_change_scene.rpc(DUNGEON_SCENE_PATH)


@rpc("authority", "call_local", "reliable")
func _rpc_change_scene(scene_path: String) -> void:
	# call_deferred : end_run() est atteint depuis take_damage() -> _update_health()
	# -> died.emit(), souvent lui-même déclenché depuis un callback physique
	# (ex : contact ennemi, cf. enemy_erratic.gd._on_collision_area_body_entered).
	# Un change_scene_to_file() direct y détruit des CollisionObject2D en plein
	# callback physique (erreur moteur) et peut libérer le noeud joueur avant
	# que les autres listeners de "died" (ex : Player._on_died) aient tourné.
	get_tree().change_scene_to_file.call_deferred(scene_path)
