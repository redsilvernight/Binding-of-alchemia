extends CanvasLayer


const WEAPON_PART_FALLBACK_ICON: Texture2D = preload("res://assets/test/water_bullet_test.png")

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")

@onready var root: Control = $Root
@onready var parts_grid: GridContainer = $Root/FramePanel/Margin/Content/PartsScroll/PartsGridMargin/PartsGrid
@onready var socket_water: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketWaterBarrel
@onready var socket_mixture: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketMixtureBarrel
@onready var socket_tank: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketTank
@onready var socket_core: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketCore

var inventory: Inventory
var weapon: Weapon


func _ready() -> void:
	root.visible = false
	weapon = get_parent().weapon
	weapon.part_equipped.connect(_on_part_equipped)

	socket_water.accepts = func(part: Resource) -> bool: return part is GunBarrelWater
	socket_mixture.accepts = func(part: Resource) -> bool: return part is GunBarrelMixture
	socket_tank.accepts = func(part: Resource) -> bool: return part is GunTank
	socket_core.accepts = func(part: Resource) -> bool: return part is GunCore
	socket_water.part_dropped.connect(_request_equip)
	socket_mixture.part_dropped.connect(_request_equip)
	socket_tank.part_dropped.connect(_request_equip)
	socket_core.part_dropped.connect(_request_equip)


func bind_inventory(p_inventory: Inventory) -> void:
	inventory = p_inventory
	inventory.weapon_part_added.connect(_on_weapon_parts_changed)
	inventory.weapon_part_removed.connect(_on_weapon_parts_changed)


func open() -> void:
	AudioManager.play_sfx("station_open")
	_refresh_parts_grid()
	_refresh_sockets()
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
		var nom: String = part.resource_path.get_file() if part.resource_path != "" else part.get_class()
		chip.setup(part, icon, nom)
		chip.activated.connect(_request_equip)


func _refresh_sockets() -> void:
	socket_water.setup(weapon.barrel_water.icon if weapon.barrel_water else null, _part_display_name(weapon.barrel_water))
	socket_mixture.setup(weapon.barrel_mixture.icon if weapon.barrel_mixture else null, _part_display_name(weapon.barrel_mixture))
	socket_tank.setup(weapon.tank.icon if weapon.tank else null, _part_display_name(weapon.tank))
	socket_core.setup(weapon.core.icon if weapon.core else null, _part_display_name(weapon.core))


func _part_display_name(part: Resource) -> String:
	if part == null:
		return "Emplacement vide"
	return part.resource_path.get_file() if part.resource_path != "" else part.get_class()


func _request_equip(part: Resource) -> void:
	get_parent().request_equip_weapon_part.rpc_id(1, part.resource_path)
