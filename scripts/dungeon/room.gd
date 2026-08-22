class_name Room
extends Node2D

# Salle de donjon générique (Phase 6.1/6.2, tileset et portes en Phase 10,
# collision 100% tuiles en Phase 10.x). Un template déclare ses 4 côtés
# (North/South/East/West), chacun pré-câblé avec un node "Door" (habillage
# visuel uniquement, cf. door.gd) -- il n'y a plus aucun StaticBody2D de mur
# dans les templates : toute la collision de mur/porte vient du TileMapLayer
# "Floor" et du physics layer défini sur les tuiles de mur dans
# dungeon_stone_terrain.tres. Le générateur (DungeonGenerator, appelé depuis
# game.gd côté hôte) décide quels côtés sont réellement connectés à une
# salle voisine et appelle set_open_sides() en conséquence — le template
# lui-même ne sait rien de sa position dans le donjon.
#
# Un côté structurellement fermé (pas de voisin) reste peint en tuiles de mur
# sur toute sa largeur -- pas d'embrasure là, cf. _paint_walls(). Un côté
# structurellement ouvert a une embrasure de DOOR_TILES tuiles : ces tuiles-là
# basculent entre "sol" (déverrouillé) et "mur" (verrouillé pendant un combat)
# via _set_door_gap_tiles(), appelée depuis _sync_shared_door(). La porte
# (sprite Closed/Open, cf. door.gd) n'est plus qu'un habillage visuel
# superposé à cette tuile, synchronisé mais sans collision propre -- avoir
# DEUX systèmes de collision qui se ferment en même temps (mur en tuiles +
# StaticBody2D de porte) était la source d'un bug où la collision de la
# porte ne bloquait pas de façon fiable le passage.
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
# ennemis, StaticBody2D jamais togglés, indépendants du système de tuiles
# ci-dessus) superposés à chaque côté. Sans eux, un ennemi qui vise le joueur
# le plus proche traverse sa propre porte dès qu'elle est ouverte pour
# quelqu'un d'autre (le lock ne se déclenche qu'à l'entrée d'un joueur DANS
# cette salle précise) — les ennemis ne doivent jamais quitter leur salle.

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
## Dimensions fixes de tous les templates de salle, en pixels -- remplace
## l'ancienne lecture dynamique de la taille du mur "Closed" (supprimé,
## cf. header) maintenant que plus aucun node de la scène ne porte cette
## information. Multiple exact de la tuile (64px), cf. _paint_floor().
## Format horizontal (Phase 10.x rework) : plus large que haute, pour
## correspondre à un viewport 16:9 et éviter que la caméra (sans limit_*,
## cf. player.gd) ne cadre du vide hors-tuiles sur les côtés d'une salle
## trop étroite.
const ROOM_WIDTH_PX: int = 1344
const ROOM_HEIGHT_PX: int = 960
## Largeur/hauteur de chaque porte, en tuiles — doit rester un diviseur commun
## qui centre proprement dans _cols/_rows (cf. _paint_walls()). Salles à
## 21x15 tuiles : (21-5)/2=8 et (15-5)/2=5, donc tout tombe rond.
const DOOR_TILES: int = 5
## Taille de tuile de dungeon_stone_terrain.tres (déjà supposée fixe par le
## calcul en dur dans le commentaire de DOOR_TILES ci-dessus) -- exposée en
## constante publique pour que game.gd puisse calculer des zones d'exclusion
## de porte (Phase 11.2, placement des props) sans attendre l'entrée en arbre
## de cette Room (_cols/_rows ne sont connus qu'après _paint_floor()).
const TILE_SIZE_PX: float = 64.0
## Tuiles "bord plein" (WANG_ATLAS_BY_CORNERS), utilisées pour forcer un pan
## de mur droit aux deux cases qui encadrent une embrasure -- cf.
## _flatten_door_frame().
const NORTH_EDGE_INDEX: int = 12
const SOUTH_EDGE_INDEX: int = 3
const WEST_EDGE_INDEX: int = 10
const EAST_EDGE_INDEX: int = 5

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
var _nav_region: NavigationRegion2D
## Props purement décoratifs (pas de collision, cf. game.gd::_prepare_room_props) :
## peints comme des tuiles dans ce layer plutôt qu'instanciés en scène +
## MultiplayerSpawner un par un -- un brin de mousse n'a aucun comportement à
## exécuter, un TileMapLayer est fait pour ça (retour utilisateur : le
## précédent système coûtait un load()+instantiate()+spawn réseau par prop
## décoratif, ce qui alourdissait le temps de chargement pour rien).
var _props_decor: TileMapLayer
## Renseignées par set_decor_props() avant l'entrée dans l'arbre, peintes dès
## que _props_decor existe (cf. _setup_props_decor_layer()) -- Array simple
## plutôt que Array[Vector2i]/Array[int], même choix que _open_sides : ces
## valeurs traversent room_data (cf. game.gd::_spawn_room), donc le
## mécanisme de réplication du RoomSpawner plutôt qu'un typage strict.
var _pending_decor_cells: Array = []
var _pending_decor_source_ids: Array = []
## Props bloquants sans script (caisses, piliers, gravats...) migrés en
## tuiles avec collision peinte sur physics_layer_0 (cf.
## resources/tilesets/dungeon_*_terrain.tres) -- même raisonnement que
## _props_decor, mais AVEC collision cette fois : plus besoin d'un
## StaticBody2D+NavigationObstacle2D par instance, le physics layer du
## TileSet et le bake de _nav_region (cf. _setup_navigation()) suffisent.
var _props_blocking: TileMapLayer
var _pending_blocking_cells: Array = []
var _pending_blocking_source_ids: Array = []
## Cellules des tuiles de torche murale peintes par set_decor_props() (cf.
## game.gd::_prepare_room_props(), WALL_LIGHT_COUNT) -- tableau vide = aucune.
## Séparé de _pending_decor_cells : ces cellules servent deux fois (peinture
## de la tuile ET position de chaque WallLight), donc gardées à part plutôt
## que retrouvées en refouillant _pending_decor_cells/_pending_decor_source_ids.
## Array simple plutôt que Array[Vector2i], même raisonnement que
## _pending_decor_cells juste au-dessus : ces valeurs traversent room_data,
## donc le mécanisme de réplication du RoomSpawner plutôt qu'un typage strict.
var _pending_wall_light_cells: Array = []
var _pending_wall_light_color: Color = Color.WHITE


