extends CanvasLayer


const INGREDIENT_FALLBACK_ICON: Texture2D = preload("res://assets/test/mixture_bullet_test.png")

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")

@onready var root: Control = $Root
@onready var cauldron_preview: MixturePreview = $Root/FramePanel/Margin/Content/CauldronPreview
@onready var ingredients_scroll: ScrollContainer = $Root/FramePanel/Margin/Content/IngredientsScroll
@onready var ingredients_grid: GridContainer = $Root/FramePanel/Margin/Content/IngredientsScroll/IngredientsGrid
@onready var compose_button: Button = $Root/FramePanel/Margin/Content/ComposeRow/ComposeButton
@onready var result_label: Label = $Root/FramePanel/Margin/Content/ComposeRow/ResultLabel
@onready var description_label: Label = $Root/FramePanel/Margin/Content/DescriptionBox/DescriptionLabel

var inventory: Inventory
var weapon: Weapon
var _pending_paths: Array[String] = []
var _owner_peer_id: int = 0
var _default_description_text: String


func _ready() -> void:
	root.visible = false
	ingredients_scroll.follow_focus = true
	compose_button.pressed.connect(_on_compose_pressed)
	cauldron_preview.item_dropped.connect(_add_to_pending)
	cauldron_preview.item_activated.connect(_remove_from_pending)
	cauldron_preview.item_selected.connect(_show_description)
	cauldron_preview.item_deselected.connect(_clear_description)
	_default_description_text = description_label.text
	weapon = get_parent().weapon
	_owner_peer_id = int(get_parent().name)
	weapon.mixture_changed.connect(_on_mixture_changed)
	RunManager.alchemy_lock_changed.connect(_on_lock_changed)


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.ingredient_added.connect(_on_inventory_changed)
	inventory.ingredient_removed.connect(_on_inventory_changed)


func _input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	AudioManager.play_sfx("station_open")
	root.visible = true
	_pending_paths.clear()
	_clear_description()
	_refresh_available()
	_refresh_cauldron_preview()
	result_label.text = ""
	_on_lock_changed(_owner_peer_id, RunManager.has_used_alchemy(_owner_peer_id))


func close() -> void:
	root.visible = false


func is_open() -> bool:
	return root.visible


func toggle() -> void:
	if root.visible:
		close()
	else:
		open()


func _on_inventory_changed(_ingredient: Ingredient, _new_quantity: int) -> void:
	if root.visible:
		_refresh_available()


func _on_mixture_changed(_ingredient_paths: Array[String]) -> void:
	if root.visible:
		_refresh_cauldron_preview()


func _refresh_cauldron_preview() -> void:
	cauldron_preview.display(_pending_paths, inventory, weapon.mixture_ingredient_paths)


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
	_refresh_cauldron_preview()


func _remove_from_pending(ingredient: Resource) -> void:
	if not (ingredient is Ingredient):
		return
	var item: Ingredient = ingredient as Ingredient
	var index: int = _pending_paths.find(item.resource_path)
	if index == -1:
		return
	_pending_paths.remove_at(index)
	_refresh_available()
	_refresh_cauldron_preview()


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
		chip.selected.connect(_show_description)
		chip.deselected.connect(_clear_description)

	if root.visible:
		call_deferred("_focus_default")


func _focus_default() -> void:
	if not root.visible:
		return
	if ingredients_grid.get_child_count() > 0:
		(ingredients_grid.get_child(0) as Control).grab_focus()
	else:
		compose_button.grab_focus()


func _on_compose_pressed() -> void:
	if RunManager.has_used_alchemy(_owner_peer_id):
		AudioManager.play_sfx("ui_error")
		result_label.text = "Table déjà utilisée pour cet étage."
		return
	if _pending_paths.is_empty():
		AudioManager.play_sfx("ui_error")
		result_label.text = "Ajoute au moins un ingrédient au chaudron."
		return

	get_parent().request_craft_mixture.rpc_id(1, _pending_paths.duplicate())
	_pending_paths.clear()
	_refresh_available()
	_refresh_cauldron_preview()
	close()


func _show_description(ingredient: Resource) -> void:
	if not (ingredient is Ingredient):
		_clear_description()
		return
	var item: Ingredient = ingredient as Ingredient
	var nom: String = item.nom if item.nom != "" else item.resource_path.get_file()
	description_label.text = "%s — %s" % [nom, item.description] if item.description != "" else nom


func _clear_description() -> void:
	description_label.text = _default_description_text


func _on_lock_changed(peer_id: int, used: bool) -> void:
	if peer_id != _owner_peer_id:
		return
	if not root.visible:
		return
	compose_button.disabled = used
	if used:
		result_label.text = "Table déjà utilisée pour cet étage."
