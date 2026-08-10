class_name Interactable
extends Area2D

# Composant générique d'interaction (Phase 5.3).
#
# Convention réseau : ce noeud ne modifie JAMAIS d'état de jeu lui-même.
# Il ne fait que détecter que LE JOUEUR LOCAL est dans la zone et que ce
# joueur a appuyé sur "interact", puis émet un signal. C'est au script qui
# écoute ce signal (ex : station d'alchimie, atelier d'arme) de respecter
# le modèle d'autorité (RPC vers l'hôte, cf. architecture_reseau.md) —
# Interactable ne fait aucune hypothèse sur ce que "interagir" signifie.
#
# Détection multijoueur : body_entered/exited se déclenchent chez TOUS les
# pairs dès qu'un Player (local ou distant) entre dans la zone (réplication
# de position via MultiplayerSynchronizer). On ne doit afficher le prompt et
# écouter l'input QUE pour le joueur dont ce client a l'autorité, sinon
# chaque client afficherait un prompt pour n'importe quel joueur distant
# passant dans la zone.

signal interacted(player: Node2D)

@export var prompt_text: String = "Appuyer sur E"

@onready var prompt_label: Label = $PromptLabel

var _local_player_inside: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.text = prompt_text
		prompt_label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	if not body.is_multiplayer_authority():
		return # joueur distant : ce client n'affiche pas de prompt pour lui
	_local_player_inside = body
	if prompt_label:
		prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _local_player_inside:
		return
	_local_player_inside = null
	if prompt_label:
		prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _local_player_inside == null:
		return
	if event.is_action_pressed("interact"):
		interacted.emit(_local_player_inside)