func _ready() -> void:
	# Retour utilisateur : "une sorte de y-sort sur les props plutôt qu'une
	# collision" -- active le tri par profondeur (Y) pour TOUS les enfants
	# directs de cette salle (donc aussi Hub, qui hérite de Room). Ne suffit
	# PAS à lui seul : ne s'applique qu'aux enfants dont le chemin complet
	# jusqu'ici a lui aussi y_sort_enabled=true (propagation Godot native) --
	# cf. _setup_props_blocking_layer() pour PropsBlocking, et Game/Rooms/
	# Players dans game.tscn/hub.tscn pour le reste de la chaîne côté joueur.
	y_sort_enabled = true
	_trigger.body_entered.connect(_on_trigger_body_entered)
	_paint_floor()
	_setup_props_decor_layer()
	_setup_props_blocking_layer()
	_setup_navigation()
	_setup_wall_light()


## Permet à game.gd d'assigner un tileset différent selon la pool thématique
## de l'étage (Phase 11.4, un tileset dédié par pool de props) -- DOIT être
## appelée AVANT que cette salle rejoigne l'arbre (donc avant _ready()),
## contrairement à set_open_sides()/_setup_navigation() qui dépendent des
## @onready et tournent après coup : _paint_floor() (dans _ready()) lit déjà
## _floor.tile_set pour peindre, donc le tileset doit être en place avant. Un
## get_node() direct plutôt que le _floor @onready, qui n'est pas encore
## assigné à ce stade.
func set_floor_tileset(tile_set: TileSet) -> void:
	(get_node("Floor") as TileMapLayer).tile_set = tile_set


