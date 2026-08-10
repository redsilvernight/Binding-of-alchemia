class_name Room
extends Node2D

# Salle de donjon générique (Phase 6.1/6.2). Un template déclare ses 4 côtés
# (North/South/East/West), chacun pré-câblé dans la scène avec deux
# configurations de collision : "Closed" (mur plein) et "Open" (mur avec
# une ouverture de porte). Le générateur (DungeonGenerator, appelé depuis
# game.gd côté hôte) décide quels côtés sont réellement connectés à une
# salle voisine et appelle set_open_sides() en conséquence — le template
# lui-même ne sait rien de sa position dans le donjon.
#
# Verrouillage (6.2) : un côté structurellement ouvert peut être
# temporairement reverrouillé (mur "Closed" réappliqué par-dessus) tant que
# la salle contient des ennemis enregistrés via register_enemy(). Seul
# l'hôte décide de verrouiller/déverrouiller (déclenché par l'entrée d'un
# joueur dans RoomTrigger, ou par la mort du dernier ennemi enregistré),
# et réplique la décision via _rpc_set_locked à tous les pairs — même
# pattern que Weapon._rpc_equip (cf. architecture_reseau.md).
#
# EnemyBoundaries : 4 murs pleins permanents (layer 16, exclusif aux
# ennemis, jamais togglés) superposés à chaque côté, en plus du système
# Closed/Open ci-dessus. Sans eux, un ennemi qui vise le joueur le plus
# proche traverse sa propre porte dès qu'elle est ouverte pour quelqu'un
# d'autre (le lock ne se déclenche qu'à l'entrée d'un joueur DANS cette
# salle précise) — les ennemis ne doivent jamais quitter leur salle.

signal room_cleared
## Émis uniquement côté hôte (cf. garde is_server() plus bas) quand un joueur
## entre dans cette salle — utilisé par game.gd pour la mini-map (Phase 6.4),
## indépendamment du verrouillage de porte.
signal player_entered

const SIDES: Array[String] = ["north", "south", "east", "west"]

@onready var _closed_by_side: Dictionary = {
	"north": $North/Closed,
	"south": $South/Closed,
	"east": $East/Closed,
	"west": $West/Closed,
}
@onready var _open_by_side: Dictionary = {
	"north": $North/Open,
	"south": $South/Open,
	"east": $East/Open,
	"west": $West/Open,
}
@onready var _trigger: Area2D = $RoomTrigger

var _open_sides: Array = []
var _locked: bool = false
var _alive_enemies: Array[Node] = []
var _enemies_activation_scheduled: bool = false


func _ready() -> void:
	_trigger.body_entered.connect(_on_trigger_body_entered)


func set_open_sides(open_sides: Array) -> void:
	_open_sides = open_sides
	_apply_walls()


## À appeler côté hôte uniquement, juste après avoir spawné un ennemi
## destiné à cette salle (cf. game.gd). Reste sans effet sur les autres
## pairs si appelé partout : seule la décision de (dé)verrouiller, prise
## plus bas, est gardée par multiplayer.is_server().
func register_enemy(enemy: Node) -> void:
	_alive_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_registered_enemy_removed.bind(enemy))


func _on_registered_enemy_removed(enemy: Node) -> void:
	_alive_enemies.erase(enemy)
	if not multiplayer.is_server():
		return
	if _locked and _alive_enemies.is_empty():
		_rpc_set_locked.rpc(false)


func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return
	if not multiplayer.is_server():
		return
	player_entered.emit()
	_activate_enemies_delayed()
	if _locked or _alive_enemies.is_empty():
		return
	_rpc_set_locked.rpc(true)


## Un ennemi ne cible/bouge qu'après ce délai suivant l'entrée d'un joueur
## dans SA salle — sinon il vise le joueur le plus proche dès le début de
## la partie, quelle que soit la salle, et se retrouve collé à sa porte
## (bloquée par EnemyBoundaries) à l'attendre avant même qu'il entre.
func _activate_enemies_delayed() -> void:
	if _enemies_activation_scheduled or _alive_enemies.is_empty():
		return
	_enemies_activation_scheduled = true
	await get_tree().create_timer(1.0).timeout
	for enemy in _alive_enemies:
		if is_instance_valid(enemy):
			enemy.active = true


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_locked(locked: bool) -> void:
	_locked = locked
	_apply_walls()
	if not locked:
		room_cleared.emit()


func _apply_walls() -> void:
	for side in SIDES:
		var structurally_open: bool = side in _open_sides
		var effectively_open: bool = structurally_open and not _locked
		_set_body_disabled(_closed_by_side[side], effectively_open)
		_set_body_disabled(_open_by_side[side], not effectively_open)


func _set_body_disabled(body: StaticBody2D, disabled: bool) -> void:
	# set_deferred (pas une affectation directe) : _apply_walls() peut être
	# appelée depuis _rpc_set_locked() elle-même déclenchée par
	# RoomTrigger.body_entered, donc en pleine requête physique — modifier
	# CollisionShape2D.disabled à ce moment précis lève "flushing queries".
	for child in body.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)
