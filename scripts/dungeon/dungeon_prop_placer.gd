class_name DungeonPropPlacer
extends RefCounted

## Extrait de game.gd (File Size, cf. .claude/rules/gdscript.md) : placement
## procédural des props décoratifs/bloquants d'une salle, en tuiles peintes
## sur son TileSet thématique (cf. Room.set_decor_props()/set_blocking_props()).
## Pure géométrie/logique de tirage -- aucun accès RPC ni MultiplayerSpawner
## ici, c'est _generate_dungeon()/_prepare_room_props() dans game.gd qui reste
## seul responsable de l'orchestration réseau (hôte uniquement, avant le spawn
## de chaque salle). room_world_rect_fn/random_position_in_room_fn sont
## injectées depuis game.gd (Game._room_world_rect / Game._random_position_in_room)
## pour rester l'unique source de vérité de ces calculs, partagés avec le
## reste de game.gd (ennemis, coffre).

const PROP_DOOR_CLEARANCE: float = 160.0
const PROP_CENTER_CLEARANCE_RADIUS: float = 180.0
const PROP_PLACEMENT_ATTEMPTS: int = 20
const PROP_MIN_SPACING: float = 110.0
const ROOM_COLS: int = 21
const ROOM_ROWS: int = 15
const WALL_LIGHT_SIDES: Array[String] = ["north", "south"]
const WALL_LIGHT_TEXTURE_PATHS: Array[String] = [
	"res://assets/tiles/props/cristaux_lumineux.png",
	"res://assets/tiles/props/torche_murale.png",
	"res://assets/tiles/props/brasero_alchimique.png",
]

var _room_world_rect: Callable
var _random_position_in_room: Callable

func _init(room_world_rect_fn: Callable, random_position_in_room_fn: Callable) -> void:
	_room_world_rect = room_world_rect_fn
	_random_position_in_room = random_position_in_room_fn

## Table texture (res://assets/tiles/props/xxx.png, cf. item_path des entrées
## dans props_pool_*.tres) -> id de source d'atlas dans ce TileSet, scindée
## en deux selon que la tuile porte un polygone de collision sur
## physics_layer_0 (props bloquants, peints sur PropsBlocking) ou non (props
## décoratifs, peints sur PropsDecor) -- entièrement dérivé du TileSet
## lui-même (aucun id ni chemin en dur côté script, aucune liste à
## maintenir en parallèle des .tres) pour rester correct si les sources sont
## un jour réordonnées ou si un prop change de catégorie.
func prop_tile_sources_by_texture(tile_set: TileSet) -> Dictionary:
	var decor: Dictionary = {}
	var blocking: Dictionary = {}
	for i in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(i)
		var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
		if tile_data == null:
			continue
		if tile_data.get_collision_polygons_count(0) > 0:
			blocking[source.texture.resource_path] = source_id
		else:
			decor[source.texture.resource_path] = source_id
	return {"decor": decor, "blocking": blocking}