## Pathfinding : un NavigationPolygon baké par salle (PARSED_GEOMETRY_
## STATIC_COLLIDERS) plutôt que le rectangle fixe d'avant -- ce rectangle
## ignorait délibérément les props bloquants (cf. commentaire disparu : "ceux-
## ci utilisent l'évitement dynamique NavigationObstacle2D + RVO plutôt qu'un
## re-bake par salle"), qui étaient alors chacun sa propre scène avec son
## propre NavigationObstacle2D. Depuis leur migration en tuiles (cf.
## _setup_props_blocking_layer()), ce node d'évitement dynamique n'existe
## plus par prop -- seul un vrai bake fait apparaître les trous correspondants
## dans le maillage de navigation.
## SOURCE_GEOMETRY_ROOT_NODE_CHILDREN ne scanne QUE les enfants DIRECTS de
## _nav_region lui-même (pas de Room) -- Floor/PropsDecor/PropsBlocking sont
## définis comme enfants de la salle (template ou _setup_props_*_layer() plus
## haut), donc migrés ici sous _nav_region pour être vus par le parseur. Le
## repositionnement ne change rien visuellement : _nav_region est ajouté à
## Room avec position par défaut (0,0), donc la position locale de chaque
## layer (déjà (0,0) pour Floor, cf. _paint_floor()) reste équivalente en
## position globale.
## Pas de bake ici (juste la config) : les tuiles de mur ne sont peintes
## qu'après, via _paint_walls() (appelée depuis set_open_sides(), en
## call_deferred par game.gd::_spawn_room une fois la salle entrée dans
## l'arbre) -- baker maintenant ne verrait qu'un Floor tout en sol, sans mur.
## cf. _bake_navigation(), appelée depuis set_open_sides() une fois les murs
## (et les props bloquants, déjà peints avant _ready()) en place.
## EnemyBoundaries (StaticBody2D layer 16, cf. header du fichier) n'est PAS
## inclus ici : il bloque en permanence les 4 côtés même à une porte ouverte
## (spécifique aux ennemis, qui ne doivent jamais quitter leur salle) --
## l'inclure ferait disparaître toute embrasure de porte du maillage.
func _setup_navigation() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	_nav_region = NavigationRegion2D.new()
	# Sans ça, la chaîne y_sort_enabled=true (Room, cf. _ready() plus haut) --
	# PropsBlocking (cf. plus bas) se retrouve coupée par ce maillon
	# intermédiaire resté à false par défaut : Godot ne compare alors plus
	# JAMAIS la position Y du joueur/des ennemis contre celle des props
	# bloquants qu'il contient, quelle que soit la valeur de y_sort_origin
	# posée sur leurs tuiles -- bug constaté en jeu (retour utilisateur : le
	# joueur passe toujours devant un prop bloquant, même en se tenant
	# derrière), le rendu retombant alors sur le simple ordre du tree.
	_nav_region.y_sort_enabled = true
	add_child(_nav_region)
	# move_child(0) : add_child() ajoute _nav_region en DERNIER enfant de Room,
	# alors que Floor était le TOUT PREMIER enfant dans les templates (cf.
	# room_template_a.tscn) -- même z_index (0) partout ici, donc l'ordre du
	# tree fait foi pour le dessin, dernier = par-dessus. Sans ce move_child,
	# Floor/PropsDecor/PropsBlocking (déplacés sous _nav_region juste en
	# dessous) se retrouvent dessinés PAR-DESSUS Chest/AlchemyStation/
	# WeaponStation (définis après Floor dans les templates, donc censés
	# rester visuellement au-dessus) -- bug constaté en jeu (meubles invisibles,
	# masqués sous la tilemap) après l'introduction de ce reparentage.
	move_child(_nav_region, 0)
	for layer in [_floor, _props_decor, _props_blocking]:
		if layer != null:
			remove_child(layer)
			_nav_region.add_child(layer)
	var nav_poly := NavigationPolygon.new()
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# Marge au-delà du rayon RVO des ennemis (cf. EnemyBase.nav_agent.radius =
	# 28px, scripts/enemies/enemy_base.gd) : sans marge, le bake érode le
	# maillage jusqu'au bord EXACT des tuiles bloquantes, donc le chemin peut
	# longer un pilier à distance zéro. Un agent_radius pile égal à 28px
	# (première tentative, cf. historique du fichier) réduisait déjà beaucoup
	# les blocages mais en laissait aux angles des props (constaté en jeu) :
	# la vélocité RVO réelle suit le chemin de façon approximative, pas au
	# pixel près, donc un chemin à distance zéro de la collision suffit à
	# accrocher le corps de l'ennemi dans un virage serré. +6px de coussin
	# (34px au total) absorbe cet écart sans trop mordre sur les passages
	# étroits (embrasure de porte = DOOR_TILES*TILE_SIZE_PX = 320px de large,
	# largement au-dessus de 2*34). Les anciens NavigationObstacle2D par prop
	# (42-50px de rayon, supprimés avec la scène de chaque prop) donnaient une
	# marge encore plus large ; à réévaluer en playtest si des blocages
	# persistent ou si des passages deviennent trop étroits.
	nav_poly.agent_radius = 34.0
	nav_poly.add_outline(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(ROOM_WIDTH_PX, 0.0),
		Vector2(ROOM_WIDTH_PX, ROOM_HEIGHT_PX),
		Vector2(0.0, ROOM_HEIGHT_PX),
	]))
	_nav_region.navigation_polygon = nav_poly


