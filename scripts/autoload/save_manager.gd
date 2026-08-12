extends Node
## Sauvegarde disque (Phase 8.3) : lit/écrit UNIQUEMENT la progression du
## joueur LOCAL (monnaie + déblocages), sans connaissance du réseau ni de
## MetaProgression. Volontairement agnostique du peer_id (qui change à
## chaque connexion, cf. meta_progression.gd) : c'est à l'appelant
## (network_manager.gd) de réinjecter cette donnée sous le bon peer_id de
## la session en cours.
##
## Profils multiples (Phase 8.5) : 3 profils distincts sur un même poste
## (ex. plusieurs joueurs locaux), chacun dans son propre fichier. Le profil
## actif est choisi depuis main_menu.gd et persiste entre les lancements du
## jeu via active_profile.json. load_progression()/save_progression() gardent
## la même signature qu'avant : les appelants (network_manager.gd,
## meta_progression.gd) restent agnostiques du profil, comme ils le sont déjà
## du peer_id.

const PROFILE_COUNT: int = 3
const SAVE_DIR: String = "user://saves/"
const ACTIVE_PROFILE_PATH: String = "user://active_profile.json"

var active_profile: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	active_profile = _load_active_profile()


func get_active_profile() -> int:
	return active_profile


func set_active_profile(index: int) -> void:
	active_profile = clampi(index, 0, PROFILE_COUNT - 1)
	var file: FileAccess = FileAccess.open(ACTIVE_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"active": active_profile}))
	file.close()


func load_progression() -> Dictionary:
	return get_profile_preview(active_profile)


func save_progression(currency: int, unlocked: Array) -> void:
	var file: FileAccess = FileAccess.open(_profile_path(active_profile), FileAccess.WRITE)
	var data: Dictionary = {"currency": currency, "unlocked": unlocked}
	file.store_string(JSON.stringify(data))
	file.close()


## Lit un profil sans changer le profil actif (ex : peupler le sélecteur de
## profils dans main_menu.gd avec un aperçu de la monnaie).
func get_profile_preview(index: int) -> Dictionary:
	var path: String = _profile_path(index)
	if not FileAccess.file_exists(path):
		return {"currency": 0, "unlocked": []}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"currency": 0, "unlocked": []}

	var unlocked: Array = parsed.get("unlocked", [])
	return {
		"currency": int(parsed.get("currency", 0)),
		"unlocked": unlocked,
	}


func _profile_path(index: int) -> String:
	return SAVE_DIR + "profile_%d.json" % index


func _load_active_profile() -> int:
	if not FileAccess.file_exists(ACTIVE_PROFILE_PATH):
		return 0

	var file: FileAccess = FileAccess.open(ACTIVE_PROFILE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return clampi(int(parsed.get("active", 0)), 0, PROFILE_COUNT - 1)
