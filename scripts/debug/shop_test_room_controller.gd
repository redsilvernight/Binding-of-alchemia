extends Node
## Scène de test jetable (retour utilisateur), même esprit que
## mixture_test_room_controller.gd : bac à sable indépendant de la boucle de
## run/donjon, ici pour tester la boutique du hub (portail, comptoir/vendeur,
## écran de déblocage, pool tournant) sans avoir à jouer une vraie run pour
## accumuler de la monnaie. hub.tscn est instancié tel quel à côté de ce
## contrôleur (cf. shop_test_room.tscn) -- aucune duplication de sa logique,
## ce script se contente d'injecter x999 monnaie AVANT toute ouverture de
## l'écran de déblocage. À supprimer une fois les tests terminés.
##
## Suppose un lancement solo (aucun pair réseau), comme mixture_test_room :
## l'absence de multiplayer_peer fait tourner Godot en mode hors-ligne
## (is_server() == true, get_unique_id() == 1) sans rien à initialiser
## explicitement -- vrai par défaut si cette scène est lancée directement
## (F6) sans passer par le menu.

const TEST_CURRENCY: int = 999


func _ready() -> void:
	_disconnect_autosave()
	MetaProgression.currency_by_peer[NetworkManager.get_unique_id()] = TEST_CURRENCY


## Retour utilisateur : "la monnaie x999 uniquement dans cette scène" --
## MetaProgression sauvegarde automatiquement sur TOUT changement de
## monnaie/déblocage (cf. _on_local_progression_changed, connecté en
## permanence dans son propre _ready()). Sans cette déconnexion, la monnaie
## factice ci-dessus (et le moindre achat de test dans la boutique)
## écraserait le vrai user://save.json du joueur. Déconnexion par
## inspection des connexions existantes plutôt qu'en reconstruisant le
## Callable exact (currency_changed est connecté via .unbind(1), fragile à
## reproduire à l'identique depuis l'extérieur) -- get_connections()
## renvoie le Callable RÉELLEMENT stocké, donc le disconnect() ne peut pas
## échouer par non-correspondance. Jamais reconnectée : cette scène est
## jetable, pas de retour à une partie normale dans le même processus.
func _disconnect_autosave() -> void:
	for connection in MetaProgression.currency_changed.get_connections():
		if connection["callable"].get_method() == "_on_local_progression_changed":
			MetaProgression.currency_changed.disconnect(connection["callable"])
	for connection in MetaProgression.unlocks_changed.get_connections():
		if connection["callable"].get_method() == "_on_local_progression_changed":
			MetaProgression.unlocks_changed.disconnect(connection["callable"])
