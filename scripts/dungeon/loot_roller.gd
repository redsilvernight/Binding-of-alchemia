class_name LootRoller
extends RefCounted

## Extrait de game.gd (File Size, cf. .claude/rules/gdscript.md) : tirage du
## contenu du coffre de la salle au trésor et répartition d'un montant de
## monnaie en pièces physiques. Pure logique de tirage -- game.gd reste seul
## responsable du spawn réseau réel (pickup_spawner, garde is_server()).

## Phase 9.2 : contenu du coffre de la salle au trésor, tiré une fois à la
## génération (pas à l'ouverture, pour rester déterministe côté hôte) --
## chest.gd se contente de stocker ce dict et de le renvoyer tel quel à
## game.gd.request_open_chest() une fois interagi. Une seule pièce d'arme au
## plus (pick_one pondéré, plus l'ancienne garantie "une de chaque"), de la
## monnaie possible en plus ou à la place, et une très faible chance de
## "coffre piège" (pas de loot, un ennemi apparaît à la place). Pourcentages
## et montants sont un premier réglage, à ajuster en playtest.
const CHEST_TRAP_CHANCE: float = 0.05
const CHEST_WEAPON_PART_CHANCE: float = 0.65
const CHEST_CURRENCY_CHANCE: float = 0.5
# Tiré en nombre de pièces (cf. CURRENCY_PER_COIN plus bas), pas en montant
# brut -- garantit que le total est toujours un multiple exact de
# CURRENCY_PER_COIN, sans quoi une partie du montant tiré ne correspondrait
# à aucune pièce physique réellement spawnable.
const CHEST_CURRENCY_COINS_MIN: int = 3
const CHEST_CURRENCY_COINS_MAX: int = 6
# Dispersion autour du coffre lui-même (room_treasure.tscn place le noeud
# Chest au centre de la salle) plutôt qu'une position aléatoire dans toute la
# salle -- sinon les items pouvaient apparaître très loin du coffre qu'on
# vient d'ouvrir.
const CHEST_LOOT_SCATTER_RADIUS: float = 80.0

## Phase 9.2 (dynamisme) : une pièce physique vaut toujours CURRENCY_PER_COIN
## -- un montant total (récompense de kill, monnaie de coffre) se traduit en
## N pièces séparées à ramasser plutôt qu'une seule au montant variable.
## Division entière, au moins une pièce si amount > 0 (arrondi vers le bas
## si amount n'est pas un multiple exact de CURRENCY_PER_COIN).
const CURRENCY_PER_COIN: int = 5
const CURRENCY_SCATTER_RADIUS: float = 40.0

func random_position_near(center: Vector2, radius: float) -> Vector2:
	return center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))

func currency_coin_positions(amount: int, center: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if amount <= 0:
		return positions
	var coin_count: int = maxi(1, amount / CURRENCY_PER_COIN)
	for i in coin_count:
		positions.append(random_position_near(center, CURRENCY_SCATTER_RADIUS))
	return positions

func roll_chest_contents(room_data: Dictionary, room_world_rect: Rect2, enemy_table_path: String, weapon_part_table_path: String) -> Dictionary:
	var chest_position: Vector2 = room_world_rect.get_center()
	if randf() < CHEST_TRAP_CHANCE:
		var enemy_table: SpawnTable = load(enemy_table_path) as SpawnTable
		return {
			"is_trap": true,
			"enemy_scene_path": enemy_table.pick_one(),
			"position": chest_position,
		}

	var contents: Dictionary = {
		"is_trap": false,
		"weapon_part_path": "",
		"currency": 0,
		"position": random_position_near(chest_position, CHEST_LOOT_SCATTER_RADIUS),
	}
	if randf() < CHEST_WEAPON_PART_CHANCE:
		var weapon_part_table: SpawnTable = load(weapon_part_table_path) as SpawnTable
		contents["weapon_part_path"] = weapon_part_table.pick_one()
	if randf() < CHEST_CURRENCY_CHANCE:
		contents["currency"] = randi_range(CHEST_CURRENCY_COINS_MIN, CHEST_CURRENCY_COINS_MAX) * CURRENCY_PER_COIN
	return contents