## Appelée depuis set_open_sides(), une fois _paint_walls() (murs) passée --
## les props bloquants sont déjà peints à ce stade (cf. _ready(), qui tourne
## avant : _setup_props_blocking_layer() précède _setup_navigation()). true
## = bake sur un thread à part (cf. NavigationRegion2D.bake_navigation_polygon) :
## asynchrone, le maillage à jour arrive dans les frames suivantes plutôt que
## bloquer -- sans conséquence ici, la navigation n'est pas répliquée
## réseau, chaque pair la calcule localement à partir des mêmes données de
## salle (cf. set_decor_props()/set_blocking_props() pour le même
## raisonnement sur la réplication).
## update_internals() AVANT le bake : set_cell() (peinture des murs et des
## props bloquants) ne crée pas les shapes de collision immédiatement --
## Godot les construit en différé, à la prochaine mise à jour interne du
## TileMapLayer. Le parseur PARSED_GEOMETRY_STATIC_COLLIDERS/
## SOURCE_GEOMETRY_ROOT_NODE_CHILDREN lit l'état RÉEL des corps physiques au
## moment de l'appel -- sans ce update_internals(), le bake tournait donc
## sur des tuiles fraîchement peintes mais encore sans collision créée côté
## PhysicsServer, d'où des trous manquants dans le maillage et des ennemis
## qui pathaient tout droit dans un prop bloquant (bug constaté en jeu).
func _bake_navigation() -> void:
	if _nav_region == null:
		return
	_floor.update_internals()
	if _props_blocking != null:
		_props_blocking.update_internals()
	_nav_region.bake_navigation_polygon(true)


## Permet à game.gd de fournir les tuiles de décor choisies pour cette salle
## (cf. game.gd::_prepare_room_props) -- même contrainte de timing que
## set_floor_tileset() : DOIT être appelée avant l'entrée dans l'arbre, ces
## valeurs sont peintes dès _setup_props_decor_layer() (_ready()). Portées
## par room_data (cf. RoomSpawner), donc répliquées nativement avec le reste
## du spawn de la salle -- contrairement à un RPC séparé et one-shot, un pair
## qui rejoint en cours de partie les reçoit automatiquement avec le spawn de
## la salle elle-même (cf. game.gd::_on_peer_connected pour le problème
## inverse déjà rencontré avec un RPC one-shot, sur la vie du boss).
func set_decor_props(cells: Array, source_ids: Array) -> void:
	_pending_decor_cells = cells
	_pending_decor_source_ids = source_ids


## Même contrat que set_decor_props() juste au-dessus (timing, réplication
## via room_data) mais pour les props bloquants (cf. _setup_props_blocking_layer()).
func set_blocking_props(cells: Array, source_ids: Array) -> void:
	_pending_blocking_cells = cells
	_pending_blocking_source_ids = source_ids


## Même contrat de timing que set_decor_props() -- cells doit contenir LES
## MÊMES cellules que les tuiles de torche murale déjà présentes dans
## decor_cells (cf. game.gd::_prepare_room_props()), pour que chaque
## WallLight tombe exactement sur sa tuile plutôt qu'à côté.
func set_wall_light(cells: Array, color: Color) -> void:
	_pending_wall_light_cells = cells
	_pending_wall_light_color = color


## Créé en code plutôt qu'un node dans chaque template (cf. header) : évite de
## toucher tous les .tscn de salle pour un layer qui n'existe que pour peindre
## des tuiles décoratives choisies par game.gd::_prepare_room_props. Réutilise
## le TileSet de Floor (déjà celui de la pool du thème courant, cf.
## set_floor_tileset()) -- les sources de props décoratifs y sont ajoutées à
## côté du terrain (cf. resources/tilesets/dungeon_*_terrain.tres). Ajouté
## APRÈS Floor dans l'arbre : à z_index égal (par défaut 0 pour les deux),
## l'ordre du tree suffit à dessiner les décors par-dessus le sol.
func _setup_props_decor_layer() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	_props_decor = TileMapLayer.new()
	_props_decor.name = "PropsDecor"
	_props_decor.tile_set = _floor.tile_set
	add_child(_props_decor)
	for i in _pending_decor_cells.size():
		_props_decor.set_cell(_pending_decor_cells[i], _pending_decor_source_ids[i], Vector2i.ZERO)


