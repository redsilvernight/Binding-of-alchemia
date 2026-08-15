class_name Room
extends Node2D

# Salle de donjon générique (Phase 6.1/6.2, tileset et portes en Phase 10).
# Un template déclare ses 4 côtés (North/South/East/West), chacun pré-câblé
# dans la scène avec un node "Closed" (mur plein, StaticBody2D) et un node
# "Door" (sprite + collision propre, cf. door.gd) -- "Open" ne sert plus
# qu'à rester compatible avec d'anciens templates non encore équipés d'une
# porte. Le générateur (DungeonGenerator, appelé depuis game.gd côté hôte)
# décide quels côtés sont réellement connectés à une salle voisine et
# appelle set_open_sides() en conséquence — le template lui-même ne sait
# rien de sa position dans le donjon.
#
# Un côté structurellement fermé (pas de voisin) garde son mur "Closed"
# activé en permanence -- pas de porte là, cf. _paint_walls(). Un côté
# ouvert n'a JAMAIS de mur fixe actif : c'est la porte qui bloque le
# passage pendant un combat (verrouillage, 6.2), via sa propre collision
# togglée dans door.gd.set_state(). Les tuiles de mur/sol (_paint_walls())
# reflètent uniquement cette connectivité structurelle, jamais l'état de
# verrouillage -- avoir DEUX systèmes qui se ferment en même temps (mur en
# tuiles + porte) créait un mur visuellement bloqué en travers de la porte
# une fois le combat commencé.
#
# Verrouillage (6.2) : un côté structurellement ouvert peut être
# temporairement bloqué tant que la salle contient des ennemis enregistrés
# via register_enemy(). Seul l'hôte décide de verrouiller/déverrouiller
# (déclenché par l'entrée d'un joueur dans RoomTrigger, ou par la mort du
# dernier ennemi enregistré), et réplique la décision via _rpc_set_locked à
# tous les pairs — même pattern que Weapon._rpc_equip (cf.
# architecture_reseau.md).
#
# EnemyBoundaries : 4 murs pleins permanents (layer 16, exclusif aux
# ennemis, jamais togglés) superposés à chaque côté, en plus du système
# Closed/Open ci-dessus. Sans eux, un ennemi qui vise le joueur le plus
# proche traverse sa propre porte dès qu'elle est ouverte pour quelqu'un
# d'autre (le lock ne se déclenche qu'à l'entrée d'un joueur DANS cette
# salle précise) — les ennemis ne doivent jamais quitter leur salle.

signal room_cleared
## Émis uniquement côté hôte (cf. garde is_server() plus bas) quand un joueur
## entre dans cette salle — utilisé par game.gd pour la mini-map (Phase 6.4)
## et pour téléporter le reste du groupe (Phase 8.1, façon Binding of Isaac),
## indépendamment du verrouillage de porte.
signal player_entered(player: Node2D)

const SIDES: Array[String] = ["north", "south", "east", "west"]
const SIDE_OFFSETS: Dictionary = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}
const OPPOSITE_SIDE: Dictionary = {
	"north": "south",
	"south": "north",
	"east": "west",
	"west": "east",
}

const TILE_FLOOR: Vector2i = Vector2i(2, 1)
## Index = coin_NW*8 + coin_NE*4 + coin_SW*2 + coin_SE*1 (1 = mur, 0 = sol),
## valeur = coordonnée atlas dans dungeon_stone_terrain.tres. Généré depuis
## les métadonnées PixelLab (assets/tiles/dungeon_stone_metadata.json) —
## set_cell() direct plutôt que le système de terrain de Godot, cf. bug du
## sol (terrains_peering_bit non fiable sans pouvoir tester dans l'éditeur).
const WANG_ATLAS_BY_CORNERS: Dictionary = {
	0: Vector2i(2, 1),
	1: Vector2i(3, 1),
	2: Vector2i(2, 2),
	3: Vector2i(1, 2),
	4: Vector2i(2, 0),
	5: Vector2i(3, 2),
	6: Vector2i(0, 1),
	7: Vector2i(3, 3),
	8: Vector2i(1, 1),
	9: Vector2i(2, 3),
	10: Vector2i(1, 0),
	11: Vector2i(0, 2),
	12: Vector2i(3, 0),
	13: Vector2i(0, 0),
	14: Vector2i(1, 3),
	15: Vector2i(0, 3),
}
## Largeur/hauteur de chaque porte, en tuiles — doit rester un diviseur commun
## qui centre proprement dans _cols/_rows (cf. _paint_walls()). Salles à
## 15x21 tuiles : (15-5)/2=5 et (21-5)/2=8, donc tout tombe rond.
const DOOR_TILES: int = 5
## Tuiles "bord plein" (WANG_ATLAS_BY_CORNERS), utilisées pour forcer un pan
## de mur droit aux deux cases qui encadrent une embrasure -- cf.
## _flatten_door_frame().
const NORTH_EDGE_INDEX: int = 12
const SOUTH_EDGE_INDEX: int = 3
const WEST_EDGE_INDEX: int = 10
const EAST_EDGE_INDEX: int = 5

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
@onready var _floor: TileMapLayer = get_node_or_null("Floor")
## get_node_or_null (pas $North/Door) : templates pas encore équipés du sprite
## de porte (cf. door.gd) -- no-op silencieux dans _apply_walls() le temps de
## les ajouter à toutes les salles.
@onready var _door_by_side: Dictionary = {
	"north": get_node_or_null("North/Door"),
	"south": get_node_or_null("South/Door"),
	"east": get_node_or_null("East/Door"),
	"west": get_node_or_null("West/Door"),
}

