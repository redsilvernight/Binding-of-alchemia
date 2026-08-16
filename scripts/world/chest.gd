extends Node2D

# Coffre de la salle au trésor (Phase 9.2). Même convention que
# run_start_station.gd/unlock_station.gd : Interactable détecte, ce script
# relaie vers l'hôte. Son contenu (pièces d'arme) est assigné par
# game.gd juste après le spawn de la salle (cf. set_contents()) -- rien
# n'est spawné dans le monde avant l'ouverture.
#
# Visuel Closed/Open avec fondu (Phase 9.3), même pattern que door.gd :
# deux sprites superposés plutôt qu'une AnimatedSprite2D, l'ouverture du
# coffre étant un événement ponctuel qui n'a besoin que d'un état avant/après.

const FADE_DURATION: float = 0.3

@onready var interactable: Interactable = $Interactable
@onready var _closed_sprite: Sprite2D = $Closed
@onready var _open_sprite: Sprite2D = $Open

var _contents: Dictionary = {}
var _opened: bool = false


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_closed_sprite.modulate.a = 1.0
	_open_sprite.modulate.a = 0.0


func set_contents(contents: Dictionary) -> void:
	_contents = contents


func _on_interacted(_player: Node2D) -> void:
	_request_open.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_open() -> void:
	if not multiplayer.is_server():
		return
	if _opened:
		return
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game:
		game.request_open_chest(_contents)
	# Diffusé à tous les pairs (pas seulement l'hôte) -- même pattern que
	# game._rpc_mark_room_visited : sans ça, le joueur qui ouvre lui-même le
	# coffre ne verrait jamais le prompt disparaître localement.
	_rpc_mark_opened.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_mark_opened() -> void:
	_opened = true
	AudioManager.play_sfx("chest_open")
	interactable.visible = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_closed_sprite, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_property(_open_sprite, "modulate:a", 1.0, FADE_DURATION)