## Phase 11.2 : décors/obstacles procéduraux, un pool par étage
## (floor_level % 3, cf. PROP_SPAWN_TABLE_PATHS dans game.gd). Salle de départ
## et salle de boss exclues (position de spawn joueur/boss fixe au centre) --
## un prop y apparaissant dessus serait un vrai problème, contrairement aux
## salles normales où seule la position est aléatoire de toute façon.
## Tourne AVANT le spawn de room_data (cf. game.gd._generate_dungeon()), pas
## après : remplit room_data["decor_cells"]/["decor_source_ids"] et
## room_data["blocking_cells"]/["blocking_source_ids"] pour que ces tuiles
## voyagent avec le reste des données de spawn de la salle et soient
## répliquées nativement par le RoomSpawner (cf. Room.set_decor_props()/
## set_blocking_props()) -- contrairement à un RPC séparé tiré une fois, un
## pair qui rejoint en cours de partie les reçoit alors automatiquement avec
## le spawn de la salle. Seuls les props qui n'ont ni tuile décorative ni
## tuile bloquante enregistrée dans ce TileSet (cf. prop_tile_sources --
## aucun cas actuel, tous les props de ce projet -- y compris la torche
## murale, cf. WALL_LIGHT_TEXTURE_PATHS -- sont des tuiles) passent encore
## par prop_spawner (MultiplayerSpawner classique, déjà rattrapé nativement
## pour un rejoin tardif).
func prepare_room_props(room_data: Dictionary, prop_table: SpawnTable, prop_tile_sources: Dictionary, pool_index: int, prop_spawner: MultiplayerSpawner) -> void:
	var decor_cells: Array[Vector2i] = []
	var decor_source_ids: Array[int] = []
	var blocking_cells: Array[Vector2i] = []
	var blocking_source_ids: Array[int] = []
	# Tableau vide = pas de torche murale pour cette salle (start/boss, cf.
	# garde ci-dessous) -- lu par Room.set_wall_light() dans game.gd._spawn_room().
	var wall_light_cells: Array[Vector2i] = []
	if not (room_data["is_start"] or room_data["is_boss"]):
		var room_origin: Vector2 = (_room_world_rect.call(room_data) as Rect2).position
		var placed_positions: Array[Vector2] = []
		for prop_path in prop_table.pick_many():
			var prop_position: Vector2 = _random_prop_position_in_room(room_data, placed_positions)
			placed_positions.append(prop_position)
			var local_pos: Vector2 = prop_position - room_origin
			var cell: Vector2i = Vector2i(floori(local_pos.x / Room.TILE_SIZE_PX), floori(local_pos.y / Room.TILE_SIZE_PX))
			if prop_tile_sources["blocking"].has(prop_path):
				blocking_cells.append(cell)
				blocking_source_ids.append(prop_tile_sources["blocking"][prop_path])
			elif prop_tile_sources["decor"].has(prop_path):
				decor_cells.append(cell)
				decor_source_ids.append(prop_tile_sources["decor"][prop_path])
			else:
				prop_spawner.spawn({
					"scene_path": prop_path,
					"position": prop_position,
				})
		# Torche/cristal/brasero murale garantie sur les murs nord ET sud
		# (retour utilisateur : "ça doit être sur le mur, comme une vraie
		# torche" -- cf. WALL_LIGHT_SIDES pour pourquoi est/ouest sont exclus)
		# -- des TUILES peintes comme les autres décors ci-dessus, une par
		# côté (cf. _wall_light_cell_for_side()). La lumière elle-même
		# (WallLight) est un noeud séparé par cellule, posé par
		# Room._setup_wall_light() (cf. set_wall_light() dans game.gd._spawn_room()) --
		# une tuile n'a pas de PointLight2D.
		var wall_light_source_id: int = prop_tile_sources["decor"][WALL_LIGHT_TEXTURE_PATHS[pool_index]]
		for side in WALL_LIGHT_SIDES:
			for cell in _wall_light_cell_for_side(room_data, side):
				wall_light_cells.append(cell)
				decor_cells.append(cell)
				decor_source_ids.append(wall_light_source_id)
	room_data["decor_cells"] = decor_cells
	room_data["decor_source_ids"] = decor_source_ids
	room_data["blocking_cells"] = blocking_cells
	room_data["blocking_source_ids"] = blocking_source_ids
	room_data["wall_light_cells"] = wall_light_cells

## Zones à garder libres pour le placement des props : bandes d'embrasure de
## porte (calculées directement depuis room_data["open_sides"], sans attendre
## le Room.set_open_sides() déféré -- cf. Room.TILE_SIZE_PX) et, pour les
## salles spéciales/trésor, un cercle autour du meuble central (toujours à
## rect.get_center() dans leurs templates, cf. AlchemyStation/WeaponStation/Chest).
func _prop_exclusion_rects(room_data: Dictionary) -> Array[Rect2]:
	var rect: Rect2 = _room_world_rect.call(room_data)
	var door_span: float = Room.DOOR_TILES * Room.TILE_SIZE_PX
	var exclusions: Array[Rect2] = []
	for side in room_data["open_sides"]:
		match side:
			"north":
				exclusions.append(Rect2(rect.position.x + (rect.size.x - door_span) / 2.0, rect.position.y, door_span, PROP_DOOR_CLEARANCE))
			"south":
				exclusions.append(Rect2(rect.position.x + (rect.size.x - door_span) / 2.0, rect.end.y - PROP_DOOR_CLEARANCE, door_span, PROP_DOOR_CLEARANCE))
			"west":
				exclusions.append(Rect2(rect.position.x, rect.position.y + (rect.size.y - door_span) / 2.0, PROP_DOOR_CLEARANCE, door_span))
			"east":
				exclusions.append(Rect2(rect.end.x - PROP_DOOR_CLEARANCE, rect.position.y + (rect.size.y - door_span) / 2.0, PROP_DOOR_CLEARANCE, door_span))
	if room_data["is_special"] or room_data["is_treasure"]:
		var center: Vector2 = rect.get_center()
		exclusions.append(Rect2(center - Vector2.ONE * PROP_CENTER_CLEARANCE_RADIUS, Vector2.ONE * PROP_CENTER_CLEARANCE_RADIUS * 2.0))
	return exclusions

