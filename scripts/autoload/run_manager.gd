extends Node

const DUNGEON_SCENE_PATH: String = "res://scenes/game.tscn"
const HUB_SCENE_PATH: String = "res://scenes/world/hub.tscn"

signal floor_changed(new_floor: int)
var current_floor: int = 1

signal alchemy_lock_changed(peer_id: int, used: bool)
var alchemy_used_by_peer: Dictionary = {}

const POOL_COUNT: int = 3
const FOOTSTEP_KEYS: Array[String] = [
	"footstep_cave",
	"footstep_crypt",
	"footstep_alchemy",
]

func pool_index_for_floor(floor_level: int) -> int:
	return (floor_level - 1) % POOL_COUNT

func footstep_key_for_floor(floor_level: int) -> String:
	return FOOTSTEP_KEYS[pool_index_for_floor(floor_level)]

signal pause_changed(paused: bool)
var is_paused: bool = false

var _saved_run_state: Dictionary = {}

const LOADING_SCREEN_SCENE_PATH: String = "res://scenes/ui/loading_screen.tscn"
var _loading_screen: CanvasLayer = null


func _ready() -> void:
	_loading_screen = (load(LOADING_SCREEN_SCENE_PATH) as PackedScene).instantiate()
	add_child(_loading_screen)

const SCENE_CHANGE_ACK_TIMEOUT: float = 3.0
const SCENE_CHANGE_ACK_POLL_INTERVAL: float = 0.05
var _peers_acked_scene_change: Dictionary = {}


func end_run() -> void:
	if not multiplayer.is_server():
		return
	_change_scene_with_handshake(HUB_SCENE_PATH)


@rpc("any_peer", "call_local", "reliable")
func request_return_to_hub() -> void:
	if not multiplayer.is_server():
		return
	reset_floor()
	end_run()


@rpc("any_peer", "call_local", "reliable")
func request_toggle_pause() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_paused.rpc(not is_paused)


@rpc("authority", "call_local", "reliable")
func _rpc_set_paused(value: bool) -> void:
	is_paused = value
	get_tree().paused = value
	pause_changed.emit(value)


@rpc("any_peer", "call_local", "reliable")
func request_start_run() -> void:
	if not multiplayer.is_server():
		return
	MetaProgression.reset_run_currency()
	MetaProgression.reroll_shop_pool_for_all()
	_change_scene_with_handshake(DUNGEON_SCENE_PATH)


func _change_scene_with_handshake(scene_path: String) -> void:
	show_loading_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	_peers_acked_scene_change.clear()
	var expected_peers: PackedInt32Array = NetworkManager.get_peers()
	if not expected_peers.is_empty():
		_rpc_prepare_scene_change.rpc()
		var elapsed: float = 0.0
		while elapsed < SCENE_CHANGE_ACK_TIMEOUT:
			var all_acked: bool = true
			for peer_id in expected_peers:
				if not _peers_acked_scene_change.has(peer_id):
					all_acked = false
					break
			if all_acked:
				break
			await get_tree().create_timer(SCENE_CHANGE_ACK_POLL_INTERVAL).timeout
			elapsed += SCENE_CHANGE_ACK_POLL_INTERVAL
	_rpc_change_scene.rpc(scene_path)


@rpc("authority", "reliable")
func _rpc_prepare_scene_change() -> void:
	_rpc_ack_scene_change.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_ack_scene_change() -> void:
	if not multiplayer.is_server():
		return
	_peers_acked_scene_change[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_local", "reliable")
func _rpc_change_scene(scene_path: String) -> void:
	if is_paused:
		is_paused = false
		get_tree().paused = false
		pause_changed.emit(false)
	get_tree().change_scene_to_file.call_deferred(scene_path)


func advance_floor() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_floor.rpc(current_floor + 1, true)


func reset_floor() -> void:
	if not multiplayer.is_server():
		return
	_saved_run_state.clear()
	_rpc_set_floor.rpc(1, false)


func save_run_state(peer_id: int, snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_saved_run_state[peer_id] = snapshot


func take_saved_run_state(peer_id: int) -> Dictionary:
	if not _saved_run_state.has(peer_id):
		return {}
	var snapshot: Dictionary = _saved_run_state[peer_id]
	_saved_run_state.erase(peer_id)
	return snapshot


@rpc("authority", "call_local", "reliable")
func _rpc_set_floor(new_floor: int, play_sound: bool = true) -> void:
	current_floor = new_floor
	floor_changed.emit(new_floor)
	alchemy_used_by_peer.clear()
	if play_sound:
		AudioManager.play_sfx("floor_advance")


func has_used_alchemy(peer_id: int) -> bool:
	return alchemy_used_by_peer.get(peer_id, false)


func mark_alchemy_used(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_alchemy_used.rpc(peer_id, true)


@rpc("authority", "call_local", "reliable")
func _rpc_set_alchemy_used(peer_id: int, used: bool) -> void:
	alchemy_used_by_peer[peer_id] = used
	alchemy_lock_changed.emit(peer_id, used)


func show_loading_screen() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_loading.rpc(true)


func hide_loading_screen() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_loading.rpc(false)


@rpc("authority", "call_local", "reliable")
func _rpc_set_loading(is_loading: bool) -> void:
	if is_loading:
		_loading_screen.show_loading()
	else:
		_loading_screen.hide_loading()
