extends CanvasLayer

# Écran de crafting d'alchimie (Phase 5.5, restylé : chaudron interactif +
# liste d'ingrédients cliquables/glissables, même paradigme que
# weapon_crafting.gd adapté à l'alchimie -- pas d'emplacements typés fixes
# ici (une mixture accepte un nombre et un mélange d'ingrédients
# quelconques), donc un chaudron qui accumule une liste EN LOCAL (jamais
# envoyée tant que "Composer" n'est pas cliqué) plutôt que des sockets.
# Comme avant, cet écran ne modifie JAMAIS l'état lui-même -- il envoie
# l'intention de mix par RPC vers l'hôte (Player.request_craft_mixture), qui
# seul valide le stock, consomme les ingrédients et résout la recette (cf.
# architecture_reseau.md).

const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")

@onready var root: Control = $Root
@onready var loaded_vial_icon: TextureRect = $Root/FramePanel/Margin/Content/HeaderRow/LoadedRow/LoadedVialIcon
@onready var loaded_label: Label = $Root/FramePanel/Margin/Content/HeaderRow/LoadedRow/LoadedLabel
@onready var cauldron_preview: MixturePreview = $Root/FramePanel/Margin/Content/CauldronPreview
@onready var ingredients_grid: GridContainer = $Root/FramePanel/Margin/Content/IngredientsScroll/IngredientsGrid
@onready var compose_button: Button = $Root/FramePanel/Margin/Content/ComposeRow/ComposeButton
@onready var result_label: Label = $Root/FramePanel/Margin/Content/ComposeRow/ResultLabel

var inventory: Inventory
var weapon: Weapon
## Ingrédients ajoutés au chaudron mais pas encore envoyés à l'hôte (cf.
## _on_compose_pressed) -- purement local, jamais répliqué : personne d'autre
## n'a besoin de voir "en cours de composition" avant confirmation.
var _pending_paths: Array[String] = []
## Peer_id du joueur propriétaire de cet écran (cf. get_parent() ci-dessous) --
## résolu une fois en _ready(), utilisé pour interroger RunManager.has_used_alchemy()
## côté CE joueur uniquement (le verrou est maintenant par joueur, pas par
## groupe, cf. RunManager.alchemy_used_by_peer).
var _owner_peer_id: int = 0


func _ready() -> void:
	root.visible = false
	compose_button.pressed.connect(_on_compose_pressed)
	cauldron_preview.item_dropped.connect(_add_to_pending)
	cauldron_preview.item_activated.connect(_remove_from_pending)
	# get_parent().weapon : même pattern que weapon_crafting.gd -- toujours
	# instancié comme enfant de Player, après que son propre @onready var
	# weapon ait déjà résolu (cf. player.gd::_ready).
	weapon = get_parent().weapon
	_owner_peer_id = int(get_parent().name)
	weapon.mixture_changed.connect(_refresh_loaded_summary)
	RunManager.alchemy_lock_changed.connect(_on_lock_changed)


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.ingredient_added.connect(_on_inventory_changed)
	inventory.ingredient_removed.connect(_on_inventory_changed)


func open() -> void:
	AudioManager.play_sfx("station_open")
	root.visible = true
	_pending_paths.clear()
	_refresh_available()
	cauldron_preview.display(_pending_paths, inventory)
	_refresh_loaded_summary(weapon.mixture_ingredient_paths)
	result_label.text = ""
	_on_lock_changed(_owner_peer_id, RunManager.has_used_alchemy(_owner_peer_id))


func close() -> void:
	root.visible = false


## Retour utilisateur : se ferme avec la même touche qu'à l'ouverture (E, via
## Interactable -> Player.open_alchemy_crafting()) plutôt qu'avec Échap --
## Échap est réservé au menu pause (pause_menu.gd).
func toggle() -> void:
	if root.visible:
		close()
	else:
		open()


func _on_inventory_changed(_ingredient: Ingredient, _new_quantity: int) -> void:
	if root.visible:
		_refresh_available()