## Même principe que _setup_props_decor_layer() juste au-dessus, mais pour
## les props bloquants (cf. game.gd::_prepare_room_props) -- couche séparée
## de PropsDecor et de Floor plutôt que peints sur l'une d'elles : Floor est
## réécrit en bloc par _paint_walls()/_set_door_gap_tiles() (qui ignorent
## tout ce qui n'est pas mur/sol), et PropsDecor n'a pas de collision --
## mélanger l'un ou l'autre risquerait un prop bloquant écrasé par une
## repeinte de mur, ou une collision qui se retrouve sans le vouloir sur un
## layer sans intention de bloquer.
func _setup_props_blocking_layer() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	_props_blocking = TileMapLayer.new()
	_props_blocking.name = "PropsBlocking"
	_props_blocking.tile_set = _floor.tile_set
	# light_mask sur une valeur que PlayerLight n'éclaire pas (retour
	# utilisateur, éclairage 2D) : occlusion_layer_0/light_mask (qui décide si
	# CE layer bloque une lumière) est un masque à part de CanvasItem.light_mask
	# (qui décide si CE layer est lui-même éclairé) -- les deux valaient 1 par
	# défaut, donc un prop bloquant recevait sa PROPRE ombre sur son propre
	# socle (son polygone d'occlusion l'assombrissant lui-même), visible comme
	# un carré sombre incohérent avec sa silhouette réelle. En le sortant du
	# range_item_cull_mask par défaut (1) des lumières, le prop garde son
	# apparence normale tout en projetant toujours une ombre correcte sur ce
	# qu'il y a derrière (Floor, resté sur le masque 1).
	_props_blocking.light_mask = 2
	# Chaque tuile bloquante trie individuellement contre le joueur (cf.
	# y_sort_enabled sur Room ci-dessus) en utilisant son y_sort_origin
	# (retaillé sur le socle visuel réel de chaque sprite, pas le centre de
	# la tuile -- cf. resources/tilesets/dungeon_*_terrain.tres) : le joueur
	# peut désormais passer devant OU derrière un prop bloquant selon sa
	# position Y, au lieu d'être bloqué sur toute la hauteur du sprite.
	_props_blocking.y_sort_enabled = true
	add_child(_props_blocking)
	for i in _pending_blocking_cells.size():
		_props_blocking.set_cell(_pending_blocking_cells[i], _pending_blocking_source_ids[i], Vector2i.ZERO)


## WallLight (cf. scripts/props/wall_light.gd) : purement une PointLight2D,
## aucun sprite -- la tuile de torche/cristal/brasero elle-même est déjà
## peinte sur PropsDecor (cf. _setup_props_decor_layer(), _pending_wall_light_cells
## correspond toujours à un sous-ensemble de _pending_decor_cells, cf.
## game.gd::_prepare_room_props()). Une instance par cellule -- WALL_LIGHT_COUNT
## torches par salle (retour utilisateur), toutes de la même couleur de thème.
## Position au CENTRE de la cellule -- même formule que set_cell() (coin
## haut-gauche = cell * TILE_SIZE_PX), + une demi-tuile pour retomber au
## centre visuel de la tuile peinte. Construites et configurées localement
## sur CHAQUE pair (comme Floor/PropsDecor juste au-dessus) : purement
## visuel, pas d'état à répliquer en plus de _pending_wall_light_cells/
## _pending_wall_light_color, déjà portés par room_data comme le reste des
## données de spawn de la salle.
func _setup_wall_light() -> void:
	for cell in _pending_wall_light_cells:
		var light: WallLight = WallLight.new()
		light.set_color(_pending_wall_light_color)
		light.position = Vector2(cell) * TILE_SIZE_PX + Vector2.ONE * (TILE_SIZE_PX / 2.0)
		add_child(light)


