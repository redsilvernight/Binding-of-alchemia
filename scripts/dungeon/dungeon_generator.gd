class_name DungeonGenerator
extends RefCounted

# Génère le donjon de la Phase 6.1 : une grille de cellules occupées par
# marche aléatoire depuis la cellule de départ (0,0), puis résout les
# connexions entre salles voisines. Modèle grille fixe façon Isaac (toutes
# les salles ont le même gabarit extérieur) plutôt qu'un graphe libre —
# choisi pour éviter tout chevauchement/désalignement de porte à valider.
#
# Aucune notion de réseau ici : c'est à l'appelant (game.gd, côté hôte
# uniquement) de décider et de répliquer le résultat aux clients via un
# MultiplayerSpawner, jamais de le régénérer indépendamment sur chaque
# pair (cf. architecture_reseau.md).

const DIRECTIONS: Dictionary = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}


static func generate(room_count: int, room_template_paths: Array[String], special_room_template_paths: Array[String], boss_room_template_path: String, treasure_room_template_path: String) -> Array[Dictionary]:
	var start: Vector2i = Vector2i.ZERO
	var occupied: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]

	while occupied.size() < room_count and not frontier.is_empty():
		var from: Vector2i = frontier[randi() % frontier.size()]
		var dirs: Array = DIRECTIONS.keys()
		dirs.shuffle()
		var placed: bool = false
		for dir in dirs:
			var candidate: Vector2i = from + DIRECTIONS[dir]
			if occupied.has(candidate):
				continue
			occupied[candidate] = true
			frontier.append(candidate)
			placed = true
			break
		if not placed:
			frontier.erase(from) # plus aucun voisin libre accessible depuis cette salle

	var cells: Array = occupied.keys()

	# Portes réelles entre salles voisines : PAS forcément un arbre -- deux
	# branches de la marche aléatoire peuvent finir géométriquement adjacentes
	# et s'ouvrir l'une sur l'autre (open_sides plus bas teste les 4 côtés,
	# pas seulement le lien de parenté de la marche). Calculé une fois ici,
	# réutilisé pour situer le boss par vraie distance de chemin et vérifier
	# l'accessibilité des salles spéciale/trésor sans passer par lui.
	var adjacency: Dictionary = {} # Vector2i -> Array[Vector2i]
	for cell in cells:
		var neighbors: Array[Vector2i] = []
		for dir in DIRECTIONS.keys():
			var neighbor: Vector2i = cell + DIRECTIONS[dir]
			if occupied.has(neighbor):
				neighbors.append(neighbor)
		adjacency[cell] = neighbors

	# Salle de boss (7.4) : jamais tirée au hasard — toujours la salle la
	# plus profonde depuis le départ en NOMBRE DE PORTES à traverser (BFS sur
	# adjacency), pas en distance à vol d'oiseau comme avant -- l'ancienne
	# métrique euclidienne pouvait désigner "profond" une salle proche en
	# distance de grille mais reliée par un long chemin, laissant une salle
	# spéciale réellement plus profonde qu'elle, donc au-delà du boss et
	# inaccessible une fois celui-ci atteint (retour utilisateur).
	var start_distances: Dictionary = _bfs_distances(start, adjacency)
	var boss_cell: Vector2i = start
	var best_distance: int = -1
	for cell in cells:
		if cell == start:
			continue
		var distance: int = start_distances.get(cell, -1)
		if distance > best_distance:
			best_distance = distance
			boss_cell = cell

	# Salles spéciale (alchimie/arme) et trésor : choisies uniquement parmi
	# les salles encore accessibles depuis le départ SANS emprunter boss_cell
	# (reachable_without_boss = même BFS, boss_cell muré). Sans cette
	# contrainte, une salle spéciale pouvait retomber dans la branche "derrière"
	# le boss et devenir inaccessible (retour utilisateur ci-dessus).
	var reachable_without_boss: Dictionary = _bfs_distances(start, adjacency, boss_cell)

	var special_candidates: Array = cells.filter(func(c): return c != start and c != boss_cell and reachable_without_boss.has(c))
	var special_cell: Vector2i = start
	if not special_candidates.is_empty():
		special_cell = special_candidates[randi() % special_candidates.size()]
	var special_template_path: String = special_room_template_paths[randi() % special_room_template_paths.size()]

	# Salle au trésor (9.2) : comme la salle spéciale, position aléatoire
	# parmi les cellules restantes accessibles sans passer par le boss (pas
	# de raison d'être "au fond du donjon" comme lui). Même repli sur start
	# si aucune cellule libre.
	var treasure_candidates: Array = cells.filter(func(c): return c != start and c != boss_cell and c != special_cell and reachable_without_boss.has(c))
	var treasure_cell: Vector2i = start
	if not treasure_candidates.is_empty():
		treasure_cell = treasure_candidates[randi() % treasure_candidates.size()]

	var layout: Array[Dictionary] = []
	for cell in cells:
		var open_sides: Array[String] = []
		for dir in DIRECTIONS.keys():
			if occupied.has(cell + DIRECTIONS[dir]):
				open_sides.append(dir)
		var template_path: String = room_template_paths[randi() % room_template_paths.size()]
		if cell == special_cell:
			template_path = special_template_path
		elif cell == boss_cell:
			template_path = boss_room_template_path
		elif cell == treasure_cell:
			template_path = treasure_room_template_path
		layout.append({
			"grid_position": cell,
			"template_path": template_path,
			"open_sides": open_sides,
			"is_start": cell == start,
			"is_special": cell == special_cell,
			"is_boss": cell == boss_cell,
			"is_treasure": cell == treasure_cell,
		})
	return layout


## BFS sur le graphe des portes réelles (adjacency), en s'interdisant
## optionnellement de traverser excluded_cell (utilisé pour vérifier qu'une
## salle reste accessible sans passer par le boss). Retourne les distances
## (en nombre de salles) des cellules atteintes depuis start -- une cellule
## absente du résultat n'est pas accessible dans ces conditions.
static func _bfs_distances(start: Vector2i, adjacency: Dictionary, excluded_cell: Variant = null) -> Dictionary:
	var distances: Dictionary = {start: 0}
	if excluded_cell != null and start == excluded_cell:
		return distances
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for neighbor in adjacency.get(current, []):
			if (excluded_cell != null and neighbor == excluded_cell) or distances.has(neighbor):
				continue
			distances[neighbor] = distances[current] + 1
			queue.append(neighbor)
	return distances