## Rejection sampling borné (PROP_PLACEMENT_ATTEMPTS) plutôt qu'une recherche
## exhaustive de point valide -- cohérent avec le reste du placement procédural
## de ce projet, qui n'a aucune garantie d'absence d'overlap pour le placement
## de type "aléatoire dans la salle" (cf. game.gd._random_position_in_room,
## utilisée telle quelle pour les ennemis). Ici en plus des zones d'exclusion,
## rejette aussi tout candidat trop proche d'un prop déjà placé DANS CETTE
## SALLE (placed_positions, cf. prepare_room_props) -- sans quoi deux props
## immobiles peuvent se chevaucher et fusionner visuellement en un bloc
## incohérent. Dernier essai accepté tel quel si aucun n'est valide : un prop
## très occasionnellement trop proche d'un autre plutôt qu'un blocage de génération.
func _random_prop_position_in_room(room_data: Dictionary, placed_positions: Array[Vector2]) -> Vector2:
	var exclusions: Array[Rect2] = _prop_exclusion_rects(room_data)
	var candidate: Vector2 = _random_position_in_room.call(room_data)
	for attempt in PROP_PLACEMENT_ATTEMPTS:
		if _is_valid_prop_position(candidate, exclusions, placed_positions):
			return candidate
		candidate = _random_position_in_room.call(room_data)
	return candidate

func _is_valid_prop_position(candidate: Vector2, exclusions: Array[Rect2], placed_positions: Array[Vector2]) -> bool:
	for zone in exclusions:
		if zone.has_point(candidate):
			return false
	for other in placed_positions:
		if candidate.distance_to(other) < PROP_MIN_SPACING:
			return false
	return true

## Choisit UNE cellule (pas une position monde) pour la torche murale de ce
## côté -- rangée de bord (cf. Room._paint_walls(), même repère que
## WANG_ATLAS_BY_CORNERS/DOOR_TILES). Room n'existe pas encore à cet instant
## (cf. prepare_room_props(), appelée avant room_spawner.spawn() dans
## game.gd._generate_dungeon()), donc ce calcul ne peut pas lire les champs
## privés de la Room -- il reproduit la même formule que _paint_walls() à
## partir des constantes publiques de Room (ROOM_COLS, DOOR_TILES). Exclut les
## 2 coins et, si ce côté est structurellement ouvert, l'embrasure de porte
## (+ les 2 cases de bord plein qui l'encadrent, cf. Room._flatten_door_frame()).
## Tableau vide si aucune cellule valide (salle trop petite ou porte trop
## large) -- mieux qu'un blocage de génération, même philosophie que
## _random_prop_position_in_room().
func _wall_light_cell_for_side(room_data: Dictionary, side: String) -> Array[Vector2i]:
	var door_col_start: int = (ROOM_COLS - Room.DOOR_TILES) / 2
	var door_col_end: int = door_col_start + Room.DOOR_TILES
	var open_here: bool = side in room_data["open_sides"]
	var y: int = 0 if side == "north" else ROOM_ROWS - 1
	var candidates: Array[Vector2i] = []
	for x in range(1, ROOM_COLS - 1):
		if open_here and x >= door_col_start - 1 and x <= door_col_end:
			continue
		candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return []
	return [candidates[randi() % candidates.size()]]
