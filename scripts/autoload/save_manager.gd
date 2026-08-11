extends Node
## Sauvegarde disque (Phase 8.3) : lit/écrit UNIQUEMENT la progression du
## joueur LOCAL (monnaie + déblocages), sans connaissance du réseau ni de
## MetaProgression. Volontairement agnostique du peer_id (qui change à
## chaque connexion, cf. meta_progression.gd) : c'est à l'appelant
## (network_manager.gd) de réinjecter cette donnée sous le bon peer_id de
## la session en cours.

const SAVE_PATH: String = "user://save.json"


func load_progression() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"currency": 0, "unlocked": []}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
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


func save_progression(currency: int, unlocked: Array) -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data: Dictionary = {"currency": currency, "unlocked": unlocked}
	file.store_string(JSON.stringify(data))
	file.close()
