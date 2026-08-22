class_name PlayerSpectator
extends RefCounted

## Extrait de player.gd (File Size, cf. .claude/rules/gdscript.md) : mode
## spectateur après la mort (Phase 9.3, façon Binding of Isaac) -- choix/
## cycle d'une cible parmi les coéquipiers vivants, et suivi caméra. `_player`
## est le Player propriétaire (nécessaire pour get_tree() et se comparer
## lui-même dans la recherche de candidats) ; `_camera` est sa Camera2D.

var _player: Node2D
var _camera: Camera2D
var _spectate_target: Node2D = null

func _init(player: Node2D, camera: Camera2D) -> void:
	_player = player
	_camera = camera

## update_room_limits : Callable (PlayerCameraController.update_room_limits)
## appelée uniquement en mode donjon (cf. Player._dungeon_camera_mode), même
## contrat que dans Player._physics_process.
func process(dungeon_camera_mode: bool, update_room_limits: Callable) -> void:
	if Input.is_action_just_pressed("spectate_next"):
		pick_target(true)
	elif not is_instance_valid(_spectate_target) or _spectate_target.is_dead:
		pick_target()
	if is_instance_valid(_spectate_target):
		_camera.global_position = _spectate_target.global_position
		if dungeon_camera_mode:
			update_room_limits.call(_spectate_target.global_position)

func pick_target(cycle: bool = false) -> void:
	var candidates: Array = []
	for p in _player.get_tree().get_nodes_in_group("Players"):
		if p != _player and not p.is_dead:
			candidates.append(p)
	if candidates.is_empty():
		_spectate_target = null
		return
	if not cycle or _spectate_target == null or not candidates.has(_spectate_target):
		_spectate_target = candidates[0]
		return
	var current_index: int = candidates.find(_spectate_target)
	_spectate_target = candidates[(current_index + 1) % candidates.size()]

func show_label(parent: Node) -> void:
	var label := Label.new()
	label.text = "Vous êtes mort — Espace pour changer de vue"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 40
	label.size.x = 400
	label.position.x -= 200
	var layer := CanvasLayer.new()
	layer.add_child(label)
	parent.add_child(layer)
