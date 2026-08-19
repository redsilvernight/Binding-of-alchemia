extends Node2D

# Station d'alchimie (Phase 5.3/5.5). Relie le signal générique d'Interactable
# à l'ouverture de l'écran de crafting du joueur qui a interagi, et gère le
# rack de fioles décoratives (une par joueur présent dans le donjon, cf.
# AlchemyVial) -- retour utilisateur : rendre visible ET amusant le verrou
# "un craft par joueur par étage" (RunManager.alchemy_used_by_peer) sans que
# ce soit perçu comme une mécanique à part -- purement décoratif, aucune
# interaction possible avec les fioles elles-mêmes.

const VIAL_SCENE: PackedScene = preload("res://scenes/world/alchemy_vial.tscn")
## Décalage entre deux fioles voisines du rack -- retour utilisateur : rester
## un petit accessoire, jamais une rangée qui envahit la salle, cf. _layout_vials().
const VIAL_SPACING: Vector2 = Vector2(26.0, 0.0)
## Position du rack relative à AlchemyStation -- au pied du plan de travail
## (cf. BenchVisual), hors du rayon d'interaction (CircleShape2D radius 80,
## cf. room_alchemy.tscn) pour ne jamais gêner le prompt "E".
const VIAL_RACK_OFFSET: Vector2 = Vector2(-39.0, 46.0)

@onready var interactable: Interactable = $Interactable

## peer_id (int) -> AlchemyVial. Une entrée par joueur actuellement présent
## dans le donjon, cf. _on_player_added()/_on_player_removed().
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


## Retour utilisateur : fermer l'écran en s'éloignant, plutôt que de le
## laisser ouvert sur une table qu'on ne touche plus.
func _on_player_left(player: Node2D) -> void:
	if player.has_method("close_alchemy_crafting"):
		player.close_alchemy_crafting()


## Casse la fiole du joueur concerné -- diffusé à tous les pairs (cf.
## RunManager._rpc_set_alchemy_used), donc la casse (bruit inclus) est bien
## vue et entendue par tout le monde, pas seulement par qui a crafté.
func _on_alchemy_used(peer_id: int, used: bool) -> void:
	if not used:
		return
	var vial: AlchemyVial = _vials.get(peer_id)
	if vial != null:
		vial.break_effect()


## Rack de fioles : un enfant par joueur PRÉSENT DANS LE DONJON (pas par
## joueur "de la partie" au sens large -- RunManager ne suit rien de tel),
## donc calqué sur le conteneur "Players" du donjon plutôt qu'une liste
## globale. Récupéré via le groupe "Game" (cf. game.gd et
## mixture_test_room_controller.gd, tous deux add_to_group("Game")) plutôt
## qu'un chemin en dur : ce script tourne dans les deux scènes.
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


## child_entered_tree (pas le groupe "Players") : ce signal tourne au moment
## de l'entrée en arbre, avant que Player._ready() n'ait appelé
## add_to_group("Players") -- mais ce conteneur ne contient de toute façon
## jamais que des joueurs (cf. PlayerManager.spawnPlayer, qui nomme déjà le
## noeud str(peer_id) avant l'add_child), donc pas besoin de ce groupe ici.
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


## Cf. header de _on_player_added -- même conteneur, donc même garantie
## qu'un enfant qui en sort est toujours un joueur qui se déconnecte (cf.
## game.gd._on_peer_disconnected) -- la fiole disparaît avec lui.
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


## Rangée simple centrée sur VIAL_RACK_OFFSET, triée par peer_id pour un ordre
## stable (indépendant de l'ordre d'arrivée des signaux réseau) -- suffisant
## pour un petit groupe coopératif, cf. header (accessoire mineur, pas une
## présentation censée supporter une foule).
func _layout_vials() -> void:
	var peer_ids: Array = _vials.keys()
	peer_ids.sort()
	var start: Vector2 = VIAL_RACK_OFFSET - VIAL_SPACING * (float(peer_ids.size() - 1) / 2.0)
	for i in peer_ids.size():
		_vials[peer_ids[i]].position = start + VIAL_SPACING * i
