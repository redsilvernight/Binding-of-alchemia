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


## Phase 8.2 : entrées effectivement tirables, en excluant celles marquées
## requires_unlock tant qu'aucun joueur de la partie ne les a débloquées
## (cf. MetaProgression.is_unlocked_by_party) — le donjon est une ressource
## partagée par le groupe, pas par-joueur.
func _available_entries() -> Array[SpawnTableEntry]:
	var available: Array[SpawnTableEntry] = []
	for entry in entries:
		if entry.requires_unlock and not MetaProgression.is_unlocked_by_party(entry.item_path):
			continue
		available.append(entry)
	return available


## Un tirage pondéré parmi entries. Chemin vide si la table n'a aucune entrée
## disponible à poids > 0.
func pick_one() -> String:
	var available: Array[SpawnTableEntry] = _available_entries()
	var total_weight: float = 0.0
	for entry in available:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return ""
	var roll: float = randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in available:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.item_path
	return available[-1].item_path


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
	for entry in _available_entries():
		paths.append(entry.item_path)
	paths.shuffle()
	return paths
