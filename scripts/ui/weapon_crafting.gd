extends CanvasLayer


const WEAPON_PART_FALLBACK_ICON: Texture2D = preload("res://assets/test/water_bullet_test.png")

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")

@onready var root: Control = $Root
@onready var parts_grid: GridContainer = $Root/FramePanel/Margin/Content/PartsScroll/PartsGridMargin/PartsGrid
@onready var socket_water: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketWaterBarrel
@onready var socket_mixture: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketMixtureBarrel
@onready var socket_tank: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketTank
@onready var socket_core: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketCore
@onready var description_label: Label = $Root/FramePanel/Margin/Content/DescriptionBox/DescriptionLabel

var inventory: Inventory
var weapon: Weapon
var _default_description_text: String


func _ready() -> void:
	root.visible = false
	weapon = get_parent().weapon
	weapon.part_equipped.connect(_on_part_equipped)
	_default_description_text = description_label.text

	socket_water.accepts = func(part: Resource) -> bool: return part is GunBarrelWater
	socket_mixture.accepts = func(part: Resource) -> bool: return part is GunBarrelMixture
	socket_tank.accepts = func(part: Resource) -> bool: return part is GunTank
	socket_core.accepts = func(part: Resource) -> bool: return part is GunCore
	socket_water.part_dropped.connect(_request_equip)
	socket_mixture.part_dropped.connect(_request_equip)
	socket_tank.part_dropped.connect(_request_equip)
	socket_core.part_dropped.connect(_request_equip)
	for socket in [socket_water, socket_mixture, socket_tank, socket_core]:
		socket.selected.connect(_show_description)
		socket.deselected.connect(_clear_description)


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.weapon_part_added.connect(_on_weapon_parts_changed)
	inventory.weapon_part_removed.connect(_on_weapon_parts_changed)


func open() -> void:
	AudioManager.play_sfx("station_open")
	_refresh_parts_grid()
	_refresh_sockets()
	_clear_description()
	root.visible = true


func close() -> void:
	root.visible = false


func is_open() -> bool:
	return root.visible


func toggle() -> void:
	if root.visible:
		close()
	else:
		open()


func _on_weapon_parts_changed(_part: Resource) -> void:
	if root.visible:
		_refresh_parts_grid()


func _on_part_equipped(_piece: Resource) -> void:
	if root.visible:
		_refresh_sockets()


func _refresh_parts_grid() -> void:
	for child in parts_grid.get_children():
		child.queue_free()

	for part in inventory.weapon_parts:
		var chip: Button = item_chip_scene.instantiate()
		parts_grid.add_child(chip)
		var icon: Texture2D = part.icon if part.icon else WEAPON_PART_FALLBACK_ICON
		chip.setup(part, icon, _part_display_name(part))
		chip.activated.connect(_request_equip)
		chip.selected.connect(_show_description)
		chip.deselected.connect(_clear_description)


func _refresh_sockets() -> void:
	socket_water.setup(weapon.barrel_water.icon if weapon.barrel_water else null, _part_display_name(weapon.barrel_water), weapon.barrel_water)
	socket_mixture.setup(weapon.barrel_mixture.icon if weapon.barrel_mixture else null, _part_display_name(weapon.barrel_mixture), weapon.barrel_mixture)
	socket_tank.setup(weapon.tank.icon if weapon.tank else null, _part_display_name(weapon.tank), weapon.tank)
	socket_core.setup(weapon.core.icon if weapon.core else null, _part_display_name(weapon.core), weapon.core)


func _part_display_name(part: Resource) -> String:
	if part == null:
		return "Emplacement vide"
	if "nom" in part and part.nom != "":
		return part.nom
	return part.resource_path.get_file() if part.resource_path != "" else part.get_class()


func _show_description(part: Resource) -> void:
	if part == null:
		_clear_description()
		return
	var desc: String = part.description if "description" in part else ""
	description_label.text = "%s — %s" % [_part_display_name(part), desc] if desc != "" else _part_display_name(part)


func _clear_description() -> void:
	description_label.text = _default_description_text


func _request_equip(part: Resource) -> void:
	get_parent().request_equip_weapon_part.rpc_id(1, part.resource_path)
