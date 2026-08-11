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


static func generate(room_count: int, room_template_paths: Array[String], special_room_template_paths: Array[String], boss_room_template_path: String) -> Array[Dictionary]:
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

	# La salle de départ (0,0) n'est jamais la salle spéciale (alchimie OU
	# arme, jamais les deux à la fois — cf. room_alchemy.tscn/room_weapon.tscn) :
	# Dictionary préserve l'ordre d'insertion en GDScript 4, donc
	# occupied.keys()[0] == start.
	var cells: Array = occupied.keys()
	var special_cell: Vector2i = start
	if cells.size() > 1:
		special_cell = cells[1 + (randi() % (cells.size() - 1))]
	var special_template_path: String = special_room_template_paths[randi() % special_room_template_paths.size()]

	# Salle de boss (7.4) : jamais tirée au hasard — toujours la cellule la
	# plus éloignée du départ (distance de grille), pour que le boss se
	# trouve systématiquement "au fond" du donjon. Exclut start et
	# special_cell (jamais les deux salles spéciales superposées).
	var boss_cell: Vector2i = start
	var boss_candidates: Array = cells.filter(func(c): return c != start and c != special_cell)
	if not boss_candidates.is_empty():
		boss_cell = boss_candidates[0]
		var best_distance: int = (boss_cell - start).length_squared()
		for candidate in boss_candidates:
			var distance: int = (candidate - start).length_squared()
			if distance > best_distance:
				best_distance = distance
				boss_cell = candidate

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
		layout.append({
			"grid_position": cell,
			"template_path": template_path,
			"open_sides": open_sides,
			"is_start": cell == start,
			"is_special": cell == special_cell,
			"is_boss": cell == boss_cell,
		})
	return layout
