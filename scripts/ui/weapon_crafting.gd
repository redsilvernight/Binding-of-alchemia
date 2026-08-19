extends CanvasLayer

# Écran de crafting d'arme (Phase 5.4, restylé : arme à trous géante au
# centre + liste de pièces cliquables/glissables, cf. retour utilisateur
# post-inventaire). Comme avant, cet écran ne modifie JAMAIS l'état lui-même
# -- équiper une pièce (clic OU drag & drop dans le bon trou) envoie
# l'intention par RPC vers l'hôte (Player.request_equip_weapon_part), qui
# seul valide la possession et applique l'équipement (cf. architecture_reseau.md).

const WEAPON_PART_FALLBACK_ICON: Texture2D = preload("res://assets/test/water_bullet_test.png")

@export var item_chip_scene: PackedScene = preload("res://scenes/ui/item_chip.tscn")

@onready var root: Control = $Root
@onready var parts_grid: GridContainer = $Root/FramePanel/Margin/Content/PartsScroll/PartsGrid
@onready var socket_water: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketWaterBarrel
@onready var socket_mixture: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketMixtureBarrel
@onready var socket_tank: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketTank
@onready var socket_core: Control = $Root/FramePanel/Margin/Content/WeaponFrame/SocketCore

var inventory: Inventory
var weapon: Weapon


func _ready() -> void:
	root.visible = false
	# get_parent().weapon : même pattern que l'ancienne _refresh_equipped_labels
	# -- weapon_crafting est toujours instancié comme enfant de Player, après
	# que son propre @onready var weapon ait déjà résolu (cf. player.gd::_ready).
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


## Retour utilisateur : se ferme avec la même touche qu'à l'ouverture (E, via
## Interactable -> Player.open_weapon_crafting()) plutôt qu'avec Échap --
## Échap est réservé au menu pause (pause_menu.gd).
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


## Point d'entrée unique pour équiper, quel que soit le déclencheur (clic sur
## la liste ou drop dans un trou) -- cf. item_chip.gd::activated et
## weapon_socket.gd::part_dropped, tous deux connectés ici.
func _request_equip(part: Resource) -> void:
	# L'hôte revalidera la possession avant d'équiper ; on ne fait ici
	# qu'exprimer l'intention, jamais d'application locale directe.
	get_parent().request_equip_weapon_part.rpc_id(1, part.resource_path)
