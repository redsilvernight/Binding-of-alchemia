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

## Cadre de substitution pendant un drag, uniquement sur les trous qui
## accepteraient la pièce en cours de déplacement -- retour utilisateur :
## un modulate sur socket_frame.tres (quasi noir) ne se voyait pas, d'où un
## StyleBox dédié bien plus contrasté (bordure claire + lueur) plutôt qu'un
## simple facteur de couleur.
const HIGHLIGHT_STYLE: StyleBoxFlat = preload("res://resources/ui/socket_frame_highlight.tres")

@onready var icon_rect: TextureRect = $Icon
@onready var frame: Panel = $Frame

## Style d'origine (socket_frame.tres, posé par le .tscn via
## theme_override_styles/panel -- donc déjà un override, pas le thème par
## défaut). Capturé ici pour le réappliquer explicitement en fin de drag :
## remove_theme_stylebox_override() effacerait cet override sans le
## restaurer, laissant le cadre retomber sur le style par défaut du thème.
var _default_frame_style: StyleBox


func _ready() -> void:
	_default_frame_style = frame.get_theme_stylebox("panel")


## icon == null : le trou reste vide (aucune pièce équipée dans ce slot).
func setup(icon: Texture2D, tooltip: String = "") -> void:
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	tooltip_text = tooltip


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("part") and accepts.call(data["part"])


func _drop_data(_position: Vector2, data: Variant) -> void:
	part_dropped.emit(data["part"])


## NOTIFICATION_DRAG_BEGIN/END : diffusées par Godot à tous les Control de
## l'arbre pendant un drag natif, précisément pour ce genre de surbrillance
## de cible -- pas besoin de connecter quoi que ce soit côté item_chip.gd.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and data.has("part") and accepts.call(data["part"]):
			frame.add_theme_stylebox_override("panel", HIGHLIGHT_STYLE)
	elif what == NOTIFICATION_DRAG_END:
		frame.add_theme_stylebox_override("panel", _default_frame_style)
