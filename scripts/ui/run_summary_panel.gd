extends CanvasLayer
## Panneau de résumé de run (Phase 8.6), affiché sur chaque pair quand tous
## les joueurs sont morts (cf. game.gd._check_all_players_dead/_show_run_summary).
## Purement affichage : lit les noeuds Player déjà présents dans l'arbre
## (mort = spectateur inerte, cf. player.gd.kill(), jamais retiré de la scène)
## et leurs données déjà répliquées à tous les pairs (Weapon.barrel_*/tank/core
## et Weapon.mixture_ingredient_paths), sauf la monnaie qui reste par-pair
## (MetaProgression) : chaque écran n'affiche donc que SA PROPRE monnaie
## gagnée cette run, jamais celle des coéquipiers.

const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")
const WEAPON_PART_FALLBACK_ICON: Texture2D = preload("res://assets/test/water_bullet_test.png")

@export var player_row_scene: PackedScene = preload("res://scenes/ui/run_summary_player_row.tscn")

@onready var root: Control = $Root
@onready var currency_label: Label = $Root/Content/CurrencyLabel
@onready var players_list: VBoxContainer = $Root/Content/ScrollContainer/PlayersList
@onready var replay_button: Button = $Root/Content/Buttons/ReplayButton
@onready var menu_button: Button = $Root/Content/Buttons/MenuButton


func _ready() -> void:
	replay_button.pressed.connect(_on_replay_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func show_summary(players: Array) -> void:
	currency_label.text = "Monnaie gagnée : %d" % MetaProgression.get_run_currency(NetworkManager.get_unique_id())

	for child in players_list.get_children():
		child.queue_free()
	for player in players:
		_add_player_row(player)

	root.visible = true


func _add_player_row(player: Node) -> void:
	var row: Control = player_row_scene.instantiate()
	# add_child AVANT setup/add_*_slot : run_summary_player_row.gd résout ses
	# propres @onready (name_label/mixture_grid/weapon_grid) dans _ready(),
	# pas encore appelé tant que le noeud n'est pas entré dans l'arbre.
	players_list.add_child(row)

	var peer_id: int = int(player.name)
	var label_text: String = "Vous" if peer_id == NetworkManager.get_unique_id() else "Joueur %d" % peer_id
	row.setup(label_text)

	var weapon: Weapon = player.weapon
	var ingredient_counts: Dictionary = _count_ingredients(weapon.mixture_ingredient_paths)
	for ingredient_path in ingredient_counts:
		var count: int = ingredient_counts[ingredient_path]
		var ingredient: Ingredient = load(ingredient_path) as Ingredient
		var icon: Texture2D = ingredient.icon if (ingredient and ingredient.icon) else INGREDIENT_FALLBACK_ICON
		var nom: String = ingredient.nom if ingredient else ingredient_path.get_file()
		row.add_mixture_slot(icon, count, nom)

	for part in [weapon.barrel_water, weapon.barrel_mixture, weapon.tank, weapon.core]:
		if part == null:
			continue
		var icon: Texture2D = part.icon if part.icon else WEAPON_PART_FALLBACK_ICON
		var nom: String = part.resource_path.get_file() if part.resource_path != "" else part.get_class()
		row.add_weapon_slot(icon, -1, nom)


func _count_ingredients(ingredient_paths: Array[String]) -> Dictionary:
	var counts: Dictionary = {} # String (resource_path) -> int
	for path in ingredient_paths:
		counts[path] = counts.get(path, 0) + 1
	return counts


func _on_replay_pressed() -> void:
	replay_button.disabled = true
	menu_button.disabled = true
	RunManager.request_return_to_hub.rpc_id(1)


func _on_menu_pressed() -> void:
	replay_button.disabled = true
	menu_button.disabled = true
	NetworkManager.leave_to_main_menu()
