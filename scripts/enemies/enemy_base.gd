class_name EnemyBase
extends Character

## Reste inactif tant que sa Room ne l'a pas activé (cf. Room._activate_enemies_delayed) :
## sans ça, un ennemi vise le joueur le plus proche dès le lancement de la
## partie, quelle que soit la salle où il se trouve, et va se coller contre
## sa propre porte à attendre — repéré avant même que le joueur entre.
var active: bool = false

## Monnaie méta (Phase 8.2) accordée au joueur qui porte le coup fatal. Exporté
## pour permettre à des ennemis plus forts (ex : boss_01.tscn) de valoir plus.
@export var currency_reward: int = 5

## Phase 9.2 : chemin d'un ingrédient à lâcher à la mort, assigné par
## game.gd juste après spawn (budget d'ingrédients fixe réparti sur des
## ennemis choisis au hasard pour tout l'étage — pas un tirage indépendant
## par mort, cf. _generate_dungeon()). Vide = cet ennemi ne lâche rien.
var carries_ingredient_path: String = ""

func _ready() -> void:
	super()
	add_to_group("Enemies")

## Monnaie et ingrédient (si porté) lâchés comme pickups physiques au sol
## (Phase 9.2, dynamisme) -- ramassés individuellement par qui marche
## dessus, plus de crédit/attribution de "partie" à décider ici. Les
## sous-classes peuvent surcharger (en appelant super()) pour ajouter
## d'autres drops avant la destruction du noeud.
func _on_death() -> void:
	var game: Node = get_tree().get_first_node_in_group("Game")
	if game == null:
		return
	game.request_currency_drop(global_position, currency_reward)
	if carries_ingredient_path != "":
		game.request_enemy_drop(global_position, carries_ingredient_path)

func kill() -> void:
	if multiplayer.is_server():
		_on_death()
	super()

## Joueur vivant le plus proche, pour les 3 implémentations concrètes de
## _update_target() (ennemi_test.gd, enemy_ranged.gd, boss_01.gd — dupliquées
## à l'identique jusqu'ici, cf. convention duck-typing documentée dans
## enemy_state_chase.gd/enemy_state_ranged_attack.gd). Exclut les spectateurs
## (is_dead) : un joueur mort reste un noeud figé dans le groupe "Players"
## (cf. Player.kill(), Phase 8.1) — sans ce filtre, un ennemi peut se fixer
## sur un cadavre plus proche que le joueur vivant et ne plus jamais recibler,
## peu importe où ce dernier se trouve (bug constaté en playtest à 3 joueurs).
func _closest_living_player() -> Node2D:
	var closest: Node2D = null
	var closest_distance: float = INF
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_dead:
			continue
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = player
	return closest
