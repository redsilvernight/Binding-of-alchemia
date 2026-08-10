class_name SpawnTable
extends Resource

# Table de spawn pondérée (Phase 6.3) : sépare QUOI/COMBIEN spawn (données,
# .tres dans resources/spawn_tables/) du OÙ (résolu par l'appelant — cf.
# game.gd, position aléatoire dans la salle). Toujours tirée côté hôte
# uniquement (appelée depuis le bloc `if multiplayer.is_server():` de
# game.gd) ; le résultat est répliqué via MultiplayerSpawner, jamais retiré
# indépendamment par chaque pair (cf. architecture_reseau.md).

@export var entries: Array[SpawnTableEntry] = []
## Nombre d'éléments tirés par pick_many() — ignoré par pick_all_shuffled().
@export var min_count: int = 1
@export var max_count: int = 1


## Un tirage pondéré parmi entries. Chemin vide si la table n'a aucune entrée
## à poids > 0.
func pick_one() -> String:
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return ""
	var roll: float = randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in entries:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.item_path
	return entries[-1].item_path


## min_count à max_count tirages pondérés avec remise (doublons possibles) —
## pour la densité d'ennemis ou la rareté d'ingrédients.
func pick_many() -> Array[String]:
	var results: Array[String] = []
	for i in randi_range(min_count, max_count):
		var path: String = pick_one()
		if path != "":
			results.append(path)
	return results


## Toutes les entrées, une fois chacune, ordre mélangé — pour garantir la
## couverture complète d'un pool (ex : une pièce d'arme de chaque catégorie
## par donjon, indispensable pour que la boucle de craft reste jouable).
func pick_all_shuffled() -> Array[String]:
	var paths: Array[String] = []
	for entry in entries:
		paths.append(entry.item_path)
	paths.shuffle()
	return paths
