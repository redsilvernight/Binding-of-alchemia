extends CanvasLayer

# Écran de crafting d'arme (Phase 5.4). Remplace le weapon_switcher.gd de
# debug (Phase 2.5) : les pièces viennent du véritable Inventory du joueur.
# Comme alchemy_crafting.gd, cet écran ne modifie JAMAIS l'état lui-même —
# sélectionner une pièce envoie l'intention par RPC vers l'hôte
# (Player.request_equip_weapon_part), qui seul valide la possession et
# applique l'équipement (cf. architecture_reseau.md).

@onready var root: Control = $Root
@onready var water_list: ItemList = $Root/Content/Columns/WaterColumn/WaterList
@onready var mixture_list: ItemList = $Root/Content/Columns/MixtureColumn/MixtureList
@onready var tank_list: ItemList = $Root/Content/Columns/TankColumn/TankList
@onready var core_list: ItemList = $Root/Content/Columns/CoreColumn/CoreList
@onready var water_equipped_label: Label = $Root/Content/Columns/WaterColumn/EquippedLabel
@onready var mixture_equipped_label: Label = $Root/Content/Columns/MixtureColumn/EquippedLabel
@onready var tank_equipped_label: Label = $Root/Content/Columns/TankColumn/EquippedLabel
@onready var core_equipped_label: Label = $Root/Content/Columns/CoreColumn/EquippedLabel

var inventory: Inventory

# Un ItemList par slot, aligné avec la liste de resource_path correspondante
# (index de la liste UI == index dans le tableau de chemins), et le Label
# "Équipé : ..." associé pour donner un retour immédiat au clic (sans quoi
# rien ne prouve visuellement qu'une pièce a bien été équipée).
var _lists: Array[ItemList]
var _keys_by_list: Dictionary = {} # ItemList -> Array[String]
var _label_by_list: Dictionary = {} # ItemList -> Label


func _ready() -> void:
	root.visible = false
	_lists = [water_list, mixture_list, tank_list, core_list]
	_label_by_list = {
		water_list: water_equipped_label,
		mixture_list: mixture_equipped_label,
		tank_list: tank_equipped_label,
		core_list: core_equipped_label,
	}
	for list in _lists:
		_keys_by_list[list] = []
		list.item_selected.connect(_on_item_selected.bind(list))


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.weapon_part_added.connect(_on_weapon_parts_changed)
	inventory.weapon_part_removed.connect(_on_weapon_parts_changed)


func open() -> void:
	_refresh_lists()
	_refresh_equipped_labels()
	root.visible = true


func close() -> void:
	root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("ui_cancel"):
		close()


func _on_weapon_parts_changed(_part: Resource) -> void:
	if root.visible:
		_refresh_lists()


func _refresh_lists() -> void:
	for list in _lists:
		list.clear()
		_keys_by_list[list] = []

	for part in inventory.weapon_parts:
		var list: ItemList = _list_for_part(part)
		if list == null:
			continue
		var nom: String = part.resource_path.get_file() if part.resource_path != "" else part.get_class()
		list.add_item(nom)
		_keys_by_list[list].append(part.resource_path)


func _list_for_part(part: Resource) -> ItemList:
	if part is GunBarrelWater:
		return water_list
	elif part is GunBarrelMixture:
		return mixture_list
	elif part is GunTank:
		return tank_list
	elif part is GunCore:
		return core_list
	return null


func _on_item_selected(index: int, list: ItemList) -> void:
	var keys: Array = _keys_by_list[list]
	var part_path: String = keys[index]
	# L'hôte revalidera la possession avant d'équiper ; on ne fait ici
	# qu'exprimer l'intention, jamais d'application locale directe.
	get_parent().request_equip_weapon_part.rpc_id(1, part_path)
	# Retour optimiste : la pièce vient de la liste de nos propres objets
	# possédés, la requête n'échouera donc que si l'inventaire a désync
	# entre-temps (cas limite, pas de rollback géré pour l'instant).
	var label: Label = _label_by_list[list]
	label.text = "Équipé : %s" % list.get_item_text(index)


func _refresh_equipped_labels() -> void:
	var weapon: Weapon = get_parent().weapon
	_set_equipped_label(water_equipped_label, weapon.barrel_water)
	_set_equipped_label(mixture_equipped_label, weapon.barrel_mixture)
	_set_equipped_label(tank_equipped_label, weapon.tank)
	_set_equipped_label(core_equipped_label, weapon.core)


func _set_equipped_label(label: Label, piece: Resource) -> void:
	if piece == null:
		label.text = "Équipé : aucun"
	else:
		var nom: String = piece.resource_path.get_file() if piece.resource_path != "" else piece.get_class()
		label.text = "Équipé : %s" % nom
