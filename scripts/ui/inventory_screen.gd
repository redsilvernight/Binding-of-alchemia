extends CanvasLayer


const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")
const WEAPON_PART_FALLBACK_ICON: Texture2D = preload("res://assets/test/water_bullet_test.png")

@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

@onready var root: Control = $Root
@onready var currency_label: Label = $Root/FramePanel/Margin/Content/HeaderRow/CurrencyLabel
@onready var ingredient_grid: GridContainer = $Root/FramePanel/Margin/Content/IngredientScroll/IngredientGrid
@onready var weapon_part_grid: GridContainer = $Root/FramePanel/Margin/Content/WeaponPartScroll/WeaponPartGrid
@onready var mixture_preview: MixturePreview = $Root/FramePanel/Margin/Content/BottomRow/MixtureColumn/MixturePreview
@onready var socket_water: Control = $Root/FramePanel/Margin/Content/BottomRow/WeaponColumn/WeaponFrame/SocketWaterBarrel
@onready var socket_mixture: Control = $Root/FramePanel/Margin/Content/BottomRow/WeaponColumn/WeaponFrame/SocketMixtureBarrel
@onready var socket_tank: Control = $Root/FramePanel/Margin/Content/BottomRow/WeaponColumn/WeaponFrame/SocketTank
@onready var socket_core: Control = $Root/FramePanel/Margin/Content/BottomRow/WeaponColumn/WeaponFrame/SocketCore

var inventory: Inventory
var weapon: Weapon


func _ready() -> void:
	root.visible = false
	MetaProgression.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(MetaProgression.get_currency())


func _on_currency_changed(new_amount: int) -> void:
	currency_label.text = "Monnaie : %d" % new_amount


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.ingredient_added.connect(_on_ingredient_changed)
	inventory.ingredient_removed.connect(_on_ingredient_changed)
	inventory.weapon_part_added.connect(_on_weapon_part_changed)
	inventory.weapon_part_removed.connect(_on_weapon_part_changed)
	_refresh_ingredients()
	_refresh_weapon_parts()


func bind_weapon(p_weapon: Weapon) -> void:
	weapon = p_weapon
	weapon.part_equipped.connect(_on_part_equipped)
	weapon.mixture_changed.connect(_on_mixture_changed)
	_refresh_weapon_sockets()
	mixture_preview.display(weapon.mixture_ingredient_paths, inventory)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if not root.visible and not get_parent().can_open_inventory():
			AudioManager.play_sfx("ui_error")
			return
		root.visible = not root.visible
		AudioManager.play_sfx("ui_toggle")


func is_open() -> bool:
	return root.visible


func _on_ingredient_changed(_ingredient: Ingredient, _new_quantity: int) -> void:
	_refresh_ingredients()


func _on_weapon_part_changed(_part: Resource) -> void:
	_refresh_weapon_parts()


func _on_part_equipped(_piece: Resource) -> void:
	_refresh_weapon_sockets()


func _on_mixture_changed(ingredient_paths: Array[String]) -> void:
	mixture_preview.display(ingredient_paths, inventory)


func _refresh_ingredients() -> void:
	for child in ingredient_grid.get_children():
		child.queue_free()

	for key in inventory.ingredients.keys():
		var quantity: int = inventory.ingredients[key]
		if quantity <= 0:
			continue
		var ingredient: Ingredient = inventory.ingredient_resources.get(key)
		var slot: Control = slot_scene.instantiate()
		ingredient_grid.add_child(slot)
		var icon: Texture2D = ingredient.icon if (ingredient and ingredient.icon) else INGREDIENT_FALLBACK_ICON
		var nom: String = ingredient.nom if ingredient else key.get_file()
		slot.setup(icon, quantity, nom)


func _refresh_weapon_parts() -> void:
	for child in weapon_part_grid.get_children():
		child.queue_free()

	for part in inventory.weapon_parts:
		var slot: Control = slot_scene.instantiate()
		weapon_part_grid.add_child(slot)
		var icon: Texture2D = part.icon if part.icon else WEAPON_PART_FALLBACK_ICON
		var nom: String = part.resource_path.get_file() if part.resource_path != "" else part.get_class()
		slot.setup(icon, -1, nom)


func _refresh_weapon_sockets() -> void:
	if weapon == null:
		return
	socket_water.setup(weapon.barrel_water.icon if weapon.barrel_water else null, _part_display_name(weapon.barrel_water))
	socket_mixture.setup(weapon.barrel_mixture.icon if weapon.barrel_mixture else null, _part_display_name(weapon.barrel_mixture))
	socket_tank.setup(weapon.tank.icon if weapon.tank else null, _part_display_name(weapon.tank))
	socket_core.setup(weapon.core.icon if weapon.core else null, _part_display_name(weapon.core))


func _part_display_name(part: Resource) -> String:
	if part == null:
		return "Emplacement vide"
	return part.resource_path.get_file() if part.resource_path != "" else part.get_class()