## Indicateur discret (icône + compte) dans l'entête -- contrairement au
## chaudron, pas de grille d'ingrédients ici : la mixture déjà chargée n'est
## qu'un rappel de contexte, pas une zone d'interaction (cf. retour
## utilisateur, un aperçu complet façon MixturePreview prenait trop de place).
func _refresh_loaded_summary(ingredient_paths: Array[String]) -> void:
	if not root.visible:
		return
	if ingredient_paths.is_empty() or inventory == null:
		loaded_vial_icon.modulate = MixturePreview.EMPTY_VIAL_COLOR
		loaded_label.text = "Mixture chargée : aucune"
		return

	var occurrences_by_type: Dictionary = {} # Ingredient.TypeAlchimie -> int
	for path in ingredient_paths:
		var ingredient: Ingredient = inventory.ingredient_resources.get(path)
		if ingredient == null:
			continue
		occurrences_by_type[ingredient.type_alchimie] = occurrences_by_type.get(ingredient.type_alchimie, 0) + 1

	var best_type = null
	var best_count: int = -1
	for type in occurrences_by_type.keys():
		if occurrences_by_type[type] > best_count:
			best_count = occurrences_by_type[type]
			best_type = type
	loaded_vial_icon.modulate = MixturePreview.TYPE_COLORS.get(best_type, MixturePreview.EMPTY_VIAL_COLOR)

	var count: int = ingredient_paths.size()
	loaded_label.text = "Mixture chargée : %d ingrédient%s" % [count, "s" if count > 1 else ""]


## Ajout depuis la grille "disponibles" (clic OU drop dans le chaudron) --
## refuse silencieusement si le joueur n'en possède plus assez pour honorer
## ce qui est déjà en attente (désync possible si l'inventaire change pendant
## que l'écran est ouvert, cf. _refresh_available).
func _add_to_pending(ingredient: Resource) -> void:
	if inventory == null or not (ingredient is Ingredient):
		return
	if RunManager.has_used_alchemy(_owner_peer_id):
		AudioManager.play_sfx("ui_error")
		return
	if _pending_paths.size() >= get_parent().MAX_INGREDIENTS_PER_CRAFT:
		AudioManager.play_sfx("ui_error")
		return
	var item: Ingredient = ingredient as Ingredient
	var key: String = item.resource_path
	var owned: int = inventory.get_ingredient_count(item)
	var already_pending: int = _pending_paths.count(key)
	if already_pending >= owned:
		AudioManager.play_sfx("ui_error")
		return
	_pending_paths.append(key)
	_refresh_available()
	cauldron_preview.display(_pending_paths, inventory)


## Retire UNE occurrence -- cliquer un ingrédient du chaudron l'enlève un par
## un plutôt que tout d'un coup, symétrique à l'ajout par clic.
func _remove_from_pending(ingredient: Resource) -> void:
	if not (ingredient is Ingredient):
		return
	var item: Ingredient = ingredient as Ingredient
	var index: int = _pending_paths.find(item.resource_path)
	if index == -1:
		return
	_pending_paths.remove_at(index)
	_refresh_available()
	cauldron_preview.display(_pending_paths, inventory)


func _refresh_available() -> void:
	for child in ingredients_grid.get_children():
		child.queue_free()

	for key in inventory.ingredients.keys():
		var owned: int = inventory.ingredients[key]
		var remaining: int = owned - _pending_paths.count(key)
		if remaining <= 0:
			continue
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		var chip: Button = item_chip_scene.instantiate()
		ingredients_grid.add_child(chip)
		var icon: Texture2D = ingredient.icon if (ingredient and ingredient.icon) else INGREDIENT_FALLBACK_ICON
		var nom: String = ingredient.nom if ingredient else key.get_file()
		chip.setup(ingredient, icon, nom, remaining)
		chip.activated.connect(_add_to_pending)


func _on_compose_pressed() -> void:
	if RunManager.has_used_alchemy(_owner_peer_id):
		AudioManager.play_sfx("ui_error")
		result_label.text = "Table déjà utilisée pour cet étage."
		return
	if _pending_paths.is_empty():
		AudioManager.play_sfx("ui_error")
		result_label.text = "Ajoute au moins un ingrédient au chaudron."
		return

	# L'hôte revalidera le stock avant de retirer quoi que ce soit ; on ne
	# fait ici qu'exprimer l'intention, jamais de calcul de résultat local.
	get_parent().request_craft_mixture.rpc_id(1, _pending_paths.duplicate())
	_pending_paths.clear()
	_refresh_available()
	cauldron_preview.display(_pending_paths, inventory)
	# Retour utilisateur : l'écran se ferme tout seul après une composition
	# envoyée, plutôt que de rester ouvert sur un chaudron vide.
	close()


## Reflète le verrouillage "un craft par étage PAR JOUEUR" (cf.
## RunManager.alchemy_lock_changed) -- purement visuel ici, la vérité vit dans
## RunManager, appliquée côté hôte dans Player.request_craft_mixture. Filtre
## sur _owner_peer_id : le signal est diffusé pour TOUS les joueurs (leurs
## fioles respectives, cf. AlchemyStation), cet écran ne doit réagir qu'à
## l'état de son propre propriétaire.
func _on_lock_changed(peer_id: int, used: bool) -> void:
	if peer_id != _owner_peer_id:
		return
	if not root.visible:
		return
	compose_button.disabled = used
	if used:
		result_label.text = "Table déjà utilisée pour cet étage."
