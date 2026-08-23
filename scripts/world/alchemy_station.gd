extends Node2D


const VIAL_SCENE: PackedScene = preload("res://scenes/world/alchemy_vial.tscn")
const VIAL_SPACING: Vector2 = Vector2(26.0, 0.0)
const VIAL_RACK_OFFSET: Vector2 = Vector2(-39.0, 46.0)

@onready var interactable: Interactable = $Interactable

var _vials: Dictionary = {}


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	interactable.player_left.connect(_on_player_left)
	RunManager.alchemy_lock_changed.connect(_on_alchemy_used)
	_setup_vial_rack()


func _on_interacted(player: Node2D) -> void:
	if RunManager.has_used_alchemy(int(player.name)):
		return
	if player.has_method("open_alchemy_crafting"):
		player.open_alchemy_crafting()


func _on_player_left(player: Node2D) -> void:
	if player.has_method("close_alchemy_crafting"):
		player.close_alchemy_crafting()


func _on_alchemy_used(peer_id: int, used: bool) -> void:
	if not used:
		return
	var vial: AlchemyVial = _vials.get(peer_id)
	if vial != null:
		vial.break_effect()


func _setup_vial_rack() -> void:
	var game_node: Node = get_tree().get_first_node_in_group("Game")
	if game_node == null:
		return
	var players_container: Node = game_node.get_node_or_null("Players")
	if players_container == null:
		return
	players_container.child_entered_tree.connect(_on_player_added)
	players_container.child_exiting_tree.connect(_on_player_removed)
	for child in players_container.get_children():
		_on_player_added(child)


func _on_player_added(player: Node) -> void:
	if not player.name.is_valid_int():
		return
	var peer_id: int = int(player.name)
	if _vials.has(peer_id):
		return
	var vial: AlchemyVial = VIAL_SCENE.instantiate()
	add_child(vial)
	vial.peer_id = peer_id
	vial.set_broken(RunManager.has_used_alchemy(peer_id))
	_vials[peer_id] = vial
	_layout_vials()


func _on_player_removed(player: Node) -> void:
	if not player.name.is_valid_int():
		return
	var peer_id: int = int(player.name)
	var vial: AlchemyVial = _vials.get(peer_id)
	if vial == null:
		return
	_vials.erase(peer_id)
	vial.queue_free()
	_layout_vials()


func _layout_vials() -> void:
	var peer_ids: Array = _vials.keys()
	peer_ids.sort()
	var start: Vector2 = VIAL_RACK_OFFSET - VIAL_SPACING * (float(peer_ids.size() - 1) / 2.0)
	for i in peer_ids.size():
		_vials[peer_ids[i]].position = start + VIAL_SPACING * i
