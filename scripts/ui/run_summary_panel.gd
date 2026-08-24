extends CanvasLayer

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


func show_summary(players: Array, final_currency: int) -> void:
	currency_label.text = "Monnaie disponible : %d" % final_currency

	for child in players_list.get_children():
		child.queue_free()
	for player in players:
		_add_player_row(player)

	root.visible = true


func _add_player_row(player: Node) -> void:
	var row: Control = player_row_scene.instantiate()
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
	var counts: Dictionary = {}
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
