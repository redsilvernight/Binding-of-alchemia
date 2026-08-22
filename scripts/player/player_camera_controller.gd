class_name PlayerCameraController
extends RefCounted

## Extrait de player.gd (File Size, cf. .claude/rules/gdscript.md) : calcul du
## zoom et des limites de la caméra du joueur en mode donjon (cf.
## Player._dungeon_camera_mode, jamais actif dans le Hub qui n'a pas de
## grille de salles). Pure math appliquée directement à la Camera2D fournie
## -- aucun état de jeu propre, une seule instance par Player suffit.

## Facteur de zoom-in supplémentaire au-delà du strict nécessaire pour que la
## zone visible tienne dans une salle -- évite qu'un pixel de la salle
## voisine ne dépasse au bord de l'écran par arrondi.
const CAMERA_ZOOM_MARGIN: float = 1.05

var _camera: Camera2D

func _init(camera: Camera2D) -> void:
	_camera = camera

## Le projet n'impose aucune résolution/stretch fixe (cf. project.godot) : la
## taille du viewport suit donc la fenêtre réelle du joueur. Un zoom fixe
## calculé pour une résolution de référence laisserait voir au-delà de la
## salle sur un écran plus large -- on recalcule ici le zoom pour que la zone
## visible tienne toujours dans les dimensions d'une salle, quelle que soit
## la taille de fenêtre (rappelée à chaque redimensionnement, cf.
## Player._on_viewport_size_changed()). N'est jamais appelée hors donjon (cf.
## Player._dungeon_camera_mode).
func update_zoom(viewport_size: Vector2) -> void:
	var zoom_x: float = viewport_size.x / float(Room.ROOM_WIDTH_PX)
	var zoom_y: float = viewport_size.y / float(Room.ROOM_HEIGHT_PX)
	var target_zoom: float = max(zoom_x, zoom_y) * CAMERA_ZOOM_MARGIN
	_camera.zoom = Vector2(target_zoom, target_zoom)

## Empêche la caméra de montrer au-delà de la salle courante (couloir/salle
## voisine visible par une porte ouverte) : les salles sont juxtaposées sans
## marge dans la grille du donjon (cf. game.gd::ROOM_CELL_SIZE, identique à
## Room.ROOM_WIDTH_PX/HEIGHT_PX), donc une simple division entière de la
## position retrouve la salle qui contient reference_position.
func update_room_limits(reference_position: Vector2) -> void:
	var room_col := floori(reference_position.x / Room.ROOM_WIDTH_PX)
	var room_row := floori(reference_position.y / Room.ROOM_HEIGHT_PX)
	_camera.limit_left = room_col * Room.ROOM_WIDTH_PX
	_camera.limit_top = room_row * Room.ROOM_HEIGHT_PX
	_camera.limit_right = (room_col + 1) * Room.ROOM_WIDTH_PX
	_camera.limit_bottom = (room_row + 1) * Room.ROOM_HEIGHT_PX
