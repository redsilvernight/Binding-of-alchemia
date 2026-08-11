class_name EnemyBase
extends Character

## Reste inactif tant que sa Room ne l'a pas activé (cf. Room._activate_enemies_delayed) :
## sans ça, un ennemi vise le joueur le plus proche dès le lancement de la
## partie, quelle que soit la salle où il se trouve, et va se coller contre
## sa propre porte à attendre — repéré avant même que le joueur entre.
var active: bool = false

func _ready() -> void:
	super()
	add_to_group("Enemies")

## Point d'extension pour un futur système de drop (aucune table de loot
## n'existe encore, donc ceci ne fait rien par défaut) : les sous-classes
## peuvent surcharger pour spawn un pickup avant la destruction du noeud.
func _on_death() -> void:
	pass

func kill() -> void:
	if multiplayer.is_server():
		_on_death()
	super()