## Templates sans node "Floor" (pas encore passés au tileset) : no-op silencieux.
func _paint_floor() -> void:
	if _floor == null or _floor.tile_set == null:
		return
	var tile_size: Vector2i = _floor.tile_set.tile_size
	_cols = ceili(float(ROOM_WIDTH_PX) / tile_size.x)
	_rows = ceili(float(ROOM_HEIGHT_PX) / tile_size.y)
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
## donjon -- l'embrasure de DOOR_TILES tuiles peinte ici reste "sol" tant
## qu'aucun combat n'est en cours ; _set_door_gap_tiles() la repeint en "mur"
## pendant un verrouillage, sans repasser par cette fonction.
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
	_bake_navigation()


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
	# process_always=false (retour utilisateur, menu pause) : sans lui ce
	# délai continue de décompter même arbre en pause, cf. bullet.gd::launch().
	await get_tree().create_timer(1.0, false).timeout
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
		# Pas de porte à afficher là où la salle n'a structurellement aucune
		# voisine (le mur y reste plein en permanence, peint une seule fois
		# par _paint_walls() -- rien à toggler ici pour ce côté).
		var door: Door = _door_by_side[side]
		if door != null:
			door.visible = structurally_open
		if structurally_open:
			_sync_shared_door(side)


## Une intersection = une seule porte à l'écran (Phase 10.x), mais chaque
## salle garde son propre verrouillage (cf. _locked, register_enemy()) --
## chacune des deux salles possède donc toujours sa propre instance de porte
## (superposées pile sur la frontière commune, cf. templates) ET sa propre
## embrasure de tuiles (superposée au même endroit dans le monde), pilotées
## avec la MÊME valeur combinée pour rester visuellement indissociables d'une
## porte unique : fermée dès que l'une ou l'autre salle a des ennemis actifs.
func _sync_shared_door(side: String) -> void:
	var neighbor: Room = _find_neighbor_room(side)
	var combined_locked: bool = _locked or (neighbor != null and neighbor.is_locked())
	var effectively_open: bool = not combined_locked
	(_door_by_side[side] as Door).set_state(effectively_open)
	_set_door_gap_tiles(side, combined_locked)
	if neighbor == null:
		return
	var neighbor_door: Door = neighbor.get_door(OPPOSITE_SIDE[side])
	if neighbor_door != null:
		neighbor_door.set_state(effectively_open)
	neighbor._set_door_gap_tiles(OPPOSITE_SIDE[side], combined_locked)


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


## Bascule la collision de l'embrasure d'un côté structurellement ouvert
## entre "mur" (verrouillé -- même tuile de bord plein que les cases
## encadrant l'embrasure, cf. _flatten_door_frame()) et "sol" (déverrouillé).
## Remplace l'ancien système de StaticBody2D Closed/Open + collision propre de
## la porte : la collision vient désormais uniquement des tuiles peintes ici
## et de leur physics layer (cf. dungeon_stone_terrain.tres) -- la porte
## (sprite, cf. door.gd) n'est plus qu'un habillage visuel superposé, sans
## collision à elle.
## call_deferred (pas set_cell direct) : appelée depuis _sync_shared_door(),
## elle-même appelable depuis _rpc_set_locked() déclenchée par
## RoomTrigger.body_entered, donc en pleine requête physique -- même piège
## que l'ancien _set_body_disabled() avec CollisionShape2D.disabled.
func _set_door_gap_tiles(side: String, locked: bool) -> void:
	if _floor == null or _floor.tile_set == null or _cols == 0:
		return
	var door_col_start: int = (_cols - DOOR_TILES) / 2
	var door_row_start: int = (_rows - DOOR_TILES) / 2
	for i in range(DOOR_TILES):
		var coords: Vector2i
		var atlas_coords: Vector2i
		match side:
			"north":
				coords = Vector2i(door_col_start + i, 0)
				atlas_coords = WANG_ATLAS_BY_CORNERS[NORTH_EDGE_INDEX] if locked else TILE_FLOOR
			"south":
				coords = Vector2i(door_col_start + i, _rows - 1)
				atlas_coords = WANG_ATLAS_BY_CORNERS[SOUTH_EDGE_INDEX] if locked else TILE_FLOOR
			"west":
				coords = Vector2i(0, door_row_start + i)
				atlas_coords = WANG_ATLAS_BY_CORNERS[WEST_EDGE_INDEX] if locked else TILE_FLOOR
			"east":
				coords = Vector2i(_cols - 1, door_row_start + i)
				atlas_coords = WANG_ATLAS_BY_CORNERS[EAST_EDGE_INDEX] if locked else TILE_FLOOR
			_:
				continue
		_floor.call_deferred("set_cell", coords, 0, atlas_coords)
