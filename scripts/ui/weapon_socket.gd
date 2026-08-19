extends Control

## Emplacement visuel "trou" sur la silhouette d'arme (cf. inventory_screen.gd
## pour l'usage en lecture seule). weapon_crafting.gd l'utilise aussi comme
## cible de drag & drop : accepts/part_dropped restent des no-op tant que
## personne ne les configure, donc l'usage en lecture seule (inventaire)
## n'est pas affecté.

## Filtre de type, assigné par l'écran parent (ex: func(p): return p is
## GunBarrelWater) -- accepte tout par défaut.
var accepts: Callable = func(_part: Resource) -> bool: return true
signal part_dropped(part: Resource)

@onready var icon_rect: TextureRect = $Icon


## icon == null : le trou reste vide (aucune pièce équipée dans ce slot).
func setup(icon: Texture2D, tooltip: String = "") -> void:
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	tooltip_text = tooltip


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("part") and accepts.call(data["part"])


func _drop_data(_position: Vector2, data: Variant) -> void:
	part_dropped.emit(data["part"])
