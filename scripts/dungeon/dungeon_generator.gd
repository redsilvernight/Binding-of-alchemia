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


static func generate(room_count: int, room_template_paths: Array[String], special_room_template_paths: Array[String]) -> Array[Dictionary]:
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

	var layout: Array[Dictionary] = []
	for cell in cells:
		var open_sides: Array[String] = []
		for dir in DIRECTIONS.keys():
			if occupied.has(cell + DIRECTIONS[dir]):
				open_sides.append(dir)
		var template_path: String = special_template_path if cell == special_cell else room_template_paths[randi() % room_template_paths.size()]
		layout.append({
			"grid_position": cell,
			"template_path": template_path,
			"open_sides": open_sides,
			"is_start": cell == start,
			"is_special": cell == special_cell,
		})
	return layout
