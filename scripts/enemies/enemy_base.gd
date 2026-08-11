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

func _ready() -> void:
	super()
	add_to_group("Enemies")

## Point d'extension pour un futur système de drop : les sous-classes peuvent
## surcharger (en appelant super() pour garder la récompense de monnaie) pour
## ajouter un spawn de pickup avant la destruction du noeud.
##
## Récompense partagée par toute la partie plutôt qu'attribuée au tireur
## précis : take_damage()/Bullet/ImpactEffect ne portent aucune identité de
## tireur aujourd'hui (Character.take_damage(degat: float) ne reçoit qu'un
## montant), et ajouter cette traçabilité toucherait la chaîne de dégâts
## partagée (cf. règle "Combat and gameplay systems" du projet) pour un
## bénéfice minime en co-op où l'équipe progresse ensemble.
func _on_death() -> void:
	for peer_id in NetworkManager.get_peers():
		MetaProgression.add_currency(peer_id, currency_reward)
	MetaProgression.add_currency(NetworkManager.get_unique_id(), currency_reward)

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