## Position dans la grille du donjon (cf. game.gd::_spawn_room) -- assignée
## de façon synchrone avant l'entrée dans l'arbre, sert à retrouver les
## salles voisines par comparaison directe (cf. _find_neighbor_room()) pour
## partager l'état visuel d'une porte entre les deux salles qu'elle relie
## (Phase 10.x : une seule porte par intersection, cf. _sync_shared_door()).
var grid_position: Vector2i = Vector2i.ZERO
var _open_sides: Array = []
var _locked: bool = false
var _alive_enemies: Array[Node] = []
var _enemies_activation_scheduled: bool = false
var _cols: int = 0
var _rows: int = 0


func _ready() -> void:
	_trigger.body_entered.connect(_on_trigger_body_entered)
	_paint_floor()


## Templates sans node "Floor" (pas encore passés au tileset) : no-op silencieux.
## La taille du sol est dérivée des shapes de collision Nord/Ouest plutôt que
## codée en dur, pour rester correcte si un template change de dimensions.
## Les salles (960x1344) sont un multiple exact de la tuile (64px) --
## dimensionnées ainsi précisément pour que les embrasures de porte tombent
## sur des limites de tuile (cf. DOOR_TILES/_paint_walls()).
func _paint_floor() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	var width: float = (_closed_by_side["north"].get_node("CollisionShape2D").shape as RectangleShape2D).size.x
	var height: float = (_closed_by_side["west"].get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	var tile_size: Vector2i = _floor.tile_set.tile_size
	_cols = ceili(width / tile_size.x)
	_rows = ceili(height / tile_size.y)
	_floor.position = Vector2.ZERO
	for x in range(_cols):
		for y in range(_rows):
			_floor.set_cell(Vector2i(x, y), 0, TILE_FLOOR)


## Peint la bordure de murs, avec embrasure de porte sur les côtés
## structurellement connectés à une salle voisine. Modèle "grille de
## sommets" façon Wang tileset : un sommet (vx, vy) est mur sauf sur le
## pourtour extérieur ET dans l'embrasure d'un côté connecté -- chaque
## cellule prend la tuile correspondant à ses 4 coins (cf.
## WANG_ATLAS_BY_CORNERS). Appelée une seule fois (cf. set_open_sides()) :
## contrairement au verrouillage (_apply_walls(), qui rejoue à chaque combat),
## la connectivité structurelle ne change jamais après la génération du
## donjon -- l'embrasure reste visuellement ouverte en permanence, c'est la
## porte (sprite + collision propre, cf. door.gd) qui se ferme pendant un
## combat, pas ce mur en tuiles.
func _paint_walls() -> void:
	if _floor == null or _floor.tile_set == null or _cols == 0:
		return
	var door_col_start: int = (_cols - DOOR_TILES) / 2
	var door_col_end: int = door_col_start + DOOR_TILES
	var door_row_start: int = (_rows - DOOR_TILES) / 2
	var door_row_end: int = door_row_start + DOOR_TILES
	var open_north: bool = "north" in _open_sides
	var open_south: bool = "south" in _open_sides
	var open_west: bool = "west" in _open_sides
	var open_east: bool = "east" in _open_sides

	var is_wall_vertex: Callable = func(vx: int, vy: int) -> bool:
		if vy == 0 and open_north and vx >= door_col_start and vx <= door_col_end:
			return false
		if vy == _rows and open_south and vx >= door_col_start and vx <= door_col_end:
			return false
		if vx == 0 and open_west and vy >= door_row_start and vy <= door_row_end:
			return false
		if vx == _cols and open_east and vy >= door_row_start and vy <= door_row_end:
			return false
		return vx == 0 or vx == _cols or vy == 0 or vy == _rows

	for x in range(_cols):
		for y in range(_rows):
			var nw: bool = is_wall_vertex.call(x, y)
			var ne: bool = is_wall_vertex.call(x + 1, y)
			var sw: bool = is_wall_vertex.call(x, y + 1)
			var se: bool = is_wall_vertex.call(x + 1, y + 1)
			if not (nw or ne or sw or se):
				continue
			var corner_index: int = int(nw) * 8 + int(ne) * 4 + int(sw) * 2 + int(se)
			corner_index = _flatten_door_frame(x, y, corner_index, open_north, open_south, open_west, open_east, door_col_start, door_col_end, door_row_start, door_row_end)
			_floor.set_cell(Vector2i(x, y), 0, WANG_ATLAS_BY_CORNERS[corner_index])


## Les deux cases juste avant/après une embrasure (door_col_start-1 et
## door_col_end pour un côté horizontal, équivalent en lignes pour un côté
## vertical) n'ont qu'un seul sommet "mur" côté salle -- le modèle de coins
## Wang y calcule donc un angle diagonal isolé (cf. WANG_ATLAS_BY_CORNERS)
## au lieu d'un pan de mur droit jusqu'à l'embrasure. On force ici la tuile
## de bord plein correspondante sur ces deux cases précises seulement, sans
## toucher aux véritables coins extérieurs de la salle.
func _flatten_door_frame(x: int, y: int, corner_index: int, open_north: bool, open_south: bool, open_west: bool, open_east: bool, door_col_start: int, door_col_end: int, door_row_start: int, door_row_end: int) -> int:
	if open_north and y == 0 and (x == door_col_start - 1 or x == door_col_end):
		return NORTH_EDGE_INDEX
	if open_south and y == _rows - 1 and (x == door_col_start - 1 or x == door_col_end):
		return SOUTH_EDGE_INDEX
	if open_west and x == 0 and (y == door_row_start - 1 or y == door_row_end):
		return WEST_EDGE_INDEX
	if open_east and x == _cols - 1 and (y == door_row_start - 1 or y == door_row_end):
		return EAST_EDGE_INDEX
	return corner_index


func set_open_sides(open_sides: Array) -> void:
	_open_sides = open_sides
	_paint_walls()
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
	player_entered.emit(body)
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
		if structurally_open:
			# Plus aucun mur fixe à opposer ici : la porte (sa propre
			# collision, cf. door.gd) bloque seule le passage pendant un
			# verrouillage -- cf. _paint_walls() pour le pourquoi.
			_set_body_disabled(_closed_by_side[side], true)
			_set_body_disabled(_open_by_side[side], true)
		else:
			_set_body_disabled(_closed_by_side[side], false)
			_set_body_disabled(_open_by_side[side], true)
		# Pas de porte à afficher là où la salle n'a structurellement aucune
		# voisine (le mur y est plein en permanence, cf. _paint_walls()).
		var door: Door = _door_by_side[side]
		if door != null:
			door.visible = structurally_open
			if structurally_open:
				_sync_shared_door(side)


## Une intersection = une seule porte à l'écran (Phase 10.x), mais chaque
## salle garde son propre verrouillage (cf. _locked, register_enemy()) --
## chacune des deux salles possède donc toujours sa propre instance de porte
## (superposées pile sur la frontière commune, cf. templates), pilotées avec
## la MÊME valeur combinée pour rester visuellement indissociables d'une
## porte unique : fermée dès que l'une ou l'autre salle a des ennemis actifs.
func _sync_shared_door(side: String) -> void:
	var neighbor: Room = _find_neighbor_room(side)
	var combined_locked: bool = _locked or (neighbor != null and neighbor.is_locked())
	var effectively_open: bool = not combined_locked
	(_door_by_side[side] as Door).set_state(effectively_open)
	if neighbor == null:
		return
	var neighbor_door: Door = neighbor.get_door(OPPOSITE_SIDE[side])
	if neighbor_door != null:
		neighbor_door.set_state(effectively_open)


## Résolution par comparaison directe de grid_position plutôt que par nom de
## nœud : le nommage des salles instanciées par le MultiplayerSpawner (cf.
## game.gd::room_spawner) n'est pas dérivé de la position dans la grille.
## Peut renvoyer null si la salle voisine n'est pas encore entrée dans
## l'arbre chez ce pair (spawns répliqués reçus dans un ordre différent) --
## sans conséquence : le seul appelant (_sync_shared_door) tourne à nouveau
## dès que la salle voisine applique elle-même son propre set_open_sides()/
## _rpc_set_locked(), qui retrouvera alors cette salle-ci sans problème.
func _find_neighbor_room(side: String) -> Room:
	var neighbor_cell: Vector2i = grid_position + SIDE_OFFSETS[side]
	for sibling in get_parent().get_children():
		if sibling != self and sibling is Room and (sibling as Room).grid_position == neighbor_cell:
			return sibling
	return null


func is_locked() -> bool:
	return _locked


func get_door(side: String) -> Door:
	return _door_by_side.get(side)


func _set_body_disabled(body: StaticBody2D, disabled: bool) -> void:
	# set_deferred (pas une affectation directe) : _apply_walls() peut être
	# appelée depuis _rpc_set_locked() elle-même déclenchée par
	# RoomTrigger.body_entered, donc en pleine requête physique — modifier
	# CollisionShape2D.disabled à ce moment précis lève "flushing queries".
	for child in body.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)
